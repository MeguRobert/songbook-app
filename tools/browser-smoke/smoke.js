#!/usr/bin/env node
//
// A browser smoke walk over the seams the widget suite cannot see.
//
// Read tools/browser-smoke/README.md before changing anything here. Every
// awkward-looking step in this file is load-bearing and is there because it
// caught, or failed to catch, a real bug.
//
//   node tools/browser-smoke/smoke.js [--port 8795] [--locale hu] [--width 360]
//                                     [--base http://localhost:8795]
//                                     [--out <dir>] [--keep-open]
//
// Exits non-zero if any check fails or if the page logs an uncaught error.

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

// ---------------------------------------------------------------- arguments

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
}
const FLAG = (name) => process.argv.includes(`--${name}`);

const PORT = arg('port', '8795');
const BASE = arg('base', `http://localhost:${PORT}`);
const LOCALE = arg('locale', 'hu');
const WIDTH = Number(arg('width', '360'));
const HEIGHT = Number(arg('height', '780'));
const OUT = arg('out', path.join(__dirname, 'shots'));
const FIXTURE = path.join(__dirname, 'fixtures', 'satb.json');

/// The interface strings each check needs, per locale. Kept here rather than
/// read from the ARBs on purpose: a typo shared between the app and its test is
/// invisible, and this file is meant to notice when a translation changes.
const WORDS = {
  hu: {
    controls: 'Ének beállításai',
    presets: ['Kotta', 'Akkord', 'Szöveg'],
    voices: ['Dallam', 'Alt', 'Tenor', 'Basszus'],
    allVoices: 'Mind',
    back: 'Vissza',
    settings: 'Beállítások',
    measureActions: 'Ütem műveletei',
    beatActions: 'Ütés műveletei',
    merge: 'Összevonás az előző ütemmel',
    properties: 'Ütem tulajdonságai',
    otherVoices: 'TOVÁBBI SZÓLAMOK',
  },
  en: {
    controls: 'Song controls',
    // 'Sheet', not 'Sheet Music' — the chip is deliberately shorter than the
    // settings row that names the same view. Getting this wrong is what the
    // in-script vocabulary is for.
    presets: ['Sheet', 'Chords', 'Lyrics'],
    voices: ['Melody', 'Alto', 'Tenor', 'Bass'],
    allVoices: 'All',
    back: 'Back',
    settings: 'Settings',
    measureActions: 'Measure actions',
    beatActions: 'Beat actions',
    merge: 'Merge into previous measure',
    properties: 'Measure properties',
    otherVoices: 'OTHER VOICES',
  },
  ro: {
    controls: 'Setările cântecului',
    presets: ['Partitură', 'Acord', 'Versuri'],
    voices: ['Melodie', 'Alto', 'Tenor', 'Bas'],
    allVoices: 'Toate',
    back: 'Înapoi',
    settings: 'Setări',
    measureActions: 'Acțiuni pentru măsură',
    beatActions: 'Acțiuni pentru notă',
    merge: 'Unește cu măsura anterioară',
    properties: 'Proprietățile măsurii',
    otherVoices: 'ALTE VOCI',
  },
};

// ------------------------------------------------------------------ results

const failures = [];
const pageErrors = [];

function check(name, ok, detail = '') {
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${name}${detail && !ok ? ` — ${detail}` : ''}`);
  if (!ok) failures.push(name);
}

// ------------------------------------------------------------- page helpers

/// Flutter's service worker caches aggressively and a `?cachebust=` query is NOT
/// enough — it will happily serve the previous build and you will "verify" code
/// from hours ago.
async function clearWorkers(page) {
  await page.evaluate(async () => {
    for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();
    for (const k of await caches.keys()) await caches.delete(k);
  });
}

/// Turns the canvas into a real accessibility DOM that can be driven by label.
/// Without this there is nothing to query and the only option is clicking by
/// coordinate, which passes against broken code as happily as against working
/// code.
async function enableSemantics(page, timeout = 30000) {
  // Wait for the placeholder to EXIST rather than sleeping a fixed 2.5s and
  // hoping. Straight after the service worker is unregistered the app has to
  // re-fetch its whole bundle, so the first load of a run is much slower than the
  // rest — a fixed sleep passed on every later page and failed on the first one,
  // which reads as "the song list is broken" and is not.
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const clicked = await page.evaluate(() => {
      const el = document.querySelector(
        'flt-semantics-placeholder,[aria-label="Enable accessibility"]');
      if (!el) return false;
      el.click();
      return true;
    });
    if (clicked) break;
    await page.waitForTimeout(500);
  }
  await stableSemantics(page);
}

/// Waits until the semantics tree stops changing.
///
/// It lags a beat behind navigation, so a single snapshot taken right after a tap
/// finds almost nothing and the check reports a false failure.
async function stableSemantics(page, timeout = 15000) {
  const deadline = Date.now() + timeout;
  let last = -1;
  while (Date.now() < deadline) {
    const n = await page.evaluate(() => document.querySelectorAll('flt-semantics').length);
    if (n > 0 && n === last) return n;
    last = n;
    await page.waitForTimeout(400);
  }
  return last;
}

async function labels(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')]
      .map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim())
      .filter((s) => s.length));
}

/// True when some semantics node's label is exactly [text], or is exactly one of
/// the newline-separated parts of a MERGED node's label.
///
/// Not a substring match — that finds the whole app bar and proves nothing. But
/// Flutter really does merge a compound row into one node: a notation-editor bar
/// header arrives as a single label reading `1. ütem\n4 / 4 ütés`, and refusing to
/// look inside it reports a working row as broken. Exact-match-per-part keeps the
/// precision while seeing the parts.
async function hasLabel(page, text) {
  const all = await labels(page);
  return all.some((l) => l === text || l.split('\n').some((p) => p.trim() === text));
}

/// Clicks the [nth] node whose label is exactly [text].
///
/// The index matters where a control repeats per row — every bar header carries
/// the same "measure actions" label, and the interesting one is rarely the first.
async function clickLabel(page, text, nth = 0) {
  const ok = await page.evaluate(([t, i]) => {
    const els = [...document.querySelectorAll('flt-semantics')].filter(
      (e) => (e.getAttribute('aria-label') || e.textContent || '').trim() === t);
    if (els.length <= i) return false;
    els[i].click();
    return true;
  }, [text, nth]);
  if (!ok) return false;
  await page.waitForTimeout(1200);
  await stableSemantics(page);
  return true;
}

/// Anything whose box reaches past the viewport, and the widest few nodes.
///
/// This is the only way this harness can see an overflow at all: a RELEASE build
/// reports no `RenderFlex` overflow, because both the assertion and the yellow
/// stripe are debug-only. So it measures the semantics boxes instead — which is
/// also closer to the real question, since a label can be clipped or ellipsized
/// without any RenderFlex ever complaining.
async function overflowing(page) {
  return page.evaluate((w) => {
    const rows = [...document.querySelectorAll('flt-semantics')]
      .map((e) => {
        const r = e.getBoundingClientRect();
        return {
          label: (e.getAttribute('aria-label') || '').trim().replace(/\n/g, ' / '),
          right: Math.round(r.right),
          width: Math.round(r.width),
        };
      })
      .filter((r) => r.label && r.width > 0);
    return {
      past: rows.filter((r) => r.right > w + 1).map((r) => `${r.label} → ${r.right}px`),
      widest: rows.sort((a, b) => b.width - a.width).slice(0, 3),
    };
  }, WIDTH);
}

/// Reports any node reaching past the viewport at the current width.
async function checkNoOverflow(page, where) {
  const box = await overflowing(page);
  check(`nothing overflows the viewport in ${where}`,
    box.past.length === 0, box.past.join('; '));
}

/// Scrolls a bottom sheet's lower sections into view.
///
/// The controls sheet opens at 72% of the screen, so VOICE — which sits below
/// CAPO — starts under the fold. A click on an off-screen chip lands outside the
/// sheet's clip and quietly misses.
async function scrollSheet(page, notches = 12) {
  await page.mouse.move(Math.floor(WIDTH / 2), Math.floor(HEIGHT * 0.66));
  for (let i = 0; i < notches; i++) {
    await page.mouse.wheel(0, 220);
    await page.waitForTimeout(120);
  }
  await stableSemantics(page);
}

async function shot(page, name, opts = {}) {
  fs.mkdirSync(OUT, { recursive: true });
  await page.screenshot({ path: path.join(OUT, `${name}.png`), ...opts });
}

// --------------------------------------------------------------------- walk

(async () => {
  if (!fs.existsSync(FIXTURE)) {
    console.error(`missing fixture ${FIXTURE} — see README.md for how to regenerate it`);
    process.exit(2);
  }
  const words = WORDS[LOCALE];
  if (!words) {
    console.error(`no vocabulary for locale "${LOCALE}" — add one to WORDS`);
    process.exit(2);
  }
  const fixture = fs.readFileSync(FIXTURE, 'utf8');

  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: WIDTH, height: HEIGHT } });
  // A CSP refusal of canvaskit means the app never booted, and every later check
  // then fails for a reason that has nothing to do with what it is testing. Say
  // so once, plainly, instead of 20 times obscurely: the cause is always a build
  // without --no-web-resources-cdn, which leaves Flutter loading canvaskit from
  // gstatic while this app's CSP allows only 'self'.
  let cspBlocked = false;
  page.on('console', (m) => {
    if (m.type() !== 'error') return;
    if (/Content Security Policy/.test(m.text()) && /canvaskit/.test(m.text())) {
      cspBlocked = true;
      return;
    }
    pageErrors.push(`console: ${m.text()}`);
  });
  page.on('pageerror', (e) => {
    if (cspBlocked && /canvaskit|Failed to fetch/.test(e.message)) return;
    pageErrors.push(`pageerror: ${e.message}`);
  });

  try {
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await clearWorkers(page);

    // shared_preferences on web stores under `flutter.<key>`, and the value is
    // the JSON string ITSELF json-encoded. Generating the payload by hand is how
    // a fixture ends up disagreeing with what the app actually writes — see the
    // README for the throwaway-test recipe.
    await page.evaluate(
      ([json, locale]) => {
        localStorage.setItem('flutter.user_songs', JSON.stringify(json));
        localStorage.setItem('flutter.settings_locale', JSON.stringify(locale));
      },
      [fixture, LOCALE],
    );

    // --- the song list, translated ---------------------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await enableSemantics(page);
    check('the song list reaches the accessibility tree',
      (await labels(page)).length > 5);
    check(`the list is in ${LOCALE}`, await hasLabel(page, words.settings));
    await checkNoOverflow(page, 'the song list');
    await shot(page, '01-list');

    // --- a song opened from a link ---------------------------------------
    // Cold-loading a URL is what a shared link does, and it is the case with no
    // navigation stack beneath it.
    await page.goto(`${BASE}/#/song/user:satb-check`, { waitUntil: 'domcontentloaded' });
    await enableSemantics(page);
    check('a pasted song link opens that song',
      page.url().includes('/song/user:satb-check'));
    check('a linked song offers a way back', await hasLabel(page, words.back));
    await shot(page, '02-song');

    // --- the controls sheet ----------------------------------------------
    check('the controls sheet opens', await clickLabel(page, words.controls));
    for (const preset of words.presets) {
      check(`the ${preset} preset is on the sheet`, await hasLabel(page, preset));
    }
    await shot(page, '03-controls');

    // --- the voice picker, on a four-part score --------------------------
    await scrollSheet(page);
    for (const voice of words.voices) {
      check(`the ${voice} voice is offered`, await hasLabel(page, voice));
    }
    check('all voices at once is offered', await hasLabel(page, words.allVoices));
    // The chip row is one of the two places Hungarian has broken this layout.
    await checkNoOverflow(page, 'the voice chip row');
    await shot(page, '04-voices');

    // --- the grand staff --------------------------------------------------
    check('all voices can be selected', await clickLabel(page, words.allVoices));
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1200);
    await stableSemantics(page);
    // The regression this exists for: the sheet is a route on the same navigator,
    // so a rebuild while it was open used to latch "not a deep link" and the only
    // way out of a shared song disappeared for good.
    check('the way out survives using the controls sheet',
      await hasLabel(page, words.back));
    await shot(page, '05-grand-staff', { fullPage: true });

    // --- the notation editor ----------------------------------------------
    // The newest and largest surface, and the one with a control on every row —
    // which is exactly the shape that has broken this layout twice. `merge` is the
    // longest label the feature added in any language, so it is the reason to look.
    await page.goto(`${BASE}/#/song/user:satb-check/notation`,
      { waitUntil: 'domcontentloaded' });
    await enableSemantics(page);
    check('the notation editor opens cold from a URL',
      await hasLabel(page, words.measureActions));
    check('the beat rows keep their own menu',
      await hasLabel(page, words.beatActions));
    await checkNoOverflow(page, 'the editor bar headers');
    await shot(page, '06-editor');

    // OTHER VOICES is appended after every verse, so on a phone it starts well
    // below the fold — and the semantics tree only carries what is laid out, so
    // asking for it without scrolling reports a working section as missing. Same
    // trap as the controls sheet's lower half.
    await scrollSheet(page, 30);
    check('the other voices are listed', await hasLabel(page, words.otherVoices));

    // The SECOND bar's menu: bar 1 offers no merge, having nothing in front of it.
    check('a bar menu opens', await clickLabel(page, words.measureActions, 1));
    check('it offers the merge that fixes mis-barring',
      await hasLabel(page, words.merge));
    check('it offers the measure properties',
      await hasLabel(page, words.properties));
    await checkNoOverflow(page, 'the bar menu');
    await shot(page, '07-measure-menu');
    await page.keyboard.press('Escape');
    await page.waitForTimeout(600);

    // --- the browser's own back button ------------------------------------
    await page.goto(BASE, { waitUntil: 'domcontentloaded' });
    await enableSemantics(page);
    const song = (await labels(page)).find((l) => l.startsWith('Song 900'));
    check('the four-part song is in the list', Boolean(song));
    if (song) {
      await clickLabel(page, song);
      const opened = page.url();
      await page.goBack();
      await page.waitForTimeout(1500);
      await stableSemantics(page);
      check('tapping a song changes the URL', opened.includes('/song/'));
      check('the browser back button leaves the song',
        !page.url().includes('/song/'));
    }
  } catch (e) {
    check('the walk completed', false, e.message);
  } finally {
    if (!FLAG('keep-open')) await browser.close();
  }

  if (cspBlocked) {
    console.log([
      '',
      'FAIL  the app never booted: this build loads canvaskit from gstatic,',
      "      which this app's own CSP blocks on purpose.",
      '      Rebuild the way CI does:',
      '        flutter build web --release --no-web-resources-cdn',
      '      Every check above failed because of that, not because of what it tests.',
    ].join('\n'));
    failures.push('canvaskit blocked by CSP');
  }
  for (const err of pageErrors) console.log(`FAIL  ${err}`);
  const total = failures.length + pageErrors.length;
  console.log(`\n${total === 0 ? 'all checks passed' : `${total} failure(s)`} — screenshots in ${OUT}`);
  process.exit(total === 0 ? 0 : 1);
})();

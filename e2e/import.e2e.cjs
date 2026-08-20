/**
 * End-to-end: photograph a song in a real browser, both engines.
 *
 * `page.evaluate` / `page.$eval` here are Playwright's browser-context calls,
 * not JavaScript `eval` — they ship a function to the page and no string is ever
 * interpreted as code.
 *
 * What each half exercises:
 *
 *  - A chord sheet goes through the *device* path — canvas, page cleaning,
 *    Tesseract fetched from the CDN, the chords-over-lyrics bridge — with
 *    nothing stubbed. The real engine reading a real photograph of song 149.
 *  - A page of sheet music goes through the *service* path, answered by a local
 *    stub returning real Audiveris output. Stubbed because the live reader
 *    demands a Supabase access token a headless browser has no way to hold, and
 *    because the half worth testing is what the app does with the answer: the
 *    grey rectangle came from there, not from the service.
 *
 * The fixture the stub returns is deliberately the shape that broke: real
 * Audiveris MusicXML with no <work-title>, and one bar whose notes all sit off
 * the melody, which the renderer receives as a bar with nothing in it.
 *
 * Two assertions here were wrong before they were right, and both mistakes are
 * worth remembering:
 *
 *  - "the preview mentions the title" passed on the *lyrics*, which contain the
 *    same words. What the accessibility tree does expose is why Save is
 *    disabled, and "Give the song a title" is a direct answer about the box.
 *  - "the preview element exists" passed for the entire life of the grey-box
 *    bug, because the widget tree around it was perfectly correct. Only pixels
 *    tell that one apart.
 */
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  enableSemantics, texts, clickLabel, waitForText, expand, isEnabled,
  regionBelow,
} = require('./dom.cjs');

const APP = process.env.APP_URL || 'http://127.0.0.1:8912';
// The sheet-music reader needs a signed-in session, which this has no way to
// hold, so a run against a deployed origin covers the device path only. Against
// the local build it is the stub answering, and both paths run.
const SERVICE_PATH = !process.env.APP_URL;
const HERE = __dirname;
const SHOTS = path.join(HERE, 'shots');

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? '\n        ' + detail : ''}`);
}

/** Distinct colours in a screenshot: a flat grey box has almost none. */
function pixels(file) {
  return JSON.parse(execFileSync(
    'python', [path.join(HERE, 'pixels.py'), file], { encoding: 'utf-8' }));
}

/**
 * Whether the screen would let this be saved.
 *
 * Not the blocker sentences: those are only rendered when there is no draft, so
 * with a successful import they are absent whatever the state of the boxes.
 * This assertion used to pass with a Title of "J" and no Number at all.
 */
async function saveable(page) {
  return isEnabled(page, 'Save');
}

/** The count the preview reports, e.g. "2 verses" or "6 bars". */
function count(settled) {
  const m = (settled || '').match(/(\d+)\s+(verses?|bars?)/i);
  return m ? { n: Number(m[1]), unit: m[2].toLowerCase() } : null;
}

/**
 * A fresh page per import.
 *
 * Navigating to `#/import` twice does nothing at all: the document and the hash
 * are identical, so the browser does not reload and the app keeps the pending
 * import from last time. The second run was reading the first run's screen and
 * looking for a checkbox that had been scrolled off it.
 */
async function importPhoto(browser, errors, { sheetMusic, photo, shot }) {
  const page = await browser.newPage({ viewport: { width: 1100, height: 1500 } });
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  await page.goto(`${APP}/#/import`, { waitUntil: 'networkidle' });
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 45000 });
  await enableSemantics(page);
  await expand(page, 'More ways to add', 'Photo');

  if (sheetMusic) {
    await clickLabel(page, 'This page has sheet music');
  }

  const [chooser] = await Promise.all([
    page.waitForEvent('filechooser', { timeout: 45000 }),
    clickLabel(page, 'Photo'),
  ]);
  await chooser.setFiles(photo);

  // Reading on the device is about a second once the engine is cached, up to ten
  // on a cold CDN fetch; the stub answers instantly. Wait for the preview to
  // name a count, or for a failure to name itself.
  const settled = await waitForText(page,
    /\d+\s+(bars?|verses?)|could not|cannot|too long|Nothing/i);
  await page.waitForTimeout(2500); // let the first paint of the staff land
  await page.screenshot({ path: path.join(SHOTS, shot + '-full.png') });
  // And again, clipped to the preview. The full page is no use for the
  // flat-colour check: it passes on any page with text on it, including one
  // whose preview never rendered.
  const region = await regionBelow(page, /^PREVIEW/);
  if (region && region.height > 40) {
    await page.screenshot({ path: path.join(SHOTS, shot + '.png'), clip: region });
  }
  const seen = await texts(page);
  const canSave = await saveable(page);
  await page.close();
  return { settled, seen, canSave };
}

(async () => {
  fs.mkdirSync(SHOTS, { recursive: true });
  const browser = await chromium.launch();
  const consoleErrors = [];

  try {
    // ---- A chord sheet, read on the device, nothing stubbed --------------
    const chords = await importPhoto(browser, consoleErrors, {
      sheetMusic: false,
      photo: path.join(HERE, 'chord-sheet.png'),
      shot: 'chord-sheet',
    });
    const chordCount = count(chords.settled);
    check('chord sheet: the page was read',
      chordCount !== null && chordCount.unit.startsWith('verse'),
      chordCount ? `${chordCount.n} ${chordCount.unit}` : `settled on: ${chords.settled}`);
    check('chord sheet: the printed heading did not become a verse',
      chordCount !== null && chordCount.n === 2,
      chordCount ? `${chordCount.n} verses (2 expected; 3 means the heading is a lyric)`
                 : 'no count');
    check('chord sheet: Title and Number were filled, so Save is offered',
      chords.canSave === true,
      chords.canSave === null ? 'no Save control found' : `Save enabled: ${chords.canSave}`);
    check('chord sheet: the words are the song',
      chords.seen.some((t) => /dzsungel Kir/i.test(t)),
      'lyrics present');
    const chordInk = pixels(path.join(SHOTS, 'chord-sheet.png'));
    check('chord sheet: the preview has something in it',
      chordInk.inkShare > 0.2,
      `${chordInk.inkShare}% ink in the preview`);

    // ---- A page of sheet music, answered by the stub ---------------------
    if (!SERVICE_PATH) {
      console.log('\nskipped: the sheet-music half needs the local stub, ' +
        'because the deployed reader requires a signed-in session');
      await browser.close();
      const failedSoFar = results.filter((r) => !r.ok);
      console.log(`\n${results.length - failedSoFar.length}/${results.length} passed`);
      process.exit(failedSoFar.length === 0 ? 0 : 1);
    }
    const score = await importPhoto(browser, consoleErrors, {
      sheetMusic: true,
      photo: path.join(HERE, 'score-page.png'),
      shot: 'score',
    });
    const barCount = count(score.settled);
    check('sheet music: notation came back',
      barCount !== null && barCount.unit.startsWith('bar'),
      barCount ? `${barCount.n} ${barCount.unit}` : `settled on: ${score.settled}`);
    // Audiveris sends no title and this page carries no printed hymn number, so
    // Save must stay refused — and the Title must not have been filled with a
    // fragment of the notation, which is what "J" was.
    check('sheet music: an unnumbered score is not saveable yet',
      score.canSave === false,
      score.canSave === null ? 'no Save control found' : `Save enabled: ${score.canSave}`);
    check('sheet music: no notation fragment was passed off as a title',
      !score.seen.some((t) => /^[A-Za-z]$/.test(t.trim())),
      'a one-letter title is OCR noise, not a heading');

    // Ink, not colour variety. A preview is mostly white paper either way, so
    // "how dominant is the commonest colour" says almost nothing — 97% for a
    // drawn staff and 99.9% for a blank box, which is far too close to assert
    // on. Ink separates them cleanly: measured 0.99% for this staff, 0.64% for
    // the chord sheet, and 0.03% when nothing rendered at all.
    const staff = pixels(path.join(SHOTS, 'score.png'));
    check('sheet music: the staff is drawn, not a flat grey box',
      staff.inkShare > 0.2,
      `${staff.inkShare}% ink in the preview (0.2% is the floor; a blank box measured 0.03%)`);

    check('no console errors in either run', consoleErrors.length === 0,
      consoleErrors.slice(0, 4).join('\n        ') || 'clean');
  } catch (err) {
    check('the run completed', false, err.message);
  }

  await browser.close();
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} passed`);
  process.exit(failed.length === 0 ? 0 : 1);
})();

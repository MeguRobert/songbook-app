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
 * The chord-sheet half also works the review surface that made the screen
 * "more like the golden generator": the photograph kept beside the reading,
 * and the line list - a chord corrected by tapping it, a row's kind overruled
 * and handed back. Those are widget-tested too; this is the layer the widget
 * suite cannot see. It was this file, run for the first time against the new
 * screen, that found the photograph and the preview never sat side by side:
 * the breakpoint was 900 and the screen's pane is 800.
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
  enableSemantics, texts, clickLabel, waitForText, isEnabled, regionBelow,
  boxOf,
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
 * The rows of the LINES list, top to bottom.
 *
 * A row is one semantics node holding a kind badge, the line's text (a lyric
 * row) or one chip per token (a chord row), and its two kind buttons. It is
 * found from the buttons inwards: the `chords` button whose next sibling is
 * `words`, and the element that holds them both is the row. Each row being one
 * node is itself a fix this file prompted - before it, every static text in the
 * list had merged into one label and no row could be told from another.
 */
async function lineRows(page) {
  return page.evaluate(() => {
    const own = (n) => {
      const a = n.getAttribute('aria-label');
      if (a) return a.trim();
      return [...n.childNodes]
        .filter((c) => c.nodeType === 3 ||
          (c.nodeType === 1 && c.tagName !== 'FLT-SEMANTICS'))
        .map((c) => c.textContent).join('').trim();
    };
    const rows = [];
    for (const kind of document.querySelectorAll('flt-semantics[role="button"]')) {
      if (own(kind) !== 'chords') continue;
      const next = kind.nextElementSibling;
      if (!next || own(next) !== 'words') continue;
      const row = kind.parentElement;
      const nodes = [...row.querySelectorAll('flt-semantics')];
      const chips = nodes
        .filter((n) => n.getAttribute('role') === 'button' && n !== kind && n !== next)
        .map(own);
      const texts = nodes
        .filter((n) => n.getAttribute('role') !== 'button')
        .map(own).filter(Boolean);
      const r = row.getBoundingClientRect();
      rows.push({ y: Math.round(r.y), badge: texts[0] || '',
                  text: texts.slice(1).join(' '), chips });
    }
    return rows;
  });
}

/** Clicks chip `chip` of row `row` (both indexes into `lineRows`). */
async function clickChip(page, row, chip) {
  return page.evaluate(([r, c]) => {
    const own = (n) => (n.getAttribute('aria-label') ||
      [...n.childNodes].filter((k) => k.nodeType === 3 ||
        (k.nodeType === 1 && k.tagName !== 'FLT-SEMANTICS'))
        .map((k) => k.textContent).join('')).trim();
    let i = 0;
    for (const kind of document.querySelectorAll('flt-semantics[role="button"]')) {
      if (own(kind) !== 'chords') continue;
      const next = kind.nextElementSibling;
      if (!next || own(next) !== 'words') continue;
      if (i++ !== r) continue;
      const chips = [...kind.parentElement.querySelectorAll('flt-semantics[role="button"]')]
        .filter((n) => n !== kind && n !== next);
      if (!chips[c]) return null;
      chips[c].click();
      return own(chips[c]);
    }
    return null;
  }, [row, chip]);
}

/** Clicks the `chords` or `words` kind button of row `row`. */
async function clickKind(page, row, which) {
  return page.evaluate(([r, w]) => {
    const own = (n) => (n.getAttribute('aria-label') ||
      [...n.childNodes].filter((k) => k.nodeType === 3 ||
        (k.nodeType === 1 && k.tagName !== 'FLT-SEMANTICS'))
        .map((k) => k.textContent).join('')).trim();
    let i = 0;
    for (const kind of document.querySelectorAll('flt-semantics[role="button"]')) {
      if (own(kind) !== 'chords') continue;
      const next = kind.nextElementSibling;
      if (!next || own(next) !== 'words') continue;
      if (i++ !== r) continue;
      (w === 'chords' ? kind : next).click();
      return true;
    }
    return false;
  }, [row, which]);
}

/**
 * Works the review surface on a chord sheet that has just been read.
 *
 * Deliberately independent of what the reader returned: it takes the first
 * chord row and the first lyric row whatever they hold, so a better reading
 * next month does not break the walk. The replacement chord is one no hymnal
 * page in the corpus prints, so finding it afterwards means it got there.
 */
async function reviewLines(page) {
  const out = {};
  out.photoBox = await boxOf(page, /^PHOTO$/);
  out.previewBox = await boxOf(page, '1.');
  const before = await lineRows(page);
  out.rows = before.length;
  const chordRow = before.findIndex((r) => r.chips.length > 0);
  const lyricRow = before.findIndex((r) => r.chips.length === 0);
  out.chordRow = chordRow;
  out.lyricRow = lyricRow;
  if (chordRow === -1 || lyricRow === -1) return out;

  // --- a chord, corrected by tapping it -------------------------------------
  out.was = await clickChip(page, chordRow, 0);
  out.dialog = await waitForText(page, /^Correct this chord$/, { timeout: 10000 });
  if (out.dialog) {
    // The dialog's field has focus (autofocus), and Enter is its Save.
    await page.keyboard.press('Control+A');
    await page.keyboard.type('Bm7');
    await page.keyboard.press('Enter');
    await waitForText(page, /^Bm7$/, { timeout: 10000 });
    await page.waitForTimeout(800);
    const after = await lineRows(page);
    out.chipNow = after[chordRow] && after[chordRow].chips[0];
    out.bm7Nodes = (await page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .filter((n) => (n.getAttribute('aria-label') || n.textContent || '').trim() === 'Bm7')
        .length));
  }

  // --- a lyric row, overruled and handed back -------------------------------
  await clickKind(page, lyricRow, 'chords');
  await page.waitForTimeout(800);
  const overruled = await lineRows(page);
  out.overruledChips = overruled[lyricRow] ? overruled[lyricRow].chips.length : -1;
  await clickKind(page, lyricRow, 'chords'); // the kind it now is: hands it back
  await page.waitForTimeout(800);
  const restored = await lineRows(page);
  out.restoredChips = restored[lyricRow] ? restored[lyricRow].chips.length : -1;
  return out;
}

/**
 * A fresh page per import.
 *
 * Navigating to `#/import` twice does nothing at all: the document and the hash
 * are identical, so the browser does not reload and the app keeps the pending
 * import from last time. The second run was reading the first run's screen and
 * looking for a checkbox that had been scrolled off it.
 */
async function importPhoto(browser, errors, { sheetMusic, photo, shot, exercise }) {
  // Tall enough for the whole screen: paste box, details, the line list and
  // the review row. The semantics tree carries only what is laid out, so a
  // row below the fold is a row that does not exist to this walk.
  const page = await browser.newPage({ viewport: { width: 1100, height: 2000 } });
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push('PAGEERROR: ' + e.message));
  await page.goto(`${APP}/#/import`, { waitUntil: 'networkidle' });
  await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 45000 });
  await enableSemantics(page);
  const firstScreen = await texts(page);

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
    // Only the rendered half when the photograph sits beside it: a photograph
    // is full of ink, and clipping it in would let a blank preview pass.
    const photo = await boxOf(page, /^PHOTO$/);
    if (photo) {
      const half = Math.round(region.width / 2);
      region.x = half;
      region.width = region.width - half;
    }
    await page.screenshot({ path: path.join(SHOTS, shot + '.png'), clip: region });
  }
  const seen = await texts(page);
  const canSave = await saveable(page);
  const extra = exercise ? await exercise(page) : {};
  await page.close();
  return { settled, seen, canSave, firstScreen, ...extra };
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
      exercise: reviewLines,
    });
    check('chord sheet: Photo is on the first screen, nothing to open first',
      chords.firstScreen.includes('Photo') &&
        !chords.firstScreen.includes('More ways to add'),
      'the expander is gone; this walk used to click it');
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

    // ---- the review surface ----------------------------------------------
    check('review: the photograph is kept on screen beside the reading',
      Boolean(chords.photoBox) && chords.seen.some((t) => /chord-sheet\.png/.test(t)),
      chords.photoBox ? 'no file name under the photograph' : 'no PHOTO pane');
    // The decision this pins: side by side on a desktop window. It shipped
    // stacked at every width, because 900 was asked of a pane that is 768.
    check('review: at 1100 wide the preview sits beside the photograph, not under it',
      Boolean(chords.photoBox && chords.previewBox) &&
        chords.previewBox.x - chords.photoBox.x > 250 &&
        Math.abs(chords.previewBox.y - chords.photoBox.y) < 200,
      `PHOTO at ${JSON.stringify(chords.photoBox)}, preview at ${JSON.stringify(chords.previewBox)}`);
    check('review: the line list has a row per line, chord rows as chips',
      chords.rows >= 4 && chords.chordRow !== -1 && chords.lyricRow !== -1,
      `${chords.rows} rows; first chord row ${chords.chordRow}, first lyric row ${chords.lyricRow}`);
    check('review: tapping a chord opens its correction',
      chords.dialog === 'Correct this chord',
      `tapped "${chords.was}", saw: ${chords.dialog}`);
    check('review: the corrected chord replaces the chip and reaches the preview',
      chords.chipNow === 'Bm7' && chords.bm7Nodes >= 2,
      `chip now "${chords.chipNow}"; Bm7 appears in ${chords.bm7Nodes} node(s) (chip + preview = 2)`);
    check('review: a lyric row overruled to chords becomes chips, and is handed back',
      chords.overruledChips > 0 && chords.restoredChips === 0,
      `chips while overruled: ${chords.overruledChips}, after handing back: ${chords.restoredChips}`);

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

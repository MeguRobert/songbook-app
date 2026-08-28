/**
 * Song CRUD in a real browser: create, read, update, delete.
 *
 *   node songs_crud.e2e.cjs [http://127.0.0.1:8912]
 *
 * Written because a real bug got past 1500 widget tests: correcting a song's
 * words and pressing Save stored the OLD verses, reported success, and said
 * nothing. It was reported from the live app as *"I can edit them, but no
 * matter that I save, it doesn't get saved"*, and no automated test in this
 * repo covered the round trip that would have caught it — create a song, edit
 * it, save, and check what is actually stored.
 *
 * The case that mattered is CASE A below: **edit the words and press Save
 * WITHOUT pressing Parse**. That is what a person does when the button they
 * want says Save. Every earlier test pressed Parse first, which is exactly why
 * the defect survived.
 *
 * ## Addressing a Flutter canvas
 *
 * Read `dom.cjs` first; its three hard-won lessons apply here too. One more
 * that this file needed:
 *
 * **A TextField publishes NO semantics node until it has focus.** So a field
 * cannot be found by its label the way a button can — the tree simply does not
 * contain it. Every field here is reached by offset from the section heading
 * above it, which IS published. That is why `PASTE THE SONG` and `DETAILS` are
 * looked up and then used as origins rather than clicked.
 *
 * If the import screen's layout changes, the offsets below are what break, and
 * they break loudly (a click into empty space types nowhere, and the assertion
 * that follows fails with the screen's text attached).
 */
const { chromium } = require('playwright');
const { enableSemantics } = require('./dom.cjs');

const APP = process.argv[2] || 'http://127.0.0.1:8912';

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}` +
    (ok || !detail ? '' : `\n        ${String(detail).slice(0, 300)}`));
}

/**
 * Every semantics node with its own label and the centre of its box.
 *
 * `label` prefers aria-label and falls back to the node's OWN text — not its
 * descendants', or every ancestor would answer to every child's words.
 */
async function nodes(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('flt-semantics')].map((n) => {
      const r = n.getBoundingClientRect();
      const own = [...n.childNodes]
        .filter((c) => c.nodeType === 3 ||
          (c.nodeType === 1 && c.tagName !== 'FLT-SEMANTICS'))
        .map((c) => c.textContent).join('').trim();
      return {
        role: n.getAttribute('role') || '',
        label: ((n.getAttribute('aria-label') || '').trim() || own).slice(0, 80),
        x: Math.round(r.x + r.width / 2),
        y: Math.round(r.y + r.height / 2),
        left: Math.round(r.x),
      };
    }).filter((n) => n.label));
}

const find = async (page, re) =>
  (await nodes(page)).find((n) => re.test(n.label)) || null;

/** Everything on screen, for an assertion's failure detail. */
const screenText = async (page) =>
  (await nodes(page)).map((n) => n.label).join(' | ');

async function tap(page, re, what, wait = 1200) {
  const n = await find(page, re);
  if (!n) throw new Error(`no node matching ${re} for "${what}". ` +
    `Present: ${(await screenText(page)).slice(0, 400)}`);
  await page.mouse.click(n.x, n.y);
  await page.waitForTimeout(wait);
}

/** Focus a field by point and replace everything in it. */
async function replaceAt(page, x, y, value) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(400);
  await page.keyboard.press('Control+A');
  await page.keyboard.type(value, { delay: 8 });
  await page.waitForTimeout(700);
}

/** The paste box: the gap between its heading and the buttons beneath it. */
async function replaceSheet(page, sheet) {
  const heading = await find(page, /PASTE THE SONG|REPLACE THE WORDS/);
  const parse = await find(page, /^Parse$/);
  if (!heading || !parse) throw new Error('the import screen is not on screen');
  await replaceAt(page, heading.x, Math.round((heading.y + parse.y) / 2), sheet);
}

/** Title sits ~44px below the DETAILS heading, Number ~106 and hard left. */
async function fillDetails(page, { title, number }) {
  const details = await find(page, /^DETAILS/);
  if (!details) throw new Error('the details section is not on screen');
  if (title !== undefined) await replaceAt(page, details.x, details.y + 44, title);
  if (number !== undefined) {
    await replaceAt(page, details.left + 48, details.y + 106, number);
  }
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1000 } });
  const errors = [];
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', (e) => errors.push(`PAGEERROR: ${e.message}`));

  /// A cold load of `hash`, with the service worker cleared the first time so
  /// this cannot silently test the previous build.
  const boot = async (hash) => {
    await page.goto(`${APP}/${hash}`, { waitUntil: 'networkidle' });
    await page.waitForSelector('flt-glass-pane, flutter-view', { timeout: 60000 });
    await enableSemantics(page);
    await page.waitForTimeout(1500);
  };

  try {
    await page.goto(`${APP}/#/import`, { waitUntil: 'domcontentloaded' });
    await page.evaluate(async () => {
      for (const r of await navigator.serviceWorker.getRegistrations()) await r.unregister();
      for (const k of await caches.keys()) await caches.delete(k);
      localStorage.clear();
    });
    await boot('#/import');

    // ---------------------------------------------------------- CREATE
    await replaceSheet(page, 'D        G\nEREDETI SZOVEG\n\nA        D\nMasodik sor');
    await tap(page, /^Parse$/, 'Parse', 2200);
    await fillDetails(page, { title: 'Crud Proba', number: '902' });
    await tap(page, /^Save$/, 'Save', 4000);

    let seen = await screenText(page);
    const songUrl = page.url();
    const hash = songUrl.split('/songbook-app/')[1] || songUrl.split(/\/(?=#)/)[1];
    check('create: saving lands on the new song',
      /Crud Proba/i.test(seen) && /\/song\//.test(songUrl), `${songUrl} :: ${seen.slice(0, 200)}`);
    check('create: the words are the ones pasted',
      /EREDETI SZOVEG/i.test(seen), seen.slice(0, 200));

    // ------------------------------------------------------------ READ
    await boot('#/');
    seen = await screenText(page);
    check('read: the song is in the catalogue list', /Crud Proba/i.test(seen), seen.slice(0, 300));

    // ---------------------------------------------------------- UPDATE
    // CASE A -- the regression this file exists for. Edit the words and press
    // Save WITHOUT Parse. The words used to be discarded in silence.
    await boot(hash);
    await tap(page, /More actions/i, 'the overflow menu', 1800);
    await tap(page, /Edit song/i, 'Edit song', 3000);
    check('update: the edit screen opens with the song in it',
      /REPLACE THE WORDS/i.test(await screenText(page)), (await screenText(page)).slice(0, 200));

    await replaceSheet(page, 'D        G\nJAVITOTT SZOVEG\n\nA        D\nMasodik sor');
    await tap(page, /^Save$/, 'Save', 4000);
    seen = await screenText(page);
    check('update: words edited WITHOUT pressing Parse are saved',
      /JAVITOTT SZOVEG/i.test(seen), `still shows: ${seen.slice(0, 250)}`);

    await boot(hash);
    seen = await screenText(page);
    check('update: and they survive a full reload',
      /JAVITOTT SZOVEG/i.test(seen), seen.slice(0, 250));
    check('update: the old words are gone',
      !/EREDETI SZOVEG/i.test(seen), seen.slice(0, 250));

    // CASE B -- a title-only change. This half always worked; it is here so a
    // fix for CASE A cannot quietly break it.
    await boot(hash);
    await tap(page, /More actions/i, 'the overflow menu', 1800);
    await tap(page, /Edit song/i, 'Edit song', 3000);
    await fillDetails(page, { title: 'Crud Proba Atnevezve' });
    await tap(page, /^Save$/, 'Save', 4000);
    await boot(hash);
    seen = await screenText(page);
    check('update: a title-only change is saved', /Atnevezve/i.test(seen), seen.slice(0, 250));
    check('update: and it did not cost the words',
      /JAVITOTT SZOVEG/i.test(seen), seen.slice(0, 250));

    // ---------------------------------------------------------- DELETE
    await tap(page, /More actions/i, 'the overflow menu', 1800);
    await tap(page, /^Delete/i, 'Delete', 1800);
    const confirm = (await nodes(page)).filter((n) => /^Delete$/i.test(n.label)).pop();
    if (confirm) {
      await page.mouse.click(confirm.x, confirm.y);
      await page.waitForTimeout(3000);
    }
    await boot('#/');
    seen = await screenText(page);
    check('delete: the song is gone from the list', !/Crud Proba/i.test(seen), seen.slice(0, 300));
  } catch (err) {
    check('the walk completed', false, err.message);
  }

  for (const e of errors) console.log(`FAIL  console: ${e}`);
  await browser.close();
  const failed = results.filter((r) => !r.ok).length + errors.length;
  console.log(`\n${results.length - results.filter((r) => !r.ok).length}/${results.length} checks passed` +
    (errors.length ? `, ${errors.length} console error(s)` : ''));
  process.exit(failed ? 1 : 0);
})();

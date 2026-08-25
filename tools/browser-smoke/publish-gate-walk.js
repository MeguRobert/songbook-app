// Walks the PUBLISH GATE in a deployed build, as a real signed-in contributor:
// import a song, share it, and meet each stop the way a first-time contributor
// does.
//
//   SITE=https://megurobert.github.io/songbook-app/ //   EMAIL=... PW=... node tools/browser-smoke/publish-gate-walk.js
//
// The account MUST be reset to a first-time state first -- display_name and
// guidelines_accepted_at both null, and no pending submissions -- or the gate
// has nothing left to ask for and every stop is skipped. That mistake produced
// a green run that proved nothing, twice.
//
// FOUR THINGS THIS HARNESS HAD TO LEARN, each of which silently produced a
// misleading run before it was fixed:
//
//  1. The placeholder that enables the semantics tree is 1x1 px at (-1,-1), so
//     Playwright's click -- even forced -- lands nowhere. Dispatch it on the
//     element instead.
//  2. Text lives in the CHILDREN of flt-semantics nodes (<h2>, <span>), not in
//     aria-label. Reading aria-label alone yields an empty tree, and an empty
//     tree satisfies every "X is not shown" assertion vacuously.
//  3. Read ALL semantics roots and wait for the tree to STOP CHANGING. An
//     overlay (dialog, popup menu) renders its own root a beat later, so
//     returning on the first non-empty read grabs the screen underneath it.
//  4. Some widgets publish no text at all: a TextField's content, and the list
//     tiles on "Songs I sent in". Those are verified by screenshot, which is a
//     legitimate check rather than a fallback -- see the README.
//
// Taps are by coordinate where Flutter merges a row into a section node. That is
// safe ONLY because nothing is asserted from the tap itself: every step verifies
// by reading the tree or the shot afterwards.
const { chromium } = require('playwright');

const SITE = process.env.SITE || 'https://megurobert.github.io/songbook-app/';
const EMAIL = process.env.EMAIL;
const PW = process.env.PW;
if (!EMAIL || !PW) { console.error('set EMAIL and PW'); process.exit(2); }

let pass = 0, fail = 0;
const check = (l, ok, d) => { if (ok) { console.log(`  PASS  ${l}`); pass++; }
  else { console.log(`  FAIL  ${l}${d ? `\n        ${String(d).slice(0, 260)}` : ''}`); fail++; } };

const sem = async p => { await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await p.waitForTimeout(1200); };
const text = async p => {
  // Poll until the tree STOPS CHANGING, not until it is merely non-empty.
  // Returning on the first non-empty read grabs the underlying screen before an
  // overlay (a popup menu, a dialog) has rendered its own semantics root -- which
  // reads exactly like the menu not offering the item you are looking for.
  let prev = '';
  for (let i = 0; i < 12; i++) {
    const t = await p.evaluate(() => Array.from(document.querySelectorAll('flt-semantics-host, flt-semantics'))
      .map(n => (n.innerText || n.textContent || '')).join(' ').replace(/\s+/g, ' ').trim());
    if (t && t === prev) return t;
    prev = t;
    await p.waitForTimeout(600);
  }
  return prev;
};
const shot = (p, n) => p.screenshot({ path: `shots/${n}.png` });

(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 900 } })).newPage();
  const errors = []; page.on('pageerror', e => errors.push(String(e)));
  const go = async (h, w = 7000) => { await page.goto(SITE + h, { waitUntil: 'domcontentloaded' }); await page.waitForTimeout(w); await sem(page); };

  // --- sign in -------------------------------------------------------------
  await go('#/settings');
  await page.mouse.click(100, 120);
  await page.waitForTimeout(3500); await sem(page);
  await page.mouse.click(200, 239); await page.waitForTimeout(500);
  await page.keyboard.type(EMAIL, { delay: 20 });
  await page.mouse.click(200, 299); await page.waitForTimeout(500);
  await page.keyboard.type(PW, { delay: 20 });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(7000); await sem(page);
  if (!/Sign out/i.test(await text(page))) { await page.mouse.click(206, 364); await page.waitForTimeout(8000); await sem(page); }
  check('signed in', /Sign out/i.test(await text(page)), (await text(page)).slice(0,160));

  // --- import a song -------------------------------------------------------
  console.log('\n=== import a song locally ===');
  await go('#/import');
  let t = await text(page);
  await shot(page, '10-import');
  check('the import screen opened', /Add a song|Paste|Save/i.test(t), t.slice(0, 200));

  // The paste box sits at y~147 (bordered area 110-185). y=260 is empty space
  // below it -- a miss there types nowhere and looks like a broken text field.
  await page.mouse.click(206, 147); await page.waitForTimeout(700);
  await page.keyboard.type('1.\nJol van, jol van, minden jol van\nAz Ur velem van ma is', { delay: 8 });
  await page.waitForTimeout(1500); await sem(page);
  await shot(page, '11-import-pasted');
  t = await text(page);
  // NOT asserted from the semantics tree: a text field's CONTENT is not exposed
  // there, so "is the pasted text present" cannot be read this way. The parse
  // below is the real evidence that the characters arrived.

  // --- parse, title, save --------------------------------------------------
  await page.mouse.click(344, 224);   // Parse
  await page.waitForTimeout(3000); await sem(page);
  t = await text(page); await shot(page, '12-parsed');
  check('the sheet parsed into a preview', /PREVIEW|Title/i.test(t), t.slice(0, 260));
  check('the parser found the verse', /Jol van, jol van/i.test(t), t.slice(0, 300));
  check('save is blocked until it has a title', /Give the song a title/i.test(t), t.slice(-160));

  await page.mouse.click(206, 355);   // Title
  await page.waitForTimeout(600);
  await page.keyboard.type('Jol van minden', { delay: 20 });
  await page.waitForTimeout(1000);
  // A number is required too -- the blocker text changes from "Give the song a
  // title" to "Give the song a number", which is how this was discovered.
  await page.mouse.click(64, 415);
  await page.waitForTimeout(600);
  await page.keyboard.type('901', { delay: 30 });
  await page.waitForTimeout(1200); await sem(page);
  await shot(page, '13-titled');

  await page.mouse.click(384, 27);    // Save
  await page.waitForTimeout(7000); await sem(page);
  t = await text(page); await shot(page, '14-song-view');
  check('saving lands on the song', /Jol van minden/i.test(t), t.slice(0, 260));

  // --- share it ------------------------------------------------------------
  console.log('=== share it: the gate ===');
  await page.mouse.click(392, 38);    // overflow menu ("More actions")
  await page.waitForTimeout(2500); await sem(page);
  t = await text(page); await shot(page, '15-menu');
  // The popup menu does not publish a semantics root of its own, so its items
  // cannot be asserted from the tree. Verified instead by shots/15-menu.png,
  // which shows "Share with the congregation" -- and by the gate firing below,
  // which could not happen if the item were missing.

  // Tap the Share item by its semantics node -- menu items are their own nodes,
  // so this one does not need a coordinate.
  await page.mouse.click(260, 258);   // "Share with the congregation"
  await page.waitForTimeout(5000); await sem(page);
  t = await text(page); await shot(page, '16-gate-stop-1');
  check('STOP: asked for a name to credit', /How should we credit you/i.test(t), t.slice(0, 320));

  // Name -> Save
  await page.mouse.click(206, 495); await page.waitForTimeout(600);
  await page.keyboard.type('Teszt Tag', { delay: 25 });
  await page.mouse.click(308, 552);
  await page.waitForTimeout(5000); await sem(page);
  t = await text(page); await shot(page, '17-gate-stop-2');
  check('STOP: the guidelines are shown', /Before you send it/i.test(t), t.slice(0, 400));
  check('the seeded guidelines text is there', /worship|istentisztelet/i.test(t), t.slice(0, 400));

  // Tick, then agree. The button is disabled until the box is ticked -- visible
  // greyed out in shots/17-gate-stop-2.png.
  await page.mouse.click(84, 503);
  await page.waitForTimeout(1200); await sem(page);
  await shot(page, '18-guidelines-ticked');
  await page.mouse.click(274, 576);   // Agree and send
  await page.waitForTimeout(5000); await sem(page);
  t = await text(page); await shot(page, '19-confirm');
  check('STOP: asked to confirm before sending', /Share this song/i.test(t), t.slice(0, 320));

  // The confirm dialog's Send.
  const send = await page.evaluate(() => {
    const n = Array.from(document.querySelectorAll('flt-semantics'))
      .find(e => (e.innerText || '').trim() === 'Send');
    if (!n) return null;
    const r = n.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  });
  if (send) { await page.mouse.click(send.x, send.y); } else { await page.mouse.click(300, 520); }
  // The snackbar lives 3 seconds. Screenshot inside that window, or the only
  // evidence of success has already faded.
  await page.waitForTimeout(2200);
  await shot(page, '20-sent');
  await sem(page); t = await text(page);
  // The snackbar is the nicest evidence but lives 3 seconds, which makes it a
  // flaky thing to assert on. "Songs I sent in" is the durable proof, and it
  // exercises the my-submissions route at the same time.
  await go('#/my-submissions');
  t = await text(page); await shot(page, '21-my-submissions');
  check('the song appears in "Songs I sent in"', /Jol van minden/i.test(t), t.slice(0, 320));
  check('it is shown as awaiting review', /wait|pending|review/i.test(t), t.slice(0, 320));
  check('no uncaught page errors', errors.length === 0, errors.slice(0, 2).join(' | '));
  await b.close();
  console.log(`\npassed=${pass} failed=${fail}`);
})().catch(e => { console.error('crashed:', e.message); process.exit(2); });

// The admin panel in a deployed build, driven as a real administrator.
//
//   SITE=... EMAIL=... PW=... node tools/browser-smoke/admin-panel-walk.js
//
// Covers the cold load of /admin -- the route guard's real failure mode, which a
// warm session cannot reproduce -- plus the member list (which only loads if the
// admin-users Edge Function is deployed and the caller's rank checks out), the
// contribution settings, and the moderation queue with its attribution line.
//
// Read tools/browser-smoke/publish-gate-walk.js first: its header documents the
// four ways a Flutter-web semantics harness lies, all of which apply here too.
// The one that bit this file specifically: Enter does not always submit the
// sign-in form, and without the fallback click the session stays signed out --
// at which point every admin route correctly shows "This area is for
// administrators" and the run reads exactly like a broken role check.
//
// Some list tiles publish no semantics text (song titles in the queue, member
// rows). Those are verified from shots/ -- see the README.
const { chromium } = require('playwright');
const SITE = process.env.SITE || 'https://megurobert.github.io/songbook-app/';
const EMAIL = process.env.EMAIL;
const PW = process.env.PW;
if (!EMAIL || !PW) { console.error('set EMAIL and PW'); process.exit(2); }

let pass = 0, fail = 0;
const check = (l, ok, d) => { if (ok) { console.log(`  PASS  ${l}`); pass++; }
  else { console.log(`  FAIL  ${l}${d ? `\n        ${String(d).slice(0, 300)}` : ''}`); fail++; } };
const sem = async p => { await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()); await p.waitForTimeout(1200); };
const text = async p => {
  let prev = '';
  for (let i = 0; i < 12; i++) {
    const t = await p.evaluate(() => Array.from(document.querySelectorAll('flt-semantics-host, flt-semantics'))
      .map(n => (n.innerText || n.textContent || '')).join(' ').replace(/\s+/g, ' ').trim());
    if (t && t === prev) return t;
    prev = t; await p.waitForTimeout(600);
  } return prev;
};
const shot = (p, n) => p.screenshot({ path: `shots/${n}.png` });

(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 900 } })).newPage();
  const errors = []; page.on('pageerror', e => errors.push(String(e)));
  const go = async (h, w = 8000) => { await page.goto(SITE + h, { waitUntil: 'domcontentloaded' }); await page.waitForTimeout(w); await sem(page); };

  // sign in
  await go('#/settings');
  await page.mouse.click(100, 120); await page.waitForTimeout(3500); await sem(page);
  await page.mouse.click(200, 239); await page.waitForTimeout(500);
  await page.keyboard.type(EMAIL, { delay: 20 });
  await page.mouse.click(200, 299); await page.waitForTimeout(500);
  await page.keyboard.type(PW, { delay: 20 });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(7000); await sem(page);
  // Enter does not always submit; fall back to the button. Without this the
  // session stays signed out and every admin route correctly shows the refusal
  // -- which reads exactly like a broken role check.
  if (!/Sign out/i.test(await text(page))) {
    await page.mouse.click(206, 364);
    await page.waitForTimeout(9000); await sem(page);
  }
  let t = await text(page); await shot(page, '30-admin-settings');
  check('signed in as the administrator', /Sign out/i.test(t), t.slice(0, 200));
  check('Settings now offers Administration', /Administration/i.test(t), t.slice(0, 300));
  check('and names the role', /Administrator/i.test(t), t.slice(0, 300));

  // THE cold load
  console.log('\n=== cold load of /admin (the guard\'s real failure mode) ===');
  await go('#/admin');
  t = await text(page); await shot(page, '31-admin-overview');
  check('the overview renders, not the refusal', !/This area is for administrators/i.test(t), t.slice(0, 300));
  check('it shows the queue depth', /waiting for review/i.test(t), t.slice(0, 300));
  check('it shows the member count', /accounts/i.test(t), t.slice(0, 300));

  console.log('\n=== the member list ===');
  await go('#/admin/users');
  t = await text(page); await shot(page, '32-users');
  check('the list loads through the Edge Function', /Members/i.test(t), t.slice(0, 300));
  check('it shows the test member', /songbook-test-member|Teszt Tag/i.test(t), t.slice(0, 400));
  check('it shows the owner account', /megurobi14/i.test(t), t.slice(0, 400));
  check('roles are labelled', /Administrator|Member/i.test(t), t.slice(0, 400));

  console.log('\n=== settings ===');
  await go('#/admin/settings');
  t = await text(page); await shot(page, '33-admin-settings-screen');
  check('the contribution settings render', /Accept new songs/i.test(t), t.slice(0, 400));
  check('the daily cap is shown', /per person per day|day/i.test(t), t.slice(0, 400));
  check('the guidelines editor is there', /Contribution guidelines|Magyar/i.test(t), t.slice(0, 500));

  console.log('\n=== the moderation queue ===');
  await go('#/admin/queue');
  t = await text(page); await shot(page, '34-queue');
  check('the pending song is listed', /Jol van minden/i.test(t), t.slice(0, 400));
  check('ATTRIBUTION: it says who submitted it', /Submitted by Teszt Tag/i.test(t), t.slice(0, 400));
  check('approve and reject are offered', /Approve/i.test(t), t.slice(0, 400));

  check('no uncaught page errors', errors.length === 0, errors.slice(0, 2).join(' | '));
  await b.close();
  console.log(`\npassed=${pass} failed=${fail}`);
})().catch(e => { console.error('crashed:', e.message); process.exit(2); });

#!/usr/bin/env node
//
// Drives the app's own reading path over a set of photographs and prints one
// JSON object per page to stdout.
//
//   node browser_driver.cjs --base http://127.0.0.1:PORT --pages a.jpg,b.jpg
//                           [--headed] [--timeout 180000]
//
// Node rather than Python because playwright is already installed globally here
// and every other browser check in this repo is a Node script
// (tools/browser-smoke/smoke.js, e2e/import.e2e.cjs). Adding a second
// playwright install to reach the same browser would be the only new thing.
//
// The page it drives is compiled from songbook_app/tool/browser_reader_harness.dart,
// which calls BrowserPhotoImportService directly. Nothing here reimplements the
// app; a fix in the app changes these numbers without being ported.

const { chromium } = require('playwright');

function arg(name, fallback) {
  const i = process.argv.indexOf(`--${name}`);
  return i === -1 ? fallback : process.argv[i + 1];
}

const BASE = arg('base');
const PAGES = (arg('pages') || '').split(',').filter(Boolean);
const TIMEOUT = Number(arg('timeout', '180000'));
const HEADED = process.argv.includes('--headed');

if (!BASE || !PAGES.length) {
  console.error('need --base and --pages');
  process.exit(2);
}

(async () => {
  const browser = await chromium.launch({ headless: !HEADED });
  const page = await browser.newPage();

  // Console errors and CSP violations are outcomes, not noise. A policy
  // violation is what caught the app fetching CanvasKit from a CDN, so the
  // harness records them rather than letting a reading look clean.
  const errors = [];
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  page.on('pageerror', (e) => errors.push(String(e)));
  await page.addInitScript(() => {
    window.__csp = [];
    document.addEventListener('securitypolicyviolation', (e) => {
      window.__csp.push(`${e.violatedDirective} ${e.blockedURI}`);
    });
  });

  await page.goto(BASE, { timeout: 60000 });
  await page.waitForFunction(() => typeof window.readPage === 'function',
                             { timeout: 60000 });

  for (const name of PAGES) {
    const before = errors.length;
    const started = Date.now();
    let answer;
    try {
      const raw = await page.evaluate(
        ([n, ms]) => Promise.race([
          window.readPage('photos/' + encodeURIComponent(n)),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('timed out in the page')), ms)),
        ]),
        [name, TIMEOUT]);
      answer = JSON.parse(raw);
    } catch (error) {
      answer = { error: String(error && error.message ? error.message : error) };
    }
    const csp = await page.evaluate(() => window.__csp || []);
    process.stdout.write(JSON.stringify({
      page: name,
      seconds: (Date.now() - started) / 1000,
      csp,
      consoleErrors: errors.slice(before),
      ...answer,
    }) + '\n');
  }

  await browser.close();
})().catch((error) => {
  console.error(String(error && error.stack ? error.stack : error));
  process.exit(1);
});

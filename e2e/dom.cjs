/**
 * Addressing a Flutter canvas from Playwright.
 *
 * Flutter paints into a canvas, so there is nothing to click until the
 * accessibility tree is switched on: clicking the "Enable accessibility"
 * placeholder turns the canvas into a DOM of <flt-semantics> nodes. Two things
 * about that DOM are easy to get wrong and cost an hour each:
 *
 *  - Nodes carry their label as text content, not as aria-label. Selecting on
 *    [aria-label] finds nothing at all, which looks exactly like the screen
 *    having failed to render.
 *  - Nodes can sit outside the viewport while the widget they describe is
 *    plainly visible, so Playwright's own click refuses with "element is
 *    outside of the viewport". Clicking through the DOM is the way in.
 */

/** Switch the canvas into an addressable accessibility tree. */
async function enableSemantics(page) {
  // Already on: Flutter keeps accessibility enabled across a reload within the
  // same page session and does not put the placeholder back, so waiting for it
  // a second time waits forever.
  if (await page.$('flt-semantics[role]')) return;
  const sel = 'flt-semantics-placeholder, [aria-label="Enable accessibility"]';
  await page.waitForSelector(sel, { state: 'attached', timeout: 45000 });
  await page.$eval(sel, (el) => el.click());
  await page.waitForSelector('flt-semantics[role]', { timeout: 45000 });
}

/**
 * Every distinct label the tree exposes.
 *
 * Both sources, because Flutter uses both: a button carries its label as text
 * content, while a merged control (a checkbox and its words) carries it as
 * aria-label. Reading only one of the two finds half the screen.
 */
async function texts(page) {
  return page.evaluate(() => {
    const seen = new Set();
    for (const n of document.querySelectorAll('flt-semantics')) {
      const t = (n.textContent || '').trim();
      if (t) seen.add(t);
      const a = (n.getAttribute('aria-label') || '').trim();
      if (a) seen.add(a);
    }
    return [...seen];
  });
}

/**
 * Click the node whose own label is `label`.
 *
 * Exact match on the deepest node: an ancestor's text contains every
 * descendant's, so "Photo" also matches the whole scroll view, and clicking
 * that hits whatever happens to be under the middle of it.
 */
async function clickLabel(page, label, { timeout = 25000 } = {}) {
  const until = Date.now() + timeout;
  for (;;) {
    const hit = await page.evaluate((wanted) => {
      const nodes = [...document.querySelectorAll('flt-semantics')];
      const exact = nodes.filter((n) =>
        (n.textContent || '').trim() === wanted ||
        (n.getAttribute('aria-label') || '').trim() === wanted);
      if (!exact.length) return false;
      // A tappable node if there is one, else the innermost match.
      const target = exact.find((n) => n.hasAttribute('role')) ||
        exact[exact.length - 1];
      target.click();
      return true;
    }, label);
    if (hit) return;
    if (Date.now() > until) {
      throw new Error(`no semantics node labelled "${label}". Present: ` +
        (await texts(page)).join(' | ').slice(0, 600));
    }
    await page.waitForTimeout(400);
  }
}

/** Wait until some exposed text matches, and return it. */
async function waitForText(page, pattern, { timeout = 90000 } = {}) {
  const until = Date.now() + timeout;
  for (;;) {
    const found = (await texts(page)).find((t) => pattern.test(t));
    if (found) return found;
    if (Date.now() > until) return null;
    await page.waitForTimeout(700);
  }
}

/**
 * Click `toggle` until `reveals` is on screen.
 *
 * An expander is a toggle, and a toggle clicked an even number of times has
 * done nothing. Asserting on what it was supposed to reveal is the only way to
 * know which way it went.
 */
async function expand(page, toggle, reveals, { attempts = 3 } = {}) {
  for (let i = 0; i < attempts; i++) {
    if ((await texts(page)).some((t) => t === reveals)) return;
    await clickLabel(page, toggle);
    await page.waitForTimeout(700);
  }
  if (!(await texts(page)).some((t) => t === reveals)) {
    throw new Error(`"${toggle}" never revealed "${reveals}"`);
  }
}

/**
 * Is the control labelled `label` enabled?
 *
 * Flutter marks a disabled button `aria-disabled="true"`. Returns null when no
 * such control is in the tree, which is a different answer from "disabled" and
 * must not be confused with it.
 */
async function isEnabled(page, label) {
  return page.evaluate((wanted) => {
    for (const n of document.querySelectorAll('flt-semantics')) {
      const own = (n.textContent || '').trim();
      const aria = (n.getAttribute('aria-label') || '').trim();
      if (own === wanted || aria === wanted) {
        return n.getAttribute('aria-disabled') !== 'true';
      }
    }
    return null;
  }, label);
}

module.exports = {
  enableSemantics, texts, clickLabel, waitForText, expand, isEnabled,
};

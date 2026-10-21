// Usage: node docs/tools/phone-shots.mjs <baseUrl> <outDir>
// Viewport-only phone shots (390x844, iPhone 14/15 class): first screen of every page, plus the open menu.
import { chromium, devices } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';
const [base = 'http://localhost:8787', out = 'docs/qa'] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
const page = await ctx.newPage();
for (const p of ['/', '/speaking', '/podcast', '/about', '/book']) {
  await page.goto(base + p, { waitUntil: 'networkidle' });
  await page.waitForTimeout(1800);
  const name = (p === '/' ? 'home' : p.slice(1)) + '-phone-fold.png';
  await page.screenshot({ path: `${out}/${name}`, fullPage: false });
  console.log('fold', p, '->', name);
}
await page.goto(base + '/', { waitUntil: 'networkidle' });
await page.click('.nav-toggle'); await page.waitForTimeout(700);
await page.screenshot({ path: `${out}/home-phone-menu.png`, fullPage: false });
console.log('menu -> home-phone-menu.png');
await browser.close();

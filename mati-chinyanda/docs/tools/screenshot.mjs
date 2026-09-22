// Usage: node docs/tools/screenshot.mjs <baseUrl> <outDir>
// Full-page desktop + mobile screenshots of every page.
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';
const [base = 'http://localhost:8787', out = 'docs/qa'] = process.argv.slice(2);
mkdirSync(out, { recursive: true });
const pages = ['/', '/speaking', '/podcast', '/freeka-runway', '/about', '/book'];
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' }).catch(() => chromium.launch());
for (const [label, vp] of [['desktop', { width: 1440, height: 900 }], ['mobile', { width: 390, height: 844 }]]) {
  const ctx = await browser.newContext({ viewport: vp, deviceScaleFactor: 1, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  for (const p of pages) {
    const url = base + p;
    const res = await page.goto(url, { waitUntil: 'networkidle' }).catch(e => ({ status: () => 'ERR ' + e.message }));
    await page.waitForTimeout(600);
    const name = (p === '/' ? 'home' : p.slice(1)) + '-' + label + '.png';
    await page.screenshot({ path: `${out}/${name}`, fullPage: true });
    console.log(label, p, res.status(), '->', name);
  }
  if (errors.length) console.log(label, 'console errors:', errors);
  await ctx.close();
}
await browser.close();

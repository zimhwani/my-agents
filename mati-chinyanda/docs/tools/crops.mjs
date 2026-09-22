// Viewport-sized crops of sections for design review: node docs/tools/crops.mjs <base> <out>
import { chromium } from '/opt/node22/lib/node_modules/playwright/index.mjs';
const [base = 'http://localhost:8787', out = 'docs/qa/crops'] = process.argv.slice(2);
import { mkdirSync } from 'node:fs'; mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
const shots = [
  ['/', 'section', 'home', { width: 1440, height: 900 }],
  ['/', 'section', 'home-m', { width: 390, height: 844 }],
  ['/speaking', 'section', 'speaking', { width: 1440, height: 900 }],
  ['/podcast', 'section', 'podcast', { width: 1440, height: 900 }],
  ['/freeka-runway', 'section', 'freeka', { width: 1440, height: 900 }],
  ['/about', 'section', 'about', { width: 1440, height: 900 }],
  ['/book', 'section', 'book', { width: 1440, height: 900 }],
];
for (const [path, sel, name, vp] of shots) {
  const ctx = await browser.newContext({ viewport: vp, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  await page.goto(base + path, { waitUntil: 'networkidle' });
  await page.addStyleTag({ content: '.js [data-reveal],.js [data-reveal-stagger]>*{opacity:1!important;transform:none!important}' });
  const els = await page.$$(sel + ', footer');
  let i = 0;
  for (const el of els) { i++; try { await el.scrollIntoViewIfNeeded(); await page.waitForTimeout(150); await el.screenshot({ path: `${out}/${name}-${String(i).padStart(2,'0')}.png` }); } catch (e) { console.log('skip', name, i, e.message.split('\n')[0]); } }
  await ctx.close();
}
await browser.close(); console.log('done');

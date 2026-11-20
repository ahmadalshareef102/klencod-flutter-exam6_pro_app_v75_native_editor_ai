// يلتقط لقطات مرجعية من المنصة الأصلية (دون أي ربط) لمقارنتها بالتطبيق.
// التشغيل: NODE_PATH=/opt/npm-tools/node_modules node tools/baseline_screens.js
const { chromium } = require('playwright');
const path = require('path');
const root = path.resolve(__dirname, '..');
const HTML = 'file://' + path.join(root, 'assets/web/index.html');
const SIZES = [
  { name: 'phone-360x800', width: 360, height: 800, dpr: 2 },
  { name: 'phone-412x915', width: 412, height: 915, dpr: 2 },
  { name: 'tablet-768x1024', width: 768, height: 1024, dpr: 1 },
  { name: 'tablet-1280x800', width: 1280, height: 800, dpr: 1 },
];
const SCREENS = ['home', 'editor', 'preview', 'templates', 'saved', 'settings'];
(async () => {
  const browser = await chromium.launch();
  for (const s of SIZES) {
    const ctx = await browser.newContext({ viewport: { width: s.width, height: s.height }, deviceScaleFactor: s.dpr });
    const page = await ctx.newPage();
    await page.goto(HTML);
    await page.waitForTimeout(500);
    await page.screenshot({ path: `docs/baseline/${s.name}_00-welcome.png` });
    await page.evaluate(() => closeModal('welcome-modal'));
    let n = 1;
    for (const v of SCREENS) {
      await page.evaluate((v) => { if (v === 'preview') openPreview(); else navigateTo(v); }, v);
      await page.waitForTimeout(350);
      await page.screenshot({ path: `docs/baseline/${s.name}_0${n++}-${v}.png` });
    }
    await ctx.close();
  }
  await browser.close();
  console.log('done');
})();

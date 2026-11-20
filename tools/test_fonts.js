const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const HTML = 'file://' + path.join(root, 'assets/web/index.html');
const CSS = fs.readFileSync(path.join(root, 'assets/web/fonts.css'), 'utf8');
const SHIM = fs.readFileSync(path.join(root, 'assets/web/native_shim.js'), 'utf8');
let pass = 0, fail = 0;
const check = (n, c, x = '') => { c ? pass++ : fail++; console.log((c ? 'PASS ' : 'FAIL ') + n + (c ? '' : ' ' + x)); };
(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 915 }, deviceScaleFactor: 2 })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(String(e)));
  await page.addInitScript(() => { window.Exam6Channel = { postMessage: () => {} }; });
  await page.goto(HTML);
  await page.evaluate((css) => { const s = document.createElement('style'); s.id = 'exam6-fonts'; s.textContent = css; document.head.appendChild(s); }, CSS);
  await page.evaluate(SHIM);
  const fams = ['Cairo', 'Tahoma', 'Amiri', 'Mohammad Bold Normal', 'Mohammad Head', 'Mohammad Laha', 'Montserrat'];
  for (const f of fams) {
    const n = await page.evaluate(async (f) => (await document.fonts.load(`700 16px "${f}"`, 'اختبار Abc 123')).length, f);
    check(`الخط ${f} يُحمَّل`, n > 0);
  }
  const opts = await page.evaluate(() => [...document.getElementById('tpl-font').options].map(o => o.textContent));
  check('قائمة الخط تحوي 3 أصلية + 6 مضافة', opts.length === 9, JSON.stringify(opts));
  // اختيار خط مضاف ينعكس على متغير الورقة
  await page.evaluate(() => { navigateTo('templates'); const s = document.getElementById('tpl-font'); s.value = "'Mohammad Head', 'Tahoma', sans-serif"; s.dispatchEvent(new Event('change')); updateDesignSettings(); });
  const ef = await page.evaluate(() => getComputedStyle(document.documentElement).getPropertyValue('--exam-font'));
  check('اختيار Mohammad Head يضبط --exam-font', ef.includes('Mohammad Head'), ef);
  await page.evaluate(() => { currentExam.meta.title = 'اختبار شهر جمادى الأولى للعام 1448هـ'; populateEditorFromState(); openPreview(); });
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'docs/fonts_preview_mohammad_head.png' });
  // عينة مقارنة لكل الخطوط
  await page.setContent(`<html dir=rtl><body style="margin:0;padding:16px;font-size:22px">${fams.map(f => `<div style="font-family:'${f}';font-weight:700;margin:6px 0">${f}: الجمهورية اليمنية – وزارة التربية والتعليم ١٢٣ 123</div>`).join('')}</body></html>`);
  await page.evaluate((css) => { const s = document.createElement('style'); s.textContent = css; document.head.appendChild(s); }, CSS);
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'docs/fonts_sample.png' });
  check('لا أخطاء JS', errs.length === 0, errs.join('|'));
  await b.close();
  console.log(`\nالنتيجة: ${pass} نجاح، ${fail} فشل`);
})();

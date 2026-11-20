// يختبر native_shim.js على المنصة الأصلية في Chromium مع Dart وهمي (ذاكرة).
// التشغيل: NODE_PATH=/opt/npm-tools/node_modules node tools/test_shim.mjs
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const HTML = 'file://' + path.join(root, 'assets/web/index.html');
const SHIM = fs.readFileSync(path.join(root, 'assets/web/native_shim.js'), 'utf8');

// ---- Dart وهمي: نفس عقود الأوامر والتحقق
const store = { exams: new Map(), draft: null };
const log = [];
const ID_RE = /^[A-Za-z0-9_\-]{1,64}$/;
const ALLOWED = new Set(['ping','saveFile','print','exportPdf','dbSave','dbDelete','dbList','dbGet','draftSave','draftGet','nav','toast','confirm']);
function dart(raw) {
  const req = JSON.parse(raw);
  if (!ALLOWED.has(req.action)) return null;
  const p = req.payload || {};
  let res;
  switch (req.action) {
    case 'ping': res = { ok: true }; break;
    case 'saveFile': {
      if (!/\.(doc|json|pdf)$/i.test(p.name || '')) { res = { ok: false, error: 'name' }; break; }
      const bytes = Buffer.from(p.data, 'base64');
      log.push({ action: 'saveFile', name: p.name, bytes });
      res = { ok: true, message: 'تم حفظ الملف' }; break; }
    case 'print': log.push({ action: 'print', html: p.html, title: p.title }); res = { ok: true }; break;
    case 'exportPdf': log.push({ action: 'exportPdf', html: p.html }); res = { ok: true }; break;
    case 'dbSave': {
      if (!ID_RE.test(p.id)) { res = { ok: false }; break; }
      const d = JSON.parse(p.json); if (d.id !== p.id) { res = { ok: false }; break; }
      store.exams.set(p.id, p.json); res = { ok: true }; break; }
    case 'dbDelete': store.exams.delete(p.id); res = { ok: true }; break;
    case 'dbList': res = { ok: true, ids: [...store.exams.keys()] }; break;
    case 'dbGet': res = store.exams.has(p.id) ? { ok: true, json: store.exams.get(p.id) } : { ok: false }; break;
    case 'draftSave': JSON.parse(p.json); store.draft = p.json; res = { ok: true }; break;
    case 'nav': log.push({ action: 'nav', view: p.view }); res = { ok: true }; break;
    case 'draftGet': res = { ok: true, json: store.draft }; break;
  }
  return { id: req.id, res };
}

(async () => {
let pass = 0, fail = 0;
const check = (name, cond, extra = '') => { (cond ? pass++ : fail++); console.log((cond ? 'PASS ' : 'FAIL ') + name + (cond ? '' : '  ' + extra)); };

const browser = await chromium.launch();
async function openPage() {
  const ctx = await browser.newContext({ viewport: { width: 412, height: 915 } });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(String(e)));
  await page.exposeFunction('__dart', (raw) => {
    const out = dart(raw);
    if (!out) return;
    setTimeout(() => page.evaluate(([id, r]) => window.Exam6Native._resolve(id, r), [out.id, JSON.stringify(out.res)]).catch(() => {}), 5);
  });
  await page.addInitScript(() => { window.Exam6Channel = { postMessage: (m) => window.__dart(m) }; });
  await page.goto(HTML);
  await page.evaluate(SHIM);              // يحاكي onPageFinished
  await page.waitForTimeout(400);
  return { ctx, page, errors };
}

// ===== جلسة 1: حفظ اختبار
let { ctx, page, errors } = await openPage();
await page.evaluate(() => navigateTo('editor'));
await page.fill('#meta-title', 'اختبار تجريبي للحفظ');
await page.fill('#meta-subject', 'الرياضيات');
await page.evaluate(() => saveCurrentExam());
await page.waitForTimeout(400);
check('الحفظ ينسخ الاختبار إلى المخزن الداخلي', store.exams.size === 1);
const savedId = [...store.exams.keys()][0];
check('المخزن يحوي العنوان الصحيح', JSON.parse(store.exams.get(savedId)).meta.title === 'اختبار تجريبي للحفظ');

// ===== تصدير Word
await page.evaluate(() => { navigateTo('preview'); exportToWordHTML(); });
await page.waitForTimeout(600);
const word = log.find(l => l.action === 'saveFile' && l.name.endsWith('.doc'));
check('تصدير Word يمر عبر الجسر باسم .doc', !!word, JSON.stringify(log.map(l=>l.action)));
check('ملف Word يبدأ بـ BOM ويحوي العنوان', word && word.bytes.slice(0,3).equals(Buffer.from([0xEF,0xBB,0xBF])) && word.bytes.toString('utf8').includes('اختبار تجريبي للحفظ'));

// ===== نسخة احتياطية
await page.evaluate(() => exportBackup());
await page.waitForTimeout(600);
const bk = log.find(l => l.action === 'saveFile' && l.name.endsWith('.json'));
check('النسخة الاحتياطية JSON صالحة وتحوي الاختبار', bk && JSON.parse(bk.bytes.toString('utf8')).exams.length === 1);

// ===== الطباعة
await page.evaluate(() => { const s=document.getElementById('exam-paper-sheet'); if(s) s.style.zoom='0.5'; window.print(); });
await page.waitForTimeout(400);
const pr = log.find(l => l.action === 'print');
check('الطباعة ترسل HTML بلا سكربتات', pr && !/<script/i.test(pr.html) && pr.html.includes('exam-paper'));
check('الطباعة لا تحمل zoom الشاشة', pr && !/zoom/i.test((pr.html.match(/<div[^>]*id="exam-paper-sheet"[^>]*>/)||[''])[0]));
check('الطباعة تحمل قواعد @media print', pr && pr.html.includes('@media print'));

// ===== مسودة
await page.evaluate(() => navigateTo('editor'));
await page.fill('#meta-title', 'عنوان مسودة لم تُحفظ');
await page.waitForTimeout(3600);
check('المسودة تُحفظ تلقائياً بعد التعديل', store.draft && JSON.parse(store.draft).meta.title === 'عنوان مسودة لم تُحفظ');
check('لا أخطاء JS في الجلسة 1', errors.length === 0, errors.join('|'));
await ctx.close();

// ===== جلسة 2: بيانات WebView ضائعة (IndexedDB فارغ) ← يجب الاسترجاع
({ ctx, page, errors } = await openPage());   // سياق جديد = IndexedDB فارغ
const restored = await page.evaluate(async () => (await dbGetAllExams()).map(e => e.id));
check('استرجاع الاختبار المحفوظ من النسخة الداخلية', restored.includes(savedId), JSON.stringify(restored));
const draftTitle = await page.evaluate(() => currentExam.meta.title);
check('استرجاع آخر مسودة غير محفوظة', draftTitle === 'عنوان مسودة لم تُحفظ', draftTitle);
const inputVal = await page.evaluate(() => document.getElementById('meta-title').value);
check('حقل العنوان يعكس المسودة', inputVal === 'عنوان مسودة لم تُحفظ');

// ===== حذف
await page.evaluate((id) => dbDeleteExam(id), savedId);
await page.waitForTimeout(300);
check('الحذف يُزال من المخزن الداخلي', store.exams.size === 0);
check('لا أخطاء JS في الجلسة 2', errors.length === 0, errors.join('|'));
await ctx.close();

// ===== غلاف أصلي: توجيه navigateTo
({ ctx, page } = await openPage());
await page.evaluate(() => { window.__nativeShell = true; navigateTo('saved'); });
await page.waitForTimeout(300);
check('navigateTo(saved) يُحوَّل إلى Flutter', log.some(l => l.action === 'nav' && l.view === 'saved'));
check('الويب لا ينتقل لواجهة المحفوظات', await page.evaluate(() => document.querySelector('.view-section.active').id !== 'view-saved'));
await page.evaluate(() => navigateTo('editor'));
check('navigateTo(editor) يعمل داخل الويب', await page.evaluate(() => document.querySelector('.view-section.active').id === 'view-editor'));
await ctx.close();

// ===== رفض أوامر غير مسموحة
({ ctx, page } = await openPage());
await page.evaluate(() => { window.__r = null; Exam6Native.call('rm_rf', {}).then(r => { window.__r = r; }); });
await page.waitForTimeout(800);
check('أمر غير مسموح لا يُنفذ ولا يُجاب', (await page.evaluate(() => window.__r)) === null);
await ctx.close();

await browser.close();
console.log(`\nالنتيجة: ${pass} نجاح، ${fail} فشل`);
process.exit(fail ? 1 : 0);

})();

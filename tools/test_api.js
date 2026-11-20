// يختبر Exam6Api (الواجهة البرمجية التي تستخدمها شاشات Flutter) على المنصة الأصلية.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const dart = fs.readFileSync(path.join(root, 'lib/web_shell.dart'), 'utf8');
const CHROME = dart.match(/_chromeScript = r'''([\s\S]*?)''';/)[1];
const SHIM = fs.readFileSync(path.join(root, 'assets/web/native_shim.js'), 'utf8');
const API = fs.readFileSync(path.join(root, 'assets/web/native_api.js'), 'utf8');
const PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
let pass = 0, fail = 0;
const check = (n, c, x = '') => { c ? pass++ : fail++; console.log((c ? 'PASS ' : 'FAIL ') + n + (c ? '' : ' ' + x)); };
(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 915 } })).newPage();
  const errs = [], posted = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.exposeFunction('__post', m => { posted.push(JSON.parse(m)); });
  await page.addInitScript(() => { window.Exam6Channel = { postMessage: m => window.__post(m) }; });
  await page.goto('file://' + path.join(root, 'assets/web/index.html'));
  await page.evaluate(CHROME); await page.evaluate(SHIM); await page.evaluate(API);
  const ev = (code) => page.evaluate(code);
  const J = async (expr) => JSON.parse(await ev(`JSON.stringify(${expr})`));

  let st = await J('Exam6Api.state()');
  check('state: الحقول الأساسية', st.meta.title && st.visibility.footer === true && Array.isArray(st.questions) && st.design.lang === 'ar');
  await ev(`Exam6Api.setMeta('title','عنوان من فلاتر')`);
  await ev(`Exam6Api.setMeta('school','مدرسة النور')`);
  const s2 = await J(`Exam6Api.setMeta('maxscore','50')`);
  st = await J('Exam6Api.state()');
  check('setMeta يعدّل الحالة', st.meta.title === 'عنوان من فلاتر' && st.meta.school === 'مدرسة النور' && st.meta.maxscore === '50' && s2.target === 50);
  await ev(`Exam6Api.setVisibility('bismillah', false)`);
  st = await J('Exam6Api.state()');
  check('setVisibility يعدّل الإظهار', st.visibility.bismillah === false);

  for (const t of ['essay','mcq','tf','fill','match','table','image','image-grid']) await ev(`Exam6Api.addQuestion('${t}')`);
  st = await J('Exam6Api.state()');
  check('إضافة 8 أنواع أسئلة', st.questions.length === 9, st.questions.length);
  check('hasTable للأسئلة الجدولية', st.questions.some(q => q.hasTable));
  await ev(`Exam6Api.setQuestion(1,'name','السؤال الثاني المعدّل')`);
  const s3 = await J(`Exam6Api.setQuestion(1,'score','12.5')`);
  st = await J('Exam6Api.state()');
  check('setQuestion للاسم والدرجة', st.questions[1].name === 'السؤال الثاني المعدّل' && st.questions[1].score === 12.5 && s3.sum >= 12.5);
  const id1 = st.questions[1].id;
  await ev('Exam6Api.move(1,1)');
  st = await J('Exam6Api.state()');
  check('نقل سؤال', st.questions[2].id === id1);
  const n = st.questions.length;
  await ev('Exam6Api.duplicate(0)');
  check('نسخ سؤال', (await J('Exam6Api.state()')).questions.length === n + 1);
  await ev('Exam6Api.remove(0)');
  check('حذف سؤال', (await J('Exam6Api.state()')).questions.length === n);

  const parsed = await J(`Exam6Api.analyzePaste('السؤال الأول: اختر\\nأ- س\\nب- ص\\nالسؤال الثاني: أكمل\\nفراغ')`);
  check('تحليل اللصق', parsed.length === 2 && parsed[0].lines === 2);
  await ev('Exam6Api.confirmPaste()');
  check('إضافة اللصق', (await J('Exam6Api.state()')).questions.length === n + 2);

  // وضع التركيز على سؤال
  st = await J('Exam6Api.state()');
  const qid = st.questions[0].id;
  check('focus', (await J(`Exam6Api.focus('${qid}')`)) === true);
  check('المحرر يطغى على الشاشة', await ev(`(()=>{const r=document.getElementById('rich_ed_${qid}').getBoundingClientRect();return r.width>=410&&r.height>=900;})()`));
  // رياضيات: إدراج رموز وقوالب عند موضع المؤشر
  await page.evaluate((qid) => { const ed = document.getElementById('rich_ed_' + qid); const r = document.createRange(); r.selectNodeContents(ed); r.collapse(false); const s = getSelection(); s.removeAllRanges(); s.addRange(r); }, qid);
  await ev(`Exam6Api.insertHtml('س² ∑ π')`);
  await ev(`Exam6Api.insertHtml('<span style="display:inline-block;vertical-align:middle;text-align:center"><span style="display:block;border-bottom:1.5px solid currentColor">أ</span><span style="display:block">ب</span></span>&nbsp;')`);
  await ev(`Exam6Api.insertHtml('جـ<sup>٢</sup> &radic;')`);
  const mathHtml = await ev(`document.getElementById('rich_ed_${qid}').innerHTML`);
  check('إدراج رمز رياضي', mathHtml.includes('س² ∑ π'));
  check('إدراج كسر بأنماط inline', mathHtml.includes('border-bottom') && mathHtml.includes('1.5px') && mathHtml.includes('inline-block'));
  check('إدراج أس وجذر', mathHtml.includes('<sup>٢</sup>') && mathHtml.includes('√'));
  check('الإدراج يصل إلى حالة الاختبار', (await ev(`currentExam.questions[0].content.includes('س² ∑ π')`)) === true);
  await ev(`Exam6Api.insertTable(3,2,'normal')`);
  check('إدراج جدول', (await ev(`document.getElementById('rich_ed_${qid}').querySelectorAll('table').length`)) >= 1);
  await ev(`Exam6Api.answerLine()`);
  await ev(`Exam6Api.insertImages([{b64:'${PNG}',mime:'image/png'}],'single')`);
  await page.waitForTimeout(800);
  check('إدراج صورة', (await ev(`document.getElementById('rich_ed_${qid}').querySelectorAll('img').length`)) >= 1);
  // تحديد الصورة بنقرة ثم أدوات الصورة
  await page.evaluate((qid) => { const img = document.getElementById('rich_ed_' + qid).querySelector('img'); img.dispatchEvent(new MouseEvent('click', { bubbles: true })); }, qid);
  const sel = await J('Exam6Api.selection()');
  check('تحديد الصورة يُكتشف', sel.img === true, JSON.stringify(sel));
  await ev(`Exam6Api.imgWrap('wrap-front')`); await ev(`Exam6Api.imgSize('50%')`); await ev(`Exam6Api.imgShape('img-rounded')`);
  check('أدوات الصورة تعمل', await ev(`(()=>{const b=document.getElementById('rich_ed_${qid}').querySelector('.img-wrap-box');return !!b&&b.classList.contains('wrap-front')&&b.style.width==='50%';})()`));
  check('سهم على الصورة', (await J(`Exam6Api.imgArrow('⬅️','#dc2626',40,40,'1')`)) === true && (await ev(`document.querySelectorAll('.img-arrow-marker').length`)) >= 1);
  await ev(`Exam6Api.cmd('bold')`); await ev(`Exam6Api.color('#dc2626')`);
  const before = await ev(`currentExam.questions[0].content.length`);
  await ev('Exam6Api.undo()'); await ev('Exam6Api.redo()');
  check('تراجع/إعادة لا يكسران المحرر', (await ev(`currentExam.questions[0].content.length`)) > 0 && before > 0);
  // شريط التنسيق: أوامر على تحديد محفوظ + حالة التنسيق
  await ev(`Exam6Api.insertHtml('<div id="fmt-target">نص للتنسيق</div>')`);
  await page.evaluate(() => { const t = document.getElementById('fmt-target').firstChild; const r = document.createRange(); r.setStart(t, 0); r.setEnd(t, t.length); const s = getSelection(); s.removeAllRanges(); s.addRange(r); });
  await page.evaluate(() => { document.activeElement && document.activeElement.blur(); getSelection().removeAllRanges(); });   // يحاكي فقدان التركيز عند الضغط على زر Flutter
  await ev(`Exam6Api.cmd('bold')`);
  const boldHtml = await ev(`document.getElementById('fmt-target').innerHTML`);
  check('عريض يعمل رغم فقدان التركيز', /<b>|font-weight/.test(boldHtml), boldHtml);
  await ev(`Exam6Api.cmdVal('hiliteColor','#fff176')`);
  const hl = await ev(`document.getElementById('fmt-target').innerHTML`);
  check('تمييز بلون خلفية', /background-color/.test(hl), hl);
  await ev(`Exam6Api.cmd('justifyCenter')`);
  const fs1 = await J('Exam6Api.formatState()');
  check('حالة التنسيق تُقرأ', fs1 && typeof fs1.bold === 'boolean' && fs1.center === true, JSON.stringify(fs1));
  await ev(`Exam6Api.cmd('insertUnorderedList')`);
  check('قائمة نقطية', (await ev(`document.getElementById('rich_ed_${qid}').querySelectorAll('ul li').length`)) >= 1);
  await ev(`Exam6Api.insertHtml('<div style="border:1.5px solid #000;padding:8px">مستطيل</div>&nbsp;')`);
  check('إدراج مستطيل', (await ev(`document.getElementById('rich_ed_${qid}').innerHTML.includes('مستطيل')`)) === true);
  await ev('Exam6Api.unfocus()');
  check('unfocus يزيل التركيز', (await ev(`document.querySelectorAll('.exam6-focused').length`)) === 0);

  // التصميم
  await ev(`Exam6Api.setDesign('fontWeight','400')`); await ev(`Exam6Api.setDesign('lineHeight','1.7')`);
  await ev(`Exam6Api.setDesign('borderColor','#8b4a5e')`); await ev(`Exam6Api.setDesign('tableMode','mode-borderless')`);
  await ev(`Exam6Api.fontSize('15')`);
  const ds = await J('Exam6Api.designState()');
  check('تعديل التصميم', ds.fontWeight === '400' && ds.lineHeight === '1.7' && ds.borderColor === '#8b4a5e' && ds.tableMode === 'mode-borderless' && ds.fontSize === 15, JSON.stringify(ds).slice(0, 200));
  await ev(`Exam6Api.setDesign('fontFamily', "'Cairo', 'Tahoma', sans-serif")`);
  const ds2 = await J('Exam6Api.designState()');
  check('الخط الأصلي المضاف يمر', ds2.fontFamily.includes('Cairo') || ds2.fonts.length >= 3, ds2.fontFamily);
  check('الإعدادات السابقة تبقى بعد تغيير آخر', ds2.fontWeight === '400' && ds2.fontSize === 15);
  await ev(`Exam6Api.setLogo({b64:'${PNG}',mime:'image/png'})`); await ev(`Exam6Api.setWatermark({b64:'${PNG}',mime:'image/png'})`);
  await page.waitForTimeout(800);
  const ds3 = await J('Exam6Api.designState()');
  check('رفع الشعار والعلامة المائية', ds3.logo.startsWith('data:image') && ds3.watermark.startsWith('data:image'));
  await ev('Exam6Api.wmOpacity(12)'); await ev('Exam6Api.wmScale(60)');
  const ds4 = await J('Exam6Api.designState()');
  check('شفافية وتمدد العلامة', ds4.wmOpacity === 12 && ds4.wmScale === 60);
  await ev('Exam6Api.removeLogo()'); await ev('Exam6Api.removeWatermark()');
  const ds5 = await J('Exam6Api.designState()');
  check('حذف الشعار والعلامة', ds5.logo === '' && ds5.watermark === '');

  // إشعارات وتأكيد أصلية
  await ev(`window.__nativeShell=true; showToast('اختبار','warning')`);
  await ev(`showConfirm('عنوان','رسالة',()=>{window.__confirmed=true;})`);
  await page.waitForTimeout(200);
  check('showToast يُحوَّل إلى Flutter', posted.some(m => m.action === 'toast' && m.payload.msg === 'اختبار'));
  check('showConfirm يُحوَّل إلى Flutter', posted.some(m => m.action === 'confirm'));
  const cid = posted.find(m => m.action === 'confirm').id;
  await ev(`window.Exam6Native._resolve('${cid}', JSON.stringify({ok:true,yes:true}))`);
  await page.waitForTimeout(100);
  check('الموافقة تنفّذ الإجراء', await ev('window.__confirmed === true'));

  await ev('Exam6Api.newExam()');
  check('newExam', (await J('Exam6Api.state()')).questions.length <= 1);
  check('لا أخطاء JS', errs.length === 0, errs.join('|'));
  await b.close();
  console.log(`\nالنتيجة: ${pass} نجاح، ${fail} فشل`);
  process.exit(fail ? 1 : 0);
})();

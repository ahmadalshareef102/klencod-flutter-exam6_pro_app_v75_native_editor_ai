// يختبر محلل نص الذكاء الاصطناعي واستيراده وتوزيع الدرجات على المنصة الأصلية.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const dart = fs.readFileSync(path.join(root, 'lib/web_shell.dart'), 'utf8');
const CHROME = dart.match(/_chromeScript = r'''([\s\S]*?)''';/)[1];
let pass = 0, fail = 0;
const check = (n, c, x = '') => { c ? pass++ : fail++; console.log((c ? 'PASS ' : 'FAIL ') + n + (c ? '' : '  ' + x)); };

const STANDARD = `#اختبار
المادة: العلوم
الصف: الخامس الأساسي
الفصل: الفصل الدراسي الأول
العام: 1448هـ
العنوان: اختبار نهاية الفصل
الزمن: 45
الدرجة: 40

#سؤال | نوع=اختيار | درجة=10 | عنوان=اختر الإجابة الصحيحة مما يلي:
1) أي الكواكب أقرب إلى الشمس؟
أ) الزهرة
ب) عطارد
ج) المريخ
د) الأرض
2) يتكون الماء من:
أ) هيدروجين وأكسجين
ب) كربون وأكسجين
ج) نيتروجين وهيدروجين
د) هيليوم وأكسجين

#سؤال | نوع=صح_خطأ | درجة=10 | عنوان=ضع علامة (✓) أو (✕):
1) الشمس نجم (صح)
2) القمر كوكب (خطأ)
3) الماء يغلي عند 100 درجة [صح]

#سؤال | نوع=أكمل | درجة=10 | عنوان=أكمل الفراغات:
1) أكبر كواكب المجموعة الشمسية هو ____
2) يدور القمر حول ......

#سؤال | نوع=توصيل | درجة=10 | عنوان=صل:
1) الأسد = حيوان مفترس
2) الأرنب = حيوان عاشب
3) النسر = طائر جارح

#اجابات
1) ب
2) أ`;

(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 900 } })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(String(e)));
  await page.addInitScript(() => { window.Exam6Channel = { postMessage: () => {} }; });
  await page.goto('file://' + path.join(root, 'assets/web/index.html'));
  await page.evaluate(CHROME);
  for (const f of ['native_shim.js', 'native_api.js']) await page.evaluate(fs.readFileSync(path.join(root, 'assets/web', f), 'utf8'));
  const J = (code, arg) => page.evaluate(([c, a]) => { const f = new Function('a', 'return ' + c); return f(a); }, [code, arg]);

  // 1) الصيغة القياسية
  const s1 = await J('Exam6Api.aiParse(a)', STANDARD);
  check('الصيغة القياسية: 4 أسئلة بأنواعها', s1.questions.map(q => q.type).join() === 'mcq,tf,fill,match', s1.questions.map(q => q.type).join());
  check('عدد الفقرات صحيح', s1.questions[0].items === 2 && s1.questions[1].items === 3 && s1.questions[2].items === 2 && s1.questions[3].items === 3);
  check('بيانات الرأس مقروءة', s1.meta.subject === 'العلوم' && s1.meta.grade === 'الخامس الأساسي' && s1.meta.maxscore === '40' && s1.hasHeader);
  check('قسم الإجابات يُتجاهل', s1.ignored === 2);
  const r1 = await J('Exam6Api.aiImport({replace:true})');
  check('الاستيراد: 4 أسئلة والدرجات متطابقة', r1.added === 4 && r1.sum === 40 && r1.match === true, JSON.stringify(r1));
  const st = await J('Exam6Api.state()');
  check('الرأس انعكس على الاختبار', st.meta.subject === 'العلوم' && st.meta.title === 'اختبار نهاية الفصل' && st.meta.duration.includes('45') && st.meta.maxscore === '40', JSON.stringify(st.meta));
  check('أسماء الأسئلة تلقائية', st.questions[0].name.includes('الأول') && st.questions[1].name.includes('الثاني'), st.questions.map(q => q.name).join('|'));
  check('درجات 10 لكل سؤال (من النص)', st.questions.every(q => q.score === 10));
  const html = await page.evaluate(() => currentExam.questions.map(q => q.content));
  check('الاختيار المتعدد: جدول بأربعة خيارات', (html[0].match(/<td>/g) || []).length === 8 && html[0].includes('أ) الزهرة') && html[0].includes('د) الأرض'), html[0].slice(0, 200));
  check('صح/خطأ: أقواس والإجابات مخفية', html[1].includes('( &nbsp;&nbsp;&nbsp; ) الشمس نجم') && !/\(صح\)|\[صح\]|\(خطأ\)/.test(html[1]) && !html[1].includes('100 درجة [صح]'), html[1]);
  check('أكمل: فراغات منقطة', html[2].includes('أكبر كواكب المجموعة الشمسية هو ............................') && html[2].includes('يدور القمر حول ............................'), html[2]);
  const rights = await page.evaluate(() => { const d = document.createElement('div'); d.innerHTML = currentExam.questions[3].content; return Array.from(d.querySelectorAll('tr')).slice(1).map(tr => tr.cells[2].textContent.replace(/^\S+-\s*/, '').trim()); });
  check('التوصيل: العمود الثاني مخلوط ولا يطابق ترتيب الإجابة', rights.join() !== 'حيوان مفترس,حيوان عاشب,طائر جارح' && rights.length === 3 && new Set(rights).size === 3, rights.join('|'));
  check('عنوان السؤال الفرعي من النص', (await J('currentExam.questions[0].subtitle')).includes('اختر الإجابة'));

  // 2) توزيع تلقائي حين لا توجد درجات
  const NOSCORE = `#اختبار
الدرجة: 30
#سؤال | نوع=مقالي
1) سؤال أول؟
2) سؤال ثانٍ؟
#سؤال | نوع=اختيار
1) س؟
أ) 1
ب) 2
ج) 3
د) 4
2) ص؟
أ) 1
ب) 2
ج) 3
د) 4
3) ع؟
أ) 1
ب) 2
ج) 3
د) 4
4) ل؟
أ) 1
ب) 2
ج) 3
د) 4`;
  await J('Exam6Api.aiParse(a)', NOSCORE);
  const r2 = await J('Exam6Api.aiImport({replace:true,autoScores:true})');
  const sc = await page.evaluate(() => currentExam.questions.map(q => q.score));
  check('توزيع تلقائي بلا درجات يطابق المجموع', r2.sum === 30 && r2.match === true, JSON.stringify(sc));
  check('التوزيع يراعي عدد الفقرات (4 اختيار > 2 مقالي)', sc[1] > sc[0], JSON.stringify(sc));
  // درجات لا تطابق المجموع ← توزيع ذكي
  const WRONG = `#اختبار\nالدرجة: 40\n#سؤال | نوع=مقالي | درجة=7\n1) أ؟\n#سؤال | نوع=مقالي | درجة=9\n1) ب؟`;
  await J('Exam6Api.aiParse(a)', WRONG);
  const r3 = await J('Exam6Api.aiImport({replace:true,autoScores:true})');
  check('درجات النص لا تطابق ← يعاد التوزيع إلى 40', r3.sum === 40, JSON.stringify(r3));
  await J('Exam6Api.aiParse(a)', WRONG);
  const r4 = await J('Exam6Api.aiImport({replace:true,autoScores:false})');
  check('إيقاف التوزيع يحفظ درجات النص كما هي', r4.sum === 16, JSON.stringify(r4));

  // 3) تنسيقات فوضوية: ماركداون، أرقام هندية، خيارات في سطر
  const MESSY = `\`\`\`
**اختبار الرياضيات**
**المادة:** الرياضيات
**الصف:** السادس
### السؤال الأول (10 درجات)
١- ما ناتج ٣ + ٤؟
أ) ٥ ب) ٦ ج) ٧ د) ٨
٢- ما ناتج ٦ × ٧؟
أ) ٣٦ ب) ٤٢ ج) ٤٨ د) ٥٤
**السؤال الثاني: أكمل (10 درجات)**
١) ٥ + ____ = ١٢
٢) ٩ - ____ = ٤
\`\`\``;
  const s3 = await J('Exam6Api.aiParse(a)', MESSY);
  check('فوضوي: تُقرأ الأقسام رغم الماركداون', s3.questions.length === 2 && s3.questions[0].type === 'mcq' && s3.questions[1].type === 'fill', JSON.stringify(s3.questions.map(q => q.type + ':' + q.items)));
  check('خيارات في سطر واحد تُفصل', s3.questions[0].items === 2);
  check('الدرجة من "(10 درجات)"', s3.questions[0].score === 10 && s3.questions[1].score === 10, JSON.stringify(s3.questions.map(q => q.score)));
  check('رأس بصيغة **المادة:**', s3.meta.subject === 'الرياضيات' && s3.meta.grade === 'السادس', JSON.stringify(s3.meta));
  await J('Exam6Api.aiImport({replace:true})');
  const mc = await page.evaluate(() => currentExam.questions[0].content);
  check('اختيار من سطر واحد: أربع خلايا خيارات', (mc.match(/<td>[أبجدهـ]+\) /g) || []).length >= 8, mc.slice(0, 220));

  // 4) نص مسطّح بلا عناوين: توزيع تلقائي على الأنواع
  const FLAT = `1) ما عاصمة اليمن؟
أ) صنعاء
ب) عدن
ج) تعز
د) إب
2) ما أكبر محافظات اليمن؟
أ) حضرموت
ب) المهرة
ج) صعدة
د) مأرب
3) صنعاء عاصمة اليمن ( )
4) البحر الأحمر يقع غرب اليمن ( )
5) يقع اليمن في قارة ____
6) اشرح أهمية الموقع الجغرافي لليمن`;
  const s4 = await J('Exam6Api.aiParse(a)', FLAT);
  check('مسطّح: اكتشاف الأنواع وتجميع المتجاورة', s4.questions.map(q => q.type).join() === 'mcq,tf,fill,essay' && s4.questions[0].items === 2 && s4.questions[1].items === 2, JSON.stringify(s4.questions.map(q => q.type + ':' + q.items)));
  const r5 = await J('Exam6Api.aiImport({replace:true})');
  check('مسطّح: ينشأ اختبار بدرجات متطابقة', r5.added === 4 && r5.match === true, JSON.stringify(r5));

  // 5) جدول + إضافة (بدون استبدال)
  const TBL = `#سؤال | نوع=جدول | درجة=6 | عنوان=أكمل الجدول:\nالعاصمة | الدولة\nصنعاء | اليمن\n | مصر\nالرياض | `;
  const before = await page.evaluate(() => currentExam.questions.length);
  await J('Exam6Api.aiParse(a)', TBL);
  const r6 = await J('Exam6Api.aiImport({replace:false,fillMeta:false})');
  const after = await page.evaluate(() => currentExam.questions.length);
  check('إضافة بلا استبدال', after === before + 1 && r6.added === 1);
  const th = await page.evaluate(() => { const d = document.createElement('div'); d.innerHTML = currentExam.questions[currentExam.questions.length - 1].content; return { th: d.querySelectorAll('th').length, td: d.querySelectorAll('td').length, rows: d.querySelectorAll('tr').length }; });
  check('الجدول: صف عناوين + 3 صفوف', th.th === 2 && th.rows === 4 && th.td === 6, JSON.stringify(th));
  const blocks = await page.evaluate(() => Exam6Api.qGet(currentExam.questions.length - 1).blocks.map(x => x.t).join());
  check('المحتوى المولَّد يُقرأ في المحرر الأصلي (كتل)', blocks.includes('table'), blocks);

  // 6) نص غير صالح
  const s7 = await J('Exam6Api.aiParse(a)', 'مرحباً هذا نص عادي بلا أسئلة');
  check('نص بلا أسئلة: لا أسئلة ولا خطأ', s7.questions.length === 0);
  check('لا أخطاء JS', errs.length === 0, errs.join('|'));
  await b.close();
  console.log(`\nالنتيجة: ${pass} نجاح، ${fail} فشل`);
  process.exit(fail ? 1 : 0);
})();

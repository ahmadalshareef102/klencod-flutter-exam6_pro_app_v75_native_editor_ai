// يختبر محوّل نص السؤال (HTML <-> كتل) على قوالب المنصة الأصلية وحالات منسّقة.
const { chromium } = require('playwright');
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const dart = fs.readFileSync(path.join(root, 'lib/web_shell.dart'), 'utf8');
const CHROME = dart.match(/_chromeScript = r'''([\s\S]*?)''';/)[1];
let pass = 0, fail = 0;
const check = (n, c, x = '') => { c ? pass++ : fail++; console.log((c ? 'PASS ' : 'FAIL ') + n + (c ? '' : '  ' + x)); };
const PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

(async () => {
  const b = await chromium.launch();
  const page = await (await b.newContext({ viewport: { width: 412, height: 900 } })).newPage();
  const errs = []; page.on('pageerror', e => errs.push(String(e)));
  await page.addInitScript(() => { window.Exam6Channel = { postMessage: () => {} }; });
  await page.goto('file://' + path.join(root, 'assets/web/index.html'));
  await page.evaluate(CHROME);
  for (const f of ['native_shim.js', 'native_api.js']) await page.evaluate(fs.readFileSync(path.join(root, 'assets/web', f), 'utf8'));

  // توقيع بنيوي للمقارنة: نص (بلا فراغات) + عدد العناصر + أنماط مهمة
  await page.evaluate(() => {
    window.__sig = (h) => {
      const d = document.createElement('div'); d.innerHTML = h;
      const tags = ['table', 'tr', 'td', 'th', 'img', 'sup', 'sub', 'b', 'i', 'u', 's', 'ul', 'ol', 'li', 'hr'];
      const o = { text: d.textContent.replace(/[\s\u00a0]+/g, '') };
      tags.forEach(t => { o[t] = d.querySelectorAll(t).length; });
      o.border = (h.match(/border-bottom|border-top|border:/g) || []).length;
      o.inline = (h.match(/inline-block/g) || []).length;
      return JSON.stringify(o);
    };
  });
  const roundtrip = async (name, html, tweak) => {
    const r = await page.evaluate((h) => {
      const f = window.__sig; const m = Exam6Api.htmlToBlocks(h); const h2 = Exam6Api.blocksToHtml(m);
      const m2 = Exam6Api.htmlToBlocks(h2); const h3 = Exam6Api.blocksToHtml(m2);
      return { a: f(h), b: f(h2), idem: h2 === h3, blocks: m.blocks.map(x => x.t).join(','), h2 };
    }, html);
    let ok = r.idem;
    const A = JSON.parse(r.a), B = JSON.parse(r.b);
    const diffs = Object.keys(A).filter(k => k !== 'br' && A[k] !== B[k]);
    check(`${name}: تحويل ذهاباً وإياباً دون فقد (${r.blocks})`, ok && diffs.length === 0, `idem=${r.idem} diffs=${diffs.map(k => k + ':' + A[k] + '→' + B[k]).join(' ')}\n${r.h2.slice(0, 300)}`);
    return r;
  };

  // 1) القوالب الثمانية الأصلية
  for (const t of ['essay', 'mcq', 'tf', 'fill', 'match', 'table', 'image', 'image-grid']) {
    const html = await page.evaluate((t) => { addQuestionByType(t); return currentExam.questions[currentExam.questions.length - 1].content; }, t);
    await roundtrip('قالب ' + t, html);
  }
  // 2) تنسيق منوع
  await roundtrip('تنسيق غني', '<div style="text-align:center"><b>عريض</b> و<i>مائل</i> <u>تسطير</u> <s>شطب</s> <span style="color:#dc2626;background-color:#fff176">ملوّن</span> س<sup>2</sup> ص<sub>1</sub> <span style="font-size:1.25em">كبير</span></div><div>سطر ثانٍ</div>');
  await roundtrip('قوائم', '<ul><li>أول</li><li>ثانٍ</li></ul><ol><li>واحد</li><li>اثنان</li></ol>');
  const nested = await page.evaluate(() => { const m = Exam6Api.htmlToBlocks('<ul><li>أول</li><li>ثانٍ<ul><li>فرعي</li></ul></li></ul>'); return { n: m.blocks.length, ind: m.blocks[2].indent, back: Exam6Api.blocksToHtml(m) }; });
  check('قائمة متداخلة: تُسطَّح مع مسافة بادئة', nested.n === 3 && nested.ind === 1 && /فرعي/.test(nested.back), JSON.stringify(nested));
  await roundtrip('كسر وجذر ومجموع (ذرّات)', '<div>س = <span style="display:inline-block;vertical-align:middle;text-align:center"><span style="display:block;border-bottom:1.5px solid currentColor">−ب</span><span style="display:block">٢أ</span></span> &nbsp;<span style="white-space:nowrap">&radic;<span style="border-top:1.5px solid currentColor;padding:0 3px">ب<sup>٢</sup></span></span></div>');
  await roundtrip('صورة مع أسهم', `<div><span class="img-wrap-box wrap-center" contenteditable="false" style="width:50%;position:relative;"><img src="${PNG}" class="exam-img img-rounded" alt="صورة"><span class="img-resize-handle"></span><span class="img-arrow-marker" style="left:30%;top:40%;color:#dc2626;">⬅️<span style="font-size:12px; background:#fff; padding:0 3px; border:1px solid #dc2626; border-radius:3px; margin-inline-start:2px;">أ</span></span></span></div>`);
  await roundtrip('صورة عائمة مع نص', `<div><span class="img-wrap-box wrap-tight-right" contenteditable="false" style="width:30%;"><img src="${PNG}" class="exam-img img-borderless"></span>نص يلتف حول الصورة العائمة</div>`);
  await roundtrip('صورة داخل سطر نصي (ذرّة)', `<div>قبل <span class="img-wrap-box wrap-inline" style="width:10%"><img src="${PNG}" class="exam-img"></span> بعد</div>`);
  await roundtrip('جدول صور (شبكة)', `<table class="borderless-table"><tr><td style="text-align:center"><span class="img-wrap-box wrap-center" style="width:85%"><img src="${PNG}" class="exam-img"></span><div>( &nbsp;&nbsp; )</div></td><td style="text-align:center"><span class="img-wrap-box wrap-center" style="width:85%"><img src="${PNG}" class="exam-img"></span><div>( &nbsp;&nbsp; )</div></td></tr></table><div><br></div>`);
  await roundtrip('مستطيل وخط أفقي', '<div style="border:1.5px solid #000;padding:8px;margin:6px 0">داخل مستطيل</div><hr style="border:0;border-top:1.5px solid #000"><div>بعد</div>');
  await roundtrip('جدول بدمج خلايا', '<table><tr><th colspan="2">عنوان</th></tr><tr><td>أ</td><td>ب</td></tr></table>');
  await roundtrip('جدول متداخل (خام)', '<table><tr><td><table><tr><td>داخل</td></tr></table></td></tr></table>');
  await roundtrip('نص حر ووسوم غريبة', 'نص بلا وسم <b>عريض</b> <custom-tag>x</custom-tag> <div>فقرة</div>');

  // 3) بنية الكتل
  const m = await page.evaluate(() => Exam6Api.htmlToBlocks('<div style="text-align:center"><b>أ</b>ب</div><table><tr><th>ع</th><td>س</td></tr></table>'));
  check('كتلة فقرة بمحاذاة وأنماط', m.blocks[0].t === 'p' && m.blocks[0].align === 'center' && m.blocks[0].runs[0].b === 1);
  check('كتلة جدول بخلايا من كتل', m.blocks[1].t === 'table' && m.blocks[1].rows[0][0].th === 1 && m.blocks[1].rows[0][1].blocks[0].runs[0].x === 'س');
  const im = await page.evaluate((png) => Exam6Api.htmlToBlocks('<div><span class="img-wrap-box wrap-tight-left" style="width:30%"><img src="' + png + '" class="exam-img img-circle"></span>نص</div>'), PNG);
  check('الصورة العائمة كتلة منفصلة + فقرة', im.blocks.length === 2 && im.blocks[0].t === 'img' && im.blocks[0].wrap === 'wrap-tight-left' && im.blocks[0].shape === 'img-circle' && im.blocks[1].t === 'p');
  const em = await page.evaluate(() => Exam6Api.htmlToBlocks('<div><br></div>'));
  check('فقرة فارغة', em.blocks.length === 1 && em.blocks[0].runs.length === 0);

  // 4) qSet / qGet على اختبار حقيقي
  const res = await page.evaluate(() => {
    const idx = 0; const model = Exam6Api.qGet(idx);
    model.blocks.push({ t: 'p', runs: [{ x: 'جديد ', b: 1 }, { x: 'ملون', c: '#dc2626' }], align: 'center' });
    Exam6Api.qSet(idx, model, false);
    const again = Exam6Api.qGet(idx);
    return { html: currentExam.questions[idx].content, n: again.blocks.length, last: again.blocks[again.blocks.length - 1] };
  });
  check('qSet يكتب المحتوى ويقرأ كما كُتب', res.html.includes('جديد') && res.last.align === 'center' && res.last.runs[0].b === 1);
  check('مزامنة نسخة المحرر المخفية', await page.evaluate(() => { const q = currentExam.questions[0]; const ed = document.getElementById('rich_ed_' + q.id); return !ed || ed.innerHTML === q.content; }));

  check('لا أخطاء JS', errs.length === 0, errs.join('|'));
  await b.close();
  console.log(`\nالنتيجة: ${pass} نجاح، ${fail} فشل`);
  process.exit(fail ? 1 : 0);
})();

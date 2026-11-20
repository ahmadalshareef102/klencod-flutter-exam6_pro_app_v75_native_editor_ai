import 'dart:convert';

import 'package:flutter/material.dart';

/// تهريب نص ليُدرج كـ HTML آمناً داخل محرر السؤال.
String esc(String s) => const HtmlEscape().convert(s);

// ---------------------------------------------------------------- قوالب HTML
// كل القوالب بأنماط inline حتى تبقى سليمة في الورقة والطباعة والحفظ.

/// كسر من HTML خام (يسمح بأسس وأدلة داخل البسط/المقام).
String mathFractionHtml(String numHtml, String denHtml) =>
    '<span style="display:inline-block;vertical-align:middle;text-align:center;line-height:1.3;margin:0 3px">'
    '<span style="display:block;padding:0 5px;border-bottom:1.5px solid currentColor">$numHtml</span>'
    '<span style="display:block;padding:0 5px">$denHtml</span></span>';

String mathFraction(String n, String d) => mathFractionHtml(esc(n), esc(d));

String mathPower(String base, String exp) => '${esc(base)}<sup>${esc(exp)}</sup>';

String mathSub(String base, String sub) => '${esc(base)}<sub>${esc(sub)}</sub>';

String mathRootHtml(String radicandHtml, {String? index}) =>
    '<span style="white-space:nowrap">'
    '${index == null || index.trim().isEmpty ? '' : '<sup style="font-size:.65em">${esc(index)}</sup>'}'
    '&radic;<span style="border-top:1.5px solid currentColor;padding:0 3px">$radicandHtml</span></span>';

String mathRoot(String radicand, {String? index}) =>
    mathRootHtml(esc(radicand), index: index);

String mathAbs(String x) => '|${esc(x)}|';

String mathOverline(String x) =>
    '<span style="text-decoration:overline">${esc(x)}</span>';

/// مجموع بحدود (سيجما) فوق/تحت.
String mathSum(String from, String to, String expr) =>
    '<span style="display:inline-block;vertical-align:middle;text-align:center;line-height:1.1;margin:0 3px">'
    '<span style="display:block;font-size:.7em">${esc(to)}</span>'
    '<span style="display:block;font-size:1.5em">&sum;</span>'
    '<span style="display:block;font-size:.7em">${esc(from)}</span></span> ${esc(expr)}';

String mathIntegral(String from, String to, String expr) =>
    '&int;<sub>${esc(from)}</sub><sup>${esc(to)}</sup> ${esc(expr)}';

String mathLimit(String variable, String to, String expr) =>
    'نهـا<sub>${esc(variable)} &rarr; ${esc(to)}</sub> ${esc(expr)}';

String mathLog(String base, String x) => 'لو<sub>${esc(base)}</sub> ${esc(x)}';

// ------------------------------------------------------------------ القوالب

class MathBuilder {
  const MathBuilder(this.title, this.icon, this.fields, this.build, this.preview);

  final String title;
  final IconData icon;
  final List<String> fields;
  final String Function(List<String> v) build;
  final String preview;
}

final List<MathBuilder> kMathBuilders = [
  MathBuilder('كسر', Icons.horizontal_rule, const ['البسط', 'المقام'],
      (v) => mathFraction(v[0], v[1]), 'أ / ب'),
  MathBuilder('أس', Icons.superscript, const ['الأساس', 'الأس'],
      (v) => mathPower(v[0], v[1]), 'س²'),
  MathBuilder('دليل سفلي', Icons.subscript, const ['الرمز', 'الدليل'],
      (v) => mathSub(v[0], v[1]), 'س₁'),
  MathBuilder('جذر تربيعي', Icons.functions, const ['ما تحت الجذر'],
      (v) => mathRoot(v[0]), '√س'),
  MathBuilder('جذر تكعيبي', Icons.functions, const ['ما تحت الجذر'],
      (v) => mathRoot(v[0], index: '٣'), '∛س'),
  MathBuilder('جذر نوني', Icons.functions, const ['الدليل', 'ما تحت الجذر'],
      (v) => mathRoot(v[1], index: v[0]), 'ⁿ√س'),
  MathBuilder('قيمة مطلقة', Icons.straighten, const ['التعبير'],
      (v) => mathAbs(v[0]), '|س|'),
  MathBuilder('قطعة مستقيمة (خط فوق)', Icons.show_chart, const ['الرمز'],
      (v) => mathOverline(v[0]), 'أ‾ب'),
  MathBuilder('مجموع (∑) بحدود', Icons.functions, const ['من', 'إلى', 'التعبير'],
      (v) => mathSum(v[0], v[1], v[2]), '∑'),
  MathBuilder('تكامل محدد', Icons.functions, const ['من', 'إلى', 'التعبير'],
      (v) => mathIntegral(v[0], v[1], v[2]), '∫'),
  MathBuilder('نهاية', Icons.functions, const ['المتغير', 'يقترب من', 'التعبير'],
      (v) => mathLimit(v[0], v[1], v[2]), 'نهـا'),
  MathBuilder('لوغاريتم بأساس', Icons.functions, const ['الأساس', 'العدد'],
      (v) => mathLog(v[0], v[1]), 'لو₂'),
];

/// معادلات وقوانين جاهزة بالرموز العربية.
final List<(String, String)> kMathFormulas = [
  ('المعادلة التربيعية', 'أ س<sup>٢</sup> + ب س + جـ = ٠'),
  (
    'القانون العام',
    'س = ${mathFractionHtml('−ب ± ${mathRootHtml('ب<sup>٢</sup> − ٤ أ جـ')}', '٢ أ')}'
  ),
  ('نظرية فيثاغورس', 'أ<sup>٢</sup> + ب<sup>٢</sup> = جـ<sup>٢</sup>'),
  ('مساحة المستطيل', 'م = الطول × العرض'),
  ('مساحة المثلث', 'م = ${mathFraction('١', '٢')} × القاعدة × الارتفاع'),
  ('مساحة الدائرة', 'م = π نق<sup>٢</sup>'),
  ('محيط الدائرة', 'ح = ٢ π نق'),
  ('حجم الأسطوانة', 'ح = π نق<sup>٢</sup> ع'),
  ('حجم الكرة', 'ح = ${mathFraction('٤', '٣')} π نق<sup>٣</sup>'),
  (
    'ميل المستقيم',
    'م = ${mathFractionHtml('ص<sub>٢</sub> − ص<sub>١</sub>', 'س<sub>٢</sub> − س<sub>١</sub>')}'
  ),
  ('معادلة المستقيم', 'ص = م س + ب'),
  (
    'البعد بين نقطتين',
    'ل = ${mathRootHtml('(س<sub>٢</sub> − س<sub>١</sub>)<sup>٢</sup> + (ص<sub>٢</sub> − ص<sub>١</sub>)<sup>٢</sup>')}'
  ),
  ('المتوسط الحسابي', 'المتوسط = ${mathFraction('مج س', 'ن')}'),
  ('الفائدة البسيطة', 'ف = ${mathFraction('أ × ر × ن', '١٠٠')}'),
  ('المتطابقة المثلثية', 'جا<sup>٢</sup> θ + جتا<sup>٢</sup> θ = ١'),
  ('ظل الزاوية', 'ظا θ = ${mathFraction('جا θ', 'جتا θ')}'),
  ('مربع المجموع', '(أ + ب)<sup>٢</sup> = أ<sup>٢</sup> + ٢ أ ب + ب<sup>٢</sup>'),
  ('مربع الفرق', '(أ − ب)<sup>٢</sup> = أ<sup>٢</sup> − ٢ أ ب + ب<sup>٢</sup>'),
  ('الفرق بين مربعين', 'أ<sup>٢</sup> − ب<sup>٢</sup> = (أ − ب)(أ + ب)'),
  (
    'قانون الجيب',
    '${mathFraction('أ', 'جا أ')} = ${mathFraction('ب', 'جا ب')} = ${mathFraction('جـ', 'جا جـ')}'
  ),
  ('قانون جيب التمام', 'أ<sup>٢</sup> = ب<sup>٢</sup> + جـ<sup>٢</sup> − ٢ ب جـ جتا أ'),
  (
    'تعريف المشتقة',
    'د′(س) = نهـا<sub>هـ &rarr; ٠</sub> ${mathFractionHtml('د(س + هـ) − د(س)', 'هـ')}'
  ),
];

// ------------------------------------------------------------------ الرموز

List<String> _s(String spaced) => spaced.split(' ').where((e) => e.isNotEmpty).toList();

class MathCategory {
  const MathCategory(this.title, this.icon, this.items, {this.wide = false});

  final String title;
  final IconData icon;
  final List<String> items;

  /// عناصر نصية أطول (وحدات ودوال) تُعرض بعرض أكبر.
  final bool wide;
}

final List<MathCategory> kMathCategories = [
  MathCategory('أرقام', Icons.pin_outlined,
      _s('٠ ١ ٢ ٣ ٤ ٥ ٦ ٧ ٨ ٩ ٫ ٬ ٪ ، ؛ ؟ ( ) [ ] { } 0 1 2 3 4 5 6 7 8 9 . ,')),
  MathCategory('متغيرات', Icons.abc,
      _s('س ص ع ل م ن ك ق ز هـ أ ب جـ د ر ط ف ض ح x y z a b c n m')),
  MathCategory('عمليات', Icons.calculate_outlined,
      _s('+ − × ÷ = ≠ ≈ ≡ ± ∓ ⋅ ∘ ∗ ‰ ∝ ‹ ›')),
  MathCategory('مقارنة', Icons.compare_arrows,
      _s('< > ≤ ≥ ≪ ≫ ≮ ≯ ≅ ∼ ≃ ≂ ∥ ⊥')),
  MathCategory('أسس وأدلة', Icons.superscript,
      _s('⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁼ ⁿ ⁱ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₙ ₘ ₓ √ ∛ ∜')),
  MathCategory('كسور', Icons.percent,
      _s('½ ⅓ ⅔ ¼ ¾ ⅕ ⅖ ⅗ ⅘ ⅙ ⅚ ⅐ ⅛ ⅜ ⅝ ⅞ ⅑ ⅒ ⁄ ÷')),
  MathCategory('مجموعات', Icons.bubble_chart_outlined,
      _s('∈ ∉ ∋ ⊂ ⊃ ⊆ ⊇ ⊄ ∪ ∩ ∅ ∖ ∁ ℕ ℤ ℚ ℝ ℂ ℙ ⊕ ⊗ ∀ ∃ ∄')),
  MathCategory('هندسة', Icons.change_history,
      _s('∠ ∡ ∟ ⊥ ∥ ∦ △ □ ▱ ○ ◯ ° ′ ″ ‴ ≅ ∽ ⌒ ⊙ ⊿ ⟂ ↔ ⟶ ⟵ ⇌')),
  MathCategory('تفاضل وتكامل', Icons.timeline,
      _s('∑ ∏ ∫ ∬ ∭ ∮ ∂ ∇ ∆ ∞ ∴ ∵ ⌊ ⌋ ⌈ ⌉ | ‖ ⟨ ⟩ ′ ″ ‰')),
  MathCategory('حروف يونانية', Icons.translate,
      _s('α β γ δ ε ζ η θ ι κ λ μ ν ξ π ρ σ τ υ φ χ ψ ω Γ Δ Θ Λ Ξ Π Σ Φ Ψ Ω')),
  MathCategory('منطق وأسهم', Icons.alt_route,
      _s('∧ ∨ ¬ ⇒ ⇔ → ← ↑ ↓ ↔ ⟹ ⟺ ⊢ ⊨ ✓ ✗ ∴ ∵ ⇄ ↦')),
  MathCategory('دوال', Icons.functions,
      _s('جا جتا ظا قا قتا ظتا جا⁻¹ جتا⁻¹ ظا⁻¹ لو لوₑ نهـا مج د(س) د′(س) د″(س) هـ تفا تكا'),
      wide: true),
  MathCategory('وحدات', Icons.straighten,
      _s('سم م كم ملم سم² م² كم² سم³ م³ ملم² لتر مل جم كجم طن ثانية دقيقة ساعة °م °ف ريال % ‰ ° ′ ″'),
      wide: true),
];

/// تسميات عربية للرموز (تظهر بالضغط المطوّل).
const Map<String, String> kMathNames = {
  '+': 'زائد', '−': 'ناقص', '×': 'ضرب', '÷': 'قسمة', '=': 'يساوي', '≠': 'لا يساوي',
  '≈': 'يساوي تقريباً', '≡': 'مطابق', '±': 'زائد أو ناقص', '∓': 'ناقص أو زائد',
  '<': 'أصغر من', '>': 'أكبر من', '≤': 'أصغر من أو يساوي', '≥': 'أكبر من أو يساوي',
  '≪': 'أصغر بكثير', '≫': 'أكبر بكثير', '∝': 'يتناسب طردياً مع', '≅': 'مطابق (تطابق)',
  '∼': 'مشابه (تشابه)', '∥': 'يوازي', '⊥': 'عمودي على', '∦': 'لا يوازي',
  '√': 'الجذر التربيعي', '∛': 'الجذر التكعيبي', '∜': 'الجذر الرابع',
  '∈': 'ينتمي إلى', '∉': 'لا ينتمي إلى', '∋': 'يحوي', '⊂': 'مجموعة جزئية من',
  '⊃': 'يحوي كمجموعة جزئية', '⊆': 'جزئية أو تساوي', '⊇': 'يحوي أو يساوي',
  '∪': 'اتحاد', '∩': 'تقاطع', '∅': 'المجموعة الخالية', '∖': 'الفرق بين مجموعتين',
  '∁': 'المتممة', 'ℕ': 'الأعداد الطبيعية', 'ℤ': 'الأعداد الصحيحة',
  'ℚ': 'الأعداد النسبية', 'ℝ': 'الأعداد الحقيقية', 'ℂ': 'الأعداد المركبة',
  'ℙ': 'الأعداد الأولية', '∀': 'لكل', '∃': 'يوجد', '∄': 'لا يوجد',
  '∠': 'زاوية', '∡': 'زاوية قياسية', '∟': 'زاوية قائمة', '△': 'مثلث', '□': 'مربع',
  '▱': 'متوازي أضلاع', '○': 'دائرة', '°': 'درجة', '′': 'دقيقة / اشتقاق',
  '″': 'ثانية / اشتقاق ثانٍ', '⌒': 'قوس', '⊙': 'دائرة ومركزها',
  '∑': 'المجموع', '∏': 'حاصل الضرب', '∫': 'التكامل', '∬': 'تكامل ثنائي',
  '∭': 'تكامل ثلاثي', '∮': 'تكامل خطي مغلق', '∂': 'المشتقة الجزئية',
  '∇': 'نابلا (التدرج)', '∆': 'التغير', '∞': 'ما لا نهاية', '∴': 'إذن', '∵': 'لأن',
  '⌊': 'الجزء الصحيح (أرضية)', '⌈': 'سقف',
  'π': 'باي', 'θ': 'ثيتا', 'α': 'ألفا', 'β': 'بيتا', 'γ': 'جاما', 'δ': 'دلتا',
  'λ': 'لامدا', 'μ': 'ميو', 'σ': 'سيجما', 'φ': 'فاي', 'ω': 'أوميجا',
  'Δ': 'دلتا (كبيرة)', 'Σ': 'سيجما (كبيرة)', 'Ω': 'أوميجا (كبيرة)', 'Π': 'باي (كبيرة)',
  '∧': 'و (منطقي)', '∨': 'أو (منطقي)', '¬': 'نفي', '⇒': 'يستلزم', '⇔': 'يكافئ',
  '→': 'سهم لليمين', '←': 'سهم لليسار', '↔': 'سهم باتجاهين',
  'جا': 'جيب الزاوية', 'جتا': 'جيب تمام الزاوية', 'ظا': 'ظل الزاوية',
  'قا': 'قاطع الزاوية', 'قتا': 'قاطع التمام', 'ظتا': 'ظل التمام',
  'لو': 'لوغاريتم', 'لوₑ': 'اللوغاريتم الطبيعي', 'نهـا': 'نهاية', 'مج': 'مجموع',
  'هـ': 'الثابت هـ / عدد أويلر', '٪': 'بالمئة', '‰': 'بالألف',
};

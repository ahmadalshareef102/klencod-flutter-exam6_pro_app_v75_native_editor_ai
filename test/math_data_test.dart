import 'package:exam6_pro_app/math_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('تهريب HTML يمنع حقن الوسوم', () {
    expect(esc('<script>x</script>'), isNot(contains('<script>')));
    expect(mathFraction('<b>', 'ب'), isNot(contains('<b>')));
    expect(mathPower('س', '٢'), 'س<sup>٢</sup>');
    expect(mathSub('س', '١'), 'س<sub>١</sub>');
  });

  test('الكسر والجذر بأنماط inline تصلح للطباعة والحفظ', () {
    final f = mathFraction('أ', 'ب');
    expect(f.contains('border-bottom:1.5px solid currentColor'), isTrue);
    expect(f.contains('<style'), isFalse);
    final r = mathRoot('س', index: '٣');
    expect(r.contains('&radic;'), isTrue);
    expect(r.contains('<sup'), isTrue);
    expect(mathRoot('س').contains('<sup'), isFalse);
  });

  test('القوالب تبني HTML بعدد الحقول الصحيح', () {
    for (final b in kMathBuilders) {
      final out = b.build([for (final _ in b.fields) 'س']);
      expect(out, isNotEmpty, reason: b.title);
    }
    expect(kMathBuilders.length, greaterThanOrEqualTo(10));
  });

  test('الفئات والقوانين غير فارغة ولا تحوي سكربتات', () {
    expect(kMathCategories.length, greaterThanOrEqualTo(10));
    for (final c in kMathCategories) {
      expect(c.items, isNotEmpty, reason: c.title);
    }
    expect(kMathFormulas.length, greaterThanOrEqualTo(15));
    for (final f in kMathFormulas) {
      expect(f.$2.toLowerCase().contains('<script'), isFalse);
    }
    expect(kMathNames['∑'], 'المجموع');
  });

  test('تحتوي الرموز الأرقام العربية والمتغيرات العربية', () {
    final all = kMathCategories.expand((c) => c.items).toSet();
    for (final x in ['٠', '٩', 'س', 'ص', 'ع', 'جـ', '√', '∑', 'π', 'جا', 'جتا', '≤', '∈', '∠']) {
      expect(all.contains(x), isTrue, reason: x);
    }
  });
}

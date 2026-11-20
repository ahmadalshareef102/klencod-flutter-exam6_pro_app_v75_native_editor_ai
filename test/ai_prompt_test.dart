import 'package:exam6_pro_app/ai_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('التعليمات تحمل المعطيات وصيغة الإخراج للأنواع المختارة فقط', () {
    final p = buildAiPrompt(const AiPromptOptions(
      subject: 'العلوم',
      grade: 'الخامس',
      total: 40,
      duration: 45,
      types: {'mcq', 'tf'},
    ));
    expect(p.contains('المادة: العلوم'), isTrue);
    expect(p.contains('الصف: الخامس'), isTrue);
    expect(p.contains('#سؤال | نوع=اختيار | درجة=20'), isTrue);
    expect(p.contains('#سؤال | نوع=صح_خطأ | درجة=20'), isTrue);
    expect(p.contains('نوع=توصيل'), isFalse);
    expect(p.contains('#الإجابات'), isTrue);
    expect(p.contains('الدرجة النهائية: 40'), isTrue);
  });

  test('بلا أنواع مختارة تُستخدم الأنواع الأساسية', () {
    final p = buildAiPrompt(const AiPromptOptions(types: {}));
    expect(p.contains('نوع=اختيار'), isTrue);
    expect(p.contains('نوع=مقالي'), isTrue);
  });
}

/// معطيات بناء تعليمات الذكاء الاصطناعي.
class AiPromptOptions {
  const AiPromptOptions({
    this.subject = '',
    this.grade = '',
    this.semester = '',
    this.lessons = '',
    this.total = 40,
    this.duration = 40,
    this.difficulty = 'متوسط',
    this.types = const {'mcq', 'tf', 'fill', 'essay'},
    this.perQuestion = 5,
    this.english = false,
  });

  final String subject, grade, semester, lessons, difficulty;
  final int total, duration, perQuestion;
  final Set<String> types;
  final bool english;
}

const Map<String, String> kAiTypeNames = {
  'mcq': 'اختيار متعدد',
  'tf': 'صح وخطأ',
  'fill': 'أكمل الفراغات',
  'essay': 'مقالي',
  'match': 'توصيل',
  'table': 'جدول',
};

const Map<String, String> _typeKey = {
  'mcq': 'اختيار',
  'tf': 'صح_خطأ',
  'fill': 'أكمل',
  'essay': 'مقالي',
  'match': 'توصيل',
  'table': 'جدول',
};

const Map<String, String> _typeTitle = {
  'mcq': 'اختر الإجابة الصحيحة مما يلي:',
  'tf': 'ضع علامة (✓) أمام العبارة الصحيحة وعلامة (✕) أمام العبارة الخطأ:',
  'fill': 'أكمل الفراغات الآتية بما يناسبها:',
  'essay': 'أجب عن الأسئلة الآتية:',
  'match': 'صل من العمود (أ) ما يناسبه من العمود (ب):',
  'table': 'أكمل الجدول الآتي:',
};

const Map<String, String> _typeExample = {
  'mcq': '''1) نص السؤال الأول؟
أ) الخيار الأول
ب) الخيار الثاني
ج) الخيار الثالث
د) الخيار الرابع
2) نص السؤال الثاني؟
أ) ...
ب) ...
ج) ...
د) ...''',
  'tf': '''1) عبارة تحتمل الصواب أو الخطأ
2) عبارة أخرى''',
  'fill': '''1) جملة فيها ____ مكان الكلمة الناقصة
2) جملة أخرى فيها ____ ناقص''',
  'essay': '''1) سؤال يحتاج إجابة كتابية؟
2) سؤال آخر؟''',
  'match': '''1) العنصر الأول = ما يناسبه من العمود الثاني
2) العنصر الثاني = ما يناسبه''',
  'table': '''العنوان الأول | العنوان الثاني | العنوان الثالث
قيمة | قيمة | قيمة
قيمة | | ''',
};

/// يبني نص التعليمات الذي يلصقه المستخدم في أي مساعد ذكاء اصطناعي.
String buildAiPrompt(AiPromptOptions o) {
  final types = o.types.isEmpty ? {'mcq', 'tf', 'fill', 'essay'} : o.types;
  final ordered = kAiTypeNames.keys.where(types.contains).toList();
  final per = o.total ~/ ordered.length;
  final b = StringBuffer();
  b.writeln('أنت معلم خبير في إعداد الاختبارات المدرسية. أنشئ اختباراً كاملاً وفق المعطيات الآتية، '
      'والتزم حرفياً بصيغة الإخراج الموضحة بعدها، لأن تطبيقاً سيقرأ النص تلقائياً ويبني الاختبار منه.');
  b.writeln();
  b.writeln('المعطيات:');
  b.writeln('- المادة: ${o.subject.trim().isEmpty ? '(حدّد المادة)' : o.subject.trim()}');
  b.writeln('- الصف: ${o.grade.trim().isEmpty ? '(حدّد الصف)' : o.grade.trim()}');
  if (o.semester.trim().isNotEmpty) b.writeln('- الفصل الدراسي: ${o.semester.trim()}');
  if (o.lessons.trim().isNotEmpty) b.writeln('- الدروس أو الوحدات المشمولة: ${o.lessons.trim()}');
  b.writeln('- الدرجة النهائية: ${o.total}');
  b.writeln('- زمن الاختبار: ${o.duration} دقيقة');
  b.writeln('- مستوى الصعوبة: ${o.difficulty}');
  b.writeln('- أنواع الأسئلة المطلوبة: ${ordered.map((t) => kAiTypeNames[t]).join('، ')}');
  b.writeln('- عدد الفقرات في كل سؤال: ${o.perQuestion}');
  b.writeln('- لغة الاختبار: ${o.english ? 'الإنجليزية' : 'العربية'}');
  b.writeln();
  b.writeln('صيغة الإخراج (التزم بها حرفياً):');
  b.writeln();
  b.writeln('#اختبار');
  b.writeln('المادة: ...');
  b.writeln('الصف: ...');
  b.writeln('الفصل: ...');
  b.writeln('العام: ...');
  b.writeln('العنوان: ...');
  b.writeln('الزمن: ${o.duration} دقيقة');
  b.writeln('الدرجة: ${o.total}');
  for (final t in ordered) {
    b.writeln();
    b.writeln('#سؤال | نوع=${_typeKey[t]} | درجة=$per | عنوان=${_typeTitle[t]}');
    b.writeln(_typeExample[t]);
  }
  b.writeln();
  b.writeln('#الإجابات');
  b.writeln('(اختياري: اكتب هنا نموذج الإجابة للمعلم، سطراً لكل فقرة. سيتجاهله التطبيق ولن يظهر في الورقة.)');
  b.writeln();
  b.writeln('قواعد صارمة:');
  b.writeln('1. ابدأ كل سؤال بسطر يبدأ بـ #سؤال متبوعاً بالخصائص مفصولة بـ | كما في الأمثلة.');
  b.writeln('2. أسماء الأنواع المسموحة فقط: اختيار، صح_خطأ، أكمل، مقالي، توصيل، جدول.');
  b.writeln('3. رقّم الفقرات داخل كل سؤال من 1، ولا تكرر اسم السؤال داخل الفقرات.');
  b.writeln('4. في الاختيار المتعدد: أربعة خيارات (أ ب ج د) ولكل فقرة، ولا تضع الإجابة داخل الفقرة.');
  b.writeln('5. في التوصيل: اكتب العنصر ثم علامة = ثم ما يناسبه (التطبيق يخلط العمود الثاني تلقائياً).');
  b.writeln('6. في الجدول: الصف الأول للعناوين، والخلايا المطلوب إكمالها اتركها فارغة.');
  b.writeln('7. اجعل مجموع درجات الأسئلة يساوي ${o.total} بالضبط.');
  b.writeln('8. لا تستخدم Markdown ولا نجوماً ولا جداول Markdown، ولا تكتب أي شرح أو مقدمة أو خاتمة خارج الصيغة أعلاه.');
  b.writeln('9. الأسئلة مناسبة للصف المذكور ومتنوعة وتغطي المحتوى، وبلا أخطاء إملائية أو علمية.');
  return b.toString();
}

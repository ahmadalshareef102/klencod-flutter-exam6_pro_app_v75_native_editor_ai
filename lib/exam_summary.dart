import 'dart:convert';

/// ملخص خفيف لاختبار محفوظ لعرضه في القوائم.
class ExamSummary {
  const ExamSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.grade,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String subject;
  final String grade;
  final DateTime? updatedAt;
}

/// دالة عليا (تصلح لـ compute). تعيد null إن كان JSON غير صالح.
ExamSummary? parseExamSummary(String json) {
  try {
    final d = jsonDecode(json);
    if (d is! Map) return null;
    final id = d['id'];
    if (id is! String) return null;
    final Map meta = d['meta'] is Map ? d['meta'] as Map : const {};
    String s(Object? v) => v is String ? v : '';
    final u = d['updatedAt'];
    return ExamSummary(
      id: id,
      title: s(meta['title']),
      subject: s(meta['subject']),
      grade: s(meta['grade']),
      updatedAt: u is String ? DateTime.tryParse(u)?.toLocal() : null,
    );
  } catch (_) {
    return null;
  }
}

String formatYmd(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// يحذف «.0» من الأعداد الصحيحة المعروضة.
String fmtNum(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

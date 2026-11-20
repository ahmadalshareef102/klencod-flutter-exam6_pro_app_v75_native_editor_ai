import 'exam_summary.dart';

class Sums {
  const Sums({required this.sum, required this.target, required this.match});
  final double sum;
  final double target;
  final bool match;

  static Sums? fromJson(Object? j) {
    if (j is! Map) return null;
    num n(Object? v) => v is num ? v : 0;
    return Sums(
      sum: n(j['sum']).toDouble(),
      target: n(j['target']).toDouble(),
      match: j['match'] == true,
    );
  }

  String get badge =>
      match ? '✓ متطابق' : 'الفرق: ${fmtNum(double.parse((target - sum).toStringAsFixed(1)))}';
}

class QuestionItem {
  const QuestionItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.score,
    required this.text,
    required this.hasImage,
    required this.hasTable,
  });

  final String id;
  final String name;
  final String subtitle;
  final num score;
  final String text;
  final bool hasImage;
  final bool hasTable;
}

/// حالة شاشة المحرر كما يقرؤها Flutter من محرك المنصة.
class EditorData {
  const EditorData({
    required this.meta,
    required this.visibility,
    required this.lang,
    required this.tableMode,
    required this.pageFit,
    required this.fontSize,
    required this.questions,
    required this.sums,
  });

  final Map<String, String> meta;
  final Map<String, bool> visibility;
  final String lang;
  final String tableMode;
  final String pageFit;
  final double fontSize;
  final List<QuestionItem> questions;
  final Sums sums;

  static EditorData? fromJson(Object? j) {
    if (j is! Map) return null;
    String s(Object? v) => v is String ? v : (v == null ? '' : v.toString());
    final metaIn = j['meta'] is Map ? j['meta'] as Map : const {};
    final visIn = j['visibility'] is Map ? j['visibility'] as Map : const {};
    final designIn = j['design'] is Map ? j['design'] as Map : const {};
    final qs = j['questions'] is List ? j['questions'] as List : const [];
    return EditorData(
      meta: {for (final e in metaIn.entries) s(e.key): s(e.value)},
      visibility: {for (final e in visIn.entries) s(e.key): e.value != false},
      lang: s(designIn['lang']).isEmpty ? 'ar' : s(designIn['lang']),
      tableMode: s(designIn['tableMode']).isEmpty ? 'mode-grid' : s(designIn['tableMode']),
      pageFit: s(designIn['pageFit']).isEmpty ? 'custom' : s(designIn['pageFit']),
      fontSize: designIn['fontSize'] is num ? (designIn['fontSize'] as num).toDouble() : 13.5,
      questions: [
        for (final q in qs.whereType<Map>())
          QuestionItem(
            id: s(q['id']),
            name: s(q['name']),
            subtitle: s(q['subtitle']),
            score: q['score'] is num ? q['score'] as num : 0,
            text: s(q['text']),
            hasImage: q['hasImage'] == true,
            hasTable: q['hasTable'] == true,
          ),
      ],
      sums: Sums.fromJson(j['sums']) ?? const Sums(sum: 0, target: 0, match: false),
    );
  }
}

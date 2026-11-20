import 'package:exam6_pro_app/exam_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ملخص الاختبار من JSON', () {
    final s = parseExamSummary(
        '{"id":"exam_1","updatedAt":"2026-11-15T10:00:00.000Z","meta":{"title":"عنوان","subject":"رياضيات","grade":"الخامس"}}');
    expect(s, isNotNull);
    expect(s!.id, 'exam_1');
    expect(s.title, 'عنوان');
    expect(s.subject, 'رياضيات');
    expect(s.updatedAt, isNotNull);
  });

  test('JSON تالف أو بلا معرّف يعيد null', () {
    expect(parseExamSummary('nope'), isNull);
    expect(parseExamSummary('{"meta":{}}'), isNull);
  });

  test('تنسيق الأعداد والتاريخ', () {
    expect(fmtNum(10.0), '10');
    expect(fmtNum(7.5), '7.5');
    expect(formatYmd(DateTime(2026, 3, 4)), '2026/03/04');
  });
}

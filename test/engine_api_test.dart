import 'package:exam6_pro_app/editor_data.dart';
import 'package:exam6_pro_app/engine_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('فك نتيجة JS بترميز مزدوج (أندرويد)', () {
    expect(decodeJsResult(r'"{\"q\":1}"'), {'q': 1});
    expect(decodeJsResult('{"q":1}'), {'q': 1});
    expect(decodeJsResult('true'), true);
    expect(decodeJsResult('null'), isNull);
    expect(decodeJsResult(null), isNull);
  });

  test('بناء استدعاء Exam6Api يرمّز الوسائط بأمان', () {
    expect(buildApiCall('state', const []), 'JSON.stringify(Exam6Api.state())');
    expect(buildApiCall('setMeta', ['title', 'a"b\n']),
        r'JSON.stringify(Exam6Api.setMeta("title","a\"b\n"))');
    expect(buildApiCall('move', [1, -1]), 'JSON.stringify(Exam6Api.move(1,-1))');
    expect(buildApiCall('setVisibility', ['logo', false]),
        'JSON.stringify(Exam6Api.setVisibility("logo",false))');
  });

  test('تحليل حالة المحرر', () {
    final d = EditorData.fromJson({
      'meta': {'title': 'ت', 'maxscore': '40'},
      'visibility': {'logo': false, 'footer': true},
      'design': {'lang': 'en', 'tableMode': 'mode-grid', 'fontSize': 13.5, 'pageFit': 'fit-1'},
      'questions': [
        {'id': 'q1', 'name': 'س1', 'subtitle': '', 'score': 10, 'text': 'نص', 'hasImage': true, 'hasTable': false}
      ],
      'sums': {'sum': 10, 'target': 40, 'match': false},
    });
    expect(d, isNotNull);
    expect(d!.meta['title'], 'ت');
    expect(d.visibility['logo'], false);
    expect(d.lang, 'en');
    expect(d.questions.single.hasImage, true);
    expect(d.sums.badge, 'الفرق: 30');
    expect(EditorData.fromJson('x'), isNull);
  });

  test('شارة المطابقة', () {
    const s = Sums(sum: 40, target: 40, match: true);
    expect(s.badge, '✓ متطابق');
  });
}

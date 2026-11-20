import 'dart:convert';
import 'dart:io';

import 'package:exam6_pro_app/exam_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late ExamStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('exam_store_test');
    store = ExamStore(tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String exam(String id, String title) =>
      jsonEncode({'id': id, 'meta': {'title': title}});

  test('حفظ وقراءة وقائمة وحذف', () async {
    await store.saveExam('exam_1', exam('exam_1', 'أ'));
    await store.saveExam('exam_2', exam('exam_2', 'ب'));
    expect((await store.listIds())..sort(), ['exam_1', 'exam_2']);
    expect(jsonDecode((await store.readExam('exam_1'))!)['meta']['title'], 'أ');
    await store.deleteExam('exam_1');
    expect(await store.readExam('exam_1'), isNull);
    expect(await store.listIds(), ['exam_2']);
  });

  test('الكتابة فوق اختبار موجود لا تترك ملفات مؤقتة', () async {
    await store.saveExam('exam_1', exam('exam_1', 'قديم'));
    await store.saveExam('exam_1', exam('exam_1', 'جديد'));
    expect(jsonDecode((await store.readExam('exam_1'))!)['meta']['title'],
        'جديد');
    final files = Directory('${tmp.path}/exams').listSync();
    expect(files.where((f) => f.path.endsWith('.tmp')), isEmpty);
  });

  test('رفض معرّفات غير آمنة وعدم تطابق المعرّف وJSON تالف', () async {
    expect(isValidExamId('../x'), isFalse);
    expect(isValidExamId('exam_17000'), isTrue);
    expect(() => store.saveExam('../x', exam('../x', 't')), throwsFormatException);
    expect(() => store.saveExam('exam_1', exam('exam_2', 't')), throwsFormatException);
    expect(() => store.saveExam('exam_1', 'not json'), throwsFormatException);
  });

  test('المسودة', () async {
    expect(await store.readDraft(), isNull);
    await store.saveDraft(exam('exam_9', 'مسودة'));
    expect(jsonDecode((await store.readDraft())!)['id'], 'exam_9');
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

final RegExp _idRe = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

/// معرّف الاختبار يجب أن يكون آمناً كاسم ملف (أحرف وأرقام و_ و- فقط).
bool isValidExamId(String id) => _idRe.hasMatch(id);

/// نسخة داخلية دائمة للاختبارات، ملف JSON لكل اختبار.
/// اخترت الملفات بدل SQLite لأن الاختبار قد يحوي صوراً تتجاوز حد الصف الواحد
/// في SQLite على أندرويد (نحو 2MB للصف عند القراءة).
class ExamStore {
  ExamStore(this.root);

  final Directory root;

  Directory get _exams => Directory('${root.path}/exams');
  File get _draft => File('${root.path}/draft.json');

  Future<void> _atomicWrite(File f, String content) async {
    await f.parent.create(recursive: true);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(content, flush: true);
    await tmp.rename(f.path);
  }

  Map<String, dynamic> _decodeMap(String json) {
    final d = jsonDecode(json);
    if (d is! Map) throw const FormatException('not an object');
    return Map<String, dynamic>.from(d);
  }

  Future<void> saveExam(String id, String json) async {
    if (!isValidExamId(id)) throw const FormatException('bad id');
    final d = _decodeMap(json);
    if (d['id'] != id) throw const FormatException('id mismatch');
    await _atomicWrite(File('${_exams.path}/$id.json'), json);
  }

  Future<String?> readExam(String id) async {
    if (!isValidExamId(id)) return null;
    final f = File('${_exams.path}/$id.json');
    return await f.exists() ? f.readAsString() : null;
  }

  Future<void> deleteExam(String id) async {
    if (!isValidExamId(id)) return;
    final f = File('${_exams.path}/$id.json');
    if (await f.exists()) await f.delete();
  }

  Future<List<String>> listIds() async {
    if (!await _exams.exists()) return const [];
    final ids = <String>[];
    await for (final e in _exams.list()) {
      if (e is! File) continue;
      final name = e.uri.pathSegments.last;
      if (!name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - 5);
      if (isValidExamId(id)) ids.add(id);
    }
    return ids;
  }

  Future<void> saveDraft(String json) async {
    _decodeMap(json);
    await _atomicWrite(_draft, json);
  }

  Future<String?> readDraft() async =>
      await _draft.exists() ? _draft.readAsString() : null;
}

/// مخزن التطبيق الفعلي (نفس المسار تستخدمه طبقة الويب والشاشات الأصلية).
Future<ExamStore> openAppStore() async {
  final dir = await getApplicationSupportDirectory();
  return ExamStore(Directory('${dir.path}/exam_store'));
}

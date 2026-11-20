import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'editor_data.dart';

/// يفك نتيجة runJavaScriptReturningResult (أندرويد يرمّز النصوص مرتين).
Object? decodeJsResult(Object? r) {
  if (r == null) return null;
  Object? d;
  try {
    d = jsonDecode(r.toString());
  } catch (_) {
    return r.toString();
  }
  if (d is String) {
    try {
      return jsonDecode(d);
    } catch (_) {
      return d;
    }
  }
  return d;
}

/// يبني تعبير JS لاستدعاء دالة في Exam6Api بوسائط مرمّزة بأمان.
String buildApiCall(String fn, List<Object?> args) =>
    'JSON.stringify(Exam6Api.$fn(${args.map(jsonEncode).join(',')}))';

/// واجهة Flutter إلى محرك المنصة (Exam6Api في native_api.js).
class EngineApi {
  EngineApi(this._controller);

  final WebViewController? Function() _controller;

  /// يصبح true عند اكتمال تحميل المحرك.
  bool ready = false;

  Future<Object?> call(String fn, [List<Object?> args = const []]) async {
    final c = _controller();
    if (c == null || !ready) return null;
    try {
      return decodeJsResult(
          await c.runJavaScriptReturningResult(buildApiCall(fn, args)));
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _map(String fn, [List<Object?> args = const []]) async {
    final r = await call(fn, args);
    return r is Map ? Map<String, dynamic>.from(r) : null;
  }

  // ---- قراءة
  Future<EditorData?> editorState() async => EditorData.fromJson(await call('state'));
  Future<Map<String, dynamic>?> designState() => _map('designState');
  Future<Map<String, dynamic>?> selection() => _map('selection');

  // ---- بيانات الرأس
  Future<Sums?> setMeta(String key, String value) async =>
      Sums.fromJson(await call('setMeta', [key, value]));
  Future<void> setVisibility(String key, bool on) => call('setVisibility', [key, on]);

  // ---- القوالب والتنسيق
  Future<void> setDesign(String key, String value) => call('setDesign', [key, value]);
  Future<void> fontSize(String v) => call('fontSize', [v]);
  Future<void> syncTableMode(String v) => call('syncTableMode', [v]);
  Future<void> pageFit(String v) => call('pageFit', [v]);
  Future<void> presetBold() => call('presetBold');
  Future<void> presetWatermark() => call('presetWatermark');
  Future<void> toggleLang() => call('toggleLang');
  Future<void> wmOpacity(int v) => call('wmOpacity', [v]);
  Future<void> wmScale(int v) => call('wmScale', [v]);
  Future<void> removeLogo() => call('removeLogo');
  Future<void> removeWatermark() => call('removeWatermark');
  Future<void> setLogo(String b64, String mime) =>
      call('setLogo', [{'b64': b64, 'mime': mime}]);
  Future<void> setWatermark(String b64, String mime) =>
      call('setWatermark', [{'b64': b64, 'mime': mime}]);

  // ---- الأسئلة
  Future<void> addQuestion(String type) => call('addQuestion', [type]);
  Future<void> move(int idx, int dir) => call('move', [idx, dir]);
  Future<void> duplicate(int idx) => call('duplicate', [idx]);
  Future<void> remove(int idx) => call('remove', [idx]);
  Future<Sums?> setQuestion(int idx, String field, Object value) async =>
      Sums.fromJson(await call('setQuestion', [idx, field, value]));
  Future<void> newExam() => call('newExam');

  // ---- محتوى السؤال (محوّل HTML <-> كتل للمحرر الأصلي)
  Future<Map<String, dynamic>?> qGet(int idx) => _map('qGet', [idx]);
  Future<void> qSet(int idx, Map<String, dynamic> model, {bool render = false}) =>
      call('qSet', [idx, model, render]);
  Future<Map<String, dynamic>?> htmlToBlocks(String html) => _map('htmlToBlocks', [html]);

  // ---- اللصق الجماعي
  Future<List<Map<String, dynamic>>> analyzePaste(String text) async {
    final r = await call('analyzePaste', [text]);
    if (r is! List) return const [];
    return r.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> confirmPaste() => call('confirmPaste');

  // ---- الاستيراد الذكي
  Future<Map<String, dynamic>?> aiParse(String text) => _map('aiParse', [text]);
  Future<Map<String, dynamic>?> aiImport(Map<String, dynamic> opts) => _map('aiImport', [opts]);

  // ---- وضع تحرير نص سؤال
  Future<bool> focus(String qid) async => (await call('focus', [qid])) == true;
  Future<void> unfocus() => call('unfocus');
  Future<void> undo() => call('undo');
  Future<void> redo() => call('redo');
  Future<void> cmd(String name) => call('cmd', [name]);
  Future<void> cmdVal(String name, String value) => call('cmdVal', [name, value]);
  Future<Map<String, dynamic>?> formatState() => _map('formatState');
  Future<void> insertHtml(String html) => call('insertHtml', [html]);
  Future<void> color(String hex) => call('color', [hex]);
  Future<void> answerLine() => call('answerLine');
  Future<void> insertTable(int rows, int cols, String style) =>
      call('insertTable', [rows, cols, style]);
  Future<void> insertImages(List<Map<String, String>> items, String mode) =>
      call('insertImages', [items, mode]);
  Future<void> imgWrap(String v) => call('imgWrap', [v]);
  Future<void> imgSize(String v) => call('imgSize', [v]);
  Future<void> imgShape(String v) => call('imgShape', [v]);
  Future<void> imgDelete() => call('imgDelete');
  Future<void> imgClearArrows() => call('imgClearArrows');
  Future<void> imgArrow(String dir, String color, int x, int y, String label) =>
      call('imgArrow', [dir, color, x, y, label]);
  Future<void> tableBorder(String mode) => call('tableBorder', [mode]);
  Future<void> tableOp(String action) => call('tableOp', [action]);

  // ---- الورقة A4
  Future<void> fitPaper() => call('fitPaper');
  Future<void> print() => call('print');
  Future<void> exportWord() => call('exportWord');
}

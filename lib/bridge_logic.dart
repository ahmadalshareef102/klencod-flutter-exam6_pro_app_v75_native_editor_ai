import 'dart:convert';

/// الحد الأقصى لحجم الملف المرسل من الواجهة (عدد أحرف Base64).
const int kMaxBase64Chars = 120 * 1024 * 1024;

/// الحد الأقصى لحجم HTML المرسل للطباعة.
const int kMaxHtmlChars = 60 * 1024 * 1024;

/// الأوامر الوحيدة المسموح بها من الواجهة (قائمة بيضاء).
const Set<String> kAllowedActions = {
  'ping',
  'saveFile',
  'print',
  'exportPdf',
  'dbSave',
  'dbDelete',
  'dbList',
  'dbGet',
  'draftSave',
  'draftGet',
  'nav',
  'toast',
  'confirm',
};

/// الواجهات التي تُعالج أصلياً (تحوّل طلبات navigateTo من الويب إلى Flutter).
const Set<String> kNativeViews = {'home', 'saved', 'settings'};

/// الامتدادات المسموحة للحفظ وأنواعها؛ النوع يُحدد من الامتداد وليس من الواجهة.
const Map<String, String> kMimeByExt = {
  'doc': 'application/msword',
  'json': 'application/json',
  'pdf': 'application/pdf',
};

class BridgeRequest {
  const BridgeRequest(this.id, this.action, this.payload);
  final String id;
  final String action;
  final Map<String, dynamic> payload;
}

/// يحلل رسالة الواجهة؛ يعيد null لأي رسالة غير صالحة أو أمر غير مسموح.
BridgeRequest? parseBridgeMessage(String raw) {
  try {
    final d = jsonDecode(raw);
    if (d is! Map) return null;
    final id = d['id'];
    final action = d['action'];
    final payload = d['payload'];
    if (id is! String || id.isEmpty || id.length > 32) return null;
    if (action is! String || !kAllowedActions.contains(action)) return null;
    return BridgeRequest(
      id,
      action,
      payload is Map ? Map<String, dynamic>.from(payload) : const {},
    );
  } catch (_) {
    return null;
  }
}

/// ينظف اسم الملف: يمنع المسارات والرموز غير الصالحة ويقبل doc/json/pdf فقط.
String? sanitizeFileName(String? raw) {
  final name = (raw ?? '')
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_');
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  final ext = name.substring(dot + 1).toLowerCase();
  if (!kMimeByExt.containsKey(ext)) return null;
  var base = name.substring(0, dot).replaceAll(RegExp(r'^\.+'), '').trim();
  if (base.isEmpty) base = 'Exam';
  if (base.length > 80) base = base.substring(0, 80);
  return '$base.$ext';
}

String mimeForFileName(String safeName) =>
    kMimeByExt[safeName.substring(safeName.lastIndexOf('.') + 1)] ??
    'application/octet-stream';

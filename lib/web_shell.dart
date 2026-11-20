import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'bridge_logic.dart';
import 'exam_store.dart';
import 'file_delivery.dart';

/// مسار صفحة المنصة الأصلية داخل assets (نسخة طبق الأصل من Exam6_Pro_VIP.html).
const String kPlatformAsset = 'assets/web/index.html';
const String kShimAsset = 'assets/web/native_shim.js';
const String kFontsAsset = 'assets/web/fonts.css';
const String kApiAsset = 'assets/web/native_api.js';

/// يسمح فقط بالمحتوى المحلي؛ أي رابط خارجي يُمنع داخل التطبيق.
bool isAllowedUrl(String url) {
  return url.startsWith('file://') ||
      url.startsWith('about:') ||
      url.startsWith('data:') ||
      url.startsWith('blob:');
}

bool isExternalLink(String url) =>
    url.startsWith('https://') || url.startsWith('http://');

/// يخفي هيدر الويب وشريطه السفلي (يحل محلهما الواجهة الأصلية) ويعلّم الصفحة أنها داخل غلاف أصلي.
const String _chromeScript = r'''
(function(){
  window.__nativeShell = true;
  if (!document.getElementById('exam6-native-chrome')) {
    var s = document.createElement('style');
    s.id = 'exam6-native-chrome';
    s.textContent = 'header.app-header,nav.mobile-bottom-nav{display:none!important}body{padding-bottom:0!important}'
      + '.view-section{animation:none!important;transform:none!important}'
      + '#view-preview>.card.no-print:first-child{display:none!important}'
      + '.rich-editor.exam6-focused{position:fixed!important;top:0!important;left:0!important;right:0!important;bottom:0!important;'
      + 'z-index:900!important;margin:0!important;border:0!important;border-radius:0!important;overflow:auto!important;'
      + 'background:#fff!important;padding:14px!important;box-sizing:border-box!important;min-height:100%!important;'
      + 'max-height:none!important;font-size:17px!important}';
    document.head.appendChild(s);
  }
  try { localStorage.setItem('exam_designer_v70_welcomed', '1'); } catch (e) {}
  var m = document.getElementById('welcome-modal');
  if (m) m.classList.remove('open');
})();
''';

/// محرك المنصة: WebView محلي يشغّل الصفحة الأصلية + الجسر. تتحكم به الواجهة الأصلية.
class WebShell extends StatefulWidget {
  const WebShell({
    super.key,
    required this.onController,
    required this.onNavigate,
    required this.onToast,
    required this.onConfirm,
    this.onLoaded,
  });

  /// يُستدعى مرة واحدة عند إنشاء المتحكم (دون setState).
  final void Function(WebViewController controller) onController;

  /// طلب انتقال إلى واجهة أصلية: home أو saved أو settings.
  final void Function(String view) onNavigate;

  /// إشعار قصير من المنصة (بدل toast الويب).
  final void Function(String message, String type) onToast;

  /// نافذة تأكيد أصلية بدل نافذة الويب.
  final Future<bool> Function(String title, String message) onConfirm;

  /// بعد اكتمال تحميل الصفحة وحقن الطبقات.
  final VoidCallback? onLoaded;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  late final WebViewController _controller;
  late final Future<String> _shim;
  late final Future<String> _fonts;
  late final Future<String> _api;
  late final Future<ExamStore> _store = openAppStore();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _shim = rootBundle.loadString(kShimAsset);
    _fonts = rootBundle.loadString(kFontsAsset);
    _api = rootBundle.loadString(kApiAsset);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFBF7EE))
      ..enableZoom(false)
      ..addJavaScriptChannel('Exam6Channel',
          onMessageReceived: (m) => _onMessage(m.message))
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          if (isAllowedUrl(request.url)) return NavigationDecision.navigate;
          if (isExternalLink(request.url)) _openExternal(request.url);
          return NavigationDecision.prevent;
        },
        onPageFinished: (_) async {
          await _controller.runJavaScript(_chromeScript);
          await _controller.runJavaScript(
              '(function(){if(document.getElementById("exam6-fonts"))return;'
              'var s=document.createElement("style");s.id="exam6-fonts";'
              's.textContent=${jsonEncode(await _fonts)};'
              'document.head.appendChild(s);})();');
          await _controller.runJavaScript(await _shim);
          await _controller.runJavaScript(await _api);
          if (mounted) setState(() => _loaded = true);
          widget.onLoaded?.call();
        },
      ))
      ..loadFlutterAsset(kPlatformAsset);

    // نافذة اختيار الملفات لعناصر <input type="file"> (الصور، الشعار، الاستعادة).
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      platform.setOnShowFileSelector(_onShowFileSelector);
    }
    widget.onController(_controller);
  }

  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    try {
      final multiple = params.mode == FileSelectorMode.openMultiple;
      final types = params.acceptTypes.map((t) => t.toLowerCase()).toList();
      final wantsJson = types.any((t) => t.contains('json'));
      final wantsImage = types.any((t) => t.startsWith('image'));
      final res = await FilePicker.platform.pickFiles(
        type: wantsJson
            ? FileType.custom
            : (wantsImage ? FileType.image : FileType.any),
        allowedExtensions: wantsJson ? const ['json'] : null,
        allowMultiple: multiple,
      );
      if (res == null) return const [];
      return res.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- الجسر

  Future<void> _onMessage(String raw) async {
    final req = parseBridgeMessage(raw);
    if (req == null) return; // رسالة غير موثوقة تُتجاهل
    Map<String, dynamic> result;
    try {
      switch (req.action) {
        case 'ping':
          result = {'ok': true};
        case 'saveFile':
          result = await _handleSaveFile(req.payload);
        case 'print':
          result = await _handlePrint(req.payload);
        case 'exportPdf':
          result = await _handleExportPdf(req.payload);
        case 'dbSave':
          result = await _handleDbSave(req.payload);
        case 'dbDelete':
          result = await _handleDbDelete(req.payload);
        case 'dbList':
          result = {'ok': true, 'ids': await (await _store).listIds()};
        case 'dbGet':
          result = await _handleDbGet(req.payload);
        case 'draftSave':
          result = await _handleDraftSave(req.payload);
        case 'draftGet':
          result = {'ok': true, 'json': await (await _store).readDraft()};
        case 'nav':
          final view = req.payload['view'];
          if (view is String && kNativeViews.contains(view)) {
            widget.onNavigate(view);
            result = {'ok': true};
          } else {
            result = {'ok': false, 'error': 'واجهة غير معروفة'};
          }
        case 'toast':
          final msg = req.payload['msg'];
          final type = req.payload['type'];
          if (msg is String && msg.length <= 300) {
            widget.onToast(msg, type is String ? type : 'success');
          }
          result = {'ok': true};
        case 'confirm':
          final t = req.payload['title'];
          final m = req.payload['message'];
          if (t is String && m is String && t.length <= 200 && m.length <= 600) {
            result = {'ok': true, 'yes': await widget.onConfirm(t, m)};
          } else {
            result = {'ok': false, 'error': 'طلب غير صالح'};
          }
        default:
          result = {'ok': false, 'error': 'أمر غير مدعوم'};
      }
    } catch (_) {
      result = {'ok': false, 'error': 'تعذر تنفيذ العملية'};
    }
    await _reply(req.id, result);
  }

  Future<void> _reply(String id, Map<String, dynamic> result) async {
    if (!mounted) return;
    final js = 'window.Exam6Native && window.Exam6Native._resolve('
        '${jsonEncode(id)}, ${jsonEncode(jsonEncode(result))});';
    await _controller.runJavaScript(js);
  }

  Future<Map<String, dynamic>> _handleSaveFile(
      Map<String, dynamic> payload) async {
    final name = sanitizeFileName(payload['name'] as String?);
    final data = payload['data'];
    if (name == null) return {'ok': false, 'error': 'اسم الملف غير مسموح'};
    if (data is! String || data.isEmpty) {
      return {'ok': false, 'error': 'الملف فارغ'};
    }
    if (data.length > kMaxBase64Chars) {
      return {'ok': false, 'error': 'الملف كبير جداً'};
    }
    final Uint8List bytes;
    try {
      bytes = base64Decode(data);
    } on FormatException {
      return {'ok': false, 'error': 'بيانات الملف غير صالحة'};
    }
    if (!mounted) return {'ok': false, 'error': 'التطبيق غير جاهز'};
    return deliverFile(context, bytes, name);
  }

  String? _htmlOf(Map<String, dynamic> payload) {
    final html = payload['html'];
    if (html is! String || html.isEmpty || html.length > kMaxHtmlChars) {
      return null;
    }
    return html;
  }

  Future<Map<String, dynamic>> _handlePrint(
      Map<String, dynamic> payload) async {
    final html = _htmlOf(payload);
    if (html == null) return {'ok': false, 'error': 'محتوى الطباعة غير صالح'};
    final title = (payload['title'] as String?) ?? 'Exam';
    // نافذة طباعة أندرويد تتضمن خيار «حفظ كملف PDF».
    await Printing.layoutPdf(
      name: title,
      format: PdfPageFormat.a4,
      onLayout: (format) => Printing.convertHtml(format: format, html: html),
    );
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _handleExportPdf(
      Map<String, dynamic> payload) async {
    final html = _htmlOf(payload);
    if (html == null) return {'ok': false, 'error': 'محتوى PDF غير صالح'};
    final title = (payload['title'] as String?) ?? 'Exam';
    final bytes =
        await Printing.convertHtml(format: PdfPageFormat.a4, html: html);
    if (!mounted) return {'ok': false, 'error': 'التطبيق غير جاهز'};
    return deliverFile(
        context, bytes, sanitizeFileName('$title.pdf') ?? 'Exam.pdf');
  }

  // ------------------------------------------------ التخزين الدائم (المرحلة 4)

  String? _jsonOf(Map<String, dynamic> payload) {
    final json = payload['json'];
    if (json is! String || json.isEmpty || json.length > kMaxHtmlChars) {
      return null;
    }
    return json;
  }

  Future<Map<String, dynamic>> _handleDbSave(
      Map<String, dynamic> payload) async {
    final id = payload['id'];
    final json = _jsonOf(payload);
    if (id is! String || !isValidExamId(id) || json == null) {
      return {'ok': false, 'error': 'بيانات الاختبار غير صالحة'};
    }
    await (await _store).saveExam(id, json);
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _handleDbDelete(
      Map<String, dynamic> payload) async {
    final id = payload['id'];
    if (id is! String || !isValidExamId(id)) {
      return {'ok': false, 'error': 'معرّف غير صالح'};
    }
    await (await _store).deleteExam(id);
    return {'ok': true};
  }

  Future<Map<String, dynamic>> _handleDbGet(
      Map<String, dynamic> payload) async {
    final id = payload['id'];
    if (id is! String || !isValidExamId(id)) {
      return {'ok': false, 'error': 'معرّف غير صالح'};
    }
    final json = await (await _store).readExam(id);
    return json == null
        ? {'ok': false, 'error': 'غير موجود'}
        : {'ok': true, 'json': json};
  }

  Future<Map<String, dynamic>> _handleDraftSave(
      Map<String, dynamic> payload) async {
    final json = _jsonOf(payload);
    if (json == null) return {'ok': false, 'error': 'مسودة غير صالحة'};
    await (await _store).saveDraft(json);
    return {'ok': true};
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (!_loaded) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

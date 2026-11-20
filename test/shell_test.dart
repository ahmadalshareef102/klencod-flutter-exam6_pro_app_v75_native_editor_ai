import 'dart:io';

import 'package:exam6_pro_app/bridge_logic.dart';
import 'package:exam6_pro_app/web_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الصفحة الأصلية موجودة وتحتوي عنوان المنصة', () {
    final text = File(kPlatformAsset).readAsStringSync();
    expect(text.contains('V7.0 Pro Max'), isTrue);
    expect(text.contains('YemenExamDesignerV70DB'), isTrue);
  });

  test('ملف الربط موجود ويعرّف القناة والطباعة والتحميل', () {
    final js = File(kShimAsset).readAsStringSync();
    expect(js.contains('Exam6Channel'), isTrue);
    expect(js.contains('window.print'), isTrue);
    expect(js.contains('createObjectURL'), isTrue);
  });

  test('ملف الخطوط موجود ويعرّف بدائل Tahoma وAmiri والخطوط المرفوعة', () {
    final css = File(kFontsAsset).readAsStringSync();
    for (final f in ['Tahoma', 'Amiri', 'Cairo', 'Mohammad Head', 'Montserrat']) {
      expect(css.contains("font-family:'$f'"), isTrue, reason: f);
    }
  });

  test('ملف واجهة المحرك موجود ويعرّف Exam6Api', () {
    final js = File(kApiAsset).readAsStringSync();
    expect(js.contains('window.Exam6Api'), isTrue);
    for (final fn in ['state', 'designState', 'focus', 'insertImages', 'analyzePaste']) {
      expect(js.contains('$fn:'), isTrue, reason: fn);
    }
  });

  test('منع الروابط الخارجية والسماح بالمحلي', () {
    expect(
        isAllowedUrl(
            'file:///android_asset/flutter_assets/assets/web/index.html'),
        isTrue);
    expect(isAllowedUrl('https://chat.whatsapp.com/x'), isFalse);
    expect(isExternalLink('https://chat.whatsapp.com/x'), isTrue);
  });

  test('تحليل رسائل الجسر: قائمة بيضاء وتحقق من الحقول', () {
    expect(parseBridgeMessage('{"id":"r1","action":"ping"}')?.action, 'ping');
    expect(parseBridgeMessage('{"id":"r1","action":"deleteAll"}'), isNull);
    expect(parseBridgeMessage('{"action":"ping"}'), isNull);
    expect(parseBridgeMessage('not json'), isNull);
  });

  test('تنظيف أسماء الملفات', () {
    expect(sanitizeFileName('الرياضيات.doc'), 'الرياضيات.doc');
    expect(sanitizeFileName('../../etc/passwd.json'), isNot(contains('/')));
    expect(sanitizeFileName('../../etc/passwd.json'), endsWith('.json'));
    expect(sanitizeFileName('a.exe'), isNull);
    expect(sanitizeFileName('noext'), isNull);
    expect(sanitizeFileName('.json'), isNull);
    expect(mimeForFileName('x.pdf'), 'application/pdf');
  });
}

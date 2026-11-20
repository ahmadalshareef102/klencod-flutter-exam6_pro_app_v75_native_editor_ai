import 'package:exam6_pro_app/editor/rich_model.dart';
import 'package:exam6_pro_app/screens/question_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('تنسيق التحديد يُصدَّر كمقاطع runs', () {
    final c = RichController();
    c.value = const TextEditingValue(text: 'abcdef', selection: TextSelection.collapsed(offset: 6));
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    c.toggleBold();
    final runs = c.toRuns();
    expect(runs.length, 3);
    expect(runs[0]['x'], 'a');
    expect(runs[1]['x'], 'bc');
    expect(runs[1]['b'], 1);
    expect(runs[2]['x'], 'def');
    expect(runs[2].containsKey('b'), isFalse);
  });

  test('الحرف المكتوب بعد نص عريض يرث التنسيق', () {
    final c = RichController();
    c.value = const TextEditingValue(text: 'abcdef', selection: TextSelection.collapsed(offset: 6));
    c.selection = const TextSelection(baseOffset: 1, extentOffset: 3);
    c.toggleBold();
    c.value = const TextEditingValue(text: 'abcXdef', selection: TextSelection.collapsed(offset: 4));
    final runs = c.toRuns();
    expect(runs[1]['x'], 'bcX');
    expect(runs[1]['b'], 1);
  });

  test('حذف نص يزيل تنسيقه ويبقي الباقي', () {
    final c = RichController();
    c.loadRuns([
      {'x': 'ab', 'b': 1},
      {'x': 'cd'},
    ]);
    c.value = const TextEditingValue(text: 'bcd', selection: TextSelection.collapsed(offset: 0));
    final runs = c.toRuns();
    expect(runs[0]['x'], 'b');
    expect(runs[0]['b'], 1);
    expect(runs[1]['x'], 'cd');
  });

  test('العناصر المدمجة تُدرج بترتيبها', () {
    final c = RichController();
    c.loadRuns([
      {'x': 'س'}
    ]);
    c.selection = const TextSelection.collapsed(offset: 1);
    c.insertAtom('<span>A</span>', 'A');
    c.insertAtom('<span>B</span>', 'B');
    final runs = c.toRuns();
    expect(runs.length, 3);
    expect(runs[1]['atom'], '<span>A</span>');
    expect(runs[2]['atom'], '<span>B</span>');
    expect(c.text.length, 3);
  });

  test('تحميل runs ثم تصديرها يعطي النتيجة نفسها', () {
    final src = [
      {'x': 'نص ', 'i': 1},
      {'x': 'ملون', 'c': '#dc2626', 'bg': '#fff176', 'sz': 'lg'},
      {'atom': '<span>½</span>', 'label': '½'},
      {'x': ' س', 'sup': 1},
    ];
    final c = RichController()..loadRuns(src);
    final out = c.toRuns();
    expect(out.length, 4);
    expect(out[1]['c'], '#dc2626');
    expect(out[1]['sz'], 'lg');
    expect(out[2]['label'], '½');
    expect(out[3]['sup'], 1);
  });

  test('نموذج الكتل: فقرة وجدول وصورة تُحفظ وتُقرأ', () {
    final p = ParaBlock(align: 'center', list: 'ol', indent: 1);
    p.c.loadRuns([
      {'x': 'بند', 'b': 1}
    ]);
    final t = TableBlock.create(2, 3, 'borderless-table');
    final img = ImageBlock(
      src: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      w: '50%',
      wrap: 'wrap-tight-right',
      shape: 'img-rounded',
      arrows: [ArrowSpec(dir: '⬅️', color: '#dc2626', x: 30, y: 40, label: 'أ')],
    );
    final json = blocksToJson([p, t, img]);
    final back = blocksFromJson(json);
    expect(back.length, 3);
    final p2 = back[0] as ParaBlock;
    expect(p2.align, 'center');
    expect(p2.list, 'ol');
    expect(p2.indent, 1);
    expect(p2.c.toRuns().first['b'], 1);
    final t2 = back[1] as TableBlock;
    expect(t2.rows.length, 2);
    expect(t2.colCount, 3);
    expect(t2.borderless, isTrue);
    final i2 = back[2] as ImageBlock;
    expect(i2.widthFactor, 0.5);
    expect(i2.arrows.single.label, 'أ');
    expect(i2.bytes, isNotNull);
  });

  test('فك كيانات HTML للرموز المدرجة', () {
    expect(decodeHtmlText('a&lt;b &amp; c&nbsp;d'), 'a<b & c\u00A0d');
    expect(decodeHtmlText('&#8721; &#x2211;'), '∑ ∑');
  });
}

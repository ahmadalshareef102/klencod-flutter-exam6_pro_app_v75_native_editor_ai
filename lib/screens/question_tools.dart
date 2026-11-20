import 'dart:async';

import 'package:flutter/material.dart';

import '../editor/rich_actions.dart';
import '../math_data.dart';
import '../theme.dart';
import 'math_sheet.dart';

class _Tool {
  const _Tool(this.label, this.run, {this.icon, this.glyph, this.stateKey});

  final String label;
  final FutureOr<void> Function() run;
  final IconData? icon;

  /// نص يظهر بدل الأيقونة (رموز رياضية وأحجام).
  final String? glyph;

  /// مفتاح حالة التنسيق لتظليل الزر عند تفعيله.
  final String? stateKey;
}

class _Group {
  const _Group(this.title, this.tools);
  final String title;
  final List<_Tool> tools;
}

class _TabDef {
  const _TabDef(this.title, this.groups);
  final String title;
  final List<_Group> groups;
}

/// شريط أدوات تحرير نص السؤال: تبويبات (الرئيسية، تنسيق، إدراج، رياضيات، جدول، صورة)
/// بمجموعات بعناوين، يُطوى بسهم، وتُظلَّل فيه الأدوات النشطة عند المؤشر.
/// ينتقل تلقائياً إلى «صورة» أو «جدول» عند تحديد أحدهما.
class QuestionRibbon extends StatefulWidget {
  const QuestionRibbon({super.key, required this.actions});

  final RichActions actions;

  @override
  State<QuestionRibbon> createState() => _QuestionRibbonState();
}

class _QuestionRibbonState extends State<QuestionRibbon> {
  static const int _tableTab = 4, _imageTab = 5;

  int _tab = 0;
  bool _open = true;
  String? _lastKind;

  RichActions get a => widget.actions;

  @override
  void initState() {
    super.initState();
    a.revision.addListener(_onRev);
  }

  @override
  void dispose() {
    a.revision.removeListener(_onRev);
    super.dispose();
  }

  void _onRev() {
    final kind = a.hasImage ? 'image' : (a.hasTable ? 'table' : null);
    if (kind != _lastKind) {
      _lastKind = kind;
      if (kind == 'image') _tab = _imageTab;
      if (kind == 'table') _tab = _tableTab;
      if (kind == null && (_tab == _imageTab || _tab == _tableTab)) _tab = 0;
      _open = true;
    }
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- التبويبات

  List<_TabDef> _tabs() {
    MathBuilder mb(String title) => kMathBuilders.firstWhere((b) => b.title == title);
    Future<void> ins(String h) => a.insertHtml(h);
    const quick = [
      '±', '×', '÷', '≠', '≈', '≤', '≥', 'π', '∞', '°', '∠', '⊥', '∥', '△', '∈', '∪', '∩', '∴', '⇒', '٪',
    ];
    return [
      _TabDef('الرئيسية', [
        _Group('التراجع', [
          _Tool('تراجع', a.undo, icon: Icons.undo),
          _Tool('إعادة', a.redo, icon: Icons.redo),
        ]),
        _Group('الحافظة', [
          _Tool('لصق', a.paste, icon: Icons.content_paste),
          _Tool('نسخ', () async => a.copy(), icon: Icons.copy_outlined),
          _Tool('قص', () async => a.cut(), icon: Icons.content_cut),
          _Tool('تحديد الكل', () async => a.selectAll(), icon: Icons.select_all),
          _Tool('حذف', () async => a.deleteSelection(), icon: Icons.backspace_outlined),
        ]),
        _Group('الخط', [
          _Tool('عريض', () async => a.toggle('bold'), icon: Icons.format_bold, stateKey: 'bold'),
          _Tool('مائل', () async => a.toggle('italic'), icon: Icons.format_italic, stateKey: 'italic'),
          _Tool('تسطير', () async => a.toggle('underline'),
              icon: Icons.format_underlined, stateKey: 'underline'),
          _Tool('شطب', () async => a.toggle('strike'),
              icon: Icons.strikethrough_s, stateKey: 'strike'),
          _Tool('لون النص', () async => _colors(context, false), icon: Icons.format_color_text),
          _Tool('تمييز', () async => _colors(context, true), icon: Icons.border_color),
          _Tool('مسح التنسيق', () async => a.clearFormat(), icon: Icons.format_clear),
        ]),
      ]),
      _TabDef('تنسيق', [
        _Group('المحاذاة', [
          _Tool('يمين', () async => a.setAlign('right'),
              icon: Icons.format_align_right, stateKey: 'right'),
          _Tool('وسط', () async => a.setAlign('center'),
              icon: Icons.format_align_center, stateKey: 'center'),
          _Tool('يسار', () async => a.setAlign('left'),
              icon: Icons.format_align_left, stateKey: 'left'),
          _Tool('ضبط', () async => a.setAlign('justify'),
              icon: Icons.format_align_justify, stateKey: 'justify'),
        ]),
        _Group('القوائم', [
          _Tool('ترقيم', () async => a.toggleList('ol'),
              icon: Icons.format_list_numbered, stateKey: 'ol'),
          _Tool('نقاط', () async => a.toggleList('ul'),
              icon: Icons.format_list_bulleted, stateKey: 'ul'),
          _Tool('زيادة مسافة', () async => a.indent(1), icon: Icons.format_indent_increase),
          _Tool('إنقاص مسافة', () async => a.indent(-1), icon: Icons.format_indent_decrease),
        ]),
        _Group('حجم الخط', [
          _Tool('صغير', () async => a.setSize('sm'), glyph: 'أ'),
          _Tool('عادي', () async => a.setSize(null), glyph: 'أ'),
          _Tool('كبير', () async => a.setSize('lg'), glyph: 'أ'),
          _Tool('ضخم', () async => a.setSize('xl'), glyph: 'أ'),
        ]),
        _Group('أس ودليل', [
          _Tool('أس', () async => a.toggle('sup'), glyph: 'س²', stateKey: 'sup'),
          _Tool('دليل', () async => a.toggle('sub'), glyph: 'س₂', stateKey: 'sub'),
        ]),
      ]),
      _TabDef('إدراج', [
        _Group('الإجابة', [
          _Tool('سطر إجابة', () async => a.insertAnswerLine(), icon: Icons.horizontal_rule),
          _Tool('نقاط تعبئة', () => ins('..................................'), icon: Icons.more_horiz),
          _Tool('قوسان', () => ins('( \u00A0\u00A0\u00A0 )'), glyph: '( )'),
          _Tool('مربع اختيار', () => ins('\u2610 '), glyph: '☐'),
          _Tool('صح', () => ins('\u2713 '), glyph: '✓'),
          _Tool('خطأ', () => ins('\u2717 '), glyph: '✗'),
        ]),
        _Group('عناصر', [
          _Tool('مستطيل', () async => a.insertBox(), icon: Icons.crop_square),
          _Tool(
              'دائرة',
              () => ins('<span style="display:inline-block;width:30px;height:30px;'
                  'border:1.5px solid #000;border-radius:50%;vertical-align:middle;'
                  'text-align:center;line-height:28px">&nbsp;</span>&nbsp;'),
              icon: Icons.circle_outlined),
          _Tool(
              'خط أفقي',
              () => ins('<hr style="border:0;border-top:1.5px solid #000;margin:8px 0">'),
              icon: Icons.remove),
        ]),
        _Group('وسائط', [
          _Tool('جدول', () => _tableDialog(context), icon: Icons.table_chart_outlined),
          _Tool('صورة', () => a.insertImages(false), icon: Icons.image_outlined),
          _Tool('شبكة صور', () => a.insertImages(true), icon: Icons.grid_view),
        ]),
      ]),
      _TabDef('رياضيات', [
        _Group('المكتبة', [
          _Tool('الرموز', () => showMathSheet(context, a.insertHtml), glyph: 'Σ'),
          _Tool('القوالب', () => showMathSheet(context, a.insertHtml, mode: MathMode.builders),
              icon: Icons.calculate_outlined),
          _Tool('القوانين', () => showMathSheet(context, a.insertHtml, mode: MathMode.formulas),
              icon: Icons.menu_book_outlined),
        ]),
        _Group('قوالب سريعة', [
          _Tool('كسر', () => runMathBuilder(context, a.insertHtml, mb('كسر')), glyph: '½'),
          _Tool('جذر', () => runMathBuilder(context, a.insertHtml, mb('جذر تربيعي')), glyph: '√'),
          _Tool('أس', () => runMathBuilder(context, a.insertHtml, mb('أس')), glyph: 'س²'),
          _Tool('دليل', () => runMathBuilder(context, a.insertHtml, mb('دليل سفلي')), glyph: 'س₁'),
          _Tool('مجموع', () => runMathBuilder(context, a.insertHtml, mb('مجموع (∑) بحدود')),
              glyph: '∑'),
          _Tool('تكامل', () => runMathBuilder(context, a.insertHtml, mb('تكامل محدد')), glyph: '∫'),
          _Tool('نهاية', () => runMathBuilder(context, a.insertHtml, mb('نهاية')), glyph: 'نهـا'),
        ]),
        _Group('رموز سريعة', [
          for (final s in quick) _Tool(kMathNames[s] ?? s, () => ins(esc(s)), glyph: s),
        ]),
      ]),
      _TabDef('جدول', [
        _Group('إنشاء', [
          _Tool('إدراج جدول', () => _tableDialog(context), icon: Icons.table_chart_outlined),
        ]),
        _Group('الصفوف والأعمدة', [
          _Tool('إضافة صف', () async => a.tableOp('addRow'), icon: Icons.add_box_outlined),
          _Tool('حذف صف', () async => a.tableOp('delRow'),
              icon: Icons.indeterminate_check_box_outlined),
          _Tool('إضافة عمود', () async => a.tableOp('addCol'), icon: Icons.view_column_outlined),
          _Tool('حذف عمود', () async => a.tableOp('delCol'), icon: Icons.remove_circle_outline),
        ]),
        _Group('الحدود', [
          _Tool('إظهار الحدود', () async => a.tableBorder('solid'), icon: Icons.border_all),
          _Tool('إخفاء الحدود', () async => a.tableBorder('borderless'), icon: Icons.border_clear),
        ]),
        _Group('حذف', [
          _Tool('حذف الجدول', () async => a.tableOp('delTable'), icon: Icons.delete_outline),
        ]),
      ]),
      _TabDef('صورة', [
        _Group('إدراج', [
          _Tool('صورة', () => a.insertImages(false), icon: Icons.image_outlined),
          _Tool('شبكة صور', () => a.insertImages(true), icon: Icons.grid_view),
        ]),
        _Group('الالتفاف', [
          _Tool('توسيط', () async => a.imgWrap('wrap-center'), icon: Icons.format_align_center),
          _Tool('بجانب النص', () async => a.imgWrap('wrap-inline'), icon: Icons.wrap_text),
          _Tool('مشدود يمين', () async => a.imgWrap('wrap-tight-right'),
              icon: Icons.align_horizontal_right),
          _Tool('مشدود يسار', () async => a.imgWrap('wrap-tight-left'),
              icon: Icons.align_horizontal_left),
          _Tool('أمام النص', () async => a.imgWrap('wrap-front'), icon: Icons.layers_outlined),
        ]),
        _Group('الحجم', [
          for (final p in const [20, 35, 50, 75, 100])
            _Tool('$p%', () async => a.imgSize('$p%'), glyph: '$p'),
        ]),
        _Group('الإطار', [
          _Tool('بدون', () async => a.imgShape('img-borderless'), glyph: '∅'),
          _Tool('مربع', () async => a.imgShape('img-square'), glyph: '□'),
          _Tool('حواف دائرية', () async => a.imgShape('img-rounded'), glyph: '▢'),
          _Tool('دائري', () async => a.imgShape('img-circle'), glyph: '○'),
          _Tool('مزدوج', () async => a.imgShape('img-double'), glyph: '▣'),
          _Tool('متقطع', () async => a.imgShape('img-dashed'), glyph: '┅'),
        ]),
        _Group('الأسهم', [
          _Tool('إضافة سهم', () => _arrowDialog(context), icon: Icons.north_east),
          _Tool('مسح الأسهم', () async => a.imgClearArrows(), icon: Icons.clear_all),
        ]),
        _Group('حذف', [
          _Tool('حذف الصورة', () async => a.imgDelete(), icon: Icons.delete_outline),
        ]),
      ]),
    ];
  }

  // -------------------------------------------------------------------- البناء

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs();
    final tab = tabs[_tab];
    return Material(
      color: AppColors.navBg,
      elevation: 10,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.bottomCenter,
              child: _open
                  ? SizedBox(height: 104, child: _panel(tab))
                  : const SizedBox(width: double.infinity),
            ),
            const Divider(height: 1, color: AppColors.border),
            SizedBox(
              height: 46,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: tabs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (_, i) {
                        final sel = i == _tab;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _tab = i;
                            _open = true;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: sel ? AppColors.pink : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              tabs[i].title,
                              style: TextStyle(
                                fontSize: 14,
                                color: sel ? AppColors.maroon : AppColors.muted,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: _open ? 'طي الأدوات' : 'إظهار الأدوات',
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(
                      _open ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: AppColors.maroon,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(_TabDef tab) {
    final children = <Widget>[];
    for (var g = 0; g < tab.groups.length; g++) {
      final group = tab.groups[g];
      if (g > 0) {
        children.add(const VerticalDivider(
            width: 20, indent: 14, endIndent: 26, color: AppColors.border));
      }
      children.add(Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (final t in group.tools) _tile(t),
          ]),
          const SizedBox(height: 4),
          Text(group.title, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ],
      ));
    }
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      children: children,
    );
  }

  Widget _tile(_Tool t) {
    final active = t.stateKey != null && a.isOn(t.stateKey!);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => t.run(),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.pink : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppColors.maroon : AppColors.border,
                  width: active ? 1.5 : 1,
                ),
              ),
              child: t.glyph != null
                  ? Text(t.glyph!, style: const TextStyle(fontSize: 19, color: AppColors.maroon))
                  : Icon(t.icon, size: 22, color: AppColors.maroon),
            ),
            const SizedBox(height: 3),
            Text(t.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- لوحات وحوارات

  Future<void> _colors(BuildContext context, bool background) async {
    const palette = [
      '#000000', '#dc2626', '#1d4ed8', '#166534', '#ea580c', '#7c3aed', '#8b4a5e', '#6b7280',
    ];
    const marks = ['#fff176', '#ffcc80', '#a5d6a7', '#90caf9', '#f48fb1', '#ce93d8', '#e0e0e0'];
    final colors = background ? marks : palette;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(background ? 'لون التمييز' : 'لون النص', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        background ? a.setBg(c) : a.setColor(c);
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      background ? a.setBg(null) : a.setColor(null);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: const Icon(Icons.format_color_reset, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tableDialog(BuildContext context) async {
    var rows = 2, cols = 2;
    var style = 'borderless-table';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إدراج جدول'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepper('الصفوف', rows, 1, 20, (v) => setS(() => rows = v)),
              _stepper('الأعمدة', cols, 1, 10, (v) => setS(() => cols = v)),
              DropdownButton<String>(
                value: style,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'normal', child: Text('بحدود واضحة')),
                  DropdownMenuItem(
                      value: 'borderless-table', child: Text('بدون حدود (لترتيب الصور)')),
                  DropdownMenuItem(value: 'dashed-table', child: Text('حدود متقطعة')),
                ],
                onChanged: (v) => setS(() => style = v ?? style),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إدراج')),
          ],
        ),
      ),
    );
    if (ok == true) a.insertTable(rows, cols, style);
  }

  Widget _stepper(String label, int v, int min, int max, void Function(int) set) => Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
              onPressed: v > min ? () => set(v - 1) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$v', style: const TextStyle(fontSize: 18)),
          IconButton(
              onPressed: v < max ? () => set(v + 1) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ],
      );

  Future<void> _arrowDialog(BuildContext context) async {
    if (!a.hasImage) return a.say('اضغط على الصورة أولاً');
    var dir = '⬅️';
    var color = '#dc2626';
    double x = 45, y = 45;
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('إضافة سهم على الصورة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<String>(
                  value: dir,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '⬅️', child: Text('⬅️ يسار')),
                    DropdownMenuItem(value: '➡️', child: Text('➡️ يمين')),
                    DropdownMenuItem(value: '⬆️', child: Text('⬆️ أعلى')),
                    DropdownMenuItem(value: '⬇️', child: Text('⬇️ أسفل')),
                    DropdownMenuItem(value: '↖️', child: Text('↖️ أعلى يسار')),
                    DropdownMenuItem(value: '↗️', child: Text('↗️ أعلى يمين')),
                    DropdownMenuItem(value: '↙️', child: Text('↙️ أسفل يسار')),
                    DropdownMenuItem(value: '↘️', child: Text('↘️ أسفل يمين')),
                  ],
                  onChanged: (v) => setS(() => dir = v ?? dir),
                ),
                Wrap(spacing: 10, children: [
                  for (final c in const ['#dc2626', '#1d4ed8', '#166534', '#000000'])
                    GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        width: 34,
                        height: 34,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse('FF${c.substring(1)}', radix: 16)),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: c == color ? AppColors.maroon : AppColors.border,
                              width: c == color ? 3 : 1),
                        ),
                      ),
                    ),
                ]),
                Text('الموضع الأفقي: ${x.round()}%'),
                Slider(value: x, min: 5, max: 90, onChanged: (v) => setS(() => x = v)),
                Text('الموضع الرأسي: ${y.round()}%'),
                Slider(value: y, min: 5, max: 90, onChanged: (v) => setS(() => y = v)),
                TextField(
                  controller: label,
                  decoration: const InputDecoration(labelText: 'تسمية (اختياري)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true) a.imgArrow(dir, color, x.round(), y.round(), label.text.trim());
  }
}

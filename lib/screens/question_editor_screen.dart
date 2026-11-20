import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../editor/block_widgets.dart';
import '../editor/image_compress.dart';
import '../editor/rich_actions.dart';
import '../editor/rich_model.dart';
import '../engine_api.dart';
import '../theme.dart';
import 'question_tools.dart';

/// يفك كيانات HTML البسيطة (نص رمز مدرج بلا وسوم).
String decodeHtmlText(String s) {
  return s
      .replaceAll('&nbsp;', '\u00A0')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll('&amp;', '&');
}

/// محرر نص السؤال الأصلي: فقرات وجداول وصور بلا أي واجهة ويب.
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.api,
    required this.index,
    required this.title,
  });

  final EngineApi api;
  final int index;
  final String title;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen>
    implements EditorHost, RichActions {
  List<RBlock> _blocks = [];
  bool _loading = true;

  ParaBlock? _focused;
  RBlock? _selected; // ImageBlock أو TableBlock
  TableBlock? _selTable;
  int _selRow = 0, _selCol = 0;

  final ValueNotifier<int> _rev = ValueNotifier<int>(0);
  final List<String> _history = [];
  int _h = -1;
  Timer? _saveTimer, _histTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _histTimer?.cancel();
    for (final b in _blocks) {
      b.dispose();
    }
    _rev.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ تحميل

  Future<void> _load() async {
    final m = await widget.api.qGet(widget.index);
    final blocks = blocksFromJson((m?['blocks'] as List?) ?? const []);
    if (blocks.isEmpty) blocks.add(ParaBlock());
    for (final b in blocks) {
      _wire(b);
    }
    if (!mounted) {
      for (final b in blocks) {
        b.dispose();
      }
      return;
    }
    setState(() {
      _blocks = blocks;
      _loading = false;
    });
    _history
      ..clear()
      ..add(blocksSnapshot(_blocks));
    _h = 0;
  }

  void _wire(RBlock b) {
    if (b is ParaBlock) {
      b.focus.addListener(() {
        if (b.focus.hasFocus) _setFocus(b);
      });
      b.c.addListener(_bump);
    } else if (b is TableBlock) {
      for (final r in b.rows) {
        for (final c in r) {
          for (final x in c.blocks) {
            _wire(x);
          }
        }
      }
    }
  }

  void _bump() => _rev.value++;

  void _setFocus(ParaBlock b) {
    if (_focused == b && _selected == null) return;
    final loc = _locate(_blocks, b);
    setState(() {
      _focused = b;
      _selected = null;
      _selTable = loc?.$1;
      _selRow = loc?.$2 ?? 0;
      _selCol = loc?.$3 ?? 0;
    });
    _rev.value++;
  }

  (TableBlock, int, int)? _locate(List<RBlock> list, ParaBlock target) {
    for (final b in list) {
      if (b is! TableBlock) continue;
      for (var r = 0; r < b.rows.length; r++) {
        for (var c = 0; c < b.rows[r].length; c++) {
          if (b.rows[r][c].blocks.contains(target)) return (b, r, c);
        }
      }
    }
    return null;
  }

  List<RBlock>? _findList(List<RBlock> list, RBlock t) {
    if (list.contains(t)) return list;
    for (final b in list) {
      if (b is! TableBlock) continue;
      for (final r in b.rows) {
        for (final c in r) {
          final f = _findList(c.blocks, t);
          if (f != null) return f;
        }
      }
    }
    return null;
  }

  // -------------------------------------------------------------- حفظ وتاريخ

  void _changed() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _saveNow());
    _histTimer?.cancel();
    _histTimer = Timer(const Duration(milliseconds: 800), _commit);
    _rev.value++;
  }

  Future<void> _saveNow({bool render = false}) =>
      widget.api.qSet(widget.index, {'blocks': blocksToJson(_blocks)}, render: render);

  void _commit() {
    final snap = blocksSnapshot(_blocks);
    if (_h >= 0 && _h < _history.length && _history[_h] == snap) return;
    _history.removeRange(_h + 1, _history.length);
    _history.add(snap);
    if (_history.length > 80) _history.removeAt(0);
    _h = _history.length - 1;
  }

  void _restore(String snap) {
    final old = _blocks;
    final nb = blocksFromJson(jsonDecode(snap) as List);
    if (nb.isEmpty) nb.add(ParaBlock());
    for (final b in nb) {
      _wire(b);
    }
    setState(() {
      _blocks = nb;
      _focused = null;
      _selected = null;
      _selTable = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final b in old) {
        b.dispose();
      }
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _saveNow());
    _rev.value++;
  }

  @override
  Future<void> undo() async {
    _histTimer?.cancel();
    _commit();
    if (_h <= 0) return;
    _h--;
    _restore(_history[_h]);
  }

  @override
  Future<void> redo() async {
    if (_h >= _history.length - 1) return;
    _h++;
    _restore(_history[_h]);
  }

  Future<void> _finish() async {
    _saveTimer?.cancel();
    _histTimer?.cancel();
    _commit();
    await _saveNow(render: true);
    if (mounted) Navigator.of(context).pop();
  }

  // ------------------------------------------------------------- EditorHost

  @override
  bool isImageSelected(ImageBlock b) => _selected == b;

  @override
  bool isTableSelected(TableBlock t) => _selTable == t && _focused == null;

  @override
  void onParaChanged(ParaBlock b) {
    if (b.c.text.contains('\n')) _splitPara(b);
    _changed();
  }

  @override
  void onSelectImage(ImageBlock b) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = b;
      _focused = null;
      _selTable = null;
    });
    _rev.value++;
  }

  @override
  void onSelectTable(TableBlock t) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selTable = t;
      _selected = t;
      _focused = null;
      _selRow = 0;
      _selCol = 0;
    });
    _rev.value++;
  }

  @override
  void onDeleteBlock(RBlock b) {
    final list = _findList(_blocks, b);
    if (list == null) return;
    list.remove(b);
    if (list.isEmpty) {
      final p = ParaBlock();
      _wire(p);
      list.add(p);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => b.dispose());
    setState(() {
      if (_selected == b) _selected = null;
      if (_selTable == b) _selTable = null;
      _focused = null;
    });
    _changed();
  }

  void _splitPara(ParaBlock b) {
    final t = b.c.text;
    final segs = <List<Map<String, dynamic>>>[];
    var start = 0;
    for (var i = 0; i < t.length; i++) {
      if (t[i] == '\n') {
        segs.add(b.c.toRuns(start, i));
        start = i + 1;
      }
    }
    segs.add(b.c.toRuns(start, t.length));
    // Enter على عنصر قائمة فارغ ينهي القائمة
    if (b.list != null && segs.length == 2 && segs[0].isEmpty && segs[1].isEmpty) {
      b.list = null;
      b.c.loadRuns(const []);
      setState(() {});
      return;
    }
    final list = _findList(_blocks, b);
    if (list == null) return;
    b.c.loadRuns(segs.first);
    var at = list.indexOf(b) + 1;
    ParaBlock? last;
    for (final runs in segs.skip(1)) {
      final nb = ParaBlock(align: b.align, list: b.list, indent: b.indent);
      nb.c.loadRuns(runs);
      _wire(nb);
      list.insert(at++, nb);
      last = nb;
    }
    setState(() {});
    final f = last;
    if (f != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        f.focus.requestFocus();
        f.c.selection = const TextSelection.collapsed(offset: 0);
      });
    }
  }

  void _mergeWithPrevious(int i) {
    if (i <= 0 || i >= _blocks.length) return;
    final cur = _blocks[i], prev = _blocks[i - 1];
    if (cur is! ParaBlock || prev is! ParaBlock) return;
    final at = prev.c.text.length;
    prev.c.appendRuns(cur.c.toRuns());
    _blocks.removeAt(i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cur.dispose();
      prev.focus.requestFocus();
      prev.c.selection = TextSelection.collapsed(offset: at);
    });
    setState(() => _focused = prev);
    _changed();
  }

  void _moveBlock(int i, int delta) {
    final j = i + delta;
    if (i < 0 || j < 0 || i >= _blocks.length || j >= _blocks.length) return;
    final b = _blocks.removeAt(i);
    _blocks.insert(j, b);
    setState(() {});
    _changed();
  }

  void _duplicateBlock(int i) {
    final copy = blocksFromJson([_blocks[i].toJson()]);
    if (copy.isEmpty) return;
    _wire(copy.first);
    _blocks.insert(i + 1, copy.first);
    setState(() {});
    _changed();
  }

  // ----------------------------------------------------------------- إدراج

  RBlock? _anchor() => _focused ?? _selected ?? (_blocks.isNotEmpty ? _blocks.last : null);

  void _insertAfter(RBlock? anchor, List<RBlock> items) {
    if (items.isEmpty) return;
    for (final b in items) {
      _wire(b);
    }
    var list = _blocks;
    var at = _blocks.length;
    if (anchor != null) {
      final l = _findList(_blocks, anchor);
      if (l != null) {
        list = l;
        at = l.indexOf(anchor) + 1;
      }
    }
    list.insertAll(at, items);
    if (list.last is! ParaBlock) {
      final p = ParaBlock();
      _wire(p);
      list.add(p);
    }
    setState(() {});
    _changed();
    ParaBlock? target;
    for (final b in items) {
      if (b is ParaBlock) {
        target = b;
        break;
      }
      if (b is TableBlock && b.rows.isNotEmpty) {
        final first = b.rows.first.first.blocks.whereType<ParaBlock>().firstOrNull;
        if (first != null) {
          target = first;
          break;
        }
      }
    }
    final t = target;
    if (t != null) WidgetsBinding.instance.addPostFrameCallback((_) => t.focus.requestFocus());
  }

  ParaBlock _ensureFocusedPara() {
    final f = _focused;
    if (f != null) return f;
    for (var i = _blocks.length - 1; i >= 0; i--) {
      final b = _blocks[i];
      if (b is ParaBlock) return b;
    }
    final p = ParaBlock();
    _wire(p);
    _blocks.add(p);
    return p;
  }

  @override
  Future<void> insertHtml(String html) async {
    if (!html.contains('<')) {
      final p = _ensureFocusedPara();
      p.focus.requestFocus();
      p.c.insertPlain(decodeHtmlText(html));
      _changed();
      return;
    }
    final r = await widget.api.htmlToBlocks(html);
    final blocks = blocksFromJson((r?['blocks'] as List?) ?? const []);
    if (blocks.isEmpty) return;
    final p = _focused;
    if (p != null && blocks.first is ParaBlock) {
      final f = blocks.first as ParaBlock;
      if (f.list == null && !f.box) {
        blocks.removeAt(0);
        p.c.insertRuns(f.c.toRuns());
        f.dispose();
        p.focus.requestFocus();
        if (blocks.isNotEmpty) _insertAfter(p, blocks);
        _changed();
        return;
      }
    }
    _insertAfter(_anchor(), blocks);
  }

  @override
  void insertAnswerLine() {
    final p = ParaBlock();
    p.c.loadRuns([
      {'x': '.' * 84}
    ]);
    _insertAfter(_anchor(), [p]);
  }

  @override
  void insertBox() => _insertAfter(_anchor(), [ParaBlock(box: true)]);

  @override
  void insertTable(int rows, int cols, String style) =>
      _insertAfter(_anchor(), [TableBlock.create(rows, cols, style)]);

  @override
  Future<void> insertImages(bool grid) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: grid,
      withData: true,
    );
    if (res == null) return;
    say('جارٍ تجهيز الصورة…');
    final urls = <String>[];
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (bytes.length > 15 * 1024 * 1024) {
        say('تم تجاهل صورة أكبر من 15MB');
        continue;
      }
      final u = await compressImageAsync(bytes);
      if (u != null) urls.add(u);
    }
    if (!mounted) return;
    if (urls.isEmpty) return say('تعذر قراءة الصورة');
    if (grid || urls.length > 1) {
      final blank = '(${'\u00A0' * 8})';
      final row = <CellModel>[
        for (final u in urls)
          CellModel(blocks: [
            ImageBlock(src: u, w: '85%'),
            ParaBlock(align: 'center')..c.loadRuns([{'x': blank}]),
          ]),
      ];
      _insertAfter(_anchor(), [TableBlock(rows: [row], cls: 'borderless-table')]);
    } else {
      _insertAfter(_anchor(), [ImageBlock(src: urls.first)]);
    }
  }

  // ------------------------------------------------------------ RichActions

  @override
  ValueListenable<int> get revision => _rev;

  @override
  bool get hasImage => _selected is ImageBlock;

  @override
  bool get hasTable => _selTable != null;

  @override
  bool isOn(String key) {
    final p = _focused;
    if (p == null) return false;
    return switch (key) {
      'bold' => p.c.isActive((s) => s.b),
      'italic' => p.c.isActive((s) => s.i),
      'underline' => p.c.isActive((s) => s.u),
      'strike' => p.c.isActive((s) => s.s),
      'sup' => p.c.isActive((s) => s.sup),
      'sub' => p.c.isActive((s) => s.sub),
      'right' => p.align == null || p.align == 'right',
      'center' => p.align == 'center',
      'left' => p.align == 'left',
      'justify' => p.align == 'justify',
      'ul' => p.list == 'ul',
      'ol' => p.list == 'ol',
      _ => false,
    };
  }

  ParaBlock? _need() {
    final p = _focused;
    if (p == null) say('اضغط داخل النص أولاً');
    return p;
  }

  @override
  void toggle(String key) {
    final p = _need();
    if (p == null) return;
    switch (key) {
      case 'bold':
        p.c.toggleBold();
      case 'italic':
        p.c.toggleItalic();
      case 'underline':
        p.c.toggleUnderline();
      case 'strike':
        p.c.toggleStrike();
      case 'sup':
        p.c.toggleSup();
      case 'sub':
        p.c.toggleSub();
    }
    _changed();
  }

  @override
  void setColor(String? hex) {
    _need()?.c.setColor(hex);
    _changed();
  }

  @override
  void setBg(String? hex) {
    _need()?.c.setBg(hex);
    _changed();
  }

  @override
  void setSize(String? size) {
    _need()?.c.setSize(size);
    _changed();
  }

  @override
  void clearFormat() {
    _need()?.c.clearFormat();
    _changed();
  }

  @override
  void setAlign(String align) {
    final p = _need();
    if (p == null) return;
    setState(() => p.align = align);
    _changed();
  }

  @override
  void toggleList(String kind) {
    final p = _need();
    if (p == null) return;
    setState(() => p.list = p.list == kind ? null : kind);
    _changed();
  }

  @override
  void indent(int delta) {
    final p = _need();
    if (p == null) return;
    setState(() => p.indent = (p.indent + delta).clamp(0, 4).toInt());
    _changed();
  }

  @override
  Future<void> paste() async {
    final p = _need();
    if (p == null) return;
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t == null || t.isEmpty) return say('الحافظة فارغة');
    p.c.insertPlain(t);
    if (t.contains('\n')) {
      onParaChanged(p);
    } else {
      _changed();
    }
  }

  String _selectedText(ParaBlock p) {
    final s = p.c.selection;
    if (!s.isValid || s.isCollapsed) return '';
    return p.c.text.substring(s.start, s.end).replaceAll(kAtomChar, '');
  }

  @override
  void copy() {
    final p = _need();
    if (p == null) return;
    final t = _selectedText(p);
    if (t.isEmpty) return say('حدّد نصاً أولاً');
    Clipboard.setData(ClipboardData(text: t));
    say('تم النسخ');
  }

  @override
  void cut() {
    final p = _need();
    if (p == null) return;
    final t = _selectedText(p);
    if (t.isEmpty) return say('حدّد نصاً أولاً');
    Clipboard.setData(ClipboardData(text: t));
    deleteSelection();
  }

  @override
  void selectAll() {
    final p = _need();
    if (p == null) return;
    p.focus.requestFocus();
    p.c.selection = TextSelection(baseOffset: 0, extentOffset: p.c.text.length);
  }

  @override
  void deleteSelection() {
    final p = _need();
    if (p == null) return;
    final s = p.c.selection;
    if (!s.isValid || s.isCollapsed) return say('حدّد نصاً أولاً');
    p.c.insertPlain('');
    _changed();
  }

  // ---- الصورة

  ImageBlock? _img() {
    final s = _selected;
    if (s is ImageBlock) return s;
    say('اضغط على الصورة أولاً');
    return null;
  }

  @override
  void imgWrap(String v) {
    final b = _img();
    if (b == null) return;
    setState(() {
      b.wrap = v;
      if (v == 'wrap-front') {
        b.top ??= '15px';
        b.left ??= '25%';
      } else {
        b.top = null;
        b.left = null;
      }
    });
    _changed();
  }

  @override
  void imgSize(String v) {
    final b = _img();
    if (b == null) return;
    setState(() => b.w = v);
    _changed();
  }

  @override
  void imgShape(String v) {
    final b = _img();
    if (b == null) return;
    setState(() => b.shape = v);
    _changed();
  }

  @override
  void imgArrow(String dir, String color, int x, int y, String label) {
    final b = _img();
    if (b == null) return;
    setState(() => b.arrows.add(
        ArrowSpec(dir: dir, color: color, x: x.toDouble(), y: y.toDouble(), label: label)));
    _changed();
  }

  @override
  void imgClearArrows() {
    final b = _img();
    if (b == null) return;
    setState(b.arrows.clear);
    _changed();
  }

  @override
  void imgDelete() {
    final b = _img();
    if (b != null) onDeleteBlock(b);
  }

  // ---- الجدول

  @override
  void tableBorder(String mode) {
    final t = _selTable;
    if (t == null) return say('اضغط داخل خلية الجدول أولاً');
    final cls = t.cls.split(' ').where((c) => c.isNotEmpty && c != 'borderless-table' && c != 'dashed-table').toList();
    if (mode == 'borderless') cls.add('borderless-table');
    setState(() => t.cls = cls.join(' '));
    _changed();
  }

  @override
  void tableOp(String action) {
    final t = _selTable;
    if (t == null) return say('اضغط داخل خلية الجدول أولاً');
    if (action == 'delTable') return onDeleteBlock(t);
    if (t.complex) return say('الجدول فيه خلايا مدموجة؛ تعديل الصفوف والأعمدة غير متاح');
    final cols = t.colCount;
    final removed = <CellModel>[];
    switch (action) {
      case 'addRow':
        final row = [for (var c = 0; c < cols; c++) CellModel.empty()];
        for (final cell in row) {
          for (final b in cell.blocks) {
            _wire(b);
          }
        }
        t.rows.insert(math.min(_selRow + 1, t.rows.length), row);
      case 'delRow':
        if (t.rows.length <= 1) return onDeleteBlock(t);
        removed.addAll(t.rows.removeAt(math.min(_selRow, t.rows.length - 1)));
      case 'addCol':
        for (final row in t.rows) {
          final cell = CellModel.empty(th: row.isNotEmpty && row.first.th);
          for (final b in cell.blocks) {
            _wire(b);
          }
          row.insert(math.min(_selCol + 1, row.length), cell);
        }
      case 'delCol':
        if (cols <= 1) return onDeleteBlock(t);
        for (final row in t.rows) {
          removed.add(row.removeAt(math.min(_selCol, row.length - 1)));
        }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in removed) {
        c.dispose();
      }
    });
    setState(() {
      _focused = null;
      _selTable = t;
      _selected = t;
      _selRow = math.min(_selRow, t.rows.length - 1);
      _selCol = math.min(_selCol, t.colCount - 1);
    });
    _changed();
  }

  @override
  void say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  // ------------------------------------------------------------------ الواجهة

  bool _active(RBlock b) =>
      b == _focused || b == _selected || (b is TableBlock && b == _selTable);

  Widget _blockBar(int i, RBlock b) {
    Widget btn(IconData icon, String tip, VoidCallback? f, {Color? color}) => IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tip,
          onPressed: f,
          icon: Icon(icon, size: 20, color: f == null ? AppColors.border : (color ?? AppColors.maroon)),
        );
    final prevIsPara = i > 0 && _blocks[i - 1] is ParaBlock && b is ParaBlock;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.pink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            btn(Icons.arrow_upward, 'نقل للأعلى', i > 0 ? () => _moveBlock(i, -1) : null),
            btn(Icons.arrow_downward, 'نقل للأسفل',
                i < _blocks.length - 1 ? () => _moveBlock(i, 1) : null),
            btn(Icons.copy_outlined, 'تكرار', () => _duplicateBlock(i)),
            if (b is ParaBlock)
              btn(Icons.merge_type, 'دمج مع السابقة', prevIsPara ? () => _mergeWithPrevious(i) : null),
            btn(Icons.delete_outline, 'حذف', () => onDeleteBlock(b), color: AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final items = <Widget>[];
    var counter = 0;
    for (var i = 0; i < _blocks.length; i++) {
      final b = _blocks[i];
      counter = (b is ParaBlock && b.list == 'ol') ? counter + 1 : 0;
      items.add(buildBlockWidget(b, this, number: counter));
      if (_active(b)) items.add(_blockBar(i, b));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _addChip(Icons.notes, 'فقرة', () => _insertAfter(_blocks.isEmpty ? null : _blocks.last, [ParaBlock()])),
            _addChip(Icons.table_chart_outlined, 'جدول',
                () => insertTable(2, 2, 'normal')),
            _addChip(Icons.image_outlined, 'صورة', () => insertImages(false)),
          ],
        ),
      ],
    );
  }

  Widget _addChip(IconData icon, String label, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 18, color: AppColors.maroon),
        label: Text(label),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        onPressed: onTap,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 4,
          title: Text(widget.title.isEmpty ? 'تحرير السؤال' : widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, color: AppColors.ink)),
          actions: [
            IconButton(
                tooltip: 'تراجع',
                onPressed: undo,
                icon: const Icon(Icons.undo, color: AppColors.maroon)),
            IconButton(
                tooltip: 'إعادة',
                onPressed: redo,
                icon: const Icon(Icons.redo, color: AppColors.maroon)),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 10, start: 4),
              child: FilledButton.icon(
                onPressed: _finish,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('تم'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
        body: _loading ? const Center(child: CircularProgressIndicator()) : _body(),
        bottomNavigationBar: _loading ? null : QuestionRibbon(actions: this),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// رمز مكان العنصر المدمج (كسر، جذر، صورة داخل سطر…) داخل النص.
const String kAtomChar = '\uFFFC';

const Object _keep = Object();

/// تنسيق حرف واحد.
@immutable
class CharStyle {
  const CharStyle({
    this.b = false,
    this.i = false,
    this.u = false,
    this.s = false,
    this.sup = false,
    this.sub = false,
    this.color,
    this.bg,
    this.size,
    this.atom,
    this.atomLabel,
  });

  final bool b, i, u, s, sup, sub;
  final String? color, bg, size;

  /// HTML خام لعنصر مدمج (يُحفظ كما هو)، ومعه تسمية قصيرة تُعرض في المحرر.
  final String? atom;
  final String? atomLabel;

  CharStyle copyWith({
    bool? b,
    bool? i,
    bool? u,
    bool? s,
    bool? sup,
    bool? sub,
    Object? color = _keep,
    Object? bg = _keep,
    Object? size = _keep,
  }) =>
      CharStyle(
        b: b ?? this.b,
        i: i ?? this.i,
        u: u ?? this.u,
        s: s ?? this.s,
        sup: sup ?? this.sup,
        sub: sub ?? this.sub,
        color: identical(color, _keep) ? this.color : color as String?,
        bg: identical(bg, _keep) ? this.bg : bg as String?,
        size: identical(size, _keep) ? this.size : size as String?,
      );

  /// نفس التنسيق دون العنصر المدمج.
  CharStyle get plain => atom == null
      ? this
      : CharStyle(b: b, i: i, u: u, s: s, sup: sup, sub: sub, color: color, bg: bg, size: size);

  bool sameFormat(CharStyle o) =>
      b == o.b &&
      i == o.i &&
      u == o.u &&
      s == o.s &&
      sup == o.sup &&
      sub == o.sub &&
      color == o.color &&
      bg == o.bg &&
      size == o.size;

  Map<String, dynamic> toRun(String text) => {
        'x': text,
        if (b) 'b': 1,
        if (i) 'i': 1,
        if (u) 'u': 1,
        if (s) 's': 1,
        if (sup) 'sup': 1,
        if (sub) 'sub': 1,
        if (color != null) 'c': color,
        if (bg != null) 'bg': bg,
        if (size != null) 'sz': size,
      };

  static CharStyle fromRun(Map run) => CharStyle(
        b: run['b'] == 1,
        i: run['i'] == 1,
        u: run['u'] == 1,
        s: run['s'] == 1,
        sup: run['sup'] == 1,
        sub: run['sub'] == 1,
        color: run['c'] as String?,
        bg: run['bg'] as String?,
        size: run['sz'] as String?,
      );
}

Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? null : Color(v);
}

double sizeScale(String? sz) => switch (sz) {
      'sm' => 0.85,
      'lg' => 1.25,
      'xl' => 1.6,
      _ => 1.0,
    };

/// متحكم نص غني: يحفظ تنسيقاً لكل حرف ويبني TextSpan مناسباً داخل TextField.
class RichController extends TextEditingController {
  RichController({String text = '', List<CharStyle>? styles})
      : _styles = styles ?? List<CharStyle>.filled(text.length, const CharStyle()),
        super(text: text);

  List<CharStyle> _styles;
  CharStyle _typing = const CharStyle();
  bool _typingExplicit = false;
  bool _skip = false;

  List<CharStyle> get styles => _styles;

  @override
  set value(TextEditingValue newValue) {
    if (!_skip) {
      if (_styles.length != text.length) {
        _styles = List<CharStyle>.filled(text.length, const CharStyle());
      }
      if (newValue.text != text) {
        _reconcile(text, newValue.text);
      } else if (newValue.selection != selection) {
        _typingExplicit = false;
      }
    }
    super.value = newValue;
  }

  /// يحدّث قائمة التنسيقات بعد تعديل النص من لوحة المفاتيح (إدراج/حذف).
  void _reconcile(String old, String neu) {
    final minLen = math.min(old.length, neu.length);
    var p = 0;
    while (p < minLen && old.codeUnitAt(p) == neu.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p && old.codeUnitAt(old.length - 1 - s) == neu.codeUnitAt(neu.length - 1 - s)) {
      s++;
    }
    final inserted = neu.length - p - s;
    final next = <CharStyle>[..._styles.sublist(0, p)];
    if (inserted > 0) {
      final st = _typingExplicit
          ? _typing
          : (p > 0 ? _styles[p - 1].plain : (p < _styles.length ? _styles[p].plain : const CharStyle()));
      next.addAll(List<CharStyle>.filled(inserted, st.plain));
    }
    next.addAll(_styles.sublist(old.length - s));
    _styles = next;
    _typingExplicit = false;
  }

  /// يستبدل المدى [start,end) بنص وتنسيقات محددة دون مصالحة تلقائية.
  void _replace(int start, int end, String t, List<CharStyle> st) {
    _styles = [..._styles.sublist(0, start), ...st, ..._styles.sublist(end)];
    _skip = true;
    value = TextEditingValue(
      text: text.replaceRange(start, end, t),
      selection: TextSelection.collapsed(offset: start + t.length),
    );
    _skip = false;
    _typingExplicit = false;
  }

  (int, int) get _range {
    final sel = selection;
    if (!sel.isValid) return (text.length, text.length);
    return (math.min(sel.start, sel.end), math.max(sel.start, sel.end));
  }

  CharStyle _styleBeforeCursor() {
    final (a, _) = _range;
    if (a > 0 && a - 1 < _styles.length) return _styles[a - 1].plain;
    if (_styles.isNotEmpty && a < _styles.length) return _styles[a].plain;
    return const CharStyle();
  }

  CharStyle get currentStyle => _typingExplicit ? _typing : _styleBeforeCursor();

  // ------------------------------------------------------------------ تنسيق

  /// هل الخاصية مفعّلة عند المؤشر/في كل التحديد؟
  bool isActive(bool Function(CharStyle) test) {
    final (a, b) = _range;
    if (a == b) return test(currentStyle);
    var any = false;
    for (var i = a; i < b && i < _styles.length; i++) {
      if (_styles[i].atom != null) continue;
      any = true;
      if (!test(_styles[i])) return false;
    }
    return any;
  }

  void applyFormat(CharStyle Function(CharStyle) f) {
    final (a, b) = _range;
    if (a == b) {
      _typing = f(currentStyle);
      _typingExplicit = true;
    } else {
      _styles = List<CharStyle>.of(_styles);
      for (var i = a; i < b && i < _styles.length; i++) {
        if (_styles[i].atom != null) continue;
        _styles[i] = f(_styles[i]);
      }
    }
    notifyListeners();
  }

  void toggleBold() {
    final on = isActive((s) => s.b);
    applyFormat((s) => s.copyWith(b: !on));
  }

  void toggleItalic() {
    final on = isActive((s) => s.i);
    applyFormat((s) => s.copyWith(i: !on));
  }

  void toggleUnderline() {
    final on = isActive((s) => s.u);
    applyFormat((s) => s.copyWith(u: !on));
  }

  void toggleStrike() {
    final on = isActive((s) => s.s);
    applyFormat((s) => s.copyWith(s: !on));
  }

  void toggleSup() {
    final on = isActive((s) => s.sup);
    applyFormat((s) => s.copyWith(sup: !on, sub: false));
  }

  void toggleSub() {
    final on = isActive((s) => s.sub);
    applyFormat((s) => s.copyWith(sub: !on, sup: false));
  }

  void setColor(String? hex) => applyFormat((s) => s.copyWith(color: hex));
  void setBg(String? hex) => applyFormat((s) => s.copyWith(bg: hex));
  void setSize(String? sz) => applyFormat((s) => s.copyWith(size: sz));

  void clearFormat() => applyFormat((s) => const CharStyle());

  // ------------------------------------------------------------------ إدراج

  void insertPlain(String t) {
    final (a, b) = _range;
    final st = currentStyle;
    _replace(a, b, t, List<CharStyle>.filled(t.length, st));
  }

  void insertAtom(String html, String label) {
    final (a, b) = _range;
    _replace(a, b, kAtomChar, [CharStyle(atom: html, atomLabel: label)]);
  }

  /// يدرج سلسلة runs (بصيغة JSON) عند المؤشر.
  void insertRuns(List<dynamic> runs) {
    final sb = StringBuffer();
    final st = <CharStyle>[];
    _appendRuns(runs, sb, st);
    final (a, b) = _range;
    _replace(a, b, sb.toString(), st);
  }

  void appendRuns(List<dynamic> runs) {
    final sb = StringBuffer();
    final st = <CharStyle>[];
    _appendRuns(runs, sb, st);
    _replace(text.length, text.length, sb.toString(), st);
  }

  void loadRuns(List<dynamic> runs) {
    final sb = StringBuffer();
    final st = <CharStyle>[];
    _appendRuns(runs, sb, st);
    _styles = st;
    _skip = true;
    value = TextEditingValue(text: sb.toString());
    _skip = false;
    _typingExplicit = false;
  }

  static void _appendRuns(List<dynamic> runs, StringBuffer sb, List<CharStyle> st) {
    for (final r in runs) {
      if (r is! Map) continue;
      if (r['atom'] is String) {
        sb.write(kAtomChar);
        st.add(CharStyle(atom: r['atom'] as String, atomLabel: (r['label'] as String?) ?? '▣'));
      } else {
        final t = (r['x'] as String?) ?? '';
        sb.write(t);
        st.addAll(List<CharStyle>.filled(t.length, CharStyle.fromRun(r)));
      }
    }
  }

  // ------------------------------------------------------------------ تصدير

  List<Map<String, dynamic>> toRuns([int? from, int? to]) {
    final a = from ?? 0, b = to ?? text.length;
    final out = <Map<String, dynamic>>[];
    var i = a;
    while (i < b && i < _styles.length) {
      final st = _styles[i];
      if (st.atom != null) {
        out.add({'atom': st.atom, 'label': st.atomLabel ?? '▣'});
        i++;
        continue;
      }
      var j = i + 1;
      while (j < b && j < _styles.length && _styles[j].atom == null && _styles[j].sameFormat(st)) {
        j++;
      }
      out.add(st.toRun(text.substring(i, j)));
      i = j;
    }
    return out;
  }

  // ------------------------------------------------------------------ عرض

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    if (_styles.length != text.length) {
      _styles = List<CharStyle>.filled(text.length, const CharStyle());
    }
    final spans = <InlineSpan>[];
    final t = text;
    var i = 0;
    while (i < t.length) {
      final st = _styles[i];
      if (st.atom != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _AtomChip(label: st.atomLabel ?? '▣'),
        ));
        i++;
        continue;
      }
      var j = i + 1;
      while (j < t.length && _styles[j].atom == null && _styles[j].sameFormat(st)) {
        j++;
      }
      spans.add(TextSpan(text: t.substring(i, j), style: _spanStyle(st, base)));
      i = j;
    }
    return TextSpan(style: base, children: spans);
  }

  TextStyle _spanStyle(CharStyle st, TextStyle base) {
    final deco = <TextDecoration>[
      if (st.u) TextDecoration.underline,
      if (st.s) TextDecoration.lineThrough,
    ];
    var scale = sizeScale(st.size);
    if (st.sup || st.sub) scale *= 0.7;
    return TextStyle(
      fontWeight: st.b ? FontWeight.w700 : null,
      fontStyle: st.i ? FontStyle.italic : null,
      decoration: deco.isEmpty ? null : TextDecoration.combine(deco),
      color: parseHexColor(st.color),
      backgroundColor: parseHexColor(st.bg),
      fontSize: (base.fontSize ?? 17) * scale,
      fontFeatures: st.sup
          ? const [FontFeature.superscripts()]
          : (st.sub ? const [FontFeature.subscripts()] : null),
    );
  }
}

class _AtomChip extends StatelessWidget {
  const _AtomChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFED9E1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF8B4A5E), height: 1.3)),
      );
}

// ===================================================================== الكتل

abstract class RBlock {
  final Key key = UniqueKey();
  Map<String, dynamic> toJson();
  void dispose() {}
}

class ParaBlock extends RBlock {
  ParaBlock({this.align, this.list, this.indent = 0, this.box = false, RichController? controller})
      : c = controller ?? RichController();

  final RichController c;
  final FocusNode focus = FocusNode();
  String? align; // right | center | left | justify
  String? list; // ul | ol
  int indent;
  bool box;

  factory ParaBlock.fromJson(Map j) {
    final p = ParaBlock(
      align: j['align'] as String?,
      list: j['list'] as String?,
      indent: (j['indent'] as num?)?.toInt() ?? 0,
      box: j['box'] == 1,
    );
    p.c.loadRuns((j['runs'] as List?) ?? const []);
    return p;
  }

  @override
  Map<String, dynamic> toJson() => {
        't': 'p',
        'runs': c.toRuns(),
        if (align != null) 'align': align,
        if (list != null) 'list': list,
        if (indent > 0) 'indent': indent,
        if (box) 'box': 1,
      };

  @override
  void dispose() {
    c.dispose();
    focus.dispose();
  }
}

class ArrowSpec {
  ArrowSpec({required this.dir, required this.color, required this.x, required this.y, this.label = ''});

  String dir, color, label;
  double x, y;

  factory ArrowSpec.fromJson(Map j) => ArrowSpec(
        dir: (j['dir'] as String?) ?? '⬅️',
        color: (j['color'] as String?) ?? '#dc2626',
        x: (j['x'] as num?)?.toDouble() ?? 45,
        y: (j['y'] as num?)?.toDouble() ?? 45,
        label: (j['label'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'dir': dir, 'color': color, 'x': x, 'y': y, 'label': label};
}

class ImageBlock extends RBlock {
  ImageBlock({
    required this.src,
    this.w = '40%',
    this.wrap = 'wrap-center',
    this.shape = 'img-borderless',
    this.top,
    this.left,
    List<ArrowSpec>? arrows,
  }) : arrows = arrows ?? [] {
    bytes = decodeDataUrl(src);
  }

  String src, w, wrap, shape;
  String? top, left;
  final List<ArrowSpec> arrows;
  Uint8List? bytes;

  factory ImageBlock.fromJson(Map j) => ImageBlock(
        src: (j['src'] as String?) ?? '',
        w: (j['w'] as String?) ?? '40%',
        wrap: (j['wrap'] as String?) ?? 'wrap-center',
        shape: (j['shape'] as String?) ?? 'img-borderless',
        top: j['top'] as String?,
        left: j['left'] as String?,
        arrows: [for (final a in (j['arrows'] as List? ?? const [])) if (a is Map) ArrowSpec.fromJson(a)],
      );

  /// نسبة العرض (0.1 – 1.0).
  double get widthFactor {
    final v = double.tryParse(w.replaceAll('%', '').trim());
    return ((v ?? 40) / 100).clamp(0.1, 1.0).toDouble();
  }

  @override
  Map<String, dynamic> toJson() => {
        't': 'img',
        'src': src,
        'w': w,
        'wrap': wrap,
        'shape': shape,
        if (top != null) 'top': top,
        if (left != null) 'left': left,
        'arrows': [for (final a in arrows) a.toJson()],
      };
}

Uint8List? decodeDataUrl(String src) {
  try {
    final i = src.indexOf(',');
    if (i < 0) return null;
    return base64Decode(src.substring(i + 1));
  } catch (_) {
    return null;
  }
}

class CellModel {
  CellModel({required this.blocks, this.th = false, this.colspan, this.rowspan, this.style});

  final List<RBlock> blocks;
  bool th;
  int? colspan, rowspan;
  String? style;

  factory CellModel.fromJson(Map j) => CellModel(
        blocks: blocksFromJson((j['blocks'] as List?) ?? const []),
        th: j['th'] == 1,
        colspan: (j['colspan'] as num?)?.toInt(),
        rowspan: (j['rowspan'] as num?)?.toInt(),
        style: j['style'] as String?,
      );

  factory CellModel.empty({bool th = false}) => CellModel(blocks: [ParaBlock()], th: th);

  Map<String, dynamic> toJson() => {
        'blocks': blocksToJson(blocks),
        if (th) 'th': 1,
        if (colspan != null) 'colspan': colspan,
        if (rowspan != null) 'rowspan': rowspan,
        if (style != null) 'style': style,
      };

  void dispose() {
    for (final b in blocks) {
      b.dispose();
    }
  }
}

class TableBlock extends RBlock {
  TableBlock({required this.rows, this.cls = '', this.style, this.complex = false});

  final List<List<CellModel>> rows;
  String cls;
  String? style;
  bool complex;

  factory TableBlock.create(int r, int c, String styleName) => TableBlock(
        rows: [for (var i = 0; i < r; i++) [for (var j = 0; j < c; j++) CellModel.empty()]],
        cls: styleName == 'normal' ? '' : styleName,
      );

  factory TableBlock.fromJson(Map j) => TableBlock(
        rows: [
          for (final r in (j['rows'] as List? ?? const []))
            [for (final c in (r as List)) CellModel.fromJson(c as Map)],
        ],
        cls: (j['cls'] as String?) ?? '',
        style: j['style'] as String?,
        complex: j['complex'] == true,
      );

  bool get borderless => cls.contains('borderless-table');
  int get colCount => rows.isEmpty ? 0 : rows.map((r) => r.length).reduce(math.max);

  @override
  Map<String, dynamic> toJson() => {
        't': 'table',
        'cls': cls,
        if (style != null) 'style': style,
        'complex': complex,
        'rows': [for (final r in rows) [for (final c in r) c.toJson()]],
      };

  @override
  void dispose() {
    for (final r in rows) {
      for (final c in r) {
        c.dispose();
      }
    }
  }
}

class RawBlock extends RBlock {
  RawBlock({required this.html, this.label = 'عنصر متقدم', this.kind});

  final String html;
  final String label;
  final String? kind;

  factory RawBlock.fromJson(Map j) => RawBlock(
        html: (j['html'] as String?) ?? '',
        label: (j['label'] as String?) ?? 'عنصر متقدم',
        kind: j['kind'] as String?,
      );

  @override
  Map<String, dynamic> toJson() => {
        't': 'raw',
        'html': html,
        'label': label,
        if (kind != null) 'kind': kind,
      };
}

List<RBlock> blocksFromJson(List<dynamic> list) {
  final out = <RBlock>[];
  for (final j in list) {
    if (j is! Map) continue;
    switch (j['t']) {
      case 'p':
        out.add(ParaBlock.fromJson(j));
      case 'img':
        out.add(ImageBlock.fromJson(j));
      case 'table':
        out.add(TableBlock.fromJson(j));
      case 'raw':
        out.add(RawBlock.fromJson(j));
    }
  }
  return out;
}

List<Map<String, dynamic>> blocksToJson(List<RBlock> blocks) => [for (final b in blocks) b.toJson()];

String blocksSnapshot(List<RBlock> blocks) => jsonEncode(blocksToJson(blocks));

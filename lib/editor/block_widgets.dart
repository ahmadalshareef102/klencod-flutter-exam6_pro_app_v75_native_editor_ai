import 'package:flutter/material.dart';

import '../theme.dart';
import 'rich_model.dart';

/// ما تحتاجه عناصر الكتل من الشاشة المضيفة.
abstract class EditorHost {
  bool isImageSelected(ImageBlock b);
  bool isTableSelected(TableBlock t);
  void onParaChanged(ParaBlock b);
  void onSelectImage(ImageBlock b);
  void onSelectTable(TableBlock t);
  void onDeleteBlock(RBlock b);
}

const TextStyle kEditorText = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 17,
  height: 1.7,
  color: AppColors.ink,
);

/// يبني عناصر قائمة كتل مع ترقيم القوائم المرقّمة المتتالية.
List<Widget> buildBlockList(List<RBlock> blocks, EditorHost host, {bool inCell = false}) {
  final out = <Widget>[];
  var counter = 0;
  for (final b in blocks) {
    if (b is ParaBlock && b.list == 'ol') {
      counter++;
    } else {
      counter = 0;
    }
    out.add(buildBlockWidget(b, host, number: counter, inCell: inCell));
  }
  return out;
}

Widget buildBlockWidget(RBlock b, EditorHost host, {int number = 0, bool inCell = false}) {
  if (b is ParaBlock) return ParaEditor(key: b.key, block: b, host: host, number: number, inCell: inCell);
  if (b is ImageBlock) return ImageBlockView(key: b.key, block: b, host: host);
  if (b is TableBlock) return TableBlockView(key: b.key, block: b, host: host);
  if (b is RawBlock) return RawBlockView(key: b.key, block: b, host: host);
  return const SizedBox.shrink();
}

// ====================================================================== فقرة

class ParaEditor extends StatelessWidget {
  const ParaEditor({
    super.key,
    required this.block,
    required this.host,
    this.number = 0,
    this.inCell = false,
  });

  final ParaBlock block;
  final EditorHost host;
  final int number;
  final bool inCell;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final align = switch (b.align) {
      'center' => TextAlign.center,
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      'justify' => TextAlign.justify,
      _ => TextAlign.start,
    };
    final field = TextField(
      controller: b.c,
      focusNode: b.focus,
      maxLines: null,
      minLines: 1,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlign: align,
      style: kEditorText,
      cursorColor: AppColors.maroon,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(vertical: inCell ? 4 : 7, horizontal: 2),
        hintText: inCell ? null : 'اكتب هنا…',
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, color: Color(0xFFB9A9AE)),
      ),
      onChanged: (_) => host.onParaChanged(b),
    );
    final marker = b.list == 'ul' ? '•' : (b.list == 'ol' ? '$number.' : null);
    Widget content = marker == null
        ? field
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(marker,
                      textAlign: TextAlign.center,
                      style: kEditorText.copyWith(color: AppColors.maroon)),
                ),
              ),
              Expanded(child: field),
            ],
          );
    if (b.box) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.ink, width: 1.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: content,
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(start: b.indent * 24.0, top: b.box ? 4 : 0, bottom: b.box ? 4 : 0),
      child: content,
    );
  }
}

// ====================================================================== صورة

class ImageBlockView extends StatelessWidget {
  const ImageBlockView({super.key, required this.block, required this.host});

  final ImageBlock block;
  final EditorHost host;

  @override
  Widget build(BuildContext context) {
    final b = block;
    final selected = host.isImageSelected(b);
    final align = switch (b.wrap) {
      'wrap-tight-right' => Alignment.centerRight,
      'wrap-tight-left' => Alignment.centerLeft,
      _ => Alignment.center,
    };
    Widget image = b.bytes == null
        ? const SizedBox(
            height: 80,
            child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.muted)),
          )
        : Image.memory(b.bytes!,
            fit: b.shape == 'img-circle' ? BoxFit.cover : BoxFit.contain, gaplessPlayback: true);
    switch (b.shape) {
      case 'img-circle':
        image = ClipOval(child: AspectRatio(aspectRatio: 1, child: image));
      case 'img-rounded':
        image = Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: BorderRadius.circular(14),
          ),
          clipBehavior: Clip.antiAlias,
          child: image,
        );
      case 'img-square':
        image = DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 2)),
          child: image,
        );
      case 'img-double':
        image = DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.ink, width: 4)),
          child: image,
        );
      case 'img-dashed':
        image = DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.muted, width: 2)),
          child: image,
        );
    }
    final stack = Stack(
      children: [
        image,
        for (final a in b.arrows)
          Positioned.fill(
            child: Align(
              alignment: Alignment((a.x / 50 - 1).clamp(-1.0, 1.0).toDouble(),
                  (a.y / 50 - 1).clamp(-1.0, 1.0).toDouble()),
              child: Text(
                '${a.dir}${a.label}',
                style: TextStyle(
                    fontSize: 20, color: parseHexColor(a.color) ?? Colors.red, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Align(
            alignment: align,
            child: FractionallySizedBox(
              widthFactor: b.widthFactor,
              child: GestureDetector(
                onTap: () => host.onSelectImage(b),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? AppColors.maroon : Colors.transparent,
                      width: 2.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: stack,
                ),
              ),
            ),
          ),
          if (b.wrap == 'wrap-front')
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('أمام النص (يظهر موضعها في الورقة)',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

// ====================================================================== جدول

class TableBlockView extends StatelessWidget {
  const TableBlockView({super.key, required this.block, required this.host});

  final TableBlock block;
  final EditorHost host;

  @override
  Widget build(BuildContext context) {
    final t = block;
    final selected = host.isTableSelected(t);
    final cols = t.colCount;
    final headRow = t.rows.isNotEmpty && t.rows.first.isNotEmpty && t.rows.first.every((c) => c.th);
    final border = t.borderless
        ? TableBorder.all(color: AppColors.border, width: 1)
        : TableBorder.all(color: AppColors.ink, width: 1.2);
    final table = Table(
      border: border,
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (var r = 0; r < t.rows.length; r++)
          TableRow(
            decoration: (r == 0 && headRow) ? const BoxDecoration(color: Color(0xFFF1EBE0)) : null,
            children: [
              for (var c = 0; c < cols; c++)
                if (c < t.rows[r].length)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: buildBlockList(t.rows[r][c].blocks, host, inCell: true),
                    ),
                  )
                else
                  const SizedBox(height: 40),
            ],
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => host.onSelectTable(t),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.table_chart_outlined,
                      size: 16, color: selected ? AppColors.maroon : AppColors.muted),
                  const SizedBox(width: 6),
                  Text('جدول ${t.rows.length}×$cols${t.complex ? ' (خلايا مدموجة)' : ''}',
                      style: TextStyle(
                          fontSize: 12.5, color: selected ? AppColors.maroon : AppColors.muted)),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: selected ? AppColors.maroon : Colors.transparent, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: table,
          ),
        ],
      ),
    );
  }
}

// ====================================================================== خام

class RawBlockView extends StatelessWidget {
  const RawBlockView({super.key, required this.block, required this.host});

  final RawBlock block;
  final EditorHost host;

  @override
  Widget build(BuildContext context) {
    if (block.kind == 'hr') {
      return GestureDetector(
        onLongPress: () => host.onDeleteBlock(block),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, thickness: 1.5, color: AppColors.ink),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chipPurple,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.extension_outlined, color: AppColors.iconPurple, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${block.label} (يُحفظ كما هو)',
                style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => host.onDeleteBlock(block),
            icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../math_data.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/ui.dart';

final List<String> _recent = [];

/// لوحة الرياضيات: رموز بالعربية، قوالب (كسر/جذر/أس…)، وقوانين جاهزة.
Future<void> showMathSheet(BuildContext context, Future<void> Function(String html) onInsert,
    {MathMode mode = MathMode.symbols}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.66,
      child: _MathSheet(onInsert: onInsert, initialMode: mode),
    ),
  );
}


/// حوار إدخال قيم قالب رياضي ثم إدراجه في نص السؤال.
Future<void> runMathBuilder(BuildContext context, Future<void> Function(String html) onInsert, MathBuilder b) async {
  final ctls = [for (final _ in b.fields) TextEditingController()];
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(b.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < b.fields.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextField(
                  controller: ctls[i],
                  autofocus: i == 0,
                  decoration: softDecoration(b.fields[i]),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true), child: const Text('إدراج')),
      ],
    ),
  );
  final values = [for (final c in ctls) c.text.trim()];
  // لا نتخلص من المتحكمات هنا: حركة إغلاق الحوار قد تستخدمها بعد عودة الدالة.
  if (ok == true && values.any((v) => v.isNotEmpty)) {
    await onInsert('${b.build(values)}&nbsp;');
  }
}


enum MathMode { symbols, builders, formulas }

class _MathSheet extends StatefulWidget {
  const _MathSheet({required this.onInsert, required this.initialMode});
  final Future<void> Function(String html) onInsert;
  final MathMode initialMode;

  @override
  State<_MathSheet> createState() => _MathSheetState();
}

class _MathSheetState extends State<_MathSheet> {
  late MathMode _mode = widget.initialMode;
  int _cat = 0;

  Future<void> _insertSymbol(String sym) async {
    _recent.remove(sym);
    _recent.insert(0, sym);
    if (_recent.length > 14) _recent.removeLast();
    setState(() {});
    await widget.onInsert(esc(sym));
  }

  Future<void> _insertHtml(String html) => widget.onInsert('$html&nbsp;');

  Future<void> _runBuilder(MathBuilder b) => runMathBuilder(context, widget.onInsert, b);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.functions, color: AppColors.maroon),
              const SizedBox(width: 8),
              const Text('الرياضيات',
                  style: TextStyle(fontSize: 20, color: AppColors.ink)),
              const Spacer(),
              const Text('ضع المؤشر في النص ثم اختر',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SoftSegmented<MathMode>(
            value: _mode,
            items: const [
              (MathMode.symbols, 'الرموز'),
              (MathMode.builders, 'القوالب'),
              (MathMode.formulas, 'القوانين'),
            ],
            onChanged: (m) => setState(() => _mode = m),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (_mode) {
            MathMode.symbols => _symbols(),
            MathMode.builders => _builders(),
            MathMode.formulas => _formulas(),
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- الرموز

  Widget _symbols() {
    final cat = kMathCategories[_cat];
    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kMathCategories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final sel = i == _cat;
              return ChoiceChip(
                label: Text(kMathCategories[i].title),
                selected: sel,
                showCheckmark: false,
                selectedColor: AppColors.pink,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                labelStyle: TextStyle(
                    fontSize: 13, color: sel ? AppColors.maroon : AppColors.muted),
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() => _cat = i),
              );
            },
          ),
        ),
        if (_recent.isNotEmpty)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              itemCount: _recent.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => i == 0
                  ? const Center(
                      child: Text('الأخيرة',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)))
                  : _cell(_recent[i - 1], false, 40),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: cat.wide ? 84 : 56,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: cat.items.length,
            itemBuilder: (_, i) => _cell(cat.items[i], cat.wide, null),
          ),
        ),
      ],
    );
  }

  Widget _cell(String sym, bool wide, double? width) {
    return Tooltip(
      message: kMathNames[sym] ?? sym,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _insertSymbol(sym),
        child: Container(
          width: width,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            sym,
            style: TextStyle(fontSize: wide ? 16 : 22, color: AppColors.ink),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- القوالب

  Widget _builders() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: kMathBuilders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = kMathBuilders[i];
        return SoftCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _runBuilder(b),
          child: Row(
            children: [
              Icon(b.icon, color: AppColors.maroon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(b.title,
                    style: const TextStyle(fontSize: 16, color: AppColors.ink)),
              ),
              Text(b.preview,
                  style: const TextStyle(fontSize: 18, color: AppColors.muted)),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------- القوانين

  Widget _formulas() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: kMathFormulas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final f = kMathFormulas[i];
        return SoftCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          onTap: () => _insertHtml(f.$2),
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline, color: AppColors.maroon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(f.$1,
                    style: const TextStyle(fontSize: 16, color: AppColors.ink)),
              ),
            ],
          ),
        );
      },
    );
  }
}

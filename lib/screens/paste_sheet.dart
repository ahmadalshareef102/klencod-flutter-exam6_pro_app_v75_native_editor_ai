import 'package:flutter/material.dart';

import '../engine_api.dart';
import '../theme.dart';

/// لصق جماعي: لصق نص ← تحليل ← معاينة ← إضافة الأسئلة للاختبار.
class PasteSheet extends StatefulWidget {
  const PasteSheet({super.key, required this.api, required this.onDone});

  final EngineApi api;
  final VoidCallback onDone;

  @override
  State<PasteSheet> createState() => _PasteSheetState();
}

class _PasteSheetState extends State<PasteSheet> {
  final TextEditingController _text = TextEditingController();
  List<Map<String, dynamic>> _parsed = const [];
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await widget.api.analyzePaste(_text.text);
    if (!mounted) return;
    setState(() {
      _parsed = r;
      _busy = false;
    });
  }

  Future<void> _confirm() async {
    await widget.api.confirmPaste();
    if (!mounted) return;
    Navigator.pop(context);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لصق أسئلة جماعي',
                style: TextStyle(fontSize: 22, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('الصق النص، وتبدأ كل سؤال بـ «السؤال الأول:» أو «س1:» أو «Q1:»',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 6,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: 'الصق الأسئلة هنا...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _analyze,
                    icon: const Icon(Icons.search),
                    label: const Text('تحليل'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.pink,
                      foregroundColor: AppColors.maroon,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _parsed.isEmpty ? null : _confirm,
                    icon: const Icon(Icons.add),
                    label: Text('إضافة (${_parsed.length})'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_parsed.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final q in _parsed)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${q['name'] ?? ''}: ${q['subtitle'] ?? ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${q['lines'] ?? 0} سطر',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

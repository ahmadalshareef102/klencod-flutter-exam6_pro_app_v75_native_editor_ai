import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../exam_store.dart';
import '../exam_summary.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
    required this.store,
    required this.tick,
    required this.onOpen,
    required this.onDelete,
  });

  final Future<ExamStore> store;

  /// يتغير رقمه لإعادة تحميل القائمة (عند فتح التبويب أو بعد حذف/استعادة).
  final int tick;
  final void Function(String id) onOpen;
  final Future<void> Function(ExamSummary exam) onDelete;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<ExamSummary> _all = const [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SavedScreen old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  Future<void> _load() async {
    final store = await widget.store;
    final ids = await store.listIds();
    final out = <ExamSummary>[];
    for (final id in ids) {
      final raw = await store.readExam(id);
      if (raw == null) continue;
      final s = await compute(parseExamSummary, raw);
      if (s != null) out.add(s);
    }
    out.sort((a, b) {
      final x = a.updatedAt, y = b.updatedAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    if (!mounted) return;
    setState(() {
      _all = out;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final shown = q.isEmpty
        ? _all
        : _all
            .where((e) =>
                e.title.contains(q) || e.subject.contains(q) || e.grade.contains(q))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الاختبارات المحفوظة',
                  style: TextStyle(fontSize: 24, color: AppColors.ink)),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'بحث بالعنوان أو المادة أو الصف',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.maroon),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : shown.isEmpty
                  ? const Center(
                      child: Text('لا توجد اختبارات محفوظة',
                          style: TextStyle(fontSize: 18, color: AppColors.muted)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ExamTile(
                        exam: shown[i],
                        onOpen: () => widget.onOpen(shown[i].id),
                        onDelete: () => widget.onDelete(shown[i]),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.exam,
    required this.onOpen,
    required this.onDelete,
  });

  final ExamSummary exam;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (exam.subject.trim().isNotEmpty) exam.subject,
      if (exam.grade.trim().isNotEmpty) exam.grade,
    ].join(' • ');
    return SoftCard(
      radius: 26,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exam.title.trim().isEmpty ? 'اختبار بلا عنوان' : exam.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, color: AppColors.ink)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(meta,
                style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
          if (exam.updatedAt != null) ...[
            const SizedBox(height: 2),
            Text(formatYmd(exam.updatedAt!),
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: AppColors.maroon,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('فتح وتعديل'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onDelete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text('حذف'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

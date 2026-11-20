import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai_prompt.dart';
import '../engine_api.dart';
import '../exam_summary.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/ui.dart';

enum _Step { prompt, paste }

/// إنشاء اختبار تلقائياً: تعليمات جاهزة للذكاء الاصطناعي ← لصق النتيجة ← بناء الاختبار.
class AiExamSheet extends StatefulWidget {
  const AiExamSheet({super.key, required this.api, required this.onDone});

  final EngineApi api;
  final void Function(Map<String, dynamic> result) onDone;

  @override
  State<AiExamSheet> createState() => _AiExamSheetState();
}

class _AiExamSheetState extends State<AiExamSheet> {
  _Step _step = _Step.prompt;

  final _subject = TextEditingController();
  final _grade = TextEditingController();
  final _semester = TextEditingController();
  final _lessons = TextEditingController();
  final _total = TextEditingController(text: '40');
  final _duration = TextEditingController(text: '40');
  String _difficulty = 'متوسط';
  final Set<String> _types = {'mcq', 'tf', 'fill', 'essay'};
  int _perQuestion = 5;
  bool _english = false;

  final _text = TextEditingController();
  Map<String, dynamic>? _summary;
  bool _busy = false;

  bool _autoScores = true, _replace = true, _fillMeta = true, _essayLines = true;

  @override
  void dispose() {
    for (final c in [_subject, _grade, _semester, _lessons, _total, _duration, _text]) {
      c.dispose();
    }
    super.dispose();
  }

  AiPromptOptions get _options => AiPromptOptions(
        subject: _subject.text,
        grade: _grade.text,
        semester: _semester.text,
        lessons: _lessons.text,
        total: int.tryParse(_total.text.trim()) ?? 40,
        duration: int.tryParse(_duration.text.trim()) ?? 40,
        difficulty: _difficulty,
        types: _types,
        perQuestion: _perQuestion,
        english: _english,
      );

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(ClipboardData(text: buildAiPrompt(_options)));
    _toast('تم نسخ التعليمات. الصقها في ChatGPT أو Claude أو Gemini ثم انسخ الناتج');
    setState(() => _step = _Step.paste);
  }

  Future<void> _pasteFromClipboard() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text == null || d!.text!.isEmpty) return _toast('الحافظة فارغة');
    _text.text = d.text!;
    await _analyze();
  }

  Future<void> _analyze() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final r = await widget.api.aiParse(_text.text);
    if (!mounted) return;
    setState(() {
      _summary = r;
      _busy = false;
    });
    final qs = (r?['questions'] as List?) ?? const [];
    if (qs.isEmpty) _toast('لم أجد أسئلة في النص. تأكد أنه بالصيغة المطلوبة');
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final r = await widget.api.aiImport({
      'autoScores': _autoScores,
      'replace': _replace,
      'fillMeta': _fillMeta,
      'essayLines': _essayLines,
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (r == null) return _toast('تعذر إنشاء الاختبار');
    Navigator.pop(context);
    widget.onDone(r);
  }

  // ------------------------------------------------------------------ واجهة

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.maroon),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('إنشاء اختبار بالذكاء الاصطناعي',
                      style: TextStyle(fontSize: 20, color: AppColors.ink)),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SoftSegmented<_Step>(
              value: _step,
              items: const [(_Step.prompt, '١  التعليمات'), (_Step.paste, '٢  لصق النتيجة')],
              onChanged: (s) => setState(() => _step = s),
            ),
          ),
          Expanded(child: _step == _Step.prompt ? _promptStep() : _pasteStep()),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type, int lines = 1}) =>
      TextField(
        controller: c,
        keyboardType: type,
        minLines: lines,
        maxLines: lines,
        decoration: softDecoration(label),
        onChanged: (_) => setState(() {}),
      );

  Widget _promptStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const SectionCaption('أخبر الذكاء الاصطناعي بما تريد'),
        Row(children: [
          Expanded(child: _field(_subject, 'المادة')),
          const SizedBox(width: 10),
          Expanded(child: _field(_grade, 'الصف')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _field(_semester, 'الفصل (اختياري)')),
          const SizedBox(width: 10),
          Expanded(child: _field(_total, 'الدرجة النهائية', type: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: _field(_duration, 'الزمن (دقيقة)', type: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        _field(_lessons, 'الدروس أو الوحدات المشمولة (اختياري)', lines: 2),
        const SectionCaption('مستوى الصعوبة'),
        SoftSegmented<String>(
          value: _difficulty,
          items: const [('سهل', 'سهل'), ('متوسط', 'متوسط'), ('صعب', 'صعب')],
          onChanged: (v) => setState(() => _difficulty = v),
        ),
        const SectionCaption('أنواع الأسئلة'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in kAiTypeNames.entries)
              FilterChip(
                label: Text(e.value),
                selected: _types.contains(e.key),
                selectedColor: AppColors.pink,
                checkmarkColor: AppColors.maroon,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                shape: const StadiumBorder(),
                onSelected: (on) => setState(() {
                  if (on) {
                    _types.add(e.key);
                  } else if (_types.length > 1) {
                    _types.remove(e.key);
                  }
                }),
              ),
          ],
        ),
        const SectionCaption('عدد الفقرات في كل سؤال'),
        SoftCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(children: [
            IconButton(
                onPressed: _perQuestion > 2 ? () => setState(() => _perQuestion--) : null,
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.maroon)),
            Expanded(
                child: Center(
                    child: Text('$_perQuestion',
                        style: const TextStyle(fontSize: 20, color: AppColors.ink)))),
            IconButton(
                onPressed: _perQuestion < 12 ? () => setState(() => _perQuestion++) : null,
                icon: const Icon(Icons.add_circle_outline, color: AppColors.maroon)),
          ]),
        ),
        const SectionCaption('لغة الاختبار'),
        SoftSegmented<bool>(
          value: _english,
          items: const [(false, 'العربية'), (true, 'English')],
          onChanged: (v) => setState(() => _english = v),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _copyPrompt,
          icon: const Icon(Icons.copy_all_outlined),
          label: const Text('نسخ التعليمات'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.maroon,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'الصق التعليمات في أي مساعد ذكاء اصطناعي، ثم عُد وانسخ ناتجه والصقه في الخطوة ٢.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('معاينة التعليمات', style: TextStyle(fontSize: 14)),
            children: [
              SoftCard(
                radius: 16,
                child: SelectableText(buildAiPrompt(_options),
                    style: const TextStyle(fontSize: 12.5, height: 1.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pasteStep() {
    final qs = ((_summary?['questions'] as List?) ?? const []).whereType<Map>().toList();
    final meta = (_summary?['meta'] as Map?) ?? const {};
    final target = _summary?['target'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const SectionCaption('الصق ما أنتجه الذكاء الاصطناعي'),
        TextField(
          controller: _text,
          minLines: 6,
          maxLines: 10,
          decoration: softDecoration('النص الناتج').copyWith(alignLabelWithHint: true),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste),
              label: const Text('لصق وتحليل'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.maroon,
                shape: const StadiumBorder(),
                side: const BorderSide(color: Color(0x808B4A5E)),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
        ]),
        if (qs.isNotEmpty) ...[
          const SectionCaption('ما وجدته في النص'),
          if (meta.isNotEmpty)
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final e in meta.entries)
                    Text('${_metaLabel(e.key.toString())}: ${e.value}',
                        style: const TextStyle(fontSize: 13, color: AppColors.ink)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < qs.length; i++) ...[
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration:
                      const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 13, color: AppColors.maroon)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${qs[i]['label']} • ${qs[i]['items']} فقرة'
                          '${qs[i]['score'] != null ? ' • ${fmtNum(qs[i]['score'] as num)} درجة' : ''}',
                          style: const TextStyle(fontSize: 14.5, color: AppColors.ink)),
                      Text('${qs[i]['sample'] ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          const SectionCaption('خيارات الإنشاء'),
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(children: [
              SoftSwitchRow(
                title: 'توزيع الدرجات تلقائياً${target is num && target > 0 ? ' (من ${fmtNum(target)})' : ''}',
                value: _autoScores,
                onChanged: (v) => setState(() => _autoScores = v),
              ),
              SoftSwitchRow(
                title: 'استبدال الأسئلة الحالية',
                value: _replace,
                onChanged: (v) => setState(() => _replace = v),
              ),
              SoftSwitchRow(
                title: 'تعبئة بيانات الرأس من النص',
                value: _fillMeta,
                onChanged: (v) => setState(() => _fillMeta = v),
              ),
              SoftSwitchRow(
                title: 'أسطر إجابة للأسئلة المقالية',
                value: _essayLines,
                onChanged: (v) => setState(() => _essayLines = v),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.auto_awesome),
            label: Text('إنشاء الاختبار (${qs.length} أسئلة)'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.maroon,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
          ),
          if (((_summary?['ignored'] as num?) ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('تم تجاهل نموذج الإجابات (${_summary!['ignored']} سطر) فلن يظهر في الورقة.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
        ],
      ],
    );
  }

  String _metaLabel(String k) => const {
        'subject': 'المادة',
        'grade': 'الصف',
        'semester': 'الفصل',
        'year': 'العام',
        'title': 'العنوان',
        'duration': 'الزمن',
        'maxscore': 'الدرجة',
        'school': 'المدرسة',
        'teacher': 'المعلم',
        'notes': 'ملاحظات',
        'ministry': 'الوزارة',
        'governorate': 'المحافظة',
        'directorate': 'المديرية',
      }[k] ??
      k;
}

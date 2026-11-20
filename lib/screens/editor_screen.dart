import 'package:flutter/material.dart';

import '../editor_data.dart';
import '../engine_api.dart';
import '../exam_summary.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';
import '../widgets/ui.dart';

const List<(String, String)> kMetaFields = [
  ('republic', 'الدولة / الجمهورية'),
  ('ministry', 'الوزارة'),
  ('governorate', 'المحافظة'),
  ('directorate', 'المديرية'),
  ('school', 'اسم المدرسة'),
  ('grade', 'الصف الدراسي'),
  ('subject', 'المادة'),
  ('semester', 'الفصل الدراسي'),
  ('year', 'العام الدراسي'),
  ('title', 'عنوان الاختبار'),
  ('duration', 'الزمن'),
  ('teacher', 'مدرس المادة'),
  ('maxscore', 'الدرجة النهائية'),
  ('notes', 'ملاحظات وتعليمات'),
];

const List<(String, String)> kVisibilityFields = [
  ('studentBar', 'شريط اسم الطالب والشعبة'),
  ('officialHeader', 'كليشة الترويسة كاملة'),
  ('bismillah', 'البسملة'),
  ('logo', 'الشعار'),
  ('govDir', 'المحافظة والمديرية'),
  ('tableHead', 'عناوين أعمدة الجدول'),
  ('footer', 'تذييل المعلم'),
];

const List<(String, String, IconData)> kQuestionTypes = [
  ('essay', 'مقالي', Icons.notes),
  ('mcq', 'اختيار متعدد', Icons.checklist),
  ('tf', 'صح وخطأ', Icons.rule),
  ('fill', 'أكمل الفراغات', Icons.more_horiz),
  ('match', 'التوصيل', Icons.swap_horiz),
  ('table', 'سؤال جدول', Icons.table_chart_outlined),
  ('image', 'صورة حرة', Icons.image_outlined),
  ('image-grid', 'شبكة صور', Icons.grid_view),
];

const List<(String, String)> kTableModes = [
  ('mode-grid', 'شبكة كاملة'),
  ('mode-horizontal', 'خطوط أفقية'),
  ('mode-outer-only', 'إطار خارجي فقط'),
  ('mode-borderless', 'بدون حدود'),
];

enum _Pane { questions, header, paper }

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.api,
    required this.tick,
    required this.onPreview,
    required this.onPaste,
    required this.onNewExam,
    required this.onEditQuestion,
    required this.onOpenTemplates,
    required this.onAiExam,
  });

  final EngineApi api;

  /// يتغير رقمه لإعادة قراءة الحالة من المحرك.
  final int tick;
  final VoidCallback onPreview;
  final VoidCallback onPaste;
  final VoidCallback onNewExam;
  final void Function(String qid, String name) onEditQuestion;
  final VoidCallback onOpenTemplates;
  final VoidCallback onAiExam;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorData? _d;
  bool _loading = true;
  _Pane _pane = _Pane.questions;
  Sums _sums = const Sums(sum: 0, target: 0, match: false);
  final Map<String, TextEditingController> _meta = {};
  final Map<String, TextEditingController> _q = {};
  final Set<String> _subOpen = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EditorScreen old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  @override
  void dispose() {
    for (final c in [..._meta.values, ..._q.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _put(Map<String, TextEditingController> m, String key, String value) {
    final c = m[key];
    if (c == null) {
      m[key] = TextEditingController(text: value);
    } else if (c.text != value) {
      c.text = value;
    }
  }

  Future<void> _load() async {
    final d = await widget.api.editorState();
    if (!mounted) return;
    if (d != null) {
      d.meta.forEach((k, v) => _put(_meta, k, v));
      for (final q in d.questions) {
        _put(_q, '${q.id}|name', q.name);
        _put(_q, '${q.id}|score', fmtNum(q.score));
        _put(_q, '${q.id}|subtitle', q.subtitle);
      }
      final ids = d.questions.map((q) => q.id).toSet();
      _q.removeWhere((k, c) {
        final drop = !ids.contains(k.split('|').first);
        if (drop) c.dispose();
        return drop;
      });
    }
    setState(() {
      _d = d;
      _loading = false;
      if (d != null) _sums = d.sums;
    });
  }

  Future<void> _then(Future<void> Function() op) async {
    await op();
    await _load();
  }

  // ---------------------------------------------------------------- إضافة سؤال

  Future<void> _addQuestion() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('نوع السؤال',
                  style: TextStyle(fontSize: 20, color: AppColors.ink)),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.7,
                children: [
                  for (final t in kQuestionTypes)
                    SoftCard(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      onTap: () => Navigator.pop(ctx, t.$1),
                      child: Row(
                        children: [
                          Icon(t.$3, color: AppColors.maroon, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(t.$2,
                                style: const TextStyle(
                                    fontSize: 15, color: AppColors.ink)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;
    await _then(() => widget.api.addQuestion(type));
  }

  Future<void> _deleteQuestion(int idx, QuestionItem q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السؤال'),
        content: Text('هل تريد حذف «${q.name}»؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حذف')),
        ],
      ),
    );
    if (ok == true) await _then(() => widget.api.remove(idx));
  }

  // -------------------------------------------------------------------- البناء

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('المحرك لم يجهز بعد',
                style: TextStyle(fontSize: 16, color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
          ],
        ),
      );
    }
    return Stack(
      children: [
        Column(
          children: [
            _topBar(d),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _scoreStrip(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SoftSegmented<_Pane>(
                value: _pane,
                items: const [
                  (_Pane.questions, 'الأسئلة'),
                  (_Pane.header, 'بيانات الرأس'),
                  (_Pane.paper, 'الورقة'),
                ],
                onChanged: (p) => setState(() => _pane = p),
              ),
            ),
            Expanded(
              child: switch (_pane) {
                _Pane.questions => _questionsPane(d),
                _Pane.header => _headerPane(d),
                _Pane.paper => _paperPane(d),
              },
            ),
          ],
        ),
        if (_pane == _Pane.questions)
          PositionedDirectional(
            end: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: _addQuestion,
              backgroundColor: AppColors.maroon,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add),
              label: const Text('سؤال'),
            ),
          ),
      ],
    );
  }

  Widget _topBar(EditorData d) {
    final title = (_meta['title']?.text ?? '').trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المحرر',
                    style: TextStyle(fontSize: 24, color: AppColors.ink)),
                Text(title.isEmpty ? 'اختبار بلا عنوان' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'معاينة الورقة',
            onPressed: widget.onPreview,
            icon: const Icon(Icons.visibility_outlined, color: AppColors.maroon),
          ),
          IconButton(
            tooltip: 'لصق أسئلة',
            onPressed: widget.onPaste,
            icon: const Icon(Icons.content_paste, color: AppColors.maroon),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.maroon),
            onSelected: (v) {
              if (v == 'lang') _then(widget.api.toggleLang);
              if (v == 'new') widget.onNewExam();
              if (v == 'ai') widget.onAiExam();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'lang',
                child: Text(d.lang == 'en' ? 'تحويل للعربية' : 'تحويل للإنجليزية (EN)'),
              ),
              const PopupMenuItem(value: 'ai', child: Text('إنشاء بالذكاء الاصطناعي')),
              const PopupMenuItem(value: 'new', child: Text('اختبار جديد')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreStrip() {
    final ok = _sums.match;
    final ratio = _sums.target > 0
        ? (_sums.sum / _sums.target).clamp(0.0, 1.0).toDouble()
        : 0.0;
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Text('المجموع',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(width: 8),
              Text('${fmtNum(_sums.sum)} / ${fmtNum(_sums.target)}',
                  style: const TextStyle(fontSize: 20, color: AppColors.ink)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ok ? AppColors.chipTeal : AppColors.pink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(_sums.badge,
                    style: TextStyle(
                        fontSize: 12,
                        color: ok ? AppColors.iconTeal : AppColors.danger)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: ok ? AppColors.iconTeal : AppColors.maroon,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ الأسئلة

  Widget _questionsPane(EditorData d) {
    if (d.questions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, size: 56, color: AppColors.border),
              const SizedBox(height: 10),
              const Text('لا توجد أسئلة بعد',
                  style: TextStyle(fontSize: 18, color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text('اضغط «سؤال» لإضافة أول سؤال',
                  style: TextStyle(fontSize: 14, color: AppColors.muted)),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      children: [
        SectionCaption('${d.questions.length} أسئلة'),
        for (var i = 0; i < d.questions.length; i++) ...[
          _questionCard(i, d.questions[i], d.questions.length),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _questionCard(int idx, QuestionItem q, int total) {
    final subVisible = q.subtitle.trim().isNotEmpty || _subOpen.contains(q.id);
    return SoftCard(
      key: ValueKey(q.id),
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: AppColors.pink, shape: BoxShape.circle),
                child: Text('${idx + 1}',
                    style: const TextStyle(fontSize: 14, color: AppColors.maroon)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _q['${q.id}|name'],
                  style: const TextStyle(fontSize: 17, color: AppColors.ink),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'اسم السؤال',
                  ),
                  onChanged: (v) => widget.api.setQuestion(idx, 'name', v),
                ),
              ),
              SizedBox(
                width: 78,
                child: TextField(
                  controller: _q['${q.id}|score'],
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: softDecoration('الدرجة'),
                  onChanged: (v) async {
                    final s = await widget.api.setQuestion(idx, 'score', v);
                    if (s != null && mounted) setState(() => _sums = s);
                  },
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.muted),
                onSelected: (v) {
                  if (v == 'up') _then(() => widget.api.move(idx, -1));
                  if (v == 'down') _then(() => widget.api.move(idx, 1));
                  if (v == 'copy') _then(() => widget.api.duplicate(idx));
                  if (v == 'delete') _deleteQuestion(idx, q);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'up', enabled: idx > 0, child: const Text('نقل للأعلى')),
                  PopupMenuItem(
                      value: 'down',
                      enabled: idx < total - 1,
                      child: const Text('نقل للأسفل')),
                  const PopupMenuItem(value: 'copy', child: Text('نسخ السؤال')),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ],
          ),
          if (subVisible)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: TextField(
                controller: _q['${q.id}|subtitle'],
                decoration: softDecoration('عنوان فرعي'),
                onChanged: (v) => widget.api.setQuestion(idx, 'subtitle', v),
              ),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => setState(() => _subOpen.add(q.id)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('عنوان فرعي'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: InkWell(
              onTap: () => widget.onEditQuestion(q.id, q.name),
              child: Text(
                q.text.isEmpty ? '(نص السؤال فارغ)' : q.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.5, color: AppColors.muted),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 10),
            child: Row(
              children: [
                if (q.hasImage)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 8),
                    child: Icon(Icons.image_outlined, size: 18, color: AppColors.muted),
                  ),
                if (q.hasTable)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(end: 8),
                    child: Icon(Icons.table_chart_outlined,
                        size: 18, color: AppColors.muted),
                  ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => widget.onEditQuestion(q.id, q.name),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تحرير النص'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.pink,
                    foregroundColor: AppColors.maroon,
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- بيانات الرأس

  Widget _metaField(String key) {
    final label = kMetaFields.firstWhere((f) => f.$1 == key).$2;
    return TextField(
      controller: _meta[key],
      minLines: key == 'notes' ? 2 : 1,
      maxLines: key == 'notes' ? 4 : 1,
      keyboardType: key == 'maxscore'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: softDecoration(label),
      onChanged: (v) async {
        final s = await widget.api.setMeta(key, v);
        if (s != null && mounted) setState(() => _sums = s);
      },
    );
  }

  Widget _fieldRows(List<String> keys) {
    final rows = <Widget>[];
    for (var i = 0; i < keys.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _metaField(keys[i])),
            const SizedBox(width: 10),
            Expanded(
                child: i + 1 < keys.length ? _metaField(keys[i + 1]) : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _headerPane(EditorData d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const SectionCaption('الترويسة الرسمية'),
        _fieldRows(const ['republic', 'ministry', 'governorate', 'directorate']),
        const SectionCaption('المدرسة والمادة'),
        _fieldRows(const ['school', 'grade', 'subject', 'semester', 'year']),
        const SectionCaption('الاختبار'),
        _fieldRows(const ['title', 'duration', 'maxscore', 'teacher']),
        _metaField('notes'),
        const SectionCaption('عناصر تظهر في الورقة'),
        SoftCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              for (final v in kVisibilityFields)
                SoftSwitchRow(
                  title: v.$2,
                  value: d.visibility[v.$1] ?? true,
                  onChanged: (on) async {
                    await widget.api.setVisibility(v.$1, on);
                    _load();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------- الورقة

  Widget _actionRow(IconData icon, String title, String sub, Future<void> Function() op) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _then(op),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppColors.pink, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: AppColors.maroon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
                  Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _paperPane(EditorData d) {
    final fit = ['fit-1', 'fit-2'].contains(d.pageFit) ? d.pageFit : 'custom';
    final mode =
        kTableModes.any((e) => e.$1 == d.tableMode) ? d.tableMode : 'mode-grid';
    void setSize(double v) =>
        _then(() => widget.api.fontSize(fmtNum(v.clamp(9.0, 24.0).toDouble())));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const SectionCaption('إعدادات سريعة'),
        SoftCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              _actionRow(Icons.format_bold, 'خط عريض 13.5',
                  'يضبط الحجم والسماكة معاً', widget.api.presetBold),
              const Divider(height: 1, color: AppColors.border),
              _actionRow(Icons.water_drop_outlined, 'توسيط العلامة المائية',
                  'وسط الصفحة بحجم مناسب', widget.api.presetWatermark),
            ],
          ),
        ),
        const SectionCaption('ضغط الصفحة'),
        SoftSegmented<String>(
          value: fit,
          items: const [('fit-1', 'صفحة واحدة'), ('fit-2', 'صفحتان'), ('custom', 'مخصص')],
          onChanged: (v) => _then(() => widget.api.pageFit(v)),
        ),
        const SectionCaption('حجم الخط'),
        SoftCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setSize(d.fontSize - 0.5),
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.maroon),
              ),
              Expanded(
                child: Center(
                  child: Text('${fmtNum(d.fontSize)} pt',
                      style: const TextStyle(fontSize: 18, color: AppColors.ink)),
                ),
              ),
              IconButton(
                onPressed: () => setSize(d.fontSize + 0.5),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.maroon),
              ),
            ],
          ),
        ),
        const SectionCaption('حدود الجدول'),
        InputDecorator(
          decoration: softDecoration('نمط الحدود'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: mode,
              isDense: true,
              isExpanded: true,
              items: [
                for (final e in kTableModes)
                  DropdownMenuItem(value: e.$1, child: Text(e.$2)),
              ],
              onChanged: (v) {
                if (v != null) _then(() => widget.api.syncTableMode(v));
              },
            ),
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          onPressed: widget.onOpenTemplates,
          icon: const Icon(Icons.palette_outlined),
          label: const Text('الخطوط والألوان والشعار في «التنسيق»'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.maroon,
            shape: const StadiumBorder(),
            side: const BorderSide(color: Color(0x808B4A5E)),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

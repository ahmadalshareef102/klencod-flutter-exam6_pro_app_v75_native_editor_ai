import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../engine_api.dart';
import '../exam_summary.dart';
import '../theme.dart';
import '../widgets/soft_card.dart';
import 'editor_screen.dart' show kTableModes;

const List<(String, String)> _weights = [
  ('400', 'عادي'),
  ('600', 'شبه عريض'),
  ('700', 'عريض واضح (Bold)'),
];
const List<(String, String)> _lineHeights = [
  ('1.25', 'مضغوط (1.25)'),
  ('1.45', 'متوازن (1.45)'),
  ('1.7', 'واسع (1.7)'),
];
const List<(String, String)> _frames = [
  ('none', 'بدون إطار'),
  ('paper-frame-double', 'إطار مزدوج'),
  ('paper-frame-solid', 'إطار مفرد'),
];
const List<String> _swatches = [
  '#000000',
  '#1b4965',
  '#8b4a5e',
  '#166534',
  '#1d4ed8',
  '#b91c1c',
  '#6b7280',
];

Color _hex(String h) {
  final s = h.replaceAll('#', '');
  final v = int.tryParse(s.length == 6 ? 'FF$s' : s, radix: 16);
  return Color(v ?? 0xFF000000);
}

Uint8List? _bytesOfDataUrl(String url) {
  if (url.isEmpty) return null;
  try {
    return base64Decode(url.substring(url.indexOf(',') + 1));
  } catch (_) {
    return null;
  }
}

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({
    super.key,
    required this.api,
    required this.tick,
    required this.onPickLogo,
    required this.onPickWatermark,
    required this.onPreview,
  });

  final EngineApi api;
  final int tick;
  final Future<void> Function() onPickLogo;
  final Future<void> Function() onPickWatermark;
  final VoidCallback onPreview;

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  final TextEditingController _fs = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TemplatesScreen old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  @override
  void dispose() {
    _fs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await widget.api.designState();
    if (!mounted) return;
    if (d != null) {
      final v = fmtNum((d['fontSize'] as num?) ?? 13.5);
      if (_fs.text != v) _fs.text = v;
    }
    setState(() {
      _d = d;
      _loading = false;
    });
  }

  Future<void> _set(String key, String value) async {
    await widget.api.setDesign(key, value);
    await _load();
  }

  /// بعد اختيار صورة يعالجها المحرك بشكل غير متزامن؛ نعيد القراءة بعد مهلة قصيرة.
  Future<void> _pick(Future<void> Function() pick) async {
    await pick();
    for (final ms in [600, 1800]) {
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (!mounted) return;
      await _load();
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _drop(String label, String value, List<(String, String)> items,
      void Function(String) onChanged) {
    final v = items.any((e) => e.$1 == value) ? value : items.first.$1;
    return InputDecorator(
      decoration: _dec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: v,
          isDense: true,
          isExpanded: true,
          items: [for (final e in items) DropdownMenuItem(value: e.$1, child: Text(e.$2))],
          onChanged: (x) {
            if (x != null) onChanged(x);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _d;
    if (d == null) {
      return Center(
        child: FilledButton(onPressed: _load, child: const Text('المحرك لم يجهز، إعادة المحاولة')),
      );
    }
    String s(String k) => (d[k] ?? '').toString();
    final fonts = (d['fonts'] is List ? d['fonts'] as List : const [])
        .whereType<Map>()
        .map((m) => (m['value'].toString(), m['label'].toString()))
        .toList();
    final color = s('borderColor').toLowerCase();
    final swatches = [if (!_swatches.contains(color)) color, ..._swatches];
    final logo = _bytesOfDataUrl(s('logo'));
    final wm = _bytesOfDataUrl(s('watermark'));
    final opacity = ((d['wmOpacity'] as num?) ?? 8).toDouble().clamp(2, 20).toDouble();
    final scale = ((d['wmScale'] as num?) ?? 75).toDouble().clamp(35, 95).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('التنسيق',
                  style: TextStyle(fontSize: 24, color: AppColors.ink)),
            ),
            FilledButton.icon(
              onPressed: widget.onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('معاينة'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SoftCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: _drop('لغة الاختبار', s('lang'),
                      const [('ar', 'العربية (RTL)'), ('en', 'الإنجليزية (LTR)')],
                      (v) => _set('lang', v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drop('حدود الجدول الرئيسي', s('tableMode'), kTableModes,
                      (v) => _set('tableMode', v)),
                ),
              ]),
              const SizedBox(height: 12),
              _drop('نوع الخط', s('fontFamily'), fonts.isEmpty ? [(s('fontFamily'), 'الخط الحالي')] : fonts,
                  (v) => _set('fontFamily', v)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _fs,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec('حجم الخط (pt)'),
                    onChanged: (v) => widget.api.fontSize(v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drop('سماكة الخط', s('fontWeight'), _weights,
                      (v) => _set('fontWeight', v)),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _drop('تباعد الأسطر', s('lineHeight'), _lineHeights,
                      (v) => _set('lineHeight', v)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _drop('إطار الصفحة A4', s('pageFrame'), _frames,
                      (v) => _set('pageFrame', v)),
                ),
              ]),
              const SizedBox(height: 14),
              const Text('لون الحدود والعناوين',
                  style: TextStyle(fontSize: 15, color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in swatches)
                    GestureDetector(
                      onTap: () => _set('borderColor', c),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _hex(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c == color ? AppColors.maroon : AppColors.border,
                            width: c == color ? 3 : 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('شعار المدرسة / الجمهورية',
                  style: TextStyle(fontSize: 16, color: AppColors.ink)),
              const SizedBox(height: 10),
              Row(children: [
                _thumb(logo),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _pick(widget.onPickLogo),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('اختيار شعار'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await widget.api.removeLogo();
                        _load();
                      },
                      child: const Text('استعادة الافتراضي'),
                    ),
                  ]),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          radius: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('العلامة المائية (وسط الصفحة)',
                  style: TextStyle(fontSize: 16, color: AppColors.ink)),
              const SizedBox(height: 10),
              Row(children: [
                _thumb(wm),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _pick(widget.onPickWatermark),
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('اختيار صورة'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await widget.api.presetWatermark();
                        _load();
                      },
                      child: const Text('ضبط مثالي'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await widget.api.removeWatermark();
                        _load();
                      },
                      child: const Text('حذف'),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Text('الشفافية: ${opacity.round()}%',
                  style: const TextStyle(color: AppColors.muted)),
              Slider(
                value: opacity,
                min: 2,
                max: 20,
                divisions: 18,
                activeColor: AppColors.maroon,
                onChanged: (v) {
                  setState(() => _d = {...d, 'wmOpacity': v.round()});
                  widget.api.wmOpacity(v.round());
                },
              ),
              Text('التمدد: ${scale.round()}%',
                  style: const TextStyle(color: AppColors.muted)),
              Slider(
                value: scale,
                min: 35,
                max: 95,
                divisions: 60,
                activeColor: AppColors.maroon,
                onChanged: (v) {
                  setState(() => _d = {...d, 'wmScale': v.round()});
                  widget.api.wmScale(v.round());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _thumb(Uint8List? bytes) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes == null
            ? const Icon(Icons.image_not_supported_outlined, color: AppColors.muted)
            : Image.memory(bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, color: AppColors.muted)),
      );
}

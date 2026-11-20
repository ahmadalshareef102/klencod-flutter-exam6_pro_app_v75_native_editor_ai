import 'package:flutter/material.dart';

import '../theme.dart';

/// حقل إدخال هادئ: خلفية بيضاء، حد رفيع، زوايا ناعمة.
InputDecoration softDecoration(String label, {String? hint, String? suffix}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    enabledBorder: b(AppColors.border),
    border: b(AppColors.border),
    focusedBorder: b(AppColors.maroon, 1.4),
  );
}

/// عنوان صغير فوق مجموعة عناصر.
class SectionCaption extends StatelessWidget {
  const SectionCaption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      );
}

/// مفتاح تبديل بصف أنيق (عنوان + مفتاح).
class SoftSwitchRow extends StatelessWidget {
  const SoftSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 15, color: AppColors.ink)),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
}

/// تبديل بين أقسام (حبوب بيضاء، المحدد بلون هادئ).
class SoftSegmented<T> extends StatelessWidget {
  const SoftSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(it.$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: it.$1 == value ? AppColors.pink : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    it.$2,
                    style: TextStyle(
                      fontSize: 14,
                      color: it.$1 == value ? AppColors.maroon : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/soft_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onNewExam,
    required this.onPaste,
    required this.onPreview,
    required this.onOpenEditor,
    required this.onOpenTemplates,
    required this.onOpenSaved,
    required this.onOpenSettings,
    required this.onSave,
    required this.onAbout,
    required this.onAiExam,
  });

  final VoidCallback onNewExam;
  final VoidCallback onPaste;
  final VoidCallback onPreview;
  final VoidCallback onOpenEditor;
  final VoidCallback onOpenTemplates;
  final VoidCallback onOpenSaved;
  final VoidCallback onOpenSettings;
  final VoidCallback onSave;
  final VoidCallback onAbout;
  final VoidCallback onAiExam;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeaderCard(onSave: onSave, onAbout: onAbout, onSettings: onOpenSettings),
        const SizedBox(height: 18),
        const _SectionTitle('إجراءات سريعة'),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: onAiExam,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('إنشاء اختبار بالذكاء الاصطناعي'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.maroon,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 17),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onNewExam,
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('اختبار جديد'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: onPaste,
                icon: const Icon(Icons.content_paste),
                label: const Text('لصق أسئلة'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: AppColors.maroon,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onPreview,
          icon: const Icon(Icons.print_outlined),
          label: const Text('معاينة وطباعة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.maroon,
            minimumSize: const Size.fromHeight(50),
            shape: const StadiumBorder(),
            side: const BorderSide(color: Color(0x808B4A5E), width: 1.2),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('الأقسام الرئيسية'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.12,
          children: [
            _SectionCard(
              icon: Icons.edit_note,
              iconColor: AppColors.iconAmber,
              chip: AppColors.chipAmber,
              title: 'إنشاء اختبار',
              subtitle: 'المحرر والأسئلة',
              onTap: onOpenEditor,
            ),
            _SectionCard(
              icon: Icons.palette_outlined,
              iconColor: AppColors.iconPurple,
              chip: AppColors.chipPurple,
              title: 'القوالب والتنسيق',
              subtitle: 'الخطوط والألوان والشعار',
              onTap: onOpenTemplates,
            ),
            _SectionCard(
              icon: Icons.folder_open,
              iconColor: AppColors.iconTeal,
              chip: AppColors.chipTeal,
              title: 'الاختبارات المحفوظة',
              subtitle: 'فتح وتعديل وحذف',
              onTap: onOpenSaved,
            ),
            _SectionCard(
              icon: Icons.settings_outlined,
              iconColor: AppColors.iconBlue,
              chip: AppColors.chipBlue,
              title: 'الإعدادات والنسخ',
              subtitle: 'نسخ احتياطي واستعادة',
              onTap: onOpenSettings,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onSave,
    required this.onAbout,
    required this.onSettings,
  });

  final VoidCallback onSave;
  final VoidCallback onAbout;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 32,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: AppColors.pink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, size: 34, color: AppColors.maroon),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلاً بك',
                    style: TextStyle(fontSize: 24, color: AppColors.ink)),
                SizedBox(height: 4),
                Text('مصمم الاختبارات المدرسية  V7.0',
                    style: TextStyle(fontSize: 15, color: AppColors.muted)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, size: 28, color: AppColors.muted),
            onSelected: (v) {
              if (v == 'save') onSave();
              if (v == 'settings') onSettings();
              if (v == 'about') onAbout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('حفظ الاختبار')),
              PopupMenuItem(value: 'settings', child: Text('الإعدادات والنسخ')),
              PopupMenuItem(value: 'about', child: Text('حول التطبيق')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(text,
            style: const TextStyle(fontSize: 22, color: AppColors.ink)),
      );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.chip,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color chip;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      radius: 30,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: chip,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const Spacer(),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.ink)),
        ],
      ),
    );
  }
}

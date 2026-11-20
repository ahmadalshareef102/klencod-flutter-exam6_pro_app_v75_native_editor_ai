import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/soft_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.onBackup,
    required this.onRestore,
  });

  final Future<void> Function() onBackup;
  final Future<void> Function() onRestore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        title: const Text('الإعدادات والنسخ',
            style: TextStyle(fontSize: 22, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Tile(
            icon: Icons.backup_outlined,
            chip: AppColors.chipBlue,
            color: AppColors.iconBlue,
            title: 'نسخة احتياطية',
            subtitle: 'تصدير كل الاختبارات المحفوظة إلى ملف JSON',
            onTap: onBackup,
          ),
          const SizedBox(height: 12),
          _Tile(
            icon: Icons.restore,
            chip: AppColors.chipTeal,
            color: AppColors.iconTeal,
            title: 'استعادة نسخة',
            subtitle: 'اختيار ملف نسخة احتياطية وإضافة اختباراته',
            onTap: onRestore,
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.chip,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color chip;
  final Color color;
  final String title;
  final String subtitle;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => onTap(),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: chip,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 19, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

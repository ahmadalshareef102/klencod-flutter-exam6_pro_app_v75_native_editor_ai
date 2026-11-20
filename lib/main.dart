import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.cream,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.navBg,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const Exam6App());
}

class Exam6App extends StatelessWidget {
  const Exam6App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مصمم الاختبارات المدرسية',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const AppShell(),
    );
  }
}
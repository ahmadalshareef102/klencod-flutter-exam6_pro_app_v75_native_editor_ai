import 'package:exam6_pro_app/editor/rich_actions.dart';
import 'package:exam6_pro_app/screens/question_tools.dart';
import 'package:exam6_pro_app/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeActions extends Fake implements RichActions {
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  @override
  ValueListenable<int> get revision => rev;

  @override
  bool get hasImage => false;

  @override
  bool get hasTable => false;

  @override
  bool isOn(String key) => key == 'bold';
}

void main() {
  testWidgets('الشريط يعرض التبويبات والمجموعات ويتنقل بينها', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              QuestionRibbon(actions: _FakeActions()),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    for (final t in ['الرئيسية', 'تنسيق', 'إدراج', 'رياضيات', 'جدول', 'صورة']) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(find.text('عريض'), findsOneWidget);

    await tester.tap(find.text('رياضيات'));
    await tester.pump();
    expect(find.text('الرموز'), findsOneWidget);
    expect(find.text('قوالب سريعة'), findsOneWidget);

    await tester.tap(find.text('جدول'));
    await tester.pump();
    expect(find.text('إدراج جدول'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    expect(find.text('إدراج جدول'), findsNothing);
  });
}

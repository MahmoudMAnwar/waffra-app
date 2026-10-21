import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Approved concept 2 keeps every original feature and its empty state', () {
    final source = File('lib/main.dart').readAsStringSync();

    // This release may change the UI, not persisted records or existing routes.
    const preserved = <String>[
      'Widget dashboard()',
      'Widget categoriesPage()',
      'Widget goalsPage()',
      'Widget recurringPage()',
      'Widget profilePage()',
      'bulkSmsSheet()',
      'entrySheet()',
      'showAiAnalysis()',
      'backupDialog()',
      'openFinancialCalendar()',
      'configurePin',
      'waffra_categories_v24',
      'waffra_goals_v24',
      'waffra_recurring_v24',
      'waffra_sms_hashes_v1',
    ];
    for (final item in preserved) {
      expect(source.contains(item), isTrue, reason: 'Preserve: $item');
    }
    expect(source.contains('WaffraFooterNavigation('),isTrue);
    final footerSource=File('lib/waffra_footer.dart').readAsStringSync();
    expect(footerSource.contains('static const itemCount=5'),isTrue);

    // Keep the floating add action, but not the duplicate dashboard shortcut.
    expect(source.contains('floatingActionButton:'), isTrue);
    expect(source.contains("_dashboardShortcut(waffraIsEnglish?'Add transaction'"),
      isFalse);
    expect(source.contains('لا توجد معاملات لتحليلها بعد'), isTrue);
    expect(source.contains('إضافة معاملة'), isTrue);
    expect(source.contains('scaffoldBackgroundColor:const Color(0xFF080A09)'),
      isTrue);
    expect(source.contains('CustomPaint(size:Size(compact?65.0:78.0'), isTrue);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Compact balance preserves amount privacy at narrow width in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          useMaterial3: true,
          fontFamily: 'Tajawal',
          scaffoldBackgroundColor: brightness == Brightness.dark
              ? const Color(0xFF080A09)
              : const Color(0xFFF4FAF7),
        ),
        home: Scaffold(body: CustomScrollView(slivers: [
          SliverPersistentHeader(
            pinned: false,
            delegate: WaffraBalanceHeader(balance: 1250, english: false),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 800)),
        ])),
      ));
      // WaffraText exposes both the translation wrapper and its nested Text.
      expect(find.text('رصيدك الحالي'), findsWidgets);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

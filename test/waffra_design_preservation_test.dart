import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_financial_tools.dart';

void main() {
  group('Waffra visual redesign regression safeguards', () {
    test('All original sections, actions and local data contracts remain', () {
      final source = File('lib/main.dart').readAsStringSync();
      // Changes to the design must never delete routes, features, or user data.
      const required = <String>[
        'Widget dashboard()',
        'Widget categoriesPage()',
        'Widget goalsPage()',
        'Widget recurringPage()',
        'Widget profilePage()',
        'void openFinancialCalendar()',
        'void openSubscriptionInsights()',
        'bulkSmsSheet()',
        'entrySheet()',
        'backupDialog()',
        'goalDialog()',
        'showAiAnalysis()',
        'configurePin',
        'transactionDetails(',
        'waffra_categories_v24',
        'waffra_goals_v24',
        'waffra_recurring_v24',
        'waffra_challenges_v1',
        'waffra_deleted_categories_v1',
        'waffra_sms_hashes_v1',
        "'entries'",
        'NavigationDestination(',
        'selectFooter(',
        'widget.onLogout()',
        'widget.onLanguage(',
        'widget.onTheme()',
      ];
      for (final feature in required) {
        expect(source.contains(feature), isTrue, reason: 'Missing existing feature or storage contract: $feature');
      }
      expect(RegExp(r'NavigationDestination\(').allMatches(source).length, 6,
        reason: 'The redesign must keep all six original footer destinations');
    });

    testWidgets('Calendar does not show zero totals in an empty month', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: WaffraFinancialCalendar(items: [], english: false),
      ));
      expect(find.text('لا توجد معاملات في هذا اليوم'), findsOneWidget);
      expect(find.textContaining('الدخل: 0.00'), findsNothing);
      expect(find.textContaining('المصروفات: 0.00'), findsNothing);
    });

    testWidgets('Calendar keeps both income and expense transactions', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(MaterialApp(
        home: WaffraFinancialCalendar(english: false, items: [
          WaffraCalendarItem(now, 'راتب تجريبي', 1500, true),
          WaffraCalendarItem(now, 'مصروف تجريبي', 120, false),
        ]),
      ));
      expect(find.text('راتب تجريبي'), findsOneWidget);
      expect(find.text('مصروف تجريبي'), findsOneWidget);
      expect(find.text('+1500.00'), findsOneWidget);
      expect(find.text('-120.00'), findsOneWidget);
    });
  });
}

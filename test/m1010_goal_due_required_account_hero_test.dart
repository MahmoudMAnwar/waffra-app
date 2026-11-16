import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_goal_recurring_account_picker.dart';

void main() {
  Widget accountPicker({required bool attempted, bool english = false}) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WaffraGoalRecurringAccountPicker(
              idPrefix: 'm1010-test',
              accounts: const [],
              english: english,
              showRequiredErrors: attempted,
              onChanged: (_) {},
              onError: (_) {},
              onCreateAccount: (_) async => null,
            ),
          ),
        ),
      );

  testWidgets('M1010 untouched linked account form is not prematurely red',
      (tester) async {
    await tester.pumpWidget(accountPicker(attempted: false));
    expect(find.text('هذا الحقل مطلوب'), findsNothing);
    expect(find.text('نوع الجهة *'), findsOneWidget);
    expect(find.text('البنك أو الجهة الأساسية *'), findsOneWidget);
    expect(find.text('الحساب المالي التابع *'), findsOneWidget);
  });

  testWidgets('M1010 goal and due account cascade shows three inline errors',
      (tester) async {
    await tester.pumpWidget(accountPicker(attempted: false));
    await tester.pumpWidget(accountPicker(attempted: true));
    await tester.pump();
    expect(find.text('هذا الحقل مطلوب'), findsNWidgets(3));
    expect(find.byType(WaffraGoalRecurringAccountPicker), findsOneWidget);
  });

  testWidgets('M1010 English required account fields remain localized',
      (tester) async {
    await tester.pumpWidget(accountPicker(attempted: true, english: true));
    expect(find.text('This field is required'), findsNWidgets(3));
  });

  test('M1010 actual goal and due save actions activate inline validation', () {
    final goal = File('lib/waffra_home_goal_actions.part.dart').readAsStringSync();
    final due = File('lib/waffra_home_recurring_workflows.part.dart')
        .readAsStringSync();
    final cascade = File('lib/waffra_goal_recurring_account_picker.dart')
        .readAsStringSync();
    expect(goal, contains('showRequiredErrors:attempted,'));
    expect(due, contains('showRequiredErrors:attempted,'));
    expect(goal, contains('updateGoal(()=>attempted=true);'));
    expect(due, contains('update(()=>attempted=true);'));
    expect(goal, contains('chosenGoalAccount==null||!goalAccounts.any('));
    expect(due, contains('selectedRecurringAccount!=null&&'));
    for (final field in [
      'errorText:missingCategory?requiredMessage:null',
      'errorText:missingProvider?requiredMessage:null',
      'errorText:missingAccount?requiredMessage:null',
    ]) {
      expect(cascade, contains(field));
    }
  });

  test('M1010 dues uses approved hero without dropping financial calendar',
      () {
    final pages = File('lib/waffra_home_goals_recurring_pages.part.dart')
        .readAsStringSync();
    expect(pages, contains(
        "WaffraApprovedPageHero(\n      title:waffraIsEnglish?'Due dates':'الاستحقاقات'"));
    expect(pages, contains("key:const Key('m1010-dues-financial-calendar')"));
    expect(pages, contains('WaffraHaptics.tap(showWaffraFinancialCalendar)'));
    expect(pages, contains("title:waffraIsEnglish?'Savings goals':'أهداف الادخار'"));
    expect(pages, contains('WaffraApprovedMetrics(metrics:['));
    expect(pages, contains("key:const Key('m938-dues-filter-menu')"));
  });
}

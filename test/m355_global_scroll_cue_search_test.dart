import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_search.dart';
import 'package:waffra/waffra_visible_scroll_behavior.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cue = Key('waffra-overflow-scroll-thumb');

  Widget appWithList({
    required int itemCount, bool horizontal = false,
  }) {
    return MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      scrollBehavior: const WaffraVisibleScrollBehavior(),
      home: Scaffold(
        body: SizedBox(
          width: 340, height: 260,
          child: ListView.builder(
            scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
            itemCount: itemCount,
            itemExtent: 58,
            itemBuilder: (_, i) => ListTile(title: Text('Budget item $i')),
          ),
        ),
      ),
    );
  }

  testWidgets('M355 visible marker only when vertical content overflows',
      (tester) async {
    await tester.pumpWidget(appWithList(itemCount: 30));
    await tester.pumpAndSettle();
    expect(find.byKey(cue), findsOneWidget);
    final before = tester.getTopLeft(find.byKey(cue)).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.byKey(cue)).dy;
    expect(after, greaterThan(before),
        reason: 'Cue should follow the scrolling position');
    expect(tester.takeException(), isNull);
  });

  testWidgets('M355 no misleading scrollbar when every item fits',
      (tester) async {
    await tester.pumpWidget(appWithList(itemCount: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(cue), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M355 do not cover horizontal carousel with vertical cue',
      (tester) async {
    await tester.pumpWidget(appWithList(itemCount: 30, horizontal:true));
    await tester.pumpAndSettle();
    expect(find.byKey(cue), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M355 nested lists stay scrollable and Android cue ignores taps',
      (tester) async {
    var taps=0;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(platform: TargetPlatform.android),
      scrollBehavior: const WaffraVisibleScrollBehavior(),
      home: Scaffold(body: SizedBox(
        height: 220, width: 340,
        child: ListView.builder(
          itemCount: 26,
          itemExtent: 50,
          itemBuilder: (_, index) => ListTile(
            title: Text('Transaction $index'),
            onTap: () => taps++,
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(cue), findsOneWidget);
    await tester.tap(find.text('Transaction 0'));
    expect(taps, 1);
    await tester.drag(find.byType(ListView),const Offset(0,-140));
    await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
  });

  test('M355 Arabic/English case-accent search uses existing common matcher', () {
    expect(waffraSearchAny(['ميزانية الأكل', 'مواصلات'], 'الاكل'), isTrue);
    expect(waffraSearchAny(['بنزين', 'جنيه مصري'], 'بِنْزِين'), isTrue);
    expect(waffraSearchAny(['Income', 'Salary'], 'sALARY'), isTrue);
    expect(waffraSearchAny(['مواصلات', 'وقود'], 'السفر'), isFalse);
    expect(waffraSearchAny(['Budget'], ''), isTrue);
  });

  test('M355 app-wide scroll integration and search on historical link pickers', () {
    final home = File('lib/main.dart').readAsStringSync();
    final cueSource =
        File('lib/waffra_visible_scroll_behavior.dart').readAsStringSync();
    expect(home,contains('scrollBehavior:const WaffraVisibleScrollBehavior()'));
    expect(cueSource,contains('notification.depth == 0'));
    expect(cueSource,contains('content <= view + 6'));
    expect(cueSource,contains('IgnorePointer('));
    expect(cueSource,contains('ScrollMetricsNotification'));
    expect(home,contains("Key('waffra-historical-expense-search')"));
    expect(home,contains("Key('waffra-budget-link-search')"));
    expect(home,contains('waffraSearchAny('));
    expect(home,contains('entryQuery'));
    expect(home,contains('budgetQuery'));
    // Search must not change any stored finance record, import or amount.
    final section=home.split('Future<void> reviewUnlinkedHistoricalExpenses()')
        .last.split('Future<void> deleteNamedBudget(').first;
    expect(section,isNot(contains('entries.add(')));
    expect(section,isNot(contains('entries.clear(')));
  });
}

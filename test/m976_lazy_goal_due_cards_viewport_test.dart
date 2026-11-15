import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// M976 / #677: defer expensive card construction until viewport mount.
void main() {
  testWidgets('M976 ListView defers 1500 expensive offscreen card builders',
      (tester) async {
    final actuallyBuilt = <int>{};
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(
        controller: scroll,
        children: List<Widget>.generate(1500, (index) =>
          Builder(builder: (_) {
            actuallyBuilt.add(index);
            return SizedBox(height: 62,
              child: Text('card-$index'));
          }), growable: false),
      )),
    ));
    final firstFrameCount = actuallyBuilt.length;
    expect(firstFrameCount, greaterThan(0));
    expect(firstFrameCount, lessThan(1500));
    expect(actuallyBuilt.contains(1499), isFalse);

    scroll.jumpTo(3100);
    await tester.pumpAndSettle();
    expect(actuallyBuilt.length, greaterThan(firstFrameCount));
    expect(actuallyBuilt.length, lessThan(1500));
    expect(actuallyBuilt.any((index) => index >= 50), isTrue);
  });

  test('M976 approved real Goals and Recurring Card source defers construction',
      () {
    final source = File('lib/waffra_home_goals_recurring_pages.part.dart')
        .readAsStringSync();
    expect(source, contains('...ordered.map((g)=>Builder(builder:(_){'));
    expect(source, contains('...shown.map((r)=>Builder(builder:(_){'));
    expect(source, contains('})),\n     if(goals.isEmpty)Padding'));
    expect(source, contains('})),\n     if(recurring.isEmpty)Card'));
    expect(source, contains("key:Key('m689-goal-card-'+g.id)"));
    expect(source, contains("key:Key('m689-due-card-'+r.id)"));
    expect(source, contains('controller:_goalsScrollController'));
    expect(source, contains('controller:_recurringScrollController'));
    expect(source, contains('final paid=paidGoalDueById.matches(settledId);'));
    expect(source, contains('final due=goal==null?dueFor(r):r.startAt;'));
    expect(source, isNot(contains('INSERT INTO')));
    expect(source, isNot(contains('DELETE FROM')));
  });
}

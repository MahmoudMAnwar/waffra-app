import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_centered_dropdown.dart';

void main() {
  test('M529 keeps blur but avoids sigma-6 and temporary selected lists', () {
    final source =
        File('lib/waffra_centered_dropdown.dart').readAsStringSync();
    expect(source, contains('items.indexWhere('));
    expect(source, isNot(contains('items.where((item)=>item.value==field.value).toList()')));
    expect(source, contains('BackdropFilter('));
    expect(source, contains('MediaQuery.disableAnimationsOf(dialogContext)?0:3'));
    expect(source, isNot(contains('sigmaX:6,sigmaY:6')));
    expect(source, contains('itemBuilder:(ctx,index)'));
  });

  for (final direction in <TextDirection>[
    TextDirection.rtl,
    TextDirection.ltr,
  ]) {
    testWidgets('M529 $direction: selection commits once', (tester) async {
      String? changed;
      var changeCount = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: direction, child: child!),
        home: Scaffold(
          body: Center(
            child: WaffraCenteredDropdownFormField<String>(
              key: const Key('test-m529-picker'),
              initialValue: 'one',
              decoration: const InputDecoration(labelText: 'Account'),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'one', child: Text('First account')),
                DropdownMenuItem(value: 'two', child: Text('Second account')),
              ],
              onChanged: (value) {
                changed = value;
                changeCount++;
              },
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('test-m529-picker')));
      await tester.pumpAndSettle();
      expect(changed, isNull);
      expect(find.byKey(const Key('waffra-modal-choice-1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('waffra-modal-choice-1')));
      await tester.pumpAndSettle();
      expect(changed, 'two');
      expect(changeCount, 1);
    });

    testWidgets('M529 $direction: closing without choice does not mutate',
        (tester) async {
      var callbacks = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) =>
            Directionality(textDirection: direction, child: child!),
        home: Scaffold(
          body: Center(
            child: WaffraCenteredDropdownFormField<String>(
              initialValue: 'one',
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'one', child: Text('First account')),
                DropdownMenuItem(value: 'two', child: Text('Second account')),
              ],
              onChanged: (_) => callbacks++,
            ),
          ),
        ),
      ));
      await tester.tap(find.text('First account'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(callbacks, 0);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  }
}

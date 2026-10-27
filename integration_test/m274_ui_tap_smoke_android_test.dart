import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_footer.dart';

/// Runs against the actual Android Flutter engine in an emulator.
/// Tests real taps, frames, layout and privacy; financial records are synthetic.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android: six rapid footer taps keep the last chosen screen',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(builder: (context, update) => Scaffold(
        body: Center(child: Text('screen-$selected',
          key: const Key('m274-selected-screen'))),
        bottomNavigationBar: WaffraFooterNavigation(
          selectedIndex: selected,
          english: false,
          onSelected: (i) => update(() => selected = i),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    for (final i in [1, 2, 3, 4, 0, 2]) {
      await tester.tap(find.byKey(Key('waffra-nav-$i')));
      await tester.pump(const Duration(milliseconds: 250));
      expect(selected, i);
    }
    await tester.pumpAndSettle();
    expect(find.text('screen-2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android: real eye taps hide and reveal the balance', (tester) async {
    expect(Platform.isAndroid, isTrue);
    hideWaffraAmounts.value = false;
    addTearDown(() => hideWaffraAmounts.value = false);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CustomScrollView(slivers: [
        SliverPersistentHeader(delegate: WaffraBalanceHeader(
          balance: 1234.50,
          english: false,
          refreshVerifiedWidgetBalance: () async {},
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 750)),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('waffra-approved-emerald-balance-card')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('waffra-balance-privacy-eye')));
    await tester.pumpAndSettle();
    expect(find.text('***'), findsWidgets);
    await tester.tap(find.byKey(const Key('waffra-balance-privacy-eye')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_finance_reloading_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M1006 visible dark Arabic finance retry never draws an empty route',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: WaffraFinanceReloadingView(english: false),
      ),
    ));
    expect(find.byKey(const Key('m1006-visible-finance-retry-surface')),
        findsOneWidget);
    expect(find.byKey(const Key('m1006-finance-retry-progress')),
        findsOneWidget);
    expect(find.text('جارٍ التحقق من بياناتك المالية المحفوظة…'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('M1006 visible light English retry respects large text and shows no balance',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: const WaffraFinanceReloadingView(english: true),
      ),
    ));
    expect(find.text('Verifying your saved financial data…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('SAR'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('M1006 only a previously visible authenticated Home receives progress', () {
    final shell = File('lib/waffra_home_root_shell.part.dart').readAsStringSync();
    final app = File('lib/main.dart').readAsStringSync();
    final loader = File('lib/waffra_home_finance_recovery.part.dart')
        .readAsStringSync();
    expect(shell, contains('child:!ready&&_financeLoadFailure==null?'));
    expect(shell, contains('widget.postAuthVisible?'));
    expect(shell, contains('WaffraFinanceReloadingView(english:waffraIsEnglish)'));
    expect(shell, contains('_m1003FinanceHandoffSurface()):Stack(children:[Scaffold('));
    // A cold authenticated handoff is still offstage behind the actual
    // credential/biometric UI; no unverified account or transaction is painted.
    expect(app, contains('final homeInteractive=canShowHome&&_m623HomeReady;'));
    expect(app, contains('child:Offstage(offstage:!homeInteractive,'));
    expect(loader, contains('setState((){ready=false;_financeLoadFailure=null;});'));
    expect(shell, contains('body:_financeLoadFailure!=null?_financialRecoveryScreen():'));
    expect(shell, contains('floatingActionButton:!ready||accountOpened||tab==2?null:'));
  });
}

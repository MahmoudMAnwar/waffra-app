import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:waffra/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_smooth_confirmation.dart';

/// Synthetic user taps and deterministic async save completion.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('P0: saving paints a frame, then disappears on confirmed success',
      (tester) async {
    final controller=WaffraSmoothOperationController();
    addTearDown(controller.dispose);
    final pending=Completer<void>();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[
      const Text('previous saved balance'),
      Positioned.fill(child:WaffraSmoothConfirmationOverlay(
          controller:controller,english:false)),
    ]))));
    final work=controller.track<void>('save',()=>pending.future);
    expect(controller.busy,isTrue);
    await tester.pump();
    expect(find.byKey(const Key('waffra-smooth-save-indicator')),
        findsOneWidget);
    expect(find.text('جارٍ حفظ التغييرات…'),findsOneWidget);
    pending.complete();
    await work;
    await tester.pumpAndSettle();
    expect(controller.busy,isFalse);
    expect(find.byKey(const Key('waffra-smooth-save-indicator')),
        findsNothing);
    expect(find.text('previous saved balance'),findsOneWidget);
  });

  testWidgets('P0: failed writer always removes overlay, propagates error',
      (tester) async {
    final controller=WaffraSmoothOperationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[
      const Text('original value'),
      Positioned.fill(child:WaffraSmoothConfirmationOverlay(
          controller:controller,english:true)),
    ]))));
    final pending=Completer<void>();
    final work=controller.track<void>('rejected',()=>pending.future);
    // Attach the failure expectation BEFORE delivering the asynchronous error.
    // Otherwise Flutter's widget-test zone reports a spurious uncaught error.
    final checked=expectLater(work,throwsStateError);
    await tester.pump();
    pending.completeError(StateError('source authority rejected save'));
    await checked;
    await tester.pumpAndSettle();
    expect(controller.pendingOperations,0);
    expect(find.byKey(const Key('waffra-smooth-save-indicator')),
        findsNothing);
    expect(find.text('original value'),findsOneWidget);
  });

  testWidgets('P0: overlapping operations retain indicator until last commit',
      (tester) async {
    final controller=WaffraSmoothOperationController();
    addTearDown(controller.dispose);
    final a=Completer<void>(),b=Completer<void>();
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[
      const SizedBox.expand(),
      Positioned.fill(child:WaffraSmoothConfirmationOverlay(
          controller:controller,english:false)),
    ]))));
    final first=controller.track<void>('A',()=>a.future);
    final second=controller.track<void>('B',()=>b.future);
    expect(controller.pendingOperations,2);
    await tester.pump();
    b.complete();
    await second;
    await tester.pump();
    expect(controller.busy,isTrue);
    a.complete();
    await first;
    await tester.pumpAndSettle();
    expect(controller.pendingOperations,0);
    expect(find.byKey(const Key('waffra-smooth-save-indicator')),
        findsNothing);
  });

  testWidgets('P1: modal barrier prevents double confirmation taps',
      (tester) async {
    final controller=WaffraSmoothOperationController();
    addTearDown(controller.dispose);
    final pending=Completer<void>();
    var pressed=0;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[
      Center(child:FilledButton(
        onPressed:(){
          pressed++;
          unawaited(controller.track<void>('save',()=>pending.future));
        },
        child:const Text('Confirm'))),
      Positioned.fill(child:WaffraSmoothConfirmationOverlay(
          controller:controller,english:true)),
    ]))));
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(pressed,1);
    await tester.tap(find.text('Confirm'),warnIfMissed:false);
    await tester.pump();
    expect(pressed,1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(controller.busy,isFalse);
  });

  testWidgets('P1: reduced motion disables progress fade',
      (tester) async {
    final controller=WaffraSmoothOperationController();
    addTearDown(controller.dispose);
    final pending=Completer<void>();
    await tester.pumpWidget(MaterialApp(home:MediaQuery(
      data:const MediaQueryData(disableAnimations:true),
      child:Scaffold(body:Stack(children:[
        const SizedBox.expand(),
        Positioned.fill(child:WaffraSmoothConfirmationOverlay(
            controller:controller,english:false)),
      ])),
    )));
    final work=controller.track<void>('save',()=>pending.future);
    await tester.pump();
    final switcher=tester.widget<AnimatedSwitcher>(
        find.byType(AnimatedSwitcher).last);
    expect(switcher.duration,Duration.zero);
    expect(switcher.reverseDuration,Duration.zero);
    pending.complete();
    await work;
    await tester.pump();
    expect(tester.takeException(),isNull);
  });

  test('P0: 100-bank-message background parse agrees with UI parser',() async {
    final samples=List<String>.generate(100,(i)=>
      'شراء PoS\nبـ${i+1}.25 SR\nمن 1111\n16/10/26 00:43');
    final direct=samples.map(BankParser.parse).toList(growable:false);
    final background=await compute(waffraParseBankSmsBatchInIsolate,samples);
    expect(background.length,100);
    for(var i=0;i<100;i++){
      expect(background[i].amount,direct[i].amount);
      expect(background[i].income,direct[i].income);
      expect(background[i].title,direct[i].title);
      expect(background[i].category,direct[i].category);
    }
  });

  test('P0: all app finance entry points use the safe feedback boundary',(){
    final code=File('lib/main.dart').readAsStringSync();
    expect(code,contains('return _saveProgress.track<void>('));
    expect(code,contains("'persist-financial-change'"));
    expect(code,contains("'commit-confirmed-bank-sms'"));
    expect(code,contains("'waffra-bank-sms-save-progress'"));
    expect(code,contains('if(submitTapped)return;'));
    expect(code,contains('previousEntries=List<MoneyEntry>.of(entries)'));
    expect(code,contains('entries..clear()..addAll(previousEntries)'));
    expect(code,contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(code,contains('await compute(waffraParseBankSmsBatchInIsolate,found)'));
  });
}

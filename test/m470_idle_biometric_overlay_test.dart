import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_idle_biometric_overlay.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

// Exercise the real Android lifecycle ordering: Flutter's AppLifecycleListener
// rejects shortcuts such as resumed -> paused and paused -> resumed.
void _moveToBackground(WidgetTester tester) {
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _resumeFromBackground(WidgetTester tester) {
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
 tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main(){
 testWidgets('M470 60s lock sits above an open dialog and restores the exact draft',
  (tester)async{
   tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
   final draft=TextEditingController(text:'أصل النص');
   addTearDown(draft.dispose);
   await tester.pumpWidget(MaterialApp(
    builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
     enabled:true,english:false,onSignOut:()async{},
     child:navigator??const SizedBox.shrink()),
    home:Scaffold(body:Builder(builder:(context)=>FilledButton(
     key:const Key('m470-idle-open-dialog'),
     onPressed:()=>showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('تفاصيل العملية'),
      content:TextField(key:const Key('m470-idle-draft'),controller:draft),
     )),
     child:const Text('Open form')))),
   ));
   await tester.tap(find.byKey(const Key('m470-idle-open-dialog')));
   await tester.pumpAndSettle();
   await tester.enterText(find.byKey(const Key('m470-idle-draft')),'تفاصيل محفوظة');
   await tester.pump();
   await tester.pump(const Duration(seconds:61));
   await tester.pump();
   expect(find.byKey(const Key('m470-idle-lock-biometric')),findsOneWidget);
   expect(draft.text,'تفاصيل محفوظة');
   final gate=tester.widget<WaffraMandatoryBiometricGate>(
    find.byKey(const Key('m470-idle-lock-biometric')));
   // Simulation is ONLY the UI test's callback: shipping code still verifies
   // fingerprint or face via the OS-protected mandatory biometric gate.
   gate.onVerified();
   await tester.pump();
   expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
   expect(find.byType(AlertDialog),findsOneWidget);
   expect(draft.text,'تفاصيل محفوظة');
 });

 testWidgets('M470 each tap renews the 60s inactivity timer', (tester)async{
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
    enabled:true,english:true,onSignOut:()async{},
    child:navigator??const SizedBox.shrink()),
   home:const Scaffold(body:Center(child:TextField(
    key:Key('m470-idle-interaction')))),
  ));
  await tester.pump(const Duration(seconds:50));
  await tester.tap(find.byKey(const Key('m470-idle-interaction')));
  await tester.pump();
  await tester.pump(const Duration(seconds:20));
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  await tester.pump(const Duration(seconds:41));
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsOneWidget);
 });

 testWidgets('M470 unverified login has no background idle challenge',
  (tester)async{
   tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
   await tester.pumpWidget(MaterialApp(
    builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
     enabled:false,english:true,onSignOut:()async{},
     child:navigator??const SizedBox.shrink()),
    home:const Scaffold(body:Text('Sign in'))));
   await tester.pump(const Duration(seconds:70));
   expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  });

 testWidgets('M470 #22 59s app switch shows privacy shield but preserves draft', (tester)async{
  var now=DateTime(2026,11,6,10);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final draft=TextEditingController(text:'المسودة محفوظة');
  addTearDown(draft.dispose);
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
    enabled:true,english:false,now:()=>now,onSignOut:()async{},
    child:navigator??const SizedBox.shrink()),
   home:Scaffold(body:TextField(controller:draft,key:const Key('m470-back-draft')))));
  _moveToBackground(tester);
  await tester.pump();
  expect(find.byKey(const Key('m470-background-green-privacy-shield')),findsOneWidget);
  now=now.add(const Duration(seconds:59));
  _resumeFromBackground(tester);
  await tester.pump();
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  expect(find.byKey(const Key('m470-background-green-privacy-shield')),findsNothing);
  expect(draft.text,'المسودة محفوظة');
 });

 testWidgets('M470 #22 after 61s background challenges above same draft', (tester)async{
  var now=DateTime(2026,11,6,11);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final draft=TextEditingController(text:'مسودة التحويل');
  addTearDown(draft.dispose);
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
    enabled:true,english:false,now:()=>now,onSignOut:()async{},
    child:navigator??const SizedBox.shrink()),
   home:Scaffold(body:TextField(controller:draft,key:const Key('m470-back-draft')))));
  _moveToBackground(tester);
  await tester.pump();
  expect(find.byKey(const Key('m470-background-green-privacy-shield')),findsOneWidget);
  now=now.add(const Duration(seconds:61));
  _resumeFromBackground(tester);
  await tester.pump();
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsOneWidget);
  expect(draft.text,'مسودة التحويل');
  final gate=tester.widget<WaffraMandatoryBiometricGate>(
   find.byKey(const Key('m470-idle-lock-biometric')));
  gate.onVerified();
  await tester.pump();
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  expect(draft.text,'مسودة التحويل');
 });

 testWidgets('M470 #22 green biometric covers an open bottom sheet and restores its inputs', (tester)async{
  var now=DateTime(2026,11,6,12);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  final draft=TextEditingController(text:'تحويل 135 ريال');
  addTearDown(draft.dispose);
  await tester.pumpWidget(MaterialApp(
   builder:(ctx,navigator)=>WaffraIdleBiometricOverlay(
    enabled:true,english:false,now:()=>now,onSignOut:()async{},
    child:navigator??const SizedBox.shrink()),
   home:Scaffold(body:Builder(builder:(ctx)=>ElevatedButton(
    key:const Key('m470-open-transaction-sheet'),
    onPressed:()=>showModalBottomSheet<void>(context:ctx,
     builder:(route)=>Padding(padding:const EdgeInsets.all(16),
      child:TextField(key:const Key('m470-sheet-saved-draft'),
       controller:draft))),
    child:const Text('فتح التحويل')))),
  ));
  await tester.tap(find.byKey(const Key('m470-open-transaction-sheet')));
  // Settle just this modal transition, without accidentally advancing a
  // fake-async idle timer while a form remains open.
  await tester.pump();
  await tester.pump(const Duration(milliseconds:350));
  expect(find.byKey(const Key('m470-sheet-saved-draft')),findsOneWidget);
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  // Android exposes Hidden before Paused. Verify the opaque shield is
  // actually painted while this Navigator still has an open bottom sheet;
  // then transition to Paused, where Flutter no longer schedules frames.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  expect(find.byKey(const Key('m470-background-green-privacy-shield')),
      findsOneWidget);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  final shield=tester.widget<ColoredBox>(
   find.byKey(const Key('m470-background-green-privacy-shield')));
  expect(shield.color,const Color(0xFF064D3B));
  now=now.add(const Duration(seconds:61));
  _resumeFromBackground(tester);
  await tester.pump();
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsOneWidget);
  final gate=tester.widget<WaffraMandatoryBiometricGate>(
   find.byKey(const Key('m470-idle-lock-biometric')));
  // QA simulates the gate's successful OS callback; shipping requires OS biometric.
  gate.onVerified();
  await tester.pump();
  expect(find.byKey(const Key('m470-idle-lock-biometric')),findsNothing);
  expect(find.byKey(const Key('m470-sheet-saved-draft')),findsOneWidget);
  expect(draft.text,'تحويل 135 ريال');
 });
}

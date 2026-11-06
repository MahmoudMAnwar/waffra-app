import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_idle_biometric_overlay.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

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
}

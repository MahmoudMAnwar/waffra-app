import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_idle_biometric_overlay.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

void main() {
  test('M513 home asks one Yes/No question, no password or duplicate confirmation', () {
    final source=readWaffraMainSourceForContracts();
    final start=source.indexOf('   OutlinedButton.icon(style:OutlinedButton.styleFrom(\n    foregroundColor:(isGuest)?emerald:Colors.red,');
    final end=source.indexOf("   const SizedBox(height:13),\n   WaffraText(waffraIsEnglish?\n    'Your data stays on this device.",start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final signOutEntry=source.substring(start,end);
    expect(signOutEntry,contains('m513-home-signout-confirmation'));
    expect(signOutEntry,contains('m513-home-signout-no'));
    expect(signOutEntry,contains('m513-home-signout-yes'));
    expect(signOutEntry,contains('هل أنت متأكد من تسجيل الخروج؟'));
    expect(signOutEntry,contains("waffraIsEnglish?'No':'لا'"));
    expect(signOutEntry,contains("waffraIsEnglish?'Yes':'نعم'"));
    expect(signOutEntry,contains('if(ok==true&&mounted)await widget.onLogout();'));
    expect(signOutEntry,isNot(contains('WaffraRegionalCopy.signOutTitle(')));
    expect(signOutEntry,isNot(contains('_repairMissingLocalCredential(')));
  });

  testWidgets('M513 lock gate Cancel keeps session; Yes calls sign-out once',
      (tester) async {
    var logouts=0;
    await tester.pumpWidget(MaterialApp(home:WaffraMandatoryBiometricGate(
      english:true,checkAvailable:()async=>false,authenticate:()async=>false,
      cancelAuthentication:()async{},
      onVerified:(){},
      onSignOut:()async{logouts++;},
    )));
    await tester.pump();
    await tester.tap(find.byKey(const Key('waffra-mandatory-biometric-signout')));
    await tester.pump();
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsOneWidget);
    expect(find.text('Are you sure you want to sign out?'),findsOneWidget);
    expect(logouts,0);
    await tester.tap(find.byKey(const Key('m513-biometric-signout-no')));
    await tester.pump();
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsNothing);
    expect(logouts,0);
    await tester.tap(find.byKey(const Key('waffra-mandatory-biometric-signout')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('m513-biometric-signout-yes')));
    await tester.pump();
    expect(logouts,1);
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsNothing);
  });

  testWidgets('M613 real background biometric keeps M513 Yes/No signout',
      (tester) async {
    var logouts=0;
    var now=DateTime(2026,11,9,13);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(home:WaffraIdleBiometricOverlay(
      english:true,enabled:true,timeout:const Duration(milliseconds:100),
      now:()=>now,onSignOut:()async{logouts++;},
      child:const Scaffold(body:Center(child:Text('Private finances'))),
    )));
    await tester.pump(const Duration(milliseconds:250));
    expect(find.byKey(const ValueKey('m470-idle-lock-biometric')),findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now=now.add(const Duration(milliseconds:250));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(const ValueKey('m470-idle-lock-biometric')),findsOneWidget);
    await tester.tap(find.byKey(const Key('waffra-mandatory-biometric-signout')));
    await tester.pump();
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsOneWidget);
    await tester.tap(find.byKey(const Key('m513-biometric-signout-no')));
    await tester.pump();
    expect(logouts,0);
    expect(find.byKey(const Key('m470-idle-lock-biometric')),findsOneWidget);
  });

  test('M513 password verifier exists before creating phone session and remains unchanged on logout', () {
    final src=readWaffraMainSourceForContracts();
    final profile=src.substring(src.indexOf(' Future<void> saveUser(Person u)async {'),
      src.indexOf(' Future<void> setUiCountry('));
    expect(profile,contains("u.provider.toLowerCase().trim()=='phone'"));
    expect(profile,contains('WaffraLocalPhoneCredentials.probeForPhone(phone)'));
    expect(profile,contains('phone_credential_not_persisted_for_profile'));
    expect(profile.indexOf('WaffraLocalPhoneCredentials.probeForPhone(phone)'),
      lessThan(profile.indexOf('_accountWriteAuthority.saveProfile(')));
    final login=src.substring(src.indexOf(' Future<void> _signIn()async{'),
      src.indexOf(' String get maskedLastPhone{'));
    expect(login,contains('WaffraLocalPhoneCredentials.verify('));
    expect(login,contains('phone:enteredPhone,password:signInPassword.text'));
    expect(login,contains('if(!match){'));
    final logout=src.substring(src.indexOf(' Future<void> logout()async {'),
      src.indexOf(' Future<void> setPin('));
    expect(logout,contains('WaffraLocalPhoneCredentials.probeForPhone('));
    expect(logout,contains('WaffraLocalCredentialProbe.ready'));
    expect(logout,contains('await _accountWriteAuthority.signOut();'));
    expect(logout,isNot(contains('_repairMissingLocalCredential(')));
    expect(logout,isNot(contains('WaffraLocalPhoneCredentials.registerOrResume(')));
    expect(logout,isNot(contains('WaffraLocalPhoneCredentials.register(')));
  });
}

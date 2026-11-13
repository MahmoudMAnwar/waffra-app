import 'dart:convert';
import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/main.dart';

/// M601 #506: owner screenshot shows an EMPTY login button while tapping.
void main() {
  const phone = '0501234567';

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'waffra_registered_profile': jsonEncode(Person(
        name: 'QA', email: '', provider: 'Phone', gender: 'ذكر',
        avatar: 'person', birthday: DateTime(2000), phone: phone,
      ).toJson()),
      'waffra_signed_out_explicitly': false,
    });
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('actual login button renders legibly in enabled and busy/disabled states',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(onSave: (_) async {},onVerifiedPasswordSave: (_) async {})));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final buttonFinder = find.byKey(const Key('m585-login-submit-stable'));
    expect(buttonFinder, findsOneWidget);
    final button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNotNull);
    final style = button.style!;
    // The button disables during PBKDF2. Material3 default disabled fill
    // was dark and made both dark-green Arabic text and progress invisible.
    expect(style.backgroundColor?.resolve({WidgetState.disabled}), Colors.white);
    expect(style.foregroundColor?.resolve({WidgetState.disabled}), const Color(0xFF073F31));
    expect(style.backgroundColor?.resolve(<WidgetState>{}), Colors.white);
    expect(find.text('تسجيل الدخول'), findsWidgets);

    // Incomplete/corrupt credentials never bypass validation; the CTA
    // remains present and can be retried after a failed attempt.
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), phone);
    await tester.enterText(inputs.at(1), 'SomePassword123');
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pump();
    expect(buttonFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('M601 source keeps a readable painted spinner and no extra secure-store read',
      () {
    final source = readWaffraMainSourceForContracts();
    final login = source.split(' Future<void> _signIn()async{')[1]
        .split(' String get maskedLastPhone{')[0];
    final ui = source.split('FilledButton(onPressed:WaffraHaptics.tap(signingIn?null:_signIn)')[1]
        .split("key:const Key('m479-login-back-to-choice')")[0];
    expect(ui, contains('disabledBackgroundColor:Colors.white'));
    expect(ui, contains('disabledForegroundColor:forest'));
    expect(ui, contains('AlwaysStoppedAnimation<Color>(forest)'));
    expect(ui, contains("waffraIsEnglish?'Signing in...':'جارٍ تسجيل الدخول'"));
    expect(ui, contains('style:const TextStyle(color:forest,fontWeight:FontWeight.bold)'));
    expect(login, contains('if(signingIn)return;'));
    expect(login, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(login, contains('WaffraLocalPhoneCredentials.probeForPhone('));
    expect(login, isNot(contains('await WaffraLocalPhoneCredentials.hasRegisteredCredentials();')));
    expect(login, contains('verifierStatus!=WaffraLocalCredentialProbe.missing'));
    expect(login, contains('await WaffraLocalPhoneCredentials.verify('));
    expect(login, contains('await widget.onVerifiedPasswordSave(verifiedAccount);'));
    expect(login, contains('if(kProfileMode&&signInTiming!=null)'));
  });

  test('M601 never loosens phone, biometric recovery, ledger or logout Yes/No',
      () {
    final source = readWaffraMainSourceForContracts();
    final login = source.split(' Future<void> _signIn()async{')[1]
        .split(' String get maskedLastPhone{')[0];
    final signout = source.split(' Future<void> logout()async {')[1]
        .split(' Future<void> setPin(')[0];
    expect(login, contains('hasSignOutRecoveryGrant(enteredPhone)'));
    expect(login, contains('WaffraBiometrics.unlockMandatory()'));
    expect(login, contains('finishSignInRecoveryAfterBiometric('));
    expect(signout, contains('WaffraAutoSms.suspendForSignOut()'));
    expect(signout, contains('await _accountWriteAuthority.signOut();'));
    expect(source, contains("key:const Key('m513-home-signout-no')"));
    expect(source, contains("key:const Key('m513-home-signout-yes')"));
    final credentials=File('lib/waffra_local_phone_credentials.dart').readAsStringSync();
    expect(credentials, contains('static const _iterations=600000;'));
    expect(credentials, contains('Isolate.run<List<int>>('));
  });

  test('M601 sign-out Yes paints progress, blocks extra taps, and always clears it',
      () {
    final source = readWaffraMainSourceForContracts();
    final signout = source.split(' Future<void> logout()async {')[1]
        .split(' Future<void> setPin(')[0];
    expect(signout, contains('if(_logoutInProgress)return;'));
    expect(signout, contains('OverlayEntry(builder:(context)=>Positioned.fill('));
    expect(signout, contains('ModalBarrier(dismissible:false'));
    expect(signout, contains("'جارٍ تسجيل الخروج'"));
    expect(signout, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(signout, contains('await WaffraAutoSms.suspendForSignOut()'));
    expect(signout, contains('await _accountWriteAuthority.signOut();'));
    expect(signout, contains('progress?.remove();'));
    expect(signout, contains('progress?.dispose();'));
    expect(signout.indexOf('await _accountWriteAuthority.signOut();'),
        lessThan(signout.indexOf('progress?.remove();')));
    expect(signout, contains('if(kProfileMode&&logoutTiming!=null)'));
    expect(signout, isNot(contains('showDialog(')));
    expect(signout, isNot(contains('WaffraBiometrics.unlockMandatory()')));
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

void main() {
  testWidgets('M502: pending native biometric must confirm logout with Yes/No', (tester) async {
    final osChallenge=Completer<bool>();
    var signOutCalls=0, cancelCalls=0, verifiedCalls=0;
    await tester.pumpWidget(MaterialApp(home:WaffraMandatoryBiometricGate(
      english:false,
      checkAvailable:()async=>true,
      authenticate:()=>osChallenge.future,
      cancelAuthentication:()async{cancelCalls++;},
      onVerified:(){verifiedCalls++;},
      onSignOut:()async{signOutCalls++;},
    )));
    await tester.pump();
    final button=find.byKey(const Key('waffra-mandatory-biometric-signout'));
    expect(button,findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(cancelCalls,1);
    expect(signOutCalls,0);
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsOneWidget);
    expect(find.text('هل أنت متأكد من تسجيل الخروج؟'),findsOneWidget);
    await tester.tap(find.byKey(const Key('m513-biometric-signout-no')));
    await tester.pump();
    expect(signOutCalls,0);
    expect(find.byKey(const Key('m513-biometric-signout-confirmation')),findsNothing);
    // A canceled OS prompt may report success late; it cannot unlock finance.
    osChallenge.complete(true);
    await tester.pump();
    expect(verifiedCalls,0);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(find.byKey(const Key('m513-biometric-signout-yes')));
    await tester.pump();
    expect(signOutCalls,1);
    expect(verifiedCalls,0);
    expect(find.textContaining('لم يكتمل تسجيل الخروج'),findsOneWidget);
  });

  test('M502: root logout reports failures visibly and preserves safety guards',(){
    final src=File('lib/main.dart').readAsStringSync();
    final logout=src.substring(src.indexOf(' Future<void> logout()async {'),
      src.indexOf(' Future<void> setPin('));
    expect(src,contains('scaffoldMessengerKey:_logoutFeedbackKey'));
    expect(src,contains('navigatorKey:_logoutNavigatorKey'));
    expect(logout,contains('_showLogoutFeedback('));
    expect(logout,contains('_logoutFeedbackKey.currentState'));
    expect(logout,contains('WaffraLocalPhoneCredentials.probeForPhone('));
    expect(logout,contains('WaffraAutoSms.suspendForSignOut()'));
    expect(logout,contains('await _accountWriteAuthority.signOut();'));
    expect(logout.indexOf('WaffraAutoSms.suspendForSignOut()'),
       lessThan(logout.indexOf('_accountWriteAuthority.signOut()')));
    expect(logout,contains('if(!hasLegacy){'));
    expect(logout,contains('return;'));
  });

  test('M503: sign-out feedback reuses exactly one footer-aware presenter',(){
    final src=File('lib/main.dart').readAsStringSync();
    final root=src.substring(src.indexOf(' void _showLogoutFeedback('),
      src.indexOf(' Future<void> setPin('));
    final presenter=src.substring(src.indexOf('void snack(BuildContext context'),
      src.indexOf('void snackSuccess('));
    expect(RegExp(r'\.showSnackBar\s*\(').allMatches(src).length,1);
    expect(RegExp(r'\bSnackBar\s*\(').allMatches(src).length,1);
    expect(root,contains('_logoutNavigatorKey.currentContext'));
    expect(root,contains('snack(feedbackContext,message,'));
    expect(root,contains('preferFooter:true'));
    expect(presenter,contains('preferFooter||inHome||inHomeDialog'));
    expect(presenter,contains('_waffraShowFooterNotice(notice)'));
    expect(presenter,contains('messenger.showSnackBar(SnackBar('));
    expect(src,contains('waffraDismissFooterNotice();'));
  });
}

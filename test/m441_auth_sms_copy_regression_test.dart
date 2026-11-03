import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_auto_sms_consent.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

void main() {
  test('M441: secure password verifier is still required after sign out', () async {
    const phone='0501234567';
    const password='ExamplePassword2026!';
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:password,testSalt:List<int>.filled(32,19));
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      record,phone:phone,password:password),isTrue);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      record,phone:phone,password:'WrongPassword2026!'),isFalse);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      record,phone:'0599999999',password:password),isFalse);
  });

  test('M441: verified phone, not editable display profile, owns login', () {
    final main=File('lib/main.dart').readAsStringSync();
    final login=main.substring(main.indexOf('Future<void> _signIn()async{'),
      main.indexOf('String get maskedLastPhone{'));
    expect(login,contains('hasRegisteredCredentials()'));
    expect(login,contains('if(!hasSecureVerifier&&storedPhone!=enteredPhone)'));
    expect(login,contains('phone:enteredPhone,password:signInPassword.text'));
    expect(login,contains('if(!match){'));
    expect(login,contains('final verifiedAccount=storedPhone==enteredPhone?account:Person('));
    expect(login,contains('await widget.onSave(verifiedAccount)'));
    expect(login,isNot(contains('signInPhone.text.trim()!=account.phone')));
    expect(main,contains('readOnly:widget.initial!=null&&widget.provider==\'Phone\''));
    expect(main,contains('Changing a sign-in phone requires verified account migration'));
  });

  testWidgets('M441: concise SMS permission keeps meaningful cloud choice',
    (tester) async {
    await tester.pumpWidget(MaterialApp(home:WaffraAutoSmsConsentPage(
      english:false,onComplete:() async {})));
    expect(find.text('السماح بالرسائل والتحليل تلقائيًا'),findsOneWidget);
    expect(find.text('السماح بالرسائل فقط'),findsOneWidget);
    expect(find.text('تخطي الآن'),findsOneWidget);
    expect(find.textContaining('خدمة سحابية خارجية'),findsOneWidget);
    expect(find.textContaining('خارج السعودية'),findsNothing);
  });
}

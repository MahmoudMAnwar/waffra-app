import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phone='0501234567';
  const password='CorrectLocalPassword2026!';

  test('M469 original password remains valid with the saved verifier after logout',()async{
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:password,testSalt:List<int>.filled(32,23));
    final stored=jsonEncode(record);
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord(stored,phone:phone),
      WaffraLocalCredentialProbe.ready);
    // Logout must retain the on-device verifier; re-login repeats the exact
    // phone/password challenge with the SAME record, not an account reset.
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(stored,
      phone:phone,password:password),isTrue);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      Map<String,dynamic>.from(jsonDecode(stored) as Map),
      phone:phone,password:password),isTrue);
  });

  test('M469 generated clipboard password survives register and re-login byte-for-byte',()async{
    // Include common generator symbols, whitespace, and non-ASCII characters.
    // Passwords are secrets: never trim, case-fold or normalize them on paste.
    const generated=r'qW7!@#-_=$%*& Àز9  ';
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:generated,testSalt:List<int>.filled(32,26));
    final saved=jsonEncode(record);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(saved,
      phone:phone,password:generated),isTrue);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(saved,
      phone:phone,password:generated.trim()),isFalse);
    expect(await WaffraLocalPhoneCredentials.canResumeRecord(saved,
      phone:phone,password:generated.toLowerCase()),isFalse);
    final main=File('lib/main.dart').readAsStringSync();
    expect(main,contains('phone:phone.text.trim(),password:password.text'));
    expect(main,contains('phone:enteredPhone,password:signInPassword.text'));
    expect(main,isNot(contains('password:signInPassword.text.trim()')));
  });

  test('M469 invalid phone or password cannot unlock or rotate saved credentials',()async{
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:password,testSalt:List<int>.filled(32,24));
    final before=jsonEncode(record);
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord(before,
      phone:'0599999999'),WaffraLocalCredentialProbe.differentPhone);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(record,
      phone:'0599999999',password:password),isFalse);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(record,
      phone:phone,password:'IncorrectLocalPassword2026!'),isFalse);
    expect(jsonEncode(record),before);
  });

  test('M469 missing and damaged OS verifiers are identified, not accepted',()async{
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord(null,phone:phone),
      WaffraLocalCredentialProbe.missing);
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord('',phone:phone),
      WaffraLocalCredentialProbe.malformed);
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord('{"version":2}',
      phone:phone),WaffraLocalCredentialProbe.malformed);
    final record=await WaffraLocalPhoneCredentials.deriveRecord(
      phone:phone,password:password,testSalt:List<int>.filled(32,25));
    record['hash']='incorrect-base64';
    expect(WaffraLocalPhoneCredentials.inspectStoredRecord(
      jsonEncode(record),phone:phone),WaffraLocalCredentialProbe.malformed);
  });

  test('M469 guarded logout cannot erase the credential or any finance record',(){
    final source=File('lib/main.dart').readAsStringSync();
    final logout=source.substring(source.indexOf(' Future<void> logout()async {'),
      source.indexOf(' Future<void> setPin(',source.indexOf(' Future<void> logout()async {')));
    expect(logout,contains('probeForPhone('));
    expect(logout.indexOf('probeForPhone('),
      lessThan(logout.indexOf('await _accountWriteAuthority.signOut();')));
    expect(logout,contains('if(!hasLegacy){'));
    expect(logout,contains('return;'));
    final adapter=File('lib/storage/waffra_live_account_write_authority.dart')
      .readAsStringSync();
    final signout=adapter.substring(adapter.indexOf('  Future<void> signOut()'),
      adapter.indexOf('  Future<void> replacePinVerifier('));
    expect(signout,contains("prefs.remove('waffra_profile')"));
    expect(signout,isNot(contains('deleteAll')));
    expect(signout,isNot(contains('waffra_registered_profile')));
    expect(signout,isNot(contains('waffra_device_phone_credentials_v2')));
  });

  test('M469 login differentiates missing verifier without bypassing password',(){
    final main=File('lib/main.dart').readAsStringSync();
    final login=main.substring(main.indexOf('Future<void> _signIn()async{'),
      main.indexOf('String get maskedLastPhone{'));
    expect(login,contains('verifierStatus==WaffraLocalCredentialProbe.missing'));
    expect(login,contains('verifierStatus==WaffraLocalCredentialProbe.malformed'));
    expect(login,contains('WaffraLocalPhoneCredentials.verify('));
    expect(login.indexOf('if(!match){'),
      lessThan(login.indexOf('await widget.onSave(verifiedAccount)')));
    expect(login,isNot(contains('registerOrResume(')));
    final credentials=File('lib/waffra_local_phone_credentials.dart')
      .readAsStringSync();
    expect(credentials,contains("'local_credential_write_unverified'"));
  });
}

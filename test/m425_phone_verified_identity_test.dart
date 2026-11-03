import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_phone_secure_auth.dart';

void main() {
  test('M425: Saudi phone converts to E164 without fake email',() {
    expect(WaffraPhoneSecureAuth.e164('0501234567'),'+966501234567');
    for(final bad in ['501234567','05012345','0412345678',
      '+966501234567','050123456a','user@gmail.com']){
      expect(()=>WaffraPhoneSecureAuth.e164(bad),throwsStateError);
    }
    expect(WaffraPhoneSecureAuth.enabled,isFalse,
      reason:'Production release remains disabled pending signed rollout');
  });

  test('M425: no credential/token is stored inside Flutter or APK',(){
    final source=File('lib/waffra_phone_secure_auth.dart').readAsStringSync();
    expect(source,contains("httpsCallable('waffraSignInPhonePassword')"));
    expect(source,contains("httpsCallable('waffraEnrollPhonePassword')"));
    expect(source,contains("httpsCallable('waffraResetPhonePassword')"));
    expect(source,contains('signInWithCustomToken(token)'));
    expect(source,contains('existing.linkWithCredential(credential)'));
    expect(source,contains('currentUser?.uid'));
    expect(source,isNot(contains('OPENROUTER_API_KEY')));
    expect(source,isNot(contains('WAFFRA_STAGING_TOKEN')));
  });

  test('M425: registration performs OTP before profile save',(){
    final main=File('lib/main.dart').readAsStringSync();
    final registration=main.substring(
      main.indexOf('Future<String?> _requestVerifiedPhoneCode()async'),
      main.indexOf('void _nextPhoneRegistrationStep()'));
    final first=registration.indexOf('WaffraPhoneSecureAuth.enrollWithOtp(');
    final save=registration.indexOf('await widget.onSave(Person(');
    expect(first,greaterThan(0));
    expect(save,greaterThan(first));
    expect(registration,contains('waffra_verified_phone_owner_uid_v1'));
    expect(registration,contains('requestCode:_requestVerifiedPhoneCode'));
  });

  test('M425: verified mode has no silent fallback to local SHA256 login',(){
    final main=File('lib/main.dart').readAsStringSync();
    final section=main.substring(main.indexOf('Future<void> _signIn()async{'),
      main.indexOf('String get maskedLastPhone{'));
    expect(section,contains('if(WaffraPhoneSecureAuth.enabled){'));
    expect(section,contains('WaffraPhoneSecureAuth.signIn('));
    expect(section,contains('bound!=uid'));
    expect(section,contains('await WaffraPhoneSecureAuth.signOut();'));
    expect(section,contains('return;'));
    expect(section,contains("waffra_local_password_salt"));
    expect(section,contains('sha256.convert'));
  });

  test('M425: stale cached profile cannot independently unlock finances',(){
    final main=File('lib/main.dart').readAsStringSync();
    expect(main,contains(
      'if(WaffraPhoneSecureAuth.enabled&&u!=null){'));
    expect(main,contains(
      'if(linked==null||WaffraPhoneSecureAuth.currentUid!=linked)u=null;'));
    expect(main,contains('WaffraMandatoryBiometricGate('));
    expect(main,contains('verified_phone_session_required'));
  });

  test('M425: Google migration retains original identity and wallet fields',(){
    final migration=File('lib/waffra_phone_migration_form.dart')
      .readAsStringSync();
    final main=File('lib/main.dart').readAsStringSync();
    expect(migration,contains('originalUid'));
    expect(migration,contains('if (linkedUid != originalUid)'));
    expect(migration,contains('widget.onMigrated('));
    expect(main,contains("provider:'Phone'"));
    expect(main,contains("name:p.name,email:p.email,phone:number"));
    expect(main,contains("gender:p.gender,avatar:p.avatar,birthday:p.birthday"));
    expect(main,contains("finance_owner_binding_conflict"));
    expect(migration,isNot(contains('clearFinance')));
    expect(migration,isNot(contains('removeAll')));
  });

  test('M425: phone auth server defaults disabled with enforced App Check',(){
    final index=File('functions/index.js').readAsStringSync();
    expect(index,contains("process.env.WAFFRA_PHONE_AUTH_ENABLED !== 'true'"));
    expect(index,contains('enforceAppCheck:true'));
    expect(index,contains("defineSecret('WAFFRA_PHONE_PASSWORD_PEPPER')"));
    expect(index,contains('waffraEnrollPhonePassword'));
    expect(index,contains('waffraSignInPhonePassword'));
    expect(index,contains('waffraResetPhonePassword'));
    expect(index,isNot(contains('waffra_public_admin_password')));
  });
}

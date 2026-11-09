import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

/// M604: source + real PBKDF2 regression for first-frame and repeated login.
/// CI checks behavior; only a physical Android profile trace can certify p95.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const phone='0501234567';
  const otherPhone='0507654321';
  const password='A-strong-local-password-123';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String,String>{});
  });

  test('one opaque secure-store snapshot authenticates the original phone only',
      () async {
    await WaffraLocalPhoneCredentials.registerOrResume(
      phone:phone,password:password);
    final inspection=await WaffraLocalPhoneCredentials.readForSignIn();
    expect(await WaffraLocalPhoneCredentials.probeForPhone(
      phone,inspection:inspection),WaffraLocalCredentialProbe.ready);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone:phone,password:password,inspection:inspection),isTrue);
    expect(await WaffraLocalPhoneCredentials.probeForPhone(
      otherPhone,inspection:inspection),
      WaffraLocalCredentialProbe.differentPhone);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone:otherPhone,password:password,inspection:inspection),isFalse);
  },timeout:const Timeout(Duration(minutes:2)));

  test('missing verifier snapshot never authenticates by itself',()async{
    final missing=await WaffraLocalPhoneCredentials.readForSignIn();
    expect(await WaffraLocalPhoneCredentials.probeForPhone(
      phone,inspection:missing),WaffraLocalCredentialProbe.missing);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone:phone,password:password,inspection:missing),isFalse);
  });

  test('login preserves source guards and removes only redundant IO/delay',(){
    final source=File('lib/main.dart').readAsStringSync();
    final login=source.split(' Future<void> _signIn()async{')[1]
      .split(' String get maskedLastPhone{')[0];
    final intro=source.split(' Future<void> launchIntro()async{')[1]
      .split(' @override void didChangeAppLifecycleState')[0];
    final home=source.split(' Future<void> _loadFinanceSafely()async{')[1]
      .split(' Widget _financialRecoveryScreen()')[0];
    expect(intro,contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(intro,isNot(contains('Duration(milliseconds:1750)')));
    expect(login,contains(
      'var inspection=await WaffraLocalPhoneCredentials.readForSignIn();'));
    expect(login,contains(
      'WaffraLocalPhoneCredentials.probeForPhone('));
    expect(login,contains('inspection:inspection'));
    expect(login,contains('await WaffraLocalPhoneCredentials.verify('));
    expect(login,contains('WaffraBiometrics.unlockMandatory()'));
    expect(login,contains('await widget.onSave(verifiedAccount);'));
    expect(home,contains('await load();'));
    expect(home,contains('unawaited(_m467RefreshHomeAccounts());'));
    expect(home,contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(home,contains('await _refreshAutoSmsInbox(importMonth:'));
    expect(source,contains('WaffraFreshHomeCatalogRecovery.load('));
    expect(source,contains('financeView.requireIntegrity();'));
  });

  test('relogin avoids redundant preference writes but keeps source lease',(){
    final src=File('lib/storage/waffra_live_account_write_authority.dart')
        .readAsStringSync();
    expect(src,contains('return _withVerifiedAccountPreferences((prefs) async {'));
    for(final key in [
      'waffra_registered_profile','waffra_last_login_method',
      'waffra_last_login_phone','waffra_last_login_email',
    ]){
      expect(src,contains("prefs.getString('$key') !="));
    }
    expect(src,contains("prefs.getString('waffra_profile') != profileJson"));
    expect(src,contains('WaffraFreshInstallSource.withVerifiedProfilePreferences(change)'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M602/M603 owner regressions for normal relogin and whole-app tap jank.
/// Source contracts supplement (never replace) physical Android frame traces.
void main() {
  late String mainSource;
  late String nativeActivity;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    nativeActivity = File('native/WaffraMainActivity.kt').readAsStringSync();
  });

  test('normal password relogin does not force a second biometric gate', () {
    final section = mainSource.split(' Future<void> saveUser(Person u)async {')[1]
        .split(' Future<void> setUiCountry(')[0];
    expect(section, contains("prefs.getBool('waffra_signed_out_explicitly')"));
    expect(section, contains("u.provider.toLowerCase().trim()=='phone'"));
    expect(section, contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
    expect(section, isNot(contains('if(freshSession)locked=true;')));
    expect(section, contains('await _accountWriteAuthority.saveProfile('));

    // Restore-from-process-death still needs biometric, as does the
    // independently enforced 60s background idle rule.
    expect(mainSource, contains('locked=u!=null;startupError=null;loading=false;'));
    expect(mainSource, contains('child:WaffraMandatoryBiometricGate('));
    final overlay = File('lib/waffra_idle_biometric_overlay.dart').readAsStringSync();
    expect(overlay, contains('this.timeout=const Duration(seconds:60)'));
    expect(overlay, contains('widget.now().difference(began)>=widget.timeout'));
    expect(overlay, contains('key:const ValueKey(\'m470-idle-lock-biometric\')'));
  });

  test('missing verifier recovery still needs fresh OS biometric', () {
    final login = mainSource.split(' Future<void> _signIn()async{')[1]
        .split(' String get maskedLastPhone{')[0];
    expect(login, contains('WaffraLocalPhoneCredentials.probeForPhone('));
    expect(login, contains('hasSignOutRecoveryGrant(enteredPhone)'));
    expect(login, contains('WaffraBiometrics.unlockMandatory()'));
    expect(login, contains('finishSignInRecoveryAfterBiometric('));
    expect(login, contains('await WaffraLocalPhoneCredentials.verify('));
    expect(mainSource, contains('await WaffraAutoSms.suspendForSignOut()'));
  });

  test('verified sign-in paints first and only then restores owner SMS', () {
    final saved = mainSource.split(' Future<void> saveUser(Person u)async {')[1]
        .split(' Future<void> setUiCountry(')[0];
    final root = mainSource.split(' Widget _m623RootContent(BuildContext rootContext){')[1]
        .split(' @override Widget build(BuildContext context)=>MaterialApp(')[0];
    final resume = mainSource.split(
        ' Future<bool> _m624ResumeSmsAfterRealHome(Person expectedOwner)async{')[1]
        .split(' void _m623HomeLoaded(')[0];
    final home = mainSource.split(' Future<void> _loadFinanceSafely()async{')[1]
        .split(' Widget _financialRecoveryScreen()')[0];
    expect(saved, contains('if(mounted)setState((){'));
    expect(saved, isNot(contains('WaffraAutoSms.resumeAfterSignIn()')));
    expect(root, contains('onVerifiedHomeSmsResume:()=>_m624ResumeSmsAfterRealHome(account)'));
    expect(resume, contains('identical(profile,expectedOwner)'));
    expect(resume, contains('!_logoutInProgress&&_m623HomeReady'));
    expect(resume, contains('if(resumed&&ownerIsActive())waffraAutoSmsUpdates.value++;'));
    expect(home.indexOf('WidgetsBinding.instance.addPostFrameCallback'),
        lessThan(home.indexOf('widget.onVerifiedHomeSmsResume?.call()')));
    expect(home.indexOf('widget.onVerifiedHomeSmsResume?.call()'),
        lessThan(home.indexOf('await _refreshAutoSmsInbox(importMonth:')));
  });

  test('Home first frame precedes four-page month SMS scan', () {
    final home = mainSource.split(' Future<void> _loadFinanceSafely()async{')[1]
        .split(' Widget _financialRecoveryScreen()')[0];
    final doneLoading = home.indexOf('await load();');
    final defer = home.indexOf('WidgetsBinding.instance.addPostFrameCallback');
    final delay = home.indexOf('const Duration(milliseconds:900)');
    final scan = home.indexOf('await _refreshAutoSmsInbox(importMonth:');
    expect(doneLoading, greaterThanOrEqualTo(0));
    expect(defer, greaterThan(doneLoading));
    expect(delay, greaterThan(defer));
    expect(scan, greaterThan(delay));
    final refresh = mainSource.split(' Future<void> _runAutoSmsRefresh({bool importMonth=false})async{')[1]
        .split(' Future<void> _analyzeAmbiguousSmsOnDemand(')[0];
    expect(refresh, contains('for(var page=0;page<4;page++)'));
    expect(refresh, contains('const Duration(milliseconds:500)'));
    expect(refresh, contains('WaffraAutoSms.importConsentMonthChecked()'));
    expect(refresh, contains('WaffraAutoSms.pendingChecked()'));
    expect(refresh, contains('if(++classifiedSinceYield>=16)'));
  });

  test('verified large-transaction remapping yields rather than freezing the UI', () {
    final mapper = mainSource.split('Future<List<MoneyEntry>> _m593BuildVerifiedEntries(')[1]
        .split(' Future<void> _m565ConfirmSms(')[0];
    expect(mapper, contains('const batchSize=32;'));
    expect(mapper, contains('Future<void>.delayed(const Duration(milliseconds:1))'));
    expect(mapper, contains('MoneyEntry.fromJson('));
    final usages = RegExp(r'await _m593BuildVerifiedEntries\(')
        .allMatches(mainSource).length;
    // Initial Home, refresh, Widget sync, reviewed and manually corrected SMS.
    expect(usages, greaterThanOrEqualTo(5));
    expect(mainSource, contains('await compute(WaffraAuthoritativeWidgetBalance.netHalalas,raw)'));
    expect(mainSource, contains('await _financeAuthority.saveCaptured('));
    expect(mainSource, contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
  });

  test('signout native queue suspension never blocks Android main thread', () {
    final bridge = nativeActivity.split('"pauseAutoSmsForSignOut" ->')[1]
        .split('"resumeAutoSmsAfterSignIn" ->')[0];
    expect(bridge, contains('smsHistoryExecutor.execute {'));
    expect(bridge, contains('WaffraAutoSmsStore.suspendForSignOut(app)'));
    expect(bridge, contains('runOnUiThread { result.success(paused) }'));
    expect(bridge, contains('result.error("SMS_SIGNOUT_UNAVAILABLE"'));
    expect(bridge, isNot(contains('result.success(WaffraAutoSmsStore.suspendForSignOut(this))')));
  });
}

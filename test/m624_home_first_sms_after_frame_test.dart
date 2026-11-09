import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M624 source guard; actual Android native concurrency and frame timings
/// must still be verified on signed physical-device builds.
void main() {
  final source = File('lib/main.dart').readAsStringSync();
  final app = source.split('class _WaffraAppState extends State<WaffraApp>')[1]
      .split('class PinLockScreen extends StatefulWidget')[0];
  final save = app.split(' Future<void> saveUser(Person u)async {')[1]
      .split(' Future<void> setUiCountry(')[0];
  final homeLoader = source.split(' Future<void> _loadFinanceSafely()async{')[1]
      .split(' Widget _financialRecoveryScreen()')[0];

  test('M624 never starts native capture on disabled auth/biometric route', () {
    expect(save, isNot(contains('WaffraAutoSms.resumeAfterSignIn()')));
    expect(app, contains('!_m623HomeReady||'));
    expect(app, contains('showLogin||locked||autoSmsConsentPending||_logoutInProgress||'));
    expect(app, contains('!identical(profile,expectedOwner)'));
    expect(app, contains('onVerifiedHomePainted:()=>_m624ResumeSmsAfterVerifiedHome(account)'));
    expect(app, contains('if(freshSession)locked=!ordinaryPhoneRelogin;'));
    expect(app, contains('onVerifiedReady:()=>_m623HomeLoaded(account)'));
    // Do not change authenticated initial dashboard into fake/masked content.
    expect(app, contains('child:Offstage(offstage:!_m623HomeReady,'));
    expect(app, isNot(contains('بنفتح الرئيسية')));
  });

  test('M624 native capture follows successful real Home frame exactly once', () {
    final painted = homeLoader.indexOf('widget.onVerifiedHomePainted?.call();');
    final complete = homeLoader.indexOf('await load();');
    final firstFrame = homeLoader.indexOf('WidgetsBinding.instance.addPostFrameCallback');
    final smsScan = homeLoader.indexOf('await _refreshAutoSmsInbox(importMonth:');
    expect(complete, greaterThanOrEqualTo(0));
    expect(painted, greaterThan(firstFrame));
    expect(firstFrame, greaterThan(complete));
    expect(smsScan, greaterThan(painted));
    expect(homeLoader, contains('if(mounted&&ready&&_financeLoadFailure==null)'));
    // The failed source branch may show protected recovery, NOT resume capture.
    final onError = homeLoader.lastIndexOf('}catch(e){');
    expect(onError, greaterThan(painted));
    expect(homeLoader.substring(onError),
      isNot(contains('onVerifiedHomePainted?.call()')));
    expect(source.split('WaffraAutoSms.resumeAfterSignIn()').length - 1, 1);
  });

  test('M624 session epoch rejects late native completion and sign-out races', () {
    final handler = app.split(' void _m624ResumeSmsAfterVerifiedHome(Person expectedOwner){')[1]
        .split(' void _m623HomeLoaded(')[0];
    expect(handler, contains('_m624SmsResumeIssuedGeneration==_m624AuthGeneration'));
    expect(handler, contains('_m624SmsResumeIssuedGeneration=generation;'));
    expect(handler, contains('final resumed=await WaffraAutoSms.resumeAfterSignIn();'));
    expect(handler, contains('generation!=_m624AuthGeneration'));
    expect(handler, contains('!_m623HomeReady||!identical(profile,expectedOwner)'));
    expect(handler.indexOf('generation!=_m624AuthGeneration'),
      greaterThan(handler.indexOf('await WaffraAutoSms.resumeAfterSignIn()')));
    expect(app, contains('if(u!=null)_m624AuthGeneration++;'));
    expect(save, contains('_m624AuthGeneration++;'));
    final signOut = app.split(' Future<void> logout()async {')[1]
        .split(' bool _logoutInProgress=false;')[0];
    expect(signOut, contains('_m624AuthGeneration++;'));
    expect(signOut, contains('await WaffraAutoSms.suspendForSignOut()'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
 test('M613 no foreground biometric timer; real background is the only idle lock', () {
  final overlay=File('lib/waffra_idle_biometric_overlay.dart')
   .readAsStringSync();
  expect(overlay,contains('this.timeout=const Duration(seconds:60)'));
  expect(overlay,contains('state==AppLifecycleState.hidden||'));
  expect(overlay,contains('state==AppLifecycleState.paused||'));
  expect(overlay,contains('_backgroundAt??=widget.now();'));
  expect(overlay,contains('widget.now().difference(began)>=widget.timeout'));
  expect(overlay,contains('m470-background-green-privacy-shield'));
  expect(overlay,contains("m470-idle-lock-biometric"));
  expect(overlay,isNot(contains('Timer(widget.timeout')));
  expect(overlay,isNot(contains('onPointerDown:')));
  expect(overlay,isNot(contains('onPointerMove:')));
  expect(overlay,isNot(contains('setState(()=>_idleLocked=true);')));
 });

 test('M614 profile-mode spans distinguish secure login from verified financial first frame', () {
  final app=File('lib/main.dart').readAsStringSync();
  final signIn=app.substring(
   app.indexOf(' Future<void> _signIn()async{'),
   app.indexOf(' String get maskedLastPhone{'));
  expect(signIn,contains('WAFFRA_AUTH_PERF sign_in_ms='));
  expect(signIn,contains('await WaffraLocalPhoneCredentials.verify('));
  expect(signIn,contains('await widget.onSave(verifiedAccount);'));
  final saveUser=app.substring(app.indexOf(' Future<void> saveUser(Person u)async {'),
   app.indexOf(' Future<void> setUiCountry('));
  expect(saveUser,contains('WAFFRA_AUTH_PERF post_login_profile_guard_ms='));
  expect(saveUser,contains('profile_persist_ms='));
  expect(saveUser,contains('WaffraLocalPhoneCredentials.probeForPhone(phone)'));
  expect(saveUser,contains('await _accountWriteAuthority.saveProfile('));
  final home=app.substring(app.indexOf(' Future<void> _loadFinanceSafely()async{'),
   app.indexOf(' Widget _financialRecoveryScreen()'));
  expect(home,contains('WAFFRA_FINANCE_PERF source_to_ready_ms='));
  expect(home,contains('WAFFRA_FINANCE_PERF first_home_frame_ms='));
  final load=app.substring(
   app.indexOf(' Future<void> load()async {',app.indexOf('class _HomeScreenState')),
   app.indexOf(' Future<void> _refreshWidget()async{'));
  expect(load,contains('WAFFRA_FINANCE_PERF bind_ms='));
  expect(load,contains('verified_catalog_ms='));
  expect(load,contains('decoded_ready_ms='));
  expect(load,contains('WaffraFreshHomeCatalogRecovery.load('));
  expect(load,contains('financeView.requireIntegrity();'));
  expect(load,contains('setState(()=>ready=true);'));
  expect(app,contains('locked=u!=null;startupError=null;loading=false;'));
 });
}

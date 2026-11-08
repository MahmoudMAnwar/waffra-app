import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// M547 PERF-04 guards source paths on every CI head. Physical Android
/// profile/release frame traces are still needed to prove perceived smoothness.
void main() {
 test('600000-round password derivation runs outside Flutter UI isolate', () {
  final source=File('lib/waffra_local_phone_credentials.dart')
   .readAsStringSync();
  final method=source.split(' static Future<List<int>> _derive(')[1]
   .split(' static bool _equal(')[0];
  expect(source,contains("import 'dart:isolate';"));
  expect(source,contains('static const _iterations=600000;'));
  expect(method,contains('Isolate.run<List<int>>('));
  expect(method,contains('() => _deriveInBackground(password,salt)'));
  expect(method,contains('Pbkdf2(macAlgorithm:Hmac.sha256()'));
  expect(method,contains('iterations:_iterations,bits:256'));
  expect(method,contains('SecretKey(utf8.encode(password)),nonce:salt'));
  expect(method,isNot(contains('FlutterSecureStorage(')));
  expect(method,isNot(contains('_store.write(')));
  expect(method,isNot(contains('_store.delete(')));
 });

 test('login shows a painted, stable busy indicator and prevents double taps', () {
  final source=File('lib/main.dart').readAsStringSync();
  final login=source.split(' Future<void> _signIn()async{')[1]
   .split(' String get maskedLastPhone{')[0];
  final button=source.split(
   'FilledButton(onPressed:WaffraHaptics.tap(signingIn?null:_signIn)')[1]
   .split("key:const Key('m479-login-back-to-choice')")[0];
  expect(login,contains('if(signingIn)return;'));
  expect(login,contains('setState(()=>signingIn=true);'));
  expect(login,contains('await WidgetsBinding.instance.endOfFrame;'));
  expect(login,contains('await WaffraLocalPhoneCredentials.verify('));
  expect(login,contains('await widget.onSave(verifiedAccount);'));
  expect(login,contains('if(mounted)setState(()=>signingIn=false);'));
  expect(button,contains('if(signingIn)...['));
  expect(button,contains('CircularProgressIndicator('));
  expect(button,contains("'جارٍ تسجيل الدخول'"));
 });

 test('Android SMS re-enable and resume do not block main-thread login frames', () {
  final source=File('native/WaffraMainActivity.kt').readAsStringSync();
  final resumed=source.split('"resumeAutoSmsAfterSignIn" -> {')[1]
   .split('"autoSmsNotificationsEnabled"')[0];
  final consent=source.split('"setAutoSmsEnabled" -> {')[1]
   .split('"restartCompletedSmsHistory"')[0];
  for(final section in [resumed,consent]){
   expect(section,contains('val app = applicationContext'));
   expect(section,contains('smsHistoryExecutor.execute {'));
   expect(section,contains('runOnUiThread { result.success('));
   expect(section,contains('runOnUiThread { result.error('));
  }
  expect(resumed,contains('WaffraAutoSmsStore.resumeForSameSignedInOwner(app)'));
  expect(consent,contains('WaffraAutoSmsStore.enable(app, allow)'));
  // Never change the original confirmed signout method.
  expect(source,contains(
   'result.success(WaffraAutoSmsStore.suspendForSignOut(this))'));
 });

}

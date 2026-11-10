import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

/// M635/#553 compares the quick early-build route to current verified Android.
/// These source contracts and a public Unicode vector do NOT certify device FPS.
void main() {
 test('native KDF preserves current secure verifier and works off Android UI', () {
  final native=File('native/WaffraMainActivity.kt').readAsStringSync();
  final dart=File('lib/waffra_local_phone_credentials.dart').readAsStringSync();
  expect(native,contains('passwordKdfExecutor = Executors.newSingleThreadExecutor()'));
  expect(native,contains('"waffra/password_kdf"'));
  expect(native,contains('"derivePbkdf2Sha256"'));
  expect(native,contains('PBEKeySpec(chars, salt, 600000, 256)'));
  expect(native,contains('SecretKeyFactory'));
  expect(native,contains('getInstance("PBKDF2WithHmacSHA256")'));
  expect(native,contains('assertNativePasswordKdfParity()'));
  expect(native,contains('passwordKdfExecutor.execute {'));
  expect(native,contains('passwordKdfExecutor.shutdown()'));
  expect(native,contains('spec.clearPassword()'));
  expect(dart,contains('static const _iterations=600000;'));
  expect(dart,contains("MethodChannel('waffra/password_kdf')"));
  expect(dart,contains('if(Platform.isAndroid){'));
  expect(dart,contains('Uint8List.fromList(salt)'));
  expect(dart,contains('if(derived!=null&&derived.length==32)return derived;'));
  expect(dart,contains('Isolate.run<List<int>>('));
  expect(dart,contains('Pbkdf2(macAlgorithm:Hmac.sha256()'));
  expect(dart,contains('iterations:_iterations,bits:256'));
  expect(dart,contains('SecretKey(utf8.encode(password)),nonce:salt'));
 });

 test('native selftest vector uses exactly Dart UTF8 PBKDF2 SHA256', () async {
  const password='اختبار🟢Waffra';
  const expected='25c045b0f0158c986f57d1e4f260b73009c8ce9cf40a8b2fb4d44cd4e7cb9cd2';
  final salt=List<int>.generate(32,(i)=>i);
  final key=await Pbkdf2(macAlgorithm:Hmac.sha256(),iterations:1000,bits:256)
   .deriveKey(secretKey:SecretKey(utf8.encode(password)),nonce:salt);
  final bytes=await key.extractBytes();
  final hex=bytes.map((b)=>b.toRadixString(16).padLeft(2,'0')).join();
  expect(hex,expected);
  final native=File('native/WaffraMainActivity.kt').readAsStringSync();
  expect(native,contains(password));
  expect(native,contains(expected));
  expect(native,contains('if (!java.security.MessageDigest.isEqual(actual, expected))'));
  expect(native,contains('throw IllegalStateException("Native PBKDF2 encoding mismatch")'));
 });

 test('foreground retains encrypted SMS without starting a competing FlutterEngine', () {
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final worker=File('native/WaffraAutoSmsWorker.kt').readAsStringSync();
  final receiver=File('native/WaffraAutoSmsReceiver.kt').readAsStringSync();
  expect(activity,contains('override fun onStart() {'));
  expect(activity,contains('WaffraAutoSmsWorker.setForegroundUiActive(true)'));
  expect(activity,contains('override fun onStop() {'));
  expect(activity,contains('WaffraAutoSmsWorker.setForegroundUiActive(false)'));
  expect(worker,contains('@Volatile private var foregroundUiActive = false'));
  expect(worker,contains('if (isForegroundUiActive() || !WaffraAutoSmsStore.enabled(context))'));
  expect(worker,contains('fun enqueue(context: Context)'));
  // No extra FlutterEngine on first consent or verified foreground relogin.
  final resume=activity.split('"resumeAutoSmsAfterSignIn" -> {')[1]
   .split('"autoSmsNotificationsEnabled"')[0];
  final consent=activity.split('"setAutoSmsEnabled" -> {')[1]
   .split('"restartCompletedSmsHistory"')[0];
  expect(resume,isNot(contains('WaffraAutoSmsWorker.enqueue(app)')));
  expect(consent,isNot(contains('WaffraAutoSmsWorker.enqueue(app)')));
  // Receiver still durably stores and schedules work while app is backgrounded.
  expect(receiver,contains('WaffraAutoSmsStore.offer('));
  expect(receiver,contains('WaffraAutoSmsWorker.enqueue(context)'));
  expect(activity,contains('WaffraAutoSmsStore.pending(app)'));
 });

 test('SMS pending result encodes outside Android UI; errors remain explicit', () {
  final activity=File('native/WaffraMainActivity.kt').readAsStringSync();
  final pending=activity.split('"pendingAutoBankSms" -> {')[1]
   .split('"pendingAutoBankSmsById" -> {')[0];
  expect(pending,contains('smsHistoryExecutor.execute {'));
  expect(pending,contains('val pending = WaffraAutoSmsStore.pending(app)'));
  expect(pending,contains('result.success(pending)'));
  expect(pending,isNot(contains('runOnUiThread { result.success(pending) }')));
  expect(pending,contains('result.error("SMS_REVIEW_READ_FAILED"'));
 });
}

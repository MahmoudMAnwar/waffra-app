import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// M425: Server-side phone identity candidate, deliberately OFF in release
/// until OTP, App Check, backend password service and account migration pass.
/// The backend, never SharedPreferences, decides password validity.
abstract final class WaffraPhoneSecureAuth {
  static const enabled = bool.fromEnvironment(
    'WAFFRA_SECURE_PHONE_AUTH_ENABLED', defaultValue: false);
  static const region = 'me-central2';

  static String e164(String raw) {
    if (!RegExp(r'^05[0-9]{8}$').hasMatch(raw)) {
      throw StateError('invalid_saudi_phone');
    }
    return '+966' + raw.substring(1);
  }

  static String? get currentUid =>
    Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

  static Future<void> signOut() async {
    if (Firebase.apps.isNotEmpty) await FirebaseAuth.instance.signOut();
  }

  static Future<void> initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity : AndroidProvider.debug);
  }

  static Future<PhoneAuthCredential> _phoneOtp(
      String phone, Future<String?> Function() requestCode) async {
    final result = Completer<PhoneAuthCredential>();
    void fail(Object error) {
      if (!result.isCompleted) {
        result.completeError(StateError('phone_verification_unavailable'));
      }
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: e164(phone),
      timeout: const Duration(seconds: 90),
      verificationCompleted: (credential) {
        if (!result.isCompleted) result.complete(credential);
      },
      verificationFailed: fail,
      codeSent: (verificationId, _) async {
        try {
          final code = await requestCode();
          if (!result.isCompleted) {
            if (code == null || !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
              fail(StateError('invalid_code'));
              return;
            }
            result.complete(PhoneAuthProvider.credential(
              verificationId: verificationId, smsCode: code));
          }
        } catch (error) {
          fail(error);
        }
      },
      codeAutoRetrievalTimeout: (_) {
        // Do not auto-confirm a phone without OS proof or a user OTP.
      },
    );
    return result.future.timeout(const Duration(minutes: 3));
  }

  /// A former Google user must be signed into the ORIGINAL Firebase UID.
  /// Never overwrite the previous user with signInWithCredential in migration.
  static Future<String> enrollWithOtp({
    required String phone,
    required String password,
    required Future<String?> Function() requestCode,
  }) async {
    if (!enabled) throw StateError('secure_phone_auth_disabled');
    await initialize();
    final credential = await _phoneOtp(phone, requestCode);
    final auth = FirebaseAuth.instance;
    final existing = auth.currentUser;
    if (existing == null) {
      await auth.signInWithCredential(credential);
    } else if (existing.phoneNumber == e164(phone)) {
      await existing.reauthenticateWithCredential(credential);
    } else {
      await existing.linkWithCredential(credential);
    }
    final user = auth.currentUser;
    if (user == null || user.phoneNumber != e164(phone)) {
      throw StateError('phone_owner_mismatch');
    }
    await user.getIdToken(true);
    final reply = await FirebaseFunctions.instanceFor(region: region)
      .httpsCallable('waffraEnrollPhonePassword')
      .call(<String,Object>{'phone':phone,'password':password})
      .timeout(const Duration(seconds: 35));
    if (reply.data is! Map || (reply.data as Map)['enrolled'] != true) {
      throw StateError('server_enrollment_not_confirmed');
    }
    return user.uid;
  }

  static Future<String> signIn({
    required String phone,
    required String password,
  }) async {
    if (!enabled) throw StateError('secure_phone_auth_disabled');
    await initialize();
    final reply = await FirebaseFunctions.instanceFor(region: region)
      .httpsCallable('waffraSignInPhonePassword')
      .call(<String,Object>{'phone':phone,'password':password})
      .timeout(const Duration(seconds: 35));
    final raw = reply.data;
    final token = raw is Map ? raw['customToken'] : null;
    if (token is! String || token.length < 30) {
      throw StateError('server_identity_unavailable');
    }
    final credential = await FirebaseAuth.instance.signInWithCustomToken(token);
    final user = credential.user;
    if (user == null || user.phoneNumber != e164(phone)) {
      await FirebaseAuth.instance.signOut();
      throw StateError('signed_phone_owner_mismatch');
    }
    return user.uid;
  }

  static Future<void> resetWithOtp({
    required String phone,
    required String newPassword,
    required Future<String?> Function() requestCode,
  }) async {
    if (!enabled) throw StateError('secure_phone_auth_disabled');
    await initialize();
    final credential = await _phoneOtp(phone,requestCode);
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInWithCredential(credential);
    } else {
      await auth.currentUser!.reauthenticateWithCredential(credential);
    }
    final user = auth.currentUser;
    if (user == null || user.phoneNumber != e164(phone)) {
      throw StateError('phone_owner_mismatch');
    }
    await user.getIdToken(true);
    final reply = await FirebaseFunctions.instanceFor(region:region)
      .httpsCallable('waffraResetPhonePassword')
      .call(<String,Object>{'phone':phone,'newPassword':newPassword})
      .timeout(const Duration(seconds:35));
    if (reply.data is! Map || (reply.data as Map)['reset'] != true) {
      throw StateError('password_reset_not_confirmed');
    }
    await auth.signOut();
  }
}

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Delegates fingerprint/face verification to the OS. The app never reads
/// fingerprint data or chooses the sensor's position on the screen.
class WaffraBiometrics {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Biometric-only OS confirmation for deleting the optional public AI
  /// model. No PIN or password fallback is allowed for this destructive step.
  static Future<bool> confirmAiModelRemoval({required bool english}) async {
    try {
      if (!await isAvailable()) return false;
      return await _auth.authenticate(
        localizedReason: english
          ? 'Confirm removing the downloaded Waffra AI model'
          : 'أكد ببصمة الجهاز حذف نموذج الذكاء الاصطناعي من وفرة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Required per-session biometric OS challenge. Does not allow a device
  /// credential/PIN fallback and does not continue silently in background.
  static Future<bool> unlockMandatory() async {
    try {
      if (!await isAvailable()) return false;
      return await _auth.authenticate(
        localizedReason: 'أكد ببصمة جهازك فتح وفرة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> unlock() async {
    try {
      if (!await isAvailable()) return false;
      return await _auth.authenticate(
        localizedReason: 'استخدم بصمة جهازك المسجلة لفتح وفرة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

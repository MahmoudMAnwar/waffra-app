import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class WaffraBiometrics {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> unlock() async {
    try {
      if (!await isAvailable()) return false;
      return await _auth.authenticate(
        localizedReason: 'استخدم بصمة جهازك لفتح تطبيق وفرة',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

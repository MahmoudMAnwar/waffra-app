import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_legacy_finance_writer_coordinator.dart';

/// M217: The shipped login/profile/PIN writer participates in the exact same
/// cross-engine native source lease as Home and the Android quick-add widget.
///
/// This class is deliberately a guarded LEGACY adapter, NOT permission to
/// promote SharedPreferences into a production encrypted account database.
/// The coordinator rechecks activation/key/checkpoint under the lock, then
/// refuses all these writes if SQLCipher becomes active or needs recovery.
class WaffraLiveAccountWriteAuthority {
  const WaffraLiveAccountWriteAuthority({
    this.coordinator = const WaffraLegacyFinanceWriterCoordinator(),
  });

  final WaffraLegacyFinanceWriterCoordinator coordinator;

  static const _personKeys = <String>{
    'name', 'email', 'provider', 'gender', 'avatar', 'phone', 'birthday',
  };

  static void _requirePersonJson(String raw) {
    if (raw.isEmpty || raw.length > 16384) {
      throw StateError('Account profile value is outside approved limits.');
    }
    Object? value;
    try {
      value = jsonDecode(raw);
    } catch (_) {
      throw StateError('Account profile JSON is invalid.');
    }
    if (value is! Map<String, dynamic> ||
        value.keys.any((key) => !_personKeys.contains(key)) ||
        value.values.any((field) => field != null && field is! String)) {
      throw StateError('Account profile contains unapproved fields.');
    }
  }

  Future<void> saveProfile({
    required String profileJson,
    String? registeredProfileJson,
    required String loginMethod,
    String? email,
    String? phone,
  }) async {
    _requirePersonJson(profileJson);
    if (registeredProfileJson != null) {
      _requirePersonJson(registeredProfileJson);
    }
    if (!const <String>{'Google', 'Apple', 'Phone', 'Local'}
        .contains(loginMethod)) {
      throw StateError('Unknown account sign-in provider.');
    }
    if ((email != null && email.length > 1024) ||
        (phone != null && phone.length > 1024)) {
      throw StateError('Account login hint exceeds approved limits.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      await prefs.setString('waffra_profile', profileJson);
      if (registeredProfileJson != null) {
        await prefs.setString(
          'waffra_registered_profile', registeredProfileJson,
        );
      }
      await prefs.setString('waffra_last_login_method', loginMethod);
      if (email != null && email.isNotEmpty) {
        await prefs.setString('waffra_last_login_email', email);
      }
      if (phone != null && phone.isNotEmpty) {
        await prefs.setString('waffra_last_login_phone', phone);
      }
    });
  }

  Future<void> signOut() => coordinator.withCurrentPreferences((prefs) async {
    // Keep the user-approved "welcome back" registration hints, but never
    // clear or overwrite any finance source or source activation pointer.
    await prefs.remove('waffra_profile');
    await prefs.setBool('waffra_signed_out_explicitly', true);
  });

  Future<void> replacePinVerifier(String? nextVerifier) async {
    if (nextVerifier != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(nextVerifier)) {
      throw StateError('PIN verifier has an invalid SHA-256 representation.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      if (nextVerifier == null) {
        await prefs.remove('waffra_pin_sha256');
      } else {
        await prefs.setString('waffra_pin_sha256', nextVerifier);
      }
    });
  }
}

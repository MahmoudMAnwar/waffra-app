import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'waffra_sms_cloud_redactor.dart';
import 'waffra_cloudflare_sms_gateway.dart';

/// M421: separately opt-in server-assisted bank-SMS interpretation.
/// Never call the provider directly from Android. No client API secret.
/// The model's output NEVER grants ledger-posting authority.
abstract final class WaffraSmsCloudService {
  static const _preference = 'waffra_cloud_sms_consent_v1_';
  static bool _appCheckActivated = false;

  static Future<void> _ready() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    if (!_appCheckActivated) {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity : AndroidProvider.debug);
      _appCheckActivated = true;
    }
  }

  static String? _owner() {
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<bool> hasConsent() async {
    if (!Platform.isAndroid) return false;
    final owner = _owner();
    if (owner == null || owner.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool('$_preference$owner') == true;
  }

  /// Separate server-side consent record is required; a local switch alone
  /// cannot authorize the callable endpoint to process any bank message.
  static Future<bool> setConsent(bool enable) async {
    if (!Platform.isAndroid) return false;
    // M423: Worker mode requires a real signed Firebase session. Local
    // passwords or a bundled staging token do not authorize cloud access.
    // The Worker verifies identity independently on the server.
    if (WaffraCloudflareSmsGateway.configured) {
      try {
        await _ready();
        final owner = _owner();
        final user = FirebaseAuth.instance.currentUser;
        if (owner == null || user == null || user.isAnonymous ||
            WaffraCloudflareSmsGateway.validEndpoint(
              WaffraCloudflareSmsGateway.configuredUrl) == null) return false;
        final prefs = await SharedPreferences.getInstance();
        return prefs.setBool('$_preference$owner', enable);
      } catch (_) {
        return false;
      }
    }

    if (!enable) {
      final owner = _owner();
      if (owner == null) return false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_preference$owner', false);
      // Local processing stops immediately even if Firebase is unavailable.
      try {
        await _ready();
        await FirebaseFunctions.instanceFor(region: 'me-central2')
            .httpsCallable('setWaffraSmsCloudConsent')
            .call(<String, Object>{'enabled': false, 'version': 1})
            .timeout(const Duration(seconds: 15));
        return true;
      } catch (_) {
        return false; // User opted out locally; remote revocation needs retry.
      }
    }
    try {
      await _ready();
      final owner = _owner();
      if (owner == null || owner.isEmpty) return false;
      final reply = await FirebaseFunctions.instanceFor(region: 'me-central2')
          .httpsCallable('setWaffraSmsCloudConsent')
          .call(<String, Object>{'enabled': true, 'version': 1})
          .timeout(const Duration(seconds: 15));
      final response = reply.data;
      if (response is! Map || response['enabled'] != true) return false;
      final prefs = await SharedPreferences.getInstance();
      return prefs.setBool('$_preference$owner', true);
    } catch (_) {
      return false; // Never pretend cloud analysis is active.
    }
  }

  /// This is intentionally a suggestion only, separate from the verified
  /// bank-source amount, direction, currency and atomic finance writer.
  static Future<Map<String, Object?>?> analyzeIfConsented(String source) async {
    if (!await hasConsent()) return null;
    final redacted = WaffraSmsCloudRedactor.redact(source);
    if (redacted == null) return null;
    // Explicitly configured Worker takes precedence over Firebase Callable.
    // Without a signed Firebase ID token, fail closed to offline analysis.
    if (WaffraCloudflareSmsGateway.configured) {
      try {
        await _ready();
        final user = FirebaseAuth.instance.currentUser;
        final endpoint = WaffraCloudflareSmsGateway.validEndpoint(
          WaffraCloudflareSmsGateway.configuredUrl);
        if (user == null || user.isAnonymous || endpoint == null) return null;
        final signedToken = await user.getIdToken();
        if (signedToken == null || signedToken.isEmpty) return null;
        return WaffraCloudflareSmsGateway.analyze(
          source: source, firebaseIdToken: signedToken, endpoint: endpoint);
      } catch (_) {
        return null;
      }
    }

    try {
      await _ready();
      if (_owner() == null) return null;
      final result = await FirebaseFunctions.instanceFor(region: 'me-central2')
          .httpsCallable('analyzeWaffraBankSms')
          .call(<String, Object>{'cloudConsent': true, 'redactedSms': redacted})
          .timeout(const Duration(seconds: 18));
      final value = result.data;
      if (value is! Map || value['verifiedForPosting'] != false ||
          value['requiresReview'] is! bool) return null;
      final kind = value['kind'];
      if (kind is! String ||
          !{'income', 'expense', 'transfer', 'card_settlement', 'uncertain'}
              .contains(kind)) return null;
      final rawAmount = value['amount'];
      final amount = rawAmount is num ? rawAmount.toDouble() : null;
      if (amount != null &&
          (!amount.isFinite || amount < 0 || amount > 100000000)) return null;
      final rawFee = value['fee'];
      final fee = rawFee is num ? rawFee.toDouble() : null;
      if (fee != null && (!fee.isFinite || fee < 0)) return null;
      final currency = value['currency'];
      if (currency != null && (currency is! String ||
          !RegExp(r'^[A-Z]{3}$').hasMatch(currency))) return null;
      final merchant = value['merchant'];
      if (merchant != null && (merchant is! String || merchant.length > 90)) {
        return null;
      }
      // Only sanitized structured model output is returned. Original SMS
      // remains in the encrypted native intake queue on the device.
      return <String, Object?>{
        'kind': kind, 'amount': amount, 'currency': currency,
        'merchant': merchant, 'fee': fee,
        'requiresReview': value['requiresReview'],
        'verifiedForPosting': false,
      };
    } catch (_) {
      // No sensitive contents, prompts or provider errors in logs.
      return null;
    }
  }
}

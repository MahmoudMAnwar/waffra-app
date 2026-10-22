import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_private_release_diagnostics.dart';

/// Compile-time reviewed release switch, OFF for all current M107 builds.
/// Even when activated, the native AndroidManifest MUST explicitly suppress
/// automatic collection before Flutter launches, until the user opts in.
const bool waffraCrashlyticsReviewed = bool.fromEnvironment(
  'WAFFRA_CRASHLYTICS_READY', defaultValue: false,
);

class WaffraCrashlyticsOptIn {
  WaffraCrashlyticsOptIn._();

  static const consentKey = 'waffra_crash_diagnostics_consent_v1';

  static bool mayTransmit({
    required bool consent,
    required bool configReviewed,
  }) => consent && configReviewed;

  /// Call after Firebase.initializeApp() on launch and after each consent
  /// change. Never invoke raw recordError on arbitrary exceptions or user
  /// data. SDK-level native collection remains disabled without consent.
  static Future<bool> synchronize() async {
    if (Firebase.apps.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final allow = mayTransmit(
      consent: prefs.getBool(consentKey) ?? false,
      configReviewed: waffraCrashlyticsReviewed,
    );
    final sdk = FirebaseCrashlytics.instance;
    await sdk.setCrashlyticsCollectionEnabled(allow);
    if (!allow) await sdk.deleteUnsentReports();
    return allow;
  }

  static Future<bool> setConsent(bool consent) async {
    if (consent && !waffraCrashlyticsReviewed) {
      // A user toggle cannot bypass incomplete SDK/privacy review.
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(consentKey, consent)) {
      throw StateError('Diagnostics permission could not be persisted.');
    }
    return synchronize();
  }

  static Future<void> sendSafeEvent(
    WaffraSafeDiagnosticCode code,
  ) async {
    if (!await synchronize()) return;
    // Fixed allowlisted tags only. Do NOT add raw exception messages,
    // stack traces, account IDs, receipt paths or transaction summaries.
    await FirebaseCrashlytics.instance.log(
      WaffraSafeDiagnosticEvent(code).safeTag,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_account_deletion.dart';
import 'package:waffra/diagnostics/waffra_crashlytics_opt_in.dart';

void main() {
  test('M107 actual delete-account callable is OFF before server rollout', () {
    expect(waffraAccountDeletionReleased, isFalse);
  });

  test('M107 Crashlytics is OFF unless consent AND reviewed build exist', () {
    expect(waffraCrashlyticsReviewed, isFalse);
    for (final consent in [false, true]) {
      expect(WaffraCrashlyticsOptIn.mayTransmit(
        consent: consent, configReviewed: false,
      ), isFalse);
    }
    expect(WaffraCrashlyticsOptIn.mayTransmit(
      consent: false, configReviewed: true,
    ), isFalse);
    expect(WaffraCrashlyticsOptIn.mayTransmit(
      consent: true, configReviewed: true,
    ), isTrue);
  });

  test('M107 opt-in storage key contains no user financial information', () {
    expect(WaffraCrashlyticsOptIn.consentKey,
      'waffra_crash_diagnostics_consent_v1');
    expect(WaffraCrashlyticsOptIn.consent.value, isFalse);
  });
}

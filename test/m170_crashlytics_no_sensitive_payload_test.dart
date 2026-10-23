import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/diagnostics/waffra_crashlytics_opt_in.dart';
import 'package:waffra/diagnostics/waffra_private_release_diagnostics.dart';

/// M170 tests do not open Firebase or send diagnostics.
void main() {
  test('collection is disabled by default and consent cannot bypass release review', () {
    expect(waffraCrashlyticsReviewed, isFalse);
    for (final permission in [false, true]) {
      expect(WaffraCrashlyticsOptIn.mayTransmit(
        consent: permission,
        configReviewed: false,
      ), isFalse);
    }
    expect(WaffraCrashlyticsOptIn.mayTransmit(
      consent: false,
      configReviewed: true,
    ), isFalse);
  });

  test('only enumerated safe tags can reach an injected fake diagnostic sender',
      () async {
    final tags = <String>[];
    final disabled = WaffraPrivateDiagnostics(
      userConsented: true,
      releaseConfigurationVerified: false,
      sender: (event) async => tags.add(event.safeTag),
    );
    for (final code in WaffraSafeDiagnosticCode.values) {
      expect(await disabled.report(code), isFalse);
    }
    expect(tags, isEmpty);

    final enabled = WaffraPrivateDiagnostics(
      userConsented: true,
      releaseConfigurationVerified: true,
      sender: (event) async => tags.add(event.safeTag),
    );
    for (final code in WaffraSafeDiagnosticCode.values) {
      expect(await enabled.report(code), isTrue);
    }
    expect(tags, hasLength(WaffraSafeDiagnosticCode.values.length));
    final safe = RegExp(r'^waffra_[a-zA-Z]+$');
    for (final tag in tags) {
      expect(safe.hasMatch(tag), isTrue);
      for (final forbidden in ['iban', 'sms', 'bank', 'receiptpath',
                               'amount', 'password', 'token', 'phone', '@']) {
        expect(tag.toLowerCase(), isNot(contains(forbidden)));
      }
    }
  });

  test('no direct free-text Crashlytics reporting is permitted in diagnostics boundary', () {
    final source = File(
      'lib/diagnostics/waffra_crashlytics_opt_in.dart',
    ).readAsStringSync();
    final typed = File(
      'lib/diagnostics/waffra_private_release_diagnostics.dart',
    ).readAsStringSync();
    expect(source, contains('WaffraSafeDiagnosticEvent(code).safeTag'));
    expect(source, contains('await sdk.deleteUnsentReports();'));
    expect(source, isNot(contains('.recordError(')));
    expect(source, isNot(contains('.setUserIdentifier(')));
    expect(source, isNot(contains('.setCustomKey(')));
    expect(typed, contains('enum WaffraSafeDiagnosticCode'));
    expect(typed, isNot(contains('String rawMessage')));
    expect(typed, isNot(contains('Object error')));
  });
}

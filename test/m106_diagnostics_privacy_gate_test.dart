import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/diagnostics/waffra_private_release_diagnostics.dart';

void main() {
  test('M106 privacy: diagnostics are disabled without user opt-in', () async {
    var sent = 0;
    final monitor = WaffraPrivateDiagnostics(
      sender: (_) async { sent++; },
    );
    for (final code in WaffraSafeDiagnosticCode.values) {
      expect(await monitor.report(code), isFalse);
    }
    expect(sent, 0);
  });

  test('M106 privacy: consent alone never enables unverified SDK collection',
      () async {
    var sent = 0;
    final monitor = WaffraPrivateDiagnostics(
      userConsented: true,
      sender: (_) async { sent++; },
    );
    expect(await monitor.report(WaffraSafeDiagnosticCode.appStartupBlocked),
        isFalse);
    expect(sent, 0);
  });

  test('M106 privacy: verified opt-in transmits ONLY bounded static tags',
      () async {
    final tags = <String>[];
    final monitor = WaffraPrivateDiagnostics(
      userConsented: true,
      releaseConfigurationVerified: true,
      sender: (event) async { tags.add(event.safeTag); },
    );
    for (final code in WaffraSafeDiagnosticCode.values) {
      expect(await monitor.report(code), isTrue);
    }
    expect(tags.length, WaffraSafeDiagnosticCode.values.length);
    for (final tag in tags) {
      expect(tag, startsWith('waffra_'));
      expect(tag, matches(RegExp(r'^waffra_[a-zA-Z]+$')));
      expect(tag, isNot(contains('SMS')));
      expect(tag, isNot(contains('@')));
      expect(tag, isNot(contains('/')));
      expect(tag, isNot(contains('amount')));
      expect(tag, isNot(contains('token')));
    }
  });

  test('M106 privacy: no free-text parameter accepts financial contents', () {
    final event = WaffraSafeDiagnosticEvent(
      WaffraSafeDiagnosticCode.cloudRevisionConflict,
    );
    expect(event.safeTag, 'waffra_cloudRevisionConflict');
    expect(event.safeTag, isNot(contains('purchase')));
  });

  test('M106 privacy: sender errors do not silently claim report delivered',
      () async {
    final monitor = WaffraPrivateDiagnostics(
      userConsented: true,
      releaseConfigurationVerified: true,
      sender: (_) async => throw StateError('disposable test transport'),
    );
    await expectLater(
      monitor.report(WaffraSafeDiagnosticCode.reportRenderFailed),
      throwsStateError,
    );
  });
}

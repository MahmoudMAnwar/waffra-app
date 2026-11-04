import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_mandatory_biometric_gate.dart';

void main() {
  test('M443 screenshot and transient focus loss never relock finances', () {
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.resumed),
        isFalse);
    expect(WaffraBiometricSessionGuard.mustLockOn(AppLifecycleState.inactive),
        isFalse, reason: 'Android screenshot overlays are not an app exit');
    for (final state in [
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      expect(WaffraBiometricSessionGuard.mustLockOn(state), isTrue,
          reason: 'An actual app background transition must require biometrics');
    }
    expect(WaffraBiometricSessionGuard.canReveal(
        authenticated: false, inForeground: true), isFalse);
    expect(WaffraBiometricSessionGuard.canReveal(
        authenticated: true, inForeground: false), isFalse);
  });

  test('M443 Home retains biometric lock on actual background only', () {
    final home = File('lib/main.dart').readAsStringSync();
    final lifecycle = home.substring(
        home.indexOf(' @override void didChangeAppLifecycleState('),
        home.indexOf(' @override void dispose(){WaffraRegionalCopy.'));
    expect(lifecycle, contains('WaffraBiometricSessionGuard.mustLockOn(state)'));
    expect(lifecycle, contains('state==AppLifecycleState.paused||'));
    expect(lifecycle, contains('state==AppLifecycleState.hidden||'));
    expect(lifecycle, contains('state==AppLifecycleState.detached){'));
    expect(lifecycle, contains('setState(()=>locked=true);'));
    expect(home, contains('locked?WaffraMandatoryBiometricGate('));
    // Screenshot permission remains an independent user setting.
    expect(home, contains('setScreenshotsAllowed'));
  });

  test('M443 no merchant selection, brand logos or remote logo assets in active UI', () {
    final home = File('lib/main.dart').readAsStringSync();
    for (final disabled in [
      "import 'waffra_merchant_brands.dart';",
      "Key('waffra-transaction-select-merchant')",
      "Key('waffra-transaction-clear-merchant')",
      'waffraChooseMerchantBrand(',
      'WaffraMerchantLogo(',
      'WaffraMerchantBrands.match(',
      'selectedMerchantOverride',
    ]) {
      expect(home, isNot(contains(disabled)), reason: disabled);
    }
    expect(home, contains('categoryIcon(c.icon)'));
    expect(home, contains('WaffraIllustration(topic:cat.icon'));
  });

  test('M443 legacy transaction amounts and merchant keys are not wiped', () {
    final home = File('lib/main.dart').readAsStringSync();
    expect(home, contains("'merchantKey':merchantKey"));
    expect(home, contains('merchantKey:initial?.merchantKey??'));
    expect(home, contains('existingMerchantKey:e.merchantKey'));
    expect(home, contains('candidateMerchantKey:result.merchantKey'));
  });
}

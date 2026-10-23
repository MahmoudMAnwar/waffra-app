import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_cutover_readiness_gate.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_cutover_release_gate.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

/// M165 — fail-closed production cutover review, disposable local state only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m165-no-cutover-');
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"synthetic-existing-ledger"}]',
      'waffra_language': 'ar',
      'waffra_profile': '{"provider":"google","testOnly":true}',
    });
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  WaffraProductionFinanceSourceGuard guard({String? key}) =>
      WaffraProductionFinanceSourceGuard(
        directoryProvider: () async => root,
        secureKeyReader: () async => key,
        checkpointReader: (_, __) async => null,
      );

  test('empty new install is guarded legacy, not authorized SQLCipher cutover',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('entries');
    final result = await guard().inspect(preferences: prefs);
    expect(result.source, WaffraProductionFinanceSource.guardedLegacy);
    expect(result.legacyIsSafe, isTrue);
    final decision = const WaffraProductionCutoverReleaseGate().inspect(
      const WaffraProductionCutoverEvidence(
        storage: WaffraCutoverReadinessReport(
          sourceDigest: 'synthetic-no-data', blockers: [],
        ),
        routes: WaffraFinanceRouteAudit(),
      ),
    );
    expect(decision.automaticallyActivateSqlCipher, isFalse);
    expect(decision.eligibleForHumanReleaseReview, isFalse);
    expect(decision.blockers, contains('human_release_approval_missing'));
    expect(decision.blockers, contains('signed_android_device_unverified'));
    expect(decision.blockers, contains('two_physical_devices_restore_unverified'));
    await prefs.reload();
    expect(prefs.getString('entries'), before);
    expect(prefs.containsKey(WaffraLiveLegacyFinanceGuard.activeKey), isFalse);
    expect(prefs.containsKey(WaffraLiveLegacyFinanceGuard.pendingKey), isFalse);
  });

  test('pending cutover rejects both Home and Widget reads, preserving profile',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getString('entries');
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    final routing = WaffraProductionFinanceRoutingGate(sourceGuard: guard());
    for (final route in [
      WaffraFinanceRoute.dashboardRead,
      WaffraFinanceRoute.widgetRead,
      WaffraFinanceRoute.backupRestore,
    ]) {
      await expectLater(routing.requireGuardedLegacy(route: route),
          throwsA(isA<StateError>()));
    }
    await prefs.reload();
    expect(prefs.getString('entries'), before);
    expect(prefs.getString('waffra_profile'),
        '{"provider":"google","testOnly":true}');
    expect(prefs.getBool(WaffraLiveLegacyFinanceGuard.pendingKey), isTrue);
  });

  test('key-only encrypted evidence fails closed for every app/widget route',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final sourceGuard = guard(key: 'test-only-orphaned-key');
    final diagnostic = await sourceGuard.inspect(preferences: prefs);
    expect(diagnostic.source,
        WaffraProductionFinanceSource.manualRecoveryRequired);
    expect(diagnostic.reasonCode, 'vault_key_file_mismatch');
    final routing = WaffraProductionFinanceRoutingGate(
      sourceGuard: sourceGuard,
    );
    for (final route in [
      WaffraFinanceRoute.appStartup,
      WaffraFinanceRoute.widgetStartup,
      WaffraFinanceRoute.manualTransactionSave,
    ]) {
      await expectLater(routing.requireGuardedLegacy(route: route),
          throwsA(isA<StateError>()));
    }
    await prefs.reload();
    expect(prefs.getString('entries'), contains('synthetic-existing-ledger'));
    expect(prefs.containsKey(WaffraLiveLegacyFinanceGuard.activeKey), isFalse);
  });
}

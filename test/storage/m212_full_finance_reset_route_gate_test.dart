import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

/// M212: all experiments use disposable finance and no real key or bank data.
class _SyntheticSource extends WaffraProductionFinanceSourceGuard {
  _SyntheticSource(this.current);
  WaffraProductionFinanceSourceReport current;
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => current;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const safe = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
  const recovery = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'pending_source_transition',
  );
  const encryptedNotCertified = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );

  late Directory workspace;
  late _SyntheticSource guard;
  late WaffraVerifiedFinanceAuthority authority;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': '[]',
      'waffra_sms_hashes_v1': <String>[],
      'waffra_goals_v24': '[]',
      'waffra_recurring_v24': '[]',
      'waffra_profile': '{"name":"synthetic user profile"}',
    });
    workspace = await Directory.systemTemp.createTemp('m212-route-reset-');
    guard = _SyntheticSource(safe);
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: guard,
      legacy: WaffraHomeFinancePersistence(
        coordinator: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: workspace,
          testBypassNativeLock: true,
        ),
      ),
    );
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  Future<void> resetWith(
    WaffraFinanceAuthorityRead baseline, {
    WaffraFinanceRoute route = WaffraFinanceRoute.fullFinanceReset,
    bool approved = true,
    bool biometric = true,
    bool backupSaved = true,
  }) async {
    await authority.resetVerifiedFinance(
      route: route,
      baseline: baseline,
      encryptedBackup: 'never-to-be-read-or-stored',
      backupPassword: 'synthetic-password-length-32',
      confirmationPhrase: 'RESET_WAFFRA_FINANCE',
      userConfirmed: approved,
      biometricVerified: biometric,
      externalBackupSaved: backupSaved,
    );
  }

  test('M212 fullFinanceReset cannot erase legacy money, goals or SMS hashes',
      () async {
    final source = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    await expectLater(resetWith(source), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getStringList('waffra_sms_hashes_v1'), <String>[]);
    expect(prefs.getString('waffra_goals_v24'), '[]');
    expect(prefs.getString('waffra_profile'),
        '{"name":"synthetic user profile"}');
  });

  test('M212 reset needs biometric, external authenticated backup and confirmation',
      () async {
    final source = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    await expectLater(resetWith(source, approved: false), throwsStateError);
    await expectLater(resetWith(source, biometric: false), throwsStateError);
    await expectLater(resetWith(source, backupSaved: false), throwsStateError);
  });

  test('M212 full reset cannot be invoked using a wrong finance route', () async {
    final source = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    await expectLater(
      resetWith(source, route: WaffraFinanceRoute.transactionEdit),
      throwsArgumentError,
    );
  });

  test('M212 pending SQLCipher activation fails closed, never to legacy reset',
      () async {
    final old = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    guard.current = recovery;
    await expectLater(resetWith(old), throwsStateError);
    guard.current = encryptedNotCertified;
    await expectLater(resetWith(old), throwsStateError);
    final pref = await SharedPreferences.getInstance();
    await pref.reload();
    expect(pref.getString('entries'), '[]');
    expect(pref.getString('waffra_profile'),
        '{"name":"synthetic user profile"}');
  });

  test('M212 all 24 finance routes remain unverified without device evidence',
      () {
    expect(WaffraFinanceRoute.values.length, 24);
    const audit = WaffraFinanceRouteAudit();
    expect(audit.eligibleForIndependentReview, isFalse);
    for (final route in WaffraFinanceRoute.values) {
      expect(audit.blockers, contains('unverified_route_${route.name}'));
    }
    expect(audit.blockers, contains('encrypted_key_recovery_unverified'));
    expect(audit.blockers, contains('two_witness_recovery_unverified'));
    expect(audit.blockers, contains('app_widget_lock_unverified'));
    expect(audit.blockers, contains('backup_restore_unverified'));
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_finance_read_view.dart';
import 'package:waffra/storage/waffra_home_finance_persistence.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _Probe extends WaffraProductionFinanceSourceGuard {
  _Probe(this.current);
  WaffraProductionFinanceSourceReport current;

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => current;
}

class _Legacy extends WaffraHomeFinancePersistence {
  _Legacy();
  int readCount = 0;
  int writeCount = 0;
  int smsCount = 0;

  @override
  Future<WaffraHomeFinanceLoaded> loadWithWitness() async {
    readCount++;
    final prefs = await SharedPreferences.getInstance();
    return WaffraHomeFinanceLoaded(
      finance: WaffraFinanceReadView.fromLegacy(prefs),
      widgetRevision: prefs.getString('waffra_widget_last_save_v1'),
    );
  }

  @override
  Future<String> saveLegacy({
    required Map<String, Object> snapshot,
    required String? expectedLedgerRaw,
    required String? expectedWidgetRevision,
  }) async {
    writeCount++;
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), expectedLedgerRaw);
    for (final entry in snapshot.entries) {
      if (entry.value is String) {
        await prefs.setString(entry.key, entry.value as String);
      }
    }
    return prefs.getString('entries') ?? '[]';
  }

  @override
  Future<WaffraConfirmedLegacySmsResult> commitConfirmedLegacySms({
    required List<Map<String, Object?>> records,
    required List<String> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
    List<Map<String, Object?>> proposedCategories = const [],
    Future<void> Function(List<Map<String, Object?>>, List<String>)?
        protectedNotesBeforeLegacyCommit,
  }) async {
    smsCount++;
    if (!userConfirmed) throw StateError('Not confirmed');
    for (final record in records) {
      expect(record['sourceType'], 'sms');
      expect(record['notes'], '');
    }
    return const WaffraConfirmedLegacySmsResult(
      savedEntriesRaw: '[]',
      savedHashes: <String>[],
      widgetRevision: null,
      added: 1,
      savedIncome: 0,
      savedExpenses: 1,
      incomeMinor: 0,
      expenseMinor: 125,
      skippedDuplicates: 0,
    );
  }
}

class _PausedSourceInspection extends WaffraProductionFinanceSourceGuard {
  bool pauseNext = false;
  final reached = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async {
    if (pauseNext) {
      pauseNext = false;
      reached.complete();
      await resume.future;
    }
    return const WaffraProductionFinanceSourceReport(
      source: WaffraProductionFinanceSource.guardedLegacy,
      reasonCode: 'legacy_source_verified',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const legacyReport = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.guardedLegacy,
    reasonCode: 'legacy_source_verified',
  );
  const pending = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.manualRecoveryRequired,
    reasonCode: 'pending_source_transition',
  );
  const sql = WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'all_live_writers_not_yet_routed',
  );

  setUp(() => SharedPreferences.setMockInitialValues({
    'entries': '[]',
    'waffra_widget_last_save_v1': 'r0',
  }));

  test('M109 dashboard and widget share only the verified legacy authority',
      () async {
    final legacy = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(legacyReport),
      legacy: legacy,
    );
    final dashboard = await authority.load(
      route: WaffraFinanceRoute.dashboardRead,
    );
    final widget = await authority.load(
      route: WaffraFinanceRoute.widgetRead,
    );
    expect(dashboard.finance.getString('entries'), '[]');
    expect(widget.finance.getString('entries'), '[]');
    expect(dashboard.source, widget.source);
    expect(dashboard.widgetRevision, 'r0');
    expect(widget.widgetRevision, 'r0');
    expect(legacy.readCount, 2);
  });

  test('M109 pending or corrupt source refuses both engines, not empty defaults',
      () async {
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(pending), legacy: writer,
    );
    for (final route in [
      WaffraFinanceRoute.dashboardRead,
      WaffraFinanceRoute.widgetRead,
      WaffraFinanceRoute.bulkSmsConfirmedSave,
      WaffraFinanceRoute.widgetSmsConfirmedSave,
    ]) {
      await expectLater(authority.load(route: route), throwsStateError);
    }
    expect(writer.readCount, 0);
    expect(writer.writeCount, 0);
    expect(writer.smsCount, 0);
  });

  test('M109 newly activated SQL vault cannot fall back to old preferences',
      () async {
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(sql), legacy: writer,
    );
    for (final route in [
      WaffraFinanceRoute.dashboardRead,
      WaffraFinanceRoute.widgetRead,
    ]) {
      await expectLater(authority.load(route: route), throwsStateError);
    }
    expect(writer.readCount, 0);
    expect(writer.writeCount, 0);
  });

  test('M109 untrusted UI flags cannot manufacture an encrypted source', () async {
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(sql),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
      audit: WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values.toSet(),
        keyRecoveryVerified: true, twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true, backupRestoreVerified: true,
        crossEngineLockVerified: true, legacyParityVerified: true,
      ),
    );
    await expectLater(authority.load(
      route: WaffraFinanceRoute.dashboardRead,
    ), throwsStateError);
  });

  test('M109 source change invalidates already captured dashboard state',
      () async {
    final probe = _Probe(legacyReport);
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: probe, legacy: writer,
    );
    final loaded = await authority.load(
      route: WaffraFinanceRoute.dashboardRead,
    );
    probe.current = pending;
    await expectLater(authority.saveCaptured(
      route: WaffraFinanceRoute.transactionEdit,
      baseline: loaded,
      captured: <String, Object>{'entries': '[]'},
    ), throwsStateError);
    expect(writer.writeCount, 0);
  });

  test('M109 verified unchanged legacy baseline persists and reloads', () async {
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(legacyReport), legacy: writer,
    );
    final initial = await authority.load(
      route: WaffraFinanceRoute.dashboardRead,
    );
    final next = await authority.saveCaptured(
      route: WaffraFinanceRoute.transactionEdit,
      baseline: initial,
      captured: <String, Object>{'entries': '[]'},
    );
    expect(writer.writeCount, 1);
    expect(next.ledgerRaw, '[]');
    expect(writer.readCount, 2);
  });

  test('M109 denial before approval cannot reach either SMS writer', () async {
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(legacyReport), legacy: writer,
    );
    await expectLater(authority.commitConfirmedSms(
      route: WaffraFinanceRoute.widgetSmsConfirmedSave,
      records: [<String, Object?>{'id': 'new'}],
      hashes: [List<String>.filled(64, 'a').join()],
      userConfirmed: false,
    ), throwsStateError);
    await expectLater(authority.commitConfirmedSms(
      route: WaffraFinanceRoute.manualTransactionSave,
      records: [<String, Object?>{'id': 'new'}],
      hashes: [List<String>.filled(64, 'a').join()],
      userConfirmed: true,
    ), throwsArgumentError);
    expect(writer.smsCount, 0);
  });

  test('M109 confirmed widget and app bank SMS share the legacy commit boundary',
      () async {
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _Probe(legacyReport), legacy: writer,
    );
    final one = <String, Object?>{
      'id': 'demo',
      'title': 'synthetic-only',
      'amount': 1.25,
      'income': false,
      'category': 'Test',
      'date': '2026-10-22T12:00:00.000',
      'sourceType': 'sms',
      'notes': 'Synthetic raw message: never store in legacy preferences.',
    };
    for (final route in [
      WaffraFinanceRoute.bulkSmsConfirmedSave,
      WaffraFinanceRoute.widgetSmsConfirmedSave,
    ]) {
      final result = await authority.commitConfirmedSms(
        route: route, records: [one], hashes: [List<String>.filled(64, 'f').join()],
        userConfirmed: true,
      );
      expect(result.saved, 1);
      expect(result.expenses, 1);
      expect(result.current.ledgerRaw, '[]');
      expect(result.originalSmsNotesOmittedOnLegacy, isTrue);
    }
    expect(writer.smsCount, 2);
  });
  test('M110 freezes queued Home snapshot before async source validation',
      () async {
    final probe = _PausedSourceInspection();
    final writer = _Legacy();
    final authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: probe, legacy: writer,
    );
    final before = await authority.load(
      route: WaffraFinanceRoute.dashboardRead,
    );
    final captured = <String, Object>{
      'entries': '[]',
      'waffra_goals_v24': '[]',
    };
    probe.pauseNext = true;
    final saving = authority.saveCaptured(
      route: WaffraFinanceRoute.transactionEdit,
      baseline: before, captured: captured,
    );
    await probe.reached.future;
    // Simulate a UI update racing the OS-backed source inspection.
    captured['entries'] = 'CORRUPT_AFTER_CAPTURE';
    captured['waffra_goals_v24'] = 'CORRUPT_AFTER_CAPTURE';
    probe.resume.complete();
    final saved = await saving;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    expect(saved.ledgerRaw, '[]');
    expect(prefs.getString('entries'), '[]');
    expect(prefs.getString('waffra_goals_v24'), '[]');
    expect(writer.writeCount, 1);
  });


}

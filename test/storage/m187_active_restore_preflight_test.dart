import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_active_restore_preflight.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _SyntheticActiveFinanceSource extends WaffraProductionFinanceSourceGuard {
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'synthetic_m187_disposable_source_not_real_device',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pass = 'm187-test-only-portable-backup-passphrase';
  const currentId = 'm187-active-personal-expense';
  const restoredId = 'm187-backup-expense';

  late Directory activeDirectory;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraVerifiedFinanceAuthority authority;

  Map<String, Object?> activeRecord() => <String, Object?>{
    'id': currentId,
    'title': 'Existing source must survive',
    'category': 'Transport',
    'amount': 14.25,
    'income': false,
    'date': '2026-10-24T11:00:00',
    'receiptPath': null,
  };

  Map<String, Object?> incomingRecord({bool invoice = true}) =>
      <String, Object?>{
        'id': restoredId,
        'title': 'Portable invoice',
        'category': 'Utilities',
        'amount': 87.60,
        'income': false,
        'date': '2026-10-23T13:00:00',
        'receiptPath': invoice ? '/old-device/invoice.jpeg' : null,
      };

  Future<String> archive({bool invoice = true}) =>
      WaffraPortableBackupV2.create(
        financialSnapshot: <String, Object?>{
          'entries': jsonEncode([incomingRecord(invoice: invoice)]),
          'waffra_goals_v24': '[]',
          'waffra_categories_v24': '[]',
          'waffra_recurring_v24': '[]',
          'waffra_deleted_goals_v1': '[]',
          'waffra_sms_hashes_v1': <String>[
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
        },
        receipts: invoice
            ? <WaffraReceiptBackupPart>[
                const WaffraReceiptBackupPart(
                  entryId: restoredId, position: 0,
                  bytes: <int>[255, 216, 22, 43, 99, 10],
                ),
              ]
            : const <WaffraReceiptBackupPart>[],
        password: pass,
      );

  Future<WaffraFinanceAuthorityRead> load() =>
      authority.load(route: WaffraFinanceRoute.backupRestore);

  Future<WaffraVerifiedRestorePreflightResult> inspect(
    WaffraFinanceAuthorityRead screen,
    String encrypted, {
    bool confirmed = true,
    String password = pass,
    bool enabled = true,
  }) => WaffraVerifiedActiveRestorePreflight(
    authority: authority,
    experimentalEnabled: enabled,
  ).inspect(
    selectedSource: screen,
    encryptedArchive: encrypted,
    password: password,
    userConfirmed: confirmed,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    activeDirectory =
        await Directory.systemTemp.createTemp('m187-live-source-fixture-');
    store = WaffraEncryptedStore.openAt(
      File('${activeDirectory.path}/already-active.sqlite'),
      key: 'm187-disposable-active-encrypted-vault-key-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    final initial = await snapshot.commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: const <String, Object?>{'entries': '[]'},
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: store, snapshot: snapshot, experimentalEnabled: true,
    );
    final source = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    await journal.prepare(
      sourceDigest: source.sourceSha256,
      targetDigest: initial.digest,
      now: DateTime.utc(2026, 10, 24),
    );
    await journal.verify(now: DateTime.utc(2026, 10, 24));
    await journal.acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 10, 24),
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: _SyntheticActiveFinanceSource(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
      encryptedSession: WaffraEncryptedFinanceSession(
        experimentalEnabled: true,
        bridge: WaffraVerifiedEncryptedFinanceBridge(
          snapshot: snapshot,
          cutoverJournal: journal,
          writerDirectory: activeDirectory,
          experimentalEnabled: true,
          allWritersRoutedVerified: true,
          secureKeyVerified: true,
        ),
      ),
      audit: WaffraFinanceRouteAudit(
        verifiedRoutes: WaffraFinanceRoute.values.toSet(),
        keyRecoveryVerified: true,
        twoWitnessRecoveryVerified: true,
        receiptRollbackVerified: true,
        backupRestoreVerified: true,
        crossEngineLockVerified: true,
        legacyParityVerified: true,
      ),
    );
    await store.transaction(() async {
      final record = activeRecord();
      await store.customStatement(
        'INSERT INTO fresh_finance_entries ('
        'entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json'
        ') VALUES(?,?,?,?,?,?,?,?)',
        [currentId, record['title'], record['category'], 1425, 0,
         record['date'], 0, jsonEncode(record)],
      );
      final previous = await snapshot.read();
      await snapshot.commit(
        expectedGeneration: previous.generation,
        fullFinanceSnapshot: <String, Object?>{
          ...previous.values,
          'entries': jsonEncode([record]),
        },
      );
    });
  });

  tearDown(() async {
    await store.close();
    if (await activeDirectory.exists()) {
      await activeDirectory.delete(recursive: true);
    }
  });

  test('M187 accepted portable receipt cold-stages without replacing active ledger',
      () async {
    final before = await load();
    final original = await snapshot.read();
    final envelope = await archive();
    final result = await inspect(before, envelope);
    expect(result.transactionCount, 1);
    expect(result.receiptCount, 1);
    expect(result.receiptBytes, 6);
    expect(result.sourceGeneration, original.generation);
    expect(result.sourceDigest, original.digest);
    expect(result.activationAuthorized, isFalse);
    expect(result.activeSourceReplaced, isFalse);
    expect(result.requiresIndependentDeviceRecovery, isTrue);
    final after = await snapshot.read();
    expect(after.generation, original.generation);
    expect(after.digest, original.digest);
    expect(after.values['entries'], original.values['entries']);
    final rowCount = await store.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(rowCount.read<int>('n'), 1);
  });

  test('M187 zero-receipt authenticated restore preview is read-only', () async {
    final selected = await load();
    final report = await inspect(selected, await archive(invoice: false));
    expect(report.transactionCount, 1);
    expect(report.receiptCount, 0);
    expect(jsonDecode((await snapshot.read()).values['entries'] as String),
        hasLength(1));
  });

  test('M187 bad password never touches existing encrypted user funds',
      () async {
    final selected = await load();
    final old = await snapshot.read();
    await expectLater(inspect(
      selected, await archive(), password: 'incorrect-passphrase-for-test',
    ), throwsA(anything));
    expect((await snapshot.read()).digest, old.digest);
  });

  test('M187 tampered encrypted envelope cannot overwrite active source',
      () async {
    final selected = await load();
    final old = await snapshot.read();
    final corrupted = (await archive()).replaceFirst(
      'waffra-secure-backup', 'unrecognized-secure-format',
    );
    await expectLater(inspect(selected, corrupted), throwsA(anything));
    expect((await snapshot.read()).digest, old.digest);
  });

  test('M187 stale Widget write invalidates preflight screen witness',
      () async {
    final selected = await load();
    final old = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: old.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...old.values,
        'waffra_monthly_budget_v1': 550.0,
      },
    );
    final actual = await snapshot.read();
    await expectLater(
      inspect(selected, await archive()), throwsStateError,
    );
    expect((await snapshot.read()).digest, actual.digest);
  });

  test('M187 source cutover in progress forbids preview', () async {
    final screen = await load();
    final state = await snapshot.read();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(inspect(screen, await archive()), throwsStateError);
    expect((await snapshot.read()).digest, state.digest);
  });

  test('M187 disabled and unconfirmed routes never open staging database',
      () async {
    final screen = await load();
    final envelope = await archive();
    final original = await snapshot.read();
    await expectLater(inspect(screen, envelope, enabled: false),
        throwsStateError);
    await expectLater(inspect(screen, envelope, confirmed: false),
        throwsStateError);
    final legacy = WaffraVerifiedFinanceAuthority();
    await expectLater(WaffraVerifiedActiveRestorePreflight(
      authority: legacy, experimentalEnabled: true,
    ).inspect(
      selectedSource: screen,
      encryptedArchive: envelope,
      password: pass,
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
  });
}

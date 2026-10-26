import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_finance_session.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';
import 'package:waffra/storage/waffra_verified_finance_authority.dart';

class _SyntheticEncryptedSource extends WaffraProductionFinanceSourceGuard {
  const _SyntheticEncryptedSource();
  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => const WaffraProductionFinanceSourceReport(
    source: WaffraProductionFinanceSource.encryptedRoutingRequired,
    reasonCode: 'm235_disposable_only_not_production_evidence',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const password = 'M235 synthetic owner archive password 2026';
  const sms = 'حوالة واردة\\n225 SAR\\nمرجع تجريبي';
  late Directory directory;
  late WaffraEncryptedStore store;
  late WaffraVerifiedFinanceAuthority authority;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    directory = await Directory.systemTemp.createTemp('waffra-m235-');
    store = WaffraEncryptedStore.openAt(
      File('${directory.path}/already-activated-synthetic.sqlite'),
      key: 'm235-disposable-sqlcipher-key-only',
    );
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: {
        'entries': jsonEncode([{
          'id': 'synthetic-sms',
          'title': 'Safe transfer',
          'category': 'Income',
          'amount': 225.0,
          'income': true,
          'date': '2026-10-26T00:00:00Z',
          'sourceType': 'sms',
          'notes': sms,
          'receiptPath': '/old-device/synthetic-invoice.png',
        }]),
        'waffra_categories_v24': '[]',
        'waffra_goals_v24': '[]',
      },
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: 'synthetic-sms', position: 0, bytes: [137, 80, 78, 71, 13],
        ),
      ],
      password: password,
    );
    await WaffraPortableEncryptedVaultRestorer(
      disposableStore: store, experimentalEnabled: true,
    ).restore(encryptedArchive: encrypted, password: password);

    final snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    final journal = WaffraEncryptedCutoverJournal(
      store: store, snapshot: snapshot, experimentalEnabled: true,
    );
    final source = WaffraLegacyPreflight.inspect(
      const <String, Object?>{'entries': '[]'},
    );
    final current = await snapshot.read();
    await journal.prepare(
      sourceDigest: source.sourceSha256,
      targetDigest: current.digest,
      now: DateTime.utc(2026, 10, 26),
    );
    await journal.verify(now: DateTime.utc(2026, 10, 26));
    await journal.acknowledgeExternalActivation(
      externalMarkerVerified: true,
      allWritersRouted: true,
      now: DateTime.utc(2026, 10, 26),
    );
    authority = WaffraVerifiedFinanceAuthority(
      sourceGuard: const _SyntheticEncryptedSource(),
      encryptedSqlWitnessActive: true,
      externalSourceWitnessActive: true,
      verifiedKeyRecoveryInDevice: true,
      encryptedSession: WaffraEncryptedFinanceSession(
        experimentalEnabled: true,
        bridge: WaffraVerifiedEncryptedFinanceBridge(
          snapshot: snapshot,
          cutoverJournal: journal,
          writerDirectory: directory,
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
  });

  tearDown(() async {
    await store.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('M235 verified authority exports encrypted SMS+image bytes with native source lock',
      () async {
    final before = await authority.load(route: WaffraFinanceRoute.backupExport);
    final ciphertext = await authority.exportVerifiedEncryptedBackup(
      route: WaffraFinanceRoute.backupExport,
      password: password,
    );
    expect(ciphertext, isNot(contains(sms)));
    expect(ciphertext, isNot(contains('Safe transfer')));
    final checked = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: ciphertext, password: password,
    );
    expect(checked.receiptCount, 1);
    expect(checked.receipts.single.bytes, [137, 80, 78, 71, 13]);
    final entries = jsonDecode(
      checked.financialSnapshot['entries'] as String,
    ) as List;
    expect(entries.single['notes'], sms);
    expect(entries.single['receiptPath'], contains('waffra-receipt://'));
    final after = await authority.load(route: WaffraFinanceRoute.backupExport);
    expect(after.encryptedWitness!.digest, before.encryptedWitness!.digest);
  });

  test('M235 wrong route and incomplete password never export', () async {
    await expectLater(authority.exportVerifiedEncryptedBackup(
      route: WaffraFinanceRoute.backupRestore, password: password,
    ), throwsArgumentError);
    await expectLater(authority.exportVerifiedEncryptedBackup(
      route: WaffraFinanceRoute.backupExport, password: 'short',
    ), throwsArgumentError);
  });

  test('M235 receipt corruption refuses complete encrypted finance backup', () async {
    await store.customStatement(
      'UPDATE fresh_finance_receipt_blobs SET content_sha256=? '
      'WHERE entry_id=? AND position=?',
      [List.filled(64, '0').join(), 'synthetic-sms', 0],
    );
    await expectLater(authority.exportVerifiedEncryptedBackup(
      route: WaffraFinanceRoute.backupExport, password: password,
    ), throwsStateError);
  });

  test('M235 receiptView only reads encrypted invoice from same activated source',
      () async {
    final pixels = await authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.receiptView, entryId: 'synthetic-sms',
    );
    expect(pixels.length, 1);
    expect(pixels.single.toList(), [137, 80, 78, 71, 13]);
    await expectLater(authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.backupExport, entryId: 'synthetic-sms',
    ), throwsArgumentError);
    await expectLater(authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.receiptView, entryId: 'not-a-finance-entry',
    ), throwsA(anything));
  });

  test('M235 Home receipt viewer routes encrypted bytes and immutable ledger ID',
      () async {
    final code = File('lib/main.dart').readAsStringSync();
    expect(code, contains(
      'route:WaffraFinanceRoute.receiptView,entryId:entryId'));
    expect(code, contains(
      'Image.memory(securedImages[index],fit:BoxFit.contain)'));
    expect(code, contains(
      "linked.single['receiptPath']!=encoded"));
    expect(code, contains(
      'showReceipt(e.receiptPath!,entryId:e.id)'));
  });

  test('M235 new manual transaction and receipts commit together on encrypted authority',
      () async {
    final confirmed = await authority.commitWithReceiptBytes(
      route: WaffraFinanceRoute.receiptCopyAndAttach,
      record: <String, Object?>{
        'id': 'manual-new-with-invoice',
        'title': 'Manual office purchase',
        'category': 'Office',
        'amount': 24.75,
        'income': false,
        'date': '2026-10-26T10:00:00.000Z',
        'notes': 'Keep full typed notes on the encrypted ledger',
        'sourceType': 'manual',
        'merchantKey': '',
        'receiptPath': null,
      },
      images: [Uint8List.fromList([137, 80, 78, 71, 11, 22])],
      userConfirmed: true,
    );
    expect(confirmed.entryId, 'manual-new-with-invoice');
    expect(confirmed.receiptCount, 1);
    final saved = await authority.load(
      route: WaffraFinanceRoute.dashboardRead);
    final rows = jsonDecode(saved.ledgerRaw!) as List;
    final record = rows.cast<Map>().singleWhere(
      (entry) => entry['id'] == 'manual-new-with-invoice');
    expect(record['notes'], 'Keep full typed notes on the encrypted ledger');
    expect(record['sourceType'], 'manual');
    expect(record['receiptPath'], startsWith('waffra-receipt://'));
    final exact = await authority.loadEncryptedReceiptImages(
      route: WaffraFinanceRoute.receiptView,
      entryId: 'manual-new-with-invoice',
    );
    expect(exact.single.toList(), [137, 80, 78, 71, 11, 22]);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), '[]');
    expect(prefs.containsKey('waffra_categories_v24'), isFalse);
  });

  test('M235 cancelled atomic invoice append never writes transaction or image',
      () async {
    await expectLater(authority.commitWithReceiptBytes(
      route: WaffraFinanceRoute.receiptCopyAndAttach,
      record: <String, Object?>{
        'id': 'cancelled-invoice',
        'title': 'Never saved',
        'category': 'Office',
        'amount': 12.5,
        'income': false,
        'date': '2026-10-26T10:00:00.000Z',
        'receiptPath': null,
      },
      images: [Uint8List.fromList([1, 2, 3])],
      userConfirmed: false,
    ), throwsStateError);
    final state = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    expect(state.ledgerRaw, isNot(contains('cancelled-invoice')));
  });

  test('M235 selected manual receipt picker remains in-memory on SQLCipher',
      () async {
    final code = File('lib/main.dart').readAsStringSync();
    expect(code, contains('final pendingEncryptedImages=<Uint8List>[];'));
    expect(code, contains(
      'await _financeAuthority.commitWithReceiptBytes('));
    expect(code, contains('final staged=<Uint8List>[];'));
    expect(code, contains('Uint8List.fromList(await file.readAsBytes())'));
    expect(code, contains('WaffraFinanceRoute.receiptCopyAndAttach'));
  });

  test('M235 image-picker never copies plaintext files after encrypted source selection',
      () async {
    final code = File('lib/main.dart').readAsStringSync();
    final start = code.indexOf(' Future<String> saveReceipt(XFile picked)async {');
    final guard = code.indexOf(
      'route:WaffraFinanceRoute.receiptCopyAndAttach', start);
    final copy = code.indexOf('await File(picked.path).copy(target);', start);
    expect(start, greaterThan(0));
    expect(guard, greaterThan(start));
    expect(copy, greaterThan(guard));
    expect(code, contains(
      'Encrypted receipt attachment requires an atomic SQLCipher writer.'));
  });

  test('M235 missing external activation source blocks backup without legacy fallback',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(authority.exportVerifiedEncryptedBackup(
      route: WaffraFinanceRoute.backupExport, password: password,
    ), throwsStateError);
  });
}

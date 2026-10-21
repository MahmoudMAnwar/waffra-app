import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_finance_migration_rehearsal.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_receipt_blob_stager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Directory receipts;
  late WaffraEncryptedStore vault;

  const key = 'isolated-legacy-receipt-blob-test-key';
  WaffraLegacyFinanceWriterCoordinator coordinator() =>
      WaffraLegacyFinanceWriterCoordinator(testDirectory: temp);

  WaffraAtomicFinanceSnapshot snapshot() =>
      WaffraAtomicFinanceSnapshot(store: vault, experimentalEnabled: true);

  WaffraLegacyReceiptBlobStager stager({bool enabled = true}) =>
      WaffraLegacyReceiptBlobStager(
        store: vault, coordinator: coordinator(),
        trustedRoots: [receipts], experimentalEnabled: enabled,
      );

  String transactions({required String receiptPath}) => jsonEncode([
    {
      'id': 'expense-1', 'title': 'شراء تجربة', 'category': 'مأكولات',
      'amount': 100.25, 'income': false,
      'date': '2026-10-21T14:00:00',
      'receiptPath': receiptPath,
    },
    {
      'id': 'income-1', 'title': 'Salary', 'category': 'Income',
      'amount': 5000, 'income': true,
      'date': '2026-10-20T13:00:00', 'receiptPath': null,
    },
  ]);

  Future<void> init({required String oldEntries}) async {
    SharedPreferences.setMockInitialValues({
      'entries': oldEntries,
      'waffra_goals_v24': '[]',
      'waffra_sms_hashes_v1': <String>['existing-hash'],
    });
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await WaffraFinanceMigrationRehearsal(
      encrypted: snapshot(), coordinator: coordinator(),
      experimentalEnabled: true,
    ).run();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('waffra-stage-receipts-');
    receipts = await Directory('${temp.path}/receipts').create();
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/staging.sqlite'), key: key,
    );
  });

  tearDown(() async {
    await vault.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('two legacy transactions and image staged with exact encrypted bytes',
      () async {
    final photo = File('${receipts.path}/real-old-photo.jpg');
    await photo.writeAsBytes([10, 20, 30, 40], flush: true);
    final old = transactions(receiptPath: photo.path);
    await init(oldEntries: old);
    final report = await stager().stage();
    expect(report.ledgerRecords, 2);
    expect(report.receiptBlobs, 1);
    expect(report.receiptBytes, 4);

    final restored = await WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    ).readAll('expense-1');
    expect(restored, hasLength(1));
    expect(restored.single.bytes, [10, 20, 30, 40]);

    final row = await vault.customSelect(
      "SELECT amount_minor,source_json FROM fresh_finance_entries "
      "WHERE entry_id='expense-1'",
    ).getSingle();
    expect(row.read<int>('amount_minor'), 10025);
    expect(row.read<String>('source_json'), contains('شراء تجربة'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), old);
    expect(prefs.getStringList('waffra_sms_hashes_v1'),
        ['existing-hash']);
    expect(await photo.readAsBytes(), [10, 20, 30, 40]);

    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/staging.sqlite'), key: key,
    );
    expect((await WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    ).readAll('expense-1')).single.bytes, [10, 20, 30, 40]);
  });

  test('missing image rolls back whole ledger projection', () async {
    await init(oldEntries: transactions(
      receiptPath: '${receipts.path}/lost.jpg',
    ));
    await expectLater(stager().stage(), throwsA(isA<StateError>()));
    final rows = await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    expect(rows.read<int>('n'), 0);
    expect((await snapshot().read()).generation, 1);
  });

  test('no existing receipt results in transaction-only projection',
      () async {
    await init(oldEntries: transactions(receiptPath: ''));
    final result = await stager().stage();
    expect(result.ledgerRecords, 2);
    expect(result.receiptBlobs, 0);
    expect(result.receiptBytes, 0);
  });

  test('second staging cannot overwrite verified encrypted records',
      () async {
    final receipt = File('${receipts.path}/photo.png');
    await receipt.writeAsBytes([1, 2]);
    await init(oldEntries: transactions(receiptPath: receipt.path));
    await stager().stage();
    await expectLater(stager().stage(), throwsA(isA<StateError>()));
    expect((await WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    ).readAll('expense-1')).single.bytes, [1, 2]);
  });

  test('untrusted file is rejected and old source stays intact', () async {
    final outside = File('${temp.path}/other.jpg');
    await outside.writeAsBytes([3, 4, 5]);
    final old = transactions(receiptPath: outside.path);
    await init(oldEntries: old);
    await expectLater(stager().stage(), throwsA(isA<StateError>()));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), old);
    expect((await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle()).read<int>('n'), 0);
  });

  test('incorrect encrypted snapshot blocks finance/receipt projection',
      () async {
    SharedPreferences.setMockInitialValues({
      'entries': transactions(receiptPath: ''),
    });
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
    await expectLater(stager().stage(), throwsA(isA<StateError>()));
  });

  test('default-off staging cannot mutate encrypted data', () async {
    await init(oldEntries: transactions(receiptPath: ''));
    await expectLater(stager(enabled: false).stage(),
        throwsA(isA<StateError>()));
    expect((await vault.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle()).read<int>('n'), 0);
  });
}

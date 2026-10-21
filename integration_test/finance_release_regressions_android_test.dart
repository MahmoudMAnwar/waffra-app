import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_finance_source_cutover_policy.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const key = 'test-only-android-regression-secret-32';

  testWidgets('100 confirmed SMS + 20 overlapping app/widget writes survive a cold restart',
      (tester) async {
    expect(Platform.isAndroid, true);
    final temp = await (await getTemporaryDirectory())
        .createTemp('waffra-100-transaction-regression-');
    final file = File('${temp.path}/stress.sqlite');
    WaffraEncryptedStore? vault;
    try {
      vault = WaffraEncryptedStore.openAt(file, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      );
      await snapshot.initializeEmpty();
      WaffraUnifiedFinanceWriter writer() => WaffraUnifiedFinanceWriter(
        writerDirectory: temp,
        snapshot: snapshot,
        experimentalEnabled: true,
      );
      Map<String, Object?> transaction(int n, {bool income = false}) => {
        'id': 'test-$n',
        'title': 'Synthetic finance $n',
        'category': income ? 'Salary' : 'Groceries',
        'amount': n + 0.25,
        'income': income,
        'date': '2026-10-21T12:00:00',
        'receiptPath': null,
      };
      String hash(int n) => n.toRadixString(16).padLeft(64, '0');
      final first = await writer().appendTransactions(
        records: List.generate(100, (i) => transaction(i + 1, income: i.isEven)),
        messageHashes: List.generate(100, (i) => hash(i + 1)),
        userConfirmed: true,
      );
      expect(first.saved, 100);
      expect(first.savedIncome, 50);
      expect(first.savedExpenses, 50);
      expect(first.generation, 1);
      final replay = await writer().appendTransactions(
        records: List.generate(100, (i) => transaction(i + 101)),
        messageHashes: List.generate(100, (i) => hash(i + 1)),
        userConfirmed: true,
      );
      expect(replay.saved, 0);
      expect(replay.skippedDuplicates, 100);
      expect(replay.generation, 1);

      final overlapping = await Future.wait(
        List.generate(20, (i) => writer().appendTransactions(
          records: [transaction(i + 201)],
          messageHashes: [i.isEven ? hash(i + 201) : null],
          userConfirmed: true,
        )),
      );
      expect(overlapping.every((r) => r.saved == 1), true);
      final after = await snapshot.read();
      expect(after.generation, 21);
      final records = jsonDecode(after.values['entries'] as String) as List;
      expect(records.length, 120);
      final ids = records.map((row) => (row as Map)['id']).toSet();
      expect(ids.length, 120);
      final hashes = after.values['waffra_sms_hashes_v1'] as List<String>;
      expect(hashes.length, 110);

      await vault.close();
      vault = null;
      final signature = await file.openRead(0, 16).toList();
      expect(signature.expand((part) => part).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102, 111, 114, 109, 97, 116, 32, 51, 0]));
      vault = WaffraEncryptedStore.openAt(file, key: key);
      final restored = await WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      ).read();
      expect(restored.generation, 21);
      expect((jsonDecode(restored.values['entries'] as String) as List).length, 120);
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  testWidgets('corrupt snapshot and interrupted source activation fail closed',
      (tester) async {
    final temp = await (await getTemporaryDirectory())
        .createTemp('waffra-corruption-regression-');
    final file = File('${temp.path}/finance.sqlite');
    WaffraEncryptedStore? vault;
    try {
      const policy = WaffraFinanceSourceCutoverPolicy();
      expect(policy.resolve(const WaffraFinanceSourceEvidence(
        preferences: {'entries': '[]'},
        encryptedFileExists: false,
        encryptedKeyReadable: false,
        encryptedSqlActivationVerified: false,
        cooperatingWritersFrozen: true,
      )), WaffraFinanceSourceStatus.legacyPreferences);
      expect(policy.resolve(const WaffraFinanceSourceEvidence(
        preferences: {'waffra_encrypted_finance_active_v1': true},
        encryptedFileExists: false,
        encryptedKeyReadable: false,
        encryptedSqlActivationVerified: false,
      )), WaffraFinanceSourceStatus.recoveryRequired);

      vault = WaffraEncryptedStore.openAt(file, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      );
      await snapshot.initializeEmpty();
      await snapshot.commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: const {
          'waffra_goals_v24': '[{"id":"goal","name":"Trip","target":500,"saved":100}]',
          'entries': '[]',
        },
      );
      await vault.customStatement(
        "UPDATE fresh_finance_snapshot_state SET snapshot_json='{}' WHERE singleton=1",
      );
      await expectLater(snapshot.read(), throwsA(isA<StateError>()));
      await expectLater(
        snapshot.commit(expectedGeneration: 1, fullFinanceSnapshot: const {'entries': '[]'}),
        throwsA(isA<StateError>()),
      );
      final still = await vault.customSelect(
        'SELECT generation,snapshot_json FROM fresh_finance_snapshot_state',
      ).getSingle();
      expect(still.read<int>('generation'), 1);
      expect(still.read<String>('snapshot_json'), '{}');
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  testWidgets('encrypted receipt rollback and incorrect SQLCipher key do not lose images',
      (tester) async {
    final temp = await (await getTemporaryDirectory())
        .createTemp('waffra-receipt-regression-');
    final file = File('${temp.path}/receipts.sqlite');
    WaffraEncryptedStore? vault;
    try {
      vault = WaffraEncryptedStore.openAt(file, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      await WaffraFreshLedgerRepository(
        store: vault, experimentalEnabled: true,
      ).add(const WaffraFreshLedgerEntry(
        id: 'receipt-owner',
        title: 'Receipt regression',
        categorySnapshot: 'Groceries',
        amountMinor: 350,
        isIncome: false,
        occurredIso: '2026-10-21T13:00:00',
      ));
      final receipts = WaffraEncryptedReceiptVault(
        store: vault, experimentalEnabled: true,
      );
      await receipts.attachNewBatch(entryId: 'receipt-owner', images: [
        Uint8List.fromList([1, 2, 3, 4]),
        Uint8List.fromList([5, 6, 7, 8]),
      ]);
      await expectLater(receipts.attachNewBatch(
        entryId: 'receipt-owner',
        images: [Uint8List.fromList([9, 9, 9])],
      ), throwsA(isA<StateError>()));
      expect((await receipts.readAll('receipt-owner')).map((r) => r.bytes.join(',')).toSet(),
          {'1,2,3,4', '5,6,7,8'});
      await vault.close();
      vault = null;

      final incorrect = WaffraEncryptedStore.openAt(
        file, key: 'incorrect-SQLCipher-test-key-32',
      );
      try {
        await expectLater(
          incorrect.stagedRowCount('receipt-owner'),
          throwsA(isA<Exception>()),
        );
      } finally {
        await incorrect.close();
      }

      vault = WaffraEncryptedStore.openAt(file, key: key);
      final saved = await WaffraEncryptedReceiptVault(
        store: vault, experimentalEnabled: true,
      ).readAll('receipt-owner');
      expect(saved.map((r) => r.bytes.join(',')).toSet(),
          {'1,2,3,4', '5,6,7,8'});
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M80 synthetic-only concurrent-writer and failed-source QA. Can execute
/// while Android emulator and remote Firebase acceptance run separately.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late WaffraEncryptedStore store;
  const localKey = 'm80-only-disposable-receipt-writer-key';
  const sourceDirectorySuffix = 'receipts';

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store: store, experimentalEnabled: true,
  );
  WaffraEncryptedReceiptVault receiptVault() => WaffraEncryptedReceiptVault(
    store: store, experimentalEnabled: true,
  );
  WaffraAtomicEncryptedReceiptTransactionWriter writer({
    Future<void> Function()? verify,
  }) => WaffraAtomicEncryptedReceiptTransactionWriter(
    snapshot: snapshot(),
    receiptVault: receiptVault(),
    writerDirectory: Directory('${temp.path}/$sourceDirectorySuffix'),
    verifySourceUnderLock: verify ?? () async {},
    experimentalEnabled: true,
  );

  Map<String, Object?> record(String id) => {
    'id': id,
    'title': 'Synthetic invoice',
    'category': 'أخرى',
    'amount': 24.75,
    'income': false,
    'date': '2026-10-22T12:00:00',
    'receiptPath': null,
  };

  Future<int> rowCount(String table) async =>
      (await store.customSelect('SELECT count(*) AS n FROM $table')
          .getSingle()).read<int>('n');

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('waffra-m80-atomic-');
    await Directory('${temp.path}/$sourceDirectorySuffix').create();
    store = WaffraEncryptedStore.openAt(
      File('${temp.path}/ledger.sqlite'), key: localKey,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });

  tearDown(() async {
    await store.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M80 source witness failure writes no entry, invoice, hash or revision',
      () async {
    final original = await snapshot().read();
    await expectLater(
      writer(verify: () async {
        throw StateError('Synthetic stale finance source');
      }).save(
        record: record('witness-rejected'),
        receiptImages: [Uint8List.fromList([1, 2, 3])],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    final now = await snapshot().read();
    expect(now.generation, original.generation);
    expect(now.digest, original.digest);
    expect(await rowCount('fresh_finance_entries'), 0);
    expect(await rowCount('fresh_finance_receipt_blobs'), 0);
    expect(await rowCount('fresh_finance_sms_hashes'), 0);
  });

  test('M80 failed source witness can retry without a ghost receipt or hash',
      () async {
    var firstAttempt = true;
    final guarded = writer(verify: () async {
      if (firstAttempt) {
        firstAttempt = false;
        throw StateError('Synthetic interruption during source validation');
      }
    });
    final receipt = Uint8List.fromList([9, 8, 7, 6]);
    await expectLater(
      guarded.save(
        record: record('retry-once'),
        receiptImages: [receipt],
        userConfirmed: true,
      ),
      throwsA(isA<StateError>()),
    );
    final result = await guarded.save(
      record: record('retry-once'),
      receiptImages: [receipt],
      userConfirmed: true,
    );
    expect(result.generation, 1);
    expect(result.receiptCount, 1);
    expect(await rowCount('fresh_finance_entries'), 1);
    expect(await rowCount('fresh_finance_receipt_blobs'), 1);
    expect((await receiptVault().readAll('retry-once')).single.bytes,
        [9, 8, 7, 6]);
    final entries = jsonDecode((await snapshot().read()).values['entries']
        as String) as List;
    expect(entries, hasLength(1));
    expect(entries.single['id'], 'retry-once');
  });

  test('M80 two concurrent confirms for one ID never persist two invoices',
      () async {
    Future<bool> save(List<int> image) async {
      try {
        await writer().save(
          record: record('same-confirmed-id'),
          receiptImages: [Uint8List.fromList(image)],
          userConfirmed: true,
        );
        return true;
      } on StateError {
        return false;
      }
    }
    final results = await Future.wait([
      save([1, 1, 1]),
      save([2, 2, 2]),
    ]);
    expect(results.where((accepted) => accepted), hasLength(1));
    expect(await rowCount('fresh_finance_entries'), 1);
    expect(await rowCount('fresh_finance_receipt_blobs'), 1);
    expect((await snapshot().read()).generation, 1);
    final images = await receiptVault().readAll('same-confirmed-id');
    expect(images, hasLength(1));
    expect(
      images.single.bytes.toList(),
      anyOf(orderedEquals([1, 1, 1]), orderedEquals([2, 2, 2])),
    );
  });
}

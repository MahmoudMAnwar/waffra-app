import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore encrypted;
  const key = 'm76-disposable-only-encrypted-sqlcipher-key';
  String hash(int n) => n.toRadixString(16).padLeft(64, '0');

  Map<String, Object?> entry(String id, {num amount = 84.72}) => {
    'id': id, 'title': 'Family supplies',
    'category': 'مطاعم وكافيهات', 'amount': amount,
    'income': false, 'date': '2026-10-22T11:00:00',
    'receiptPath': null,
  };

  WaffraAtomicFinanceSnapshot currentSnapshot() =>
      WaffraAtomicFinanceSnapshot(store: encrypted, experimentalEnabled: true);
  WaffraEncryptedReceiptVault receiptVault() =>
      WaffraEncryptedReceiptVault(store: encrypted, experimentalEnabled: true);

  WaffraAtomicEncryptedReceiptTransactionWriter writer({
    bool enabled = true,
    bool verifiedSource = true,
  }) => WaffraAtomicEncryptedReceiptTransactionWriter(
    snapshot: currentSnapshot(),
    receiptVault: receiptVault(),
    writerDirectory: root,
    experimentalEnabled: enabled,
    verifySourceUnderLock: verifiedSource ? () async {} : null,
  );

  Future<void> initialize() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: encrypted, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await currentSnapshot().initializeEmpty();
  }

  Future<int> normalizedCount() async =>
      (await encrypted.customSelect(
        'SELECT count(*) AS n FROM fresh_finance_entries',
      ).getSingle()).read<int>('n');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m76-atomic-receipt-');
    encrypted = WaffraEncryptedStore.openAt(
      File('${root.path}/receipt-finance.sqlite'), key: key,
    );
    await initialize();
  });
  tearDown(() async {
    await encrypted.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M76 confirmed entry and two invoice images commit in a single SQLCipher generation',
      () async {
    final initial = await currentSnapshot().read();
    expect(initial.generation, 0);
    final result = await writer().save(
      record: entry('restaurant-1'),
      receiptImages: [
        Uint8List.fromList([1, 2, 3, 4]),
        Uint8List.fromList([11, 12, 13]),
      ],
      userConfirmed: true,
      smsHash: hash(19),
    );
    expect(result.receiptCount, 2);
    expect(result.receiptBytes, 7);
    expect(result.generation, 1);
    expect(await normalizedCount(), 1);
    final state = await currentSnapshot().read();
    expect(state.values['waffra_sms_hashes_v1'], [hash(19)]);
    final saved = jsonDecode(state.values['entries'] as String) as List;
    final row = saved.single as Map;
    final refs = jsonDecode(row['receiptPath'] as String) as List;
    expect(refs, [
      WaffraEncryptedReceiptReference.of('restaurant-1', 0),
      WaffraEncryptedReceiptReference.of('restaurant-1', 1),
    ]);
    final attachments = await receiptVault().readAll('restaurant-1');
    expect(attachments.map((x) => x.bytes.toList()).toList(),
        [[1, 2, 3, 4], [11, 12, 13]]);

    await encrypted.close();
    encrypted = WaffraEncryptedStore.openAt(
      File('${root.path}/receipt-finance.sqlite'), key: key,
    );
    expect((await currentSnapshot().read()).generation, 1);
    expect((await receiptVault().readAll('restaurant-1')).last.bytes, [11, 12, 13]);
  });

  test('M76 never writes without user confirmation, a verified source or explicit feature',
      () async {
    final record = entry('unsaved');
    final pictures = [Uint8List.fromList([10])];
    await expectLater(writer().save(
      record: record, receiptImages: pictures, userConfirmed: false,
    ), throwsA(isA<StateError>()));
    await expectLater(writer(enabled: false).save(
      record: record, receiptImages: pictures, userConfirmed: true,
    ), throwsA(isA<StateError>()));
    await expectLater(writer(verifiedSource: false).save(
      record: record, receiptImages: pictures, userConfirmed: true,
    ), throwsA(isA<StateError>()));
    expect(await normalizedCount(), 0);
    expect((await currentSnapshot().read()).generation, 0);
  });

  test('M76 refuses separately owned SQLCipher receipt vaults', () async {
    final other = WaffraEncryptedStore.openAt(
      File('${root.path}/other-owner.sqlite'), key: key,
    );
    try {
      final split = WaffraAtomicEncryptedReceiptTransactionWriter(
        snapshot: currentSnapshot(),
        receiptVault: WaffraEncryptedReceiptVault(
          store: other, experimentalEnabled: true,
        ),
        writerDirectory: root,
        experimentalEnabled: true,
        verifySourceUnderLock: () async {},
      );
      await expectLater(split.save(
        record: entry('split-write'),
        receiptImages: [Uint8List.fromList([99])],
        userConfirmed: true,
      ), throwsA(isA<StateError>()));
      expect(await normalizedCount(), 0);
      expect((await currentSnapshot().read()).generation, 0);
    } finally {
      await other.close();
    }
  });

  test('M76 refuses legacy plaintext file paths, raw bank data and zero amounts',
      () async {
    for (final invalid in [
      {...entry('path'), 'receiptPath': '/storage/emulated/0/invoice.jpg'},
      {...entry('raw-sms'), 'rawSms': 'bank transaction message'},
      entry('zero', amount: 0),
      entry('fraction', amount: 2.005),
    ]) {
      await expectLater(writer().save(
        record: invalid,
        receiptImages: [Uint8List.fromList([1])],
        userConfirmed: true,
      ), throwsA(isA<ArgumentError>()));
    }
    expect(await normalizedCount(), 0);
    expect((await currentSnapshot().read()).generation, 0);
  });

  test('M76 duplicate transaction ID and SMS hash never overwrite prior images',
      () async {
    await writer().save(
      record: entry('first'),
      receiptImages: [Uint8List.fromList([3, 7])],
      smsHash: hash(1), userConfirmed: true,
    );
    for (final attempt in [
      (record: entry('first'), hash: hash(2)),
      (record: entry('second'), hash: hash(1)),
    ]) {
      await expectLater(writer().save(
        record: attempt.record,
        receiptImages: [Uint8List.fromList([90])],
        smsHash: attempt.hash, userConfirmed: true,
      ), throwsA(isA<StateError>()));
    }
    expect(await normalizedCount(), 1);
    expect((await currentSnapshot().read()).generation, 1);
    expect((await receiptVault().readAll('first')).single.bytes, [3, 7]);
    expect((await currentSnapshot().read()).values['waffra_sms_hashes_v1'], [hash(1)]);
  });

  test('M76 a receipt SQL trigger failure rolls back ledger, hashes and entry row',
      () async {
    await writer().save(
      record: entry('existing'),
      receiptImages: [Uint8List.fromList([8])],
      userConfirmed: true,
    );
    final before = await currentSnapshot().read();
    await encrypted.customStatement('''
CREATE TRIGGER synthetic_m76_receipt_failure
BEFORE INSERT ON fresh_finance_receipt_blobs
BEGIN
  SELECT RAISE(ABORT, 'synthetic receipt failure');
END
''');
    await expectLater(writer().save(
      record: entry('should-rollback'),
      receiptImages: [Uint8List.fromList([7, 7])],
      smsHash: hash(7), userConfirmed: true,
    ), throwsA(anything));
    final after = await currentSnapshot().read();
    expect(after.generation, before.generation);
    expect(after.digest, before.digest);
    expect(await normalizedCount(), 1);
    expect((jsonDecode(after.values['entries'] as String) as List).length, 1);
    expect(after.values.containsKey('waffra_sms_hashes_v1'), false);
    expect((await receiptVault().readAll('existing')).single.bytes, [8]);
  });

  test('M76 protects original image buffer from asynchronous mutation',
      () async {
    final image = Uint8List.fromList([22, 23, 24]);
    await writer().save(
      record: entry('private-photo'),
      receiptImages: [image], userConfirmed: true,
    );
    image[0] = 99;
    expect((await receiptVault().readAll('private-photo')).single.bytes, [22, 23, 24]);
  });

  test('M76 refuses mixed snapshot-vs-normalized ledger source corruption',
      () async {
    await currentSnapshot().commit(
      expectedGeneration: 0,
      fullFinanceSnapshot: {
        'entries': jsonEncode([entry('out-of-band')]),
      },
    );
    await expectLater(writer().save(
      record: entry('new-entry'),
      receiptImages: [Uint8List.fromList([1])],
      userConfirmed: true,
    ), throwsA(isA<StateError>()));
    expect(await normalizedCount(), 0);
    expect((await currentSnapshot().read()).generation, 1);
  });
}

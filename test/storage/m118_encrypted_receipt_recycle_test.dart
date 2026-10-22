import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late WaffraEncryptedStore store;
  var permitSource = true;
  const key = 'm118-disposable-sqlcipher-recycle-32-characters';
  final createdAt = DateTime.utc(2026, 10, 23, 7, 0);

  WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
    store: store, experimentalEnabled: true,
  );
  WaffraEncryptedReceiptVault vault() => WaffraEncryptedReceiptVault(
    store: store, experimentalEnabled: true,
  );
  WaffraEncryptedReceiptRecycle recycle({bool enabled = true}) =>
      WaffraEncryptedReceiptRecycle(
        snapshot: snapshot(),
        receiptVault: vault(),
        writerDirectory: directory,
        verifySourceUnderLock: () async {
          if (!permitSource) throw StateError('Source witness unavailable.');
        },
        experimentalEnabled: enabled,
      );

  Map<String, Object?> entry(String id) => {
    'id': id, 'title': 'Test invoice', 'category': 'Shopping',
    'amount': 84.72, 'income': false, 'receiptPath': null,
    'date': '2026-10-22T18:00:00',
  };

  Future<void> addWithReceipts(String id, {int count = 2}) async {
    await WaffraAtomicEncryptedReceiptTransactionWriter(
      snapshot: snapshot(),
      receiptVault: vault(),
      writerDirectory: directory,
      experimentalEnabled: true,
      verifySourceUnderLock: () async {},
    ).save(
      record: entry(id),
      receiptImages: List.generate(count,
        (n) => Uint8List.fromList([n + 1, n + 10, n + 20])),
      userConfirmed: true,
      smsHash: id == 'first'
          ? List<String>.filled(64, 'a').join() : null,
    );
  }

  Map<String, dynamic> getEntry(Map<String, Object?> values, String id) =>
      Map<String, dynamic>.from((jsonDecode(values['entries'] as String)
          as List).singleWhere((row) => row['id'] == id) as Map);

  Future<List<String>> imageDigests(String id) async =>
      (await vault().readAll(id))
          .map((image) => image.sha256Hex).toList(growable: false);

  setUp(() async {
    permitSource = true;
    directory = await Directory.systemTemp.createTemp('waffra-m118-recycle-');
    store = WaffraEncryptedStore.openAt(
      File(directory.path + '/recycle.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await snapshot().initializeEmpty();
  });
  tearDown(() async {
    await store.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('M118: removal retains amount, history, hashes and encrypted archive',
      () async {
    await addWithReceipts('first');
    final before = await snapshot().read();
    final original = getEntry(before.values, 'first');
    final savedBytes = (await vault().readAll('first'))
        .map((item) => item.bytes.toList()).toList();
    final result = await recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: before.generation,
      now: createdAt, userConfirmed: true,
    );
    expect(result.generation, before.generation + 1);
    expect(result.receiptCount, 2);
    expect(result.expiresAtMs,
        createdAt.add(const Duration(days: 30)).millisecondsSinceEpoch);
    final after = await snapshot().read();
    final edited = getEntry(after.values, 'first');
    expect(edited['receiptPath'], isNull);
    for (final field in ['id', 'title', 'category', 'amount', 'income', 'date']) {
      expect(edited[field], original[field]);
    }
    expect(after.values['waffra_sms_hashes_v1'],
        before.values['waffra_sms_hashes_v1']);
    expect(await vault().readAll('first'), isEmpty);
    expect((await recycle().pendingRecoveries()).containsKey('first'), true);
    final archived = await store.customSelect(
      'SELECT encrypted_blob FROM fresh_finance_receipt_recycle_blobs '
      "WHERE entry_id='first' ORDER BY position",
    ).get();
    expect(archived.map((r) => r.read<Uint8List>('encrypted_blob').toList())
        .toList(), savedBytes);
  });

  test('M118: restore after 29 days recovers exact images and references',
      () async {
    await addWithReceipts('first');
    final original = await snapshot().read();
    final path = getEntry(original.values, 'first')['receiptPath'];
    final images = (await vault().readAll('first'))
        .map((part) => part.bytes.toList()).toList();
    final deleted = await recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: original.generation,
      now: createdAt, userConfirmed: true,
    );
    final restored = await recycle().restore(
      entryId: 'first', expectedGeneration: deleted.generation,
      now: createdAt.add(const Duration(days: 29)),
    );
    expect(restored.generation, deleted.generation + 1);
    final current = await snapshot().read();
    expect(getEntry(current.values, 'first')['receiptPath'], path);
    expect(current.values['waffra_sms_hashes_v1'],
        original.values['waffra_sms_hashes_v1']);
    expect((await vault().readAll('first'))
        .map((part) => part.bytes.toList()).toList(), images);
    expect(await recycle().pendingRecoveries(), isEmpty);
    await store.close();
    store = WaffraEncryptedStore.openAt(
      File(directory.path + '/recycle.sqlite'), key: key,
    );
    expect((await vault().readAll('first'))
        .map((part) => part.bytes.toList()).toList(), images);
  });

  test('M118: expired archive rejects restore and remains encrypted', () async {
    await addWithReceipts('first');
    final deleted = await recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'),
      expectedGeneration: (await snapshot().read()).generation,
      now: createdAt, userConfirmed: true,
    );
    await expectLater(recycle().restore(
      entryId: 'first', expectedGeneration: deleted.generation,
      now: createdAt.add(const Duration(days: 30)),
    ), throwsStateError);
    expect((await snapshot().read()).generation, deleted.generation);
    expect((await recycle().pendingRecoveries()).containsKey('first'), true);
    final archived = await store.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_receipt_recycle_blobs',
    ).getSingle();
    expect(archived.read<int>('n'), 2);
  });

  test('M118: unconfirmed, stale and unavailable source retain pictures',
      () async {
    await addWithReceipts('first');
    final generation = (await snapshot().read()).generation;
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: generation,
      now: createdAt, userConfirmed: false,
    ), throwsStateError);
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: generation - 1,
      now: createdAt, userConfirmed: true,
    ), throwsStateError);
    permitSource = false;
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: generation,
      now: createdAt, userConfirmed: true,
    ), throwsStateError);
    expect(await vault().readAll('first'), hasLength(2));
    expect((await snapshot().read()).generation, generation);
    permitSource = true;
    await expectLater(recycle(enabled: false).moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'),
      expectedGeneration: generation,
      now: createdAt, userConfirmed: true,
    ), throwsStateError);
  });

  test('M118: SQL archive failure rolls back ledger, attachments and trash',
      () async {
    await addWithReceipts('first');
    final before = await snapshot().read();
    await store.customStatement('''
CREATE TABLE fresh_finance_receipt_recycle_blobs (
  entry_id TEXT NOT NULL, position INTEGER NOT NULL,
  safe_name TEXT NOT NULL, sha256_hex TEXT NOT NULL,
  byte_count INTEGER NOT NULL, encrypted_blob BLOB NOT NULL,
  PRIMARY KEY(entry_id, position)
)''');
    await store.customStatement('''
CREATE TRIGGER m118_simulated_failure
BEFORE INSERT ON fresh_finance_receipt_recycle_blobs
BEGIN
  SELECT RAISE(ABORT, 'synthetic archive failure');
END
''');
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: before.generation,
      now: createdAt, userConfirmed: true,
    ), throwsA(anything));
    final after = await snapshot().read();
    expect(after.digest, before.digest);
    expect(after.generation, before.generation);
    expect(await vault().readAll('first'), hasLength(2));
  });

  test('M118: tampered archive refuses partial recovery', () async {
    await addWithReceipts('first');
    final deleted = await recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'),
      expectedGeneration: (await snapshot().read()).generation,
      now: createdAt, userConfirmed: true,
    );
    await store.customStatement(
      'UPDATE fresh_finance_receipt_recycle_blobs '
      "SET encrypted_blob=? WHERE entry_id='first' AND position=0",
      [Uint8List.fromList([0, 0])],
    );
    await expectLater(recycle().restore(
      entryId: 'first', expectedGeneration: deleted.generation,
      now: createdAt.add(const Duration(days: 1)),
    ), throwsStateError);
    expect((await snapshot().read()).generation, deleted.generation);
    expect(await vault().readAll('first'), isEmpty);
    expect((await recycle().pendingRecoveries()).containsKey('first'), true);
  });

  test('M118: changed image rejects stale delete despite unchanged generation',
      () async {
    await addWithReceipts('first');
    final loaded = await snapshot().read();
    final oldHashes = await imageDigests('first');
    await vault().replaceExistingImage(
      entryId: 'first', position: 0,
      image: Uint8List.fromList([90, 91, 92]),
      expectedSha256: oldHashes.first,
    );
    expect((await snapshot().read()).generation, loaded.generation);
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: oldHashes,
      expectedGeneration: loaded.generation,
      now: createdAt, userConfirmed: true,
    ), throwsStateError);
    expect(await vault().readAll('first'), hasLength(2));
    expect((await vault().readAll('first')).first.bytes, [90, 91, 92]);
    expect((await recycle().pendingRecoveries()).containsKey('first'), false);
  });

  test('M118: concurrent widget write invalidates stale deletion', () async {
    await addWithReceipts('first');
    final baseline = await snapshot().read();
    await WaffraUnifiedFinanceWriter(
      writerDirectory: directory,
      snapshot: snapshot(), experimentalEnabled: true,
    ).appendTransactions(
      records: [entry('widget-added')],
      messageHashes: [null], userConfirmed: true,
    );
    await expectLater(recycle().moveToRecycle(
      entryId: 'first', expectedImageHashes: await imageDigests('first'), expectedGeneration: baseline.generation,
      now: createdAt, userConfirmed: true,
    ), throwsStateError);
    final latest = await snapshot().read();
    expect(getEntry(latest.values, 'widget-added')['amount'], 84.72);
    expect(await vault().readAll('first'), hasLength(2));
  });
}

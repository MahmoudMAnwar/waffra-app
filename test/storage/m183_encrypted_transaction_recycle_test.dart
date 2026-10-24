import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_encrypted_transaction_recycle.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporary;
  late WaffraEncryptedStore store;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedTransactionRecycle recycle;
  late WaffraEncryptedReceiptVault receipts;

  final deletedAt = DateTime.utc(2026, 10, 24, 9, 0);
  final imageBytes = Uint8List.fromList(<int>[137, 80, 78, 71, 1, 2, 3, 4]);
  const id = 'synthetic-m183-entry';
  String hash(Uint8List bytes) => sha256.convert(bytes).toString();

  Map<String, Object?> entry({bool hasImage = false}) =>
      <String, Object?>{
        'id': id,
        'title': 'Synthetic invoice',
        'category': 'Utilities',
        'amount': 15.25,
        'income': false,
        'date': '2026-10-24T09:00:00.000Z',
        'receiptPath': hasImage
            ? WaffraEncryptedReceiptReference.of(id, 0)
            : null,
      };

  Future<void> seed({bool withReceipt = true}) async {
    final record = entry(hasImage: withReceipt);
    await store.transaction(() async {
      await store.customStatement(
        'INSERT INTO fresh_finance_entries(entry_id,title,category_snapshot,'
        'amount_minor,is_income,occurred_iso,receipt_count,source_json) '
        'VALUES(?,?,?,?,?,?,?,?)',
        [id, record['title'], record['category'], 1525, 0,
         record['date'], 0, jsonEncode(record)],
      );
      if (withReceipt) {
        await receipts.attachNewBatch(
          entryId: id,
          images: <Uint8List>[imageBytes],
        );
      }
      final current = await snapshot.read();
      await snapshot.commit(
        expectedGeneration: current.generation,
        fullFinanceSnapshot: <String, Object?>{
          ...current.values,
          'entries': jsonEncode(<Map<String, Object?>>[record]),
        },
      );
    });
  }

  Future<int> typedCount() async {
    final sql = await store.customSelect(
      'SELECT count(*) AS n FROM fresh_finance_entries',
    ).getSingle();
    return sql.read<int>('n');
  }

  Future<void> sourceWitness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getBool(WaffraLiveLegacyFinanceGuard.activeKey) != true ||
        prefs.containsKey(WaffraLiveLegacyFinanceGuard.pendingKey)) {
      throw StateError('Synthetic SQL source witness is invalid.');
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    temporary = await Directory.systemTemp.createTemp('m183-sqlcipher-test-');
    store = WaffraEncryptedStore.openAt(
      File('${temporary.path}/synthetic.sqlite'),
      key: 'm183-synthetic-disposable-key-only',
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: store, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: store, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    receipts = WaffraEncryptedReceiptVault(
      store: store, experimentalEnabled: true,
    );
    recycle = WaffraEncryptedTransactionRecycle(
      snapshot: snapshot,
      writerDirectory: temporary,
      verifySourceUnderLock: sourceWitness,
      experimentalEnabled: true,
    );
  });

  tearDown(() async {
    await store.close();
    if (await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  });

  test('M183 deletes transaction and encrypted invoice as one reversible SQL commit',
      () async {
    await seed();
    final baseline = await snapshot.read();
    final original = await receipts.readAll(id);
    expect(original.single.sha256Hex, hash(imageBytes));
    final deleted = await recycle.delete(
      baseline: baseline,
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: true,
    );
    expect(deleted.receiptCount, 1);
    expect(deleted.restored, isFalse);
    expect(await typedCount(), 0);
    expect(jsonDecode((await snapshot.read()).values['entries'] as String),
        isEmpty);
    final archive = await store.customSelect(
      'SELECT encrypted_blob FROM fresh_finance_transaction_recycle_blobs '
      'WHERE entry_id=\'synthetic-m183-entry\'',
    ).get();
    expect(archive, hasLength(1));
    expect(archive.single.read<Uint8List>('encrypted_blob'), imageBytes);
    expect((await recycle.pendingRecoveries())[id], deleted.expiresAtMs);
  });

  test('M183 undo restores identical financial fields and receipt bytes',
      () async {
    await seed();
    await recycle.delete(
      baseline: await snapshot.read(),
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: true,
    );
    final restored = await recycle.restore(
      baseline: await snapshot.read(),
      entryId: id,
      now: deletedAt.add(const Duration(hours: 1)),
    );
    expect(restored.restored, isTrue);
    expect(restored.receiptCount, 1);
    expect(await typedCount(), 1);
    final ledger = jsonDecode(
      (await snapshot.read()).values['entries'] as String,
    ) as List<dynamic>;
    expect(ledger, hasLength(1));
    expect(ledger.single, entry(hasImage: true));
    expect((await receipts.readAll(id)).single.bytes, imageBytes);
    expect(await recycle.pendingRecoveries(), isEmpty);
  });

  test('M183 no-invoice transaction can be recycled without creating fake bytes',
      () async {
    await seed(withReceipt: false);
    final removed = await recycle.delete(
      baseline: await snapshot.read(),
      entryId: id,
      expectedImageHashes: const <String>[],
      now: deletedAt,
      userConfirmed: true,
    );
    expect(removed.receiptCount, 0);
    expect(await typedCount(), 0);
    await recycle.restore(
      baseline: await snapshot.read(),
      entryId: id,
      now: deletedAt.add(const Duration(seconds: 15)),
    );
    expect(await typedCount(), 1);
    expect(jsonDecode((await snapshot.read()).values['entries'] as String),
        hasLength(1));
    expect((await receipts.readAll(id)), isEmpty);
  });

  test('M183 stale Home finance cannot delete after separate Widget edit',
      () async {
    await seed();
    final stale = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: stale.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...stale.values,
        'waffra_monthly_budget_v1': 100.0,
      },
    );
    final latest = await snapshot.read();
    await expectLater(recycle.delete(
      baseline: stale,
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, latest.digest);
    expect(await typedCount(), 1);
  });

  test('M183 replaced receipt rejects outdated byte digest without losing funds',
      () async {
    await seed();
    final baseline = await snapshot.read();
    final later = Uint8List.fromList(<int>[137, 80, 78, 71, 8, 9, 10]);
    await receipts.replaceExistingImage(
      entryId: id,
      position: 0,
      image: later,
      expectedSha256: hash(imageBytes),
    );
    await expectLater(recycle.delete(
      baseline: baseline,
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: true,
    ), throwsStateError);
    expect(await typedCount(), 1);
    expect((await receipts.readAll(id)).single.bytes, later);
  });

  test('M183 no consent and wrong receipt witness cannot delete transaction',
      () async {
    await seed();
    final original = await snapshot.read();
    await expectLater(recycle.delete(
      baseline: original,
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: false,
    ), throwsStateError);
    await expectLater(recycle.delete(
      baseline: original,
      entryId: id,
      expectedImageHashes: const <String>[],
      now: deletedAt,
      userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
    expect(await typedCount(), 1);
  });

  test('M183 expired or rolled-back clock cannot restore archived money',
      () async {
    await seed();
    await recycle.delete(
      baseline: await snapshot.read(),
      entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt,
      userConfirmed: true,
    );
    final immutable = await snapshot.read();
    for (final time in [
      deletedAt.subtract(const Duration(milliseconds: 1)),
      deletedAt.add(const Duration(days: 30)),
      deletedAt.add(const Duration(days: 31)),
    ]) {
      await expectLater(recycle.restore(
        baseline: immutable, entryId: id, now: time,
      ), throwsStateError);
    }
    expect((await snapshot.read()).digest, immutable.digest);
    expect(await typedCount(), 0);
  });

  test('M183 corrupted archived encrypted receipt cannot rehydrate funds',
      () async {
    await seed();
    await recycle.delete(
      baseline: await snapshot.read(), entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt, userConfirmed: true,
    );
    await store.customStatement(
      'UPDATE fresh_finance_transaction_recycle_blobs SET encrypted_blob=? '
      'WHERE entry_id=?',
      [Uint8List.fromList(<int>[1, 2, 3]), id],
    );
    final unchanged = await snapshot.read();
    await expectLater(recycle.restore(
      baseline: unchanged,
      entryId: id,
      now: deletedAt.add(const Duration(hours: 2)),
    ), throwsStateError);
    expect((await snapshot.read()).digest, unchanged.digest);
    expect(await typedCount(), 0);
  });

  test('M183 changed archived financial amount cannot silently restore',
      () async {
    await seed();
    await recycle.delete(
      baseline: await snapshot.read(), entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt, userConfirmed: true,
    );
    final altered = entry(hasImage: true)..['amount'] = 955.25;
    await store.customStatement(
      'UPDATE fresh_finance_transaction_recycle SET source_json=? '
      'WHERE entry_id=?',
      [jsonEncode(altered), id],
    );
    final old = await snapshot.read();
    await expectLater(recycle.restore(
      baseline: old, entryId: id,
      now: deletedAt.add(const Duration(hours: 1)),
    ), throwsStateError);
    expect((await snapshot.read()).digest, old.digest);
    expect(await typedCount(), 0);
  });

  test('M183 source activation conflict blocks both delete and restore',
      () async {
    await seed();
    final before = await snapshot.read();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    await expectLater(recycle.delete(
      baseline: before, entryId: id,
      expectedImageHashes: <String>[hash(imageBytes)],
      now: deletedAt, userConfirmed: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
  });

  test('M183 disabled source rejects all deletions and metadata reads',
      () async {
    final disabled = WaffraEncryptedTransactionRecycle(
      snapshot: snapshot,
      writerDirectory: temporary,
      verifySourceUnderLock: sourceWitness,
    );
    await expectLater(disabled.delete(
      baseline: await snapshot.read(), entryId: id,
      expectedImageHashes: const <String>[],
      now: deletedAt, userConfirmed: true,
    ), throwsStateError);
    await expectLater(disabled.pendingRecoveries(), throwsStateError);
  });
}

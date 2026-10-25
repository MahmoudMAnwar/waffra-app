import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_full_finance_reset.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_portable_encrypted_vault_restorer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pass = 'm188-independent-disposable-backup-password';
  const key = 'm188-disposable-32-or-more-key-no-live-data';
  const entryId = 'm188-finance-entry';
  final image = Uint8List.fromList(<int>[137, 80, 78, 71, 3, 7, 1, 8]);
  final smsHash = sha256.convert(utf8.encode('synthetic bank SMS')).toString();

  late Directory temp;
  late WaffraEncryptedStore vault;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedReceiptVault receipts;
  late WaffraEncryptedFullFinanceReset resetter;
  var sourceVerified = true;

  Map<String, Object?> financeEntry() => <String, Object?>{
    'id': entryId,
    'title': 'Synthetic invoice',
    'category': 'Bills',
    'amount': 84.72,
    'income': false,
    'date': '2026-10-24T09:00:00.000Z',
    'receiptPath': WaffraEncryptedReceiptReference.of(entryId, 0),
  };

  Future<void> seed() async {
    final item = financeEntry();
    await vault.transaction(() async {
      await vault.customStatement(
        'INSERT INTO fresh_finance_entries'
        '(entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
        [entryId, item['title'], item['category'], 8472, 0,
         item['date'], jsonEncode(item)],
      );
      await receipts.attachNewBatch(
        entryId: entryId, images: <Uint8List>[image],
      );
      await vault.customStatement(
        'INSERT INTO fresh_finance_sms_hashes(message_hash) VALUES (?)',
        [smsHash],
      );
      final start = await snapshot.read();
      await snapshot.commit(
        expectedGeneration: start.generation,
        fullFinanceSnapshot: <String, Object?>{
          ...start.values,
          'entries': jsonEncode([item]),
          'waffra_sms_hashes_v1': <String>[smsHash],
          'waffra_categories_v24': '[]',
          'waffra_goals_v24': '[]',
          'waffra_recurring_v24': '[]',
          'waffra_deleted_categories_v1': '[]',
          'waffra_deleted_goals_v1': '[]',
          'waffra_deleted_recurring_v1': '[]',
        },
      );
    });
  }

  Future<String> backedUp() async {
    final current = await snapshot.read();
    return WaffraPortableBackupV2.create(
      financialSnapshot: current.values,
      receipts: <WaffraReceiptBackupPart>[
        WaffraReceiptBackupPart(
          entryId: entryId, position: 0, bytes: image,
        ),
      ],
      password: pass,
    );
  }

  Future<int> count(String table) async {
    final row = await vault.customSelect(
      'SELECT count(*) AS n FROM ' + table,
    ).getSingle();
    return row.read<int>('n');
  }

  Future<WaffraEncryptedFullResetResult> execute({
    WaffraFinanceSnapshotState? witness,
    String? archive,
    String password = pass,
    bool consent = true,
    bool biometric = true,
    bool saved = true,
    String phrase = WaffraEncryptedFullFinanceReset.confirmation,
  }) async {
    final baseline = witness ?? await snapshot.read();
    final backup = archive ?? await backedUp();
    return resetter.reset(
      baseline: baseline,
      encryptedBackup: backup,
      backupPassword: password,
      confirmationPhrase: phrase,
      userConfirmed: consent,
      biometricVerified: biometric,
      externalBackupSaved: saved,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'waffra_language': 'en',
    });
    temp = await Directory.systemTemp.createTemp('m188-reset-fixture-');
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/disposable.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: vault, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    receipts = WaffraEncryptedReceiptVault(
      store: vault, experimentalEnabled: true,
    );
    sourceVerified = true;
    resetter = WaffraEncryptedFullFinanceReset(
      snapshot: snapshot,
      writerDirectory: temp,
      verifySourceUnderLock: () async {
        if (!sourceVerified) {
          throw StateError('Encrypted source marker is not verified.');
        }
      },
      experimentalEnabled: true,
    );
    await seed();
  });

  tearDown(() async {
    await vault.close();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('M188 authenticated reset atomically deletes funds receipt SMS and modules',
      () async {
    final before = await snapshot.read();
    final result = await execute();
    expect(result.transactionsRemoved, 1);
    expect(result.receiptImagesRemoved, 1);
    expect(result.previousDigest, before.digest);
    expect(result.previousGeneration, before.generation);
    expect(result.newGeneration, before.generation + 1);
    expect(result.resetDigest, isNot(before.digest));
    for (final table in [
      'fresh_finance_entries', 'fresh_finance_receipt_blobs',
      'fresh_finance_categories', 'fresh_finance_goals',
      'fresh_finance_recurring', 'fresh_finance_sms_hashes',
      'fresh_finance_custom_goals', 'fresh_finance_settings',
    ]) {
      expect(await count(table), 0, reason: table);
    }
    final cleared = await snapshot.read();
    expect(cleared.values, const <String, Object?>{'entries': '[]'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_language'), 'en');

    await vault.close();
    vault = WaffraEncryptedStore.openAt(
      File('${temp.path}/disposable.sqlite'), key: key,
    );
    final cold = await WaffraAtomicFinanceSnapshot(
      store: vault, experimentalEnabled: true,
    ).read();
    expect(cold.digest, result.resetDigest);
    expect(await count('fresh_finance_entries'), 0);
  });

  test('M212 reset preserves preexisting encrypted activation checkpoint',
      () async {
    // Simulated checkpoint metadata is an internal QA-only witness, NOT
    // permission to activate customer SQLCipher without physical evidence.
    await vault.customStatement('''
CREATE TABLE fresh_finance_cutover_checkpoint(
  singleton INTEGER PRIMARY KEY CHECK(singleton=1),
  source_digest TEXT NOT NULL,
  encrypted_digest TEXT NOT NULL,
  phase TEXT NOT NULL,
  activated_generation INTEGER,
  modified_at_ms INTEGER NOT NULL
)''');
    await vault.customStatement(
      'INSERT INTO fresh_finance_cutover_checkpoint '
      '(singleton,source_digest,encrypted_digest,phase,'
      'activated_generation,modified_at_ms) VALUES(1,?,?,?,?,?)',
      [List<String>.filled(64, 'a').join(),
       (await snapshot.read()).digest, 'active', 1,
       DateTime.utc(2026, 10, 25).millisecondsSinceEpoch],
    );
    final saved = await execute();
    expect(saved.transactionsRemoved, 1);
    final witness = await vault.customSelect(
      'SELECT phase,activated_generation FROM '
      'fresh_finance_cutover_checkpoint WHERE singleton=1',
    ).getSingle();
    expect(witness.read<String>('phase'), 'active');
    expect(witness.read<int>('activated_generation'), 1);
    expect((await snapshot.read()).values['entries'], '[]');
  });

  test('M188 incorrect encrypted backup password cannot erase the original',
      () async {
    final original = await snapshot.read();
    await expectLater(execute(password: 'wrong-but-long-enough'),
        throwsA(anything));
    expect((await snapshot.read()).digest, original.digest);
    expect(await count('fresh_finance_entries'), 1);
    expect((await receipts.readAll(entryId)).single.bytes, image);
  });

  test('M188 irreversible reset needs confirmation biometric and saved backup',
      () async {
    final original = await snapshot.read();
    await expectLater(execute(consent: false), throwsStateError);
    await expectLater(execute(biometric: false), throwsStateError);
    await expectLater(execute(saved: false), throwsStateError);
    await expectLater(execute(phrase: 'RESET'), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
  });

  test('M188 stale Widget finance generation refuses reset', () async {
    final old = await snapshot.read();
    await snapshot.commit(
      expectedGeneration: old.generation,
      fullFinanceSnapshot: <String, Object?>{
        ...old.values, 'waffra_monthly_budget_v1': 500.0,
      },
    );
    final latest = await snapshot.read();
    await expectLater(execute(witness: old), throwsStateError);
    expect((await snapshot.read()).digest, latest.digest);
  });

  test('M188 any source-marker mismatch fails without deleting receipts',
      () async {
    final before = await snapshot.read();
    sourceVerified = false;
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
    expect((await receipts.readAll(entryId)).single.bytes, image);
  });

  test('M188 forged typed amount cannot be covered up by a finance reset',
      () async {
    final original = await snapshot.read();
    await vault.customStatement(
      'UPDATE fresh_finance_entries SET amount_minor=9999 WHERE entry_id=?',
      [entryId],
    );
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
    expect(await count('fresh_finance_entries'), 1);
  });

  test('M188 orphan invoice bytes block full reset without loss', () async {
    final original = await snapshot.read();
    await vault.customStatement(
      'UPDATE fresh_finance_entries SET receipt_count=0 WHERE entry_id=?',
      [entryId],
    );
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
    // A corrupted receipt_count must make the high-level receipt reader
    // fail closed. Check the raw encrypted BLOB row survives instead of
    // bypassing that integrity guard to read it.
    await expectLater(receipts.readAll(entryId), throwsStateError);
    expect(await count('fresh_finance_receipt_blobs'), 1);
    expect(await count('fresh_finance_entries'), 1);
  });

  test('M188 typed SMS fingerprints must match backup before resetting',
      () async {
    final original = await snapshot.read();
    await vault.customStatement('DELETE FROM fresh_finance_sms_hashes');
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, original.digest);
  });

  test('M188 nonempty recoverable tombstones refuse irreversible reset',
      () async {
    await vault.customStatement(
      'CREATE TABLE fresh_finance_transaction_recycle('
      'entry_id TEXT NOT NULL)',
    );
    await vault.customStatement(
      'INSERT INTO fresh_finance_transaction_recycle(entry_id) VALUES (?)',
      ['pending-30-day-undo'],
    );
    final before = await snapshot.read();
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
    expect(await count('fresh_finance_transaction_recycle'), 1);
    expect(await count('fresh_finance_entries'), 1);
  });

  test('M188 unapproved new encrypted financial table blocks unsafe deletion',
      () async {
    await vault.customStatement(
      'CREATE TABLE fresh_finance_future_wallet(source_json TEXT NOT NULL)',
    );
    await vault.customStatement(
      'INSERT INTO fresh_finance_future_wallet(source_json) VALUES (?)',
      ['{"money":12345}'],
    );
    final before = await snapshot.read();
    await expectLater(execute(), throwsStateError);
    expect((await snapshot.read()).digest, before.digest);
    expect(await count('fresh_finance_future_wallet'), 1);
  });

  test('M188 default-off encrypted full reset leaves user money untouched',
      () async {
    final disabled = WaffraEncryptedFullFinanceReset(
      snapshot: snapshot,
      writerDirectory: temp,
      verifySourceUnderLock: () async {},
    );
    final old = await snapshot.read();
    await expectLater(disabled.reset(
      baseline: old,
      encryptedBackup: await backedUp(),
      backupPassword: pass,
      confirmationPhrase: WaffraEncryptedFullFinanceReset.confirmation,
      userConfirmed: true,
      biometricVerified: true,
      externalBackupSaved: true,
    ), throwsStateError);
    expect((await snapshot.read()).digest, old.digest);
  });
}

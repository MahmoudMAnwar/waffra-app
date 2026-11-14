import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_full_finance_reset.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M644 uses ONLY a disposable SQLCipher key and synthetic test transactions.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const key = 'm644-disposable-encrypted-finance-test-key';
  late Directory directory;
  late WaffraEncryptedStore db;
  late WaffraAtomicFinanceSnapshot snapshot;
  late WaffraEncryptedFullFinanceReset resetter;
  late WaffraFinanceSnapshotState previous;
  var sourceValid = true;

  Future<int> count(String name) async {
    final rows = await db.customSelect(
      'SELECT count(*) AS n FROM ' + name,
    ).getSingle();
    return rows.read<int>('n');
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'waffra_language': 'ar', 'waffra_dark_mode': true,
    });
    directory = await Directory.systemTemp.createTemp('m644-synthetic-reset-');
    db = WaffraEncryptedStore.openAt(
      File(directory.path + '/finance.sqlite'), key: key,
    );
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    snapshot = WaffraAtomicFinanceSnapshot(
      store: db, experimentalEnabled: true,
    );
    await snapshot.initializeEmpty();
    await WaffraAccountsSchema.install(db);
    const stamp = '2026-11-14T10:00:00.000Z';
    const one = 'account-one', two = 'account-two';
    final entry = <String, Object?>{
      'id': 'test-entry', 'title': 'Synthetic expense',
      'category': 'Groceries', 'amount': 10.0, 'income': false,
      'date': stamp, 'receiptPath': null,
    };
    await db.transaction(() async {
      await db.customStatement(
        'INSERT INTO fresh_finance_entries'
        '(entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES(?,?,?,?,?,?,?,?)',
        ['test-entry','Synthetic expense','Groceries',1000,0,
         stamp,0,jsonEncode(entry)],
      );
      for (final account in [one, two]) {
        await db.customStatement(
          'INSERT INTO fresh_finance_money_accounts'
          '(account_id,label,kind,currency,opening_minor,archived,created_iso) '
          'VALUES(?,?,?,?,?,?,?)',
          [account,account,'bank','SAR',10000,0,stamp],
        );
      }
      await db.customStatement(
        'INSERT INTO fresh_finance_account_entry_links'
        '(entry_id,account_id,confirmed_iso) VALUES(?,?,?)',
        ['test-entry',one,stamp],
      );
      await db.customStatement(
        'INSERT INTO fresh_finance_internal_transfers'
        '(transfer_id,from_account_id,to_account_id,amount_minor,'
        'occurred_iso,note) VALUES(?,?,?,?,?,?)',
        ['tx-test',one,two,125,stamp,'synthetic transfer'],
      );
      final initial = await snapshot.read();
      await snapshot.commit(
        expectedGeneration: initial.generation,
        fullFinanceSnapshot: <String,Object?>{
          'entries':jsonEncode([entry]),
        },
      );
    });
    previous = await snapshot.read();
    sourceValid = true;
    resetter = WaffraEncryptedFullFinanceReset(
      snapshot: snapshot, writerDirectory: directory,
      verifySourceUnderLock: () async {
        if (!sourceValid) throw StateError('Source marker changed');
      },
      experimentalEnabled: true,
    );
  });

  tearDown(() async {
    await db.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('M644 one biometric approval clears ledger, accounts and transfers '
      'without requiring an external backup', () async {
    final cleared = await resetter.resetAfterBiometric(
      baseline: previous,
      userConfirmed: true,
      biometricVerified: true,
    );
    expect(cleared.transactionsRemoved, 1);
    expect(cleared.newGeneration, previous.generation + 1);
    for (final table in [
      'fresh_finance_entries',
      'fresh_finance_money_accounts',
      'fresh_finance_account_entry_links',
      'fresh_finance_internal_transfers',
      'fresh_finance_goals',
      'fresh_finance_recurring',
      'fresh_finance_receipt_blobs',
      'fresh_finance_sms_hashes',
    ]) {
      expect(await count(table), 0, reason: table);
    }
    expect((await snapshot.read()).values, {'entries':'[]'});
    expect((await db.customSelect('PRAGMA foreign_key_check').get()), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_language'), 'ar');
    expect(prefs.getBool('waffra_dark_mode'), isTrue);
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File(directory.path+'/finance.sqlite'), key:key);
    expect((await WaffraAtomicFinanceSnapshot(
      store:db,experimentalEnabled:true).read()).values, {'entries':'[]'});
    expect(await count('fresh_finance_money_accounts'), 0);
    await WaffraAccountsSchema.requireReady(db);
  });

  test('M644 biometric refusal never changes finance or account balances',
      () async {
    await expectLater(resetter.resetAfterBiometric(
      baseline:previous,userConfirmed:true,biometricVerified:false),
      throwsStateError);
    expect((await snapshot.read()).digest, previous.digest);
    expect(await count('fresh_finance_money_accounts'), 2);
    expect(await count('fresh_finance_entries'), 1);
  });

  test('M644 stale or forged source and unknown finance table fail closed',
      () async {
    sourceValid = false;
    await expectLater(resetter.resetAfterBiometric(
      baseline:previous,userConfirmed:true,biometricVerified:true),
      throwsStateError);
    sourceValid = true;
    await db.customStatement(
      'CREATE TABLE fresh_finance_unverified_v44(value TEXT)');
    await expectLater(resetter.resetAfterBiometric(
      baseline:previous,userConfirmed:true,biometricVerified:true),
      throwsStateError);
    expect((await snapshot.read()).digest, previous.digest);
    expect(await count('fresh_finance_entries'), 1);
    expect(await count('fresh_finance_internal_transfers'), 1);
  });
}

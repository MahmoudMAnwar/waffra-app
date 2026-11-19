import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M1040/#769: disposable SQLCipher only; never any real user bank data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late File file;
  late WaffraEncryptedStore db;
  late WaffraAccountsRepository accounts;
  const key = 'm1040-disposable-verified-source-funds-key';
  const at = '2026-11-19T10:00:00';

  Future<Map<String, int>> balances() async => {
    for (final a in await accounts.balances()) a.id: a.balanceMinor,
  };
  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle()).read<int>('n');

  Future<bool> move(String id, int amount, {
    String from = 'bank',
    String to = 'wallet',
    int fee = 0,
    bool confirmed = true,
  }) => accounts.transfer(
    id: id, fromAccountId: from, toAccountId: to,
    amountMinor: amount,
    additionalSourceDebitMinor: fee,
    occurredIso: at, userConfirmed: confirmed,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('waffra-m1040-source-funds-');
    file = File('${dir.path}/finance.sqlite');
    db = WaffraEncryptedStore.openAt(file, key: key);
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await WaffraAccountsSchema.install(db);
    accounts = WaffraAccountsRepository(db: db, experimentalEnabled: true);
    await accounts.createAccount(
      id: 'bank', name: 'Source Bank', kind: 'bank',
      openingMinor: 10000, createdIso: at, userConfirmed: true);
    await accounts.createAccount(
      id: 'wallet', name: 'Destination Wallet', kind: 'wallet',
      openingMinor: 0, createdIso: at, userConfirmed: true);
    await accounts.createAccount(
      id: 'other', name: 'Other Bank', kind: 'bank',
      openingMinor: 5000, createdIso: at, userConfirmed: true);
  });

  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('M1040 oversized source transfer is rejected atomically', () async {
    expect(await balances(), {'bank': 10000, 'wallet': 0, 'other': 5000});
    await expectLater(move('unsupported-150-sar', 15000),
      throwsA(isA<StateError>()));
    expect(await count('fresh_finance_internal_transfers'), 0);
    expect(await count('fresh_finance_entries'), 0);
    expect(await balances(), {'bank': 10000, 'wallet': 0, 'other': 5000});
  });

  test('M1040 exact funds permitted, replay idempotent after depletion', () async {
    expect(await move('exact', 10000), isTrue);
    expect(await balances(), {'bank': 0, 'wallet': 10000, 'other': 5000});
    expect(await move('exact', 10000), isFalse,
      reason: 'An identical retry must not debit the account again.');
    await expectLater(move('same-id-new-money', 1), throwsStateError);
    await expectLater(move('exact', 10001), throwsStateError);
    expect(await count('fresh_finance_internal_transfers'), 1);
    expect(await balances(), {'bank': 0, 'wallet': 10000, 'other': 5000});
    expect(await accounts.reverseInternalTransfer(
      originalTransferId: 'exact', reversedIso: at,
      userConfirmed: true), isTrue);
    expect(await balances(), {'bank': 10000, 'wallet': 0, 'other': 5000});
    expect(await count('fresh_finance_internal_transfers'), 2);
  });

  test('M1040 checks latest SQL balance after earlier transfer, including income', () async {
    expect(await move('first', 8000), isTrue);
    await expectLater(move('too-much-after-first', 2001), throwsStateError);
    expect(await move('inbound', 2500, from: 'other', to: 'bank'), isTrue);
    expect(await move('now-covered', 4500), isTrue);
    expect(await balances(), {'bank': 0, 'wallet': 12500, 'other': 2500});
    expect(await count('fresh_finance_internal_transfers'), 3);
  });

  test('M1040 SMS fee reserve uses credited amount plus fee, not only transfer', () async {
    // Simulate separately booked fee of 6.00 SAR on 95.00 SAR transfer.
    await expectLater(move('not-funded-with-fee', 9500, fee: 600),
      throwsStateError);
    expect(await count('fresh_finance_internal_transfers'), 0);
    expect(await balances(), {'bank': 10000, 'wallet': 0, 'other': 5000});

    // Included fee: 100.00 SAR gross, recipient gets 95.00 and fee is 5.00.
    expect(await move('exact-with-fee', 9500, fee: 500), isTrue);
    expect(await count('fresh_finance_internal_transfers'), 1);
    // This accounts-only fixture has no fee entry; the production SMS writer
    // adds that expense under the SAME outer SQL transaction and app lock.
    expect(await balances(), {'bank': 500, 'wallet': 9500, 'other': 5000});
    await expectLater(move('invalid-negative-fee', 100, fee: -1),
      throwsArgumentError);
  });

  test('M1040 no stale funds after SQLCipher cold reopen', () async {
    expect(await move('sent', 9000), isTrue);
    await db.close();
    db = WaffraEncryptedStore.openAt(file, key: key);
    await WaffraAccountsSchema.requireReady(db);
    accounts = WaffraAccountsRepository(db: db, experimentalEnabled: true);
    await expectLater(move('not-covered-after-reopen', 1001),
      throwsStateError);
    expect(await balances(), {'bank': 1000, 'wallet': 9000, 'other': 5000});
  });
}

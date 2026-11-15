import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M952 axes 1/2: no account-linked finance may trust a partial domain
/// schema just because the account revision table is still present.
/// All fixtures are temporary and encrypted. No live-user vault is opened.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> withFreshVault(
    Future<void> Function(WaffraEncryptedStore db) verify,
  ) async {
    final dir = await Directory.systemTemp.createTemp('m952-account-ready-');
    WaffraEncryptedStore? store;
    try {
      store = WaffraEncryptedStore.openAt(
        File('${dir.path}/disposable-vault.sqlite'),
        key: 'm952-disposable-encrypted-vault-key',
      );
      await WaffraFreshEncryptedVaultBootstrap(
        store: store,
        experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(store);
      await WaffraAccountsSchema.requireReady(store);
      await verify(store);
    } finally {
      await store?.close();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  test('M952 linked account readiness rejects missing goal wallet table '
      'even when accounts and foreign-key check are healthy', () async {
    await withFreshVault((db) async {
      // The account schema and its revision still exist, but this
      // finance-domain link table has been lost in an interrupted restore.
      await db.customStatement(
        'DROP TABLE fresh_finance_goal_wallet_movements',
      );
      final surviving = await db.customSelect(
        'SELECT version FROM fresh_finance_account_revision '
        "WHERE slot='accounts'",
      ).getSingle();
      expect(surviving.read<int>('version'), WaffraAccountsSchema.version);
      expect((await db.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty);
      await expectLater(
        WaffraAccountsSchema.requireReady(db),
        throwsStateError,
      );
    });
  });

  test('M952 account readiness rejects altered domain revision '
      'without modifying ledger or account rows', () async {
    await withFreshVault((db) async {
      await db.customStatement(
        "UPDATE fresh_finance_domain_revision SET version=99 "
        "WHERE slot='domain'",
      );
      final accountRowsBefore = (await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_money_accounts',
      ).getSingle()).read<int>('n');
      await expectLater(
        WaffraAccountsSchema.requireReady(db),
        throwsStateError,
      );
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_money_accounts',
      ).getSingle()).read<int>('n'), accountRowsBefore);
    });
  });
}

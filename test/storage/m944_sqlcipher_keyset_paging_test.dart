import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_sqlcipher_history_pager.dart';

/// M944 axis 1: source-backed SQLCipher paging, never a list of all MoneyEntry
/// objects split into smaller Flutter widgets. Synthetic data only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M944 keyset pages preserve 2700 encrypted entries, ties and account scope',
      () async {
    final directory = await Directory.systemTemp.createTemp('m944-sql-page-');
    final path = File(directory.path + '/vault.sqlite');
    const key = 'm944-disposable-only-vault-key';
    WaffraEncryptedStore? db;
    try {
      db = WaffraEncryptedStore.openAt(path, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: db, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(db);
      final accounts = WaffraAccountsRepository(
        db: db, experimentalEnabled: true);
      for (final id in ['bank-a', 'bank-b']) {
        await accounts.createAccount(
          id: id, name: id, kind: 'bank',
          openingMinor: id == 'bank-a' ? 100000 : 250000,
          createdIso: '2026-11-01T00:00:00',
          userConfirmed: true);
      }

      const insert = 'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)';
      const link = 'INSERT INTO fresh_finance_account_entry_links '
          '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)';
      await db.transaction(() async {
        for (var i = 0; i < 2700; i++) {
          final id = 'm944-' + i.toString().padLeft(5, '0');
          final month = i % 5 == 0 ? '10' : '11';
          final date = '2026-' + month + '-04T12:00:00';
          await db!.customStatement(
            insert, [id, id, 'Synthetic', 125, i % 17 == 0 ? 1 : 0,
              date, '{}']);
          if (i % 3 != 2) {
            await db!.customStatement(link, [
              id, i % 3 == 0 ? 'bank-a' : 'bank-b',
              '2026-11-15T00:00:00',
            ]);
          }
        }
      });

      Future<List<String>> queryIds(String sql, [List<Object?> args = const []])
          async {
        final rows = await db!.customSelect(
          sql,
          variables: [
            for (final arg in args)
              if (arg is String) Variable.withString(arg)
              else if (arg is int) Variable.withInt(arg),
          ],
        ).get();
        return rows.map((row) => row.read<String>('entry_id')).toList();
      }

      final expected = await queryIds(
        'SELECT entry_id FROM fresh_finance_entries '
        'ORDER BY occurred_iso DESC,entry_id DESC');
      expect(expected.length, 2700);

      Future<List<String>> collect({
        int limit = 43,
        String? monthIso,
        String? accountId,
        bool? income,
      }) async {
        final result = <String>[];
        WaffraSqlcipherHistoryCursor? after;
        for (var i = 0; i < 100; i++) {
          final page = await WaffraSqlcipherHistoryPager.load(
            store: db!, limit: limit, monthIso: monthIso,
            accountId: accountId, income: income, after: after);
          expect(page.entries.length, lessThanOrEqualTo(limit));
          result.addAll(page.entries.map((row) => row.id));
          if (!page.hasMore) {
            expect(page.nextCursor, isNull);
            return result;
          }
          expect(page.nextCursor, isNotNull);
          expect(page.entries, isNotEmpty);
          after = page.nextCursor;
        }
        fail('Keyset did not terminate after 100 bounded pages.');
      }

      final all = await collect();
      expect(all, expected);
      expect(all.toSet().length, expected.length);
      final scopedExpected = await queryIds(
        'SELECT e.entry_id FROM fresh_finance_entries e '
        'JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id '
        'WHERE e.occurred_iso>=? AND e.occurred_iso<? '
        'AND l.account_id=? AND e.is_income=? '
        'ORDER BY e.occurred_iso DESC,e.entry_id DESC',
        ['2026-11-01', '2026-12-01', 'bank-a', 0]);
      final scoped = await collect(
        limit: 29, monthIso: '2026-11',
        accountId: 'bank-a', income: false);
      expect(scoped, scopedExpected);
      expect(scoped.toSet().length, scoped.length);
      final november = await WaffraSqlcipherHistoryPager.load(
        store: db, monthIso: '2026-11', limit: 75);
      final legacy = await WaffraAccountContextRead.loadMonthEntries(
        store: db, monthIso: '2026-11', limit: 75);
      expect(november.entries.map((r) => r.id).toList(),
          legacy.map((r) => r.id).toList());
      expect(
        (await collect(monthIso: '2026-09')).isEmpty, isTrue);

      final countBefore = (await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n');
      final balancesBefore = await accounts.balances();
      expect(() => WaffraSqlcipherHistoryPager.load(
        store: db!, limit: 0), throwsArgumentError);
      await expectLater(
        WaffraSqlcipherHistoryPager.load(
          store: db, accountId: 'missing-bank'), throwsStateError);
      await expectLater(
        WaffraSqlcipherHistoryPager.load(
          store: db, monthIso: '2026-13'), throwsArgumentError);
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_entries')
        .getSingle()).read<int>('n'), countBefore);
      expect(await accounts.balances(), hasLength(balancesBefore.length));
      expect(
        (await accounts.balances()).map((a) => a.balanceMinor).toList(),
        balancesBefore.map((a) => a.balanceMinor).toList());

      await db.close();
      db = null;
      db = WaffraEncryptedStore.openAt(path, key: key);
      final reopened = await WaffraSqlcipherHistoryPager.load(
        store: db, limit: 43);
      expect(reopened.entries.map((e) => e.id).toList(),
          expected.take(43).toList());
    } finally {
      await db?.close();
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

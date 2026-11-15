import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_account_context_read.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

/// M952 axes 1/2/3: a disposable encrypted many-goal fixture proves the
/// grouped contribution read is identical to the prior per-goal SQL policy.
/// Never use or alter a real user backup, goals, balances, or SMS data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('M952 eighty goal wallets aggregate account contributions without '
      'N per-goal scans or duplicate bank postings', () async {
    final dir = await Directory.systemTemp.createTemp('m952-goal-scale-');
    WaffraEncryptedStore? db;
    try {
      db = WaffraEncryptedStore.openAt(
        File('${dir.path}/vault.sqlite'),
        key: 'm952-disposable-goal-contribution-parity-key',
      );
      await WaffraFreshEncryptedVaultBootstrap(
        store: db, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      await WaffraAccountsSchema.install(db);
      final accounts = WaffraAccountsRepository(
        db: db, experimentalEnabled: true);
      for (final id in const ['bank-a', 'bank-b']) {
        await accounts.createAccount(
          id: id, name: id, kind: 'bank', openingMinor: 750000,
          createdIso: '2026-11-15T00:00:00', userConfirmed: true);
      }
      const stamp = '2026-11-15T10:00:00';
      const totalGoals = 80, movementsPerGoal = 9;
      await db.transaction(() async {
        for (var i = 0; i < totalGoals; i++) {
          final goal = 'goal-${i.toString().padLeft(3, '0')}';
          await db!.customStatement(
            'INSERT INTO fresh_finance_goals '
            '(goal_id,name,target_minor,saved_minor,source_json) '
            'VALUES (?,?,?,?,?)',
            [goal, 'Savings $goal', 400000, 100000+i, '{}']);
          for (var j = 0; j < movementsPerGoal; j++) {
            final movement = '$goal-movement-$j';
            final kind = j == 8 ? 'due_debit' :
              (j % 3 == 0 ? 'release' : 'fund');
            final amount = 100+i*3+j;
            await db!.customStatement(
              'INSERT INTO fresh_finance_goal_wallet_movements '
              '(movement_id,goal_id,kind,amount_minor,idempotency_key,'
              'occurred_at_iso) VALUES (?,?,?,?,?,?)',
              [movement, goal, kind, amount, movement, stamp]);
            if (kind == 'fund' || kind == 'release') {
              await db!.customStatement(
                'INSERT INTO fresh_finance_goal_account_sources '
                '(movement_id,account_id,linked_iso) VALUES (?,?,?)',
                [movement, j.isEven ? 'bank-a' : 'bank-b', stamp]);
            }
          }
        }
      });

      // Fixture inserts have their own real source-backed bank effects.
      // Snapshot AFTER seeding: the read-only projection must add none.
      final balancesBefore = {
        for (final a in await accounts.balances()) a.id: a.balanceMinor,
      };

      Future<int> originalPerGoal(String id, String bank) async {
        final result = await db!.customSelect('''
SELECT COALESCE(SUM(CASE
 WHEN m.kind='fund' THEN m.amount_minor
 WHEN m.kind='release' THEN -m.amount_minor ELSE 0 END),0) AS own_minor
FROM fresh_finance_goal_account_sources s
JOIN fresh_finance_goal_wallet_movements m ON m.movement_id=s.movement_id
WHERE m.goal_id=? AND s.account_id=?
''', variables: [Variable.withString(id),Variable.withString(bank)])
            .getSingle();
        return result.read<int>('own_minor');
      }
      for (final accountId in ['bank-a', 'bank-b', null]) {
        final summary = await WaffraAccountContextRead.load(
          store: db, monthIso: '2026-11', summaryOnly: true,
          selectedAccountId: accountId);
        expect(summary.goals.length, totalGoals);
        expect(summary.entries, isEmpty);
        expect(summary.budgets, isEmpty);
        final ids = <String>{};
        for (final goal in summary.goals) {
          expect(ids.add(goal.id), isTrue, reason: 'Duplicate goal projection');
          final index = int.parse(goal.id.substring(5));
          expect(goal.totalSavedMinor, 100000+index);
          final expected = accountId == null
              ? 0 : await originalPerGoal(goal.id, accountId);
          expect(goal.selectedAccountNetMinor, expected,
              reason: '${goal.id} / $accountId');
        }
      }
      expect({
        for (final a in await accounts.balances()) a.id: a.balanceMinor,
      }, balancesBefore, reason: 'Goal summaries must not post bank money.');
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_goal_account_sources')
          .getSingle()).read<int>('n'), totalGoals*(movementsPerGoal-1));
      expect((await db.customSelect(
        'SELECT COUNT(*) AS n FROM fresh_finance_goal_wallet_movements')
          .getSingle()).read<int>('n'), totalGoals*movementsPerGoal);
    } finally {
      await db?.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}

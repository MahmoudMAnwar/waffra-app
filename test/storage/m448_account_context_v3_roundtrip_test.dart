import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_account_context_repository.dart';
import 'package:waffra/storage/waffra_accounts_portable_backup_v3.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_portable_encrypted_backup_exporter.dart';

void main() {
  late Directory dir;
  late WaffraEncryptedStore db;
  const password = 'm448-context-verified-portable-password';
  const at = '2026-11-04T12:00:00';

  Future<String> seedAndExport() async {
    await WaffraFreshEncryptedVaultBootstrap(
      store: db, experimentalEnabled: true,
    ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
    await WaffraAtomicFinanceSnapshot(
      store: db, experimentalEnabled: true,
    ).initializeEmpty();
    await WaffraAccountsSchema.install(db);
    final accounts = WaffraAccountsRepository(db: db, experimentalEnabled: true);
    await accounts.createAccount(
      id: 'rajhi', name: 'Bank account', kind: 'bank',
      openingMinor: 100000, createdIso: at, userConfirmed: true,
    );
    await accounts.createAccount(
      id: 'cash', name: 'Cash', kind: 'cash',
      openingMinor: 50000, createdIso: at, userConfirmed: true,
    );
    await db.customStatement(
      'INSERT INTO fresh_finance_goals '
      '(goal_id,name,target_minor,saved_minor,source_json) VALUES (?,?,?,?,?)',
      ['travel', 'Travel', 90000, 30000, '{}'],
    );
    await db.customStatement(
      'INSERT INTO fresh_finance_recurring '
      '(recurring_id,amount_minor,is_income,due_day,source_json) '
      'VALUES (?,?,?,?,?)', ['internet', 10000, 0, 1, '{}'],
    );
    await db.customStatement(
      'INSERT INTO fresh_finance_goal_wallet_movements '
      '(movement_id,goal_id,kind,amount_minor,idempotency_key,occurred_at_iso) '
      'VALUES (?,?,?,?,?,?)',
      ['funding-1', 'travel', 'fund', 30000, 'funding-once', at],
    );
    final context = WaffraAccountContextRepository(
      store: db, experimentalEnabled: true,
    );
    expect(await context.attributeGoalMovement(
      movementId: 'funding-1', accountId: 'rajhi',
      linkedIso: at, userConfirmed: true,
    ), isTrue);
    await context.setRecurringDefault(
      recurringId: 'internet', accountId: 'rajhi',
      changedIso: at, userConfirmed: true,
    );
    await context.setVerifiedBankSuffix(
      accountId: 'rajhi', lastFour: '1234',
      confirmedIso: at, userConfirmed: true,
    );
    return WaffraPortableEncryptedBackupExporter(
      snapshot: WaffraAtomicFinanceSnapshot(
        store: db, experimentalEnabled: true,
      ),
      receiptVault: WaffraEncryptedReceiptVault(
        store: db, experimentalEnabled: true,
      ),
      writerDirectory: dir, verifySourceUnderLock: () async {},
      experimentalEnabled: true,
    ).exportV3(password: password);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('m448-context-v3-');
    db = WaffraEncryptedStore.openAt(
      File('${dir.path}/source.sqlite'),
      key: 'm448-source-sqlcipher-disposable-only-long-key',
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('encrypted V3 restores funded goals, recurring defaults and SMS suffix', () async {
    final encrypted = await seedAndExport();
    expect(encrypted.contains('1234'), isFalse);
    expect(encrypted.contains('Bank account'), isFalse);
    final verified = await WaffraAccountsPortableBackupV3.verifyAndPreview(
      encryptedArchive: encrypted, password: password,
    );
    expect(verified.context, isNotNull);
    expect(verified.context!['goalSources']!.length, 1);
    expect(verified.context!['recurringDefaults']!.length, 1);
    expect(verified.context!['smsSuffixes']!.length, 1);
    expect(verified.history, isNotNull);

    final targetPath = File('${dir.path}/restored.sqlite');
    const targetKey = 'm448-target-sqlcipher-disposable-only-long-key';
    final target = WaffraEncryptedStore.openAt(targetPath, key: targetKey);
    await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
      encryptedArchive: encrypted, password: password,
      disposableStore: target, userConfirmed: true,
      experimentalEnabled: true,
    );
    await target.close();
    final reopened = WaffraEncryptedStore.openAt(targetPath, key: targetKey);
    try {
      final balances = await WaffraAccountsRepository(
        db: reopened, experimentalEnabled: true,
      ).balances();
      expect({for (final a in balances) a.id: a.balanceMinor},
          {'rajhi': 70000, 'cash': 50000});
      final restoredContext = WaffraAccountContextRepository(
        store: reopened, experimentalEnabled: true,
      );
      expect(await restoredContext.recurringDefault('internet'), 'rajhi');
      final progress = await restoredContext.goalProgress(
        goalId: 'travel', selectedAccountId: 'rajhi',
      );
      expect(progress.totalSavedMinor, 30000);
      expect(progress.selectedAccountNetMinor, 30000);
      final captured = await WaffraAccountsPortableBackupV3.capture(reopened);
      expect(captured['contextV1'], verified.context);
    } finally {
      await reopened.close();
    }
  });

  test('forged goal-source reference rolls back the entire restore', () async {
    final encrypted = await seedAndExport();
    final envelope = jsonDecode(
      await WaffraSecureBackup.decrypt(encrypted, password),
    ) as Map<String, dynamic>;
    final context = envelope['accountContextV1'] as Map<String, dynamic>;
    final goalSources = context['goalSources'] as List;
    (goalSources.single as Map<String, dynamic>)['movement_id'] = 'missing-movement';
    final tampered = await WaffraSecureBackup.encrypt(
      jsonEncode(envelope), password,
    );
    final target = WaffraEncryptedStore.openAt(
      File('${dir.path}/rollback.sqlite'),
      key: 'm448-rollback-disposable-only-long-sqlcipher-key',
    );
    try {
      await expectLater(
        WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
          encryptedArchive: tampered, password: password,
          disposableStore: target, userConfirmed: true,
          experimentalEnabled: true,
        ),
        throwsA(isA<Exception>()),
      );
      await WaffraAccountsPortableBackupV3.restoreToEmptyEncryptedVault(
        encryptedArchive: encrypted, password: password,
        disposableStore: target, userConfirmed: true,
        experimentalEnabled: true,
      );
      expect((await target.customSelect(
        'SELECT movement_id FROM fresh_finance_goal_account_sources',
      ).get()).length, 1);
    } finally {
      await target.close();
    }
  });
}

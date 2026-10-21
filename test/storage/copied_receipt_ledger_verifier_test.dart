import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_copied_receipt_ledger_verifier.dart';
import 'package:waffra/storage/waffra_disposable_receipt_copier.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_ledger_projection.dart';
import 'package:waffra/storage/waffra_offline_receipt_path_planner.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';

void main() {
  late Directory root;
  late Directory stageDirectory;
  late Directory copiedDirectory;
  late WaffraEncryptedStore vault;
  const password = 'offline-copied-receipt-ledger-test';

  Map<String, Object?> sample() => {
    'entries': jsonEncode([
      {
        'id': 'expense-1', 'title': 'Cash expense',
        'category': 'Groceries', 'amount': 12.75, 'income': false,
        'date': '2026-10-21T10:00:00',
        'receiptPath': jsonEncode(['/former/picture-1', '/former/picture-2']),
      },
      {
        'id': 'income-1', 'title': 'Salary',
        'category': 'Salary', 'amount': 500.0, 'income': true,
        'date': '2026-10-20T10:00:00', 'receiptPath': null,
      },
    ]),
    'waffra_categories_v24': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_learned_merchants_v1': '{}',
    'waffra_sms_hashes_v1': <String>[],
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_recurring_reminders_enabled_v1': false,
  };

  Future<(WaffraBackupV2Preview, WaffraReceiptRemapPlan)> ready()
      async {
    final archive = await WaffraPortableBackupV2.create(
      financialSnapshot: sample(),
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: 'expense-1', position: 0, bytes: [4, 5, 6]),
        const WaffraReceiptBackupPart(
          entryId: 'expense-1', position: 1, bytes: [7, 8, 9, 10]),
      ],
      password: password,
    );
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: archive, password: password);
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true,
    ).stage(emptySandboxDirectory: stageDirectory, preview: preview);
    final plan = await const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true,
    ).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageDirectory,
      emptyAppPrivateDestination: copiedDirectory,
    );
    await const WaffraDisposableReceiptCopier(
      experimentalEnabled: true,
    ).copy(
      stagingDirectory: stageDirectory,
      emptyDestination: copiedDirectory,
      preview: preview,
      staged: staged,
      plan: plan,
    );
    return (preview, plan);
  }

  WaffraCopiedReceiptLedgerVerifier verifier(bool enabled) =>
      WaffraCopiedReceiptLedgerVerifier(
        disposableStore: vault, experimentalEnabled: enabled);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-ledger-files-');
    stageDirectory = await Directory('${root.path}/staging').create();
    copiedDirectory = await Directory('${root.path}/copied').create();
    vault = WaffraEncryptedStore.openAt(
      File('${root.path}/sandbox.sqlite'),
      key: 'isolated-ledger-receipt-test-key-32',
    );
  });
  tearDown(() async {
    await vault.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('stages remapped ledger with matching copies, totals and SQL file rows',
      () async {
    final (preview, plan) = await ready();
    final report = await verifier(true).verifyAndStage(
      disposableVaultId: 'disposable-only',
      preview: preview,
      plan: plan,
      copiedReceiptDirectory: copiedDirectory,
    );
    expect(report.ledgerEntries, 2);
    expect(report.receiptCount, 2);
    expect(report.incomeMinor, 50000);
    expect(report.expenseMinor, 1275);
    final sourceJson = await vault.readOriginalEntryJson('disposable-only');
    expect(sourceJson, hasLength(2));
    expect(sourceJson.first, contains(copiedDirectory.path));
    expect(sourceJson.first, isNot(contains('/former/picture')));
    expect(await copiedDirectory.list().toList(), hasLength(2));
  });

  test('disabled by default, keeps empty vault', () async {
    final (preview, plan) = await ready();
    await expectLater(verifier(false).verifyAndStage(
      disposableVaultId: 'disposable-only', preview: preview,
      plan: plan, copiedReceiptDirectory: copiedDirectory),
      throwsA(isA<StateError>()));
    expect(await copiedDirectory.list().toList(), hasLength(2));
  });

  test('tampered copied bytes prevent staging', () async {
    final (preview, plan) = await ready();
    final copied = await copiedDirectory.list().toList();
    await File(copied.first.path).writeAsBytes([1, 1, 1]);
    await expectLater(verifier(true).verifyAndStage(
      disposableVaultId: 'disposable-only', preview: preview,
      plan: plan, copiedReceiptDirectory: copiedDirectory),
      throwsA(isA<StateError>()));
  });

  test('forged path mapping rejected', () async {
    final (preview, plan) = await ready();
    final forged = WaffraReceiptRemapPlan(
      remappedSnapshot: {...plan.remappedSnapshot, 'entries': '[]'},
      entryCount: plan.entryCount,
      receiptCount: plan.receiptCount,
      sourceChecksum: plan.sourceChecksum,
    );
    await expectLater(verifier(true).verifyAndStage(
      disposableVaultId: 'disposable-only', preview: preview,
      plan: forged, copiedReceiptDirectory: copiedDirectory),
      throwsA(isA<StateError>()));
  });

  test('extra files block staging', () async {
    final (preview, plan) = await ready();
    final extra = File('${copiedDirectory.path}/extraneous');
    await extra.writeAsBytes([99]);
    await expectLater(verifier(true).verifyAndStage(
      disposableVaultId: 'disposable-only', preview: preview,
      plan: plan, copiedReceiptDirectory: copiedDirectory),
      throwsA(isA<StateError>()));
    expect(await extra.readAsBytes(), [99]);
  });

  test('invalid vault name blocked before database import', () async {
    final (preview, plan) = await ready();
    await expectLater(verifier(true).verifyAndStage(
      disposableVaultId: '../active-vault', preview: preview,
      plan: plan, copiedReceiptDirectory: copiedDirectory),
      throwsA(isA<ArgumentError>()));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_disposable_receipt_copier.dart';
import 'package:waffra/storage/waffra_offline_receipt_path_planner.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';

void main() {
  const password = 'disposable-testing-password-only';
  late Directory root;
  late Directory staging;
  late Directory destination;

  Map<String, Object?> snapshot() => {
    'entries': jsonEncode([
      {
        'id': '../hostile/id', 'title': 'Test purchase',
        'category': 'Shopping', 'amount': 12.75,
        'income': false, 'date': '2026-10-21T09:00:00',
        'receiptPath': jsonEncode(['/previous/receipt1', '/previous/receipt2']),
      },
      {
        'id': 'income1', 'title': 'Income',
        'category': 'Salary', 'amount': 150.0,
        'income': true, 'date': '2026-10-20T09:00:00',
        'receiptPath': null,
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

  Future<(WaffraBackupV2Preview, WaffraReceiptSandboxResult,
      WaffraReceiptRemapPlan)> prepared() async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: snapshot(),
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: '../hostile/id', position: 0, bytes: [1, 2, 3]),
        const WaffraReceiptBackupPart(
          entryId: '../hostile/id', position: 1, bytes: [4, 5, 6, 7]),
      ], password: password,
    );
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: password);
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
      emptySandboxDirectory: staging, preview: preview);
    final plan = await const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true).plan(
      verifiedPreview: preview, stagedReceipts: staged,
      receiptSandboxDirectory: staging,
      emptyAppPrivateDestination: destination,
    );
    return (preview, staged, plan);
  }

  WaffraDisposableReceiptCopier get copier =>
      const WaffraDisposableReceiptCopier(experimentalEnabled: true);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-disposable-copy-');
    staging = await Directory('${root.path}/staging').create();
    destination = await Directory('${root.path}/destination').create();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copies both receipts byte-for-byte and leaves stage files intact',
      () async {
    final (preview, staged, plan) = await prepared();
    final result = await copier.copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: plan);
    expect(result.fileCount, 2);
    expect(result.totalBytes, 7);
    final names = staged.sandboxRelativePaths['../hostile/id']!;
    expect(await File('${destination.path}/${names.first}').readAsBytes(),
        [1, 2, 3]);
    expect(await File('${destination.path}/${names.last}').readAsBytes(),
        [4, 5, 6, 7]);
    expect(await File('${staging.path}/${names.first}').readAsBytes(),
        [1, 2, 3]);
    expect(await destination.list().toList(), hasLength(2));
  });

  test('feature is disabled by default; no file writes', () async {
    final (preview, staged, plan) = await prepared();
    await expectLater(const WaffraDisposableReceiptCopier().copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: plan),
      throwsA(isA<StateError>()));
    expect(await destination.list().toList(), isEmpty);
  });

  test('fault after first copy cleans created destination files', () async {
    final (preview, staged, plan) = await prepared();
    await expectLater(copier.copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: plan,
      failAfterCopiesForTest: 1),
      throwsA(isA<StateError>()));
    expect(await destination.list().toList(), isEmpty);
    expect(await staging.list().toList(), hasLength(2));
  });

  test('staging tamper blocks any destination change', () async {
    final (preview, staged, plan) = await prepared();
    final name = staged.sandboxRelativePaths['../hostile/id']!.first;
    await File('${staging.path}/$name').writeAsBytes([100, 101]);
    await expectLater(copier.copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: plan),
      throwsA(isA<StateError>()));
    expect(await destination.list().toList(), isEmpty);
  });

  test('forged planned destinations never get installed', () async {
    final (preview, staged, plan) = await prepared();
    final fake = WaffraReceiptRemapPlan(
      remappedSnapshot: {...plan.remappedSnapshot, 'entries': '[]'},
      entryCount: 2, receiptCount: 2, sourceChecksum: plan.sourceChecksum);
    await expectLater(copier.copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: fake),
      throwsA(isA<StateError>()));
    expect(await destination.list().toList(), isEmpty);
  });

  test('refuses preexisting files without modifying them', () async {
    final (preview, staged, plan) = await prepared();
    final file = File('${destination.path}/existing-file');
    await file.writeAsBytes([8, 9]);
    await expectLater(copier.copy(
      stagingDirectory: staging, emptyDestination: destination,
      preview: preview, staged: staged, plan: plan),
      throwsA(isA<StateError>()));
    expect(await file.readAsBytes(), [8, 9]);
  });

  test('refuses identical staging and destination', () async {
    final (preview, staged, plan) = await prepared();
    await expectLater(copier.copy(
      stagingDirectory: staging, emptyDestination: staging,
      preview: preview, staged: staged, plan: plan),
      throwsA(isA<StateError>()));
  });
}

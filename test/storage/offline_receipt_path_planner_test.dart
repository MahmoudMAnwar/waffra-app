import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_offline_receipt_path_planner.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';

void main() {
  const password = 'only-for-isolated-receipt-path-test';
  late Directory root;
  late Directory stageFolder;
  late Directory targetFolder;

  Map<String, Object?> financialSnapshot() => {
    'entries': jsonEncode([
      {
        'id': '../untrusted-entry', 'title': 'Test purchase',
        'category': 'Shopping', 'amount': 19.25,
        'income': false, 'date': '2026-10-21T13:00:00',
        'receiptPath': jsonEncode([
          '/old/mobile/one.jpg', '/old/mobile/two.png',
        ]),
      },
      {
        'id': 'income-1', 'title': 'Test income',
        'category': 'Salary', 'amount': 200.0,
        'income': true, 'date': '2026-10-20T13:00:00',
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

  Future<(WaffraBackupV2Preview, WaffraReceiptSandboxResult)> prepare()
      async {
    final archive = await WaffraPortableBackupV2.create(
      financialSnapshot: financialSnapshot(),
      receipts: [
        const WaffraReceiptBackupPart(
          entryId: '../untrusted-entry', position: 0,
          bytes: [10, 11, 12]),
        const WaffraReceiptBackupPart(
          entryId: '../untrusted-entry', position: 1,
          bytes: [13, 14, 15]),
      ],
      password: password,
    );
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: archive, password: password);
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
      emptySandboxDirectory: stageFolder, preview: preview);
    return (preview, staged);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('receipt-remap-');
    stageFolder = await Directory('${root.path}/stage').create();
    targetFolder = await Directory('${root.path}/new-private').create();
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('copies financial snapshot and preserves totals and receipt order',
      () async {
    final (preview, staged) = await prepare();
    final originalJson = preview.financialSnapshot['entries'];
    final plan = await const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageFolder,
      emptyAppPrivateDestination: targetFolder,
    );

    expect(plan.entryCount, 2);
    expect(plan.receiptCount, 2);
    expect(plan.sourceChecksum, preview.sourceChecksum);
    expect(plan.redactedDiagnostics['files_written'], isFalse);
    final rows =
        jsonDecode(plan.remappedSnapshot['entries']! as String) as List;
    final expense = rows.first as Map<String, dynamic>;
    final income = rows.last as Map<String, dynamic>;
    final paths = (jsonDecode(expense['receiptPath'] as String) as List)
        .cast<String>();
    expect(paths.length, 2);
    expect(paths.every((p) => p.startsWith('${targetFolder.path}/')), isTrue);
    expect(paths.every((p) => p.endsWith('.bin')), isTrue);
    expect(paths.first, isNot(paths.last));
    expect(expense['amount'], 19.25);
    expect(expense['date'], '2026-10-21T13:00:00');
    expect(income['amount'], 200.0);
    expect(income['receiptPath'], isNull);
    expect(preview.financialSnapshot['entries'], originalJson);
    expect(await targetFolder.list().toList(), isEmpty);
  });

  test('default disabled mode refuses remapping', () async {
    final (preview, staged) = await prepare();
    await expectLater(const WaffraOfflineReceiptPathPlanner().plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageFolder,
      emptyAppPrivateDestination: targetFolder,
    ), throwsA(isA<StateError>()));
    expect(await targetFolder.list().toList(), isEmpty);
  });

  test('tampered staged receipt cannot create path plan', () async {
    final (preview, staged) = await prepare();
    final name = staged.sandboxRelativePaths['../untrusted-entry']!.first;
    await File('${stageFolder.path}/$name').writeAsBytes([99, 98]);
    await expectLater(const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageFolder,
      emptyAppPrivateDestination: targetFolder,
    ), throwsA(isA<StateError>()));
    expect(await targetFolder.list().toList(), isEmpty);
  });

  test('never overwrites existing destination contents', () async {
    final (preview, staged) = await prepare();
    final existing = File('${targetFolder.path}/do-not-touch');
    await existing.writeAsBytes([1, 2, 3]);
    await expectLater(const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageFolder,
      emptyAppPrivateDestination: targetFolder,
    ), throwsA(isA<StateError>()));
    expect(await existing.readAsBytes(), [1, 2, 3]);
  });

  test('staging directory cannot also be final private destination',
      () async {
    final (preview, staged) = await prepare();
    await expectLater(const WaffraOfflineReceiptPathPlanner(
      experimentalEnabled: true).plan(
      verifiedPreview: preview,
      stagedReceipts: staged,
      receiptSandboxDirectory: stageFolder,
      emptyAppPrivateDestination: stageFolder,
    ), throwsA(isA<StateError>()));
  });
}

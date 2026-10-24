import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';
import 'package:waffra/storage/waffra_receipt_sandbox_auditor.dart';

void main() {
  late Directory sandbox;
  setUp(() async => sandbox = await Directory.systemTemp.createTemp('audit-'));
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<(WaffraBackupV2Preview, WaffraReceiptSandboxResult)> stage() async {
    final snapshot = <String, Object?>{
      'entries': jsonEncode([
        {
          'id': 'entry1', 'title': 'Receipt', 'category': 'Food',
          'amount': 15, 'income': false, 'date': '2026-10-21T08:00:00',
          'receiptPath': jsonEncode(['/former/device/image.png'])
        }
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
    const part = WaffraReceiptBackupPart(
      entryId: 'entry1', position: 0, bytes: [1, 2, 3, 4]);
    final archive = await WaffraPortableBackupV2.create(
      financialSnapshot: snapshot, receipts: [part],
      password: 'Long strong archive passphrase');
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: archive, password: 'Long strong archive passphrase');
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
      emptySandboxDirectory: sandbox, preview: preview);
    return (preview, staged);
  }

  test('valid staged archive passes independent read-only audit', () async {
    final (preview, staged) = await stage();
    expect((await const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true).verify(
      sandboxDirectory: sandbox, preview: preview, staged: staged))
        .restoredBytes, 4);
  });

  test('audit is default-deny', () async {
    final (preview, staged) = await stage();
    await expectLater(const WaffraReceiptSandboxAuditor().verify(
      sandboxDirectory: sandbox, preview: preview, staged: staged),
      throwsA(isA<StateError>()));
  });

  test('tampered receipt bytes are detected', () async {
    final (preview, staged) = await stage();
    final name = staged.sandboxRelativePaths['entry1']!.single;
    await File('${sandbox.path}/$name').writeAsBytes([1, 2, 3, 5]);
    await expectLater(const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true).verify(
      sandboxDirectory: sandbox, preview: preview, staged: staged),
      throwsA(isA<StateError>()));
  });

  test('unknown extra file fails the audit', () async {
    final (preview, staged) = await stage();
    await File('${sandbox.path}/extra').writeAsBytes([9]);
    await expectLater(const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true).verify(
      sandboxDirectory: sandbox, preview: preview, staged: staged),
      throwsA(isA<StateError>()));
  });

  test('missing receipt is rejected', () async {
    final (preview, staged) = await stage();
    await File('${sandbox.path}/${staged.sandboxRelativePaths['entry1']!.single}')
        .delete();
    await expectLater(const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true).verify(
      sandboxDirectory: sandbox, preview: preview, staged: staged),
      throwsA(isA<StateError>()));
  });

  test('forged filename mapping is rejected', () async {
    final (preview, staged) = await stage();
    final forged = WaffraReceiptSandboxResult(
      sandboxRelativePaths: {'entry1': ['../outside.bin']},
      restoredBytes: staged.restoredBytes);
    await expectLater(const WaffraReceiptSandboxAuditor(
      experimentalEnabled: true).verify(
      sandboxDirectory: sandbox, preview: preview, staged: forged),
      throwsA(isA<StateError>()));
  });
}

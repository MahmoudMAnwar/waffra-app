import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/storage/waffra_receipt_restore_sandbox.dart';

void main() {
  const password = 'Long strong archive passphrase';
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-receipts-');
  });
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Map<String, Object?> snapshot() => {
    'entries': jsonEncode([
      {
        'id': '../unsafe/entry', 'title': 'إيصال تجربة',
        'category': 'طعام', 'amount': 10.25, 'income': false,
        'date': '2026-10-21T08:00:00',
        'receiptPath': jsonEncode([
          '/old/phone/private-one.jpg', '/old/phone/private-two.png',
        ]),
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

  List<WaffraReceiptBackupPart> receipts() => const [
    WaffraReceiptBackupPart(
      entryId: '../unsafe/entry', position: 0, bytes: [1, 2, 3, 4],
    ),
    WaffraReceiptBackupPart(
      entryId: '../unsafe/entry', position: 1, bytes: [5, 6, 7, 8, 9],
    ),
  ];

  Future<WaffraBackupV2Preview> preview() async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: snapshot(),
      receipts: receipts(),
      password: password,
    );
    return WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted,
      password: password,
    );
  }

  test('authenticated receipt bytes restore only under disposable folder',
      () async {
    final valid = await preview();
    final staged = await const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
        emptySandboxDirectory: sandbox, preview: valid);
    expect(staged.restoredFiles, 2);
    expect(staged.restoredBytes, 9);
    final names = staged.sandboxRelativePaths['../unsafe/entry']!;
    expect(names, hasLength(2));
    expect(names.toSet(), hasLength(2));
    for (var i = 0; i < names.length; i++) {
      expect(names[i], matches(RegExp(r'^[a-f0-9]{64}\.bin$')));
      expect(names[i], isNot(contains('unsafe')));
      expect(await File(sandbox.path + '/' + names[i]).readAsBytes(),
          receipts()[i].bytes);
    }
    expect((await sandbox.list().toList()).length, 2);
    expect(staged.sandboxRelativePaths.toString(),
        isNot(contains('/old/phone/')));
  });

  test('disabled/default mode does not write receipt files', () async {
    await expectLater(const WaffraReceiptSandboxStager().stage(
      emptySandboxDirectory: sandbox, preview: await preview()),
      throwsA(isA<StateError>()));
    expect(await sandbox.list().toList(), isEmpty);
  });

  test('nonempty sandbox never overwrites existing files', () async {
    final untouched = File(sandbox.path + '/user-file.bin');
    await untouched.writeAsBytes([99]);
    await expectLater(const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
        emptySandboxDirectory: sandbox, preview: await preview()),
      throwsA(isA<StateError>()));
    expect(await untouched.readAsBytes(), [99]);
  });

  test('invalid or duplicate receipts are rejected before first disk write',
      () async {
    final good = await preview();
    final malicious = WaffraBackupV2Preview(
      financialSnapshot: good.financialSnapshot,
      sourceChecksum: good.sourceChecksum,
      receipts: [
        good.receipts.first, good.receipts.first,
      ],
    );
    await expectLater(const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
        emptySandboxDirectory: sandbox, preview: malicious),
      throwsA(isA<StateError>()));
    expect(await sandbox.list().toList(), isEmpty);
  });

  test('invalid source checksum prevents any restore writes', () async {
    final good = await preview();
    final altered = WaffraBackupV2Preview(
      financialSnapshot: good.financialSnapshot,
      sourceChecksum: '0' * 64,
      receipts: good.receipts,
    );
    await expectLater(const WaffraReceiptSandboxStager(
      experimentalEnabled: true).stage(
        emptySandboxDirectory: sandbox, preview: altered),
      throwsA(isA<StateError>()));
    expect(await sandbox.list().toList(), isEmpty);
  });
}

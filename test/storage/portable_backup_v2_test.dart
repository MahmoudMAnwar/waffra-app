import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  const password = 'Strong archive password 2026';
  Map<String, Object?> fixture() => {
    'entries': jsonEncode([
      {
        'id': 'transaction-one',
        'title': 'مشتريات خاصة',
        'category': 'مواد غذائية',
        'amount': 25.75,
        'income': false,
        'date': '2026-10-21T12:00:00',
        'receiptPath': jsonEncode(['/private/r1.jpg', '/private/r2.png']),
      },
      {
        'id': 'transaction-two',
        'title': 'راتب',
        'category': 'دخل',
        'amount': 5000.0,
        'income': true,
        'date': '2026-10-20T07:00:00',
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
    'waffra_sms_hashes_v1': <String>['some-hash'],
    'waffra_monthly_budget_v1': 2000.0,
    'waffra_monthly_budget_enabled_v1': true,
    'waffra_recurring_reminders_enabled_v1': false,
    'waffra_custom_goals_v1': <String>['شراء منزل'],
  };

  List<WaffraReceiptBackupPart> sampleReceipts() => [
    WaffraReceiptBackupPart(
      entryId: 'transaction-one', position: 0,
      bytes: [0xFF, 0xD8, 0xFF, 0x01, 0x32],
    ),
    WaffraReceiptBackupPart(
      entryId: 'transaction-one', position: 1,
      bytes: [0x89, 0x50, 0x4E, 0x47, 0x00],
    ),
  ];

  test('encrypted portable archive restores exact finance and receipt bytes',
      () async {
    final source = fixture();
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: source,
      receipts: sampleReceipts(),
      password: password,
    );
    expect(encrypted, contains('waffra-secure-backup'));
    expect(encrypted, isNot(contains('مشتريات خاصة')));
    expect(encrypted, isNot(contains('/private/r1.jpg')));
    expect(encrypted, isNot(contains('some-hash')));
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: password);
    expect(preview.receiptCount, 2);
    expect(preview.financialSnapshot['entries'], source['entries']);
    expect(preview.financialSnapshot['waffra_sms_hashes_v1'],
        ['some-hash']);
    expect(preview.financialSnapshot['waffra_custom_goals_v1'],
        ['شراء منزل']);
    expect(preview.receipts[0].bytes, sampleReceipts()[0].bytes);
    expect(preview.receipts[1].bytes, sampleReceipts()[1].bytes);
    expect(preview.sourceChecksum, hasLength(64));
  });

  test('password failure and unencrypted old backup always fail closed',
      () async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: fixture(),
      receipts: sampleReceipts(),
      password: password);
    await expectLater(
      WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: encrypted, password: 'wrong password'),
      throwsA(anything),
    );
    await expectLater(
      WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: jsonEncode({'format': 'waffra-backup'}),
        password: password),
      throwsA(isA<FormatException>()),
    );
  });

  test('missing, duplicate and invented receipt associations block export',
      () async {
    await expectLater(WaffraPortableBackupV2.create(
      financialSnapshot: fixture(),
      receipts: [sampleReceipts().first], password: password),
      throwsA(isA<StateError>()));
    await expectLater(WaffraPortableBackupV2.create(
      financialSnapshot: fixture(),
      receipts: [
        sampleReceipts().first,
        sampleReceipts().first,
      ], password: password),
      throwsA(isA<StateError>()));
    await expectLater(WaffraPortableBackupV2.create(
      financialSnapshot: fixture(),
      receipts: [
        sampleReceipts().first,
        WaffraReceiptBackupPart(
          entryId: 'non-existent', position: 1, bytes: [1]),
      ], password: password),
      throwsA(isA<StateError>()));
  });

  test('secret financial fields cannot enter an encrypted portable archive',
      () async {
    final source = fixture()..['waffra_local_password_hash'] = 'secret';
    await expectLater(WaffraPortableBackupV2.create(
      financialSnapshot: source,
      receipts: sampleReceipts(), password: password),
      throwsA(isA<StateError>()));

    final entries = jsonDecode(fixture()['entries']! as String) as List;
    (entries.first as Map)['bankAccount'] = '123456';
    final changed = fixture()..['entries'] = jsonEncode(entries);
    await expectLater(WaffraPortableBackupV2.create(
      financialSnapshot: changed,
      receipts: sampleReceipts(), password: password),
      throwsA(isA<StateError>()));
  });

  test('receipt checksum and archive snapshot digest are strictly verified',
      () async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: fixture(),
      receipts: sampleReceipts(), password: password);
    final clear = await WaffraSecureBackup.decrypt(encrypted, password);
    final archive = jsonDecode(clear) as Map<String, dynamic>;
    final receipts = archive['receipts'] as List;
    (receipts.first as Map)['sha256'] = '0' * 64;
    final malformed = await WaffraSecureBackup.encrypt(
      jsonEncode(archive), password);
    await expectLater(
      WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: malformed, password: password),
      throwsA(isA<StateError>()),
    );

    archive['sourceChecksum'] = 'tampered';
    final changed = await WaffraSecureBackup.encrypt(
      jsonEncode(archive), password);
    await expectLater(
      WaffraPortableBackupV2.verifyAndPreview(
        encryptedArchive: changed, password: password),
      throwsA(isA<StateError>()),
    );
  });

  test('zero receipt financial exports are allowed without fake files',
      () async {
    final source = fixture();
    final entries = jsonDecode(source['entries']! as String) as List;
    (entries.first as Map)['receiptPath'] = null;
    source['entries'] = jsonEncode(entries);
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: source, receipts: [], password: password);
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: password);
    expect(preview.receipts, isEmpty);
    expect(preview.financialSnapshot['entries'], source['entries']);
  });
}

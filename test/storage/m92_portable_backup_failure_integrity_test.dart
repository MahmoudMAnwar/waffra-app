import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_portable_backup_v2.dart';
import 'package:waffra/waffra_secure_backup.dart';

/// M92 synthetic password-encrypted archive safety, no real backup data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const passphrase = 'm92 disposable synthetic strong password';

  Map<String, Object?> finance() => {
    'entries': jsonEncode([
      {
        'id': 'm92-entry-1',
        'title': 'Synthetic receipt',
        'category': 'أخرى',
        'amount': 12.50,
        'income': false,
        'date': '2026-10-22T12:00:00',
        'receiptPath': '/device-private/photo.jpg',
      },
    ]),
    'waffra_goals_v24': '[]',
    'waffra_sms_hashes_v1': <String>['m92-dedupe-fingerprint'],
  };

  WaffraReceiptBackupPart photo({
    String id = 'm92-entry-1', int position = 0,
  }) => WaffraReceiptBackupPart(
    entryId: id, position: position, bytes: [255, 216, 1, 2, 3],
  );

  test('M92 encrypted archive never leaks sensitive descriptions or local paths',
      () async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: finance(), receipts: [photo()], password: passphrase,
    );
    expect(encrypted, isNot(contains('Synthetic receipt')));
    expect(encrypted, isNot(contains('/device-private/photo.jpg')));
    expect(encrypted, isNot(contains('m92-dedupe-fingerprint')));
    final preview = await WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: passphrase,
    );
    expect(preview.receiptCount, 1);
    expect(preview.receipts.single.bytes, [255, 216, 1, 2, 3]);
    expect(preview.sourceChecksum, hasLength(64));
  });

  test('M92 zero or duplicate or another-entry receipt cannot enter backup',
      () async {
    for (final parts in [
      <WaffraReceiptBackupPart>[],
      [photo(), photo()],
      [photo(id: 'nonexistent')],
      [photo(position: 1)],
    ]) {
      await expectLater(WaffraPortableBackupV2.create(
        financialSnapshot: finance(), receipts: parts, password: passphrase,
      ), throwsA(isA<StateError>()));
    }
  });

  test('M92 wrong password and clear JSON format never pass authentication',
      () async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: finance(), receipts: [photo()], password: passphrase,
    );
    await expectLater(WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: encrypted, password: 'incorrect',
    ), throwsA(anything));
    await expectLater(WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: jsonEncode({
        'format': 'waffra-portable-finance', 'version': 2,
      }), password: passphrase,
    ), throwsA(isA<FormatException>()));
  });

  test('M92 re-encrypting a forged receipt hash still fails integrity checks',
      () async {
    final encrypted = await WaffraPortableBackupV2.create(
      financialSnapshot: finance(), receipts: [photo()], password: passphrase,
    );
    final decoded = jsonDecode(
      await WaffraSecureBackup.decrypt(encrypted, passphrase),
    ) as Map<String, dynamic>;
    final photos = decoded['receipts'] as List;
    (photos.single as Map<String, dynamic>)['sha256'] = '0' * 64;
    final altered = await WaffraSecureBackup.encrypt(
      jsonEncode(decoded), passphrase,
    );
    await expectLater(WaffraPortableBackupV2.verifyAndPreview(
      encryptedArchive: altered, password: passphrase,
    ), throwsA(isA<StateError>()));
  });

  test('M92 forbidden banking and authentication fields never enter archive',
      () async {
    for (final field in ['rawSms', 'iban', 'bankAccount', 'accessToken']) {
      final original = finance();
      final items = jsonDecode(original['entries'] as String) as List;
      (items.single as Map)[field] = 'not allowed';
      original['entries'] = jsonEncode(items);
      await expectLater(WaffraPortableBackupV2.create(
        financialSnapshot: original, receipts: [photo()], password: passphrase,
      ), throwsA(isA<StateError>()), reason: field);
    }
  });
}

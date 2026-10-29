import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';

/// M279 uses only invented records and passwords. No real device data, SMS,
/// phone identifiers, network connections or live Firebase project is accessed.
void main() {
  const password = 'M279!Synthetic-Backup-Passphrase-Only';
  const sensitive = '{"entries":[{"id":"qa-expense",'
      '"title":"PRIVATE_SYNTHETIC_MERCHANT_QA","amount":1234.56}],'
      '"bankNote":"PRIVATE_SYNTHETIC_BANK_MESSAGE_QA"}';

  test('M279 new exports require a long passphrase and authenticated V2', () async {
    expect(WaffraSecureBackup.isValidNewPassword('12345678'), isFalse);
    expect(WaffraSecureBackup.isValidNewPassword('12345678901'), isFalse);
    expect(WaffraSecureBackup.isValidNewPassword(password), isTrue);
    await expectLater(
      WaffraSecureBackup.encryptUserBackup(sensitive, '12345678'),
      throwsFormatException,
    );
    final archive = await WaffraSecureBackup.encryptUserBackup(
        sensitive, password);
    final header = Map<String, dynamic>.from(jsonDecode(archive) as Map);
    expect(header['version'], 2);
    expect(header['kdf'], 'argon2id');
    expect(header['cipher'], 'aes-256-gcm');
    expect(WaffraSecureBackup.hasValidEncryptedHeader(archive), isTrue);
    expect(archive, isNot(contains('PRIVATE_SYNTHETIC_MERCHANT_QA')));
    expect(archive, isNot(contains('PRIVATE_SYNTHETIC_BANK_MESSAGE_QA')));
    expect(archive, isNot(contains(password)));
    expect(await WaffraSecureBackup.decrypt(archive, password), sensitive);
  });

  test('M279 wrong backup password cannot produce plaintext', () async {
    final archive = await WaffraSecureBackup.encryptUserBackup(
        sensitive, password);
    await expectLater(
      WaffraSecureBackup.decrypt(
          archive, 'M279!Wrong-Password-Never-Authorizes'),
      throwsA(anything),
    );
  });

  test('M279 authenticated backup MAC tampering is rejected', () async {
    final archive = await WaffraSecureBackup.encryptUserBackup(
        sensitive, password);
    final fields = Map<String, dynamic>.from(jsonDecode(archive) as Map);
    final tampered = base64Decode(fields['mac'] as String);
    tampered[0] ^= 0x01;
    fields['mac'] = base64Encode(tampered);
    expect(WaffraSecureBackup.hasValidEncryptedHeader(
        jsonEncode(fields)), isTrue,
        reason: 'A plausible header is not proof of authenticated plaintext');
    await expectLater(
      WaffraSecureBackup.decrypt(jsonEncode(fields), password),
      throwsA(anything),
    );
  });

  test('M279 invalid version, KDF and nonce sizes are rejected', () async {
    final archive = await WaffraSecureBackup.encryptUserBackup(
        sensitive, password);
    final original = Map<String, dynamic>.from(jsonDecode(archive) as Map);
    for (final change in <Map<String, dynamic>>[
      {'version': 987},
      {'kdf': 'pbkdf2-sha256'},
      {'nonce': base64Encode([1, 2, 3])},
      {'cipher': 'none'},
    ]) {
      final forged = jsonEncode({...original, ...change});
      expect(WaffraSecureBackup.hasValidEncryptedHeader(forged), isFalse);
      await expectLater(
          WaffraSecureBackup.decrypt(forged, password),
          throwsA(anything));
    }
  });

  test('M279 separate user backups use independent random salt and nonce',
      () async {
    final first = Map<String, dynamic>.from(jsonDecode(
      await WaffraSecureBackup.encryptUserBackup(sensitive, password)) as Map);
    final second = Map<String, dynamic>.from(jsonDecode(
      await WaffraSecureBackup.encryptUserBackup(sensitive, password)) as Map);
    expect(first['salt'], isNot(second['salt']));
    expect(first['nonce'], isNot(second['nonce']));
    expect(first['data'], isNot(second['data']));
  });

  test('M279 cloud payload hides private fields and rejects forbidden keys',
      () async {
    final cipher = WaffraCloudCipher();
    final key = await cipher.newRandomVaultKey();
    final record = await cipher.encrypt(
      vaultKey: key, vaultId: 'qa-vault', kind: 'entry',
      recordId: 'qa-expense', deviceId: 'qa-device',
      mutationId: 'qa-mutation', localVersion: 1,
      record: {
        'id': 'qa-expense',
        'title': 'PRIVATE_SYNTHETIC_MERCHANT_QA',
        'amount': 1234.56,
        'income': false,
        'category': 'qa-expense-category',
        'date': '2026-10-27T00:00:00',
        'receiptPath': '/private/qa-receipt.jpeg',
      },
    );
    final serialized = jsonEncode(record.toFirestoreDocument());
    for (final leak in [
      'PRIVATE_SYNTHETIC_MERCHANT_QA',
      '1234.56',
      '/private/qa-receipt.jpeg',
      'qa-expense-category',
    ]) {
      expect(serialized, isNot(contains(leak)));
    }
    final actual = await cipher.decrypt(
        vaultKey: key, vaultId: 'qa-vault', envelope: record);
    expect(actual['title'], 'PRIVATE_SYNTHETIC_MERCHANT_QA');
    expect(actual.containsKey('receiptPath'), isFalse);

    for (final forbidden in ['rawSms', 'iban', 'accessToken', 'pin', 'bankAccount']) {
      await expectLater(cipher.encrypt(
        vaultKey: key, vaultId: 'qa-vault', kind: 'entry',
        recordId: 'qa-expense', deviceId: 'qa-device',
        mutationId: 'qa-mutation', localVersion: 1,
        record: {
          'id': 'qa-expense',
          forbidden: 'PRIVATE_SYNTHETIC_BANK_MESSAGE_QA',
        },
      ), throwsStateError);
    }
  });

  test('M279 cloud authenticated metadata and ciphertext cannot be replayed',
      () async {
    final cipher = WaffraCloudCipher();
    final key = await cipher.newRandomVaultKey();
    final other = await cipher.newRandomVaultKey();
    final record = await cipher.encrypt(
      vaultKey: key, vaultId: 'qa-vault', kind: 'goal',
      recordId: 'qa-goal', deviceId: 'qa-device',
      mutationId: 'qa-mutation', localVersion: 1,
      record: {'id': 'qa-goal', 'name': 'Synthetic fund',
        'target': 4500.0, 'saved': 100.0},
    );
    await expectLater(cipher.decrypt(vaultKey: other,
        vaultId: 'qa-vault', envelope: record), throwsA(anything));
    await expectLater(cipher.decrypt(vaultKey: key,
        vaultId: 'other-vault', envelope: record), throwsA(anything));
    for (final changed in [
      record.copyWith(recordId: 'other-goal'),
      record.copyWith(mutationId: 'replayed-mutation'),
      record.copyWith(localVersion: 2),
    ]) {
      await expectLater(
        cipher.decrypt(vaultKey: key, vaultId: 'qa-vault',
          envelope: changed),
        throwsA(anything),
      );
    }
    final bytes = base64Decode(record.ciphertext);
    bytes[0] ^= 0x01;
    await expectLater(
      cipher.decrypt(vaultKey: key, vaultId: 'qa-vault',
        envelope: record.copyWith(ciphertext: base64Encode(bytes))),
      throwsA(anything),
    );
  });

  test('M279 security settings and unknown record types never sync', () {
    for (final setting in [
      'waffra_pin_sha256', 'waffra_profile', 'googleToken',
      'recoveryPassword', 'rawBankSms',
    ]) {
      expect(() => WaffraCloudSanitizer.sanitize(
        'setting', {'key': setting, 'value': 'synthetic-secret'}),
        throwsStateError);
    }
    expect(() => WaffraCloudSanitizer.sanitize(
        'unreviewed-future-feature', {'bank': 'synthetic'}),
        throwsArgumentError);
  });
}

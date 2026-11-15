import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

/// M977/#679: synthetic big V2 envelope only. Never embeds an owner's backup.
void main() {
  const password = 'M977 Synthetic Backup Password 2026!';
  late String plaintext;
  late String archive;

  setUpAll(() async {
    final dummy = List<String>.filled(
      32000, 'ملف مالي افتراضي / SAR 123.45 / no personal information')
        .join('|');
    plaintext = jsonEncode(<String, Object?>{
      'format': 'waffra-backup',
      'schema': 24,
      'entries': <Object?>[],
      'syntheticPayload': dummy,
    });
    expect(utf8.encode(plaintext).length, greaterThan(1000000));
    archive = await WaffraSecureBackup.encryptUserBackup(
        plaintext, password);
  });

  test('M977 1MiB+ synthetic V2 envelope uses original approved parameters',
      () async {
    final envelope = jsonDecode(archive) as Map<String, dynamic>;
    expect(envelope['format'], 'waffra-secure-backup');
    expect(envelope['version'], 2);
    expect(envelope['kdf'], 'argon2id');
    expect(envelope['memory'], 19456);
    expect(envelope['iterations'], 2);
    expect(envelope['parallelism'], 1);
    expect(envelope['cipher'], 'aes-256-gcm');
    expect(base64Decode(envelope['salt'] as String).length, 16);
    expect(base64Decode(envelope['nonce'] as String).length, 12);
    expect(base64Decode(envelope['mac'] as String).length, 16);
    expect(base64Decode(envelope['data'] as String).length,
        utf8.encode(plaintext).length);
    expect(WaffraSecureBackup.hasValidEncryptedHeader(archive), isTrue);
    expect(archive, isNot(contains('ملف مالي افتراضي')));
    expect(await WaffraSecureBackup.decrypt(archive, password), plaintext);
  });

  test('M977 ciphertext bit flip is never authenticated as valid restore',
      () async {
    final envelope = Map<String, dynamic>.from(
        jsonDecode(archive) as Map<String, dynamic>);
    final cipherText = base64Decode(envelope['data'] as String);
    cipherText[cipherText.length ~/ 2] ^= 1;
    envelope['data'] = base64Encode(cipherText);
    final corrupted = jsonEncode(envelope);
    // A structurally valid V2 header does NOT prove GCM integrity.
    expect(WaffraSecureBackup.hasValidEncryptedHeader(corrupted), isTrue);
    await expectLater(
      WaffraSecureBackup.decrypt(corrupted, password),
      throwsA(isA<Exception>()));
  });

  test('M977 invalid KDF metadata is denied before password authentication',
      () async {
    final envelope = Map<String, dynamic>.from(
        jsonDecode(archive) as Map<String, dynamic>);
    envelope['memory'] = 19457;
    final forged = jsonEncode(envelope);
    expect(WaffraSecureBackup.hasValidEncryptedHeader(forged), isFalse);
    await expectLater(
      WaffraSecureBackup.decrypt(forged, password),
      throwsFormatException);
  });

  test('M977 syntactically corrupt encrypted bytes never yield plaintext',
      () async {
    final envelope = Map<String, dynamic>.from(
        jsonDecode(archive) as Map<String, dynamic>);
    envelope['data'] = '*invalid ciphertext*';
    await expectLater(
      WaffraSecureBackup.decrypt(jsonEncode(envelope), password),
      throwsA(isA<Exception>()));
  });
}

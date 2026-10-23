import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('new backup round trips with exactly eight alphanumeric characters', () async {
    const content='{"format":"waffra-backup","entries":[{"amount":120.50}]}';
    final encrypted=await WaffraSecureBackup.encrypt(content,'Abcd1234');
    expect(encrypted,contains('waffra-secure-backup'));
    expect(encrypted,isNot(contains('120.50')));
    expect(await WaffraSecureBackup.decrypt(encrypted,'Abcd1234'),content);
  });

  test('wrong password cannot decrypt eight-slot export', () async {
    final encrypted=await WaffraSecureBackup.encrypt('secret','Valid123');
    await expectLater(WaffraSecureBackup.decrypt(encrypted,'Wrong123'),
        throwsA(isA<Exception>()));
  });

  test('backup export refuses short, long, letters-only, digits-only and symbols', () async {
    for (final value in [
      'short', 'Abcd12345', 'abcdefgh', '12345678', 'Abcd12!!',
      'Abcd 123', 'Abcd123\u00e9',
    ]) {
      expect(WaffraSecureBackup.isValidNewPassword(value),false,
          reason:'Rejected: $value');
      await expectLater(WaffraSecureBackup.encrypt('content',value),
          throwsFormatException);
    }
    expect(WaffraSecureBackup.isValidNewPassword('ABC12345'),true);
  });

  test('old encrypted backups with longer passwords still restore', () async {
    // Construct a legacy-version archive without using the new export API.
    const legacyPassword='previous-long-password-2025';
    const plaintext='{"format":"waffra-backup","entries":[]}';
    final salt=List<int>.generate(16,(i)=>i+1);
    final nonce=List<int>.generate(12,(i)=>20+i);
    final cipher=AesGcm.with256bits();
    final key=await Pbkdf2(
      macAlgorithm:Hmac.sha256(),iterations:120000,bits:256,
    ).deriveKey(secretKey:SecretKey(utf8.encode(legacyPassword)),nonce:salt);
    final box=await cipher.encrypt(
      utf8.encode(plaintext),secretKey:key,nonce:nonce,
    );
    final archive=jsonEncode({
      'format':'waffra-secure-backup',
      'version':1,'kdf':'pbkdf2-sha256',
      'iterations':120000,'cipher':'aes-256-gcm',
      'salt':base64Encode(salt),'nonce':base64Encode(box.nonce),
      'data':base64Encode(box.cipherText),'mac':base64Encode(box.mac.bytes),
    });
    expect(await WaffraSecureBackup.decrypt(archive,legacyPassword),plaintext);
  });

  test('legacy plaintext exports remain importable',() async {
    const backup='{"format":"waffra-backup","entries":[]}';
    expect(await WaffraSecureBackup.decrypt(backup,''),backup);
  });
}

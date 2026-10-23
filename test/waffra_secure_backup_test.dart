import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_secure_backup.dart';

void main() {
  test('V2 Argon2id backup encrypts round trip with long password', () async {
    const content='{"format":"waffra-backup","entries":[{"amount":120.50}]}';
    final encrypted=await WaffraSecureBackup.encryptUserBackup(content,'StrongPassphrase123!2026');
    expect(encrypted,contains('waffra-secure-backup'));
    expect(encrypted,contains('"argon2id"'));
    expect(WaffraSecureBackup.hasValidEncryptedHeader(encrypted),isTrue);
    expect(encrypted,isNot(contains('120.50')));
    expect(await WaffraSecureBackup.decrypt(encrypted,'StrongPassphrase123!2026'),content);
  });

  test('wrong password cannot decrypt V2 archive', () async {
    final encrypted=await WaffraSecureBackup.encryptUserBackup('secret','StrongPassphrase123!2026');
    await expectLater(WaffraSecureBackup.decrypt(encrypted,'CompletelyWrong123!2026'),
        throwsA(isA<Exception>()));
  });

  test('backup export requires 12+ characters and accepts international passphrases', () async {
    for(final value in ['', 'short','Abcd1234567','12345678']){
     expect(WaffraSecureBackup.isValidNewPassword(value),false);
     await expectLater(WaffraSecureBackup.encryptUserBackup('content',value),
      throwsFormatException);
    }
    expect(WaffraSecureBackup.isValidNewPassword('ABC12345!strong'),true);
    expect(WaffraSecureBackup.isValidNewPassword('عبارة مرور قوية ٢٠٢٦'),true);
  });

  test('internal portable archive encryption retains long passwords', () async {
    const archivePassword='very-long-portable-archive-passphrase';
    const raw='portable finance vault';
    final encoded=await WaffraSecureBackup.encrypt(raw,archivePassword);
    expect(await WaffraSecureBackup.decrypt(encoded,archivePassword),raw);
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

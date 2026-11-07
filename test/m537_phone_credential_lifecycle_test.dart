import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:waffra/waffra_local_phone_credentials.dart';

/// M537: execute real PBKDF2/secure-verifier operations against an isolated
/// platform-storage mock. No Android APK, real user storage or finance writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const phone = '0501234567';
  const password = 'A-strong-local-password-123';
  const otherPhone = '0507654321';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('register, close session, login repeatedly with same phone/password', () async {
    await WaffraLocalPhoneCredentials.registerOrResume(
      phone: phone, password: password);
    expect(await WaffraLocalPhoneCredentials.probeForPhone(phone),
      WaffraLocalCredentialProbe.ready);
    for (var session = 0; session < 3; session++) {
      // Sign-out must never erase the OS-protected password verifier.
      expect(await WaffraLocalPhoneCredentials.verify(
        phone: phone, password: password), isTrue);
      expect(await WaffraLocalPhoneCredentials.verify(
        phone: phone, password: 'wrong-password-123'), isFalse);
    }
    await WaffraLocalPhoneCredentials.registerOrResume(
      phone: phone, password: password);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: phone, password: password), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('different phone and password cannot steal existing local identity', () async {
    await WaffraLocalPhoneCredentials.registerOrResume(
      phone: phone, password: password);
    expect(await WaffraLocalPhoneCredentials.probeForPhone(otherPhone),
      WaffraLocalCredentialProbe.differentPhone);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: otherPhone, password: password), isFalse);
    await expectLater(
      WaffraLocalPhoneCredentials.registerOrResume(
        phone: otherPhone, password: password), throwsStateError);
    await expectLater(
      WaffraLocalPhoneCredentials.registerOrResume(
        phone: phone, password: 'different-password-123'), throwsStateError);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: phone, password: password), isTrue);
  });

  test('missing and malformed verifier cannot authenticate or be silently replaced', () async {
    expect(await WaffraLocalPhoneCredentials.probeForPhone(phone),
      WaffraLocalCredentialProbe.missing);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: phone, password: password), isFalse);
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'waffra_device_phone_credentials_v2': jsonEncode({
        'version': 2, 'iterations': 600000, 'phoneHash': 'invalid',
        'salt': 'bad', 'hash': 'bad',
      }),
    });
    expect(await WaffraLocalPhoneCredentials.probeForPhone(phone),
      WaffraLocalCredentialProbe.malformed);
    await expectLater(
      WaffraLocalPhoneCredentials.registerOrResume(
        phone: phone, password: password), throwsStateError);
  });

  test('credential verifier is salted, not a plaintext password', () async {
    final record = await WaffraLocalPhoneCredentials.deriveRecord(
      phone: phone, password: password,
      testSalt: List<int>.generate(32, (i) => i));
    expect(record['version'], 2);
    expect(record['iterations'], 600000);
    expect(jsonEncode(record), isNot(contains(password)));
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      record, phone: phone, password: password), isTrue);
    expect(await WaffraLocalPhoneCredentials.verifyRecord(
      record, phone: phone, password: 'wrong-password-123'), isFalse);
  });

  test('M545 old missing verifier stages secure grant and restores at next login', () async {
    expect(await WaffraLocalPhoneCredentials.probeForPhone(phone),
      WaffraLocalCredentialProbe.missing);
    expect(await WaffraLocalPhoneCredentials.stageSignOutRecoveryGrant(phone),
      isTrue);
    expect(await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(phone),
      isTrue);
    expect(await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(otherPhone),
      isFalse);
    expect(await WaffraLocalPhoneCredentials.stageSignOutRecoveryGrant(otherPhone),
      isFalse);
    expect(await WaffraLocalPhoneCredentials.finishSignInRecoveryAfterBiometric(
      phone: otherPhone, password: password), isFalse);
    // The UI must first require OS biometrics; this unit test challenges
    // the storage step directly with a simulated positive biometric result.
    expect(await WaffraLocalPhoneCredentials.finishSignInRecoveryAfterBiometric(
      phone: phone, password: password), isTrue);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: phone, password: password), isTrue);
    expect(await WaffraLocalPhoneCredentials.verify(
      phone: phone, password: 'wrong-password'), isFalse);
    expect(await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(phone),
      isFalse);
    expect(await WaffraLocalPhoneCredentials.finishSignInRecoveryAfterBiometric(
      phone: phone, password: password), isFalse);
    expect(await WaffraLocalPhoneCredentials.stageSignOutRecoveryGrant(phone),
      isFalse);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('M545 malformed or unrelated recovery grants fail closed', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'waffra_phone_missing_verifier_signout_recovery_v1': '{not-json',
    });
    expect(await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(phone),
      isFalse);
    expect(await WaffraLocalPhoneCredentials.stageSignOutRecoveryGrant(phone),
      isFalse); // never overwrite a damaged secure grant
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'waffra_phone_missing_verifier_signout_recovery_v1': jsonEncode({
        'version': 1, 'phoneHash': 'foreign', 'nonce': base64Encode(List<int>.filled(32, 1)),
      }),
    });
    expect(await WaffraLocalPhoneCredentials.hasSignOutRecoveryGrant(phone),
      isFalse);
    expect(await WaffraLocalPhoneCredentials.finishSignInRecoveryAfterBiometric(
      phone: phone, password: password), isFalse);
  });
}

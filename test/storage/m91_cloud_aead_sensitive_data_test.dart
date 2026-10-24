import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';

/// M91 standalone offline AEAD and allow-list privacy acceptance.
/// Not connected to a real Firebase project or user account.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cipher = WaffraCloudCipher();

  test('M91 cloud public document has no unencrypted financial values',
      () async {
    final key = await cipher.newRandomVaultKey();
    final encrypted = await cipher.encrypt(
      vaultKey: key,
      vaultId: 'qa-private-vault',
      kind: 'entry',
      recordId: 'qa-transaction',
      deviceId: 'qa-device',
      mutationId: 'qa-mutation',
      localVersion: 1,
      record: {
        'id': 'qa-transaction',
        'title': 'تجربة خاصة جدا',
        'category': 'مصروف',
        'amount': 857.35,
        'income': false,
        'date': '2026-10-22T12:00:00',
        'receiptPath': '/private/receipt.png',
      },
    );
    final publicJson = jsonEncode(encrypted.toFirestoreDocument());
    expect(publicJson, isNot(contains('تجربة خاصة جدا')));
    expect(publicJson, isNot(contains('857.35')));
    expect(publicJson, isNot(contains('/private/receipt.png')));
    expect(publicJson, isNot(contains('receiptPath')));
    expect(publicJson, isNot(contains('bankAccount')));
    final decrypted = await cipher.decrypt(
      vaultKey: key, vaultId: 'qa-private-vault', envelope: encrypted,
    );
    expect(decrypted['amount'], 857.35);
    expect(decrypted.containsKey('receiptPath'), isFalse);
  });

  test('M91 unsupported bank credential and raw SMS fields fail before encrypt',
      () async {
    final key = await cipher.newRandomVaultKey();
    for (final forbidden in [
      'bankAccount', 'iban', 'rawSms', 'accessToken',
      'password', 'authToken', 'accountNumber',
    ]) {
      await expectLater(cipher.encrypt(
        vaultKey: key,
        vaultId: 'qa-private-vault',
        kind: 'entry',
        recordId: 'qa-transaction',
        deviceId: 'qa-device',
        mutationId: 'qa-mutation',
        localVersion: 1,
        record: {
          'id': 'qa-transaction',
          'title': 'Synthetic',
          'category': 'أخرى',
          'amount': 10,
          'income': false,
          'date': '2026-10-22',
          forbidden: 'private value',
        },
      ), throwsA(isA<StateError>()), reason: forbidden);
    }
  });

  test('M91 altered vault, identity, revision and AEAD tag cannot decrypt',
      () async {
    final key = await cipher.newRandomVaultKey();
    final record = await cipher.encrypt(
      vaultKey: key, vaultId: 'qa-private-vault',
      kind: 'entry', recordId: 'record-1', deviceId: 'device-one',
      mutationId: 'mutation-one', localVersion: 1,
      record: {
        'id': 'record-1', 'title': 'Synthetic',
        'category': 'أخرى', 'amount': 5.50,
        'income': false, 'date': '2026-10-22',
      },
    );
    await expectLater(cipher.decrypt(
      vaultKey: key, vaultId: 'qa-other-vault', envelope: record,
    ), throwsA(anything));
    for (final changed in [
      record.copyWith(recordId: 'another-record'),
      record.copyWith(mutationId: 'forged-replay'),
      record.copyWith(localVersion: 2),
      record.copyWith(mac: base64Encode(List<int>.filled(16, 0))),
    ]) {
      await expectLater(cipher.decrypt(
        vaultKey: key, vaultId: 'qa-private-vault', envelope: changed,
      ), throwsA(anything));
    }
  });

  test('M91 cloud sanitizer refuses unapproved settings and nested fields',
      () {
    expect(() => WaffraCloudSanitizer.sanitize(
      'setting', {'key': 'accountId', 'value': 'secret'},
    ), throwsA(isA<StateError>()));
    expect(() => WaffraCloudSanitizer.sanitize(
      'entry', {
        'id': 'record-1', 'title': 'Safe', 'amount': 4,
        'metadata': {'iban': 'do-not-sync'},
      },
    ), throwsA(isA<StateError>()));
    expect(() => WaffraCloudSanitizer.sanitize(
      'unknown-kind', {'id': 'x'},
    ), throwsA(isA<ArgumentError>()));
  });
}

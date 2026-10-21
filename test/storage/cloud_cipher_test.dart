import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';

void main() {
  late WaffraCloudCipher cipher;

  setUp(() {
    cipher = WaffraCloudCipher();
  });

  test('record is round-trippable, but envelope contains no financial plaintext',
      () async {
    final key = await cipher.newRandomVaultKey();
    final input = {
      'id': 'entry-1',
      'title': 'فاتورة سرية 💸',
      'category': 'غذاء',
      'amount': 12.75,
      'income': false,
      'date': '2026-10-21T14:00:00',
      'receiptPath': '/private/receipt.jpg',
    };
    final envelope = await cipher.encrypt(
      vaultKey: key,
      vaultId: 'vault-a',
      kind: 'entry',
      recordId: 'entry-1',
      deviceId: 'device-a',
      mutationId: 'mutation-1',
      localVersion: 1,
      record: input,
    );
    final remoteDoc = envelope.toFirestoreDocument();
    final serialized = jsonEncode(remoteDoc);
    expect(serialized, isNot(contains('فاتورة')));
    expect(serialized, isNot(contains('12.75')));
    expect(serialized, isNot(contains('غذاء')));
    expect(serialized, isNot(contains('/private/receipt.jpg')));
    expect(remoteDoc.containsKey('amount'), isFalse);
    expect(remoteDoc.containsKey('receiptPath'), isFalse);

    final decrypted = await cipher.decrypt(
      vaultKey: key, vaultId: 'vault-a', envelope: envelope);
    expect(decrypted['title'], 'فاتورة سرية 💸');
    expect(decrypted['amount'], 12.75);
    expect(decrypted.containsKey('receiptPath'), isFalse);
    expect(input['receiptPath'], '/private/receipt.jpg');
  });

  test('tampering with ciphertext, record ID, vault or mutation fails', () async {
    final key = await cipher.newRandomVaultKey();
    final envelope = await cipher.encrypt(
      vaultKey: key,
      vaultId: 'vault-a',
      kind: 'entry',
      recordId: 'entry-1',
      deviceId: 'device-a',
      mutationId: 'mutation-1',
      localVersion: 1,
      record: {
        'id': 'entry-1',
        'title': 'اختبار',
        'category': 'أخرى',
        'amount': 2.0,
        'income': false,
        'date': '2026-10-21T14:00:00',
      },
    );
    await expectLater(
      cipher.decrypt(vaultKey: key, vaultId: 'vault-b', envelope: envelope),
      throwsA(anything),
    );
    await expectLater(
      cipher.decrypt(vaultKey: key, vaultId: 'vault-a',
        envelope: envelope.copyWith(recordId: 'entry-2')),
      throwsA(anything),
    );
    await expectLater(
      cipher.decrypt(vaultKey: key, vaultId: 'vault-a',
        envelope: envelope.copyWith(mutationId: 'mutation-changed')),
      throwsA(anything),
    );
    final differentKey = await cipher.newRandomVaultKey();
    await expectLater(
      cipher.decrypt(vaultKey: differentKey, vaultId: 'vault-a',
        envelope: envelope),
      throwsA(anything),
    );
  });

  test('unknown fields and account secrets are blocked instead of uploaded',
      () async {
    final key = await cipher.newRandomVaultKey();
    Future<void> attempt(Map<String, dynamic> record) async {
      await cipher.encrypt(
        vaultKey: key,
        vaultId: 'vault-a',
        kind: 'entry',
        recordId: 'entry-1',
        deviceId: 'device-a',
        mutationId: 'mutation-1',
        localVersion: 1,
        record: record,
      );
    }
    await expectLater(attempt({'id': 'entry-1', 'rawSms': 'bank body'}),
      throwsA(isA<StateError>()));
    await expectLater(attempt({'id': 'entry-1', 'bankAccount': 'secret'}),
      throwsA(isA<StateError>()));
    await expectLater(attempt({'id': 'wrong-id'}),
      throwsA(isA<StateError>()));
  });

  test('forbidden setting cannot be synced', () {
    expect(
      () => WaffraCloudSanitizer.sanitize('setting',
        {'key': 'waffra_pin_sha256', 'value': 'sensitive'}),
      throwsA(isA<StateError>()),
    );
  });

  test('independent encryption uses fresh nonce and authenticates metadata',
      () async {
    final key = await cipher.newRandomVaultKey();
    Future<WaffraEncryptedCloudRecord> encrypt() => cipher.encrypt(
      vaultKey: key, vaultId: 'vault-a', kind: 'goal', recordId: 'goal-1',
      deviceId: 'device-a', mutationId: 'mut-1', localVersion: 1,
      record: {'id':'goal-1','name':'سيارة','target':100000,'saved':50},
    );
    final first = await encrypt();
    final second = await encrypt();
    expect(first.nonce, isNot(second.nonce));
    expect(first.ciphertext, isNot(second.ciphertext));
    final out = await cipher.decrypt(
      vaultKey: key, vaultId: 'vault-a', envelope: second);
    expect(out['name'], 'سيارة');
    expect(out['saved'], 50);
  });
}

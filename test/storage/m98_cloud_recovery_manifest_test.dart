import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_recovery_manifest.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

/// M98 authenticates an encrypted record inventory for device recovery.
/// Does not connect to Firestore or mutate a real user's local vault.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final crypto = WaffraCloudCipher();
  const vaultId = 'm98-test-private-vault';

  WaffraCloudRecordPointer pointer({
    String id = 'finance-one',
    String kind = 'entry',
    String mutation = 'm98-version-one',
    int version = 1,
    bool deleted = false,
  }) => WaffraCloudRecordPointer(
    kind: kind, id: id, mutationId: mutation,
    version: version, deleted: deleted,
  );

  Future<WaffraEncryptedCloudRecord> manifest({
    required SecretKey key,
    List<WaffraCloudRecordPointer>? pointers,
  }) => WaffraCloudRecoveryManifest.encrypt(
    recoveredVaultKey: key,
    vaultId: vaultId,
    deviceId: 'm98-phone-A',
    mutationId: 'm98-index-v1',
    version: 1,
    records: pointers ?? [pointer()],
  );

  test('M98 encrypted recovery index stays ciphertext-only in Firestore',
      () async {
    final key = await crypto.newRandomVaultKey();
    final encrypted = await manifest(
      key: key,
      pointers: [
        pointer(),
        pointer(id: 'goal-two', kind: 'goal', mutation: 'goal-2', version: 2),
      ],
    );
    final public = jsonEncode(encrypted.toFirestoreDocument());
    expect(public, isNot(contains('finance-one')));
    expect(public, isNot(contains('goal-two')));
    expect(public, isNot(contains('m98-version-one')));
    expect(public, isNot(contains('amount')));
    expect(WaffraEncryptedCloudOutbox.documentId(
      WaffraCloudRecoveryManifest.kind,
      WaffraCloudRecoveryManifest.recordId,
    ), hasLength(64));
    final restored = await WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: key, vaultId: vaultId, manifest: encrypted,
    );
    expect(restored, hasLength(2));
    expect(restored.first.id, 'finance-one');
    expect(restored.last.kind, 'goal');
    expect(restored.last.version, 2);
  });

  test('M98 recovery inventory cannot decrypt with a wrong vault or key',
      () async {
    final key = await crypto.newRandomVaultKey();
    final encrypted = await manifest(key: key);
    await expectLater(WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: await crypto.newRandomVaultKey(),
      vaultId: vaultId,
      manifest: encrypted,
    ), throwsA(anything));
    await expectLater(WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: key,
      vaultId: 'unrelated-vault',
      manifest: encrypted,
    ), throwsA(anything));
  });

  test('M98 changing recovery index revision or mutation breaks AEAD',
      () async {
    final key = await crypto.newRandomVaultKey();
    final encrypted = await manifest(key: key);
    for (final changed in [
      encrypted.copyWith(localVersion: 2),
      encrypted.copyWith(mutationId: 'm98-forged'),
      encrypted.copyWith(recordId: 'finance-index-forged'),
      encrypted.copyWith(mac: base64Encode(List<int>.filled(16, 0))),
    ]) {
      await expectLater(WaffraCloudRecoveryManifest.decrypt(
        recoveredVaultKey: key,
        vaultId: vaultId,
        manifest: changed,
      ), throwsA(anything));
    }
  });

  test('M98 repeated kind and ID never create ambiguous recovery list',
      () async {
    final key = await crypto.newRandomVaultKey();
    await expectLater(manifest(
      key: key,
      pointers: [
        pointer(), pointer(mutation: 'another-local-mutation'),
      ],
    ), throwsA(isA<StateError>()));
    final differentKinds = await manifest(
      key: key, pointers: [pointer(), pointer(kind: 'goal')],
    );
    final recovered = await WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: key, vaultId: vaultId,
      manifest: differentKinds,
    );
    expect(recovered, hasLength(2));
  });

  test('M98 index refuses unsupported kinds, metadata and secrets',
      () async {
    final key = await crypto.newRandomVaultKey();
    for (final invalid in [
      pointer(kind: 'manifest'),
      pointer(kind: 'bank_account'),
      pointer(id: ''),
      pointer(version: 0),
      pointer(mutation: ''),
      pointer(id: 'x'.padRight(129, 'x')),
    ]) {
      await expectLater(manifest(key: key, pointers: [invalid]),
          throwsA(isA<StateError>()));
    }
    await expectLater(crypto.encrypt(
      vaultKey: key,
      vaultId: vaultId,
      kind: 'manifest',
      recordId: 'finance-index',
      deviceId: 'm98-phone-A',
      mutationId: 'm98-index-v1',
      localVersion: 1,
      record: {
        'id': 'finance-index',
        'records': [pointer().toJson()],
        'bankAccessToken': 'forbidden-plaintext',
      },
    ), throwsA(isA<StateError>()));
  });

  test('M98 inventory cannot silently truncate at 1000 records',
      () async {
    final key = await crypto.newRandomVaultKey();
    final maximum = [
      for (var i = 0; i < 1000; i++)
        pointer(id: 'transaction-${i.toString().padLeft(4, '0')}'),
    ];
    final encrypted = await manifest(key: key, pointers: maximum);
    expect((await WaffraCloudRecoveryManifest.decrypt(
      recoveredVaultKey: key,
      vaultId: vaultId,
      manifest: encrypted,
    )).length, 1000);
    await expectLater(manifest(
      key: key,
      pointers: [...maximum, pointer(id: 'overflow')],
    ), throwsA(isA<StateError>()));
  });
}

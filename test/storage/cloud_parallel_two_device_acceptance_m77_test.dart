import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_compare_and_swap.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

/// Read-only/rehearsal acceptance for two independent devices and their
/// offline SQLCipher queues. Requires no UI cutover or M76 receipt writer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late WaffraEncryptedStore firstDevice;
  late WaffraEncryptedStore secondDevice;
  late WaffraCloudCipher crypt;
  const sqlcipherKey = 'm77-disposable-device-sqlcipher-only';
  const vaultId = 'm77-user-private-vault';
  const recordId = 'finance-1';

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m77-2-devices-');
    firstDevice = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/phone-one.sqlite'), key: sqlcipherKey,
    );
    secondDevice = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/phone-two.sqlite'), key: sqlcipherKey,
    );
    crypt = WaffraCloudCipher();
  });

  tearDown(() async {
    await firstDevice.close();
    await secondDevice.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  WaffraRemoteRevision acknowledged(WaffraCloudQueueItem item) =>
      WaffraRemoteRevision(
        documentId: item.documentId,
        kind: item.envelope.kind,
        mutationId: item.envelope.mutationId,
        deviceId: item.envelope.deviceId,
        localVersion: item.envelope.localVersion,
        ciphertext: item.envelope.ciphertext,
        nonce: item.envelope.nonce,
        mac: item.envelope.mac,
        deleted: item.deleted,
      );

  test('M77 independently queued devices preserve BOTH local transactions after a conflict',
      () async {
    final sharedKey = await crypt.newRandomVaultKey();
    final firstQueue = WaffraEncryptedCloudOutbox(firstDevice);
    final secondQueue = WaffraEncryptedCloudOutbox(secondDevice);
    Future<WaffraEncryptedCloudRecord> local(String device, String mutation) =>
        crypt.encrypt(
          vaultKey: sharedKey,
          vaultId: vaultId,
          kind: 'entry',
          recordId: recordId,
          deviceId: device,
          mutationId: mutation,
          localVersion: 1,
          record: {
            'id': recordId, 'title': 'قهوة',
            'category': 'مطاعم وكافيهات', 'amount': 14.75,
            'income': false, 'date': '2026-10-22T10:00:00',
          },
        );
    await firstQueue.enqueue(
      vaultId: vaultId, envelope: await local('phone-1', 'phone-1-mutation'),
    );
    await secondQueue.enqueue(
      vaultId: vaultId, envelope: await local('phone-2', 'phone-2-mutation'),
    );

    final first = (await firstQueue.pending(vaultId: vaultId)).single;
    final second = (await secondQueue.pending(vaultId: vaultId)).single;
    expect(WaffraCloudCompareAndSwap.plan(
      item: first, remote: null, expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.create);
    // The server committed phone 1's envelope before phone 2 arrived.
    expect(WaffraCloudCompareAndSwap.plan(
      item: second, remote: acknowledged(first),
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
    await expectLater(secondQueue.acknowledge(
      item: second, confirmedRemote: acknowledged(first),
    ), throwsA(isA<StateError>()));
    await firstQueue.acknowledge(
      item: first, confirmedRemote: acknowledged(first),
    );
    expect(await firstQueue.pending(vaultId: vaultId), isEmpty);
    expect((await secondQueue.pending(vaultId: vaultId)).single
        .envelope.mutationId, 'phone-2-mutation');

    // A cold restart MUST NOT wipe an unresolved offline conflict.
    await secondDevice.close();
    secondDevice = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/phone-two.sqlite'), key: sqlcipherKey,
    );
    final replay = (await WaffraEncryptedCloudOutbox(secondDevice)
        .pending(vaultId: vaultId)).single;
    expect(replay.envelope.mutationId, 'phone-2-mutation');
    final plaintext = await crypt.decrypt(
      vaultKey: sharedKey, vaultId: vaultId, envelope: replay.envelope,
    );
    expect(plaintext['amount'], 14.75);
  });

  test('M77 wrong recovery key and forged device/revision never decrypt remote money',
      () async {
    final sharedKey = await crypt.newRandomVaultKey();
    final wrongKey = await crypt.newRandomVaultKey();
    final envelope = await crypt.encrypt(
      vaultKey: sharedKey,
      vaultId: vaultId,
      kind: 'goal',
      recordId: 'goal-recovery',
      deviceId: 'phone-1',
      mutationId: 'first-goal-mutation',
      localVersion: 1,
      record: {'id': 'goal-recovery', 'name': 'سيارة',
               'target': 20000, 'saved': 300},
    );
    await expectLater(crypt.decrypt(
      vaultKey: wrongKey, vaultId: vaultId, envelope: envelope,
    ), throwsA(anything));
    await expectLater(crypt.decrypt(
      vaultKey: sharedKey, vaultId: vaultId,
      envelope: envelope.copyWith(deviceId: 'other-phone'),
    ), throwsA(anything));
    await expectLater(crypt.decrypt(
      vaultKey: sharedKey, vaultId: vaultId,
      envelope: envelope.copyWith(localVersion: 2),
    ), throwsA(anything));
    final unlocked = await crypt.decrypt(
      vaultKey: sharedKey, vaultId: vaultId, envelope: envelope,
    );
    expect(unlocked['name'], 'سيارة');
    expect(unlocked['saved'], 300);
  });

  test('M77 re-encryption can advance only from the exact observed remote predecessor',
      () async {
    final key = await crypt.newRandomVaultKey();
    Future<WaffraEncryptedCloudRecord> update(String mutation, int version) =>
        crypt.encrypt(
          vaultKey: key, vaultId: vaultId, kind: 'entry',
          recordId: recordId, deviceId: 'phone-2',
          mutationId: mutation, localVersion: version,
          record: {
            'id': recordId, 'title': 'اشتراك',
            'category': 'متكررة', 'amount': 27.00,
            'income': false, 'date': '2026-10-22T10:00:00',
          },
        );
    final previous = await update('known-remote-1', 1);
    final next = await update('phone-2-retry-2', 2);
    final queued = WaffraCloudQueueItem(
      vaultId: vaultId,
      documentId: WaffraEncryptedCloudOutbox.documentId('entry', recordId),
      envelope: next, deleted: false,
    );
    final remote = WaffraRemoteRevision(
      documentId: queued.documentId,
      kind: previous.kind,
      mutationId: previous.mutationId,
      deviceId: previous.deviceId,
      localVersion: previous.localVersion,
      ciphertext: previous.ciphertext,
      nonce: previous.nonce,
      mac: previous.mac,
      deleted: false,
    );
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued, remote: remote,
      expectedPreviousMutationId: 'known-remote-1',
    ), WaffraCloudCasAction.advance);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued, remote: remote,
      expectedPreviousMutationId: 'wrong-previous',
    ), WaffraCloudCasAction.manualConflict);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued, remote: remote, expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
  });

  test('M77 cloud sanitizer excludes invoice paths but rejects raw SMS or bank secrets',
      () async {
    final key = await crypt.newRandomVaultKey();
    final encrypted = await crypt.encrypt(
      vaultKey: key, vaultId: vaultId,
      kind: 'entry', recordId: recordId,
      deviceId: 'phone-1', mutationId: 'privacy-test', localVersion: 1,
      record: {
        'id': recordId, 'title': 'شراء',
        'category': 'أخرى', 'amount': 2.0,
        'income': false, 'date': '2026-10-22T10:00:00',
        'receiptPath': '/private/app/invoice.jpg',
      },
    );
    final clear = await crypt.decrypt(
      vaultKey: key, vaultId: vaultId, envelope: encrypted,
    );
    expect(clear.containsKey('receiptPath'), false);
    expect(encrypted.toFirestoreDocument().containsKey('amount'), false);
    for (final sensitive in ['rawSms', 'iban', 'accountNumber', 'authToken']) {
      await expectLater(crypt.encrypt(
        vaultKey: key, vaultId: vaultId,
        kind: 'entry', recordId: recordId,
        deviceId: 'phone-1', mutationId: 'disallowed-field',
        localVersion: 1,
        record: {'id': recordId, sensitive: 'never upload'},
      ), throwsA(isA<StateError>()));
    }
  });
}

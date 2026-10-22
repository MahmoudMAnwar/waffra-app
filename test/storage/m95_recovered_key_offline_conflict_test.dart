import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_compare_and_swap.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';
import 'package:waffra/storage/waffra_vault_key_recovery.dart';

/// M95 end-to-end synthetic offline E2EE key recovery + conflict handling.
/// No network or Firebase credentials. Never automatically resolves conflicts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late WaffraEncryptedStore database;
  late WaffraEncryptedCloudOutbox outbox;
  final crypto = WaffraCloudCipher();
  final recover = WaffraVaultKeyRecovery();
  const vaultId = 'm95-test-vault';
  const sqlKey = 'm95-synthetic-disposable-device-db-key';

  Future<WaffraEncryptedCloudRecord> queuedRecord() async =>
      crypto.encrypt(
        vaultKey: await crypto.newRandomVaultKey(),
        vaultId: vaultId,
        kind: 'entry',
        recordId: 'm95-entry',
        deviceId: 'm95-phone-A',
        mutationId: 'm95-edit-A-1',
        localVersion: 1,
        record: {
          'id': 'm95-entry',
          'title': 'Synthetic private transaction',
          'category': 'أخرى',
          'amount': 35.25,
          'income': false,
          'date': '2026-10-22T15:00:00',
        },
      );

  WaffraRemoteRevision revision(WaffraCloudQueueItem item, {
    String? mutationId,
    String? deviceId,
    String? ciphertext,
  }) => WaffraRemoteRevision(
    documentId: item.documentId,
    kind: item.envelope.kind,
    mutationId: mutationId ?? item.envelope.mutationId,
    deviceId: deviceId ?? item.envelope.deviceId,
    localVersion: item.envelope.localVersion,
    ciphertext: ciphertext ?? item.envelope.ciphertext,
    nonce: item.envelope.nonce, mac: item.envelope.mac,
    deleted: item.deleted,
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('waffra-m95-cloud-');
    database = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: sqlKey,
    );
    outbox = WaffraEncryptedCloudOutbox(database);
  });
  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M95 recovered E2EE key opens ciphertext after simulated device loss',
      () async {
    final original = await crypto.newRandomVaultKey();
    final bundle = await recover.create(
      vaultKey: original, vaultId: vaultId,
    );
    final record = await crypto.encrypt(
      vaultKey: original, vaultId: vaultId,
      kind: 'entry', recordId: 'm95-entry',
      deviceId: 'phone-A', mutationId: 'phone-A-1',
      localVersion: 1,
      record: {
        'id': 'm95-entry', 'title': 'Synthetic recovery',
        'category': 'أخرى', 'amount': 15.75,
        'income': false, 'date': '2026-10-22T15:00:00',
      },
    );
    final newDeviceKey = await recover.recover(
      vaultId: vaultId, recoveryCode: bundle.recoveryCode,
      envelope: bundle.envelope,
    );
    final opened = await crypto.decrypt(
      vaultKey: newDeviceKey, vaultId: vaultId, envelope: record,
    );
    expect(opened['amount'], 15.75);
    expect(opened['title'], 'Synthetic recovery');
  });

  test('M95 remote competing device keeps local encrypted pending change',
      () async {
    await outbox.enqueue(
      vaultId: vaultId, envelope: await queuedRecord(),
    );
    final pending = (await outbox.pending(vaultId: vaultId)).single;
    final remote = revision(
      pending, mutationId: 'm95-edit-B-1', deviceId: 'm95-phone-B',
    );
    expect(WaffraCloudCompareAndSwap.plan(
      item: pending, remote: remote, expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
    await expectLater(outbox.acknowledge(
      item: pending, confirmedRemote: remote,
    ), throwsA(isA<StateError>()));
    expect((await outbox.pending(vaultId: vaultId)).single
        .envelope.mutationId, 'm95-edit-A-1');
  });

  test('M95 only exact remote ciphertext can acknowledge after restart',
      () async {
    await outbox.enqueue(
      vaultId: vaultId, envelope: await queuedRecord(),
    );
    await database.close();
    database = WaffraEncryptedStore.openAt(
      File('${root.path}/vault.sqlite'), key: sqlKey,
    );
    outbox = WaffraEncryptedCloudOutbox(database);
    final pending = (await outbox.pending(vaultId: vaultId)).single;
    await expectLater(outbox.acknowledge(
      item: pending,
      confirmedRemote: revision(pending, ciphertext: 'forged'),
    ), throwsA(isA<StateError>()));
    expect(await outbox.pending(vaultId: vaultId), hasLength(1));
    await outbox.acknowledge(
      item: pending, confirmedRemote: revision(pending),
    );
    expect(await outbox.pending(vaultId: vaultId), isEmpty);
  });

  test('M95 old vault recovery code never authorizes another vault',
      () async {
    final key = await crypto.newRandomVaultKey();
    final bundle = await recover.create(
      vaultKey: key, vaultId: vaultId,
    );
    await expectLater(recover.recover(
      vaultId: 'm95-unrelated-vault',
      recoveryCode: bundle.recoveryCode,
      envelope: bundle.envelope,
    ), throwsA(isA<StateError>()));
  });
}

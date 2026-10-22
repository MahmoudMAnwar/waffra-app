import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_manifest_last_outbox_drain.dart';
import 'package:waffra/storage/waffra_cloud_recovery_manifest.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_firestore_encrypted_sync_transport.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

/// Disposable two-device remote-ack simulation. Does not touch user Firebase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cipher = WaffraCloudCipher();
  late Directory root;
  late WaffraEncryptedStore db;
  late WaffraEncryptedCloudOutbox outbox;
  const vault = 'm99-test-vault';
  const authorized = WaffraCloudSyncAuthorization(
    userConsented: true,
    recoveryKeyVerified: true,
    encryptedSourceVerified: true,
    allWritersRouted: true,
  );

  Future<WaffraEncryptedCloudRecord> entry(String id,
      {int version = 1}) async {
    return cipher.encrypt(
      vaultKey: await cipher.newRandomVaultKey(),
      vaultId: vault,
      kind: 'entry', recordId: id,
      deviceId: 'm99-device-A',
      mutationId: '$id-mut-$version',
      localVersion: version,
      record: {
        'id': id, 'title': 'Synthetic private item',
        'category': 'أخرى', 'amount': 12.50,
        'income': false, 'date': '2026-10-22',
      },
    );
  }

  Future<WaffraEncryptedCloudRecord> manifest() async =>
      WaffraCloudRecoveryManifest.encrypt(
        recoveredVaultKey: await cipher.newRandomVaultKey(),
        vaultId: vault, deviceId: 'm99-device-A',
        mutationId: 'manifest-v1', version: 1,
        records: [
          const WaffraCloudRecordPointer(
            kind: 'entry', id: 'item-a', mutationId: 'item-a-mut-1',
            version: 1, deleted: false,
          ),
          const WaffraCloudRecordPointer(
            kind: 'entry', id: 'item-b', mutationId: 'item-b-mut-1',
            version: 1, deleted: false,
          ),
        ],
      );

  Future<void> acknowledge(WaffraCloudQueueItem item) =>
      outbox.acknowledge(
        item: item,
        confirmedRemote: WaffraRemoteRevision(
          documentId: item.documentId,
          kind: item.envelope.kind,
          mutationId: item.envelope.mutationId,
          deviceId: item.envelope.deviceId,
          localVersion: item.envelope.localVersion,
          ciphertext: item.envelope.ciphertext,
          nonce: item.envelope.nonce,
          mac: item.envelope.mac,
          deleted: item.deleted,
        ),
      );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('m99-recovery-order-');
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/local.sqlite'), key: 'm99-only-disposable-encrypted-vault-test-key',
    );
    outbox = WaffraEncryptedCloudOutbox(db);
  });
  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('M99 records publish and acknowledge before any manifest is visible',
      () async {
    // Queue the index FIRST to prove queue ordering cannot leak a premature
    // recovery snapshot even across a cold restart.
    await outbox.enqueue(vaultId: vault, envelope: await manifest());
    await outbox.enqueue(vaultId: vault, envelope: await entry('item-a'));
    await outbox.enqueue(vaultId: vault, envelope: await entry('item-b'));
    await db.close();
    db = WaffraEncryptedStore.openAt(
      File('${root.path}/local.sqlite'), key: 'm99-only-disposable-encrypted-vault-test-key',
    );
    outbox = WaffraEncryptedCloudOutbox(db);
    final events = <String>[];
    final coordinator = WaffraCloudManifestLastOutboxDrain(
      outbox: outbox,
      experimentalEnabled: true,
      verifyManifestReferences: (item) async {
        events.add('verify');
        return events.where((e) => e.startsWith('entry:')).length == 2;
      },
      publishMutation: (item, expected) async {
        events.add('${item.envelope.kind}:${item.envelope.recordId}');
        await acknowledge(item);
        return const WaffraCloudPublishResult(
          status: WaffraCloudPublishStatus.created,
        );
      },
    );
    final result = await coordinator.drain(
      vaultId: vault, authorization: authorized,
      expectedPreviousMutationId: (_) async => null,
    );
    expect(result.fullySynced, isTrue);
    expect(result.recordMutations, 2);
    expect(events, [
      'entry:item-a', 'entry:item-b', 'verify', 'manifest:finance-index',
    ]);
    expect(await outbox.pending(vaultId: vault), isEmpty);
  });

  test('M99 a failed upload must not advance or publish recovery manifest',
      () async {
    await outbox.enqueue(vaultId: vault, envelope: await manifest());
    await outbox.enqueue(vaultId: vault, envelope: await entry('item-a'));
    var manifestAttempted = false;
    final result = await WaffraCloudManifestLastOutboxDrain(
      outbox: outbox, experimentalEnabled: true,
      verifyManifestReferences: (_) async {
        manifestAttempted = true; return true;
      },
      publishMutation: (_, __) async => const WaffraCloudPublishResult(
        status: WaffraCloudPublishStatus.blocked,
      ),
    ).drain(
      vaultId: vault, authorization: authorized,
      expectedPreviousMutationId: (_) async => null,
    );
    expect(result.blocked, isTrue);
    expect(result.manifestCommitted, isFalse);
    expect(manifestAttempted, isFalse);
    expect(await outbox.pending(vaultId: vault), hasLength(2));
  });

  test('M99 two-phone conflict retains pending changes and blocks manifest',
      () async {
    await outbox.enqueue(vaultId: vault, envelope: await manifest());
    await outbox.enqueue(vaultId: vault, envelope: await entry('item-a'));
    final result = await WaffraCloudManifestLastOutboxDrain(
      outbox: outbox, experimentalEnabled: true,
      verifyManifestReferences: (_) async => true,
      publishMutation: (_, __) async => const WaffraCloudPublishResult(
        status: WaffraCloudPublishStatus.manualConflict,
      ),
    ).drain(
      vaultId: vault, authorization: authorized,
      expectedPreviousMutationId: (_) async => null,
    );
    expect(result.manualConflict, isTrue);
    expect(result.fullySynced, isFalse);
    expect(result.manifestCommitted, isFalse);
    expect(await outbox.pending(vaultId: vault), hasLength(2));
  });

  test('M99 incomplete remote receipts/revisions block index publication',
      () async {
    await outbox.enqueue(vaultId: vault, envelope: await manifest());
    var attempts = 0;
    final result = await WaffraCloudManifestLastOutboxDrain(
      outbox: outbox, experimentalEnabled: true,
      verifyManifestReferences: (_) async => false,
      publishMutation: (_, __) async {
        attempts++;
        return const WaffraCloudPublishResult(
          status: WaffraCloudPublishStatus.created,
        );
      },
    ).drain(
      vaultId: vault, authorization: authorized,
      expectedPreviousMutationId: (_) async => null,
    );
    expect(result.blocked, isTrue);
    expect(result.hasPending, isTrue);
    expect(attempts, 0);
    expect((await outbox.pending(vaultId: vault)).single
        .envelope.kind, 'manifest');
  });

  test('M99 cloud consent and mandatory previous revision fail closed',
      () async {
    await outbox.enqueue(
      vaultId: vault, envelope: await entry('item-a', version: 2),
    );
    var calls = 0;
    final coordinator = WaffraCloudManifestLastOutboxDrain(
      outbox: outbox, experimentalEnabled: true,
      verifyManifestReferences: (_) async => true,
      publishMutation: (_, __) async {
        calls++;
        return const WaffraCloudPublishResult(
          status: WaffraCloudPublishStatus.created,
        );
      },
    );
    final noConsent = await coordinator.drain(
      vaultId: vault,
      authorization: const WaffraCloudSyncAuthorization(),
      expectedPreviousMutationId: (_) async => null,
    );
    expect(noConsent.blocked, isTrue);
    final noWitness = await coordinator.drain(
      vaultId: vault, authorization: authorized,
      expectedPreviousMutationId: (_) async => null,
    );
    expect(noWitness.blocked, isTrue);
    expect(calls, 0);
    expect(await outbox.pending(vaultId: vault), hasLength(1));
  });
}

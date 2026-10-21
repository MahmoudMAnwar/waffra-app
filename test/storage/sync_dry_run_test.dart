import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_sync_dry_run.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

class FakeAtomicCreatePort implements WaffraAtomicCreatePort {
  final remote = <String, WaffraRemoteRevision>{};
  bool loseFirstReply = false;
  bool forceWrongReceipt = false;
  int calls = 0;

  String keyFor(WaffraCloudQueueItem item) =>
      item.vaultId + ':' + item.documentId;

  WaffraRemoteRevision revision(WaffraCloudQueueItem item) =>
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

  @override
  Future<WaffraAtomicCommitReceipt> createIfAbsent(
      WaffraCloudQueueItem item) async {
    calls++;
    final key = keyFor(item);
    final present = remote[key];
    if (present != null) {
      final action = WaffraEncryptedCloudOutbox.preflight(
        item: item, remote: present, consentGiven: true,
        identityVerified: true, recoveryReady: true,
        atomicRemoteTransportReady: true,
      );
      return WaffraAtomicCommitReceipt(
        status: action == WaffraRemoteAction.alreadyApplied
            ? WaffraAtomicCommitStatus.alreadyApplied
            : WaffraAtomicCommitStatus.conflict,
        confirmedRevision: present,
      );
    }
    remote[key] = revision(item);
    if (loseFirstReply) {
      loseFirstReply = false; // Simulate server commit, lost network response.
      throw StateError('Connection dropped after remote commit.');
    }
    if (forceWrongReceipt) {
      return WaffraAtomicCommitReceipt(
        status: WaffraAtomicCommitStatus.created,
        confirmedRevision: WaffraRemoteRevision(
          documentId: item.documentId,
          kind: item.envelope.kind,
          mutationId: 'wrong-mutation',
          deviceId: item.envelope.deviceId,
          localVersion: item.envelope.localVersion,
          ciphertext: item.envelope.ciphertext,
          nonce: item.envelope.nonce,
          mac: item.envelope.mac,
          deleted: item.deleted,
        ),
      );
    }
    return WaffraAtomicCommitReceipt(
      status: WaffraAtomicCommitStatus.created,
      confirmedRevision: remote[key],
    );
  }
}

void main() {
  late Directory sandbox;
  late WaffraEncryptedStore db;
  late WaffraEncryptedCloudOutbox outbox;
  late WaffraCloudCipher cipher;
  late FakeAtomicCreatePort remote;
  late WaffraSyncDryRunCoordinator coordinator;

  const ready = WaffraSyncReadiness(
    userConsented: true,
    accountOwnershipVerified: true,
    recoveryVerified: true,
    firestoreRulesVerified: true,
    regionAndBillingVerified: true,
    transactionalAdapterVerified: true,
  );

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-dryrun-');
    db = WaffraEncryptedStore.openAt(
      File(sandbox.path + '/vault.db'),
      key: 'testing-project-funds-not-production-32',
    );
    outbox = WaffraEncryptedCloudOutbox(db);
    cipher = WaffraCloudCipher();
    remote = FakeAtomicCreatePort();
    coordinator = WaffraSyncDryRunCoordinator(
      outbox: outbox, atomicPort: remote, experimentalEnabled: true);
  });
  tearDown(() async {
    await db.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Future<void> queue({
    String vault = 'vault-1',
    String entry = 'entry-1',
    String mutation = 'mutation-1',
    bool deleted = false,
  }) async {
    final envelope = await cipher.encrypt(
      vaultKey: await cipher.newRandomVaultKey(),
      vaultId: vault, kind: 'entry', recordId: entry,
      deviceId: 'phone-1', mutationId: mutation, localVersion: 1,
      record: {
        'id': entry, 'title': 'عملية سرية', 'category': 'مصروفات',
        'amount': 29.50, 'income': false, 'date': '2026-10-21T11:00:00',
      },
    );
    await outbox.enqueue(vaultId: vault, envelope: envelope, deleted: deleted);
  }

  test('both explicit feature gate and readiness are required', () async {
    await queue();
    final disabled = WaffraSyncDryRunCoordinator(
      outbox: outbox, atomicPort: remote);
    await expectLater(
      disabled.processOnce(vaultId: 'vault-1', readiness: ready),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      coordinator.processOnce(
        vaultId: 'vault-1', readiness: const WaffraSyncReadiness()),
      throwsA(isA<StateError>()),
    );
    expect(remote.calls, 0);
    expect((await outbox.pending(vaultId: 'vault-1')), hasLength(1));
  });

  test('atomic create and exact receipt safely acknowledge local queue',
      () async {
    await queue();
    final result = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(result.pendingAttempted, 1);
    expect(result.acknowledged, 1);
    expect(result.conflicts, 0);
    expect(result.retryLater, 0);
    expect(remote.remote.length, 1);
    expect((await outbox.pending(vaultId: 'vault-1')), isEmpty);
  });

  test('remote commit with lost reply replays idempotently', () async {
    await queue();
    remote.loseFirstReply = true;
    final first = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(first.acknowledged, 0);
    expect(first.retryLater, 1);
    expect(remote.remote.length, 1);
    expect((await outbox.pending(vaultId: 'vault-1')), hasLength(1));
    final retry = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(retry.acknowledged, 1);
    expect(remote.remote.length, 1);
    expect((await outbox.pending(vaultId: 'vault-1')), isEmpty);
  });

  test('two devices editing same record never last-write-win', () async {
    await queue();
    final item = (await outbox.pending(vaultId: 'vault-1')).single;
    remote.remote[remote.keyFor(item)] = WaffraRemoteRevision(
      documentId: item.documentId, kind: 'entry',
      mutationId: 'someone-else', deviceId: 'second-phone',
      localVersion: 2, ciphertext: item.envelope.ciphertext,
      nonce: item.envelope.nonce, mac: item.envelope.mac, deleted: false,
    );
    final report = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(report.conflicts, 1);
    expect(report.acknowledged, 0);
    expect((await outbox.pending(vaultId: 'vault-1')), hasLength(1));
  });

  test('tampered success receipt must not lose a queued operation', () async {
    await queue();
    remote.forceWrongReceipt = true;
    final result = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(result.retryLater, 1);
    expect(result.acknowledged, 0);
    expect((await outbox.pending(vaultId: 'vault-1')), hasLength(1));
    remote.forceWrongReceipt = false;
    final retry = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(retry.acknowledged, 1);
    expect((await outbox.pending(vaultId: 'vault-1')), isEmpty);
  });

  test('vault isolation and deletion are only encrypted tombstone creation',
      () async {
    await queue(vault: 'vault-1', mutation: 'delete-1', deleted: true);
    await queue(vault: 'vault-2', mutation: 'regular-2');
    final a = await coordinator.processOnce(
      vaultId: 'vault-1', readiness: ready);
    expect(a.acknowledged, 1);
    expect((await outbox.pending(vaultId: 'vault-2')), hasLength(1));
    expect(remote.remote.values.single.deleted, isTrue);
    final b = await coordinator.processOnce(
      vaultId: 'vault-2', readiness: ready);
    expect(b.acknowledged, 1);
    expect(remote.remote.values.length, 2);
    expect(remote.remote.values.where((x) => x.deleted).length, 1);
  });
}

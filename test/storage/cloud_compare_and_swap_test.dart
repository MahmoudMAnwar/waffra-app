import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_compare_and_swap.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  WaffraCloudQueueItem queued({
    int version = 1,
    String mutation = 'device-a-1',
    String ciphertext = 'YWJj',
  }) {
    const recordId = 'transaction-111';
    const kind = 'entry';
    return WaffraCloudQueueItem(
      vaultId: 'private-user-vault',
      documentId: WaffraEncryptedCloudOutbox.documentId(kind, recordId),
      envelope: WaffraEncryptedCloudRecord(
        kind: kind,
        recordId: recordId,
        deviceId: 'device-a',
        mutationId: mutation,
        localVersion: version,
        ciphertext: ciphertext,
        nonce: 'AAAAAAAAAAAAAAAA',
        mac: 'AAAAAAAAAAAAAAAAAAAAAA==',
      ),
      deleted: false,
    );
  }

  WaffraRemoteRevision remote({
    int version = 1,
    String mutation = 'device-a-1',
    String ciphertext = 'YWJj',
  }) {
    final item = queued();
    return WaffraRemoteRevision(
      documentId: item.documentId,
      kind: item.envelope.kind,
      mutationId: mutation,
      deviceId: 'device-a',
      localVersion: version,
      ciphertext: ciphertext,
      nonce: item.envelope.nonce,
      mac: item.envelope.mac,
      deleted: false,
    );
  }

  test('first encrypted record can only be created at revision one', () {
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(),
      remote: null,
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.create);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(version: 2),
      remote: null,
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(),
      remote: null,
      expectedPreviousMutationId: 'unknown',
    ), WaffraCloudCasAction.manualConflict);
  });

  test('same cryptographic mutation can retry after remote confirmation', () {
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(),
      remote: remote(),
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.alreadyApplied);
  });

  test('second encrypted revision advances only from exact predecessor', () {
    final next = queued(version: 2, mutation: 'device-b-2',
      ciphertext: 'ZGVm');
    expect(WaffraCloudCompareAndSwap.plan(
      item: next,
      remote: remote(),
      expectedPreviousMutationId: 'device-a-1',
    ), WaffraCloudCasAction.advance);
    expect(WaffraCloudCompareAndSwap.plan(
      item: next,
      remote: remote(),
      expectedPreviousMutationId: 'stale-device-observation',
    ), WaffraCloudCasAction.manualConflict);
    expect(WaffraCloudCompareAndSwap.plan(
      item: next,
      remote: remote(),
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
  });

  test('two-device collision, jumping generations and equal-version overwrite are rejected',
      () {
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(version: 2, mutation: 'device-b-2'),
      remote: remote(version: 2, mutation: 'device-a-2'),
      expectedPreviousMutationId: 'device-a-1',
    ), WaffraCloudCasAction.manualConflict);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(version: 3, mutation: 'device-b-3'),
      remote: remote(version: 1, mutation: 'device-a-1'),
      expectedPreviousMutationId: 'device-a-1',
    ), WaffraCloudCasAction.manualConflict);
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(version: 1, mutation: 'forged'),
      remote: remote(version: 1),
      expectedPreviousMutationId: 'device-a-1',
    ), WaffraCloudCasAction.manualConflict);
  });

  test('remote ciphertext mismatch with same mutation fails closed', () {
    expect(WaffraCloudCompareAndSwap.plan(
      item: queued(),
      remote: remote(ciphertext: 'tampered-remote'),
      expectedPreviousMutationId: null,
    ), WaffraCloudCasAction.manualConflict);
  });
}

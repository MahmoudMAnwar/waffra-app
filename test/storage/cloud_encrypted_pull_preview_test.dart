import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_cloud_encrypted_pull_preview.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  const kind = 'entry';
  const recordId = 'test-entry-111';
  final id = WaffraEncryptedCloudOutbox.documentId(kind, recordId);

  Map<String, dynamic> metadata() => {
    'kind': kind,
    'ciphertext': 'YWJj',
    'nonce': 'AAAAAAAAAAAAAAAA',
    'mac': 'AAAAAAAAAAAAAAAAAAAAAA==',
    'encryptionVersion': 1,
    'deviceId': 'first-test-device',
    'mutationId': 'safe-mutation-1',
    'localVersion': 1,
    'updatedAt': 'a-server-timestamp-validated-by-firestore-rules',
    'deleted': false,
  };

  test('M69 preview reconstructs only a known encrypted identity', () {
    final value = WaffraCloudEncryptedPullPreview.parseEnvelope(
      kind: kind, recordId: recordId, documentId: id,
      remote: metadata(),
    );
    expect(value.recordId, recordId);
    expect(value.localVersion, 1);
    expect(value.mutationId, 'safe-mutation-1');
  });

  test('M69 forged identity, unknown fields and plaintext finance are refused', () {
    for (final data in [
      {...metadata(), 'amount': 100},
      {...metadata(), 'bankAccount': 'should-never-upload'},
      {...metadata(), 'kind': 'goal'},
      {...metadata(), 'encryptionVersion': 2},
      {...metadata(), 'localVersion': 0},
      {...metadata()}..remove('mac'),
    ]) {
      expect(() => WaffraCloudEncryptedPullPreview.parseEnvelope(
        kind: kind, recordId: recordId, documentId: id, remote: data,
      ), throwsA(isA<StateError>()));
    }
    expect(() => WaffraCloudEncryptedPullPreview.parseEnvelope(
      kind: kind, recordId: 'different-record', documentId: id,
      remote: metadata(),
    ), throwsA(isA<StateError>()));
  });
}

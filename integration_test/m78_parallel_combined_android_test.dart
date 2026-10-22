import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_atomic_encrypted_receipt_transaction_writer.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_cloud_cipher.dart';
import 'package:waffra/storage/waffra_cloud_compare_and_swap.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_sync_outbox.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'M78 Android real SQLCipher: atomic encrypted images plus isolated two-device collision',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      final root = await (await getTemporaryDirectory())
          .createTemp('waffra-m78-android-');
      const secret = 'm78-disposable-native-sqlcipher-key';
      WaffraEncryptedStore? store;
      try {
        final dbFile = File('${root.path}/m78-secure.sqlite');
        store = WaffraEncryptedStore.openAt(dbFile, key: secret);
        await WaffraFreshEncryptedVaultBootstrap(
          store: store,
          experimentalEnabled: true,
        ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
        final snapshot = WaffraAtomicFinanceSnapshot(
          store: store, experimentalEnabled: true,
        );
        await snapshot.initializeEmpty();
        final receipts = WaffraEncryptedReceiptVault(
          store: store, experimentalEnabled: true,
        );
        final writer = WaffraAtomicEncryptedReceiptTransactionWriter(
          snapshot: snapshot,
          receiptVault: receipts,
          writerDirectory: root,
          experimentalEnabled: true,
          // Only the isolated test vault is verified here. Production source
          // activation must provide a durable under-lock witness.
          verifySourceUnderLock: () async {},
        );
        const digest =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        final record = <String, Object?>{
          'id': 'm78-groceries',
          'title': 'Private groceries',
          'category': 'Shopping',
          'amount': 24.75,
          'income': false,
          'date': '2026-10-22T12:00:00',
          'receiptPath': null,
        };
        final saved = await writer.save(
          record: record,
          receiptImages: [Uint8List.fromList([1, 3, 5, 7])],
          userConfirmed: true,
          smsHash: digest,
        );
        expect(saved.generation, 1);
        expect(saved.receiptCount, 1);
        expect((await receipts.readAll('m78-groceries')).single.bytes,
            [1, 3, 5, 7]);
        await expectLater(writer.save(
          record: {...record, 'id': 'duplicate-SMS'},
          receiptImages: [Uint8List.fromList([8])],
          userConfirmed: true,
          smsHash: digest,
        ), throwsA(isA<StateError>()));
        expect((await snapshot.read()).generation, 1);
        final rows = jsonDecode(
          (await snapshot.read()).values['entries'] as String,
        ) as List;
        expect(rows.length, 1);

        final cloud = WaffraCloudCipher();
        final cloudKey = await cloud.newRandomVaultKey();
        Future<WaffraEncryptedCloudRecord> encrypted(
            String device, String mutation) => cloud.encrypt(
          vaultKey: cloudKey,
          vaultId: 'isolated-vault',
          kind: 'entry',
          recordId: 'm78-groceries',
          deviceId: device,
          mutationId: mutation,
          localVersion: 1,
          record: {...record, 'receiptPath': '/local-only/invoice.jpg'},
        );
        final a = await encrypted('device-A', 'device-A-1');
        final b = await encrypted('device-B', 'device-B-1');
        final remote = WaffraRemoteRevision(
          documentId: WaffraEncryptedCloudOutbox.documentId(
              'entry', 'm78-groceries'),
          kind: a.kind,
          mutationId: a.mutationId,
          deviceId: a.deviceId,
          localVersion: a.localVersion,
          ciphertext: a.ciphertext,
          nonce: a.nonce,
          mac: a.mac,
          deleted: false,
        );
        final contender = WaffraCloudQueueItem(
          vaultId: 'isolated-vault',
          documentId: remote.documentId,
          envelope: b,
          deleted: false,
        );
        expect(WaffraCloudCompareAndSwap.plan(
          item: contender,
          remote: remote,
          expectedPreviousMutationId: null,
        ), WaffraCloudCasAction.manualConflict);
        final decrypted = await cloud.decrypt(
          vaultKey: cloudKey, vaultId: 'isolated-vault', envelope: a,
        );
        expect(decrypted['amount'], 24.75);
        expect(decrypted.containsKey('receiptPath'), isFalse);
        await store.close();
        store = null;

        store = WaffraEncryptedStore.openAt(dbFile, key: secret);
        final cold = await WaffraAtomicFinanceSnapshot(
          store: store, experimentalEnabled: true,
        ).read();
        expect(cold.generation, 1);
        expect(cold.values['waffra_sms_hashes_v1'], [digest]);
        final attachments = await WaffraEncryptedReceiptVault(
          store: store, experimentalEnabled: true,
        ).readAll('m78-groceries');
        expect(attachments.single.bytes, [1, 3, 5, 7]);
      } finally {
        await store?.close();
        if (await root.exists()) await root.delete(recursive: true);
      }
    },
  );
}

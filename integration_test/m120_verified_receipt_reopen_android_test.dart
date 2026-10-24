import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/legacy_snapshot_preflight.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_cutover_journal.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('M120 Android SQLCipher receipt view/recycle/restore survives cold reopen',
      (tester) async {
    expect(Platform.isAndroid, true);
    final dir = await (await getTemporaryDirectory())
        .createTemp('m120-disposable-receipt-screen-');
    final file = File('${dir.path}/finance.sqlite');
    const key = 'm120-disposable-android-key-only';
    const id = 'm120-test-receipt';
    final start = DateTime.utc(2026, 10, 23);
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    WaffraEncryptedStore? store;
    try {
      store = WaffraEncryptedStore.openAt(file, key: key);
      WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
        store: store!, experimentalEnabled: true,
      );
      WaffraEncryptedCutoverJournal journal() => WaffraEncryptedCutoverJournal(
        store: store!, snapshot: snapshot(), experimentalEnabled: true,
      );
      WaffraVerifiedEncryptedFinanceBridge bridge() =>
          WaffraVerifiedEncryptedFinanceBridge(
            snapshot: snapshot(),
            cutoverJournal: journal(),
            writerDirectory: dir,
            allWritersRoutedVerified: true,
            secureKeyVerified: true,
            experimentalEnabled: true,
          );
      await WaffraFreshEncryptedVaultBootstrap(
        store: store, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      await snapshot().initializeEmpty();
      final initialized = await snapshot().commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: const {'entries': '[]'},
      );
      await journal().prepare(
        sourceDigest: WaffraLegacyPreflight.inspect(
          {'entries': '[]'},
        ).sourceSha256,
        targetDigest: initialized.digest,
        now: start,
      );
      await journal().verify(now: start);
      await journal().acknowledgeExternalActivation(
        externalMarkerVerified: true,
        allWritersRouted: true,
        now: start,
      );
      final original = [
        Uint8List.fromList([1, 2, 3, 4]),
        Uint8List.fromList([5, 6, 7]),
      ];
      final added = await bridge().appendConfirmedWithReceiptBytes(
        record: {
          'id': id,
          'title': 'Synthetic offline purchase',
          'category': 'Food',
          'amount': 64.25,
          'income': false,
          'date': '2026-10-23T09:00:00',
          'receiptPath': null,
        },
        images: original,
        userConfirmed: true,
      );
      expect(added.receiptCount, 2);
      final screen = await bridge().loadVerifiedReceiptScreen(id);
      expect(screen.images.map((x) => x.toList()).toList(),
          [[1, 2, 3, 4], [5, 6, 7]]);
      expect(screen.imageSha256, hasLength(2));

      // Simulate an actual app process closing its encrypted DB handle.
      await store.close();
      store = null;
      final signature = await file.openRead(0, 16).toList();
      expect(signature.expand((chunk) => chunk).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
      store = WaffraEncryptedStore.openAt(file, key: key);
      final reopened = await bridge().loadVerifiedReceiptScreen(id);
      expect(reopened.images.map((x) => x.toList()).toList(),
          [[1, 2, 3, 4], [5, 6, 7]]);
      expect(reopened.generation, screen.generation);

      final recycled = await bridge().moveReceiptBatchToRecycle(
        baseline: reopened,
        userConfirmed: true,
        now: start,
      );
      expect(recycled.receiptCount, 2);
      await store.close();
      store = null;
      store = WaffraEncryptedStore.openAt(file, key: key);
      final archived = await bridge().loadVerifiedReceiptScreen(id);
      expect(archived.images, isEmpty);
      expect(archived.isInRecycleBin, true);
      expect(archived.recoverUntilMs,
          start.add(const Duration(days: 30)).millisecondsSinceEpoch);

      final restored = await bridge().restoreReceiptBatchFromRecycle(
        baseline: archived,
        now: start.add(const Duration(days: 29)),
      );
      expect(restored.receiptCount, 2);
      await store.close();
      store = null;
      store = WaffraEncryptedStore.openAt(file, key: key);
      final recovered = await bridge().loadVerifiedReceiptScreen(id);
      expect(recovered.images.map((x) => x.toList()).toList(),
          [[1, 2, 3, 4], [5, 6, 7]]);
      expect(recovered.isInRecycleBin, false);
      expect(recovered.generation, screen.generation + 2);
      final ledger = await snapshot().read();
      expect(ledger.values['entries'], contains('"amount":64.25'));
      expect(ledger.values['entries'], contains(id));

      // A pending source marker must stop all encrypted UI reads.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
      await expectLater(bridge().loadVerifiedReceiptScreen(id),
          throwsStateError);
      await prefs.remove(WaffraLiveLegacyFinanceGuard.pendingKey);
      expect((await bridge().loadVerifiedReceiptScreen(id)).images, hasLength(2));
      // No user production DB, real Firebase or device gallery touched.
    } finally {
      await store?.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });
}

import 'dart:convert';
import 'dart:io';

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

  testWidgets('Android verified SQLCipher home/widget finance survives restart',
      (tester) async {
    expect(Platform.isAndroid, true);
    final directory = await (await getTemporaryDirectory())
        .createTemp('m61-isolated-encrypted-bridge-');
    final db = File('${directory.path}/finance.sqlite');
    const key = 'android-m61-only-disposable-secret-key';
    const hash =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    SharedPreferences.setMockInitialValues({
      'entries': '[]',
      'waffra_language': 'ar',
      WaffraLiveLegacyFinanceGuard.activeKey: true,
    });
    WaffraEncryptedStore? vault;
    try {
      vault = WaffraEncryptedStore.openAt(db, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      WaffraAtomicFinanceSnapshot snapshot() => WaffraAtomicFinanceSnapshot(
            store: vault!, experimentalEnabled: true,
          );
      WaffraEncryptedCutoverJournal cutover() => WaffraEncryptedCutoverJournal(
            store: vault!, snapshot: snapshot(), experimentalEnabled: true,
          );
      WaffraVerifiedEncryptedFinanceBridge bridge() =>
          WaffraVerifiedEncryptedFinanceBridge(
            snapshot: snapshot(),
            cutoverJournal: cutover(),
            writerDirectory: directory,
            allWritersRoutedVerified: true,
            secureKeyVerified: true,
            experimentalEnabled: true,
          );

      await snapshot().initializeEmpty();
      final migration = await snapshot().commit(
        expectedGeneration: 0,
        fullFinanceSnapshot: const {
          'entries': '[]',
          'waffra_goals_v24':
              '[{"id":"vacation","name":"Vacation","target":1000,"saved":100}]',
        },
      );
      final oldDigest = WaffraLegacyPreflight.inspect({
        'entries': '[]',
      }).sourceSha256;
      await cutover().prepare(
        sourceDigest: oldDigest,
        targetDigest: migration.digest,
        now: DateTime.utc(2026, 10, 22),
      );
      await cutover().verify(now: DateTime.utc(2026, 10, 22));
      await cutover().acknowledgeExternalActivation(
        externalMarkerVerified: true,
        allWritersRouted: true,
        now: DateTime.utc(2026, 10, 22),
      );

      final home = await bridge().loadForHomeAndWidget();
      expect(home.generation, 1);
      final added = await bridge().appendConfirmedTransactions(
        records: [{
          'id': 'android-widget-1',
          'title': 'POS',
          'category': 'Groceries',
          'amount': 28.75,
          'income': false,
          'date': '2026-10-21T19:00:00',
          'receiptPath': null,
        }],
        messageHashes: [hash],
        userConfirmed: true,
      );
      expect(added.saved, 1);

      final edited = await bridge().saveHomeChanges(
        baseline: home,
        replacements: const {
          'waffra_goals_v24':
              '[{"id":"vacation","name":"Vacation","target":1000,"saved":200}]',
        },
        changedKeys: const {'waffra_goals_v24'},
      );
      expect(edited.generation, 3);
      expect(edited.values['entries'], contains('android-widget-1'));
      expect(edited.values['waffra_sms_hashes_v1'], [hash]);

      await vault.close();
      vault = null;
      final prefix = await db.openRead(0, 16).toList();
      final bytes = prefix.expand((segment) => segment).toList();
      expect(bytes,
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
      vault = WaffraEncryptedStore.openAt(db, key: key);
      final cold = await bridge().loadForHomeAndWidget();
      expect(cold.generation, 3);
      expect((jsonDecode(cold.ledgerRaw!) as List), hasLength(1));
      expect(cold.finance.getString('waffra_goals_v24'),
          contains('"saved":200'));

      final original = await SharedPreferences.getInstance();
      expect(original.getString('entries'), '[]');
      expect(original.getString('waffra_language'), 'ar');
      expect(original.getBool(WaffraLiveLegacyFinanceGuard.activeKey), isTrue);
      // The source selector remains a synthetic test witness. No actual
      // user vault, Firebase service, or production marker is touched.
    } finally {
      await vault?.close();
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  });
}

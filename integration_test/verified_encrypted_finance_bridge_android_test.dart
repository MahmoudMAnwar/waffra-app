import 'dart:async';
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
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_verified_encrypted_finance_bridge.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android verified SQLCipher home/widget finance survives restart',
      (tester) async {
    expect(Platform.isAndroid, true);
    Future<T> checkpoint<T>(String phase, Future<T> Function() action) async {
      // Diagnostic breadcrumbs are deliberately free from financial values,
      // encryption keys and bank SMS data.
      // ignore: avoid_print
      print('M66_ANDROID_BRIDGE_START:$phase');
      final value = await action().timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'M66 Android bridge timeout at $phase (45 seconds).',
        ),
      );
      // ignore: avoid_print
      print('M66_ANDROID_BRIDGE_PASS:$phase');
      return value;
    }
    final directory = await checkpoint('private-dir', () async =>
      (await getTemporaryDirectory()).createTemp('m61-isolated-encrypted-bridge-'));
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
      await checkpoint('bootstrap', () => WaffraFreshEncryptedVaultBootstrap(
        store: vault!, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate));
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

      await checkpoint('initialize-empty', () => snapshot().initializeEmpty());
      // Seed the disposable normalized SQL goal alongside its snapshot.
      // The UI editor must reject absent/forged rows instead of repairing
      // them, so a test fixture needs to satisfy that same source contract.
      final migration = await checkpoint('commit-migration', () =>
          vault!.transaction(() async {
            final committed = await snapshot().commit(
              expectedGeneration: 0,
              fullFinanceSnapshot: const {
                'entries': '[]',
                'waffra_goals_v24':
                    '[{"id":"vacation","name":"Vacation","target":1000,"saved":100}]',
              },
            );
            await WaffraFreshModulesRepository(
              store: vault!, experimentalEnabled: true,
            ).save(WaffraFinanceModule.goals, const {
              'id': 'vacation', 'name': 'Vacation',
              'target': 1000, 'saved': 100,
            });
            return committed;
          }));
      final seededGoals = await checkpoint('verify-goal-projection', () =>
          WaffraFreshModulesRepository(
            store: vault!, experimentalEnabled: true,
          ).list(WaffraFinanceModule.goals));
      expect(seededGoals, [const {
        'id': 'vacation', 'name': 'Vacation',
        'target': 1000, 'saved': 100,
      }]);
      final oldDigest = WaffraLegacyPreflight.inspect({
        'entries': '[]',
      }).sourceSha256;
      await checkpoint('prepare-cutover', () => cutover().prepare(
        sourceDigest: oldDigest,
        targetDigest: migration.digest,
        now: DateTime.utc(2026, 10, 22),
      ));
      await checkpoint('verify-cutover', () => cutover().verify(now: DateTime.utc(2026, 10, 22)));
      await checkpoint('acknowledge-cutover', () => cutover().acknowledgeExternalActivation(
        externalMarkerVerified: true,
        allWritersRouted: true,
        now: DateTime.utc(2026, 10, 22),
      ));

      final home = await checkpoint('load-home', () => bridge().loadForHomeAndWidget());
      expect(home.generation, 1);
      final added = await checkpoint('widget-sms-save', () => bridge().appendConfirmedTransactions(
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
      ));
      expect(added.saved, 1);

      final edited = await checkpoint('home-goal-save', () => bridge().saveHomeChanges(
        baseline: home,
        replacements: const {
          'waffra_goals_v24':
              '[{"id":"vacation","name":"Vacation","target":1000,"saved":200}]',
        },
        changedKeys: const {'waffra_goals_v24'},
      ));
      expect(edited.generation, 3);
      expect(edited.values['entries'], contains('android-widget-1'));
      expect(edited.values['waffra_sms_hashes_v1'], [hash]);

      await checkpoint('cold-close', () => vault!.close());
      vault = null;
      final prefix = await db.openRead(0, 16).toList();
      final bytes = prefix.expand((segment) => segment).toList();
      expect(bytes,
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
      vault = WaffraEncryptedStore.openAt(db, key: key);
      final cold = await checkpoint('cold-reload', () => bridge().loadForHomeAndWidget());
      expect(cold.generation, 3);
      expect((jsonDecode(cold.ledgerRaw!) as List), hasLength(1));
      expect(cold.finance.getString('waffra_goals_v24'),
          contains('"saved":200'));
      final persistedGoals = await checkpoint('cold-goal-projection', () =>
          WaffraFreshModulesRepository(
            store: vault!, experimentalEnabled: true,
          ).list(WaffraFinanceModule.goals));
      expect(persistedGoals, [const {
        'id': 'vacation', 'name': 'Vacation',
        'target': 1000, 'saved': 200,
      }]);

      final original = await checkpoint('prefs-check', () => SharedPreferences.getInstance());
      expect(original.getString('entries'), '[]');
      expect(original.getString('waffra_language'), 'ar');
      expect(original.getBool(WaffraLiveLegacyFinanceGuard.activeKey), isTrue);
      // The source selector remains a synthetic test witness. No actual
      // user vault, Firebase service, or production marker is touched.
    } finally {
      final current = vault;
      if (current != null) await checkpoint('cleanup-db', () => current.close());
      if (await directory.exists()) {
        await checkpoint('cleanup-temp-files', () => directory.delete(recursive: true));
      }
    }
  });
}

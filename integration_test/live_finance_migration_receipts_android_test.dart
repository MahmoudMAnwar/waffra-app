import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_finance_migration_rehearsal.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_legacy_receipt_integrity_auditor.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android finance copy and receipt-byte preflight survive restart',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, true);
    final temp = await (await getTemporaryDirectory())
        .createTemp('waffra-migration-preflight-android-');
    final receiptDir = await Directory('${temp.path}/receipts').create();
    final first = File('${receiptDir.path}/one.png');
    final second = File('${receiptDir.path}/two.jpg');
    await first.writeAsBytes([1, 2, 3, 4, 5], flush: true);
    await second.writeAsBytes([6, 7, 8], flush: true);
    final oldEntries = jsonEncode([
      {
        'id': 'old-expense',
        'title': 'مشتريات',
        'category': 'تسوق',
        'amount': 22.75,
        'income': false,
        'date': '2026-10-21T14:00:00',
        'receiptPath': jsonEncode([first.path, second.path]),
      },
      {
        'id': 'old-income',
        'title': 'دخل سابق',
        'category': 'راتب',
        'amount': 5000,
        'income': true,
        'date': '2026-10-20T14:00:00',
        'receiptPath': null,
      },
    ]);
    final oldGoal = jsonEncode([
      {'id': 'goal-one', 'name': 'رحلة', 'target': 4000, 'saved': 180},
    ]);
    // Mock only; NEVER load or change a real device user's preferences.
    SharedPreferences.setMockInitialValues({
      'entries': oldEntries,
      'waffra_goals_v24': oldGoal,
      'waffra_sms_hashes_v1': <String>['already-reviewed-message'],
      'waffra_monthly_budget_v1': 1200.0,
      'waffra_language': 'ar',
      'waffra_profile': '{"source":"synthetic"}',
    });

    final dbFile = File('${temp.path}/finance.sqlcipher');
    const key = 'offline-migration-test-only-secret-32';
    WaffraEncryptedStore? vault;
    try {
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: WaffraFirstRunDecision.freshCandidate);
      final snapshot = WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      );
      final coordinator = WaffraLegacyFinanceWriterCoordinator(
        testDirectory: temp,
      );
      final migration = await WaffraFinanceMigrationRehearsal(
        encrypted: snapshot,
        coordinator: coordinator,
        experimentalEnabled: true,
      ).run();
      expect(migration.itemCounts['entries'], 2);
      expect(migration.itemCounts['waffra_goals_v24'], 1);
      expect(migration.legacyReceiptReferences, 2);
      expect(migration.needsReceiptMigration, true);
      final audit = await WaffraLegacyReceiptIntegrityAuditor(
        coordinator: coordinator,
        trustedRoots: [receiptDir],
        experimentalEnabled: true,
      ).audit();
      expect(audit.referenceCount, 2);
      expect(audit.totalBytes, 8);
      expect(audit.financeSourceDigest, migration.legacyDigest);
      expect(audit.receipts.map((r) => r.sha256Hex).toSet(), {
        sha256.convert([1, 2, 3, 4, 5]).toString(),
        sha256.convert([6, 7, 8]).toString(),
      });

      await vault.close();
      vault = null;
      final plainHeader = await dbFile.openRead(0, 16).toList();
      expect(plainHeader.expand((list) => list).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      final verified = await WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      ).read();
      expect(verified.generation, 1);
      expect(verified.digest, migration.encryptedDigest);
      expect(verified.values['entries'], oldEntries);
      expect(verified.values['waffra_goals_v24'], oldGoal);
      final legacy = await SharedPreferences.getInstance();
      expect(legacy.getString('entries'), oldEntries);
      expect(legacy.getString('waffra_profile'),
          '{"source":"synthetic"}');
      expect(legacy.containsKey(WaffraLiveLegacyFinanceGuard.activeKey),
          false);

      // One missing old image must block "ready" even though the financial
      // SQLCipher snapshot remains intact. No silent attachment omissions.
      await second.delete();
      await expectLater(
        WaffraLegacyReceiptIntegrityAuditor(
          coordinator: coordinator,
          trustedRoots: [receiptDir],
          experimentalEnabled: true,
        ).audit(),
        throwsA(isA<StateError>()),
      );
      expect((await WaffraAtomicFinanceSnapshot(
        store: vault, experimentalEnabled: true,
      ).read()).digest, migration.encryptedDigest);
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}

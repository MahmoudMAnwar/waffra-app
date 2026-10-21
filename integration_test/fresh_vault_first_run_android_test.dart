import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';

/// Android/iOS offline rehearsal only. Uses a temporary encrypted file and
/// NEVER reads app SharedPreferences, actual receipt files or Firebase.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('brand new phone uses an empty encrypted ledger and reopens',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    const classifier = WaffraFirstRunClassifier();
    final decision = classifier.decide(
      existingPreferences: const {},
      encryptedVaultFileExists: false,
      activationMarkerExists: false,
    );
    expect(decision, WaffraFirstRunDecision.freshCandidate);

    final parent = await getTemporaryDirectory();
    final temp = await parent.createTemp('waffra-new-ledger-mobile-');
    final dbFile = File('${temp.path}/encrypted-finance.sqlite');
    const key = 'ephemeral-device-test-key-32-characters';
    WaffraEncryptedStore? vault;
    try {
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      final first = await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: decision);
      expect(first.isNew, isTrue);
      final repository = WaffraFreshLedgerRepository(
        store: vault, experimentalEnabled: true,
      );
      final zero = await repository.totals();
      expect(zero.count, 0);
      expect(zero.incomeMinor, 0);
      expect(zero.expenseMinor, 0);

      await repository.add(const WaffraFreshLedgerEntry(
        id: 'temporary-expense',
        title: 'تجربة مشتريات',
        categorySnapshot: 'مأكولات',
        amountMinor: 975,
        isIncome: false,
        occurredIso: '2026-10-21T14:00:00',
      ));
      await repository.add(const WaffraFreshLedgerEntry(
        id: 'temporary-income',
        title: 'Temporary salary',
        categorySnapshot: 'Income',
        amountMinor: 100025,
        isIncome: true,
        occurredIso: '2026-10-20T14:00:00',
      ));
      expect((await repository.totals()).expenseMinor, 975);
      expect((await repository.totals()).incomeMinor, 100025);
      await vault.close();
      vault = null;

      final plaintextSignature = await dbFile.openRead(0, 16).toList();
      expect(plaintextSignature.expand((part) => part).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));

      // Reopen without resetting values, keys or schema. No sample objects
      // are manufactured by the bootstrap on an existing vault.
      vault = WaffraEncryptedStore.openAt(dbFile, key: key);
      final again = await WaffraFreshEncryptedVaultBootstrap(
        store: vault, experimentalEnabled: true,
      ).initialize(decision: decision);
      expect(again.isNew, false);
      final restored = WaffraFreshLedgerRepository(
        store: vault, experimentalEnabled: true,
      );
      final rows = await restored.list();
      expect(rows, hasLength(2));
      expect(rows.first.title, 'تجربة مشتريات');
      expect(rows.first.amountMinor, 975);
      expect((await restored.totals()).count, 2);

      await restored.remove('temporary-expense');
      expect((await restored.totals()).expenseMinor, 0);
      expect((await restored.totals()).incomeMinor, 100025);
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });

  testWidgets('even zero old transactions cannot be reset as fresh',
      (tester) async {
    const classifier = WaffraFirstRunClassifier();
    final decision = classifier.decide(
      existingPreferences: const {'entries': '[]'},
      encryptedVaultFileExists: false,
      activationMarkerExists: false,
    );
    expect(decision, WaffraFirstRunDecision.legacyNeedsReview);

    final parent = await getTemporaryDirectory();
    final temp = await parent.createTemp('waffra-protect-legacy-');
    WaffraEncryptedStore? vault;
    try {
      final file = File('${temp.path}/blocked.sqlite');
      vault = WaffraEncryptedStore.openAt(
        file, key: 'isolated-existing-data-test-key-32',
      );
      await expectLater(
        WaffraFreshEncryptedVaultBootstrap(
          store: vault, experimentalEnabled: true,
        ).initialize(decision: decision),
        throwsA(isA<StateError>()),
      );
      final rows = await vault.customSelect(
        "SELECT name FROM sqlite_master "
        "WHERE name='fresh_finance_meta'",
      ).get();
      expect(rows, isEmpty);
    } finally {
      await vault?.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    }
  });
}

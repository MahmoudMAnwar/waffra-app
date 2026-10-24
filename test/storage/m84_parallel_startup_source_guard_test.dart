import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

/// M84 independent startup safety tests. No production file, key or switch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory sandbox;
  const syntheticKey = 'm84-private-test-only-key';

  File vaultFile() => File(
    '${sandbox.path}/${WaffraEncryptedStore.encryptedDatabaseFilename}',
  );

  WaffraProductionFinanceSourceGuard guard({
    String? key,
    String? phase,
    bool badProbe = false,
  }) => WaffraProductionFinanceSourceGuard(
    directoryProvider: () async => sandbox,
    secureKeyReader: () async => key,
    checkpointReader: (_, candidateKey) async {
      expect(candidateKey, syntheticKey);
      if (badProbe) throw StateError('simulated unreadable encrypted data');
      return phase;
    },
  );

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('waffra-m84-source-');
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"legacy-preserved"}]',
    });
  });
  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M84 truly legacy source remains readable without a shadow vault',
      () async {
    final result = await guard().inspect();
    expect(result.source, WaffraProductionFinanceSource.guardedLegacy);
    await guard().requireSafeLegacyStartup();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('legacy-preserved'));
  });

  test('M84 orphan file, lost key or key without file blocks legacy fallback',
      () async {
    expect((await guard(key: syntheticKey).inspect()).reasonCode,
        'vault_key_file_mismatch');
    await vaultFile().writeAsBytes([12, 34, 56]);
    expect((await guard().inspect()).reasonCode, 'vault_key_file_mismatch');
    await expectLater(guard().requireSafeLegacyStartup(),
        throwsA(isA<StateError>()));
  });

  test('M84 verified/active SQL witness without prefs marker cannot reset data',
      () async {
    await vaultFile().writeAsBytes([12, 34, 56]);
    for (final phase in ['verified', 'active']) {
      final result = await guard(key: syntheticKey, phase: phase).inspect();
      expect(result.source,
          WaffraProductionFinanceSource.manualRecoveryRequired);
      expect(result.reasonCode, 'orphaned_sql_activation_witness');
    }
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('legacy-preserved'));
  });

  test('M84 matching activation witnesses still require encrypted UI routing',
      () async {
    await vaultFile().writeAsBytes([12, 34, 56]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    final result = await guard(key: syntheticKey, phase: 'active')
        .inspect(preferences: prefs);
    expect(result.source,
        WaffraProductionFinanceSource.encryptedRoutingRequired);
    await expectLater(
      guard(key: syntheticKey, phase: 'active')
          .requireSafeLegacyStartup(preferences: prefs),
      throwsA(isA<StateError>()),
    );
    expect(prefs.getString('entries'), contains('legacy-preserved'));
  });

  test('M84 unreadable candidate never initializes blank financial data',
      () async {
    await vaultFile().writeAsBytes([12, 34, 56]);
    final result = await guard(
      key: syntheticKey, badProbe: true,
    ).inspect();
    expect(result.reasonCode, 'encrypted_source_probe_failed');
    expect(await vaultFile().readAsBytes(), [12, 34, 56]);
    expect((await SharedPreferences.getInstance()).getString('entries'),
        contains('legacy-preserved'));
  });
}

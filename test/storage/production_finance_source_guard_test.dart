import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  const key = 'existing-test-only-encrypted-vault-key';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('waffra-source-m71-');
    SharedPreferences.setMockInitialValues({
      'entries': '[{"id":"unchanged-legacy-ledger"}]',
      'waffra_language': 'ar',
    });
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<void> writeVault() =>
      File('${directory.path}/waffra_shadow_v1.sqlite').writeAsBytes([17, 30, 55]);

  WaffraProductionFinanceSourceGuard guard({
    String? secureKey,
    String? sqlPhase,
    bool badCipher = false,
  }) => WaffraProductionFinanceSourceGuard(
    directoryProvider: () async => directory,
    secureKeyReader: () async => secureKey,
    checkpointReader: (_, candidateKey) async {
      expect(candidateKey, key);
      if (badCipher) throw StateError('unreadable vault');
      return sqlPhase;
    },
  );

  test('M71 legacy startup and writes remain enabled when no vault was created',
      () async {
    final result = await guard().inspect();
    expect(result.legacyIsSafe, isTrue);
    expect(result.source, WaffraProductionFinanceSource.guardedLegacy);
    await guard().requireSafeLegacyStartup();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('unchanged-legacy-ledger'));
  });

  test('M71 key without DB and DB without key both block startup and widget',
      () async {
    final missingDb = await guard(secureKey: key).inspect();
    expect(missingDb.reasonCode, 'vault_key_file_mismatch');
    await expectLater(guard(secureKey: key).requireSafeLegacyStartup(),
        throwsA(isA<StateError>()));
    await writeVault();
    final missingKey = await guard().inspect();
    expect(missingKey.reasonCode, 'vault_key_file_mismatch');
    await expectLater(guard().requireSafeLegacyStartup(),
        throwsA(isA<StateError>()));
  });

  test('M71 a shadow copy is NEVER promoted into the active source', () async {
    await writeVault();
    final result = await guard(secureKey: key).inspect();
    expect(result.legacyIsSafe, isTrue);
    expect(result.reasonCode, 'unactivated_encrypted_candidate');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('entries'), contains('unchanged-legacy-ledger'));
  });

  test('M71 an active orphan SQL witness blocks legacy fallback', () async {
    await writeVault();
    for (final phase in ['verified', 'active']) {
      final report = await guard(secureKey: key, sqlPhase: phase).inspect();
      expect(report.source, WaffraProductionFinanceSource.manualRecoveryRequired);
      expect(report.reasonCode, 'orphaned_sql_activation_witness');
    }
  });

  test('M71 pending, invalid or mismatched external activation never shows zero balance',
      () async {
    await writeVault();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.pendingKey, true);
    expect((await guard(secureKey: key).inspect()).reasonCode,
        'pending_source_transition');
    await prefs.remove(WaffraLiveLegacyFinanceGuard.pendingKey);

    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, false);
    expect((await guard(secureKey: key).inspect()).reasonCode,
        'invalid_activation_marker');
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    expect((await guard(secureKey: key).inspect()).reasonCode,
        'activation_witness_disagreement');
    final consistentSql = await guard(secureKey: key, sqlPhase: 'active').inspect();
    expect(consistentSql.source,
        WaffraProductionFinanceSource.encryptedRoutingRequired);
    await expectLater(
      guard(secureKey: key, sqlPhase: 'active').requireSafeLegacyStartup(),
      throwsA(isA<StateError>()),
    );
  });

  test('M71 wrong key, unreadable database and unsafe vault symlink fail closed',
      () async {
    await writeVault();
    expect((await guard(secureKey: key, badCipher: true).inspect()).reasonCode,
        'encrypted_source_probe_failed');

    final link = Link('${directory.path}/waffra_shadow_v1.sqlite');
    await File(link.path).delete();
    await link.create('${directory.path}/outside-file.sqlite');
    final report = await guard(secureKey: key).inspect();
    expect(report.reasonCode, 'unsafe_encrypted_vault_path');
  });

  test('M71 activation marker without real database always blocks', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    final report = await guard().inspect();
    expect(report.source, WaffraProductionFinanceSource.manualRecoveryRequired);
    expect(report.reasonCode, 'active_vault_missing');
  });
}

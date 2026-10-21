import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';

void main() {
  const classifier = WaffraFirstRunClassifier();
  const eligible = WaffraFirstRunDecision.freshCandidate;
  const legacy = WaffraFirstRunDecision.legacyNeedsReview;
  const inconsistent = WaffraFirstRunDecision.inconsistentState;

  WaffraFirstRunDecision classify(
    Map<String, Object?> prefs, {
    bool vaultExists = false,
    bool markerExists = false,
    bool anotherWriter = false,
  }) => classifier.decide(
    existingPreferences: prefs,
    encryptedVaultFileExists: vaultExists,
    activationMarkerExists: markerExists,
    independentWriterMayBeActive: anotherWriter,
  );

  group('first-run eligibility fails closed', () {
    test('true first run is eligible', () {
      expect(classify({}), eligible);
    });
    test('appearance settings alone do not force a legacy financial import', () {
      expect(classify({
        'waffra_language': 'en',
        'waffra_dark_mode': true,
        'waffra_hide_amounts': false,
        'waffra_allow_screenshots': true,
        'waffra_animation_level': 'reduced',
      }), eligible);
    });
    test('even empty legacy finance lists prevent fresh reset', () {
      expect(classify({'entries': '[]'}), legacy);
      expect(classify({'waffra_goals_v24': '[]'}), legacy);
      expect(classify({'waffra_sms_hashes_v1': <String>[]}), legacy);
      expect(classify({'waffra_monthly_budget_v1': 0.0}), legacy);
    });
    test('unknown keys and account/profile data are not silently dropped', () {
      expect(classify({'account_session': 'a-session'}), legacy);
      expect(classify({'waffra_widget_last_save_v1': 'date'}), legacy);
      expect(classify({'waffra_language': 'bad'}), legacy);
      expect(classify({'waffra_dark_mode': 'false'}), legacy);
    });
    test('preexisting vault never treated as brand new', () {
      expect(classify({}, vaultExists: true),
          WaffraFirstRunDecision.inconsistentState);
      expect(classify({}, vaultExists: true, markerExists: true),
          WaffraFirstRunDecision.encryptedVaultAlreadyPresent);
      expect(classify({}, markerExists: true), inconsistent);
    });
    test('another running widget writer blocks activation', () {
      expect(classify({}, anotherWriter: true), inconsistent);
    });
  });

  group('empty encrypted finance schema is isolated', () {
    late Directory temp;
    late WaffraEncryptedStore store;
    File dbFile() => File('${temp.path}/fresh.sqlite');
    const key = 'fresh-test-only-nonproduction-secret-32';
    WaffraFreshEncryptedVaultBootstrap bootstrap({bool enabled = true}) =>
        WaffraFreshEncryptedVaultBootstrap(
          store: store,
          experimentalEnabled: enabled,
        );

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('waffra-fresh-');
      store = WaffraEncryptedStore.openAt(dbFile(), key: key);
    });
    tearDown(() async {
      await store.close();
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    Future<int> count(String table) async {
      final result = await store.customSelect(
        'SELECT count(*) AS n FROM $table',
      ).getSingle();
      return result.read<int>('n');
    }

    test('feature flag blocks all schema creation', () async {
      await expectLater(bootstrap(enabled: false).initialize(
        decision: eligible,
      ), throwsA(isA<StateError>()));
      final tables = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE name = 'fresh_finance_meta'",
      ).get();
      expect(tables, isEmpty);
    });

    test('refuses legacy or inconsistent eligibility', () async {
      for (final decision in [
        legacy,
        inconsistent,
        WaffraFirstRunDecision.encryptedVaultAlreadyPresent,
      ]) {
        await expectLater(bootstrap().initialize(decision: decision),
            throwsA(isA<StateError>()));
      }
      final tables = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE name = 'fresh_finance_meta'",
      ).get();
      expect(tables, isEmpty);
    });

    test('brand-new vault contains schema but no sample money or entities',
        () async {
      final report = await bootstrap().initialize(decision: eligible);
      expect(report.isNew, isTrue);
      expect(report.schemaVersion, 1);
      for (final table in const [
        'fresh_finance_entries',
        'fresh_finance_categories',
        'fresh_finance_goals',
        'fresh_finance_recurring',
        'fresh_finance_receipts',
        'fresh_finance_settings',
        'fresh_finance_sms_hashes',
      ]) {
        expect(await count(table), 0, reason: table);
      }
      expect(await count('fresh_finance_meta'), 1);
    });

    test('reopening encrypted vault is idempotent and non-destructive',
        () async {
      final created = await bootstrap().initialize(decision: eligible);
      expect(created.isNew, true);
      await store.close();
      store = WaffraEncryptedStore.openAt(dbFile(), key: key);
      final again = await bootstrap().initialize(decision: eligible);
      expect(again.isNew, false);
      expect(again.schemaVersion, created.schemaVersion);
      expect(await count('fresh_finance_meta'), 1);
      expect(await count('fresh_finance_entries'), 0);
      final header = await dbFile().openRead(0, 16).toList();
      expect(header.expand((x) => x).toList(),
          isNot([83, 81, 76, 105, 116, 101, 32, 102,
                 111, 114, 109, 97, 116, 32, 51, 0]));
    });

    test('retry never erases a previously inserted row', () async {
      await bootstrap().initialize(decision: eligible);
      await store.customStatement(
        'INSERT INTO fresh_finance_entries '
        '(entry_id,title,category_snapshot,amount_minor,is_income,'
        'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,?,?)',
        ['test-only-id', 'Test', 'Food', 199, 0,
         '2026-10-21T12:00:00', 0, '{}'],
      );
      final again = await bootstrap().initialize(decision: eligible);
      expect(again.isNew, false);
      expect(await count('fresh_finance_entries'), 1);
    });

    test('shadow-staged data is protected from first-run initialization',
        () async {
      await store.stageSnapshot('protected-shadow', const {});
      await expectLater(
        bootstrap().initialize(decision: eligible),
        throwsA(isA<StateError>()),
      );
      final tables = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE name = 'fresh_finance_meta'",
      ).get();
      expect(tables, isEmpty);
    });

    test('unknown schema revision is rejected, not overwritten', () async {
      await bootstrap().initialize(decision: eligible);
      await store.customStatement(
        "UPDATE fresh_finance_meta SET schema_version = 999 "
        "WHERE slot = 'primary'",
      );
      await expectLater(
        bootstrap().initialize(decision: eligible),
        throwsA(isA<StateError>()),
      );
      final value = await store.customSelect(
        "SELECT schema_version FROM fresh_finance_meta "
        "WHERE slot = 'primary'",
      ).getSingle();
      expect(value.read<int>('schema_version'), 999);
    });

    test('currency and FK constraints reject invalid records', () async {
      await bootstrap().initialize(decision: eligible);
      await expectLater(
        store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,source_json) VALUES (?,?,?,?,?,?,?)',
          ['invalid', 'Test', 'Other', -100, 0,
           '2026-10-21T12:00:00', '{}'],
        ),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        store.customStatement(
          'INSERT INTO fresh_finance_receipts '
          '(entry_id,position,safe_filename,sha256_hex) VALUES (?,?,?,?)',
          ['nonexistent', 0, 'safe.bin', '00'],
        ),
        throwsA(isA<Exception>()),
      );
      expect(await count('fresh_finance_entries'), 0);
    });
  });
}

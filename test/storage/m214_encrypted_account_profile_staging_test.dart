import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_account_profile_stager.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_live_legacy_finance_guard.dart';
import 'package:waffra/storage/waffra_migration_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory sandbox;
  late File database;
  late WaffraEncryptedStore vault;
  const key = 'm214-test-os-credential-not-production';

  WaffraEncryptedAccountProfileStager stager() =>
      WaffraEncryptedAccountProfileStager(
        store: vault,
        legacyWriter: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: sandbox,
        ),
        experimentalEnabled: true,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': '[]',
      'waffra_profile': jsonEncode(<String, String>{
        'name': 'Synthetic Example',
        'email': 'test-profile-person@example.invalid',
        'provider': 'Google',
        'gender': 'ذكر',
        'avatar': 'person',
        'phone': '0500000000',
        'birthday': '2000-01-01T00:00:00.000',
      }),
      'waffra_registered_profile': jsonEncode(<String, String>{
        'name': 'Synthetic Example',
        'email': 'test-profile-person@example.invalid',
        'provider': 'Phone',
        'gender': '',
        'avatar': 'person',
        'phone': '0500000000',
        'birthday': '2000-01-01T00:00:00.000',
      }),
      'waffra_last_login_email': 'test-profile-person@example.invalid',
      'waffra_last_login_phone': '0500000000',
      'waffra_last_login_method': 'Phone',
      'waffra_signed_out_explicitly': true,
      'waffra_pin_sha256': 'synthetic-hash-not-a-real-pin',
      'waffra_language': 'ar',
      'waffra_appearance_mode_v1': 'light',
    });
    sandbox = await Directory.systemTemp.createTemp('m214-profile-');
    database = File('${sandbox.path}/account.sqlcipher');
    vault = WaffraEncryptedStore.openAt(database, key: key);
    // A profile must never migrate into a vault with no matching money
    // source. Seed this disposable database with that exact finance witness.
    final prefs = await SharedPreferences.getInstance();
    await vault.stageSnapshot(
      'synthetic-finance-owner',
      WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs),
    );
  });

  tearDown(() async {
    await vault.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('M214 stage only reviewed PII fields without changing legacy login',
      () async {
    final pref = await SharedPreferences.getInstance();
    final beforeProfile = pref.getString('waffra_registered_profile');
    final saved = await stager().stageLegacyProfile();
    expect(saved.records, 6);
    expect(saved.hasRegisteredProfile, isTrue);
    final rows = await vault.customSelect(
      'SELECT profile_key,profile_value FROM fresh_account_profile_staging',
    ).get();
    expect(rows.length, 6);
    final byKey = <String, String>{
      for (final row in rows)
        row.read<String>('profile_key'): row.read<String>('profile_value')
    };
    expect(byKey['waffra_registered_profile'], beforeProfile);
    expect(byKey['waffra_profile'], pref.getString('waffra_profile'));
    expect(byKey['waffra_signed_out_explicitly'], 'true');
    expect(byKey.containsKey('waffra_pin_sha256'), isFalse);
    expect(byKey.containsKey('waffra_language'), isFalse);
    expect(byKey.containsKey('waffra_appearance_mode_v1'), isFalse);
    await pref.reload();
    expect(pref.getString('waffra_registered_profile'), beforeProfile);
    expect(pref.getString('waffra_pin_sha256'),
        'synthetic-hash-not-a-real-pin');
    final again = await stager().stageLegacyProfile();
    expect(again.records, 6);
  });

  test('M214 cold SQLCipher reopen retains contact metadata encrypted on disk',
      () async {
    await stager().stageLegacyProfile();
    await vault.close();
    // Distinct literal synthetic contact values are not visible in the
    // SQLCipher database bytes even after the database handle is closed.
    final databaseBytes = await database.readAsBytes();
    final diskText = latin1.decode(databaseBytes);
    expect(diskText, isNot(contains('test-profile-person@example.invalid')));
    expect(diskText, isNot(contains('0500000000')));
    vault = WaffraEncryptedStore.openAt(database, key: key);
    final reread = await vault.customSelect(
      'SELECT profile_value FROM fresh_account_profile_staging '
      'WHERE profile_key = ?',
      variables: [Variable.withString('waffra_registered_profile')],
    ).getSingle();
    final user = jsonDecode(reread.read<String>('profile_value')) as Map;
    expect(user['phone'], '0500000000');
  });

  test('M214 different customer profile cannot overwrite a staged vault',
      () async {
    await stager().stageLegacyProfile();
    final prefs = await SharedPreferences.getInstance();
    final original = prefs.getString('waffra_profile')!;
    await prefs.setString('waffra_profile', jsonEncode(<String, String>{
      'name': 'Different synthetic account',
      'email': 'other@example.invalid',
    }));
    await expectLater(stager().stageLegacyProfile(), throwsStateError);
    final unchanged = await vault.customSelect(
      'SELECT profile_value FROM fresh_account_profile_staging '
      'WHERE profile_key = ?',
      variables: [Variable.withString('waffra_profile')],
    ).getSingle();
    expect(unchanged.read<String>('profile_value'), original);
  });

  test('M214 unknown/malformed sensitive profile refuses migration', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('waffra_profile', '{"name": "Example", "token": "x"}');
    await expectLater(stager().stageLegacyProfile(), throwsStateError);
    final tables = await vault.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE name='fresh_account_profile_staging'",
    ).get();
    expect(tables, isEmpty);
    await prefs.setString('waffra_profile', '[malformed');
    await expectLater(stager().stageLegacyProfile(), throwsA(anything));
  });

  test('M214 active finance source marker blocks legacy profile migration',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(WaffraLiveLegacyFinanceGuard.activeKey, true);
    await expectLater(stager().stageLegacyProfile(), throwsStateError);
    final tables = await vault.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE name='fresh_account_profile_staging'",
    ).get();
    expect(tables, isEmpty);
  });

  test('M214 changed legacy financial owner cannot stage profile',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('entries', jsonEncode([<String, Object?>{
      'id': 'different-owner-transaction',
      'title': 'Synthetic other owner',
      'category': 'Other',
      'amount': 12.50,
      'income': false,
      'date': '2026-10-25T10:00:00.000',
      'receiptPath': null,
    }]));
    await expectLater(stager().stageLegacyProfile(), throwsStateError);
    final rows = await vault.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE name='fresh_account_profile_staging'",
    ).get();
    expect(rows, isEmpty);
  });

  test('M214 disabled staging cannot access source or vault', () async {
    final disabled = WaffraEncryptedAccountProfileStager(
      store: vault,
      legacyWriter: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
      ),
    );
    await expectLater(disabled.stageLegacyProfile(), throwsStateError);
    final tables = await vault.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE name='fresh_account_profile_staging'",
    ).get();
    expect(tables, isEmpty);
  });
}

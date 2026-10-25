import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_account_profile_stager.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_migration_coordinator.dart';
import 'package:waffra/storage/waffra_verified_encrypted_account_profile_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const vaultId = 'm215-synthetic-vault';
  late Directory sandbox;
  late WaffraEncryptedStore store;
  late String digest;

  WaffraVerifiedEncryptedAccountProfileRead reader({bool enabled = true}) =>
      WaffraVerifiedEncryptedAccountProfileRead(
        store: store,
        experimentalEnabled: enabled,
      );

  Future<WaffraEncryptedAccountProfileCandidate> read() =>
      reader().readCandidate(
        expectedVaultId: vaultId,
        expectedSourceSha256: digest,
      );

  Future<void> stage() =>
      WaffraEncryptedAccountProfileStager(
        store: store,
        legacyWriter: WaffraLegacyFinanceWriterCoordinator(
          testDirectory: sandbox,
        ),
        experimentalEnabled: true,
      ).stageLegacyProfile().then((_) {});

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': '[]',
      'waffra_profile': jsonEncode(<String, String>{
        'name': 'Synthetic person',
        'email': 'profile-m215@example.invalid',
        'provider': 'Google',
        'gender': '',
        'avatar': 'person',
        'phone': '0500000000',
        'birthday': '2000-01-01T00:00:00.000',
      }),
      'waffra_registered_profile': jsonEncode(<String, String>{
        'name': 'Synthetic person',
        'email': 'profile-m215@example.invalid',
        'provider': 'Phone',
        'gender': '',
        'avatar': 'person',
        'phone': '0500000000',
        'birthday': '2000-01-01T00:00:00.000',
      }),
      'waffra_last_login_method': 'Phone',
      'waffra_last_login_email': 'profile-m215@example.invalid',
      'waffra_last_login_phone': '0500000000',
      'waffra_signed_out_explicitly': false,
      'waffra_pin_sha256': 'synthetic-pin-not-for-profile-store',
    });
    sandbox = await Directory.systemTemp.createTemp('m215-read-');
    store = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/profile.sqlcipher'),
      key: 'synthetic-m215-device-only-key',
    );
    final prefs = await SharedPreferences.getInstance();
    await store.stageSnapshot(
      vaultId,
      WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs),
    );
    final owner = await store.customSelect(
      'SELECT source_sha256 FROM shadow_migrations',
    ).getSingle();
    digest = owner.read<String>('source_sha256');
  });

  tearDown(() async {
    await store.close();
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('M215 candidate read is disabled by default', () async {
    await stage();
    await expectLater(
      reader(enabled: false).readCandidate(
        expectedVaultId: vaultId,
        expectedSourceSha256: digest,
      ),
      throwsStateError,
    );
  });

  test('M215 verified encrypted profile read preserves exact source bytes',
      () async {
    await stage();
    final snap = await read();
    final prefs = await SharedPreferences.getInstance();
    expect(snap.vaultId, vaultId);
    expect(snap.sourceSha256, digest);
    expect(snap.fields.length, 6);
    expect(snap.fields['waffra_profile'],
        prefs.getString('waffra_profile'));
    expect(snap.fields['waffra_registered_profile'],
        prefs.getString('waffra_registered_profile'));
    expect(snap.fields.containsKey('waffra_pin_sha256'), isFalse);
    expect(
      () => snap.fields['new'] = 'untrusted',
      throwsUnsupportedError,
    );
  });

  test('M215 missing encrypted profile stage cannot fall back to legacy',
      () async {
    await expectLater(read(), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_profile'), isNotNull);
  });

  test('M215 wrong vault and changed finance source witness are rejected',
      () async {
    await stage();
    await expectLater(
      reader().readCandidate(
        expectedVaultId: 'other-vault',
        expectedSourceSha256: digest,
      ),
      throwsStateError,
    );
    await expectLater(
      reader().readCandidate(
        expectedVaultId: vaultId,
        expectedSourceSha256: List<String>.filled(64, '0').join(),
      ),
      throwsStateError,
    );
  });

  test('M215 marker count mismatch refuses incomplete profile', () async {
    await stage();
    await store.customStatement(
      'UPDATE fresh_account_profile_stage_marker SET captured_count = 5',
    );
    await expectLater(read(), throwsStateError);
  });

  test('M215 missing completion witness fails closed', () async {
    await stage();
    await store.customStatement(
      'DELETE FROM fresh_account_profile_stage_marker',
    );
    await expectLater(read(), throwsStateError);
  });

  test('M215 unapproved credential-like account key refuses read',
      () async {
    await stage();
    await store.customStatement(
      'INSERT INTO fresh_account_profile_staging'
      '(profile_key,profile_value) VALUES (?,?)',
      ['waffra_pin_sha256', 'not-a-real-pin'],
    );
    // Keep the marker count valid; the check must reject the unknown key
    // itself, not merely a count larger than the six-key allowlist.
    await store.customStatement(
      'DELETE FROM fresh_account_profile_staging WHERE profile_key = ?',
      ['waffra_last_login_phone'],
    );
    await expectLater(read(), throwsStateError);
  });

  test('M215 malformed staged person JSON refuses read', () async {
    await stage();
    await store.customStatement(
      'UPDATE fresh_account_profile_staging SET profile_value = ? '
      'WHERE profile_key = ?',
      ['{"name":"Someone","token":"secret"}', 'waffra_profile'],
    );
    await expectLater(read(), throwsStateError);
  });

  test('M215 empty staged account stays a verified empty account',
      () async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in WaffraEncryptedAccountProfileStager.approvedProfileKeys) {
      await prefs.remove(key);
    }
    await stage();
    final snap = await read();
    expect(snap.fields, isEmpty);
    expect(snap.vaultId, vaultId);
  });

  test('M215 rejects invalid expected source witness without SQL reads',
      () async {
    await stage();
    await expectLater(
      reader().readCandidate(
        expectedVaultId: '',
        expectedSourceSha256: 'not-a-digest',
      ),
      throwsStateError,
    );
  });
}

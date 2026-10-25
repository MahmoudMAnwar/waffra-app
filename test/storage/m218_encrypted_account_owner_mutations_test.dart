import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/storage/waffra_encrypted_account_owner_mutations.dart';
import 'package:waffra/storage/waffra_encrypted_account_profile_stager.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_legacy_finance_writer_coordinator.dart';
import 'package:waffra/storage/waffra_migration_coordinator.dart';
import 'package:waffra/storage/waffra_production_finance_source_guard.dart';

class _FixedActiveSource extends WaffraProductionFinanceSourceGuard {
  const _FixedActiveSource(this.source);
  final WaffraProductionFinanceSource source;

  @override
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async => WaffraProductionFinanceSourceReport(
    source: source,
    reasonCode: 'synthetic-exact-test-only',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const vaultId = 'synthetic-m218-owner-vault';
  const uid = 'synthetic-firebase-user-1';
  const otherUid = 'synthetic-firebase-user-2';
  final key = List<int>.filled(32, 0x32);
  late Directory sandbox;
  late WaffraEncryptedStore store;
  late String digest;
  late String? currentUid;
  late List<int>? currentKey;
  late WaffraProductionFinanceSource selectedSource;

  WaffraEncryptedAccountOwnerMutations writer({bool enabled = true}) =>
      WaffraEncryptedAccountOwnerMutations(
        store: store,
        writerDirectory: sandbox,
        sourceGuard: _FixedActiveSource(selectedSource),
        currentAuthenticatedUid: () async => currentUid,
        readDeviceOwnerKey: () async => currentKey,
        experimentalEnabled: enabled,
      );

  Future<Map<String, String>> readFields() async {
    final rows = await store.customSelect(
      'SELECT profile_key,profile_value FROM fresh_account_profile_staging',
    ).get();
    return <String, String>{
      for (final row in rows)
        row.read<String>('profile_key'): row.read<String>('profile_value')
    };
  }

  Future<void> mutate({
    Map<String, String>? baseline,
    Map<String, String?> changes = const {'waffra_last_login_method': 'Phone'},
    String? expectedDigest,
  }) async {
    await writer().replaceFields(
      expectedVaultId: vaultId,
      expectedSourceSha256: expectedDigest ?? digest,
      expectedFields: baseline ?? await readFields(),
      changes: changes,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'entries': '[]',
      'waffra_profile': jsonEncode(<String, String>{
        'name': 'Synthetic account',
        'email': 'test-user@example.invalid',
        'provider': 'Google',
        'gender': '',
        'avatar': 'person',
        'phone': '0500000000',
        'birthday': '2000-01-01T00:00:00.000',
      }),
      'waffra_last_login_method': 'Google',
    });
    sandbox = await Directory.systemTemp.createTemp('m218-sql-account-');
    store = WaffraEncryptedStore.openAt(
      File('${sandbox.path}/owner.sqlcipher'),
      key: 'm218-disposable-test-key-not-for-users',
    );
    final prefs = await SharedPreferences.getInstance();
    await store.stageSnapshot(
      vaultId,
      WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs),
    );
    await WaffraEncryptedAccountProfileStager(
      store: store,
      legacyWriter: WaffraLegacyFinanceWriterCoordinator(
        testDirectory: sandbox,
      ),
      experimentalEnabled: true,
    ).stageLegacyProfile();
    digest = (await store.customSelect(
      'SELECT source_sha256 FROM shadow_migrations',
    ).getSingle()).read<String>('source_sha256');
    await store.customStatement('''
CREATE TABLE fresh_finance_cutover_checkpoint(
  singleton INTEGER PRIMARY KEY,
  phase TEXT NOT NULL
)''');
    await store.customStatement(
      'INSERT INTO fresh_finance_cutover_checkpoint'
      '(singleton,phase) VALUES (1,?)',
      ['active'],
    );
    await store.customStatement('''
CREATE TABLE fresh_account_profile_principal_binding(
  singleton INTEGER PRIMARY KEY,
  owner_hmac TEXT NOT NULL
)''');
    final hmac = WaffraEncryptedAccountOwnerMutations.ownerTag(
      deviceKey: key, uid: uid, vaultId: vaultId, sourceSha256: digest,
    );
    await store.customStatement(
      'INSERT INTO fresh_account_profile_principal_binding'
      '(singleton,owner_hmac) VALUES (1,?)', [hmac],
    );
    currentUid = uid;
    currentKey = key;
    selectedSource = WaffraProductionFinanceSource.encryptedRoutingRequired;
  });

  tearDown(() async {
    await store.close();
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('M218 atomic encrypted account update persists reviewed values',
      () async {
    final before = await readFields();
    final edited = await writer().replaceFields(
      expectedVaultId: vaultId,
      expectedSourceSha256: digest,
      expectedFields: before,
      changes: const <String, String?>{
        'waffra_last_login_method': 'Phone',
        'waffra_last_login_phone': '0509999999',
      },
    );
    expect(edited.fields['waffra_last_login_method'], 'Phone');
    expect(edited.fields['waffra_last_login_phone'], '0509999999');
    expect((await readFields()).length, before.length + 1);
    final marker = await store.customSelect(
      'SELECT captured_count FROM fresh_account_profile_stage_marker',
    ).getSingle();
    expect(marker.read<int>('captured_count'), before.length + 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('waffra_last_login_method'), 'Google');
    expect(prefs.getString('entries'), '[]');
  });

  test('M218 atomic encrypted signout preserves registered record', () async {
    final before = await readFields();
    final result = await writer().replaceFields(
      expectedVaultId: vaultId, expectedSourceSha256: digest,
      expectedFields: before, changes: const {
        'waffra_profile': null,
        'waffra_signed_out_explicitly': 'true',
      },
    );
    expect(result.fields.containsKey('waffra_profile'), isFalse);
    expect(result.fields['waffra_signed_out_explicitly'], 'true');
    expect((await readFields()).length, before.length);
  });

  test('M218 disabled account writer cannot touch an existing vault', () async {
    await expectLater(writer(enabled: false).replaceFields(
      expectedVaultId: vaultId, expectedSourceSha256: digest,
      expectedFields: await readFields(),
      changes: const {'waffra_last_login_method': 'Phone'},
    ), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 account switch cannot overwrite another owner vault', () async {
    currentUid = otherUid;
    await expectLater(mutate(), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 changed OS owner secret cannot overwrite a vault', () async {
    currentKey = List<int>.filled(32, 0x22);
    await expectLater(mutate(), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 missing OS owner key refuses account mutation', () async {
    currentKey = null;
    await expectLater(mutate(), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 uncertified or legacy source blocks encrypted mutation', () async {
    selectedSource = WaffraProductionFinanceSource.guardedLegacy;
    await expectLater(mutate(), throwsStateError);
    selectedSource = WaffraProductionFinanceSource.manualRecoveryRequired;
    await expectLater(mutate(), throwsStateError);
  });

  test('M218 absent principal witness blocks owner enrollment shortcut',
      () async {
    await store.customStatement(
      'DELETE FROM fresh_account_profile_principal_binding',
    );
    await expectLater(mutate(), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 stale account baseline fails closed without partial edits',
      () async {
    final before = await readFields();
    final stale = <String, String>{...before};
    stale['waffra_last_login_method'] = 'Local';
    await expectLater(mutate(baseline: stale), throwsStateError);
    expect((await readFields())['waffra_last_login_method'], 'Google');
  });

  test('M218 rejected PIN and token fields never enter encrypted profile',
      () async {
    for (final field in ['waffra_pin_sha256', 'auth_token']) {
      await expectLater(mutate(changes: {field: 'secret'}), throwsStateError);
    }
    expect((await readFields()).containsKey('waffra_pin_sha256'), isFalse);
  });

  test('M218 malformed profile JSON cannot be committed', () async {
    await expectLater(mutate(changes: const {
      'waffra_profile': '{"name":"Person","token":"secret"}',
    }), throwsStateError);
    expect((await readFields())['waffra_profile'], contains('Synthetic'));
  });

  test('M218 missing active cutover checkpoint refuses mutation', () async {
    await store.customStatement(
      'DELETE FROM fresh_finance_cutover_checkpoint',
    );
    await expectLater(mutate(), throwsStateError);
  });

  test('M218 changed legacy finance witness refuses account writes', () async {
    await expectLater(
      mutate(expectedDigest: List<String>.filled(64, '0').join()),
      throwsStateError,
    );
  });

  test('M218 invalid signed-out boolean fails before SQL writes', () async {
    await expectLater(mutate(changes: const {
      'waffra_signed_out_explicitly': 'maybe',
    }), throwsStateError);
  });
}

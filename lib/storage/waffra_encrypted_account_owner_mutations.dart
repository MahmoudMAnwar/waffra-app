import 'dart:convert';
import 'dart:io';


import 'waffra_encrypted_account_profile_stager.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_production_finance_source_guard.dart';
import 'waffra_verified_encrypted_account_profile_read.dart';

/// M218: an atomic SQLCipher *account* write path for a separately attested
/// active source. No caller in the shipped UI uses this class yet.
///
/// The binding table must ALREADY have been installed by a trustworthy
/// OS/Firebase owner-enrollment service. This code cannot enroll an identity,
/// create its own key, enable cutover, delete finance or fall back to
/// SharedPreferences. A migration is NOT authorized by an e-mail address.
class WaffraEncryptedAccountOwnerMutations {
  const WaffraEncryptedAccountOwnerMutations({
    required this.store,
    required this.writerDirectory,
    required this.sourceGuard,
    required this.currentAuthenticatedUid,
    required this.signOwnerChallenge,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final Directory writerDirectory;
  final WaffraProductionFinanceSourceGuard sourceGuard;

  /// Must resolve directly from an already-verified auth SDK session,
  /// never from text entered by the user or their editable profile fields.
  final Future<String?> Function() currentAuthenticatedUid;

  /// Must use a provisioned OS-backed HMAC key operation, not export the
  /// key bytes to Flutter. Returns only the lowercase hexadecimal MAC; do
  /// not derive the key from PIN, backup password or Firebase UID.
  final Future<String?> Function(List<int> challenge) signOwnerChallenge;
  final bool experimentalEnabled;

  static const Set<String> _personFields = <String>{
    'name', 'email', 'provider', 'gender', 'avatar', 'phone', 'birthday',
  };

  static void _requireValidValue(String key, String value) {
    if (value.length > 16384 ||
        (key != 'waffra_profile' &&
         key != 'waffra_registered_profile' && value.length > 1024)) {
      throw StateError('Encrypted account value exceeds reviewed schema.');
    }
    if (key == 'waffra_signed_out_explicitly') {
      if (value != 'true' && value != 'false') {
        throw StateError('Encrypted account sign-out flag is invalid.');
      }
      return;
    }
    if (key != 'waffra_profile' && key != 'waffra_registered_profile') return;
    Object? valueDecoded;
    try {
      valueDecoded = jsonDecode(value);
    } catch (_) {
      throw StateError('Encrypted account JSON is malformed.');
    }
    if (valueDecoded is! Map<String, dynamic> ||
        valueDecoded.keys.any((field) => !_personFields.contains(field)) ||
        valueDecoded.values.any((field) => field != null && field is! String)) {
      throw StateError('Encrypted account contains unapproved personal fields.');
    }
  }

  /// Canonical, domain-separated bytes signed by the OS device keystore.
  static List<int> ownerChallenge({
    required String uid,
    required String vaultId,
    required String sourceSha256,
  }) {
    if (uid.trim().isEmpty || vaultId.trim().isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(sourceSha256)) {
      throw StateError('Account enrollment evidence is invalid.');
    }
    return List<int>.unmodifiable(utf8.encode(jsonEncode([
      'waffra-profile-owner-v1', vaultId, sourceSha256, uid,
    ])));
  }

  /// Expected fields come from a previously verified SQLCipher read; a
  /// stale screen may NOT overwrite a concurrent login or widget change.
  /// Deleting a profile key uses null; PINs and OAuth credentials are banned.
  Future<WaffraEncryptedAccountProfileCandidate> replaceFields({
    required String expectedVaultId,
    required String expectedSourceSha256,
    required Map<String, String> expectedFields,
    required Map<String, String?> changes,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted account writes are not released.');
    }
    // Freeze *before* waiting on the cross-engine file lock or OS signer.
    // A caller may otherwise modify a Map after schema validation.
    final frozenExpected = Map<String, String>.unmodifiable(expectedFields);
    final frozenChanges = Map<String, String?>.unmodifiable(changes);
    if (frozenChanges.isEmpty) {
      throw StateError('No independently confirmed account changes.');
    }
    for (final entry in frozenChanges.entries) {
      if (!WaffraEncryptedAccountProfileStager.approvedProfileKeys
              .contains(entry.key)) {
        throw StateError('Unreviewed account field mutation denied.');
      }
      if (entry.value != null) _requireValidValue(entry.key, entry.value!);
    }
    for (final entry in frozenExpected.entries) {
      if (!WaffraEncryptedAccountProfileStager.approvedProfileKeys
              .contains(entry.key)) {
        throw StateError('Unreviewed account baseline denied.');
      }
      _requireValidValue(entry.key, entry.value);
    }
    return WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    ).withExclusiveAccess(() async {
      final selected = await sourceGuard.inspect();
      if (selected.source !=
          WaffraProductionFinanceSource.encryptedRoutingRequired) {
        throw StateError('A certified active SQLCipher source is required.');
      }
      final uid = await currentAuthenticatedUid();
      if (uid == null) {
        throw StateError('Authenticated account principal is missing.');
      }
      // The challenge is signed by an existing Android Keystore owner key.
      // Never load a raw owner MAC key into Dart or accept UI-supplied proofs.
      final tag = await signOwnerChallenge(ownerChallenge(
        uid: uid,
        vaultId: expectedVaultId,
        sourceSha256: expectedSourceSha256,
      ));
      if (tag == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(tag)) {
        throw StateError('Authenticated OS-protected account proof missing.');
      }
      return store.transaction(() async {
        final tables = await store.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
          "('shadow_migrations','fresh_finance_cutover_checkpoint',"
          "'fresh_account_profile_staging','fresh_account_profile_stage_marker',"
          "'fresh_account_profile_principal_binding')",
        ).get();
        if (tables.map((row) => row.read<String>('name')).toSet().length != 5) {
          throw StateError('Encrypted account release schema is incomplete.');
        }
        final phase = await store.customSelect(
          'SELECT phase FROM fresh_finance_cutover_checkpoint',
        ).get();
        if (phase.length != 1 ||
            phase.single.read<String>('phase') != 'active') {
          throw StateError('Finance source is not durably active.');
        }
        final finance = await store.customSelect(
          'SELECT vault_id,source_sha256 FROM shadow_migrations',
        ).get();
        if (finance.length != 1 ||
            finance.single.read<String>('vault_id') != expectedVaultId ||
            finance.single.read<String>('source_sha256') !=
                expectedSourceSha256) {
          throw StateError('Encrypted account financial source differs.');
        }
        final owner = await store.customSelect(
          'SELECT singleton,owner_hmac FROM '
          'fresh_account_profile_principal_binding',
        ).get();
        if (owner.length != 1 ||
            owner.single.read<int>('singleton') != 1 ||
            owner.single.read<String>('owner_hmac') != tag) {
          throw StateError('Encrypted account owner proof does not match.');
        }
        final marker = await store.customSelect(
          'SELECT singleton,captured_count FROM '
          'fresh_account_profile_stage_marker',
        ).get();
        if (marker.length != 1 ||
            marker.single.read<int>('singleton') != 1) {
          throw StateError('Encrypted profile staging witness is missing.');
        }
        final raw = await store.customSelect(
          'SELECT profile_key,profile_value FROM '
          'fresh_account_profile_staging',
        ).get();
        final before = <String, String>{};
        for (final row in raw) {
          final key = row.read<String>('profile_key');
          final value = row.read<String>('profile_value');
          if (!WaffraEncryptedAccountProfileStager.approvedProfileKeys
                  .contains(key) || before.containsKey(key)) {
            throw StateError('Encrypted account staging is unreviewed.');
          }
          _requireValidValue(key, value);
          before[key] = value;
        }
        if (before.length != marker.single.read<int>('captured_count') ||
            before.length != frozenExpected.length ||
            before.entries.any((e) => frozenExpected[e.key] != e.value)) {
          throw StateError('Encrypted account edit has stale source evidence.');
        }
        for (final entry in frozenChanges.entries) {
          if (entry.value == null) {
            await store.customStatement(
              'DELETE FROM fresh_account_profile_staging '
              'WHERE profile_key = ?', [entry.key],
            );
          } else {
            await store.customStatement(
              'INSERT INTO fresh_account_profile_staging '
              '(profile_key,profile_value) VALUES (?,?) '
              'ON CONFLICT(profile_key) DO UPDATE SET '
              'profile_value=excluded.profile_value',
              [entry.key, entry.value!],
            );
          }
        }
        final after = <String, String>{...before};
        for (final entry in frozenChanges.entries) {
          if (entry.value == null) {
            after.remove(entry.key);
          } else {
            after[entry.key] = entry.value!;
          }
        }
        await store.customStatement(
          'UPDATE fresh_account_profile_stage_marker '
          'SET captured_count = ? WHERE singleton = 1', [after.length],
        );
        // Verify the persisted row set, not merely the caller's proposal.
        final persisted = await store.customSelect(
          'SELECT profile_key,profile_value FROM '
          'fresh_account_profile_staging',
        ).get();
        if (persisted.length != after.length ||
            persisted.any((row) => after[row.read<String>('profile_key')] !=
                row.read<String>('profile_value'))) {
          throw StateError('SQLCipher account mutation parity mismatch.');
        }
        return WaffraEncryptedAccountProfileCandidate(
          vaultId: expectedVaultId,
          sourceSha256: expectedSourceSha256,
          fields: Map<String, String>.unmodifiable(after),
        );
      });
    });
  }
}

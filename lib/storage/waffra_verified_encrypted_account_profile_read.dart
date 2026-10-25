import 'dart:convert';

import 'waffra_encrypted_account_profile_stager.dart';
import 'waffra_encrypted_store.dart';

/// M215: read-only verification of an ALREADY-STAGED encrypted account
/// candidate. This is deliberately NOT connected to login, profile UI,
/// finance routing or production source selection.
class WaffraVerifiedEncryptedAccountProfileRead {
  const WaffraVerifiedEncryptedAccountProfileRead({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static const Set<String> _personFields = <String>{
    'name', 'email', 'provider', 'gender', 'avatar', 'phone', 'birthday',
  };

  static void _validateField(String key, String value) {
    if (value.length > 16384 ||
        (key != 'waffra_profile' &&
            key != 'waffra_registered_profile' &&
            value.length > 1024)) {
      throw StateError('Encrypted account field exceeds the approved bounds.');
    }
    if (key == 'waffra_signed_out_explicitly') {
      if (value != 'true' && value != 'false') {
        throw StateError('Encrypted account sign-out state is invalid.');
      }
      return;
    }
    if (key != 'waffra_profile' && key != 'waffra_registered_profile') {
      return;
    }
    try {
      final parsed = jsonDecode(value);
      if (parsed is! Map<String, dynamic> ||
          parsed.keys.any((name) => !_personFields.contains(name)) ||
          parsed.values.any((field) => field is! String && field != null)) {
        throw const FormatException('Unreviewed profile fields.');
      }
    } catch (_) {
      throw StateError('Encrypted account profile format is unverified.');
    }
  }

  /// The caller must obtain these two identifiers from independently
  /// authenticated finance-source evidence, not from UI preferences or
  /// untrusted screen input. An equal finance digest is NOT proof of the
  /// Firebase/account principal; production still requires account binding.
  ///
  /// A SQLCipher transaction gives one consistent view of the finance
  /// witness, completion marker and all encrypted account rows. No fallback
  /// to SharedPreferences exists, even when the candidate is absent.
  Future<WaffraEncryptedAccountProfileCandidate> readCandidate({
    required String expectedVaultId,
    required String expectedSourceSha256,
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted account candidate reading is disabled.');
    }
    if (expectedVaultId.trim().isEmpty ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(expectedSourceSha256)) {
      throw StateError('Independent finance source evidence is incomplete.');
    }
    return store.transaction(() async {
      final tables = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
        "('shadow_migrations','fresh_account_profile_staging',"
        "'fresh_account_profile_stage_marker')",
      ).get();
      final names = tables.map((row) => row.read<String>('name')).toSet();
      if (!names.containsAll(<String>{
        'shadow_migrations',
        'fresh_account_profile_staging',
        'fresh_account_profile_stage_marker',
      })) {
        throw StateError('Verified encrypted account staging is missing.');
      }

      final witnesses = await store.customSelect(
        'SELECT vault_id,source_sha256 FROM shadow_migrations',
      ).get();
      if (witnesses.length != 1 ||
          witnesses.single.read<String>('vault_id') != expectedVaultId ||
          witnesses.single.read<String>('source_sha256') !=
              expectedSourceSha256) {
        throw StateError('Encrypted account/finance witness mismatch.');
      }

      final markers = await store.customSelect(
        'SELECT singleton,captured_count FROM '
        'fresh_account_profile_stage_marker',
      ).get();
      if (markers.length != 1 ||
          markers.single.read<int>('singleton') != 1 ||
          markers.single.read<int>('captured_count') < 0 ||
          markers.single.read<int>('captured_count') >
              WaffraEncryptedAccountProfileStager.approvedProfileKeys.length) {
        throw StateError('Encrypted account completion witness is invalid.');
      }

      final rows = await store.customSelect(
        'SELECT profile_key,profile_value FROM fresh_account_profile_staging',
      ).get();
      if (rows.length != markers.single.read<int>('captured_count')) {
        throw StateError('Encrypted account staging is incomplete.');
      }
      final captured = <String, String>{};
      for (final row in rows) {
        final key = row.read<String>('profile_key');
        final value = row.read<String>('profile_value');
        if (!WaffraEncryptedAccountProfileStager.approvedProfileKeys
            .contains(key) || captured.containsKey(key)) {
          throw StateError('Encrypted account contains unapproved fields.');
        }
        _validateField(key, value);
        captured[key] = value;
      }
      return WaffraEncryptedAccountProfileCandidate(
        vaultId: expectedVaultId,
        sourceSha256: expectedSourceSha256,
        fields: Map<String, String>.unmodifiable(captured),
      );
    });
  }
}

/// Never log the payload: it may include contact details or account hints.
class WaffraEncryptedAccountProfileCandidate {
  const WaffraEncryptedAccountProfileCandidate({
    required this.vaultId,
    required this.sourceSha256,
    required this.fields,
  });

  final String vaultId;
  final String sourceSha256;
  final Map<String, String> fields;
}

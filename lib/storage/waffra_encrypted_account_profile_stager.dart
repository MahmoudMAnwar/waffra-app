import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_migration_coordinator.dart';
import 'legacy_snapshot_preflight.dart';

/// M214: copies account contact/profile metadata into the ALREADY-KEYED
/// SQLCipher candidate while Home and Widget are frozen by their native lock.
/// This is a non-destructive staging operation, not the live login repository
/// and never a source activation or account migration permission.
///
/// UI language/theme/onboarding are harmless device preferences. PIN hashes,
/// Firebase/Apple/Google tokens and the SQLCipher key MUST NOT be placed in
/// this profile table: the PIN needs a separate OS-backed credential migration.
class WaffraEncryptedAccountProfileStager {
  const WaffraEncryptedAccountProfileStager({
    required this.store,
    required this.legacyWriter,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final WaffraLegacyFinanceWriterCoordinator legacyWriter;
  final bool experimentalEnabled;

  static const Set<String> approvedProfileKeys = <String>{
    'waffra_profile',
    'waffra_registered_profile',
    'waffra_last_login_method',
    'waffra_last_login_email',
    'waffra_last_login_phone',
    'waffra_signed_out_explicitly',
  };

  static const _structuredProfiles = <String>{
    'waffra_profile',
    'waffra_registered_profile',
  };

  static const _personFields = <String>{
    'name', 'email', 'provider', 'gender', 'avatar', 'phone', 'birthday',
  };

  /// A blank/mobile-only profile is permitted, but unknown fields or a
  /// non-JSON profile must block migration rather than silently drop data.
  static void _validateProfileJson(String original) {
    if (original.isEmpty || original.length > 16384) {
      throw StateError('Account profile source is outside the safe bounds.');
    }
    final decoded = jsonDecode(original);
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.any((key) => !_personFields.contains(key)) ||
        decoded.values.any((value) => value is! String && value != null)) {
      throw StateError('Account profile fields require reviewed schema migration.');
    }
  }

  static Map<String, String> _capture(SharedPreferences prefs) {
    final captured = <String, String>{};
    final keys = prefs.getKeys();
    for (final name in approvedProfileKeys) {
      if (!keys.contains(name)) continue;
      if (name == 'waffra_signed_out_explicitly') {
        final v = prefs.getBool(name);
        if (v == null) {
          throw StateError('Account signed-out flag has an invalid source type.');
        }
        captured[name] = jsonEncode(v);
        continue;
      }
      final original = prefs.getString(name);
      if (original == null || original.length > 16384) {
        throw StateError('Account profile source has an invalid type or size.');
      }
      if (_structuredProfiles.contains(name)) {
        _validateProfileJson(original);
      } else if (original.length > 1024) {
        throw StateError('Account login hint exceeds approved size.');
      }
      captured[name] = original;
    }
    return Map<String, String>.unmodifiable(captured);
  }

  Future<WaffraEncryptedAccountProfileStageResult> stageLegacyProfile() {
    if (!experimentalEnabled) {
      throw StateError('Encrypted profile staging is disabled.');
    }
    // This method refuses an active/pending encrypted finance source and
    // replays both legacy journals BEFORE exposing a native preferences view.
    // Do NOT use an in-process-only mutex or remove the old account metadata.
    return legacyWriter.withCurrentPreferences((prefs) async {
      await prefs.reload();
      final frozen = _capture(prefs);
      // Refuse a vault staged for a different financial owner. Contact
      // metadata must only accompany the exact previously staged finance
      // source within the same native Home/Widget writer lease.
      final finance = WaffraMigrationCoordinator.copyCurrentFinancialPreferences(prefs);
      final preflight = WaffraLegacyPreflight.inspect(finance);
      if (!preflight.canStage) {
        throw StateError('Financial source is not valid for account staging.');
      }
      return store.transaction(() async {
        final financeJournal = await store.customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type='table' AND name='shadow_migrations'",
        ).get();
        if (financeJournal.length != 1) {
          throw StateError('Encrypted finance stage owner is not recorded.');
        }
        final stagedFinance = await store.customSelect(
          'SELECT source_sha256 FROM shadow_migrations',
        ).get();
        if (stagedFinance.length != 1 ||
            stagedFinance.single.read<String>('source_sha256') !=
                preflight.sourceSha256) {
          throw StateError('Encrypted finance owner does not match the profile.');
        }
        await store.customStatement('''
CREATE TABLE IF NOT EXISTS fresh_account_profile_staging(
 profile_key TEXT PRIMARY KEY NOT NULL,
 profile_value TEXT NOT NULL
)''');
        final existing = await store.customSelect(
          'SELECT profile_key,profile_value FROM fresh_account_profile_staging',
        ).get();
        if (existing.isNotEmpty) {
          // Idempotent re-stage only if *all* stored profile values match the
          // source exactly. Never overwrite a different staged customer.
          if (existing.length != frozen.length ||
              existing.any((row) {
                final key = row.read<String>('profile_key');
                return !frozen.containsKey(key) ||
                    frozen[key] != row.read<String>('profile_value');
              })) {
            throw StateError(
              'An unrelated encrypted profile already occupies this vault.',
            );
          }
        } else {
          for (final pair in frozen.entries) {
            await store.customStatement(
              'INSERT INTO fresh_account_profile_staging'
              '(profile_key,profile_value) VALUES (?,?)',
              [pair.key, pair.value],
            );
          }
        }
        final saved = await store.customSelect(
          'SELECT profile_key,profile_value FROM fresh_account_profile_staging',
        ).get();
        if (saved.length != frozen.length ||
            saved.any((row) =>
                frozen[row.read<String>('profile_key')] !=
                row.read<String>('profile_value'))) {
          throw StateError('Encrypted profile staging parity did not match.');
        }
        return WaffraEncryptedAccountProfileStageResult(
          records: frozen.length,
          hasRegisteredProfile:
              frozen.containsKey('waffra_registered_profile'),
        );
      });
    });
  }
}

/// No personal fields, phone numbers, emails or passwords are logged here.
class WaffraEncryptedAccountProfileStageResult {
  const WaffraEncryptedAccountProfileStageResult({
    required this.records,
    required this.hasRegisteredProfile,
  });

  final int records;
  final bool hasRegisteredProfile;
}

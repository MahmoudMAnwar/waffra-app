import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'waffra_encrypted_store.dart';
import 'waffra_live_legacy_finance_guard.dart';

enum WaffraProductionFinanceSource {
  /// The current shipped app/widget readers and writers may use legacy
  /// SharedPreferences behind the existing native transaction lock.
  guardedLegacy,

  /// An encrypted source appears active, but this release does not yet route
  /// ALL UI, widget, receipts, recurring and backup writers through SQLCipher.
  encryptedRoutingRequired,

  /// Inconsistent file/key/activation evidence. Neither source is safe.
  manualRecoveryRequired,
}

class WaffraProductionFinanceSourceReport {
  const WaffraProductionFinanceSourceReport({
    required this.source,
    required this.reasonCode,
  });

  final WaffraProductionFinanceSource source;
  final String reasonCode;
  bool get legacyIsSafe =>
      source == WaffraProductionFinanceSource.guardedLegacy;
}

/// Non-mutating startup check SHARED by HomeScreen and the separate widget
/// engine. Real storage file and OS-backed key presence are checked before
/// permitting current legacy finance reads/writes.
///
/// No key is ever generated, no empty vault is ever initialized, and no
/// user-visible finance is silently switched. An already active SQL witness
/// without its external pointer is treated as a recovery incident.
///
/// A future release can extend this with a real encrypted runtime adapter,
/// but must not treat encryptedRoutingRequired as permission to use legacy.
class WaffraProductionFinanceSourceGuard {
  const WaffraProductionFinanceSourceGuard({
    this.directoryProvider,
    this.secureKeyReader,
    this.checkpointReader,
  });

  final Future<Directory> Function()? directoryProvider;
  final Future<String?> Function()? secureKeyReader;

  /// Optional read-only SQL checkpoint inspector for deterministic tests.
  /// The default production function opens an EXISTING vault using its OS
  /// key, never writes source markers or changes schema.
  final Future<String?> Function(File file, String key)? checkpointReader;

  static const _active = WaffraLiveLegacyFinanceGuard.activeKey;
  static const _pending = WaffraLiveLegacyFinanceGuard.pendingKey;

  Future<String?> _readStoredKey() async {
    final custom = secureKeyReader;
    if (custom != null) return custom();
    const native = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return native.read(key: WaffraEncryptedStore.secureKeyStorageName);
  }

  Future<String?> _readSqlCutoverPhase(File file, String key) async {
    final custom = checkpointReader;
    if (custom != null) return custom(file, key);
    final store = WaffraEncryptedStore.openAt(file, key: key);
    try {
      // An existing shadow database may be a copy-only migration candidate.
      // sqlite_master is read-only and safe for older database schemas.
      final table = await store.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name='fresh_finance_cutover_checkpoint'",
      ).get();
      if (table.isEmpty) return null;
      final rows = await store.customSelect(
        'SELECT phase FROM fresh_finance_cutover_checkpoint '
        'WHERE singleton=1',
      ).get();
      if (rows.isEmpty) return null;
      if (rows.length != 1) {
        throw StateError('Duplicate encrypted activation witness.');
      }
      return rows.single.read<String>('phase');
    } finally {
      await store.close();
    }
  }

  /// An inspection result is diagnostic, NEVER a signal to perform cutover.
  /// The caller must keep the guarded legacy coordinator as the only writer
  /// whenever guardedLegacy is returned.
  Future<WaffraProductionFinanceSourceReport> inspect({
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.containsKey(_pending)) {
      return const WaffraProductionFinanceSourceReport(
        source: WaffraProductionFinanceSource.manualRecoveryRequired,
        reasonCode: 'pending_source_transition',
      );
    }
    final hasPointer = prefs.containsKey(_active);
    if (hasPointer && prefs.getBool(_active) != true) {
      return const WaffraProductionFinanceSourceReport(
        source: WaffraProductionFinanceSource.manualRecoveryRequired,
        reasonCode: 'invalid_activation_marker',
      );
    }

    try {
      final dir = directoryProvider != null
          ? await directoryProvider!()
          : await getApplicationSupportDirectory();
      final path = File(
        '${dir.path}${Platform.pathSeparator}'
        '${WaffraEncryptedStore.encryptedDatabaseFilename}',
      );
      final fileType = await FileSystemEntity.type(
        path.path, followLinks: false,
      );
      if (fileType != FileSystemEntityType.notFound &&
          fileType != FileSystemEntityType.file) {
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.manualRecoveryRequired,
          reasonCode: 'unsafe_encrypted_vault_path',
        );
      }
      final dbPresent = fileType == FileSystemEntityType.file;
      final key = await _readStoredKey();
      final keyPresent = key != null && key.isNotEmpty;
      if (keyPresent != dbPresent) {
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.manualRecoveryRequired,
          reasonCode: 'vault_key_file_mismatch',
        );
      }
      if (!dbPresent) {
        return hasPointer
            ? const WaffraProductionFinanceSourceReport(
                source: WaffraProductionFinanceSource.manualRecoveryRequired,
                reasonCode: 'active_vault_missing',
              )
            : const WaffraProductionFinanceSourceReport(
                source: WaffraProductionFinanceSource.guardedLegacy,
                reasonCode: 'legacy_source_verified',
              );
      }

      // Confirm existing data can actually be opened with the OS key:
      // incorrect keys or unreadable SQL must NEVER silently fall back.
      final phase = await _readSqlCutoverPhase(path, key!);
      if (phase != null &&
          phase != 'prepared' &&
          phase != 'verified' &&
          phase != 'active') {
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.manualRecoveryRequired,
          reasonCode: 'unrecognized_sql_cutover_phase',
        );
      }
      if (hasPointer && phase != 'active') {
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.manualRecoveryRequired,
          reasonCode: 'activation_witness_disagreement',
        );
      }
      if (!hasPointer && (phase == 'active' || phase == 'verified')) {
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.manualRecoveryRequired,
          reasonCode: 'orphaned_sql_activation_witness',
        );
      }
      if (hasPointer) {
        // SQL + preferences both claim active, but live legacy writers still
        // exist in main.dart/widget. Do not expose an unusable empty balance.
        return const WaffraProductionFinanceSourceReport(
          source: WaffraProductionFinanceSource.encryptedRoutingRequired,
          reasonCode: 'all_live_writers_not_yet_routed',
        );
      }
      // A staged but unactivated database is NEVER authoritative. Keep
      // the original guarded preferences for the current app release.
      return const WaffraProductionFinanceSourceReport(
        source: WaffraProductionFinanceSource.guardedLegacy,
        reasonCode: 'unactivated_encrypted_candidate',
      );
    } catch (_) {
      // OS keychain unavailable, wrong key, corrupt DB or unexpected storage
      // state: never initialize an empty finance source on exception.
      return const WaffraProductionFinanceSourceReport(
        source: WaffraProductionFinanceSource.manualRecoveryRequired,
        reasonCode: 'encrypted_source_probe_failed',
      );
    }
  }

  Future<void> requireSafeLegacyStartup({
    SharedPreferences? preferences,
  }) async {
    final result = await inspect(preferences: preferences);
    if (!result.legacyIsSafe) {
      // Only a redacted diagnostic is exposed. No user money, PIN, key,
      // user identifier, SMS text or local filesystem path is logged.
      throw StateError('Finance recovery is required: ${result.reasonCode}');
    }
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

enum WaffraCutoverPhase { prepared, verified, active }

enum WaffraCutoverRecoveryStatus {
  noCheckpoint,
  manualReconciliationRequired,
  encryptedReady,
}

class WaffraCutoverCheckpoint {
  const WaffraCutoverCheckpoint({
    required this.sourceDigest,
    required this.encryptedDigest,
    required this.phase,
  });

  final String sourceDigest;
  final String encryptedDigest;
  final WaffraCutoverPhase phase;
}

/// Durable, opt-in *experimental* transition checkpoints inside SQLCipher.
///
/// The live main.dart/Android widget are NOT yet routed to encrypted finance.
/// This component does not write a SharedPreferences activation pointer and
/// cannot activate the application by itself. It supports fail-closed replay
/// and evidence verification before a future durable two-witness cutover.
class WaffraEncryptedCutoverJournal {
  const WaffraEncryptedCutoverJournal({
    required this.store,
    required this.snapshot,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final WaffraAtomicFinanceSnapshot snapshot;
  final bool experimentalEnabled;
  static const _table = 'fresh_finance_cutover_checkpoint';

  static bool _isDigest(String value) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted finance cutover is disabled by default.');
    }
    final revision = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (revision.length != 1 ||
        revision.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Encrypted source is not initialized.');
    }
    final staged = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (staged.read<int>('n') != 0) {
      throw StateError('Unresolved staging vault blocks source activation.');
    }
  }

  Future<void> _ensureTable() async {
    await store.customStatement('''
CREATE TABLE IF NOT EXISTS $_table(
  singleton INTEGER PRIMARY KEY NOT NULL CHECK(singleton=1),
  source_digest TEXT NOT NULL,
  encrypted_digest TEXT NOT NULL,
  phase TEXT NOT NULL CHECK(phase IN ('prepared','verified','active')),
  modified_at_ms INTEGER NOT NULL
)''');
  }

  Future<WaffraCutoverCheckpoint?> _readOrNull() async {
    final found = await store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='$_table'",
    ).get();
    if (found.isEmpty) return null;
    final rows = await store.customSelect(
      'SELECT source_digest,encrypted_digest,phase FROM $_table '
      'WHERE singleton=1',
    ).get();
    if (rows.isEmpty) return null;
    if (rows.length != 1) throw StateError('Invalid cutover checkpoint count.');
    final row = rows.single;
    final source = row.read<String>('source_digest');
    final encrypted = row.read<String>('encrypted_digest');
    final name = row.read<String>('phase');
    if (!_isDigest(source) || !_isDigest(encrypted)) {
      throw StateError('Invalid cutover checksum encoding.');
    }
    final phase = WaffraCutoverPhase.values.where((e) => e.name == name);
    if (phase.length != 1) throw StateError('Unrecognized cutover phase.');
    return WaffraCutoverCheckpoint(
      sourceDigest: source,
      encryptedDigest: encrypted,
      phase: phase.single,
    );
  }

  Future<WaffraCutoverCheckpoint?> read() async {
    await _requireReady();
    return _readOrNull();
  }

  /// Call only with ALL legacy writers frozen, AFTER encrypted copy has been
  /// independently verified. Source digest must originate from the
  /// preflight-validated source, not be guessed from transaction count.
  Future<WaffraCutoverCheckpoint> prepare({
    required String sourceDigest,
    required String targetDigest,
    required DateTime now,
  }) async {
    if (!_isDigest(sourceDigest) || !_isDigest(targetDigest)) {
      throw ArgumentError('Cutover requires valid SHA-256 digests.');
    }
    return store.transaction(() async {
      await _requireReady();
      final encrypted = await snapshot.read();
      if (encrypted.digest != targetDigest) {
        throw StateError('Encrypted snapshot differs from candidate cutover.');
      }
      await _ensureTable();
      final existing = await _readOrNull();
      if (existing != null) {
        if (existing.sourceDigest != sourceDigest ||
            existing.encryptedDigest != targetDigest) {
          throw StateError('Cannot replace a previous cutover checkpoint.');
        }
        return existing;
      }
      await store.customStatement(
        'INSERT INTO $_table(singleton,source_digest,encrypted_digest,'
        'phase,modified_at_ms) VALUES(1,?,?,?,?)',
        [
          sourceDigest, targetDigest,
          WaffraCutoverPhase.prepared.name,
          now.toUtc().millisecondsSinceEpoch,
        ],
      );
      return (await _readOrNull())!;
    });
  }

  static bool _hasLegacyReceiptPaths(Map<String, Object?> values) {
    final raw = values['entries'];
    if (raw == null) return false;
    if (raw is! String) return true;
    final decoded = jsonDecode(raw);
    if (decoded is! List) return true;
    for (final entry in decoded) {
      if (entry is! Map) return true;
      final receipt = entry['receiptPath'];
      if (receipt != null &&
          (receipt is! String || receipt.trim().isNotEmpty)) {
        return true;
      }
    }
    return false;
  }

  /// Refuses 'verified' when encrypted bytes, financial digest, or external
  /// legacy receipt files have not been separately accounted for.
  Future<WaffraCutoverCheckpoint> verify({required DateTime now}) async {
    return store.transaction(() async {
      await _requireReady();
      final existing = await _readOrNull();
      if (existing == null) throw StateError('No prepared checkpoint.');
      if (existing.phase == WaffraCutoverPhase.active) return existing;
      final state = await snapshot.read();
      if (state.digest != existing.encryptedDigest ||
          _hasLegacyReceiptPaths(state.values)) {
        throw StateError(
          'Source/receipt parity is incomplete; refusing cutover.',
        );
      }
      await store.customStatement(
        "UPDATE $_table SET phase='verified',modified_at_ms=? "
        "WHERE singleton=1 AND phase IN ('prepared','verified')",
        [now.toUtc().millisecondsSinceEpoch],
      );
      return (await _readOrNull())!;
    });
  }

  /// A future source coordinator may record that its external active marker
  /// was independently verified. This never writes that marker itself.
  /// Activating production by calling this API alone is NOT sufficient.
  Future<WaffraCutoverCheckpoint> acknowledgeExternalActivation({
    required bool externalMarkerVerified,
    required bool allWritersRouted,
    required DateTime now,
  }) async {
    if (!externalMarkerVerified || !allWritersRouted) {
      throw StateError('Live source activation evidence is missing.');
    }
    return store.transaction(() async {
      await _requireReady();
      final before = await _readOrNull();
      if (before == null || before.phase == WaffraCutoverPhase.prepared) {
        throw StateError('Cannot activate an unverified cutover.');
      }
      final saved = await snapshot.read();
      if (saved.digest != before.encryptedDigest) {
        throw StateError('Cutover target changed after verification.');
      }
      await store.customStatement(
        "UPDATE $_table SET phase='active',modified_at_ms=? "
        "WHERE singleton=1 AND phase IN ('verified','active')",
        [now.toUtc().millisecondsSinceEpoch],
      );
      return (await _readOrNull())!;
    });
  }

  Future<WaffraCutoverRecoveryStatus> recover({
    required bool externalMarkerPresent,
    required bool encryptedKeyReadable,
    required bool allWritersRouted,
  }) async {
    await _requireReady();
    final evidence = await _readOrNull();
    if (evidence == null) {
      return externalMarkerPresent
          ? WaffraCutoverRecoveryStatus.manualReconciliationRequired
          : WaffraCutoverRecoveryStatus.noCheckpoint;
    }
    if (evidence.phase != WaffraCutoverPhase.active ||
        !externalMarkerPresent || !encryptedKeyReadable ||
        !allWritersRouted) {
      return WaffraCutoverRecoveryStatus.manualReconciliationRequired;
    }
    final current = await snapshot.read();
    return current.digest == evidence.encryptedDigest
        ? WaffraCutoverRecoveryStatus.encryptedReady
        : WaffraCutoverRecoveryStatus.manualReconciliationRequired;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_preferences_reader.dart';
import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_normalized_import.dart';

/// Explicit opt-in diagnostic staging; NEVER invoked on app startup.
///
/// Requires the caller to hold an app-wide financial write barrier. This
/// class does not and cannot pause the UI, recurring scheduler, SMS import,
/// home widget or background isolate on its own.
class WaffraShadowMigrationService {
  const WaffraShadowMigrationService();

  Future<ShadowMigrationResult> stageOnly({
    required SharedPreferences preferences,
    required String localVaultId,
    required bool financialWritersArePaused,
    WaffraEncryptedStore? encryptedStoreForTests,
  }) async {
    if (!financialWritersArePaused) {
      throw StateError('Refusing migration while financial writers are active.');
    }
    if (localVaultId.trim().isEmpty) {
      throw ArgumentError.value(localVaultId, 'localVaultId');
    }

    const reader = LegacyPreferencesSnapshotReader();
    final before = await reader.readStable(preferences);
    final beforeResult = WaffraLegacyPreflight.inspect(before);
    if (!beforeResult.canStage) {
      throw StateError('Legacy data failed financial preflight.');
    }

    final ownStore = encryptedStoreForTests == null;
    final store = encryptedStoreForTests ?? await WaffraEncryptedStore.openShadow();
    try {
      final normalized = await WaffraNormalizedImporter(store).stage(
        localVaultId, before,
      );

      // Spot concurrent mutation, despite requiring an external barrier.
      // The original preferences are not edited even if this check fails.
      final after = await reader.readStable(preferences);
      if (WaffraLegacyPreflight.inspect(after).sourceSha256 !=
          normalized.sourceSha256) {
        throw StateError('Legacy data changed during staging; no cutover permitted.');
      }

      return ShadowMigrationResult(
        sourceSha256: normalized.sourceSha256,
        transactions: normalized.entries,
        goals: normalized.goals,
        categories: normalized.categories,
        recurring: normalized.recurring,
        challenges: normalized.challenges,
        archivedRecords: normalized.trash,
        receiptReferences: normalized.receipts,
        incomeMinor: normalized.incomeMinor,
        expenseMinor: normalized.expenseMinor,
      );
    } finally {
      if (ownStore) await store.close();
    }
  }
}

class ShadowMigrationResult {
  const ShadowMigrationResult({
    required this.sourceSha256,
    required this.transactions,
    required this.goals,
    required this.categories,
    required this.recurring,
    required this.challenges,
    required this.archivedRecords,
    required this.receiptReferences,
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final String sourceSha256;
  final int transactions, goals, categories, recurring, challenges;
  final int archivedRecords, receiptReferences;
  final int incomeMinor, expenseMinor;
}

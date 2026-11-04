import 'dart:convert';

import 'legacy_snapshot_preflight.dart';
import 'waffra_production_finance_routing_gate.dart';
import 'waffra_verified_finance_authority.dart';

/// M451: One-time startup repair for an *authenticated fresh* SQLCipher vault.
///
/// M440 initialized a valid empty encrypted snapshot with ABSENT ledger and
/// categories. Home correctly refused to show a category-free source, leaving
/// new registrations on the financial recovery screen. Never substitute the
/// old SharedPreferences values or manufacture defaults for a migrated vault.
///
/// Only add missing empty-ledger/default-category fields, together in ONE
/// atomic SQLCipher snapshot + relational projection commit under the existing
/// Home/Widget lease and active source witnesses. Reopen the durable source
/// afterward. Any ambiguity fails closed without erasing the vault.
abstract final class WaffraFreshHomeCatalogRecovery {
  static Future<WaffraFinanceAuthorityRead> load({
    required WaffraVerifiedFinanceAuthority authority,
    required String defaultCategoriesJson,
  }) async {
    var current = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    current.finance.requireIntegrity();
    if (current.source != WaffraRuntimeFinanceBackend.verifiedEncrypted) {
      return current;
    }
    final missingLedger = !current.finance.containsKey('entries');
    final missingCategories =
        !current.finance.containsKey('waffra_categories_v24');
    if (!missingLedger && !missingCategories) return current;

    final witness = current.encryptedWitness;
    final session = authority.encryptedSession;
    if (authority.freshInstall == null || witness == null || session == null) {
      throw StateError(
        'Encrypted financial defaults cannot be repaired without '
        'an authenticated fresh-install origin.',
      );
    }

    final replacements = <String, Object?>{};
    if (missingLedger) replacements['entries'] = '[]';
    if (missingCategories) {
      final decoded = jsonDecode(defaultCategoriesJson);
      if (decoded is! List || decoded.isEmpty ||
          !WaffraLegacyPreflight.inspect(<String, Object?>{
            'waffra_categories_v24': defaultCategoriesJson,
          }).canStage) {
        throw StateError('Default categories did not pass finance preflight.');
      }
      replacements['waffra_categories_v24'] = defaultCategoriesJson;
    }

    // CAS rechecks every missing field and the SQL source inside the writer
    // lease. If a widget or another app engine changed them, it must refuse
    // the edit rather than replace the newly saved value.
    await session.saveChangedFields(
      baseline: witness,
      changedValues: replacements,
    );
    current = await authority.load(route: WaffraFinanceRoute.dashboardRead);
    current.finance.requireIntegrity();
    if (current.source != WaffraRuntimeFinanceBackend.verifiedEncrypted ||
        !current.finance.containsKey('entries') ||
        !current.finance.containsKey('waffra_categories_v24') ||
        (missingLedger && current.ledgerRaw != '[]') ||
        (missingCategories &&
            current.finance.getString('waffra_categories_v24') !=
                defaultCategoriesJson)) {
      throw StateError('Fresh encrypted Home defaults were not durable.');
    }
    return current;
  }
}

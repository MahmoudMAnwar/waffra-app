import 'dart:convert';

import 'waffra_fresh_finance_modules_repository.dart';

/// Validates that a financial module tile still represents the exact stored
/// entity, not a same-ID or same-name replacement made by another screen.
///
/// The source-selected Authority must still validate CAS+typed SQL under its
/// native Home/Widget lock; this guard is only the pre-confirmation UI witness.
class WaffraVerifiedModuleUiGuard {
  const WaffraVerifiedModuleUiGuard._();

  static String activeKey(WaffraFinanceModule module) => switch (module) {
    WaffraFinanceModule.categories => 'waffra_categories_v24',
    WaffraFinanceModule.goals => 'waffra_goals_v24',
    WaffraFinanceModule.recurring => 'waffra_recurring_v24',
  };

  static String trashKey(WaffraFinanceModule module) => switch (module) {
    WaffraFinanceModule.categories => 'waffra_deleted_categories_v1',
    WaffraFinanceModule.goals => 'waffra_deleted_goals_v1',
    WaffraFinanceModule.recurring => 'waffra_deleted_recurring_v1',
  };

  static String trashPayloadKey(WaffraFinanceModule module) =>
      module.name == 'categories' ? 'category' :
      module.name == 'goals' ? 'goal' : 'recurring';

  static List<Map<String, dynamic>> decodeRows(String? raw) {
    if (raw == null) {
      throw StateError('Verified financial module snapshot is unavailable.');
    }
    final value = jsonDecode(raw);
    if (value is! List) {
      throw StateError('Verified financial module snapshot is not a list.');
    }
    final seen = <String>{};
    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw StateError('Verified module contains an invalid entity.');
      }
      final id = item['id'];
      if (id is! String || id.trim().isEmpty || !seen.add(id)) {
        throw StateError('Verified module contains an ambiguous identity.');
      }
      rows.add(Map<String, dynamic>.unmodifiable(item));
    }
    return List<Map<String, dynamic>>.unmodifiable(rows);
  }

  static void requireUnchanged({
    required String? activeRaw,
    required Map<String, dynamic> selected,
  }) {
    final id = selected['id'];
    if (id is! String || id.trim().isEmpty) {
      throw StateError('Selected module entity has no verified identity.');
    }
    final matches = decodeRows(activeRaw)
        .where((entry) => entry['id'] == id)
        .toList(growable: false);
    if (matches.length != 1 ||
        jsonEncode(matches.single) != jsonEncode(selected)) {
      throw StateError('Selected financial entity changed before confirmation.');
    }
  }

  static List<Map<String, dynamic>> verifiedTrash({
    required WaffraFinanceModule module,
    required String? trashRaw,
    required Map<String, int> encryptedExpiries,
  }) {
    final payload = trashPayloadKey(module);
    final wrappers = decodeTrash(trashRaw, payload);
    final seen = <String>{};
    for (final wrapper in wrappers) {
      final entry = wrapper[payload] as Map<String, dynamic>;
      final id = entry['id'] as String;
      if (!seen.add(id) || !encryptedExpiries.containsKey(id)) {
        throw StateError('Encrypted module trash and UI metadata differ.');
      }
    }
    if (encryptedExpiries.length != wrappers.length) {
      throw StateError('Encrypted trash has missing or forged metadata.');
    }
    return wrappers;
  }

  static List<Map<String, dynamic>> decodeTrash(
    String? raw, String payload,
  ) {
    if (raw == null) return const <Map<String, dynamic>>[];
    final value = jsonDecode(raw);
    if (value is! List) {
      throw StateError('Encrypted finance trash is not a list.');
    }
    final rows = <Map<String, dynamic>>[];
    for (final item in value) {
      if (item is! Map<String, dynamic> ||
          item[payload] is! Map<String, dynamic> ||
          item['deletedAt'] is! String ||
          DateTime.tryParse(item['deletedAt'] as String) == null) {
        throw StateError('Encrypted finance trash item is malformed.');
      }
      final entity = item[payload] as Map<String, dynamic>;
      if (entity['id'] is! String ||
          (entity['id'] as String).trim().isEmpty) {
        throw StateError('Encrypted finance trash entity has no identity.');
      }
      rows.add(Map<String, dynamic>.unmodifiable(item));
    }
    return List<Map<String, dynamic>>.unmodifiable(rows);
  }
}

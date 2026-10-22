import 'dart:convert';

import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_modules_repository.dart';

/// Keeps category, goal and recurring SQL projections in step with an
/// authorized Home edit, in the SAME SQLCipher transaction as the encrypted
/// finance snapshot. The caller holds the native Home/Widget writer lock.
///
/// Only creates and in-place edits are supported. Deletion, restoration and
/// recycle-bin operations need an independently audited retention writer.
/// A mismatch between pre-edit snapshot and SQL is a recovery incident.
class WaffraEncryptedModuleProjectionGuard {
  const WaffraEncryptedModuleProjectionGuard._();

  static WaffraFinanceModule _module(String key) => switch (key) {
    'waffra_categories_v24' => WaffraFinanceModule.categories,
    'waffra_goals_v24' => WaffraFinanceModule.goals,
    'waffra_recurring_v24' => WaffraFinanceModule.recurring,
    _ => throw ArgumentError.value(key, 'key', 'No SQL module projection'),
  };

  static Map<String, Map<String, Object?>> _decode(String? raw) {
    final decoded = jsonDecode(raw ?? '[]');
    if (decoded is! List) {
      throw StateError('Encrypted finance module is not a list.');
    }
    final entities = <String, Map<String, Object?>>{};
    for (final value in decoded) {
      if (value is! Map) {
        throw StateError('Encrypted finance module has a malformed entity.');
      }
      final item = Map<String, Object?>.from(value);
      final id = item['id'];
      if (id is! String || id.trim().isEmpty ||
          id.length > 256 || entities.containsKey(id)) {
        throw StateError('Encrypted finance module has ambiguous identity.');
      }
      entities[id] = item;
    }
    return entities;
  }

  static String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return jsonEncode({
        for (final key in keys) key: jsonDecode(_canonical(value[key])),
      });
    }
    if (value is List) {
      return jsonEncode(value.map((part) => jsonDecode(_canonical(part))).toList());
    }
    return jsonEncode(value);
  }

  static bool _same(Map<String, Object?> a, Map<String, Object?> b) =>
      _canonical(a) == _canonical(b);

  static Future<void> reconcile({
    required WaffraEncryptedStore store,
    required String key,
    required String? previousJson,
    required String? updatedJson,
  }) async {
    final module = _module(key);
    final before = _decode(previousJson);
    final after = _decode(updatedJson);
    // Never interpret disappearance from an active list as permission to
    // destroy its SQL record or orphan related historical transactions.
    if (!after.keys.toSet().containsAll(before.keys)) {
      throw StateError('Finance module removal needs verified recycle handling.');
    }

    final repository = WaffraFreshModulesRepository(
      store: store, experimentalEnabled: true,
    );
    final sql = await repository.list(module);
    final projected = <String, Map<String, Object?>>{};
    for (final row in sql) {
      final id = row['id'];
      if (id is! String || projected.containsKey(id)) {
        throw StateError('SQLCipher module identity is inconsistent.');
      }
      projected[id] = row;
    }
    if (projected.length != before.length ||
        !projected.keys.toSet().containsAll(before.keys)) {
      throw StateError('SQLCipher module projection differs from finance snapshot.');
    }
    for (final id in before.keys) {
      if (!_same(before[id]!, projected[id]!)) {
        throw StateError('SQLCipher module values differ from finance snapshot.');
      }
    }

    for (final item in after.entries) {
      final old = before[item.key];
      if (old != null && _same(old, item.value)) continue;
      await repository.save(
        module, item.value,
        replaceExisting: old != null,
      );
    }

    // A partial SQL update must never be committed as a successful UI save.
    final written = await repository.list(module);
    final verify = <String, Map<String, Object?>>{
      for (final value in written) value['id'] as String: value,
    };
    if (verify.length != after.length ||
        !verify.keys.toSet().containsAll(after.keys)) {
      throw StateError('SQLCipher module projection failed final verification.');
    }
    for (final id in after.keys) {
      if (!_same(after[id]!, verify[id]!)) {
        throw StateError('SQLCipher module projection changed unexpectedly.');
      }
    }
  }
}

import 'dart:convert';

import 'package:drift/drift.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_encrypted_vault_bootstrap.dart';

/// The screens for categories, goals, and recurring transactions can consume
/// these maps without importing main.dart into the encrypted data layer.
///
/// IMPORTANT: This repository is DISCONNECTED from the running Waffra app.
/// It is not the actual storage switch. Existing SharedPreferences data and
/// the separately running Android quick-add widget remain untouched.
enum WaffraFinanceModule { categories, goals, recurring }

class WaffraFreshModulesRepository {
  const WaffraFreshModulesRepository({
    required this.store,
    this.experimentalEnabled = false,
  });

  final WaffraEncryptedStore store;
  final bool experimentalEnabled;

  static String _table(WaffraFinanceModule module) => switch (module) {
    WaffraFinanceModule.categories => 'fresh_finance_categories',
    WaffraFinanceModule.goals => 'fresh_finance_goals',
    WaffraFinanceModule.recurring => 'fresh_finance_recurring',
  };

  static String _idColumn(WaffraFinanceModule module) => switch (module) {
    WaffraFinanceModule.categories => 'category_id',
    WaffraFinanceModule.goals => 'goal_id',
    WaffraFinanceModule.recurring => 'recurring_id',
  };

  Future<void> _requireReady() async {
    if (!experimentalEnabled) {
      throw StateError('Encrypted finance modules are disabled by default.');
    }
    final meta = await store.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name='fresh_finance_meta'",
    ).get();
    if (meta.length != 1) {
      throw StateError('Encrypted finance database is not initialized.');
    }
    final result = await store.customSelect(
      "SELECT schema_version FROM fresh_finance_meta WHERE slot='primary'",
    ).get();
    if (result.length != 1 ||
        result.single.read<int>('schema_version') !=
            WaffraFreshEncryptedVaultBootstrap.schemaVersion) {
      throw StateError('Finance schema is not supported.');
    }
    final old = await store.customSelect(
      'SELECT count(*) AS n FROM shadow_vaults',
    ).getSingle();
    if (old.read<int>('n') != 0) {
      throw StateError('Cannot modify a finance migration sandbox.');
    }
  }

  static int _halalas(Object? value, {bool positive = false}) {
    if (value is! num ||
        !WaffraLegacyPreflight.canRepresentHalalas(value) ||
        (positive && value <= 0)) {
      throw ArgumentError('Invalid amount in financial module.');
    }
    return (value * 100).round();
  }

  static String _validId(Map<String, Object?> data) {
    final id = data['id'];
    if (id is! String || id.trim().isEmpty || id.length > 256) {
      throw ArgumentError('A unique, nonempty financial entity ID is required.');
    }
    return id;
  }

  static Map<String, Object?> _validate(
    WaffraFinanceModule module, Map<String, Object?> item,
  ) {
    final data = Map<String, Object?>.from(item);
    _validId(data);
    final name = data[module == WaffraFinanceModule.recurring ? 'title' : 'name'];
    if (name is! String || name.trim().isEmpty) {
      throw ArgumentError('Name/title is mandatory.');
    }
    switch (module) {
      case WaffraFinanceModule.categories:
        if (data['income'] is! bool) throw ArgumentError('Category type is mandatory.');
        _halalas(data['budget'] ?? 0);
        final p = data['parentId'];
        if (p != null && p is! String) throw ArgumentError('Invalid parent category.');
        break;
      case WaffraFinanceModule.goals:
        _halalas(data['target'], positive: true);
        _halalas(data['saved'] ?? 0);
        break;
      case WaffraFinanceModule.recurring:
        if (data['income'] is! bool) throw ArgumentError('Recurring type is mandatory.');
        _halalas(data['amount']);
        final day = data['day'];
        if (day is! int || day < 1 || day > 31) {
          throw ArgumentError('Recurring due day must be 1 through 31.');
        }
        final date = data['startAt'];
        if (date is! String || DateTime.tryParse(date) == null) {
          throw ArgumentError('Recurring start date is invalid.');
        }
        if (data['active'] != null && data['active'] is! bool) {
          throw ArgumentError('Recurring active flag is invalid.');
        }
        break;
    }
    // Ensure legacy JSON can be serialized losslessly before the SQL write.
    try {
      final roundtrip = jsonDecode(jsonEncode(data));
      if (roundtrip is! Map) throw const FormatException('Not a JSON object');
    } catch (_) {
      throw ArgumentError('Unsupported financial data payload.');
    }
    return data;
  }

  Future<List<Map<String, Object?>>> list(WaffraFinanceModule module) async {
    await _requireReady();
    final table = _table(module);
    final idColumn = _idColumn(module);
    final rows = await store.customSelect(
      'SELECT source_json FROM $table ORDER BY $idColumn',
    ).get();
    return List.unmodifiable(rows.map((row) => Map<String, Object?>.unmodifiable(
      Map<String, Object?>.from(
        jsonDecode(row.read<String>('source_json')) as Map,
      ),
    )));
  }

  /// insert => create only, replaceExisting => update only.
  /// Keep record IDs stable and never silently overwrite other user records.
  Future<void> save(
    WaffraFinanceModule module,
    Map<String, Object?> item, {
    bool replaceExisting = false,
  }) async {
    await _requireReady();
    final data = _validate(module, item);
    final id = _validId(data);
    final table = _table(module);
    final idColumn = _idColumn(module);
    final raw = jsonEncode(data);

    await store.transaction(() async {
      final matching = await store.customSelect(
        'SELECT $idColumn FROM $table WHERE $idColumn = ?',
        variables: [Variable.withString(id)],
      ).get();
      if (replaceExisting && matching.length != 1) {
        throw StateError('Cannot update missing finance entity.');
      }
      if (!replaceExisting && matching.isNotEmpty) {
        throw StateError('Duplicate finance entity ID.');
      }
      switch (module) {
        case WaffraFinanceModule.categories:
          final values = <Object?>[
            data['name'], data['parentId'] ?? '',
            data['income'] == true ? 1 : 0,
            _halalas(data['budget'] ?? 0), raw,
          ];
          if (replaceExisting) {
            await store.customStatement(
              'UPDATE fresh_finance_categories SET name=?,parent_id=?,'
              'is_income=?,budget_minor=?,source_json=? WHERE category_id=?',
              [...values, id],
            );
          } else {
            await store.customStatement(
              'INSERT INTO fresh_finance_categories '
              '(name,parent_id,is_income,budget_minor,source_json,category_id) '
              'VALUES (?,?,?,?,?,?)',
              [...values, id],
            );
          }
          break;
        case WaffraFinanceModule.goals:
          final values = <Object?>[
            data['name'], _halalas(data['target'], positive: true),
            _halalas(data['saved'] ?? 0), raw,
          ];
          if (replaceExisting) {
            await store.customStatement(
              'UPDATE fresh_finance_goals SET name=?,target_minor=?,'
              'saved_minor=?,source_json=? WHERE goal_id=?',
              [...values, id],
            );
          } else {
            await store.customStatement(
              'INSERT INTO fresh_finance_goals '
              '(name,target_minor,saved_minor,source_json,goal_id) '
              'VALUES (?,?,?,?,?)',
              [...values, id],
            );
          }
          break;
        case WaffraFinanceModule.recurring:
          final values = <Object?>[
            _halalas(data['amount']), data['income'] == true ? 1 : 0,
            data['day'], raw,
          ];
          if (replaceExisting) {
            await store.customStatement(
              'UPDATE fresh_finance_recurring SET amount_minor=?,is_income=?,'
              'due_day=?,source_json=? WHERE recurring_id=?',
              [...values, id],
            );
          } else {
            await store.customStatement(
              'INSERT INTO fresh_finance_recurring '
              '(amount_minor,is_income,due_day,source_json,recurring_id) '
              'VALUES (?,?,?,?,?)',
              [...values, id],
            );
          }
          break;
      }
    });
  }

  /// Prevent permanent deletion until category references and goal/recycle-bin
  /// retention are represented and verified by the future app adapter.
  /// Screens must not map their Delete button to SQL DELETE here.
  Future<void> delete(WaffraFinanceModule module, String id) async {
    await _requireReady();
    throw StateError('Safe deletion/recycle-bin support is not active.');
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_snapshot_preflight.dart';
import 'waffra_finance_read_view.dart';
import 'waffra_legacy_finance_writer_coordinator.dart';
import 'waffra_legacy_finance_batch_journal.dart';
import 'waffra_legacy_widget_commit_journal.dart';

/// Immutable financial read + independent widget revision captured while
/// holding the same cross-engine lock used for financial writes.
class WaffraHomeFinanceLoaded {
  const WaffraHomeFinanceLoaded({
    required this.finance,
    required this.widgetRevision,
  });

  final WaffraFinanceReadView finance;
  final String? widgetRevision;

  String? get ledgerRaw => finance.getString('entries');
}


class WaffraConfirmedLegacySmsResult {
  const WaffraConfirmedLegacySmsResult({
    required this.savedEntriesRaw,
    required this.savedHashes,
    required this.widgetRevision,
    required this.added,
    required this.savedIncome,
    required this.savedExpenses,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.skippedDuplicates,
  });
  final String savedEntriesRaw;
  final List<String> savedHashes;
  final String? widgetRevision;
  final int added, savedIncome, savedExpenses;
  final int incomeMinor, expenseMinor, skippedDuplicates;
}

/// The live HomeScreen's finance persistence boundary.
///
/// M57 routes the EXISTING dashboard through one guarded entry point.
/// SharedPreferences remains authoritative: this class neither opens a
/// SQLCipher vault nor sets cutover markers or activates Firebase. The future
/// encrypted implementation must be selected only after all app/widget/SMS
/// writers share an independently verified, crash-safe source selector.
/// Never introduce or change raw bank SMS notes in unencrypted legacy storage.
/// This protects the current Home/Widget writer while SQLCipher production
/// cutover is NO-GO. Existing legacy notes remain byte-for-byte unchanged
/// during unrelated edits; they are not silently erased or migrated.
class WaffraLegacySmsNotesPrivacyGate {
  const WaffraLegacySmsNotesPrivacyGate._();

  static void rejectConfirmedSmsNotes(List<Map<String, Object?>> records) {
    for (final record in records) {
      final notes = record['notes'];
      if (notes != null && notes != '') {
        throw StateError(
          'Original bank SMS notes require verified encrypted storage.',
        );
      }
    }
  }

  static void rejectNewOrModifiedSmsNotes({
    required String proposedLedger,
    required String? previousLedger,
  }) {
    final before = jsonDecode(previousLedger ?? '[]');
    final after = jsonDecode(proposedLedger);
    if (before is! List || after is! List ||
        before.any((row) => row is! Map) ||
        after.any((row) => row is! Map)) {
      throw StateError('Legacy finance ledger encoding is invalid.');
    }
    // Fail closed on malformed or duplicate identities. Otherwise a legacy
    // ledger containing both SMS and manual rows with the same ID could let
    // the manual row shadow the original SMS source in this comparison.
    final priorById = <String, Map>{};
    for (final row in before) {
      final record = row as Map;
      final id = record['id'];
      if (id is! String || id.trim().isEmpty ||
          priorById.containsKey(id)) {
        throw StateError('Legacy finance ledger has ambiguous identities.');
      }
      priorById[id] = record;
    }
    final proposedIds = <String>{};
    for (final row in after) {
      final record = row as Map;
      final id = record['id'];
      if (id is! String || id.trim().isEmpty || !proposedIds.add(id)) {
        throw StateError('Proposed finance ledger has ambiguous identities.');
      }
      final prior = priorById[id];
      // A legacy SMS entry must never be reclassified as manual: doing so
      // would let a second save add raw bank text to plaintext preferences.
      // This check runs under the native writer lock, before journal writes.
      if (prior?['sourceType'] == 'sms' && record['sourceType'] != 'sms') {
        throw StateError(
          'Original bank SMS source cannot be downgraded in legacy storage.',
        );
      }
      final isSms = record['sourceType'] == 'sms' ||
          prior?['sourceType'] == 'sms';
      final notes = record['notes'];
      if (isSms && notes != null && notes != '' &&
          (prior == null || prior['notes'] != notes)) {
        throw StateError(
          'Original bank SMS notes require verified encrypted storage.',
        );
      }
    }
  }
}

class WaffraHomeFinancePersistence {
  const WaffraHomeFinancePersistence({
    this.coordinator = const WaffraLegacyFinanceWriterCoordinator(),
  });

  final WaffraLegacyFinanceWriterCoordinator coordinator;

  /// Read finance plus widget revision under a single native writer lock.
  /// The coordinator replays a pending widget journal and blocks cutover
  /// markers before calling us, so this cannot mix before/after transactions.
  Future<WaffraHomeFinanceLoaded> loadWithWitness() =>
      coordinator.withCurrentPreferences((preferences) async {
        return WaffraHomeFinanceLoaded(
          finance: WaffraFinanceReadView.fromLegacy(preferences),
          widgetRevision:
              preferences.getString('waffra_widget_last_save_v1'),
        );
      });

  /// Retained for callers that only need the legacy finance value view.
  Future<WaffraFinanceReadView> loadLegacy(
    SharedPreferences preferences,
  ) async => (await loadWithWitness()).finance;

  /// Single guarded entry for all participating live writers (dashboard,
  /// widget SMS, catalog, dedupe and recurring settings). Callers must not
  /// take this lock recursively. The real coordinator recovers interrupted
  /// widget saves and rejects pending/enabled SQLCipher cutover.
  Future<T> withLegacyWriter<T>(
    Future<T> Function(SharedPreferences preferences) writer,
  ) => coordinator.withCurrentPreferences(writer);

  /// Merge *fingerprints*, never original bank messages, under the existing
  /// Home/Widget native lock. A concurrent widget commit is preserved.
  Future<List<String>> mergeSmsHashes(Iterable<String> additions) async {
    final requested = Set<String>.of(additions);
    const hex = '0123456789abcdef';
    if (requested.length > 1000 || requested.any((hash) =>
        hash.length != 64 || hash.split('').any((c) => !hex.contains(c)))) {
      throw ArgumentError('Only SHA-256 bank SMS fingerprints may be saved.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final existing = prefs.getStringList('waffra_sms_hashes_v1') ??
          const <String>[];
      final merged = <String>{...existing, ...requested}.toList()..sort();
      if (merged.length != existing.length ||
          !Set<String>.from(existing).containsAll(requested)) {
        if (!await prefs.setStringList('waffra_sms_hashes_v1', merged)) {
          throw StateError('Failed to persist SMS fingerprints.');
        }
      }
      return List<String>.unmodifiable(merged);
    });
  }

  /// Reminder preference is a finance scalar, not an arbitrary UI setting.
  /// Only a guarded legacy source may use this writer.
  Future<void> setRecurringReminderPreference(bool enabled) =>
      coordinator.withCurrentPreferences((prefs) async {
        if (!await prefs.setBool('waffra_recurring_reminders_enabled_v1',
            enabled)) {
          throw StateError('Could not durably save recurring reminders.');
        }
      });

  /// Install a catalog version after comparing the exact loaded catalog with
  /// the current catalog INSIDE the same app/widget lock. The marker comes
  /// last, so a crash before it can retry without deleting custom entries.
  Future<void> installCategoryCatalog({
    required int version,
    required String? expectedCatalogRaw,
    required String nextCatalogRaw,
    required bool catalogChanged,
  }) async {
    if (version != 2 && version != 3) {
      throw ArgumentError('Unsupported category catalog version.');
    }
    final preflight = WaffraLegacyPreflight.inspect(
      <String, Object?>{'waffra_categories_v24': nextCatalogRaw},
    );
    if (!preflight.canStage) {
      throw StateError('Category catalog failed integrity validation.');
    }
    await coordinator.withCurrentPreferences((prefs) async {
      if (prefs.getString('waffra_categories_v24') != expectedCatalogRaw) {
        throw StateError('Category catalog changed concurrently; reload.');
      }
      final marker = 'waffra_category_catalog_v${version}_installed';
      if (prefs.getBool(marker) == true) return;
      if (catalogChanged &&
          !await prefs.setString('waffra_categories_v24', nextCatalogRaw)) {
        throw StateError('Category catalog could not be persisted.');
      }
      if (!await prefs.setBool(marker, true)) {
        throw StateError('Category catalog version could not be committed.');
      }
    });
  }

  /// Custom saving-goal suggestions live beside the primary financial
  /// snapshot in legacy installs. They are included in verified SQLCipher
  /// staging, so all reads and writes must share the native app/widget lock.
  /// Never touch arbitrary profile or bank settings here.
  Future<List<String>> loadCustomGoalSuggestions() =>
      coordinator.withCurrentPreferences((prefs) async {
        if (!prefs.containsKey('waffra_custom_goals_v1')) {
          return const <String>[];
        }
        final value = prefs.getStringList('waffra_custom_goals_v1');
        if (value == null || value.length > 1000 ||
            value.any((name) => name.trim().isEmpty || name.length > 512)) {
          throw StateError('Saved custom goal suggestions are invalid.');
        }
        return List<String>.unmodifiable(value);
      });

  /// Atomically adds a custom suggestion without overwriting suggestions
  /// written by another app instance since the goal dialog opened. A future
  /// fully encrypted runtime will replace this one legacy-only adapter,
  /// not copy its SharedPreferences implementation into UI code.
  Future<bool> addCustomGoalSuggestion(String suggestedName) async {
    final name = suggestedName.trim();
    if (name.isEmpty || name.length > 100) {
      throw ArgumentError('Custom savings goal name must be 1–100 characters.');
    }
    return coordinator.withCurrentPreferences((prefs) async {
      final current = prefs.getStringList('waffra_custom_goals_v1') ??
          const <String>[];
      if (current.length > 1000 ||
          current.any((entry) => entry.trim().isEmpty ||
              entry.length > 512)) {
        throw StateError('Saved custom goal suggestions are invalid.');
      }
      final candidate = name.toLowerCase();
      if (current.any((existing) =>
          existing.trim().toLowerCase() == candidate)) {
        return false;
      }
      if (current.length >= 1000) {
        throw StateError('Custom goal suggestion capacity exceeded.');
      }
      final saved = await prefs.setStringList(
        'waffra_custom_goals_v1', [...current, name],
      );
      if (!saved) {
        throw StateError('Custom saving-goal suggestion could not be saved.');
      }
      return true;
    });
  }


  /// The Home and Android quick-add widget share this lock and crash journal.
  /// This bridge remains on guarded legacy storage; it never activates SQLCipher.
  Future<WaffraConfirmedLegacySmsResult> commitConfirmedLegacySms({
    required List<Map<String, Object?>> records,
    required List<String> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
    List<Map<String, Object?>> proposedCategories = const [],
  }) async {
    if (!userConfirmed) {
      throw StateError('Bank transaction batch was not confirmed.');
    }
    if (records.isEmpty || records.length > 100 ||
        messageHashes.length != records.length) {
      throw ArgumentError('Confirmed SMS batch must contain 1–100 records.');
    }
    final copied = <Map<String, Object?>>[];
    for (final record in records) {
      copied.add(Map<String, Object?>.unmodifiable(
        Map<String, Object?>.from(
          jsonDecode(jsonEncode(record)) as Map<String, dynamic>,
        ),
      ));
    }
    WaffraLegacySmsNotesPrivacyGate.rejectConfirmedSmsNotes(copied);
    final hashes = List<String>.unmodifiable(messageHashes);
    // A standalone test or future legacy caller can invoke this bridge
    // without the outer finance authority. Snapshot merchant proposals
    // BEFORE awaiting the coordinator lock, just like records and hashes.
    if (proposedCategories.length > 100) {
      throw ArgumentError('Too many proposed merchant categories.');
    }
    final frozenCategories = List<Map<String, Object?>>.unmodifiable(
      proposedCategories.map((item) {
        final decoded = jsonDecode(jsonEncode(item));
        if (decoded is! Map<String, dynamic>) {
          throw ArgumentError('Invalid merchant category payload.');
        }
        return Map<String, Object?>.unmodifiable(decoded);
      }),
    );
    const alphabet = '0123456789abcdef';
    for (final hash in hashes) {
      if (hash.length != 64 ||
          hash.split('').any((digit) => !alphabet.contains(digit))) {
        throw ArgumentError('Invalid SMS SHA-256 fingerprint.');
      }
    }
    if (!WaffraLegacyPreflight.inspect({
      'entries': jsonEncode(copied),
    }).canStage) {
      throw StateError('Confirmed SMS financial records are invalid.');
    }

    return coordinator.withCurrentPreferences((prefs) async {
      final previous = prefs.getString('entries') ?? '[]';
      final decoded = jsonDecode(previous);
      if (decoded is! List || decoded.any((item) => item is! Map)) {
        throw StateError('Persisted finance ledger has invalid encoding.');
      }
      final oldEntries = decoded
          .map((item) => Map<String, dynamic>.from(item as Map)).toList();
      final existingIds = oldEntries.map((item) => item['id']).toSet();
      final existingHashes = (prefs.getStringList('waffra_sms_hashes_v1') ??
          const <String>[]).toSet();
      final confirmed = <Map<String, Object?>>[];
      final newHashes = <String>{};
      var income = 0, expense = 0, incomeMinor = 0, expenseMinor = 0;
      var skipped = 0;
      for (var i = 0; i < copied.length; i++) {
        final item = copied[i];
        final hash = hashes[i];
        if (!allowDuplicateHashes &&
            (existingHashes.contains(hash) || newHashes.contains(hash))) {
          skipped++;
          continue;
        }
        if (!existingIds.add(item['id'])) {
          throw StateError('Duplicate transaction ID in confirmed batch.');
        }
        final amount = item['amount'];
        if (amount is! num || !amount.toDouble().isFinite || amount <= 0 ||
            ((amount * 100) - (amount * 100).round()).abs() > 1e-7) {
          throw StateError('Invalid transaction precision.');
        }
        confirmed.add(item);
        newHashes.add(hash);
        if (item['income'] == true) {
          income++;
          incomeMinor += (amount * 100).round();
        } else {
          expense++;
          expenseMinor += (amount * 100).round();
        }
      }
      if (confirmed.isNotEmpty) {
        final finalEntries = jsonEncode([...confirmed, ...oldEntries]);
        final finalHashes = {...existingHashes, ...newHashes}.toList()..sort();
        final revision = DateTime.now().toUtc().toIso8601String();
        if(proposedCategories.isEmpty){
          // Existing Home/Widget journal semantics remain unchanged.
          const journal = WaffraLegacyWidgetCommitJournal();
          await journal.prepare(prefs: prefs, nextEntries: finalEntries,
            nextHashes: finalHashes, nextRevision: revision);
          await journal.recover(prefs);
        }else{
          final rawCategories=prefs.getString('waffra_categories_v24')??'[]';
          final decodedCats=jsonDecode(rawCategories);
          if(decodedCats is! List || decodedCats.any((e)=>e is! Map)){
            throw StateError('Current category catalog is invalid.');
          }
          final live=decodedCats.map((e)=>Map<String,dynamic>.from(e as Map))
            .toList();
          final ids=live.map((e)=>e['id']).toSet();
          final names=live.map((e)=>'${e['income']}|${e['name']}'.toLowerCase()).toSet();
          final used=confirmed.map((e)=>'${e['income']}|${e['category']}'.toLowerCase()).toSet();
          final proposedIds=<String>{};
          for(final value in frozenCategories){
            final c=Map<String,dynamic>.from(value);
            final id=c['id'],name=c['name'],parentId=c['parentId'];
            final incomeFlag=c['income'],budget=c['budget'];
            if(id is! String||id.isEmpty||name is! String||
             name.trim().isEmpty||name.runes.length>300||
             parentId is! String||parentId.isEmpty||
             incomeFlag is! bool||budget is! num||
             !budget.toDouble().isFinite||budget!=0||
             c['icon'] is! String||c['color'] is! int||
             c['alertPercent'] is! int){
              throw StateError('Invalid auto-generated category.');
            }
            final label='$incomeFlag|$name'.toLowerCase();
            if(!used.contains(label))continue; // Duplicate SMS => no orphan child.
            if(names.contains(label))continue;
            final parent=live.where((p)=>p['id']==parentId&&
              p['income']==incomeFlag&&(p['parentId']==null||
                p['parentId']=='')).toList();
            if(parent.length!=1||
              !name.startsWith('${parent.single['name']} / ')){
              throw StateError('Unverified or deleted merchant parent.');
            }
            if(ids.contains(id)||!proposedIds.add(id)){
              throw StateError('Duplicate category identifier.');
            }
            live.add(c);
            ids.add(id);
            names.add(label);
          }
          final snapshot=<String,Object>{
            'entries':finalEntries,
            'waffra_categories_v24':jsonEncode(live),
            'waffra_sms_hashes_v1':finalHashes,
            'waffra_widget_last_save_v1':revision,
          };
          final verification=WaffraLegacyPreflight.inspect({
           'entries':finalEntries,
           'waffra_categories_v24':jsonEncode(live),
           'waffra_sms_hashes_v1':finalHashes,
          });
          if(!verification.canStage) {
            throw StateError('Confirmed finance and category snapshot is invalid.');
          }
          // One durable intent covers all 4 keys, recovered under the
          // existing inter-engine file lock on every startup.
          const journal=WaffraLegacyFinanceBatchJournal();
          await journal.prepare(prefs:prefs,nextValues:snapshot);
          await journal.recover(prefs);
        }
      }
      return WaffraConfirmedLegacySmsResult(
        savedEntriesRaw: prefs.getString('entries') ?? previous,
        savedHashes: List<String>.unmodifiable(
          prefs.getStringList('waffra_sms_hashes_v1') ?? const <String>[],
        ),
        widgetRevision: prefs.getString('waffra_widget_last_save_v1'),
        added: confirmed.length,
        savedIncome: income,
        savedExpenses: expense,
        incomeMinor: incomeMinor,
        expenseMinor: expenseMinor,
        skippedDuplicates: skipped,
      );
    });
  }

  /// Persist the screen's already-captured batch without mixing in profile
  /// settings. The cross-engine lock checks the exact ledger and widget
  /// revision before ANY field is changed. Returns the committed ledger
  /// witness for the next queued HomeScreen write.
  ///
  /// Journaled recovery completes a partially persisted legacy batch after
  /// process death; SQLCipher source activation is NOT implemented.
  Future<String> saveLegacy({
    required Map<String, Object> snapshot,
    required String? expectedLedgerRaw,
    required String? expectedWidgetRevision,
  }) async {
    // Defensively copy SMS hash lists before any asynchronous work. The
    // encrypted/legacy writer must persist exactly the user-confirmed batch.
    final captured = Map<String, Object>.unmodifiable(snapshot.map(
      (key, value) => MapEntry(
        key, value is List<String> ? List<String>.unmodifiable(value) : value,
      ),
    ));
    if (captured.keys.toSet().difference(
      WaffraLegacyPreflight.allKeys.toSet(),
    ).isNotEmpty) {
      throw ArgumentError('Attempted to save non-financial preference keys.');
    }
    final entries = captured['entries'];
    if (entries is! String) {
      throw ArgumentError('Screen ledger must be a JSON string.');
    }
    for (final entry in captured.entries) {
      final value = entry.value;
      if (value is! String && value is! double && value is! bool &&
          !(WaffraLegacyPreflight.financeListOfStringsKeys
              .contains(entry.key) && value is List<String>)) {
        throw ArgumentError('Unsupported legacy financial value: ${entry.key}');
      }
    }
    await coordinator.withCurrentPreferences((preferences) async {
      WaffraLegacyFinanceWriterCoordinator.requireUnchangedLedger(
        preferences,
        expectedRaw: expectedLedgerRaw,
        expectedWidgetRevision: expectedWidgetRevision,
      );
      WaffraLegacySmsNotesPrivacyGate.rejectNewOrModifiedSmsNotes(
        proposedLedger: entries,
        previousLedger: preferences.getString('entries'),
      );
      const batch = WaffraLegacyFinanceBatchJournal();
      await batch.prepare(prefs: preferences, nextValues: captured);
      await batch.recover(preferences);
    });
    return entries;
  }
}

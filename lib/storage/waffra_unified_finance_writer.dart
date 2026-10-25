import 'dart:convert';
import 'dart:io';

import 'legacy_snapshot_preflight.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_experimental_writer_gate.dart';

class WaffraUnifiedWriteResult {
  const WaffraUnifiedWriteResult({
    required this.saved,
    required this.savedIncome,
    required this.savedExpenses,
    this.incomeMinor = 0,
    this.expenseMinor = 0,
    required this.skippedDuplicates,
    required this.generation,
  });

  final int saved;
  final int savedIncome;
  final int savedExpenses;
  final int incomeMinor, expenseMinor;
  final int skippedDuplicates;
  final int generation;
}

/// A single lossless finance writer to be shared by the dashboard and widget
/// only after both have been moved to the same encrypted data source.
///
/// Current production UI and quick-add widget are NOT yet wired to this.
/// This isolated rehearsal never touches SharedPreferences or real receipts.
class WaffraUnifiedFinanceWriter {
  const WaffraUnifiedFinanceWriter({
    required this.writerDirectory,
    required this.snapshot,
    this.experimentalEnabled = false,
    this.verifySourceUnderLock,
  });

  final Directory writerDirectory;
  final WaffraAtomicFinanceSnapshot snapshot;
  final bool experimentalEnabled;

  /// Optional runtime source verification. Executed while holding the same
  /// app/widget native lock, before reading or changing finance. Never use
  /// an unchecked writer in an activated installation.
  final Future<void> Function()? verifySourceUnderLock;

  /// Called AFTER explicit confirmation for bank SMS, or on a manual save.
  /// Hashes align one-to-one with entries, and may be null for manual entries.
  /// The only finance fields this operation changes are entries and SMS hashes.
  ///
  /// Every caller takes the SAME lock, re-reads latest state INSIDE it, and
  /// commits with the source revision to avoid widget/dashboard lost updates.
  Future<WaffraUnifiedWriteResult> appendTransactions({
    required List<Map<String, Object?>> records,
    required List<String?> messageHashes,
    required bool userConfirmed,
    bool allowDuplicateHashes = false,
    List<Map<String, Object?>> proposedCategories = const [],
  }) async {
    if (!experimentalEnabled) {
      throw StateError('Unified finance writer is disabled by default.');
    }
    if (!userConfirmed) {
      throw StateError('Explicit finance save confirmation was not granted.');
    }
    if (records.isEmpty || records.length > 100 ||
        messageHashes.length != records.length) {
      throw ArgumentError('A save requires 1 to 100 aligned transactions.');
    }
    // Freeze the entire confirmed payload BEFORE awaiting the shared native
    // lock or source witness. The caller (Home form, SMS parser or widget)
    // can reuse and mutate both lists and their maps while this runs.
    // A JSON round-trip also isolates nested JSON data from caller memory.
    final confirmedRecords = <Map<String, Object?>>[];
    for (final record in records) {
      final decoded = jsonDecode(jsonEncode(record));
      if (decoded is! Map<String, dynamic>) {
        throw ArgumentError('Invalid confirmed transaction payload.');
      }
      confirmedRecords.add(Map<String, Object?>.unmodifiable(decoded));
    }
    final confirmedHashes = List<String?>.unmodifiable(messageHashes);
    if(proposedCategories.length>100) {
      throw ArgumentError('Merchant categories exceed batch limit.');
    }
    // Capture mutable input before awaits; no bank account/card data is used
    // to generate new category identities or stored as the merchant key.
    final frozenCategories=proposedCategories.map((raw) =>
      Map<String,Object?>.unmodifiable(Map<String,Object?>.from(
        jsonDecode(jsonEncode(raw)) as Map<String,dynamic>)))
      .toList(growable:false);
    for(final c in frozenCategories){
      if(c['id'] is! String||(c['id'] as String).isEmpty||
         c['name'] is! String||(c['name'] as String).runes.length>300||
         (c['name'] as String).trim().isEmpty||
         c['parentId'] is! String||(c['parentId'] as String).isEmpty||
         c['income'] is! bool||c['budget'] is! num||c['budget']!=0||
         c['icon'] is! String||c['color'] is! int||
         c['alertPercent'] is! int){
        throw ArgumentError('Untrusted merchant category metadata.');
      }
    }
    for (var index = 0; index < confirmedRecords.length; index++) {
      final data = confirmedRecords[index];
      final hash = confirmedHashes[index];
      if (hash != null && !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw ArgumentError('Invalid SMS digest.');
      }
      if (data['receiptPath'] != null && data['receiptPath'] != '') {
        throw StateError('Receipts require their own verified file installer.');
      }
      // Delegate financial value, ID, date and amount validation to the same
      // existing migration preflight instead of silently coercing money.
      final check = WaffraLegacyPreflight.inspect({
        'entries': jsonEncode([data]),
      });
      if (!check.canStage) {
        throw ArgumentError('Invalid transaction data.');
      }
      if (data['id'] is! String || (data['id'] as String).trim().isEmpty ||
          data['title'] is! String ||
          (data['title'] as String).trim().isEmpty ||
          data['category'] is! String ||
          (data['category'] as String).trim().isEmpty) {
        throw ArgumentError('Transaction ID, title and category are required.');
      }
    }

    final gate = WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory,
      experimentalEnabled: true,
    );
    return gate.withExclusiveAccess(() async {
      await verifySourceUnderLock?.call();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        final next = Map<String, Object?>.from(current.values);
        final decoded = jsonDecode((next['entries'] as String?) ?? '[]');
        if (decoded is! List) {
          throw StateError('Existing finance entries have invalid storage.');
        }
        final list = decoded.map<Map<String, Object?>>((item) {
          if (item is! Map) throw StateError('Invalid saved finance entry.');
          return Map<String, Object?>.from(item);
        }).toList();
        final ids = list.map((item) => item['id']).toSet();
        // M76 writes normalized SQL and the canonical finance snapshot in
        // one transaction. The unified Home/widget writer must do the same.
        // A count-only check can miss equal-sized, mismatched ID sets.
        final sqlRows = await snapshot.store.customSelect(
          'SELECT entry_id FROM fresh_finance_entries',
        ).get();
        final normalizedIds = sqlRows
            .map((row) => row.read<String>('entry_id')).toSet();
        if (sqlRows.length != list.length ||
            normalizedIds.length != list.length ||
            !normalizedIds.containsAll(ids) ||
            !ids.containsAll(normalizedIds)) {
          throw StateError('Encrypted SQL ledger differs from screen snapshot.');
        }
        final existingHashes = Set<String>.from(
          next['waffra_sms_hashes_v1'] as List<String>? ?? const <String>[],
        );
        final rawCategories=next['waffra_categories_v24'] as String?;
        final parsedCategories=jsonDecode(rawCategories??'[]');
        if(parsedCategories is! List||
          parsedCategories.any((value)=>value is! Map)){
          throw StateError('Encrypted category catalog is corrupted.');
        }
        final categoryList=parsedCategories.map((raw)=>
         Map<String,Object?>.from(raw as Map)).toList();
        final normalizedCategoryRows=await snapshot.store.customSelect(
          'SELECT category_id,source_json FROM fresh_finance_categories',
        ).get();
        final categoryIds=categoryList.map((c)=>c['id']).toSet();
        final sqlIds=normalizedCategoryRows.map((row)=>
          row.read<String>('category_id')).toSet();
        if(sqlIds.length!=categoryIds.length||normalizedCategoryRows.length!=categoryList.length||
           sqlIds.difference(categoryIds).isNotEmpty||categoryIds.difference(sqlIds).isNotEmpty){
          throw StateError('Encrypted category projection differs from finance snapshot.');
        }
        final normalizedById={
         for(final row in normalizedCategoryRows)
          row.read<String>('category_id'):row.read<String>('source_json'),
        };
        for(final c in categoryList){
          if(normalizedById[c['id']]!=jsonEncode(c)){
            throw StateError('Encrypted category JSON is not identical to ledger snapshot.');
          }
        }
        // Bank notes must survive BOTH encrypted representations byte-for-byte.
        // Kept only in memory; never print or copy them to legacy preferences.
        final newlySavedSmsNotes = <String, String>{};
        var savedIncome = 0, savedExpenses = 0, skipped = 0;
        final usedCategoryNames=<String>{};
        var incomeMinor = 0, expenseMinor = 0;
        for (var i = 0; i < confirmedRecords.length; i++) {
          final record = confirmedRecords[i];
          final hash = confirmedHashes[i];
          if (hash != null && !allowDuplicateHashes &&
              existingHashes.contains(hash)) {
            skipped++;
            continue;
          }
          if (!ids.add(record['id'])) {
            throw StateError('Duplicate transaction ID; refusing partial save.');
          }
          // Save both projections under the SAME SQLCipher transaction; if
          // any row insert or snapshot commit fails, no finance or hash is
          // persisted. Receipt-bearing records are rejected above.
          await snapshot.store.customStatement(
            'INSERT INTO fresh_finance_entries '
            '(entry_id,title,category_snapshot,amount_minor,is_income,'
            'occurred_iso,receipt_count,source_json) VALUES(?,?,?,?,?,?,?,?)',
            [
              record['id'], record['title'], record['category'],
              ((record['amount'] as num) * 100).round(),
              record['income'] == true ? 1 : 0,
              record['date'], 0, jsonEncode(record),
            ],
          );
          list.add(record);
          if (hash != null && record['notes'] is String &&
              (record['notes'] as String).isNotEmpty) {
            newlySavedSmsNotes[record['id'] as String] = record['notes'] as String;
          }
          usedCategoryNames.add('${record['income']}|${record['category']}'.toLowerCase());
          if(hash!=null){
            existingHashes.add(hash);
            // Keep the canonical finance snapshot and SQL hash projection
            // in this one transaction, even under allow-duplicates mode.
            await snapshot.store.customStatement(
              'INSERT OR IGNORE INTO fresh_finance_sms_hashes '
              '(message_hash) VALUES (?)',[hash],
            );
          }
          final minor = ((record['amount'] as num) * 100).round();
          if (record['income'] == true) {
            savedIncome++;
            incomeMinor += minor;
          } else {
            savedExpenses++;
            expenseMinor += minor;
          }
        }
        final saved = savedIncome + savedExpenses;
        if (saved == 0) {
          return WaffraUnifiedWriteResult(
            saved: 0, savedIncome: 0, savedExpenses: 0,
            skippedDuplicates: skipped, generation: current.generation,
          );
        }
        // Category child rows and their parent snapshot are inserted under
        // the exact SAME SQL transaction as normalized ledger rows, hashes
        // and the canonical finance snapshot. Any failure rolls all back.
        if(frozenCategories.isNotEmpty){
          final categoryNames=categoryList.map((c)=>
           '${c['income']}|${c['name']}'.toLowerCase()).toSet();
          final pendingIds=<String>{};
          for(final c in frozenCategories){
            final name=c['name'] as String,id=c['id'] as String;
            final income=c['income'] as bool, parentId=c['parentId'] as String;
            final normalizedName='$income|$name'.toLowerCase();
            if(!usedCategoryNames.contains(normalizedName))continue;
            if(categoryNames.contains(normalizedName))continue;
            final parent=categoryList.where((item)=>item['id']==parentId&&
              item['income']==income&&
              (item['parentId']==null||item['parentId']=='')).toList();
            if(parent.length!=1||
              !name.startsWith('${parent.single['name']} / ')){
              throw StateError('Merchant category parent is absent or invalid.');
            }
            if(categoryIds.contains(id)||!pendingIds.add(id)){
              throw StateError('Duplicate category identifier.');
            }
            final raw=jsonEncode(c);
            await snapshot.store.customStatement(
             'INSERT INTO fresh_finance_categories '
             '(category_id,name,parent_id,is_income,budget_minor,source_json) '
             'VALUES (?,?,?,?,?,?)',
             [id,name,parentId,income?1:0,0,raw],
            );
            categoryList.add(c);
            categoryNames.add(normalizedName);categoryIds.add(id);
          }
          next['waffra_categories_v24']=jsonEncode(categoryList);
          final count=await snapshot.store.customSelect(
            'SELECT count(*) AS n FROM fresh_finance_categories').getSingle();
          if(count.read<int>('n')!=categoryList.length){
            throw StateError('SQLCipher merchant category projection parity failed.');
          }
        }
        // Unrelated goals, recurring, savings and receipts stay byte-identical.
        next['entries'] = jsonEncode(list);
        if (confirmedHashes.any((hash) => hash != null)) {
          next['waffra_sms_hashes_v1'] = existingHashes.toList()..sort();
        }
        final written = await snapshot.commit(
          expectedGeneration: current.generation,
          fullFinanceSnapshot: next,
        );
        // A successful insert alone is NOT proof of preservation: the
        // canonical encrypted ledger and the typed encrypted SQL projection
        // must contain the exact originally confirmed multiline bank note.
        // Verify inside the SAME SQLCipher transaction so any source-json
        // truncation, tampering or projection mismatch rolls back the ledger,
        // hash and transaction together. Error strings disclose no SMS text.
        if (newlySavedSmsNotes.isNotEmpty) {
          final canonicalRaw = written.values['entries'];
          if (canonicalRaw is! String) {
            throw StateError('Encrypted SMS note parity is unavailable.');
          }
          final decoded = jsonDecode(canonicalRaw);
          if (decoded is! List) {
            throw StateError('Encrypted SMS ledger is invalid.');
          }
          final canonicalNotes = <String, String>{};
          for (final item in decoded) {
            if (item is! Map) {
              throw StateError('Encrypted SMS ledger row is invalid.');
            }
            final id = item['id'];
            if (id is String && newlySavedSmsNotes.containsKey(id)) {
              if (canonicalNotes.containsKey(id) || item['notes'] is! String) {
                throw StateError('Encrypted SMS ledger note mismatch.');
              }
              canonicalNotes[id] = item['notes'] as String;
            }
          }
          final sqlRows = await snapshot.store.customSelect(
            'SELECT entry_id,source_json FROM fresh_finance_entries',
          ).get();
          final sqlNotes = <String, String>{};
          for (final row in sqlRows) {
            final id = row.read<String>('entry_id');
            if (!newlySavedSmsNotes.containsKey(id)) continue;
            final encoded = jsonDecode(row.read<String>('source_json'));
            if (encoded is! Map || encoded['notes'] is! String ||
                sqlNotes.containsKey(id)) {
              throw StateError('Encrypted SMS SQL note mismatch.');
            }
            sqlNotes[id] = encoded['notes'] as String;
          }
          for (final note in newlySavedSmsNotes.entries) {
            if (canonicalNotes[note.key] != note.value ||
                sqlNotes[note.key] != note.value) {
              throw StateError('Encrypted SMS original note parity failed.');
            }
          }
        }
        return WaffraUnifiedWriteResult(
          saved: saved,
          savedIncome: savedIncome,
          savedExpenses: savedExpenses,
          incomeMinor: incomeMinor,
          expenseMinor: expenseMinor,
          skippedDuplicates: skipped,
          generation: written.generation,
        );
      });
    });
  }
}

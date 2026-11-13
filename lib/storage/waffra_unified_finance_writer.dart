import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import 'legacy_snapshot_preflight.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_accounts_repository.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_experimental_writer_gate.dart';
import 'waffra_encrypted_receipt_vault.dart';
import 'waffra_portable_encrypted_vault_restorer.dart';

bool waffraSameReceiptBytes(Uint8List a, Uint8List b) {
  if(a.length!=b.length)return false;
  for(var i=0;i<a.length;i++){if(a[i]!=b[i])return false;}
  return true;
}

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

  /// M597: verified two-account SMS transfer, separately booked source fee
  /// and durable source hash MUST be one SQLCipher/app-widget transaction.
  /// No caller can commit a fee with a different writer or an ACK first.
  Future<bool> appendReviewedSmsTransferWithFee({
    required int expectedGeneration,
    required String transferId,
    required String fromAccountId,
    required String toAccountId,
    required int principalMinor,
    required int feeMinor,
    required bool feeIncludedInDebit,
    required String occurredIso,
    required String messageHash,
    required String feeCategory,
    required bool userConfirmed,
  }) async {
    if (!experimentalEnabled || !userConfirmed ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(messageHash) ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(transferId) ||
        fromAccountId == toAccountId ||
        fromAccountId.trim().isEmpty || toAccountId.trim().isEmpty ||
        principalMinor <= 0 || feeMinor <= 0 ||
        principalMinor > 9007199254740991 - feeMinor ||
        (feeIncludedInDebit && principalMinor <= feeMinor) ||
        feeCategory != 'خدمات مالية / رسوم تحويل' ||
        DateTime.tryParse(occurredIso) == null) {
      throw StateError('Unverified SMS transfer or fee; nothing was posted.');
    }
    // When bank states that the fee is INCLUDED, the recipient is credited
    // only principal minus fee. Otherwise it receives the full principal.
    final creditedMinor =
        feeIncludedInDebit ? principalMinor - feeMinor : principalMinor;
    final entryId = '$transferId-fee';
    final gate = WaffraExperimentalWriterGate(
      disposableDirectory: writerDirectory, experimentalEnabled: true);
    return gate.withExclusiveAccess(() async {
      await verifySourceUnderLock?.call();
      return snapshot.store.transaction(() async {
        final current = await snapshot.read();
        if (current.generation != expectedGeneration) {
          throw StateError('Finance changed after transfer review; reload.');
        }
        await WaffraAccountsSchema.requireReady(snapshot.store);
        final categoriesRaw = current.values['waffra_categories_v24'];
        final ledgerRaw = current.values['entries'];
        if (categoriesRaw is! String || ledgerRaw is! String) {
          throw StateError('Authoritative finance data is incomplete.');
        }
        final categoriesDecoded = jsonDecode(categoriesRaw);
        final ledgerDecoded = jsonDecode(ledgerRaw);
        if (categoriesDecoded is! List || ledgerDecoded is! List ||
            categoriesDecoded.any((c) => c is! Map) ||
            ledgerDecoded.any((e) => e is! Map)) {
          throw StateError('Invalid canonical finance data.');
        }
        final categories = categoriesDecoded.map((c) =>
          Map<String, Object?>.from(c as Map)).toList();
        final ledger = ledgerDecoded.map((e) =>
          Map<String, Object?>.from(e as Map)).toList();
        // Existing ID sets and category source JSON must match typed SQL.
        final typedEntries = await snapshot.store.customSelect(
          'SELECT entry_id FROM fresh_finance_entries').get();
        final entryIds = ledger.map((e) => e['id']).toSet();
        if (entryIds.length != ledger.length ||
            typedEntries.length != ledger.length ||
            typedEntries.map((r) => r.read<String>('entry_id')).toSet()
                .difference(entryIds).isNotEmpty) {
          throw StateError('SQLCipher ledger parity failed.');
        }
        final typedCategories = await snapshot.store.customSelect(
          'SELECT category_id,source_json FROM fresh_finance_categories').get();
        final categoryById = {
          for (final r in typedCategories)
            r.read<String>('category_id'):r.read<String>('source_json'),
        };
        if (categoryById.length != categories.length ||
            categories.any((c) => categoryById[c['id']] != jsonEncode(c))) {
          throw StateError('SQLCipher category parity failed.');
        }
        final eligible = categories.where((c) =>
          c['name'] == feeCategory && c['income'] == false &&
          c['parentId'] is String &&
          (c['parentId'] as String).isNotEmpty &&
          c['categoryActive'] != false).toList();
        if (eligible.length != 1 ||
            !categories.any((c) => c['id'] == eligible.single['parentId'] &&
              c['income'] == false &&
              (c['parentId'] == null || c['parentId'] == '') &&
              c['categoryActive'] != false)) {
          throw StateError('Transfer-fee category is unavailable.');
        }
        final rawHashes = current.values['waffra_sms_hashes_v1'];
        if (rawHashes != null && rawHashes is! List<String>) {
          throw StateError('Invalid canonical SMS fingerprint list.');
        }
        final listHashes = rawHashes as List<String>? ?? const <String>[];
        final hashes = listHashes.toSet();
        final typedHashes = await snapshot.store.customSelect(
          'SELECT message_hash FROM fresh_finance_sms_hashes').get();
        final sqlHashes = typedHashes
            .map((r) => r.read<String>('message_hash')).toSet();
        if (hashes.length != listHashes.length ||
            sqlHashes.length != typedHashes.length ||
            sqlHashes.length != hashes.length ||
            !sqlHashes.containsAll(hashes)) {
          throw StateError('SMS fingerprint SQL parity failed.');
        }
        final transferRows = await snapshot.store.customSelect(
          'SELECT from_account_id,to_account_id,amount_minor,occurred_iso '
          'FROM fresh_finance_internal_transfers WHERE transfer_id=?',
          variables: [Variable.withString(transferId)]).get();
        if (hashes.contains(messageHash)) {
          // A replay is only safe to acknowledge if the same transfer AND
          // separately charged fee exist. Never turn partial legacy saves
          // into a new charge or pretend they are complete.
          final existingFee = ledger.where((e) => e['id'] == entryId).toList();
          if (transferRows.length != 1 || existingFee.length != 1 ||
              transferRows.single.read<String>('from_account_id') != fromAccountId ||
              transferRows.single.read<String>('to_account_id') != toAccountId ||
              transferRows.single.read<int>('amount_minor') != creditedMinor ||
              transferRows.single.read<String>('occurred_iso') != occurredIso ||
              existingFee.single['amount'] != feeMinor / 100 ||
              existingFee.single['category'] != feeCategory) {
            throw StateError('Existing SMS is not this confirmed transfer.');
          }
          return false;
        }
        if (transferRows.isNotEmpty || entryIds.contains(entryId)) {
          throw StateError('Existing transfer must never be double charged.');
        }
        final accounts = WaffraAccountsRepository(
          db: snapshot.store, experimentalEnabled: true);
        final inserted = await accounts.transfer(
          id: transferId, fromAccountId: fromAccountId,
          toAccountId: toAccountId, amountMinor: creditedMinor,
          occurredIso: occurredIso, note: 'تحويل مؤكد من رسالة بنكية',
          userConfirmed: true);
        if (!inserted) {
          throw StateError('SMS transfer had already been posted.');
        }
        final fee = <String, Object?>{
          'id': entryId, 'title': 'رسوم تحويل بنكي',
          'category': feeCategory, 'amount': feeMinor / 100,
          'income': false, 'date': occurredIso, 'receiptPath': null,
          'notes': '', 'personalNotes': '', 'sourceType': 'sms',
          'merchantKey': '',
        };
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_entries '
          '(entry_id,title,category_snapshot,amount_minor,is_income,'
          'occurred_iso,receipt_count,source_json) VALUES (?,?,?,?,?,?,0,?)',
          [entryId, 'رسوم تحويل بنكي', feeCategory, feeMinor, 0,
           occurredIso, jsonEncode(fee)]);
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_account_entry_links '
          '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
          [entryId, fromAccountId, occurredIso]);
        await snapshot.store.customStatement(
          'INSERT INTO fresh_finance_sms_hashes (message_hash) VALUES (?)',
          [messageHash]);
        ledger.add(fee);
        hashes.add(messageHash);
        final next = Map<String, Object?>.from(current.values)
          ..['entries'] = jsonEncode(ledger)
          ..['waffra_sms_hashes_v1'] = (hashes.toList()..sort());
        final saved = await snapshot.commit(
          expectedGeneration: current.generation, fullFinanceSnapshot: next);
        // Verify every consequence before allowing the SQL transaction to
        // commit. If even one assertion fails, Drift rolls all inserts back.
        final transferCheck = await snapshot.store.customSelect(
          'SELECT amount_minor FROM fresh_finance_internal_transfers '
          'WHERE transfer_id=?',
          variables: [Variable.withString(transferId)]).get();
        final feeCheck = await snapshot.store.customSelect(
          'SELECT amount_minor,source_json FROM fresh_finance_entries '
          'WHERE entry_id=?',
          variables: [Variable.withString(entryId)]).get();
        if (transferCheck.length != 1 ||
            transferCheck.single.read<int>('amount_minor') != creditedMinor ||
            feeCheck.length != 1 ||
            feeCheck.single.read<int>('amount_minor') != feeMinor ||
            feeCheck.single.read<String>('source_json') != jsonEncode(fee) ||
            saved.values['entries'] != jsonEncode(ledger) ||
            (saved.values['waffra_sms_hashes_v1'] as List<String>)
                .contains(messageHash) != true) {
          throw StateError('Atomic transfer/fee/hash verification failed.');
        }
        return true;
      });
    });
  }

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
    // Confirmed manual and reviewed SMS records both require explicit account linkage.
    // It shares this method's app/widget lock and SQL transaction.
    String? accountId,
    List<String?>? selectedAccountIds,
    int? expectedAccountGeneration,
    List<Uint8List>? manualReceiptImages,
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
    // Freeze picker bytes before any awaited account witness or source lock.
    // No file path may enter the encrypted canonical finance ledger.
    final frozenReceiptImages = manualReceiptImages == null ? null :
        List<Uint8List>.unmodifiable(
          manualReceiptImages.map(Uint8List.fromList));
    if (frozenReceiptImages != null) {
      if (confirmedRecords.length != 1 ||
          !((confirmedHashes.single == null &&
             confirmedRecords.single['sourceType'] == 'manual') ||
            (confirmedHashes.single != null &&
             confirmedRecords.single['sourceType'] == 'sms')) ||
          (confirmedRecords.single['receiptPath'] != null &&
           confirmedRecords.single['receiptPath'] != '') ||
          confirmedRecords.single['id'] is! String ||
          (confirmedRecords.single['id'] as String).trim().isEmpty ||
          frozenReceiptImages.isEmpty ||
          frozenReceiptImages.length >
              WaffraEncryptedReceiptVault.maxReceiptsPerEntry ||
          frozenReceiptImages.any((image) => image.isEmpty ||
              image.length > WaffraEncryptedReceiptVault.maxReceiptBytes) ||
          frozenReceiptImages.fold<int>(
                  0, (total, image) => total + image.length) >
              60 * 1024 * 1024) {
        throw StateError('Invalid confirmed single-entry receipt batch.');
      }
      final entryId = confirmedRecords.single['id'] as String;
      final refs = List<String>.generate(frozenReceiptImages.length,
        (i) => WaffraEncryptedReceiptReference.of(entryId, i));
      final normalized = Map<String, Object?>.from(confirmedRecords.single);
      normalized['receiptPath'] =
          refs.length == 1 ? refs.single : jsonEncode(refs);
      confirmedRecords[0] = Map<String, Object?>.unmodifiable(normalized);
    }
    // One explicit account decision per confirmed transaction. The old
    // single-manual-account argument remains supported for existing callers.
    // Freeze selections before the first await, as the UI may change them.
    if(accountId!=null && selectedAccountIds!=null){
      throw StateError('Ambiguous account selection.');
    }
    if(accountId!=null && (
       accountId.trim().isEmpty || accountId.length>128 ||
       confirmedRecords.length!=1 || confirmedHashes.single!=null ||
       confirmedRecords.single['sourceType']!='manual')) {
      throw StateError('Single account shortcut requires one manual entry.');
    }
    final confirmedAccounts=List<String?>.unmodifiable(
      selectedAccountIds??List<String?>.filled(
       confirmedRecords.length,accountId));
    if(confirmedAccounts.length!=confirmedRecords.length ||
       confirmedAccounts.any((id)=>id!=null &&
        (id.trim().isEmpty || id.length>128))){
      throw ArgumentError('Account choices must match confirmed entries.');
    }
    final hasAccountLinks=confirmedAccounts.any((id)=>id!=null);
    // M679: a new entry saved through the ACTIVATED production writer must
    // link to exactly one verified money account. Authenticated legacy
    // restore is a different path and retains its original accountless IDs.
    if(verifySourceUnderLock!=null &&
        confirmedAccounts.any((id)=>id==null)){
      throw StateError('A verified account is required for each new transaction.');
    }
    if(frozenReceiptImages!=null && !hasAccountLinks){
      throw StateError('Confirmed receipts require one verified money account.');
    }
    if(hasAccountLinks && expectedAccountGeneration==null){
      throw StateError('Account-linked save needs witnessed finance generation.');
    }

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
      if (data['receiptPath'] != null && data['receiptPath'] != '' &&
          frozenReceiptImages == null) {
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
        if(hasAccountLinks){
          if(current.generation!=expectedAccountGeneration){
            throw StateError('Accounts or transactions changed. Reload before posting.');
          }
          await WaffraAccountsSchema.requireReady(snapshot.store);
          for(final id in confirmedAccounts.whereType<String>().toSet()){
            final account=await snapshot.store.customSelect(
              'SELECT archived,currency FROM fresh_finance_money_accounts '
              'WHERE account_id=?',variables:[Variable.withString(id)],
            ).get();
            if(account.length!=1 ||
               account.single.read<int>('archived')!=0 ||
               account.single.read<String>('currency')!='SAR'){
              throw StateError('Chosen finance account is not active or valid.');
            }
          }
        }

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
          if (frozenReceiptImages != null) {
            // This is inside the SAME native-lock SQLCipher transaction as
            // the ledger and account link. No early partial financial save.
            final vault = WaffraEncryptedReceiptVault(
              store: snapshot.store, experimentalEnabled: true);
            await vault.attachNewBatch(
              entryId: record['id'] as String,
              images: frozenReceiptImages);
            final persisted = await vault.readAll(record['id'] as String);
            if (persisted.length != frozenReceiptImages.length ||
                persisted.asMap().entries.any((row) =>
                  !waffraSameReceiptBytes(row.value.bytes,
                      frozenReceiptImages[row.key]))) {
              throw StateError('Encrypted receipt verification failed.');
            }
          }
          // Atomic double-entry association: the original classified ledger
          // row and its selected account link either BOTH commit, or neither.
          final selectedAccount=confirmedAccounts[i];
          if(selectedAccount!=null){
            await snapshot.store.customStatement(
              'INSERT INTO fresh_finance_account_entry_links '
              '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
              [record['id'],selectedAccount,DateTime.now().toIso8601String()],
            );
          }
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

import 'dart:convert';

import 'package:collection/collection.dart';

import 'waffra_account_context_schema.dart';
import 'waffra_accounts_finance_history.dart';
import 'waffra_accounts_portable_backup_v3.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_atomic_finance_snapshot.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_portable_backup_v2.dart';
import 'waffra_restored_finance_receipt_attestor.dart';

class WaffraVerifiedAccountsRestoreReceipt {
 const WaffraVerifiedAccountsRestoreReceipt(
  this.transactionCount,this.receiptCount,this.previousGeneration,
  this.newGeneration,
 );
 final int transactionCount,receiptCount,previousGeneration,newGeneration;
}

/// Apply a cold-attested V3 to the ALREADY ACTIVE SQLCipher source.
/// A caller must hold the active Home/Widget writer lock, verify source
/// activation, authenticate the incoming archive and obtain user consent.
/// The *existing* source is protected by the outermost SQLite transaction:
/// failed/aborted restores roll back, without exporting a second backup.
/// This never changes keys, source pointers, credentials or Firebase.
/// Unsupported retained records cause failure before any deletion.
/// A failure anywhere restores the original rows, typed histories, SMS hashes,
/// receipt bytes and snapshot through SQLite's outermost transaction rollback.
class WaffraVerifiedActiveAccountsRestore {
 const WaffraVerifiedActiveAccountsRestore({
  required this.store,required this.snapshot,this.experimentalEnabled=false,
 });
 final WaffraEncryptedStore store;
 final WaffraAtomicFinanceSnapshot snapshot;
 final bool experimentalEnabled;

 static const _permanent=<String>{
  'fresh_finance_meta',
  'fresh_finance_domain_revision',
  'fresh_finance_account_revision',
  'fresh_finance_account_context_revision',
  'fresh_finance_cutover_checkpoint',
 };
 static const _archived=<String>{
  'fresh_finance_snapshot_state','fresh_finance_entries',
  'fresh_finance_receipt_blobs','fresh_finance_custom_goals',
  'fresh_finance_sms_hashes',
  ...WaffraAccountsFinanceHistory.tables,
  ...WaffraAccountsSchema.tables,
  ...WaffraAccountContextSchema.tables,
 };

 Future<WaffraVerifiedAccountsRestoreReceipt> restore({
  required String encryptedArchive,required String password,
  required int expectedGeneration,required String expectedDigest,
  required String preflightChecksum,required bool userConfirmed,
 }) async {
  if(!experimentalEnabled||!userConfirmed||
      password.isEmpty||preflightChecksum.isEmpty) {
   throw StateError('Restore requires authenticated user consent and checksum.');
  }
  // Authenticate the supplied archive before opening a transaction with live money.
  final archive=await WaffraAccountsPortableBackupV3.verifyAndPreview(
   encryptedArchive:encryptedArchive,password:password);
  if(archive.history==null) {
   throw StateError('Legacy V3 lacks authenticated finance history; restore refused.');
  }
  final preview=await WaffraPortableBackupV2.verifyAndPreview(
   encryptedArchive:archive.encryptedV2,password:password);
  if(preview.sourceChecksum!=preflightChecksum) {
   throw StateError('Archive no longer matches its cold-restore preview.');
  }
  return store.transaction(()async{
   await WaffraAccountsSchema.requireReady(store);
   await WaffraAccountContextSchema.requireReady(store);
   final before=await snapshot.read();
   if(before.generation!=expectedGeneration||
      before.digest!=expectedDigest){
    throw StateError('Active money changed since restore preflight.');
   }
   // Independently attest current snapshot versus typed SQL under the
   // protected writer transaction. No second encrypted rescue is generated;
   // a failure rolls back every live row to its original state.
   // Never silently discard existing SMS deduplication fingerprints.
   final hashesBefore=before.values['waffra_sms_hashes_v1'];
   if(hashesBefore!=null&&hashesBefore is! List<String>){
    throw StateError('Invalid canonical SMS hash snapshot.');
   }
   final expectedHashes=(hashesBefore as List<String>? ?? const <String>[]).toSet();
   final hashRows=await store.customSelect(
    'SELECT message_hash FROM fresh_finance_sms_hashes').get();
   final typedHashes=hashRows.map((r)=>r.read<String>('message_hash')).toSet();
   if(!const SetEquality<String>().equals(expectedHashes,typedHashes)){
    throw StateError('SMS duplicate ledger is not fully backed up.');
   }
   const same=DeepCollectionEquality();
   // Read active typed history before replacing any rows, so malformed
   // relations or unsupported retained records fail closed. There is no
   // plaintext backup, export, or external rescue side effect.
   await WaffraAccountsPortableBackupV3.capture(store);
   await WaffraAccountsFinanceHistory.capture(store);
   final all=await store.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name LIKE 'fresh_finance_%'").get();
   final present=<String>{for(final row in all)row.read<String>('name')};
   if(!present.containsAll(const <String>{
       'fresh_finance_meta','fresh_finance_domain_revision',
       'fresh_finance_account_revision',
       'fresh_finance_account_context_revision',
      })||
      !present.contains('fresh_finance_snapshot_state')) {
    throw StateError('Required finance tables are missing.');
   }
   for(final table in present.difference(_archived.union(_permanent))) {
    // A future schema or a non-portable recycle blob is NEVER erased.
    // No caller-controlled SQL identifiers reach this method.
    if(!RegExp(r'^fresh_finance_[a-z0-9_]+$').hasMatch(table)) {
     throw StateError('Unknown financial table schema.');
    }
    final count=await store.customSelect(
     'SELECT count(*) AS n FROM $table').getSingle();
    if(count.read<int>('n')!=0) {
     throw StateError('Existing unarchived finance records block replacement.');
    }
   }

   // Discover FK dependencies from the local versioned schema. Delete child
   // rows before their parents; a cycle is refused rather than disabling FKs.
   final remaining=_archived.intersection(present).toSet();
   final references=<String,Set<String>>{};
   for(final table in remaining) {
    final fk=await store.customSelect('PRAGMA foreign_key_list($table)').get();
    references[table]={
     for(final row in fk)
      if(remaining.contains(row.read<String>('table'))&&
         row.read<String>('table')!=table) row.read<String>('table'),
    };
   }
   final order=<String>[];
   while(remaining.isNotEmpty){
    final next=remaining.where((t)=>
      !remaining.any((child)=>child!=t&&
       references[child]!.contains(t))).toList()..sort();
    if(next.isEmpty)throw StateError('Unrestorable cyclic finance relations.');
    final table=next.first;
    order.add(table);remaining.remove(table);
   }
   for(final table in order){
    if(table=='fresh_finance_categories'){
     // The M452 SQL parent guard requires children removed first. The
     // surrounding source-witnessed SQL transaction rolls back everything
     // if any later restore validation fails.
     await store.customStatement(
      "DELETE FROM fresh_finance_categories WHERE COALESCE(parent_id,'')<>''");
    }
    await store.customStatement('DELETE FROM $table');
   }
   // All source activation/cutover checkpoints survive unchanged.
   final restored=await WaffraAccountsPortableBackupV3
    .restoreToEmptyEncryptedVault(
     encryptedArchive:encryptedArchive,password:password,
     disposableStore:store,userConfirmed:true,experimentalEnabled:true);
   final restoredRaw=preview.financialSnapshot['entries'];
   final verifiedEntries=restoredRaw==null?<Object>[]:jsonDecode(restoredRaw as String) as List;
   if(restored.sourceChecksum!=preview.sourceChecksum||
      restored.transactionCount!=verifiedEntries.length||
      restored.receiptCount!=preview.receiptCount) {
    throw StateError('Restored finance and receipt proof differs.');
   }
   // The final live vault must contain the exact authenticated receipt
   // owner/position/bytes, not merely the expected number of attachments.
   await WaffraRestoredFinanceReceiptAttestor(
    store:store,experimentalEnabled:true,
   ).attest(authenticatedArchive:preview,reported:restored);
   // The portable restorer creates generation 1 for a new vault. Revisions
   // of an EXISTING live source must never move backward or reuse a stale
   // Home/Widget generation.
   final newGeneration=before.generation+1>1?before.generation+1:2;
   await store.customStatement(
    'UPDATE fresh_finance_snapshot_state SET generation=? '
    'WHERE singleton=1 AND generation=1',[newGeneration]);
   final snap=await snapshot.read();
   if(snap.generation!=newGeneration) {
    throw StateError('Restored generation failed to advance.');
   }
   // The V2 snapshot already authenticates these hashes. Reconstruct the
   // typed duplicate index, which legacy V2 portable fields don't carry as a
   // distinct SQL table.
   final hashes=snap.values['waffra_sms_hashes_v1'];
   if(hashes!=null) {
    if(hashes is! List<String>) {
     throw StateError('Invalid authenticated SMS duplicate index.');
    }
    for(final hash in hashes.toSet()){
     if(!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw StateError('Invalid restored SMS fingerprint.');
     }
     await store.customStatement(
      'INSERT INTO fresh_finance_sms_hashes(message_hash) VALUES (?)',
      [hash]);
    }
   }
   final finalAccounts=await WaffraAccountsPortableBackupV3.capture(store);
   if(!same.equals(finalAccounts['accounts'],archive.accounts)||
      !same.equals(finalAccounts['links'],archive.links)||
      !same.equals(finalAccounts['transfers'],archive.transfers)||
      !same.equals(finalAccounts['contextV1'], archive.context ?? <String,Object?>{'goalSources':<Object>[], 'recurringDefaults':<Object>[], 'smsSuffixes':<Object>[]})||
      !same.equals(
       await WaffraAccountsFinanceHistory.capture(store),archive.history)||
      (await store.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty){
    throw StateError('Restored account/history parity failed.');
   }
   // No data leaves SQLCipher while the source is being replaced.
   return WaffraVerifiedAccountsRestoreReceipt(
    restored.transactionCount,restored.receiptCount,
    before.generation,newGeneration);
  });
 }
}

import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// M470 typed account identities. M942 v2 widens only the approved
/// provider constraints, preserving every verified account/ledger opening.
/// Legacy v1 is readable and upgraded transactionally before any new write.
abstract final class WaffraAccountDetailsSchema {
 static const version=2;
 static const details='fresh_finance_account_details';
 static const revision='fresh_finance_account_details_revision';
 static const _upgradedDetails='fresh_finance_account_details_m942';
 static const _upgradedRevision='fresh_finance_account_details_revision_m942';

 static const bankProviders=<String>{
  'rajhi','inma','snb','riyad','bilad','stc','other',
  'sabb','anb','bsf','saib','jazira','gib','vision','d360',
 };
 static const walletProviders=<String>{
  'stc','other','barq','enjazpay','alinmapay',
 };
 static const bankSubtypes=<String>{
  'current','savings','investment','deposit','other'
 };
 static bool valid({
  required String kind,required String providerId,required String subtype,
 }){
  switch(kind){
   case 'bank':
    return bankProviders.contains(providerId)&&bankSubtypes.contains(subtype);
   case 'wallet':
    return walletProviders.contains(providerId)&&
     const {'digital','prepaid'}.contains(subtype);
   case 'cash':
    return providerId=='none'&&subtype=='cash';
   case 'other':
    return providerId=='none'&&subtype=='other';
  }
  return false;
 }

 static Future<bool> exists(WaffraEncryptedStore db)async{
  final r=await db.customSelect(
   'SELECT name FROM sqlite_master WHERE type=\'table\' AND name=?',
   variables:[Variable.withString(revision)]).get();
  return r.length==1;
 }

 /// Only known, compile-time names are passed. No caller-controlled SQL ID.
 static Future<void> _createDetails(WaffraEncryptedStore db,String table)async{
  if(table!=details&&table!=_upgradedDetails){
   throw ArgumentError('Unexpected account-details table name.');
  }
  await db.customStatement('''
CREATE TABLE $table(
 account_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 provider_id TEXT NOT NULL CHECK(provider_id IN
  ('rajhi','inma','snb','riyad','bilad','stc','other',
   'sabb','anb','bsf','saib','jazira','gib','vision','d360',
   'barq','enjazpay','alinmapay','none')),
 subtype TEXT NOT NULL CHECK(subtype IN
  ('current','savings','investment','deposit','digital','prepaid','cash','other')),
 confirmed_iso TEXT NOT NULL
)''');
 }

 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  await db.transaction(()async{
   if(await exists(db)){
    // First attest the legacy v1 table and foreign keys, then migrate.
    await requireReady(db);
    final rows=await db.customSelect(
     "SELECT version FROM $revision WHERE slot='account_details'").get();
    if(rows.length!=1)throw StateError('Account details revision missing.');
    final storedVersion=rows.single.read<int>('version');
    if(storedVersion==version)return;
    if(storedVersion!=1)throw StateError('Unsupported account details revision.');
    final originalCount=(await db.customSelect(
     'SELECT COUNT(*) AS n FROM $details').getSingle()).read<int>('n');
    // M942: atomic metadata-only swap; money accounts, opening_minor,
    // finance entries, transfers and account links are never touched.
    await _createDetails(db,_upgradedDetails);
    await db.customStatement(
     'INSERT INTO $_upgradedDetails '
     '(account_id,provider_id,subtype,confirmed_iso) '
     'SELECT account_id,provider_id,subtype,confirmed_iso FROM $details');
    final copiedCount=(await db.customSelect(
     'SELECT COUNT(*) AS n FROM $_upgradedDetails').getSingle()).read<int>('n');
    if(copiedCount!=originalCount)throw StateError(
     'Typed account migration did not preserve every identity.');
    await db.customStatement('DROP TABLE $details');
    await db.customStatement('ALTER TABLE $_upgradedDetails RENAME TO $details');
    await db.customStatement('''
CREATE TABLE $_upgradedRevision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='account_details'),
 version INTEGER NOT NULL CHECK(version=2)
)''');
    await db.customStatement(
     "INSERT INTO $_upgradedRevision(slot,version) VALUES('account_details',2)");
    await db.customStatement('DROP TABLE $revision');
    await db.customStatement('ALTER TABLE $_upgradedRevision RENAME TO $revision');
    await requireReady(db);
    return;
   }
   for(final table in [details,_upgradedDetails,_upgradedRevision]){
    final found=await db.customSelect(
     "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
     variables:[Variable.withString(table)]).get();
    if(found.isNotEmpty)throw StateError(
     'Unversioned account details require authenticated recovery.');
   }
   await _createDetails(db,details);
   await db.customStatement('''
CREATE TABLE $revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='account_details'),
 version INTEGER NOT NULL CHECK(version=2)
)''');
   await db.customStatement(
    "INSERT INTO $revision(slot,version) VALUES('account_details',2)");
   await requireReady(db);
  });
 }

 /// Reads remain compatible with encrypted v1 accounts until the next
 /// verified typed account creation migrates the metadata table.
 static Future<void> requireReady(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  final r=await db.customSelect(
   'SELECT version FROM $revision WHERE slot=\'account_details\'').get();
  if(r.length!=1||
    !const {1,2}.contains(r.single.read<int>('version'))){
   throw StateError('Unsupported encrypted account details.');
  }
  final table=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
   variables:[Variable.withString(details)]).get();
  if(table.length!=1)throw StateError('Missing typed account details.');
  if((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty){
   throw StateError('Account details have invalid foreign keys.');
  }
 }

 static Future<void> assign(WaffraEncryptedStore db,{
  required String accountId,required String kind,
  required String providerId,required String subtype,
  required String confirmedIso,
  bool allowArchivedRestore=false,
 })async{
  await install(db); // v1 typed details migrate before any new provider write.
  if(accountId.trim().isEmpty||accountId.length>128||
     !valid(kind:kind,providerId:providerId,subtype:subtype)||
     confirmedIso.length>40||DateTime.tryParse(confirmedIso)==null){
   throw ArgumentError('Invalid account identity metadata.');
  }
  final a=await db.customSelect(
   'SELECT kind,archived FROM fresh_finance_money_accounts WHERE account_id=?',
   variables:[Variable.withString(accountId)]).get();
  // Only an authenticated, prevalidated disposable-vault restore is
  // permitted to carry identity metadata for an already archived account.
  // Ordinary account edits can never resurrect or modify archived records.
  if(a.length!=1||a.single.read<String>('kind')!=kind||
     (!allowArchivedRestore&&a.single.read<int>('archived')!=0)){
   throw StateError('Identity must match a live verified money account.');
  }
  await db.customStatement(
   'INSERT INTO fresh_finance_account_details '
   '(account_id,provider_id,subtype,confirmed_iso) VALUES (?,?,?,?)',
   [accountId,providerId,subtype,confirmedIso]);
 }
}

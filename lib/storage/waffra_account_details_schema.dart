import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// M470 additive, independently versioned account identity metadata.
/// The original four money-account kinds, balances and ledger schema do
/// NOT change. Pre-existing accounts without details remain valid.
abstract final class WaffraAccountDetailsSchema {
 static const version=1;
 static const details='fresh_finance_account_details';
 static const revision='fresh_finance_account_details_revision';

 static const bankProviders=<String>{
  'rajhi','inma','snb','riyad','bilad','stc','other'
 };
 static const bankSubtypes=<String>{
  'current','savings','investment','deposit','other'
 };
 static bool valid({
  required String kind,required String providerId,required String subtype,
 }){
  switch(kind){
   case 'bank':
    return bankProviders.contains(providerId)&&
     bankSubtypes.contains(subtype);
   case 'wallet':
    return const {'stc','other'}.contains(providerId)&&
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
   "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
   variables:[Variable.withString(revision)]).get();
  return r.length==1;
 }

 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  await db.transaction(()async{
   if(await exists(db)){await requireReady(db);return;}
   final ghost=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables:[Variable.withString(details)]).get();
   if(ghost.isNotEmpty)throw StateError(
    'Unversioned account details need verified recovery.');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_details(
 account_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 provider_id TEXT NOT NULL CHECK(provider_id IN
  ('rajhi','inma','snb','riyad','bilad','stc','other','none')),
 subtype TEXT NOT NULL CHECK(subtype IN
  ('current','savings','investment','deposit','digital','prepaid','cash','other')),
 confirmed_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_details_revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='account_details'),
 version INTEGER NOT NULL CHECK(version=1)
)''');
   await db.customStatement(
    "INSERT INTO fresh_finance_account_details_revision(slot,version) "
    "VALUES('account_details',?)",[version]);
   await requireReady(db);
  });
 }

 static Future<void> requireReady(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  final r=await db.customSelect(
   'SELECT version FROM fresh_finance_account_details_revision '
   "WHERE slot='account_details'").get();
  if(r.length!=1||r.single.read<int>('version')!=version){
   throw StateError('Unsupported encrypted account details schema.');
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
  await requireReady(db);
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

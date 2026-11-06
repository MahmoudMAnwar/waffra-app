import 'package:drift/drift.dart';

import 'waffra_account_details_schema.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// M487 / #406: optional, independently versioned encrypted display labels.
/// The canonical bank/wallet subtype and accounting classification remain
/// unchanged; custom text never becomes an unvalidated ledger enum.
abstract final class WaffraCustomAccountSubtypeSchema {
 static const revision='fresh_finance_custom_account_subtypes_revision';
 static const table='fresh_finance_custom_account_subtypes';
 static const version=1;

 static bool validLabel(String value){
  final trimmed=value.trim();
  return trimmed.runes.length>=2&&trimmed.runes.length<=40&&
   !RegExp(r'[\u0000-\u001f\u007f]').hasMatch(trimmed);
 }

 static Future<bool> exists(WaffraEncryptedStore db)async{
  final rows=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
   variables:[Variable.withString(revision)]).get();
  return rows.length==1;
 }

 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  await WaffraAccountDetailsSchema.requireReady(db);
  await db.transaction(()async{
   if(await exists(db)){await requireReady(db);return;}
   final ghost=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables:[Variable.withString(table)]).get();
   if(ghost.isNotEmpty)throw StateError(
    'Unversioned custom account subtypes require verified recovery.');
   await db.customStatement('''
CREATE TABLE fresh_finance_custom_account_subtypes(
 account_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 kind TEXT NOT NULL CHECK(kind IN ('bank','wallet')),
 label TEXT NOT NULL CHECK(length(label) BETWEEN 2 AND 40),
 confirmed_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_custom_account_subtypes_revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='custom_account_subtypes'),
 version INTEGER NOT NULL CHECK(version=1)
)''');
   await db.customStatement(
    "INSERT INTO fresh_finance_custom_account_subtypes_revision(slot,version) "
    "VALUES('custom_account_subtypes',?)",[version]);
   await requireReady(db);
  });
 }

 static Future<void> requireReady(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  final rows=await db.customSelect(
   "SELECT version FROM fresh_finance_custom_account_subtypes_revision "
   "WHERE slot='custom_account_subtypes'").get();
  if(rows.length!=1||rows.single.read<int>('version')!=version){
   throw StateError('Unsupported custom account subtype schema.');
  }
  final found=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
   variables:[Variable.withString(table)]).get();
  if(found.length!=1)throw StateError('Missing custom account subtype table.');
  if((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty){
   throw StateError('Invalid custom account subtype reference.');
  }
 }

 static Future<void> assign(WaffraEncryptedStore db,{
  required String accountId,required String kind,
  required String label,required String confirmedIso,
 })async{
  await requireReady(db);
  final clean=label.trim();
  if((kind!='bank'&&kind!='wallet')||!validLabel(clean)||
    accountId.trim().isEmpty||accountId.length>128||
    DateTime.tryParse(confirmedIso)==null){
   throw ArgumentError('Invalid custom account subtype.');
  }
  final account=await db.customSelect(
   'SELECT kind,archived FROM fresh_finance_money_accounts WHERE account_id=?',
   variables:[Variable.withString(accountId)]).get();
  if(account.length!=1||account.single.read<String>('kind')!=kind||
     account.single.read<int>('archived')!=0){
   throw StateError('Custom subtype requires a verified active account.');
  }
  await db.customStatement(
   'INSERT INTO fresh_finance_custom_account_subtypes '
   '(account_id,kind,label,confirmed_iso) VALUES (?,?,?,?)',
   [accountId,kind,clean,confirmedIso]);
 }
}

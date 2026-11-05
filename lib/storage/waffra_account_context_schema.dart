import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

/// Additive M448 source metadata inside the SAME verified SQLCipher vault.
//// Existing M440 account and finance migrations are not replaced.
abstract final class WaffraAccountContextSchema {
 static const version=1;
 static const tables=<String>[
  'fresh_finance_goal_account_sources',
  'fresh_finance_recurring_account_defaults',
  'fresh_finance_account_sms_suffixes',
 ];

 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  await db.transaction(()async{
   final markers=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name='fresh_finance_account_context_revision'").get();
   if(markers.isNotEmpty){await requireReady(db);return;}
   for(final name in tables){
    final found=await db.customSelect(
     "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
     variables:[Variable.withString(name)]).get();
    if(found.isNotEmpty)throw StateError(
     'Unversioned account context requires verified recovery.');
   }
   await db.customStatement('''
CREATE TABLE fresh_finance_goal_account_sources(
 movement_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_goal_wallet_movements(movement_id) ON DELETE RESTRICT,
 account_id TEXT NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 linked_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_recurring_account_defaults(
 recurring_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_recurring(recurring_id) ON DELETE RESTRICT,
 account_id TEXT NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 changed_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_sms_suffixes(
 account_id TEXT PRIMARY KEY NOT NULL
  REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 last_four TEXT NOT NULL CHECK(
  length(last_four)=4 AND last_four NOT GLOB '*[^0-9]*'),
 confirmed_iso TEXT NOT NULL
)''');
   await db.customStatement(
    'CREATE INDEX idx_m448_goal_sources_account '
    'ON fresh_finance_goal_account_sources(account_id)');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_context_revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='account_context'),
 version INTEGER NOT NULL CHECK(version>0)
)''');
   await db.customStatement(
    "INSERT INTO fresh_finance_account_context_revision(slot,version) "
    "VALUES('account_context',?)",[version]);
   await requireReady(db);
  });
 }

 static Future<void> requireReady(WaffraEncryptedStore db)async{
  await WaffraAccountsSchema.requireReady(db);
  final marker=await db.customSelect(
   "SELECT version FROM fresh_finance_account_context_revision "
   "WHERE slot='account_context'").get();
  if(marker.length!=1 || marker.single.read<int>('version')!=version){
   throw StateError('Unsupported encrypted account-context schema.');
  }
  for(final name in tables){
   final found=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables:[Variable.withString(name)]).get();
   if(found.length!=1)throw StateError('Missing account-context table.');
  }
  if((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty){
   throw StateError('Account-context foreign keys are not verified.');
  }
 }
}

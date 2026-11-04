import 'package:drift/drift.dart';
import 'waffra_encrypted_store.dart';
import 'waffra_fresh_finance_domain_schema.dart';

/// SQLCipher-only M440 tables. Does not activate finance cutover or create
/// a competing finance database. Existing ledger entries remain untouched.
abstract final class WaffraAccountsSchema {
 static const version=1;
 static const tables=<String>[
  'fresh_finance_money_accounts','fresh_finance_account_entry_links',
  'fresh_finance_internal_transfers'
 ];
 static Future<void> install(WaffraEncryptedStore db)async{
  await WaffraFreshFinanceDomainSchema.requireReady(db);
  await db.transaction(()async{
   final revision=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' "
    "AND name='fresh_finance_account_revision'").get();
   if(revision.isNotEmpty){await requireReady(db);return;}
   for(final table in tables){
    final found=await db.customSelect(
     "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
     variables:[Variable.withString(table)]).get();
    if(found.isNotEmpty)throw StateError('Unversioned accounts database requires recovery.');
   }
   await db.customStatement('''
CREATE TABLE fresh_finance_money_accounts(
 account_id TEXT PRIMARY KEY NOT NULL,
 label TEXT NOT NULL CHECK(length(trim(label)) BETWEEN 1 AND 80),
 kind TEXT NOT NULL CHECK(kind IN ('cash','bank','wallet','other')),
 currency TEXT NOT NULL DEFAULT 'SAR' CHECK(currency='SAR'),
 opening_minor INTEGER NOT NULL CHECK(opening_minor>=0),
 archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)),
 created_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_entry_links(
 entry_id TEXT PRIMARY KEY NOT NULL REFERENCES fresh_finance_entries(entry_id) ON DELETE RESTRICT,
 account_id TEXT NOT NULL REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 confirmed_iso TEXT NOT NULL
)''');
   await db.customStatement('''
CREATE TABLE fresh_finance_internal_transfers(
 transfer_id TEXT PRIMARY KEY NOT NULL,
 from_account_id TEXT NOT NULL REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 to_account_id TEXT NOT NULL REFERENCES fresh_finance_money_accounts(account_id) ON DELETE RESTRICT,
 amount_minor INTEGER NOT NULL CHECK(amount_minor>0),
 occurred_iso TEXT NOT NULL,
 note TEXT NOT NULL DEFAULT '' CHECK(length(note)<=2000),
 CHECK(from_account_id<>to_account_id)
)''');
   await db.customStatement('CREATE INDEX idx_m440_links_account ON fresh_finance_account_entry_links(account_id)');
   await db.customStatement('CREATE INDEX idx_m440_transfers_from ON fresh_finance_internal_transfers(from_account_id)');
   await db.customStatement('CREATE INDEX idx_m440_transfers_to ON fresh_finance_internal_transfers(to_account_id)');
   await db.customStatement('''
CREATE TABLE fresh_finance_account_revision(
 slot TEXT PRIMARY KEY NOT NULL CHECK(slot='accounts'),
 version INTEGER NOT NULL CHECK(version>0)
)''');
   await db.customStatement("INSERT INTO fresh_finance_account_revision(slot,version) VALUES('accounts',?)",[version]);
   await requireReady(db);
  });
 }
 static Future<void> requireReady(WaffraEncryptedStore db)async{
  final found=await db.customSelect(
   "SELECT name FROM sqlite_master WHERE type='table' "
   "AND name='fresh_finance_account_revision'").get();
  if(found.length!=1)throw StateError('Accounts database has not been initialized.');
  final revision=await db.customSelect(
   "SELECT version FROM fresh_finance_account_revision WHERE slot='accounts'").get();
  if(revision.length!=1||revision.single.read<int>('version')!=version)throw StateError('Unsupported accounts schema version.');
  for(final table in tables){
   final current=await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
    variables:[Variable.withString(table)]).get();
   if(current.length!=1)throw StateError('Missing encrypted account table.');
  }
  if((await db.customSelect('PRAGMA foreign_key_check').get()).isNotEmpty)throw StateError('Accounts foreign key check failed.');
 }
}

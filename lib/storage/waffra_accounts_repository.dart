import 'package:drift/drift.dart';

import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

class WaffraAccountBalance {
 const WaffraAccountBalance(this.id,this.name,this.kind,this.balanceMinor,this.archived);
 final String id,name,kind;
 final int balanceMinor;
 final bool archived;
}

/// M440. Account movements share a single preverified SQLCipher domain.
/// The current legacy source is never silently read, mirrored or replaced.
/// A single user-facing contract for a verified finance authority. Direct
/// SQL access remains QA-only; the production adapter must check source and
/// hold the app/widget lock before any mutation.
abstract class WaffraAccountOperations {
 Future<List<WaffraAccountBalance>> balances();
 Future<void> initializeAccounts({required bool userConfirmed});
 Future<void> createAccount({required String id,required String name,
  required String kind,required int openingMinor,required String createdIso,
  required bool userConfirmed});
 Future<bool> transfer({required String id,required String fromAccountId,
  required String toAccountId,required int amountMinor,
  required String occurredIso,String note='',required bool userConfirmed});
 Future<void> renameAccount({required String id,required String name,
  required bool userConfirmed});
 Future<void> archiveEmptyAccount({required String id,required bool userConfirmed});
}

class WaffraAccountsRepository implements WaffraAccountOperations {
 const WaffraAccountsRepository({required this.db,this.experimentalEnabled=false});
 final WaffraEncryptedStore db;
 final bool experimentalEnabled;

 Future<void> initializeAccounts({required bool userConfirmed}) async {
  if(!experimentalEnabled || !userConfirmed) {
   throw StateError('Encrypted account initialization requires release approval.');
  }
  await WaffraAccountsSchema.install(db);
 }

 Future<void> _ready()async{
  if(!experimentalEnabled)throw StateError('Account release not certified for production.');
  await WaffraAccountsSchema.requireReady(db);
 }
 static void _id(String value){
  if(value.trim().isEmpty||value.length>128)throw ArgumentError('Invalid identifier.');
 }
 static void _when(String value){
  if(value.length>40||DateTime.tryParse(value)==null)throw ArgumentError('Invalid timestamp.');
 }
 Future<void> _activeAccount(String id)async{
  final found=await db.customSelect(
   'SELECT archived,currency FROM fresh_finance_money_accounts WHERE account_id=?',
   variables:[Variable.withString(id)]).get();
  if(found.length!=1||found.single.read<int>('archived')!=0||
    found.single.read<String>('currency')!='SAR'){
   throw StateError('Account is missing, archived or not SAR.');
  }
 }

 Future<void> createAccount({required String id,required String name,
  required String kind,required int openingMinor,required String createdIso,
  required bool userConfirmed})async{
  await _ready();
  if(!userConfirmed)throw StateError('Account creation requires approval.');
  _id(id);_when(createdIso);
  if(name.trim().isEmpty||name.runes.length>80||openingMinor<0||
     !const {'cash','bank','wallet','other'}.contains(kind)){
   throw ArgumentError('Invalid Saudi money account.');
  }
  await db.transaction(()async{
   await db.customStatement(
    'INSERT INTO fresh_finance_money_accounts '
    '(account_id,label,kind,currency,opening_minor,created_iso) VALUES (?,?,?,?,?,?)',
    [id,name.trim(),kind,'SAR',openingMinor,createdIso]);
  });
 }

 /// Only after a separately verified old-finance migration and explicit user
 /// approval. Copies NO original transaction and never edits its amount.
 Future<int> linkHistoricalEntries({required String accountId,
  required String linkedIso,required bool userConfirmed,
  required bool verifiedMigration})async{
  await _ready();
  if(!userConfirmed||!verifiedMigration)throw StateError(
   'Historic account mapping requires consent and authenticated migration.');
  _id(accountId);_when(linkedIso);
  return db.transaction(()async{
   await _activeAccount(accountId);
   // A current-balance opening plus re-imported historical income would
   // double count money. Historic mapping requires zero opening, with all
   // prior postings retained in their source ledger.
   final opening=await db.customSelect(
    'SELECT opening_minor FROM fresh_finance_money_accounts WHERE account_id=?',
    variables:[Variable.withString(accountId)]).getSingle();
   if(opening.read<int>('opening_minor')!=0)throw StateError(
    'Historical entry mapping requires a zero opening balance.');
   final rows=await db.customSelect(
    'SELECT e.entry_id FROM fresh_finance_entries e WHERE NOT EXISTS '
    '(SELECT 1 FROM fresh_finance_account_entry_links l '
    'WHERE l.entry_id=e.entry_id)').get();
   for(final row in rows){
    await db.customStatement(
     'INSERT INTO fresh_finance_account_entry_links '
     '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
     [row.read<String>('entry_id'),accountId,linkedIso]);
   }
   return rows.length;
  });
 }

 /// A new income or expense must already be present in the authoritative
 /// finance table. This linking step does not post another income/expense.
 Future<void> linkEntry({required String entryId,required String accountId,
  required String linkedIso,required bool userConfirmed})async{
  await _ready();
  if(!userConfirmed)throw StateError('Account selection must be confirmed.');
  _id(entryId);_id(accountId);_when(linkedIso);
  await db.transaction(()async{
   await _activeAccount(accountId);
   await db.customStatement(
    'INSERT INTO fresh_finance_account_entry_links '
    '(entry_id,account_id,confirmed_iso) VALUES (?,?,?)',
    [entryId,accountId,linkedIso]);
  });
 }

 /// Exactly one durable transfer ID, opposite account effects and ZERO
 /// ledger income/expense entries. Same intent may be retried safely.
 Future<bool> transfer({required String id,required String fromAccountId,
  required String toAccountId,required int amountMinor,
  required String occurredIso,String note='',required bool userConfirmed})async{
  await _ready();
  if(!userConfirmed)throw StateError('Transfer requires user confirmation.');
  _id(id);_id(fromAccountId);_id(toAccountId);_when(occurredIso);
  if(fromAccountId==toAccountId||amountMinor<=0||note.runes.length>2000){
   throw ArgumentError('Invalid internal transfer.');
  }
  return db.transaction(()async{
   await _activeAccount(fromAccountId);
   await _activeAccount(toAccountId);
   final previous=await db.customSelect(
    'SELECT from_account_id,to_account_id,amount_minor,occurred_iso,note '
    'FROM fresh_finance_internal_transfers WHERE transfer_id=?',
    variables:[Variable.withString(id)]).get();
   if(previous.isNotEmpty){
    final item=previous.single;
    if(item.read<String>('from_account_id')!=fromAccountId||
       item.read<String>('to_account_id')!=toAccountId||
       item.read<int>('amount_minor')!=amountMinor||
       item.read<String>('occurred_iso')!=occurredIso||
       item.read<String>('note')!=note){
      throw StateError('Transfer ID reused with different money.');
    }
    return false;
   }
   await db.customStatement(
    'INSERT INTO fresh_finance_internal_transfers '
    '(transfer_id,from_account_id,to_account_id,amount_minor,occurred_iso,note) '
    'VALUES (?,?,?,?,?,?)',
    [id,fromAccountId,toAccountId,amountMinor,occurredIso,note]);
   return true;
  });
 }

 /// Calculated exclusively from SQL. No separate mutable balance can drift.
 Future<List<WaffraAccountBalance>> balances()async{
  await _ready();
  final rows=await db.customSelect('''
SELECT a.account_id,a.label,a.kind,a.archived,
 a.opening_minor +
 COALESCE((SELECT SUM(CASE WHEN e.is_income=1 THEN e.amount_minor
   WHEN due.entry_id IS NOT NULL THEN -due.current_cash_minor
   ELSE -e.amount_minor END)
  FROM fresh_finance_account_entry_links l
  JOIN fresh_finance_entries e ON e.entry_id=l.entry_id
  LEFT JOIN fresh_finance_goal_due_settlements due ON due.entry_id=e.entry_id
  WHERE l.account_id=a.account_id),0) +
 COALESCE((SELECT SUM(t.amount_minor) FROM fresh_finance_internal_transfers t
  WHERE t.to_account_id=a.account_id),0) -
 COALESCE((SELECT SUM(t.amount_minor) FROM fresh_finance_internal_transfers t
  WHERE t.from_account_id=a.account_id),0) AS balance_minor
FROM fresh_finance_money_accounts a
ORDER BY a.created_iso,a.account_id
''').get();
  return List<WaffraAccountBalance>.unmodifiable(rows.map((r)=>
   WaffraAccountBalance(r.read<String>('account_id'),r.read<String>('label'),
    r.read<String>('kind'),r.read<int>('balance_minor'),
    r.read<int>('archived')!=0)));
 }

 Future<void> renameAccount({required String id,required String name,
  required bool userConfirmed})async{
  await _ready();
  if(!userConfirmed)throw StateError('Account rename needs confirmation.');
  _id(id);
  if(name.trim().isEmpty||name.runes.length>80)throw ArgumentError('Invalid account name.');
  await db.transaction(()async{
   await _activeAccount(id);
   await db.customStatement(
    'UPDATE fresh_finance_money_accounts SET label=? WHERE account_id=?',
    [name.trim(),id]);
  });
 }

 Future<void> archiveEmptyAccount({required String id,
  required bool userConfirmed})async{
  await _ready();
  if(!userConfirmed)throw StateError('Account archive needs confirmation.');
  _id(id);
  await db.transaction(()async{
   await _activeAccount(id);
   final matched=(await balances()).where((a)=>a.id==id).toList();
   if(matched.length!=1||matched.single.balanceMinor!=0){
    throw StateError('Non-empty account cannot be archived.');
   }
   await db.customStatement(
    'UPDATE fresh_finance_money_accounts SET archived=1 WHERE account_id=?',[id]);
  });
 }
}

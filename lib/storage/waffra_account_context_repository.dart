import 'dart:convert';

import 'package:drift/drift.dart';

import '../waffra_bank_sms_facts.dart';
import 'waffra_account_context_policy.dart';
import 'waffra_account_context_schema.dart';
import 'waffra_accounts_schema.dart';
import 'waffra_encrypted_store.dart';

class WaffraGoalAccountProgress {
 const WaffraGoalAccountProgress(this.goalId,this.totalSavedMinor,
  this.selectedAccountNetMinor);
 final String goalId;
 final int totalSavedMinor,selectedAccountNetMinor;
}

class WaffraRecurringAccountTemplate {
 const WaffraRecurringAccountTemplate(this.id,this.title,this.accountId);
 final String id,title;
 final String? accountId;
}

/// Verified read-only internal transfer row. This is NOT an income or expense.
class WaffraInternalTransferHistory {
 const WaffraInternalTransferHistory({
  required this.id,required this.fromAccountId,required this.toAccountId,
  required this.amountMinor,required this.occurredIso,required this.note,
 });
 final String id,fromAccountId,toAccountId,occurredIso,note;
 final int amountMinor;
}

/// M448 account attribution metadata: never adds a second income, expense,
/// goal movement, or internal transfer. All mutations require a verified
/// source lock from WaffraVerifiedAccountsApi/Bridge in production.
class WaffraAccountContextRepository {
 const WaffraAccountContextRepository({
  required this.store,this.experimentalEnabled=false,
 });
 final WaffraEncryptedStore store;
 final bool experimentalEnabled;
 Future<void> _ready()async{
  if(!experimentalEnabled)throw StateError('Verified account source required.');
  await WaffraAccountsSchema.requireReady(store);
  await WaffraAccountContextSchema.requireReady(store);
 }
 static void _id(String text){
  if(text.trim().isEmpty||text.length>128)throw ArgumentError('Invalid id.');
 }
 static void _when(String text){
  if(text.length>40||DateTime.tryParse(text)==null){
   throw ArgumentError('Invalid timestamp.');
  }
 }
 Future<void> _active(String id)async{
  final rows=await store.customSelect(
   'SELECT archived,currency FROM fresh_finance_money_accounts WHERE account_id=?',
   variables:[Variable.withString(id)]).get();
  if(rows.length!=1||rows.single.read<int>('archived')!=0||
     rows.single.read<String>('currency')!='SAR'){
   throw StateError('An active SAR account is required.');
  }
 }

 /// Read a single historical entry association without loading the full
 /// ledger into a transaction edit sheet. An absent legacy/non-migrated row
 /// is NOT treated as an accountless verified ledger entry.
 Future<({bool exists,String? accountId})> readExistingEntryAccount({
  required String entryId,
 })async{
  await _ready();_id(entryId);
  final rows=await store.customSelect('''
SELECT e.entry_id,l.account_id FROM fresh_finance_entries e
LEFT JOIN fresh_finance_account_entry_links l ON l.entry_id=e.entry_id
WHERE e.entry_id=?
''',variables:[Variable.withString(entryId)]).get();
  if(rows.length>1)throw StateError('Entry account link is ambiguous.');
  return (exists:rows.length==1,
   accountId:rows.isEmpty?null:rows.single.readNullable<String>('account_id'));
 }

 /// Register the user-confirmed funding source for an EXISTING typed goal
 /// movement. The movement and its amount are never recreated here.
 Future<bool> attributeGoalMovement({
  required String movementId,required String accountId,
  required String linkedIso,required bool userConfirmed,
 })async{
  await _ready();
  if(!userConfirmed)throw StateError('Goal funding source needs confirmation.');
  _id(movementId);_id(accountId);_when(linkedIso);
  return store.transaction(()async{
   await _active(accountId);
   final source=await store.customSelect(
    'SELECT kind FROM fresh_finance_goal_wallet_movements WHERE movement_id=?',
    variables:[Variable.withString(movementId)]).get();
   if(source.length!=1||
      !const {'fund','release'}.contains(source.single.read<String>('kind'))){
    throw StateError('Only actual funding or release may affect an account.');
   }
   final old=await store.customSelect(
    'SELECT account_id FROM fresh_finance_goal_account_sources WHERE movement_id=?',
    variables:[Variable.withString(movementId)]).get();
   if(old.isNotEmpty){
    if(old.single.read<String>('account_id')!=accountId){
     throw StateError('Goal source cannot be changed after confirmation.');
    }
    return false;
   }
   await store.customStatement(
    'INSERT INTO fresh_finance_goal_account_sources '
    '(movement_id,account_id,linked_iso) VALUES (?,?,?)',
    [movementId,accountId,linkedIso]);
   return true;
  });
 }

 Future<WaffraGoalAccountProgress> goalProgress({
  required String goalId,required String selectedAccountId,
 })async{
  await _ready();_id(goalId);_id(selectedAccountId);
  final rows=await store.customSelect('''
SELECT g.saved_minor,
 COALESCE((SELECT SUM(CASE WHEN m.kind='fund' THEN m.amount_minor
    WHEN m.kind='release' THEN -m.amount_minor ELSE 0 END)
  FROM fresh_finance_goal_account_sources s
  JOIN fresh_finance_goal_wallet_movements m ON m.movement_id=s.movement_id
  WHERE m.goal_id=g.goal_id AND s.account_id=?),0) AS contribution_minor
FROM fresh_finance_goals g WHERE g.goal_id=?
''',variables:[Variable.withString(selectedAccountId),
  Variable.withString(goalId)]).get();
  if(rows.length!=1)throw StateError('Savings goal not found.');
  return WaffraGoalAccountProgress(goalId,
   rows.single.read<int>('saved_minor'),
   rows.single.read<int>('contribution_minor'));
 }

 /// Enumerate the real encrypted recurring templates and their persisted
 /// account defaults. The open Home header never supplies a default.
 Future<List<WaffraRecurringAccountTemplate>> recurringTemplates()async{
  await _ready();
  final rows=await store.customSelect('''
SELECT r.recurring_id,r.source_json,d.account_id
FROM fresh_finance_recurring r
LEFT JOIN fresh_finance_recurring_account_defaults d
 ON d.recurring_id=r.recurring_id
ORDER BY r.recurring_id
''').get();
  return List<WaffraRecurringAccountTemplate>.unmodifiable(rows.map((row){
   final id=row.read<String>('recurring_id');
   var title=id;
   try{
    final data=jsonDecode(row.read<String>('source_json'));
    if(data is Map&&data['title'] is String&&
       (data['title'] as String).trim().isNotEmpty){
     title=(data['title'] as String).trim();
    }
   }catch(_){
    // A malformed label must never guess the money source.
   }
   return WaffraRecurringAccountTemplate(
    id,title,row.readNullable<String>('account_id'));
  }));
 }

 /// A recurring template owns its default, never the currently opened header.
 Future<String?> recurringDefault(String recurringId)async{
  await _ready();_id(recurringId);
  final rows=await store.customSelect(
   'SELECT account_id FROM fresh_finance_recurring_account_defaults '
   'WHERE recurring_id=?',variables:[Variable.withString(recurringId)]).get();
  return rows.isEmpty?null:rows.single.read<String>('account_id');
 }

 Future<void> setRecurringDefault({
  required String recurringId,required String? accountId,
  required String changedIso,required bool userConfirmed,
 })async{
  await _ready();
  if(!userConfirmed)throw StateError('Recurring account update needs consent.');
  _id(recurringId);_when(changedIso);
  await store.transaction(()async{
   final schedule=await store.customSelect(
    'SELECT recurring_id FROM fresh_finance_recurring WHERE recurring_id=?',
    variables:[Variable.withString(recurringId)]).get();
   if(schedule.length!=1)throw StateError('Recurring template not found.');
   if(accountId==null){
    await store.customStatement(
     'DELETE FROM fresh_finance_recurring_account_defaults WHERE recurring_id=?',
     [recurringId]);
   }else{
    _id(accountId);await _active(accountId);
    await store.customStatement('''
INSERT INTO fresh_finance_recurring_account_defaults
 (recurring_id,account_id,changed_iso) VALUES (?,?,?)
ON CONFLICT(recurring_id) DO UPDATE SET
 account_id=excluded.account_id,changed_iso=excluded.changed_iso
''',[recurringId,accountId,changedIso]);
   }
  });
 }

 /// Only last-four masked identifiers, explicitly mapped by the user, are
 /// stored. Unknown, shared or ambiguous suffixes remain unassigned.
 Future<void> setVerifiedBankSuffix({
  required String accountId,required String lastFour,
  required String confirmedIso,required bool userConfirmed,
 })async{
  await _ready();
  if(!userConfirmed)throw StateError('Bank identifier needs approval.');
  _id(accountId);_when(confirmedIso);
  if(!RegExp(r'^[0-9]{4}$').hasMatch(lastFour)){
   throw ArgumentError('Only 4 masked ASCII digits may be persisted.');
  }
  await store.transaction(()async{
   await _active(accountId);
   final a=await store.customSelect(
    'SELECT kind FROM fresh_finance_money_accounts WHERE account_id=?',
    variables:[Variable.withString(accountId)]).getSingle();
   if(a.read<String>('kind')!='bank')throw StateError(
    'SMS suffix belongs to a bank account only.');
   await store.customStatement('''
INSERT INTO fresh_finance_account_sms_suffixes
(account_id,last_four,confirmed_iso) VALUES (?,?,?)
ON CONFLICT(account_id) DO UPDATE SET
last_four=excluded.last_four,confirmed_iso=excluded.confirmed_iso
''',[accountId,lastFour,confirmedIso]);
  });
 }

 /// Read only the user-confirmed four-digit suffix from SQLCipher.
 /// Never infer digits from account labels, SMS sender or the Home filter.
 Future<String?> verifiedBankSuffix(String accountId)async{
  await _ready();
  _id(accountId);
  final rows=await store.customSelect('''
SELECT s.last_four
FROM fresh_finance_account_sms_suffixes s
JOIN fresh_finance_money_accounts a ON a.account_id=s.account_id
WHERE s.account_id=? AND a.kind='bank' AND a.currency='SAR'
  AND a.archived=0
''',variables:[Variable.withString(accountId)]).get();
  if(rows.length>1)throw StateError('Duplicate verified bank suffix.');
  if(rows.isEmpty)return null;
  final suffix=rows.single.read<String>('last_four');
  if(!RegExp(r'^[0-9]{4}$').hasMatch(suffix)){
   throw StateError('Stored bank suffix failed integrity validation.');
  }
  return suffix;
 }

 Future<WaffraSmsAccountDecision> inferSmsAccount(
  WaffraBankSmsFacts facts,
 )async{
  await _ready();
  final rows=await store.customSelect('''
SELECT s.account_id,s.last_four
FROM fresh_finance_account_sms_suffixes s
JOIN fresh_finance_money_accounts a ON a.account_id=s.account_id
WHERE a.archived=0 AND a.kind='bank' AND a.currency='SAR'
''').get();
  final suffixes=<String,String>{
   for(final row in rows)row.read<String>('account_id'):
     row.read<String>('last_four'),
  };
  return WaffraAccountContextPolicy.matchBankSms(
   sourceSuffix:facts.sourceSuffix,
   destinationSuffix:facts.destinationSuffix,
   incoming:facts.kind==WaffraBankOperationKind.income,
   classifiedIncomeOrExpense:facts.canAutoPostAsIncomeExpense,
   verifiedSuffixByAccount:suffixes,
  );
 }
 /// M611: read the actual encrypted two-sided transfer ledger, never infer
 /// transfers from income/expense MoneyEntry rows or mutable Home state.
 /// The caller must hold the verified Home/Widget source read lock.
 Future<List<WaffraInternalTransferHistory>> readInternalTransferHistory({
  String? accountId,int limit=500,
 })async{
  await _ready();
  if(limit<1||limit>500)throw ArgumentError('Invalid transfer page size');
  if(accountId!=null)_id(accountId);
  final rows=await store.customSelect(
   'SELECT transfer_id,from_account_id,to_account_id,amount_minor,'
   'occurred_iso,note FROM fresh_finance_internal_transfers '
   +(accountId==null?'':'WHERE from_account_id=? OR to_account_id=? ')
   +'ORDER BY occurred_iso DESC,transfer_id DESC LIMIT ?',
   variables:[
    if(accountId!=null)...[
     Variable.withString(accountId),Variable.withString(accountId),
    ],
    Variable.withInt(limit),
   ],
  ).get();
  return List<WaffraInternalTransferHistory>.unmodifiable(rows.map((r)=>
   WaffraInternalTransferHistory(
    id:r.read<String>('transfer_id'),
    fromAccountId:r.read<String>('from_account_id'),
    toAccountId:r.read<String>('to_account_id'),
    amountMinor:r.read<int>('amount_minor'),
    occurredIso:r.read<String>('occurred_iso'),
    note:r.read<String>('note'),
   )));
 }


 /// M649: account-linked goal movements are a separate savings wallet.
 /// Read only verified source provenance; never synthesize MoneyEntry rows.
 Future<List<WaffraVerifiedGoalMovement>> readGoalAccountMovementHistory({
  String? accountId,int limit=500,
 })async{
  await _ready();
  if(limit<1||limit>500)throw ArgumentError('Invalid savings page size');
  if(accountId!=null)_id(accountId);
  final rows=await store.customSelect(
   'SELECT m.movement_id,m.goal_id,g.name,m.kind,m.amount_minor,'
   'm.occurred_at_iso,s.account_id '
   'FROM fresh_finance_goal_wallet_movements m '
   'JOIN fresh_finance_goal_account_sources s ON s.movement_id=m.movement_id '
   'JOIN fresh_finance_goals g ON g.goal_id=m.goal_id '
   "WHERE m.kind IN ('fund','release') "
   +(accountId==null?'':'AND s.account_id=? ')
   +'ORDER BY m.occurred_at_iso DESC,m.movement_id DESC LIMIT ?',
   variables:[
    if(accountId!=null)Variable.withString(accountId),
    Variable.withInt(limit),
   ],
  ).get();
  return List<WaffraVerifiedGoalMovement>.unmodifiable(rows.map((r)=>
   (
    id:r.read<String>('movement_id'),
    goalId:r.read<String>('goal_id'),
    goalName:r.read<String>('name'),
    accountId:r.read<String>('account_id'),
    kind:r.read<String>('kind'),
    amountMinor:r.read<int>('amount_minor'),
    occurredIso:r.read<String>('occurred_at_iso'),
   )));
 }
}
/// A single actual verified account-linked fund/release event.
typedef WaffraVerifiedGoalMovement = ({
 String id,String goalId,String goalName,String accountId,String kind,
 int amountMinor,String occurredIso,
});

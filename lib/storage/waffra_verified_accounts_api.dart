import 'waffra_accounts_repository.dart';
import 'waffra_account_context_read.dart';
import 'waffra_account_context_repository.dart';
import 'waffra_account_details_schema.dart';
import 'waffra_custom_account_subtype_schema.dart';
import 'waffra_account_context_policy.dart';
import '../waffra_bank_sms_facts.dart';
import 'waffra_unified_finance_writer.dart';
import 'waffra_verified_encrypted_finance_bridge.dart';

/// Production-facing M440 account adapter. The existing finance source
/// verifies SQLCipher activation and app/Widget writer ownership under a
/// shared lock. This class cannot opt in to SQLCipher or create encryption
/// keys itself. A stale screen can never commit a transfer.
class WaffraVerifiedAccountsApi implements WaffraAccountOperations {
 WaffraVerifiedAccountsApi({required this.bridge});
 final WaffraVerifiedEncryptedFinanceBridge bridge;
 WaffraEncryptedHomeWitness? _lastDisplayed;

 @override
 Future<List<WaffraAccountBalance>> balances()async{
  final data=await bridge.readVerifiedAccounts();
  _lastDisplayed=data.witness;
  return data.balances;
 }

 /// M611: owner-scoped verified read; transfers never enter income/expense.
 Future<List<WaffraInternalTransferHistory>> readInternalTransferHistory({
  String? accountId,int limit=500,
 })=>bridge.readVerifiedAccountMetadata((context)=>
  context.readInternalTransferHistory(accountId:accountId,limit:limit));

 /// M649: owner/vault-scoped read-only linked savings wallet provenance.
 Future<List<WaffraVerifiedGoalMovement>> readGoalAccountMovementHistory({
  String? accountId,int limit=500,
 })=>bridge.readVerifiedAccountMetadata((context)=>
  context.readGoalAccountMovementHistory(accountId:accountId,limit:limit));

 /// A witnessed, bounded read for existing entry Edit. Missing SQLCipher
 /// entries must never be misrepresented as safely migrated legacy data.
 Future<({bool exists,String? accountId})> readExistingEntryAccount({
  required String entryId,
 })=>bridge.readVerifiedAccountMetadata((context)=>
  context.readExistingEntryAccount(entryId:entryId));

 Future<T> _commit<T>(
  Future<T> Function(WaffraAccountsRepository accounts) command,
  {required bool userConfirmed})async{
  final before=_lastDisplayed;
  if(before==null){
   throw StateError('Account screen has no witnessed balances. Refresh.');
  }
  // Immediately invalidate the local witness: two rapid buttons cannot
  // submit separate account changes from a single stale screen.
  _lastDisplayed=null;
  return bridge.commitVerifiedAccountChange<T>(
   baseline:before,change:command,userConfirmed:userConfirmed,
  );
 }

 @override
 Future<void> initializeAccounts({required bool userConfirmed})async{
  if(!userConfirmed)throw StateError('Accounts onboarding was not approved.');
  // First initialization uses a verified finance baseline from the already
  // activated encrypted source, not a fake zero-generation account view.
  final before=await bridge.loadForHomeAndWidget();
  await bridge.commitVerifiedAccountChange<void>(
   baseline:before,userConfirmed:true,initializeSchema:true,
   change:(accounts)=>accounts.initializeAccounts(userConfirmed:true),
  );
  _lastDisplayed=null;
 }

 @override
 Future<void> createAccount({required String id,required String name,
  required String kind,required int openingMinor,required String createdIso,
  required bool userConfirmed})=>_commit<void>((repository)=>
   repository.createAccount(id:id,name:name,kind:kind,
    openingMinor:openingMinor,createdIso:createdIso,userConfirmed:true),
   userConfirmed:userConfirmed);

 /// User-approved bank/wallet subtype and provider identity are stored
 /// in the same verified SQLCipher account creation transaction.
 Future<void> createTypedAccountWithIdentity({
  required String id,required String name,required String kind,
  required String providerId,required String subtype,
  required int openingMinor,required String createdIso,
  String? lastFour,String? customSubtypeLabel,
  required bool userConfirmed,
 })=>_commit<void>((accounts)async{
  if(customSubtypeLabel!=null&&
     (!WaffraCustomAccountSubtypeSchema.validLabel(customSubtypeLabel)||
      !((kind=='bank'&&subtype=='other')||
        (kind=='wallet'&&subtype=='digital')))){
   throw ArgumentError('Invalid custom subtype and account classification.');
  }
  if(!WaffraAccountDetailsSchema.valid(
    kind:kind,providerId:providerId,subtype:subtype)){
   throw ArgumentError('Unsupported money-account subtype/provider.');
  }
  if(lastFour!=null&&(kind!='bank'||
     !RegExp(r'^[0-9]{4}$').hasMatch(lastFour))){
   throw ArgumentError('Only masked bank last-four is supported.');
  }
  await WaffraAccountDetailsSchema.install(accounts.db);
  await accounts.createAccount(
   id:id,name:name,kind:kind,openingMinor:openingMinor,
   createdIso:createdIso,userConfirmed:true);
  await WaffraAccountDetailsSchema.assign(accounts.db,
   accountId:id,kind:kind,providerId:providerId,subtype:subtype,
   confirmedIso:createdIso);
  if(customSubtypeLabel!=null){
   await WaffraCustomAccountSubtypeSchema.install(accounts.db);
   await WaffraCustomAccountSubtypeSchema.assign(accounts.db,
    accountId:id,kind:kind,label:customSubtypeLabel,
    confirmedIso:createdIso);
  }
  if(lastFour!=null){
   await WaffraAccountContextRepository(
    store:accounts.db,experimentalEnabled:true).setVerifiedBankSuffix(
     accountId:id,lastFour:lastFour,
     confirmedIso:createdIso,userConfirmed:true);
  }
 },userConfirmed:userConfirmed);

 /// Create a bank account and its explicitly approved four-digit bank
 /// identifier inside ONE verified SQLCipher writer transaction.
 Future<void> createBankAccountWithVerifiedSuffix({
  required String id,required String name,required int openingMinor,
  required String createdIso,required String lastFour,
  required bool userConfirmed,
 })=>_commit<void>((accounts)async{
  if(!RegExp(r'^[0-9]{4}$').hasMatch(lastFour)){
   throw ArgumentError('Bank SMS identifier must be four masked digits.');
  }
  await accounts.createAccount(
   id:id,name:name,kind:'bank',openingMinor:openingMinor,
   createdIso:createdIso,userConfirmed:true);
  await WaffraAccountContextRepository(
   store:accounts.db,experimentalEnabled:true).setVerifiedBankSuffix(
    accountId:id,lastFour:lastFour,
    confirmedIso:createdIso,userConfirmed:true);
 },userConfirmed:userConfirmed);

 @override
 Future<bool> transfer({required String id,required String fromAccountId,
  required String toAccountId,required int amountMinor,
  required String occurredIso,String note='',
  required bool userConfirmed})=>_commit<bool>((repository)=>
   repository.transfer(id:id,fromAccountId:fromAccountId,
    toAccountId:toAccountId,amountMinor:amountMinor,occurredIso:occurredIso,
    note:note,userConfirmed:true),userConfirmed:userConfirmed);

 /// M597: never charge an SMS transfer and its bank fee in two writes.
 /// The witnessed API rejects a stale picker and preserves hash/ledger parity.
 Future<bool> transferReviewedSmsWithFee({
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
 })async{
  final displayed=_lastDisplayed;
  if(displayed==null||!userConfirmed){
   throw StateError('Reload accounts and confirm this SMS transfer.');
  }
  _lastDisplayed=null;
  return bridge.commitReviewedSmsTransferWithFee(
   baseline:displayed,transferId:transferId,
   fromAccountId:fromAccountId,toAccountId:toAccountId,
   principalMinor:principalMinor,feeMinor:feeMinor,
   feeIncludedInDebit:feeIncludedInDebit,
   occurredIso:occurredIso,messageHash:messageHash,
   feeCategory:feeCategory,userConfirmed:true);
 }

 /// One manual income/expense + its account association must share a
 /// single verified Home/Widget SQLCipher transaction. Budget/category
 /// approval remains the caller's responsibility; no SMS/OCR is auto-posted.
 Future<WaffraUnifiedWriteResult> postAccountLinkedManual({
  required Map<String,Object?> record,
  required String accountId,
  required bool userConfirmed,
 })async{
  final displayed=_lastDisplayed;
  if(displayed==null || !userConfirmed){
   throw StateError('Reload and explicitly approve the account transaction.');
  }
  if(record['sourceType']!='manual' ||
     record['receiptPath']!=null ||
     record['notes'] is! String ||
     record['income'] is! bool ||
     accountId.trim().isEmpty) {
   throw StateError('Only confirmed manual transactions may be linked.');
  }
  _lastDisplayed=null;
  return bridge.appendConfirmedTransactions(
   records:[Map<String,Object?>.unmodifiable(record)],
   messageHashes:const <String?>[null],
   userConfirmed:true,
   accountId:accountId,
   expectedAccountGeneration:displayed.generation,
  );
 }

 /// Bank-SMS and recurring confirmations supply one explicit account decision
 /// per posting. A null decision is UNASSIGNED, never the visible header.
 /// No fake cash account is added while identifying a bank message.
 /// The bank-SMS review screen or recurring scheduler must submit its own
 /// confirmed transaction payloads, SMS hashes and explicit account choices.
 /// The same witnessed SQLCipher writer handles deduplication, money posting
 /// and account associations; there is no independent account balance update.
 Future<WaffraUnifiedWriteResult> postAccountLinkedConfirmedBatch({
  required List<Map<String,Object?>> records,
  required List<String?> messageHashes,
  required List<String?> selectedAccountIds,
  required bool userConfirmed,
 })async{
  final displayed=_lastDisplayed;
  if(displayed==null||!userConfirmed||records.isEmpty||
     records.length!=messageHashes.length||
     records.length!=selectedAccountIds.length||
     selectedAccountIds.any((id)=>id!=null&&id.trim().isEmpty)){
   throw StateError('Reload balances and confirm every account assignment.');
  }
  _lastDisplayed=null;
  return bridge.appendConfirmedTransactions(
   records:records,messageHashes:messageHashes,userConfirmed:true,
   selectedAccountIds:selectedAccountIds,
   expectedAccountGeneration:displayed.generation,
  );
 }


 /// Return the complete ledger (including unassigned entries) and the
 /// independent monthly budget totals for the selected account context.
 Future<WaffraAccountContextReadResult> readAccountContext({
  required String monthIso,String? selectedAccountId,bool summaryOnly=false,
 })=>bridge.readVerifiedAccountContext(
  monthIso:monthIso,selectedAccountId:selectedAccountId,
  summaryOnly:summaryOnly);

 /// M681: user-owned read-only preview and all-time legacy link queue.
 Future<({int count,int netMinor})> readUnassignedSummary()=>
  bridge.readVerifiedAccountMetadata((context)=>
   WaffraAccountContextRead.unassignedSummary(store:context.store));

 Future<List<WaffraAccountLedgerRow>> readUnassignedPage({
  int limit=50,int offset=0,
 })=>bridge.readVerifiedAccountMetadata((context)=>
  WaffraAccountContextRead.loadUnassignedEntries(
   store:context.store,limit:limit,offset:offset));

 /// M684: actual bounded SQL read. No historical ledger mutation.
 Future<List<WaffraAccountLedgerRow>> readMonthlyPage({
  required String monthIso,String? selectedAccountId,
  int limit=50,int offset=0,
 })=>bridge.readVerifiedAccountMetadata((context)=>
  WaffraAccountContextRead.loadMonthEntries(
   store:context.store,monthIso:monthIso,
   selectedAccountId:selectedAccountId,limit:limit,offset:offset));

 /// Attach a past unassigned entry only AFTER the account screen has a
 /// witnessed generation and the user explicitly confirms. This does not
 /// create a second income/expense or rewrite the original transaction.
 Future<void> linkUnassignedEntry({
  required String entryId,required String accountId,
  required bool userConfirmed,
  bool openingExcludesHistory=false,
 })=>_commit<void>((repository)async{
   await WaffraAccountContextRead.attachPreviouslyUnassigned(
    store:repository.db,entryId:entryId,accountId:accountId,
    confirmedIso:DateTime.now().toIso8601String(),
    userConfirmed:true,
    openingExcludesHistory:openingExcludesHistory,
   );
  },userConfirmed:userConfirmed);


 /// A goal's overall progress stays independent of the selected account.
 Future<WaffraGoalAccountProgress> goalAccountProgress({
  required String goalId,required String selectedAccountId,
 })=>bridge.readVerifiedAccountMetadata((context)=>context.goalProgress(
  goalId:goalId,selectedAccountId:selectedAccountId));

 /// The source is an existing goal funding/release movement, never a second
 /// savings deposit or expense. Requires witnessed confirmation.
 Future<bool> attributeGoalMovement({
  required String movementId,required String accountId,
  required bool userConfirmed,
 })=>_commit<bool>((accounts)=>WaffraAccountContextRepository(
   store:accounts.db,experimentalEnabled:true).attributeGoalMovement(
    movementId:movementId,accountId:accountId,
    linkedIso:DateTime.now().toIso8601String(),
    userConfirmed:true),userConfirmed:userConfirmed);

 /// Read available recurring templates with their own default account.
 /// Reminder enable/disable is independent of these financial references.
 Future<List<WaffraRecurringAccountTemplate>> recurringAccountTemplates()=>
  bridge.readVerifiedAccountMetadata((context)=>context.recurringTemplates());

 Future<String?> recurringDefaultAccount(String recurringId)=>
  bridge.readVerifiedAccountMetadata((context)=>
   context.recurringDefault(recurringId));

 /// Changing an alert/reminder does not trigger this accounting operation.
 Future<void> setRecurringDefaultAccount({
  required String recurringId,required String? accountId,
  required bool userConfirmed,
 })=>_commit<void>((accounts)=>WaffraAccountContextRepository(
   store:accounts.db,experimentalEnabled:true).setRecurringDefault(
    recurringId:recurringId,accountId:accountId,
    changedIso:DateTime.now().toIso8601String(),
    userConfirmed:true),userConfirmed:userConfirmed);

 /// Read the exact user-confirmed account identifier from the encrypted
 /// authority; never derive it from account name or the selected Home filter.
 Future<String?> verifiedBankSuffix(String accountId)=>
  bridge.readVerifiedAccountMetadata(
   (context)=>context.verifiedBankSuffix(accountId));

 Future<void> registerVerifiedBankSuffix({
  required String accountId,required String lastFour,
  required bool userConfirmed,
 })=>_commit<void>((accounts)=>WaffraAccountContextRepository(
  store:accounts.db,experimentalEnabled:true).setVerifiedBankSuffix(
   accountId:accountId,lastFour:lastFour,
   confirmedIso:DateTime.now().toIso8601String(),
   userConfirmed:true),userConfirmed:userConfirmed);

 /// Null account means unassigned and MUST NOT be replaced by header cash.
 Future<WaffraSmsAccountDecision> suggestSmsAccount(
  WaffraBankSmsFacts facts,
 )=>bridge.readVerifiedAccountMetadata(
  (context)=>context.inferSmsAccount(facts));

 @override
 Future<void> renameAccount({required String id,required String name,
  required bool userConfirmed})=>_commit<void>((repository)=>
   repository.renameAccount(id:id,name:name,userConfirmed:true),
   userConfirmed:userConfirmed);

 /// Update the account label and corrected bank suffix atomically through
 /// one existing verified SQLCipher writer/ledger generation. Inner SQL
 /// transactions are nested in the outer witnessed finance transaction.
 Future<void> renameAccountWithSuffix({
  required String id,required String name,required String lastFour,
  required bool userConfirmed,
 })=>_commit<void>((repository)async{
  if(!RegExp(r'^[0-9]{4}$').hasMatch(lastFour)){
   throw ArgumentError('Bank suffix must contain exactly four ASCII digits.');
  }
  await repository.renameAccount(id:id,name:name,userConfirmed:true);
  await WaffraAccountContextRepository(
   store:repository.db,experimentalEnabled:true).setVerifiedBankSuffix(
    accountId:id,lastFour:lastFour,
    confirmedIso:DateTime.now().toIso8601String(),userConfirmed:true);
 },userConfirmed:userConfirmed);

 @override
 Future<void> archiveEmptyAccount({required String id,
  required bool userConfirmed})=>_commit<void>((repository)=>
   repository.archiveEmptyAccount(id:id,userConfirmed:true),
   userConfirmed:userConfirmed);
}

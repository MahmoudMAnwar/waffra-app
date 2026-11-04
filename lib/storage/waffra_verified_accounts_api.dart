import 'waffra_accounts_repository.dart';
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

 @override
 Future<bool> transfer({required String id,required String fromAccountId,
  required String toAccountId,required int amountMinor,
  required String occurredIso,String note='',
  required bool userConfirmed})=>_commit<bool>((repository)=>
   repository.transfer(id:id,fromAccountId:fromAccountId,
    toAccountId:toAccountId,amountMinor:amountMinor,occurredIso:occurredIso,
    note:note,userConfirmed:true),userConfirmed:userConfirmed);

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
     selectedAccountIds.any((id)=>id==null||id.trim().isEmpty)){
   throw StateError('Reload balances and confirm every account assignment.');
  }
  _lastDisplayed=null;
  return bridge.appendConfirmedTransactions(
   records:records,messageHashes:messageHashes,userConfirmed:true,
   selectedAccountIds:selectedAccountIds,
   expectedAccountGeneration:displayed.generation,
  );
 }

 @override
 Future<void> renameAccount({required String id,required String name,
  required bool userConfirmed})=>_commit<void>((repository)=>
   repository.renameAccount(id:id,name:name,userConfirmed:true),
   userConfirmed:userConfirmed);

 @override
 Future<void> archiveEmptyAccount({required String id,
  required bool userConfirmed})=>_commit<void>((repository)=>
   repository.archiveEmptyAccount(id:id,userConfirmed:true),
   userConfirmed:userConfirmed);
}

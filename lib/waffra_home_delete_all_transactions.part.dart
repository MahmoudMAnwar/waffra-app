part of 'main.dart';

/// M907: exact original owner-confirmed SQLCipher delete-all implementation.
extension _WaffraHomeDeleteAllTransactions on _HomeScreenState {
 Future<void> confirmDeleteAllEntries() async {
  if(entries.isEmpty){snack(context,waffraIsEnglish?'No transactions to delete':'لا توجد معاملات لحذفها');return;}
  final confirmed=await confirmDeletion(
   waffraIsEnglish?'Delete all transactions?':'حذف كل المعاملات؟',
   waffraIsEnglish?'Move all ${entries.length} recorded transactions and their attachments to encrypted Trash for 30 days? You can restore them individually.':'ستنقل ${entries.length} معاملة بكل مرفقاتها إلى المحذوفات المشفرة لمدة 30 يومًا، ويمكن استعادتها بشكل فردي.');
  if(confirmed!=true||!mounted)return;
  // Financial entries move to a reversible encrypted archive; preserve SMS
  // hashes so historical rescans never charge the owner a second time.
  final baseline=_lastFinanceAuthorityRead;
  final hashes=baseline?.encryptedWitness?.snapshot.values['waffra_sms_hashes_v1'];
  final clear=<String,Object>{
   'entries':'[]',
   'waffra_sms_hashes_v1':hashes is List<String>?
    List<String>.of(hashes):List<String>.of(smsHashes),
  };
  try{
   await _financialWriteQueue.submit(clear,(captured)async{
    if(baseline==null)throw StateError('Finance source baseline unavailable.');
    final committed=await _financeAuthority.saveCaptured(
     route:WaffraFinanceRoute.deleteAllTransactions,
     baseline:baseline,captured:captured,userConfirmed:true,
    );
    _lastFinanceAuthorityRead=committed;
    _lastLedgerSavedRaw=committed.ledgerRaw;
    _lastWidgetRevision=committed.widgetRevision;
   });
   if(!mounted)return;
   setState((){_m684InvalidatePeriodRead();entries.clear();});
   unawaited(_refreshWidget());
   // M1008: delete-all updates the durable account source as well as the
   // Home ledger. Refresh its read-only balances and selected-entry IDs.
   // Post-commit refresh errors must not claim the deletion rolled back.
   try{await _m467RefreshHomeAccounts();}catch(error){
    debugPrint('M1008 delete-all account view: ${error.runtimeType}');
   }
   if(!mounted)return;
   if(!_m468VerifiedAccountsLoaded){
    snack(context,waffraIsEnglish?
     'Transactions were deleted, but account balances need verification. Refresh accounts.':
     'تم حذف العمليات، لكن أرصدة الحسابات تحتاج تحقق. حدّث الحسابات.',isError:true);
    return;
   }
   snackSuccess(context,waffraIsEnglish?
    'Transactions moved to encrypted Trash for 30 days.':
    'تم نقل جميع المعاملات إلى المحذوفات المشفرة لمدة 30 يومًا.');
  }catch(e){
   debugPrint('Confirmed transaction deletion could not be verified: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be confirmed. Reload before retrying.':
    'تعذر تأكيد الحذف. أعد تحميل المعاملات قبل المحاولة مجددًا.');
  }
 }
}

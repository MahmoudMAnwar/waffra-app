part of 'main.dart';

/// M907: exact original owner-confirmed SQLCipher delete-all implementation.
extension _WaffraHomeDeleteAllTransactions on _HomeScreenState {
 Future<void> confirmDeleteAllEntries() async {
  if(entries.isEmpty){snack(context,waffraIsEnglish?'No transactions to delete':'لا توجد معاملات لحذفها');return;}
  final confirmed=await confirmDeletion(
   waffraIsEnglish?'Delete all transactions?':'حذف كل المعاملات؟',
   waffraIsEnglish?'Delete all ${entries.length} recorded transactions permanently? This cannot be undone.':'سيُحذف ${entries.length} معاملة نهائيًا. لا يمكن التراجع.');
  if(confirmed!=true||!mounted)return;
  // Crash journal BOTH the ledger and duplicate hashes as one recoverable
  // intent. Do not clear in-memory finance until durable storage confirms it.
  final clear=<String,Object>{
   'entries':'[]',
   'waffra_sms_hashes_v1':<String>[],
  };
  try{
   final baseline=_lastFinanceAuthorityRead;
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
   setState((){_m684InvalidatePeriodRead();entries.clear();smsHashes.clear();});
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
   snackSuccess(context,waffraIsEnglish?'All transactions deleted':'تم حذف جميع المعاملات');
  }catch(e){
   debugPrint('Confirmed transaction deletion could not be verified: $e');
   if(mounted)snack(context,waffraIsEnglish?
    'Deletion could not be confirmed. Reload before retrying.':
    'تعذر تأكيد الحذف. أعد تحميل المعاملات قبل المحاولة مجددًا.');
  }
 }
}

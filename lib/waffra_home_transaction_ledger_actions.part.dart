part of 'main.dart';

/// M780 / Issue #633: original verified transaction-ledger delete/undo routes.
/// Original cash writer and source-verified deletion remain byte-identical.
extension _WaffraHomeVerifiedLedgerActions on _HomeScreenState {
 void _publishVerifiedTransactionLedger(WaffraFinanceAuthorityRead committed){
  if(committed.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
   throw StateError('Encrypted transaction UI received a legacy source.');
  }
  committed.finance.requireIntegrity();
  final loaded=WaffraVerifiedTransactionUiGuard.decodeLedger(committed.ledgerRaw)
   .map((json)=>MoneyEntry.fromJson(json)).toList(growable:false);
  final hashes=committed.finance.getStringList('waffra_sms_hashes_v1')??const <String>[];
  if(!mounted)return;
  setState((){
   _m684InvalidatePeriodRead();
   entries..clear()..addAll(loaded);
   smsHashes..clear()..addAll(hashes);
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  });
  unawaited(_refreshWidget());
 }

 Future<void> _deleteVerifiedEntry(MoneyEntry entry)async {
  try {
   await _financialWriteQueue.drain();
   final baseline=await _financeAuthority.load(
    route:WaffraFinanceRoute.transactionDeleteAndUndo);
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
      baseline.encryptedWitness==null){
    throw StateError('Verified encrypted transaction source is missing.');
   }
   // Reject a stale tile, including an edited receipt reference or amount.
   WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
    ledgerRaw:baseline.ledgerRaw,selected:entry.toJson());
   // A changed receipt image does not increment the finance generation.
   // The screen must capture every actual BLOB digest BEFORE asking consent.
   final screen=await _financeAuthority.loadVerifiedReceiptScreen(
    route:WaffraFinanceRoute.receiptView,entryId:entry.id);
   if(screen.entryId!=entry.id||
      screen.generation!=baseline.encryptedWitness!.generation||
      screen.isInRecycleBin){
    throw StateError('Receipt and finance screen witnesses disagree.');
   }
   if(!mounted)return;
   final approved=await confirmDeletion(
    waffraIsEnglish?'Move transaction to recently deleted':
     'نقل المعاملة إلى المحذوفات',
    waffraIsEnglish?
     'Move «${entry.title}» and its attached invoices to encrypted Recently Deleted for 30 days?':
     'هل تريد نقل المعاملة «${entry.title}» وفواتيرها إلى المحذوفات لمدة 30 يومًا؟');
   if(approved!=true||!mounted)return;
   await _financialWriteQueue.submit(<String,Object>{'id':entry.id},(_)async{
    // M675: a concurrent SMS/Widget writer may have changed the source
    // generation while the user was reading the confirmation dialog.
    // Re-open and verify all witnesses under the serialized write queue.
    final current=await _financeAuthority.load(
     route:WaffraFinanceRoute.transactionDeleteAndUndo);
    if(current.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
       current.encryptedWitness==null){
     throw StateError('Current encrypted deletion source unavailable.');
    }
    WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
     ledgerRaw:current.ledgerRaw,selected:entry.toJson());
    final receipt=await _financeAuthority.loadVerifiedReceiptScreen(
     route:WaffraFinanceRoute.receiptView,entryId:entry.id);
    if(receipt.entryId!=entry.id||
       receipt.generation!=current.encryptedWitness!.generation||
       receipt.isInRecycleBin){
     throw StateError('Encrypted receipt changed during deletion.');
    }
    final committed=await _financeAuthority.deleteVerifiedTransactionToRecycle(
     baseline:current,entryId:entry.id,
     expectedImageHashes:receipt.imageSha256,
     userConfirmed:true,now:DateTime.now().toUtc());
    _publishVerifiedTransactionLedger(committed);
   });
   if(!mounted)return;
   snack(context,waffraIsEnglish?
    'Transaction saved in encrypted Recently Deleted for 30 days.':
    'تم نقل المعاملة إلى المحذوفات لمدة 30 يومًا.',
    isError:false,duration:const Duration(seconds:6),
    actionLabel:waffraIsEnglish?'Undo':'تراجع',
    onAction:(){if(mounted)unawaited(_undoVerifiedDeletedEntry(entry.id));});
  }catch(error){
   debugPrint('Verified encrypted transaction delete refused: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Deletion could not be verified. Your saved financial data was not reset. Reload before retrying.':
     'تعذر التحقق من الحذف. لم يتم تصفير بياناتك المالية. أعد تحميل المعاملات قبل المحاولة.');
    // No full startup reset or transient black screen on failed deletion.
    unawaited(_refreshFromVerifiedFinance());
   }
  }
 }

 Future<void> _undoVerifiedDeletedEntry(String entryId)async {
  try {
   await _financialWriteQueue.submit(<String,Object>{'id':entryId},(_)async{
    // Reopen the CURRENT source instead of restoring over a stale Home or
    // Widget snapshot. The SQL recycle enforces its 30-day clock and IDs.
    final baseline=await _financeAuthority.load(
     route:WaffraFinanceRoute.transactionDeleteAndUndo);
    if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
     throw StateError('Encrypted undo source is not available.');
    }
    final committed=await _financeAuthority.restoreVerifiedDeletedTransaction(
     baseline:baseline,entryId:entryId,now:DateTime.now().toUtc());
    _publishVerifiedTransactionLedger(committed);
   });
   if(mounted)snackSuccess(context,waffraIsEnglish?
    'Transaction and invoices restored':'تم استرجاع المعاملة وفواتيرها');
  }catch(error){
   debugPrint('Encrypted transaction undo blocked safely: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Could not restore safely. Reload Recently Deleted and try again.':
     'تعذر الاسترجاع الآمن. أعد فتح المحذوفات وحاول مجددًا.');
    unawaited(_refreshFromVerifiedFinance());
   }
  }
 }

 Future<void> _showVerifiedDeletedTransactions()async {
  if(_lastFinanceAuthorityRead?.source!=
     WaffraRuntimeFinanceBackend.verifiedEncrypted)return;
  try {
   final deleted=await _financeAuthority.listVerifiedDeletedTransactions();
   if(!mounted)return;
   if(deleted.isEmpty){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Recently deleted transactions':
      'المعاملات المحذوفة'),
     content:WaffraText(waffraIsEnglish?
      'There are no encrypted transactions to restore.':
      'لا توجد معاملات لاسترجاعها.'),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
    return;
   }
   final selection=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Recently deleted (30 days)':
      'المعاملات المحذوفة (30 يومًا)'),
     content:SizedBox(width:360,
      height:min(360.0,deleted.length*82.0+16.0),
      child:ListView.builder(itemCount:deleted.length,
       itemBuilder:(ctx,index){
        final item=deleted.entries.elementAt(index);
        final expires=DateTime.fromMillisecondsSinceEpoch(
         item.value,isUtc:true).toLocal();
        return ListTile(
         leading:const Icon(Icons.restore,color:emerald),
         title:WaffraText(item.key,maxLines:1),
         subtitle:WaffraText(waffraIsEnglish?
          'Recover until ${dayText(expires)}':
          'الاسترجاع متاح حتى ${dayText(expires)}',maxLines:2),
         onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,item.key)));
       })),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))]));
   if(selection!=null&&mounted)await _undoVerifiedDeletedEntry(selection);
  }catch(error){
   debugPrint('Encrypted transaction trash cannot be verified: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Recently Deleted is unavailable until encrypted source verification succeeds.':
    'المحذوفات غير متاحة حتى ينجح التحقق من المصدر المشفر.');
  }
 }

 Future<void> deleteEntry(MoneyEntry e)async {
  // Deleting a confirmed goal debit without also reversing its goal-wallet
  // earmark would silently increase spendable cash. No unverified rollback.
  if(e.sourceType=='goal_due'){
   snack(context,waffraIsEnglish?
    'Goal payments need a verified wallet reversal before deletion. '
    'No money was changed.':
    'حذف استحقاق الهدف يحتاج عكس الخصم من محفظة الهدف بأمان؛ '
    'لم يتم تغيير أي مبلغ.');
   return;
  }
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _deleteVerifiedEntry(e);
   return;
  }
  final yes=await confirmDeletion(waffraIsEnglish?'Delete transaction':'حذف العملية',
   waffraIsEnglish?'Delete «'+e.title+'»? You can undo for 6 seconds after deletion.':'هل تريد حذف المعاملة «'+e.title+'»؟ يمكنك التراجع خلال 6 ثوانٍ بعد الحذف.');
  if(yes!=true||!mounted)return;
  // A tentative removal is never success until the source acknowledges it.
  _m684InvalidatePeriodRead();
  setState(()=>entries.removeWhere((x)=>x.id==e.id));
  if(!await _persistModuleOrReload(
   WaffraFinanceRoute.transactionDeleteAndUndo,
   operation:'transaction-delete'))return;
  if(!mounted)return;
  snack(context,waffraIsEnglish?'Transaction deleted':'تم حذف العملية',
   isError:false,duration:const Duration(seconds:5),
   actionLabel:waffraIsEnglish?'Undo':'تراجع',
   onAction:()async{
    if(!mounted||entries.any((x)=>x.id==e.id))return;
    _m684InvalidatePeriodRead();
    setState(()=>entries.insert(0,e));
    if(!await _persistModuleOrReload(
     WaffraFinanceRoute.transactionDeleteAndUndo,
     operation:'transaction-undo'))return;
    if(mounted)snackSuccess(context,waffraIsEnglish?
     'Transaction restored':'تم استرجاع المعاملة');
   });
 }
}

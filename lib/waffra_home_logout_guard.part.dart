part of 'main.dart';

/// M929 / Issue #633: byte-preserved Home method extraction; no financial writer change.
extension _WaffraHomeLogoutGuard on _HomeScreenState {
 Future<void> _m627CloseForLogout()async{
  if(_m627ClosingSession)return;
  _m627ClosingSession=true;
  _m627AccountEpoch++;
  _m630HomeStartupEpoch++;
  // M636: retain the last verified Home frame behind the blocking logout
  // overlay. An error/retry view belongs to real failure, never success.
  // _m627ClosingSession still prevents finance work until safe teardown.
  try{
   // Never close an active database underneath a Home load or pending
   // finance preparation/write. Timeout fails signout closed, not finance.
   final pendingLoad=_m627HomeLoadCompletion;
   if(pendingLoad!=null){
    await pendingLoad.future.timeout(const Duration(seconds:20));
   }
   // Future.timeout does not cancel the SQL query: fail signout rather
   // than close a vault whose old account read is still running.
   await Future.wait<void>(_m627OutstandingAccountReads.toList())
    .timeout(const Duration(seconds:20));
   // M630: a widget reread or due-payment/reminder task may still own
   // this source after the first Home frame. Finish it before vault close.
   final postFrameFinance=_m630PostFrameFinanceWork;
   if(postFrameFinance!=null){
    await postFrameFinance.timeout(const Duration(seconds:20));
   }
   await _m468PersistSequence.timeout(const Duration(seconds:20));
   await _financialWriteQueue.drain().timeout(const Duration(seconds:20));
   final pending=_financeBindingFuture;
   if(pending!=null)await pending;
   final binding=_financeBinding;
   if(binding!=null)await binding.close();
   _financeBinding=null;
   _financeBindingFuture=null;
   // Preserve a non-null guarded authority until this Home unmounts.
   _financeAuthority=WaffraVerifiedFinanceAuthority(legacy:_homeFinancePersistence);
   _m468AccountReadInFlight=null;
   _m468AccountReadAgain=false;
   _m468VerifiedAccountsLoaded=false;
  }catch(_){
   _m627ClosingSession=false;
   rethrow;
  }
 }
 void _m627AbortFailedLogout(){
  _m627ClosingSession=false;
  // M636: if the genuine Home DB close fails, keep the owner signed in
  // but offer verified finance Retry rather than a frozen
  // `Signing out` state with a disposed authority or fake old balances.
  if(mounted)setState((){
   ready=false;
   _financeLoadFailure=waffraIsEnglish?
    'Sign-out was cancelled. Retry safely to verify your financial data.':
    'توقف تسجيل الخروج. أعد المحاولة بأمان للتحقق من بياناتك المالية.';
  });
 }

}

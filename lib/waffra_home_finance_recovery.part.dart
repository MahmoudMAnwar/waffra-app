part of 'main.dart';

/// M791 / Issue #633: original verified Home finance startup and recovery UI.
/// Same-library relocation; all financial loading/guard behavior unchanged.
extension _WaffraHomeFinanceRecovery on _HomeScreenState {
 Future<void> _loadFinanceSafely()async{
  if(!mounted||_m627ClosingSession)return;
  // One Home finance load at a time. Do not concurrently clear the same
  // verified ledger or race a sign-out DB close.
  final activeLoad=_m627HomeLoadCompletion;
  if(activeLoad!=null){
   await activeLoad.future;
   return;
  }
  final completion=Completer<void>();
  _m627HomeLoadCompletion=completion;
  final startupEpoch=++_m630HomeStartupEpoch;
  // Retry invalidates any late completion from a previous account read.
  _m627AccountEpoch++;
  // M614: measure the real verified finance wait separately from login.
  final startupClock=kProfileMode?(Stopwatch()..start()):null;
  setState((){ready=false;_financeLoadFailure=null;});
  _m684InvalidatePeriodRead();
  entries.clear();categories.clear();namedBudgets.clear();goals.clear();recurring.clear();challenges.clear();
  deletedCategories.clear();deletedGoals.clear();deletedRecurring.clear();
  recurringPostponed.clear();smsHashes.clear();learnedMerchantCategories.clear();
  try{
   await load();
   if(_m627ClosingSession)return;
   if(mounted)widget.onVerifiedReady?.call();
   if(kProfileMode&&startupClock!=null){
    debugPrint('WAFFRA_FINANCE_PERF source_to_ready_ms='
     '${startupClock.elapsedMilliseconds}');
   }
   // Account balances were verified before ready=true; no second startup read.
   WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(()async{
    if(!await _m663AwaitVisible(startupEpoch)||
       !_m630SmsSessionCurrent(startupEpoch))return;
    if(kProfileMode&&startupClock!=null){
     debugPrint('WAFFRA_FINANCE_PERF first_home_frame_ms='
      '${startupClock.elapsedMilliseconds}');
    }
    // Finance notice dispatch happens with the other optional UI work,
    // never on the first authenticated Home frame.
    // Home first: encrypted SMS scan starts only after initial layout settles.
    unawaited(()async{
     await Future<void>.delayed(const Duration(milliseconds:900));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     // M624: native SMS resume and encrypted inbox scan are sequential,
     // only after the first fully verified Home frame has painted.
     final activeOwner=(await widget.onVerifiedHomeSmsResume?.call())??true;
     if(!activeOwner||!_m630SmsSessionCurrent(startupEpoch))return;
     // Let Home receive interactions and finish its first tab animation
     // before Android starts historical month paging and native AES I/O.
     await Future<void>.delayed(const Duration(milliseconds:1200));
     if(!_m630SmsSessionCurrent(startupEpoch))return;
     await _refreshAutoSmsInbox(importMonth:!_autoSmsHistoryComplete);
    }());
    }());
   });
  }catch(e){
   debugPrint('Financial startup integrity/recovery gate blocked access: $e');
   if(_m627ClosingSession)return;
   if(mounted)setState((){
    ready=false;
    _financeLoadFailure=waffraIsEnglish?
     'Could not verify your financial data. Nothing was deleted. Retry or restore a trusted backup.':
     'تعذر التحقق من بياناتك. لم يُحذف شيء. حاول مجددًا أو استعد نسخة موثوقة.';
   });
   // A genuine failed-source recovery page is actionable; never leave
   // the previous auth screen stuck forever if vault verification fails.
   if(mounted)widget.onVerifiedReady?.call();
  }finally{
   if(identical(_m627HomeLoadCompletion,completion)){
    _m627HomeLoadCompletion=null;
   }
   if(!completion.isCompleted)completion.complete();
  }
 }
 Widget _financialRecoveryScreen()=>Center(child:Padding(
  padding:const EdgeInsets.all(24),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   const Icon(Icons.shield_outlined,size:50,color:emerald),
   const SizedBox(height:14),
   WaffraText(waffraIsEnglish?'Financial data protected':'بياناتك المالية محمية',
    textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
   const SizedBox(height:9),
   WaffraText(_financeLoadFailure??'',textAlign:TextAlign.center),
   const SizedBox(height:18),
   FilledButton.icon(
    onPressed:WaffraHaptics.tap(()=>unawaited(_loadFinanceSafely())),
    icon:const Icon(Icons.refresh),
    label:WaffraText(waffraIsEnglish?'Retry safely':'إعادة المحاولة بأمان')),
  ])));
 // M621: a notification is a navigation request, NOT permission to write
 // money. Deferred across cold start and biometric/credential verification.
}

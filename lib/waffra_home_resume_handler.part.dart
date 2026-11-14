part of 'main.dart';

/// M930 / Issue #633: original verified session/nav method extraction.
extension _WaffraHomeResumeHandler on _HomeScreenState {
 void _m468OnResume(){
  if(!mounted||!ready||!widget.postAuthVisible||
     WaffraExternalMediaSession.shouldSkipResumeBackgroundWork)return;
  _m621OnFinanceNoticeTap();
  // M486 #419: biometrics/OS resume must render a frame before expensive
  // SQLCipher/widget and SMS I/O start. Collapse repeated lifecycle events.
  if(_m486ResumeQueued)return;
  _m486ResumeQueued=true;
  WidgetsBinding.instance.addPostFrameCallback((_){
   _m486ResumeQueued=false;
   if(!mounted||!ready||!widget.postAuthVisible||
      WaffraExternalMediaSession.shouldSkipResumeBackgroundWork)return;
   // Verified finance/widget read is still required, merely deferred one
   // frame. Never infer cash from an unverified snapshot.
   if(accountOpened&&mounted)setState((){
    _m528SmsEnabledFuture=null;
   });
   unawaited(_syncWidgetTransactions());
   final now=DateTime.now();
   final last=_m468LastResumeSmsScan;
   if(_autoSmsRefreshInFlight!=null||
      (last!=null&&now.difference(last)<const Duration(seconds:20)))return;
   _m468LastResumeSmsScan=now;
   // Real-time receiver already stages new SMS. A lifecycle resume must not
   // launch a four-page historical scan while the UI unlock animation runs.
   // The owner's explicit Rescan action continues any incomplete history.
   unawaited(_refreshAutoSmsInbox());
  });
 }
}

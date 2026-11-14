part of 'main.dart';

/// M850 / Issue #633: original native SMS notice throttle and explicit rescan.
/// Same library; owner/consent and local no-auto-money policy unchanged.
extension _WaffraHomeSmsRescan on _HomeScreenState {
 void _receiveAutoSmsNotice(){
  if(!mounted||!ready||!widget.postAuthVisible||
     _m627ClosingSession)return;
  // One refresh per notification BURST, not one full 2k-message reparse
  // for each new or repeated Android receiver callback.
  _m632SmsNoticeTimer?.cancel();
  _m632SmsNoticeTimer=Timer(const Duration(milliseconds:900),(){
   _m632SmsNoticeTimer=null;
   if(mounted&&ready&&!_m627ClosingSession){
    // A received native notice can queue during first-run biometric setup.
    // Do not start encrypted history work until real Home is interactive.
    if(!widget.postAuthVisible)return;
    unawaited(_refreshAutoSmsInbox());
   }
  });
 }
 Future<void> _rescanAutoSmsInbox({BuildContext? feedbackContext})async{
  if(_autoSmsRescanRunning||!mounted)return;
  final feedback=feedbackContext??context;
  setState(()=>_autoSmsRescanRunning=true);
  try{
   // Do not rewind the durable month cursor after it has completed.
   // Repeated explicit scans read only newly arrived provider rows; a
   // partially completed first history pass continues from its last row.
   final active=_autoSmsRefreshInFlight;
   if(active!=null)await active;
   final before=await WaffraAutoSms.scanProgress();
   // M638: Rescan first removes only encrypted, unconfirmed SMS review
   // candidates no longer present in the Android inbox. This checked
   // native source operation fails closed on missing permission or error.
   // It runs on SMS I/O executor, never the first Home frame/UI thread.
   final removedFromPhone=await WaffraAutoSms.reconcilePendingWithAndroidInboxChecked();
   final continuingInitialHistory=before?['initialComplete']!=true;
   if(!mounted)return;
   await _refreshAutoSmsInbox(importMonth:true);
   if(!mounted)return;
   final after=await WaffraAutoSms.scanProgress();
   final priorScanned=before?['scanned'] is num?
    (before!['scanned'] as num).toInt():0;
   final nowScanned=after?['scanned'] is num?
    (after!['scanned'] as num).toInt():priorScanned;
   // The native cursor never rewinds; counters are cumulative and this
   // button reports only the difference observed during this invocation.
   final scanned=(nowScanned-priorScanned).clamp(0,2147483647);
   if(after!=null)setState((){
    _autoSmsProgress=after;
    _autoSmsLastRescanScanned=scanned;
   });
   final previous=before?['added'] is num?
    (before!['added'] as num).toInt():0;
   final current=after?['added'] is num?
    (after!['added'] as num).toInt():previous;
   final added=(current-previous).clamp(0,2147483647);
   if(_autoSmsStatusProblem!=null){
    snack(feedback,_autoSmsStatusProblem!,isError:true);
   }else if(after?['complete']!=true){
    final continuation=continuingInitialHistory?
     (waffraIsEnglish?'Continuing first history scan.':
      'جارٍ استكمال الفحص الأول للرسائل السابقة.'):
     (waffraIsEnglish?'More newly received messages remain to scan.':
      'لسه فيه رسائل جديدة محتاجة استكمال الفحص.');
    snack(feedback,waffraIsEnglish?
     'Examined $scanned new inbox rows • $added added • '
      '$removedFromPhone deleted from phone removed from review • '
      '${_autoSmsPending.length} awaiting review. $continuation':
     'تم فحص $scanned رسالة من الدفعة الحالية • $added اتضافت للمراجعة • '
      '$removedFromPhone اتحذفت من المراجعة بعد حذفها من الهاتف • '
      '${_autoSmsPending.length} بانتظار المراجعة. $continuation');
   }else{
    if(feedbackContext!=null&&!feedbackContext.mounted)return;
    if(added==0){
     snackSuccess(feedback,waffraIsEnglish?
      'No new messages to review.':'لا توجد رسائل جديدة للمراجعة.');
    }else{
     snackSuccess(feedback,waffraIsEnglish?
      '$added new messages added for review.':
      'تمت إضافة $added رسالة جديدة للمراجعة.');
    }
   }
  }catch(_){
   if(mounted&&(feedbackContext==null||feedbackContext.mounted))snack(feedback,waffraIsEnglish?
    'SMS rescan failed. Pending messages were not deleted.':
    'تعذر إعادة الفحص. لم تُحذف الرسائل المعلقة.',isError:true);
  }finally{
   if(mounted)setState(()=>_autoSmsRescanRunning=false);
  }
 }
}

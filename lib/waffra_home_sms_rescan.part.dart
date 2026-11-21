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
  // Only genuinely new visible candidates count as added to review.
  final previouslyVisibleIds=_autoSmsPending
   .map((row)=>row['id']).whereType<String>().toSet();
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
   // SMS_RESCAN_RECOVERY (M1050): a late Android provider row may have a
   // receipt date older than the already-committed forward history cursor.
   // The explicit pull alone replays a bounded recent window through the
   // owner-encrypted live offer/dedup gate, WITHOUT resetting any cursor.
   final recovery=await WaffraAutoSms.recoverRecentlyMissedSmsChecked();
   if(!mounted)return;
   // Native replay is review-only; re-classify and repaint the live queue.
   await _refreshAutoSmsInbox();
   if(!mounted)return;
   final after=await WaffraAutoSms.scanProgress();
   final priorScanned=before?['scanned'] is num?
    (before!['scanned'] as num).toInt():0;
   final nowScanned=after?['scanned'] is num?
    (after!['scanned'] as num).toInt():priorScanned;
   // The native cursor never rewinds; counters are cumulative and this
   // button reports only the difference observed during this invocation.
   final scanned=((nowScanned-priorScanned).clamp(0,2147483647)+
    (recovery['checked'] as int)).clamp(0,2147483647).toInt();
   if(after!=null)setState((){
    _autoSmsProgress=after;
    _autoSmsLastRescanScanned=scanned;
   });
   final previous=before?['added'] is num?
    (before!['added'] as num).toInt():0;
   final current=after?['added'] is num?
    (after!['added'] as num).toInt():previous;
   final added=((current-previous).clamp(0,2147483647)+
    (recovery['added'] as int)).clamp(0,2147483647).toInt();
   final visibleAdded=_autoSmsPending.where((row)=>
    row['id'] is String&&!previouslyVisibleIds.contains(row['id'])).length;
   // M1053: a zero-result recovery must show WHY Android candidates
   // disappeared. The provider returns aggregate local-only reason counts,
   // not bank message text, account numbers or verification secrets.
   final skipMap=recovery['skipReasons'];
   final skip=skipMap is Map?skipMap:const <String,int>{};
   int skipped(String reason){
    final value=skip[reason];
    return value is int&&value>0?value:0;
   }
   final topReasons=<String>[
    if(skipped('senderBlocked')>0)
     (waffraIsEnglish?'sender blocked':'مرسل محظور')+
      ': ${skipped('senderBlocked')}',
    if(skipped('messageExcluded')>0)
     (waffraIsEnglish?'exact message excluded':'رسالة مستبعدة ببصمتها')+
      ': ${skipped('messageExcluded')}',
    if(skipped('alreadyCommitted')>0)
     (waffraIsEnglish?'already booked':'عملية مسجلة')+
      ': ${skipped('alreadyCommitted')}',
    if(skipped('intakeRejected')>0)
     (waffraIsEnglish?'capture rejected':'تعذر إدراجها')+
      ': ${skipped('intakeRejected')}',
    if(skipped('alreadyPending')>0)
     (waffraIsEnglish?'already awaiting review':'موجودة للمراجعة')+
      ': ${skipped('alreadyPending')}',
    if(skipped('verification')>0)
     (waffraIsEnglish?'OTP protected':'رمز تحقق محمي')+
      ': ${skipped('verification')}',
   ];
   final senderMap=recovery['senderSkipReasons'];
   final senderInfo=senderMap is Map?
    senderMap.entries.where((entry)=>entry.key is String&&entry.value is Map)
     .take(3).map((entry){
      final breakdown=entry.value as Map;
      final denied=(breakdown['messageExcluded'] is int?
       breakdown['messageExcluded'] as int:0);
      final blocked=(breakdown['senderBlocked'] is int?
       breakdown['senderBlocked'] as int:0);
      return (denied+blocked)>0?
       '${entry.key}: ${waffraIsEnglish?'blocked':'محجوبة'} ${denied+blocked}':'';
     }).where((s)=>s.isNotEmpty).join(' • '):'';
   final diagnostic=(topReasons.take(4).join(' • ')+
     (senderInfo.isEmpty?'':' • $senderInfo')).trim();
   final recoveryPartial=recovery['partial']==true;
   final recoveryAtCapacity=recovery['capacityBlocked']==true;
   if(_autoSmsStatusProblem!=null){
    snack(feedback,_autoSmsStatusProblem!,isError:true);
   }else if(after?['complete']!=true||recoveryPartial){
    final continuation=recoveryAtCapacity?
     (waffraIsEnglish?
       'Review queue is full (1000). Review/exclude pending SMS, then pull again.':
       'قائمة المراجعة ممتلئة (1000). راجع أو استبعد الرسائل المعلقة ثم اسحب للتحديث.'):
     recoveryPartial?
      (waffraIsEnglish?
       'Recent SMS recovery was partial; not all provider rows were checked.':
       'فحص الرسائل الفائتة جزئي؛ لم تُفحص كل رسائل الهاتف.'):
     continuingInitialHistory?
      (waffraIsEnglish?'Continuing first history scan.':
       'جارٍ استكمال الفحص الأول للرسائل السابقة.'):
      (waffraIsEnglish?'More newly received messages remain to scan.':
       'لسه فيه رسائل جديدة محتاجة استكمال الفحص.');
    snack(feedback,waffraIsEnglish?
     'Checked $scanned inbox rows • $added candidates accepted • '
      '$removedFromPhone deleted from phone removed from review • '
      '${_autoSmsPending.length} awaiting review. $continuation':
     'تم فحص $scanned صفًا من رسائل الهاتف • $added مرشحة تم التقاطها • '
      '$removedFromPhone اتحذفت من المراجعة بعد حذفها من الهاتف • '
      '${_autoSmsPending.length} بانتظار المراجعة. $continuation');
   }else{
    if(feedbackContext!=null&&!feedbackContext.mounted)return;
    if(visibleAdded==0){
     final note=waffraIsEnglish?
      (added>0?
       '$added SMS accepted, but none remains for review after local rules.':
       'No new messages to review. Checked $scanned Android rows.'):
      (added>0?
       'تم التقاط $added رسالة لكن اختفت بعد تطبيق القواعد المحلية.':
       'لم تظهر رسائل جديدة من $scanned صفًا فُحص في أندرويد.');
     // No false success when relevant financial SMS have been filtered.
     if(diagnostic.isNotEmpty)snack(feedback,'$note $diagnostic',isError:true);
     else snackSuccess(feedback,note);
    }else{
     snackSuccess(feedback,waffraIsEnglish?
      '$visibleAdded new messages added for review.':
      'تمت إضافة $visibleAdded رسالة جديدة للمراجعة.');
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

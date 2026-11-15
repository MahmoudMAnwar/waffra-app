part of 'main.dart';

/// M742 / Issue #633: original incremental native SMS review refresh.
/// Retains offline isolates, owner checks, backpressure and no auto posting.
extension _WaffraHomeSmsRefresh on _HomeScreenState {
 Future<void> _refreshAutoSmsInbox({bool importMonth=false})async{
  final active=_autoSmsRefreshInFlight;
  if(active!=null){
   _autoSmsRefreshAgain=true;
   _autoSmsImportAgain|=importMonth;
   await active;
   return;
  }
  final running=_runAutoSmsRefresh(importMonth:importMonth);
  _autoSmsRefreshInFlight=running;
  try{await running;}finally{
   _autoSmsRefreshInFlight=null;
   if(_autoSmsRefreshAgain){
    final scan=_autoSmsImportAgain;
    _autoSmsRefreshAgain=false;
    _autoSmsImportAgain=false;
    if(mounted)unawaited(_refreshAutoSmsInbox(importMonth:scan));
   }
  }
 }
 Future<void> _runAutoSmsRefresh({bool importMonth=false})async{
  if(!mounted||!ready||_m627ClosingSession||_financeLoadFailure!=null)return;
  final smsEpoch=_m630HomeStartupEpoch;
  final status=await WaffraAutoSms.trackingStatus();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(status==null||status['enabled']!=true){
   final message=status==null?
    (waffraIsEnglish?'Could not verify bank SMS state. Retry.':
     'تعذر التحقق من حالة الرسائل البنكية. حاول التحديث.'):
    status['permissionGranted']!=true?
     (waffraIsEnglish?'Android SMS permission is not granted.':
      'صلاحية رسائل أندرويد غير مفعّلة بالكامل.'):
    status['profileReady']!=true?
     (waffraIsEnglish?'Sign in to access your bank SMS.':
      'سجّل دخولك لمراجعة رسائل حسابك البنكية.'):
    (waffraIsEnglish?
     'Android permission is granted, but Waffra tracking is paused. Enable it in Security & privacy.':
     'صلاحية أندرويد مفعّلة، لكن متابعة الرسائل موقوفة داخل وفرة. فعّلها من الأمان والخصوصية.');
   setState((){
    _autoSmsStatusChecked=true;
    _autoSmsStatusProblem=message;
    _autoSmsHistoryComplete=false;
    _autoSmsPending.clear();
   });
   _m991CachedSmsOwner=null;
   _m991CachedRules=const [];
   _m991SmsReviewRevision.value++;
   return;
  }
  if(importMonth){
   // Bounded native cursor pages; the UI reports real scanned/new counts.
   // Stop if the encrypted review queue is full until the user reviews items.
   try{
    for(var page=0;page<4;page++){
     // Preserve complete month scan but avoid uninterrupted native I/O.
     if(page>0)await Future<void>.delayed(const Duration(milliseconds:500));
     if(!_m630SmsSessionCurrent(smsEpoch))return;
     final imported=await WaffraAutoSms.importConsentMonthChecked();
     final snapshot=await WaffraAutoSms.scanProgress();
     if(_m630SmsSessionCurrent(smsEpoch)&&snapshot!=null)setState(()=>_autoSmsProgress=snapshot);
     final progress=await WaffraAutoSms.trackingStatus();
     if(progress==null||progress['enabled']!=true||
        progress['historyComplete']==true)break;
     if(snapshot?['pending'] is num&&snapshot?['capacity'] is num&&
        (snapshot!['pending'] as num)>=(snapshot['capacity'] as num))break;
     if(imported==0&&snapshot==null)break;
    }
   }catch(_){
    if(_m630SmsSessionCurrent(smsEpoch))setState((){
     _autoSmsStatusChecked=true;
     _autoSmsStatusProblem=waffraIsEnglish?
      'Could not finish reading the SMS history. Retry.':
      'تعذر استكمال فحص الرسائل السابقة. أعد المحاولة.';
    });
    return;
   }
  }
  final results=await WaffraAutoSms.pendingChecked();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(results==null){
   setState((){
    _autoSmsStatusChecked=true;
    // Clear only stale in-memory candidates. Native encrypted data remains
    // untouched and the user sees an explicit recoverable read error.
    _autoSmsPending.clear();
    _autoSmsStatusProblem=waffraIsEnglish?
     'Could not read encrypted SMS queue. Nothing was deleted. Retry.':
     'تعذر قراءة الرسائل المشفرة. لم يُحذف شيء. حاول التحديث.';
   });
   _m991CachedSmsOwner=null;
   _m991CachedRules=const [];
   _m991SmsReviewRevision.value++;
   return;
  }
  // Update counts on *every* completed refresh, not just initial import.
  final latestScan=await WaffraAutoSms.scanProgress();
  if(_m630SmsSessionCurrent(smsEpoch)&&latestScan!=null){
   setState((){
    _autoSmsProgress=latestScan;
    _autoSmsLastChecked=DateTime.now();
   });
  }
  // On a vault error keep SMS review available with built-in rules.
  var customRules=<WaffraSmsLocalRule>[];
  if(_smsRuleOwnerKey.isNotEmpty){
   try{
    customRules=await const WaffraSmsLocalRuleStore().read(
     _smsRuleOwnerKey);
    _m661RuleLoadErrorNotified=false;
   }catch(_){
    // M661: built-ins are safe fallback, but never silently claim the
    // owner's saved custom rules ran when encrypted storage is unreadable.
    if(_m630SmsSessionCurrent(smsEpoch)&&!_m661RuleLoadErrorNotified){
     _m661RuleLoadErrorNotified=true;
     snack(context,waffraIsEnglish?
      'Saved SMS rules could not be loaded. Custom exclusions are not active. Try refreshing.':
      'تعذر تحميل قواعد الرسائل المحفوظة. قواعد الاستبعاد المضافة غير نشطة حاليًا. حاول التحديث.',
      isError:true);
    }
   }
  }
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  // Heavy SHA256, bank parser, OTP detection and local-rule matching now
  // run on a background isolate; the main isolate handles only native ACKs
  // and one UI update. No network or database is used inside the worker.
  final classifyClock=kProfileMode?(Stopwatch()..start()):null;
  final categoryNames=<String>[
   for(final c in categories)
    if(c.isSubcategory&&waffraCategoryAvailableForNewEntry(categories,c))
     '${c.income?'1':'0'}:${c.name}',
  ];
  final signature=categoryNames.join('\u001F');
  // In-memory hints are only valid for the same verified owner and category
  // catalogue. The worker still examines every CURRENT native pending item.
  final canReuse=_smsRuleOwnerKey.isNotEmpty&&
   !_m661RuleLoadErrorNotified&&
   _m991CachedSmsOwner==_smsRuleOwnerKey&&
   _m991CachedCategorySignature==signature;
  // Encrypted owner-only relation digests. Invalid/missing history never
  // authorizes an ACK or financial post and cannot disable current review.
  final historyOwner=_smsRuleOwnerKey;
  var historyReadable=false;
  List<Map<String,Object?>> previousHistory=const [];
  if(historyOwner.isNotEmpty){
   try{
    previousHistory=await const WaffraSmsLifecycleHistoryStore()
     .read(historyOwner);
    historyReadable=true;
   }catch(_){
    historyReadable=false; // Keep owner review open, never invent history.
   }
  }
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  final classified=await compute(waffraM632ClassifySmsQueue,<String,Object?>{
   'results':results,
   'rules':customRules.map((r)=>r.toJson()).toList(growable:false),
   'categories':categoryNames,
   'hashes':smsHashes.toList(growable:false),
   'history':historyReadable?previousHistory:const <Map<String,Object?>>[],
   'previousRules':canReuse?_m991CachedRules:const <Map<String,Object?>>[],
   'cached':canReuse?<Map<String,Object?>>[
    for(final row in _autoSmsPending)
     if(row['id'] is String&&row['m991SourceHash'] is String)
      <String,Object?>{
       'id':row['id'],'sender':row['sender'],
       'm991SourceHash':row['m991SourceHash'],
       'm991Evaluated':row['m991Evaluated'],
       if(row['local'] is Map)'local':row['local'],
      },
   ]:const <Map<String,Object?>>[],
  });
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(kProfileMode&&classifyClock!=null){
   debugPrint('WAFFRA_SMS_PERF classify_count=${results.length} '
    'cache_hits=${classified['cacheHits']} '
    'isolate_ms=${classifyClock.elapsedMilliseconds}');
  }
  final waiting=(classified['waiting'] as List).cast<Map<String,Object?>>();
  final toAcknowledge=(classified['excluded'] as List).cast<String>();
  final toAcknowledgeCommitted=(classified['committed'] as List).cast<String>();
  final toRestoreOnAckFailure=
   (classified['retainOnAckFailure'] as List).cast<Map<String,Object?>>();
  // One encrypted native queue commit instead of one platform call per SMS.
  // If the durable acknowledgement fails, retain every pending item in UI.
  if(toAcknowledge.isNotEmpty){
   // Native encrypted ACK is capped at 100 IDs per atomic operation.
   // Drain larger review queues in batches without losing failed items.
   final failedAcks=<String>{};
   for(var from=0;from<toAcknowledge.length;from+=100){
    if(!_m630SmsSessionCurrent(smsEpoch))return;
    final batch=toAcknowledge.skip(from).take(100).toList(growable:false);
    final removed=await WaffraAutoSms.excludeMessages(batch);
    if(!removed)failedAcks.addAll(batch);
   }
   waiting.addAll(toRestoreOnAckFailure.where(
    (row)=>failedAcks.contains(row['id'])));
  }
  // Process verified hashes separately from ordinary user exclusions:
  // only real finance commits may create permanent native anti-replay markers.
  if(toAcknowledgeCommitted.isNotEmpty){
   final failed=<String>{};
   for(var from=0;from<toAcknowledgeCommitted.length;from+=100){
    if(!_m630SmsSessionCurrent(smsEpoch))return;
    final batch=toAcknowledgeCommitted.skip(from).take(100).toList(growable:false);
    if(!await WaffraAutoSms.acknowledgeCommitted(batch))failed.addAll(batch);
   }
   waiting.addAll(toRestoreOnAckFailure.where(
    (row)=>failed.contains(row['id'])));
  }
  final progress=await WaffraAutoSms.trackingStatus();
  if(!_m630SmsSessionCurrent(smsEpoch))return;
  if(progress?['enabled']!=true){
   setState((){
    _autoSmsStatusChecked=true;
    _autoSmsPending.clear();
    _autoSmsStatusProblem=waffraIsEnglish?
     'SMS tracking was paused while reading. Refresh after sign-in.':
     'متابعة الرسائل توقفت أثناء القراءة. حدّث بعد تسجيل الدخول.';
   });
   _m991CachedSmsOwner=null;
   _m991CachedRules=const [];
   _m991SmsReviewRevision.value++;
   return;
  }
  setState((){
   _autoSmsStatusChecked=true;
   _autoSmsStatusProblem=null;
   _autoSmsHistoryComplete=progress?['historyComplete']==true;
   _autoSmsPending..clear()..addAll(waiting);
  });
  _m991CachedSmsOwner=_smsRuleOwnerKey;
  _m991CachedCategorySignature=signature;
  _m991CachedRules=customRules.map((r)=>r.toJson())
   .toList(growable:false);
  // The open sender sheet listens to this revision, so counts and filters
  // reflect rule changes without closing/reopening or history rescan.
  _m991SmsReviewRevision.value++;
  // Do not block the already-painted review UI on storage latency. This
  // only saves opaque hashed suggestions in encrypted owner-scoped storage.
  if(historyReadable&&historyOwner.isNotEmpty&&
     historyOwner==_smsRuleOwnerKey&&_m630SmsSessionCurrent(smsEpoch)){
   final snapshot=classified['latestHistory'];
   if(snapshot is List){
    final hints=snapshot.whereType<Map>()
     .map((value)=>Map<String,Object?>.from(value)).toList(growable:false);
    try{
     await const WaffraSmsLifecycleHistoryStore()
      .write(historyOwner,hints);
    }catch(_){/* Retain live review; no raw SMS or ledger mutation. */}
   }
  }
  // Passive SMS review is local-only; it never sends a message to
  // cloud analysis or posts money from an unconfirmed match.
 }
}

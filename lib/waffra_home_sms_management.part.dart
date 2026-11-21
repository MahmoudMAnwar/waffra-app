part of 'main.dart';

/// M783 / Issue #633: exact original SMS settings, exclusions and notifications.
/// Same Dart library; owner-bound native consent, no auto-post or money edits.
extension _WaffraHomeSmsManagement on _HomeScreenState {
 Future<void> _scanPreviousBankSmsFromSettings()async{
  if(!await WaffraAutoSms.enabled()){
   final status=await WaffraAutoSms.trackingStatus();
   if(mounted)snack(context,status?['permissionGranted']!=true?
    (waffraIsEnglish?'Allow bank SMS in Android permissions first.':
     'اسمح لوفرة بقراءة الرسائل من صلاحيات أندرويد أولًا.'):
    (waffraIsEnglish?
     'Android SMS permission is already allowed. Enable Waffra tracking in Security & privacy.':
     'صلاحية أندرويد مفعّلة بالفعل؛ فعّل متابعة وفرة من الأمان والخصوصية.'));
   return;
  }
  await WaffraAutoSms.importConsentMonth();
  await _refreshAutoSmsInbox(importMonth:true);
  if(!mounted)return;
  // Successful scan opens sender/message review; never auto-posts money.
  if(_autoSmsPending.isEmpty){
   snack(context,_autoSmsStatusProblem!=null?_autoSmsStatusProblem!:
    !_autoSmsHistoryComplete?
     (waffraIsEnglish?'History scan incomplete. Scan again to continue.':
      'فحص الرسائل السابقة لسه ما اكتملش. اضغط فحص مرة تانية للاستكمال.'):
    (waffraIsEnglish?
     'No recent bank SMS found since the first day of the installation month.':
     'لا توجد رسائل بنكية حديثة منذ بداية شهر تثبيت التطبيق.'));
   return;
  }
  await _openAutoSmsInbox();
 }
 /// M1026: never broaden Android SMS inbox history implicitly.
 Future<void> _scanAllBankSmsHistoryFromSettings()async{
  if(!mounted||!await WaffraAutoSms.enabled()){
   if(mounted)snack(context,waffraIsEnglish?
    'Sign in and enable bank SMS tracking first.':
    'سجل دخولك وفعّل متابعة الرسائل البنكية أولًا.',isError:true);
   return;
  }
  final confirmed=await showWaffraDialog<bool>(context:context,
   builder:(dialog)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Scan all SMS history?':'فحص سجل الرسائل بالكامل؟'),
    content:WaffraText(waffraIsEnglish?
     'This will review bank SMS older than the installation month, in limited batches. It does not automatically save or delete financial entries.':
     'سيتم فحص الرسائل البنكية الأقدم من شهر التثبيت على دفعات محدودة. لن تُحفظ أو تُحذف أي حركة مالية تلقائيًا.'),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(dialog,false),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:()=>Navigator.pop(dialog,true),
      child:WaffraText(waffraIsEnglish?'Scan history':'ابدأ الفحص')),
    ]));
  if(confirmed!=true)return;
  final approved=await WaffraAutoSms.enableAllHistoryScan();
  if(!mounted)return;
  if(!approved){
   snack(context,waffraIsEnglish?'Could not approve SMS history scan.':
    'تعذر تفعيل فحص سجل الرسائل.',isError:true);
   return;
  }
  await _refreshAutoSmsInbox(importMonth:true);
  if(!mounted)return;
  if(_autoSmsPending.isNotEmpty)await _openAutoSmsInbox();
  else snack(context,waffraIsEnglish?
   'History scan started. Repeat Scan previous SMS to continue bounded pages.':
   'بدأ فحص السجل. استخدم فحص الرسائل السابقة لاستكمال الدفعات.');
 }

 Future<void> _openUnknownSmsFromSettings()async{
  if(!await WaffraAutoSms.enabled()){
   final status=await WaffraAutoSms.trackingStatus();
   if(mounted)snack(context,status?['permissionGranted']!=true?
    (waffraIsEnglish?'Allow bank SMS in Android permissions first.':
     'اسمح لوفرة بقراءة الرسائل من صلاحيات أندرويد أولًا.'):
    (waffraIsEnglish?
     'Android SMS permission is already allowed. Enable Waffra tracking in Security & privacy.':
     'صلاحية أندرويد مفعّلة بالفعل؛ فعّل متابعة وفرة من الأمان والخصوصية.'));
   return;
  }
  final notices=await WaffraAutoSms.scanUnknownFinancialSms();
  if(!mounted)return;
  await Navigator.push<void>(context,MaterialPageRoute(
   builder:(_)=>WaffraUnknownFinancialSmsPage(
    english:waffraIsEnglish,
    messages:List<Map<String,Object?>>.unmodifiable(notices),
    onCreateManual:()async{if(mounted)await entrySheet();},
   )));
 }
 Future<void> _openExcludedSenders()async{
  // M517: whole-sender exclusion and single/bulk message exclusion are
  // different encrypted policies. An empty sender list is NOT zero exclusions.
  final saved=await WaffraAutoSms.excludedSenders();
  final excluded=await WaffraAutoSms.excludedMessages();
  if(!mounted)return;
  if(saved==null||excluded==null){
   snack(context,waffraIsEnglish?
    'Excluded messages could not be verified. Check SMS access and sign-in.':
    'تعذر قراءة الرسائل المستبعدة بأمان. تأكد من صلاحية الرسائل وتسجيل الدخول.',
    isError:true);
   return;
  }
  final senders=saved.toList()
   ..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));
  final messages=excluded.toList();
  var busy=false;
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(builder:(ctx,refresh)=>SafeArea(
    child:SizedBox(height:min(620.0,MediaQuery.sizeOf(ctx).height*.78),
     child:Column(children:[
      Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:12),
       child:Row(children:[
        const Icon(Icons.block_rounded,color:forest),
        const SizedBox(width:10),
        Expanded(child:WaffraText(waffraIsEnglish?'Excluded SMS':
         'المستبعدون',style:Theme.of(ctx).textTheme.titleLarge)),
       ])),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20,vertical:5),
       child:WaffraText(waffraIsEnglish?
        '${messages.length} excluded messages • ${senders.length} blocked senders. '
        'Restoring an eligible individual message returns it to review now. '
        'Unblocking a sender rescans recent Android SMS. Financial records stay unchanged.':
        '${messages.length} رسالة مستبعدة • ${senders.length} مرسل مستبعد. '
        'إلغاء استبعاد رسالة محفوظ نصها الآمن بيرجعها للمراجعة فورًا. '
        'إلغاء استبعاد مرسل بيفحص رسائله الأخيرة من الهاتف. '
        'رموز التحقق والعمليات المسجلة محمية، والعمليات المالية لا تتغير.',
        style:Theme.of(ctx).textTheme.bodySmall)),
      Expanded(child:messages.isEmpty&&senders.isEmpty?
       Center(child:WaffraText(waffraIsEnglish?
        'No excluded SMS':'لا توجد رسائل أو مرسلون مستبعدون')):
       ListView.builder(
        key:const Key('waffra-excluded-sms-list'),
        itemCount:messages.length+senders.length+2,
        itemBuilder:(itemContext,index){
         if(index==0){
          return Padding(padding:const EdgeInsets.fromLTRB(18,12,18,4),
           child:WaffraText(waffraIsEnglish?
            'Individual messages (${messages.length})':
            'رسائل مستبعدة (${messages.length})',
            style:Theme.of(ctx).textTheme.titleSmall));
         }
         if(index<=messages.length){
          final message=messages[index-1];
          final id=message['id'] as String;
          final sender=message['sender'] as String? ?? '';
          final receivedAt=message['receivedAt'] as int? ?? 0;
          final excludedAt=message['excludedAt'] as int? ?? 0;
          final expiresAt=excludedAt>0?
           DateTime.fromMillisecondsSinceEpoch(excludedAt).add(
            const Duration(days:30)):null;
          final remaining=expiresAt==null?null:
           (expiresAt.difference(DateTime.now()).inHours/24).ceil().clamp(0,30);
          final expiryNote=remaining==null?'':waffraIsEnglish?
           ' • ${remaining}d to restore':' • متبقي ${remaining} يوم للاسترجاع';
          final date=receivedAt>0?
           DateTime.fromMillisecondsSinceEpoch(receivedAt):null;
          final dateLabel=date==null?'':
           '${date.day}/${date.month}/${date.year}';
          final labelPrefix=dateLabel.isEmpty?'':'$dateLabel • ';
          final storedBody=(message['body'] as String? ?? '').trim();
          final preview=storedBody.replaceAll(RegExp(r'\s+'),' ');
          return ListTile(
           key:Key('waffra-excluded-message-${id.substring(0,12)}'),
           leading:const Icon(Icons.mark_email_read_outlined,color:emerald),
           title:WaffraText(sender.isNotEmpty?sender:
            (waffraIsEnglish?'Excluded message':'رسالة مستبعدة')),
           subtitle:WaffraText(
            '$labelPrefix••••${id.substring(id.length-8)}$expiryNote\n'
            '${preview.isNotEmpty?preview:(waffraIsEnglish?
             'Tap to retrieve the original SMS':'اضغط لعرض الرسالة الأصلية')}',
            maxLines:3,style:Theme.of(ctx).textTheme.bodySmall),
           onTap:busy?null:()async{
            // Do not pretend an opaque legacy fingerprint is the SMS text.
            // Android only returns the body after exact fingerprint recovery.
            final details=await WaffraAutoSms.excludedMessageDetails(id);
            if(!ctx.mounted)return;
            final status=details?['status'] as String? ?? 'unavailable';
            final original=(details?['body'] as String? ?? '').trim();
            final explanation=status=='available'&&original.isNotEmpty?
             original:status=='otp_protected'?
             (waffraIsEnglish?
              'Verification code protected; its secret is never displayed.':
              'هذه رسالة رمز تحقق محمية؛ لن يُعرض الرمز السري.') :
             (waffraIsEnglish?
              'The original SMS could not be verified in Android Messages.':
              'تعذر مطابقة النص الأصلي مع الرسالة الموجودة على الهاتف.');
            await showWaffraDialog<void>(context:ctx,builder:(dialog)=>
             AlertDialog(
              title:WaffraText(sender.isNotEmpty?sender:
               (waffraIsEnglish?'Excluded SMS':'رسالة مستبعدة')),
              content:SingleChildScrollView(child:SelectableText(explanation)),
              actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
               child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
           },
           trailing:TextButton(
            onPressed:busy?null:()async{
             refresh(()=>busy=true);
             var restored=false;
             try{
              restored=await WaffraAutoSms.restoreExcludedMessage(id);
              if(restored&&mounted)await _refreshAutoSmsInbox();
             }catch(_){restored=false;}
             final visible=mounted&&_autoSmsPending.any((row)=>row['id']==id);
             // A failed undo must keep the row visible and explain whether
             // the original is a protected OTP or unavailable legacy text.
             final details=restored?null:
              await WaffraAutoSms.excludedMessageDetails(id);
             if(ctx.mounted)refresh((){
              busy=false;
              if(restored)messages.removeWhere((item)=>item['id']==id);
             });
             if(mounted){
              if(visible)snackSuccess(context,waffraIsEnglish?
               'Message restored to review.':
               'تم إرجاع الرسالة إلى قائمة المراجعة.');
              else if(restored)snack(context,waffraIsEnglish?
               'Exclusion removed, but the SMS is not visible in review yet. Rescan notifications and verify SMS access.':
               'تم إلغاء الاستبعاد لكن الرسالة لم تظهر في المراجعة بعد. افحص الإشعارات وتأكد من صلاحية الرسائل.',
               isError:true);
              else snack(context,details?['status']=='otp_protected'?
               (waffraIsEnglish?
                'This is a protected verification SMS, not a completed debit.':
                'هذه رسالة تحقق محمية وليست عملية خصم مكتملة.') :
               details?['status']=='unavailable'?
               (waffraIsEnglish?
                'Could not find the exact original SMS on your phone. No exclusion was changed.':
                'تعذر العثور على النص الأصلي المطابق على الهاتف؛ لم يتغير الاستبعاد.') :
               (waffraIsEnglish?
                'Undo refused: sender blocked, already booked, pending full, or storage unavailable.':
                'تعذر الإلغاء: المرسل مستبعد أو العملية مسجلة أو قائمة المراجعة ممتلئة أو التخزين غير متاح.'),
               isError:true);
             }
            },child:WaffraText(waffraIsEnglish?'Restore':'إلغاء الاستبعاد')),
          );
         }
         if(index==messages.length+1){
          return Padding(padding:const EdgeInsets.fromLTRB(18,12,18,4),
           child:WaffraText(waffraIsEnglish?
            'Blocked senders (${senders.length})':
            'مرسلون مستبعدون (${senders.length})',
            style:Theme.of(ctx).textTheme.titleSmall));
         }
         final sender=senders[index-messages.length-2];
         return ListTile(
          key:Key('waffra-excluded-sender-${index-messages.length-2}'),
          leading:const Icon(Icons.sms_failed_outlined,color:emerald),
          title:WaffraText(sender,maxLines:2),
          trailing:TextButton(
           onPressed:busy?null:()async{
            refresh(()=>busy=true);
            var restored=false;
            try{
             restored=await WaffraAutoSms.restoreExcludedSender(sender);
             if(restored&&mounted){
              // M1051: unblock historical provider rows, not just future SMS.
              // The existing bounded, owner-checked rescan also repaints the
              // open review and reports partial/capacity/provider failures.
              await _rescanAutoSmsInbox(feedbackContext:ctx);
             }
            }catch(_){/* A failed rescan has its own error feedback. */}
            if(ctx.mounted)refresh((){
             busy=false;
             if(restored)senders.remove(sender);
            });
            if(mounted&&!restored)snack(context,waffraIsEnglish?
             'Could not unblock the sender. Retry.':
             'تعذر إلغاء استبعاد المرسل. حاول مرة أخرى.',isError:true);
           },
           child:WaffraText(waffraIsEnglish?'Restore':'إلغاء الاستبعاد')),
         );
        })),
     ]))),
   ));
 }

 /// Real notifications: SMS stay pending until the owner confirms a financial
 /// save or exclusion; no mock notifications are ever presented as real.
 List<WaffraReviewNotice> _m549ReviewNotices(){
  return _autoSmsPending.where((row)=>row['id'] is String)
   .map((row){
    final id=row['id'] as String;
    final sender=(row['sender'] as String?)?.trim()??'';
    final sensitive=row['sensitiveOtp']==true;
    final body=sensitive?'':(row['body'] as String? ?? '');
    final snippet=sensitive?
     (waffraIsEnglish?'Verification message':'رسالة تحقق'):
     body.replaceAll(RegExp(r'\s+'),' ').trim();
    final summary=snippet.length>108?snippet.substring(0,108)+'…':snippet;
    final local=row['local'];
    final localInfo=local is Map?local:null;
    final income=localInfo?['income'];
    final amount=localInfo?['amount'];
    // One message's own verified local suggestion is authoritative for its
    // badge. Never infer Expense from a sibling sender or an OTP notice.
    final localKind=localInfo?['kind'];
    final suggested=WaffraBankSmsFactsParser.reviewSuggestedKind(
     body:body,localKind:localKind is String?localKind:null,
     sensitiveOtp:sensitive);
    final noticeKind=sensitive?'otpReview':
     suggested=='excluded'?'excludeSuggestion':
     suggested??'needsReview';
    return WaffraReviewNotice(
     id:id,sender:sender.isEmpty?(waffraIsEnglish?'Unknown sender':'مرسل غير محدد'):sender,
     preview:summary.isEmpty?(waffraIsEnglish?'Bank message':'رسالة بنكية'):summary,
     kind:noticeKind,
     receivedAtMs:row['receivedAt'] is int?row['receivedAt'] as int:0,
     amount:sensitive?null:(amount is num?amount.toDouble():null));
   }).toList(growable:false);
 }

 /// Only owner-confirmed SMS IDs or fully selected sender groups may be
 /// excluded. Persistent anti-replay markers live in native encrypted SMS
 /// policy; neither the Android inbox nor financial ledger is modified.
 Future<bool> _m592ExcludeNotificationSelection(
  List<String> ids,List<String> senderNames)async{
  if(!mounted||!ready||_financeLoadFailure!=null||
     ids.isEmpty||ids.length>1000)return false;
  final selected=ids.toSet();
  if(selected.length!=ids.length||
     selected.any((id)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)))return false;
  final pending=<String,Map<String,Object?>>{
   for(final row in _autoSmsPending)
    if(row['id'] is String)row['id'] as String:row};
  if(!selected.every(pending.containsKey))return false;
  String canon(String s)=>s.trim().toLowerCase();
  final blockKeys=senderNames.map(canon).toSet();
  if(blockKeys.length!=senderNames.length||
    senderNames.any((s)=>s.trim().isEmpty||s.length>100))return false;
  for(final sender in blockKeys){
   final rows=_autoSmsPending.where((row)=>
    canon((row['sender'] as String?)??'')==sender);
   if(rows.isEmpty||rows.any((row)=>!selected.contains(row['id'])))
    return false;
  }
  final bySender=ids.where((id)=>blockKeys.contains(
   canon((pending[id]!['sender'] as String?)??''))).toSet();
  final individual=ids.where((id)=>!bySender.contains(id)).toList();
  final done=<String>{};
  var failed=false;
  var learnedPatterns=0;
  String? ruleWarning;
  try{
   if(senderNames.isNotEmpty){
    if(await WaffraAutoSms.excludeSenders(senderNames)){
     done.addAll(bySender);
    }else{failed=true;}
   }
   if(!failed){
    for(var start=0;start<individual.length;start+=100){
     final batch=individual.skip(start).take(100).toList();
     if(!await WaffraAutoSms.excludeMessages(batch)){
      failed=true;break;
     }
     done.addAll(batch);
    }
   }
   if(mounted&&done.isNotEmpty){
    setState(()=>_autoSmsPending.removeWhere(
     (row)=>done.contains(row['id'])));
   }
   // These are two different owner-encrypted policies: native message
   // exclusions and reusable safe local rules. Never interpret an absent
   // reusable pattern as an absent/native-failed message exclusion.
   if(done.isNotEmpty&&_smsRuleOwnerKey.isNotEmpty){
    try{
     final candidates=<WaffraSmsLocalRule>[];
     var index=0;
     for(final id in individual){
      if(!done.contains(id))continue;
      final row=pending[id],body=row?['body'],sender=row?['sender'];
      if(body is! String||sender is! String)continue;
      if(++index%16==0){
       await Future<void>.delayed(const Duration(milliseconds:1));
      }
      final rule=WaffraSmsLocalRules.suggestedGlobalRule(
       body:body,sender:sender,kind:'excluded',confidentOnly:true);
      if(rule!=null)candidates.add(rule);
     }
     final saved=await const WaffraSmsLocalRuleStore()
      .learnReviewedCandidates(_smsRuleOwnerKey,candidates);
     learnedPatterns=saved.addedOrUpdated;
     if(saved.changed)_receiveAutoSmsNotice();
    }catch(_){
     ruleWarning=waffraIsEnglish?
      'Messages were excluded, but encrypted rule learning could not be verified.':
      'الرسائل اتستبعدت، لكن تعذر التحقق من حفظ قواعد الاستبعاد المشفرة.';
    }
   }else if(done.isNotEmpty){
    ruleWarning=waffraIsEnglish?
     'Messages were excluded; rules need a signed-in verified owner.':
     'الرسائل اتستبعدت؛ حفظ القواعد يتطلب مستخدمًا موثقًا.';
   }
  }catch(e){
   failed=true;
   debugPrint('M592 native exclusion rejected: ${e.runtimeType}');
  }
  // M1005: refresh current native pending rows after durable excludes.
  // M1002 owner-serialized encrypted rule learning/read-back is retained.
  if(mounted&&done.isNotEmpty){
   await _refreshAutoSmsInbox();
  }
  if(!mounted)return false;
  if(failed||done.length!=selected.length){
   snack(context,waffraIsEnglish?
    'Some selected SMS remain in review.':
    'بعض الرسائل المحددة ما زالت للمراجعة.',isError:true);
   return false;
  }
  if(ruleWarning!=null){
   snack(context,ruleWarning,isError:true);
  }else{
   snackSuccess(context,waffraIsEnglish?
    'Excluded ${done.length} messages; ${learnedPatterns} reusable safe rule changes saved. Individual exclusions remain in Android.':
    'تم استبعاد ${done.length} رسالة وحفظ ${learnedPatterns} تغيير آمن في القواعد. الاستبعاد الفردي محفوظ على أندرويد.');
  }
  return true;
 }
 Future<void> _m549OpenNotifications()async{
  if(!mounted||!ready)return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
   builder:(route)=>WaffraApprovedNotificationsPage(
    english:waffraIsEnglish,readPending:_m549ReviewNotices,
    onReviewAll:_openAutoSmsInbox,
    onBulkExclude:_m592ExcludeNotificationSelection,
    onFeedback:(route,message,isError)=>snack(route,message,isError:isError),
    onReviewOne:(id)=>_reviewAutoSmsCandidates(targetId:id),
    onRescan:()=>_rescanAutoSmsInbox(feedbackContext:route),
    // A user refresh always checks the real incremental native cursor;
    // a false rescanNeeded hint must not make the button inert.
    canRescan:()=>!_autoSmsRescanRunning,
   )));
 }
}

part of 'main.dart';

/// M835 / Issue #633: unchanged local SMS Review status/progress card.
/// No automatic SMS finance write or navigation change.
extension _WaffraHomeSmsReviewIndicator on _HomeScreenState {
 // ignore: unused_element
 Widget _autoSmsReviewCard(){
  final count=_autoSmsPending.length;
  final localCount=_autoSmsPending.where((row)=>row['local'] is Map).length;
  final ambiguous=count-localCount;
  final canRescan=!_autoSmsRescanRunning&&
   (_autoSmsStatusProblem!=null||_autoSmsProgress['rescanNeeded']==true);
  return Container(
   key:const Key('waffra-auto-sms-review-card'),
   decoration:BoxDecoration(color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(16),
    border:Border.all(color:forest.withValues(alpha:.16))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    // Match Quick Actions: tap anywhere on the framed title to expand.
    Semantics(
     button:true,expanded:_autoSmsReviewExpanded,
     label:waffraIsEnglish?'Transactions requiring review':
      'عمليات تحتاج مراجعة',
     child:InkWell(
      key:const Key('waffra-auto-sms-review-expand'),
      borderRadius:BorderRadius.circular(16),
      onTap:WaffraHaptics.tap(
       ()=>setState(()=>_autoSmsReviewExpanded=!_autoSmsReviewExpanded)),
      child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
       Icon(_autoSmsReviewExpanded?
        Icons.keyboard_arrow_up_rounded:Icons.keyboard_arrow_down_rounded,
        color:forest),
       const SizedBox(width:8),
       const Icon(Icons.fact_check_outlined,color:emerald),
       const SizedBox(width:8),
       Expanded(child:WaffraText(waffraIsEnglish?
        'Transactions requiring review':'عمليات تحتاج مراجعة',
        style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
       Container(
        key:const Key('waffra-auto-sms-review-count'),
        padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
        decoration:BoxDecoration(color:const Color(0xFFE4F4EB),
         borderRadius:BorderRadius.circular(24)),
        child:Text(!_autoSmsStatusChecked||_autoSmsStatusProblem!=null?
         '—':count.toString(),
         style:const TextStyle(color:forest,fontWeight:FontWeight.bold))),
      ]))),
    ),
    if(_autoSmsReviewExpanded)Padding(
     key:const Key('waffra-auto-sms-review-expanded-content'),
     padding:const EdgeInsets.fromLTRB(14,0,14,14),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(_autoSmsStatusProblem!=null?_autoSmsStatusProblem!:
       !_autoSmsStatusChecked?
        (waffraIsEnglish?'Checking SMS tracking status...':
         'جارٍ التحقق من حالة الرسائل البنكية...'):
       count==0?
        (!_autoSmsHistoryComplete?
         (waffraIsEnglish?'History scan incomplete. Tap refresh to continue.':
          'فحص الرسائل السابقة غير مكتمل؛ اضغط تحديث للاستكمال.'):
         (waffraIsEnglish?'No bank SMS awaiting review.':
          'ما فيه رسائل بنكية بانتظار المراجعة.')):
        (waffraIsEnglish?
         'Bank SMS since the installation month await approval.':
         'رسائل من بداية شهر تثبيت التطبيق بانتظار مراجعتك وتأكيدك.')),
      if(count>0)...[
       const SizedBox(height:5),
       WaffraText(waffraIsEnglish?
        '$localCount classified locally • ${ambiguous<0?0:ambiguous} need review':
        '$localCount مصنفة محليًا • ${ambiguous<0?0:ambiguous} تحتاج مراجعة',
        style:const TextStyle(color:emerald,fontSize:12,
         fontWeight:FontWeight.w600)),
      ],
      const SizedBox(height:12),
      if(_autoSmsRescanRunning)...[
       Row(children:[
        const SizedBox(width:18,height:18,
         child:CircularProgressIndicator(strokeWidth:2.4)),
        const SizedBox(width:9),
        Expanded(child:WaffraText(waffraIsEnglish?
         'Scanning SMS now…':'جارٍ الآن فحص الرسائل…')),
       ]),
       const SizedBox(height:10),
      ],
      if(_autoSmsLastRescanScanned!=null)...[
       WaffraText(waffraIsEnglish?
        'Last rescan checked: $_autoSmsLastRescanScanned • Awaiting review: ${_autoSmsProgress['pending']}':
        'آخر إعادة فحص: $_autoSmsLastRescanScanned رسالة • بانتظار المراجعة: ${_autoSmsProgress['pending']}',
        style:const TextStyle(fontSize:12,color:emerald)),
       if(_autoSmsLastChecked!=null)
        WaffraText(waffraIsEnglish?
         'Updated: ${dayText(_autoSmsLastChecked!)}':
         'آخر تحديث: ${dayText(_autoSmsLastChecked!)}',
         style:const TextStyle(fontSize:11,color:emerald)),
       if(_autoSmsProgress['complete']==false)
        Padding(padding:const EdgeInsets.only(top:6),child:WaffraText(
         ((_autoSmsProgress['pending'] as num?)?.toInt()??0)>=
           ((_autoSmsProgress['capacity'] as num?)?.toInt()??1000)?
          (waffraIsEnglish?
           'Review pending messages to continue scanning other senders.':
           'قائمة المراجعة ممتلئة. راجع بعض الرسائل عشان نكمل فحص باقي المرسلين.'):
          _autoSmsProgress['initialComplete']!=true?
          (waffraIsEnglish?
           'First history scan is unfinished. Tap Rescan to continue.':
           'الفحص الأول للرسائل السابقة لسه ما اكتملش. اضغط إعادة الفحص للاستكمال.'):
          (waffraIsEnglish?
           'There are more new messages. Tap Rescan to continue.':
           'فيه رسائل جديدة باقي فحصها. اضغط إعادة الفحص للاستكمال.'),
         style:const TextStyle(fontSize:12,color:emerald))),
       const SizedBox(height:8),
      ],
      Row(children:[
       Expanded(child:FilledButton.icon(
        key:const Key('waffra-auto-sms-review-open'),
        onPressed:count==0||_autoSmsStatusProblem!=null?
         null:WaffraHaptics.tap(_openAutoSmsInbox),
        icon:const Icon(Icons.rate_review_outlined,size:18),
        label:WaffraText(waffraIsEnglish?'Review messages':'مراجعة العمليات'))),
       const SizedBox(width:8),
       OutlinedButton.icon(
        key:const Key('waffra-auto-sms-review-refresh'),
        onPressed:canRescan?
         WaffraHaptics.tap(()=>unawaited(_rescanAutoSmsInbox())):null,
        icon:_autoSmsRescanRunning?
         const SizedBox(width:19,height:19,
          child:CircularProgressIndicator(strokeWidth:2)):
         const Icon(Icons.refresh_rounded,size:19),
        label:WaffraText(_autoSmsRescanRunning?
         (waffraIsEnglish?'Scanning…':'جارٍ الفحص'):
         (waffraIsEnglish?'Rescan':'إعادة الفحص'))),
      ]),
     ])),
   ]),
  );
 }
}

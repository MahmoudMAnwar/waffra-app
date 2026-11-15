part of 'main.dart';

/// M739 / Issue #633: original authenticated SMS inbox review dialog.
/// Same Dart library; no SMS confirmation/account/ledger behavior change.
extension _WaffraHomeSmsInbox on _HomeScreenState {
 Future<void> _openAutoSmsInbox()async{
  // The Home snapshot has already passed native owner/consent verification.
  // Re-reading/decrypting/reclassifying all 1000 SMS on every tap blocks
  // navigation for no gain; initial/invalid/empty snapshots still refresh.
  if(!_autoSmsStatusChecked||_autoSmsStatusProblem!=null||
     _autoSmsPending.isEmpty){
   await _refreshAutoSmsInbox();
  }
  if(!mounted||!ready||_autoSmsStatusProblem!=null||
     _autoSmsPending.isEmpty)return;
  // O(N) case-insensitive grouping; preserve each original sender and date.
  final grouped=WaffraSmsReviewGroups.from(_autoSmsPending,
   unknownSender:waffraIsEnglish?'Unknown sender':'مرسل غير محدد');
  final bySender=grouped.bySender;
  final senders=grouped.senders;
  String? selectedSender,openingReviewId;
  DateTime? selectedDay;
  var calendarIndex=WaffraSmsReviewCalendarIndex.from(_autoSmsPending,
   paidDueDates:entries.where((e)=>
    e.sourceType=='recurring'||e.sourceType=='goal_due')
    .map((e)=>e.date));
  final visibleSenderNames=<String>[];
  var visibleSenderRows=<Map<String,Object?>>[];
  var visibleReviewIds=<String>[];
  void rebuildCalendarIndex(){
   calendarIndex=WaffraSmsReviewCalendarIndex.from(_autoSmsPending,
    paidDueDates:entries.where((e)=>
     e.sourceType=='recurring'||e.sourceType=='goal_due')
     .map((e)=>e.date));
  }
  // M940: a bounded display window only; bulk selection always sees full IDs.
  final messageWindow=WaffraSmsReviewPageWindow();
  // Coalesce repeated near-bottom scroll notifications into one queue turn.
  var pageRevealScheduled=false;
  final selectedIds=<String>{};
  var bulkBusy=false;
  // M952: memoize *complete* sender IDs. Rebuilding 10k IDs for each
  // header, metric, checkbox or scroll repaint is unnecessary work.
  // The cache belongs to this dialog; confirmed mutations invalidate it.
  final idsCache=<List<Map<String,Object?>>,List<String>>{};
  List<String> idsOf(Iterable<Map<String,Object?>> rows){
   if(rows is List<Map<String,Object?>>){
    return idsCache.putIfAbsent(rows,()=>List<String>.unmodifiable(
     rows.map((row)=>row['id']).whereType<String>()));
   }
   return rows.map((row)=>row['id']).whereType<String>()
    .toList(growable:false);
  }
  final senderIds=<String,List<String>>{};
  var allReviewIds=<String>[];
  void refreshReviewIds(){
   idsCache.clear();
   senderIds.clear();
   final combined=<String>[];
   for(final sender in senders){
    final group=bySender[sender];
    if(group==null)continue;
    final ids=idsOf(group);
    senderIds[sender]=ids;
    combined.addAll(ids);
   }
   allReviewIds=List<String>.unmodifiable(combined);
   visibleSenderNames
    ..clear()
    ..addAll(selectedDay==null?senders:senders.where((sender)=>
     (bySender[sender]??const <Map<String,Object?>>[]).any((row){
      final id=row['id'];
      return id is String&&calendarIndex.matchesId(id,selectedDay!);
     })));
   final source=selectedSender==null?allReviewIds:
    senderIds[selectedSender]??const <String>[];
   visibleReviewIds=selectedDay==null?source:source.where(
    (id)=>calendarIndex.matchesId(id,selectedDay!)).toList(growable:false);
   final rows=bySender[selectedSender]??const <Map<String,Object?>>[];
   visibleSenderRows=selectedDay==null?rows:rows.where((row){
    final id=row['id'];
    return id is String&&calendarIndex.matchesId(id,selectedDay!);
   }).toList(growable:false);
  }
  refreshReviewIds();
  List<String> visibleIds()=>visibleReviewIds;
  void moveSender(int offset){
   if(selectedSender==null||visibleSenderNames.length<2)return;
   final current=visibleSenderNames.indexOf(selectedSender!);
   final next=current+offset;
   if(current<0||next<0||next>=visibleSenderNames.length)return;
   selectedSender=visibleSenderNames[next];
   messageWindow.reset();
   refreshReviewIds();
  }
  Color calendarDotColor(String kind,BuildContext ctx)=>switch(kind){
   'income'=>emerald,
   'expense'=>Colors.deepOrange,
   'transfer'=>const Color(0xFFD8A400),
   'due'=>Theme.of(ctx).brightness==Brightness.dark?
    const Color(0xFFD6BBFF):const Color(0xFF7653AA),
   _=>Theme.of(ctx).colorScheme.outline,
  };
  Future<void> openReviewCalendar(BuildContext ctx,StateSetter refresh)async{
   var month=DateTime(
    (selectedDay??DateTime.now()).year,(selectedDay??DateTime.now()).month);
   final selected=await showWaffraDialog<String>(
    context:ctx,builder:(dialog)=>StatefulBuilder(
     builder:(dialog,updateMonth){
      final start=DateTime(month.year,month.month);
      final offset=start.weekday%7; // Sunday first, RTL mirrors layout.
      final days=DateTime(month.year,month.month+1,0).day;
      final isDark=Theme.of(dialog).brightness==Brightness.dark;
      final labels=waffraIsEnglish?
       const <String>['Su','Mo','Tu','We','Th','Fr','Sa']:
       const <String>['أح','إث','ثل','أر','خم','جم','سب'];
      return AlertDialog(scrollable:true,
       title:WaffraText(waffraIsEnglish?'SMS review calendar':
        'تقويم رسائل المراجعة'),
       content:SizedBox(width:360,child:Column(
        mainAxisSize:MainAxisSize.min,children:[
         Row(children:[
          IconButton(key:const Key('m984-calendar-prev-month'),
           icon:const Icon(Icons.chevron_right_rounded),
           onPressed:()=>updateMonth(()=>
            month=DateTime(month.year,month.month-1))),
          Expanded(child:WaffraText(
           MaterialLocalizations.of(dialog).formatMonthYear(month),
           textAlign:TextAlign.center,
           style:const TextStyle(fontWeight:FontWeight.w700))),
          IconButton(key:const Key('m984-calendar-next-month'),
           icon:const Icon(Icons.chevron_left_rounded),
           onPressed:()=>updateMonth(()=>
            month=DateTime(month.year,month.month+1))),
         ]),
         Row(children:[
          for(final label in labels)Expanded(child:Center(
           child:WaffraText(label,style:const TextStyle(fontSize:11)))),
         ]),
         const SizedBox(height:4),
         GridView.builder(shrinkWrap:true,
          physics:const NeverScrollableScrollPhysics(),
          itemCount:offset+days,
          gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
           crossAxisCount:7,mainAxisSpacing:3,crossAxisSpacing:2,
           childAspectRatio:.88),
          itemBuilder:(cellContext,i){
           if(i<offset)return const SizedBox.shrink();
           final d=i-offset+1;
           final date=DateTime(month.year,month.month,d);
           final dots=calendarIndex.dots(date);
           final chosen=selectedDay==date;
           return InkWell(
            key:Key('m984-calendar-day-${date.year}-${date.month}-$d'),
            borderRadius:BorderRadius.circular(8),
            onTap:()=>Navigator.pop(dialog,date.toIso8601String()),
            child:Container(
             decoration:BoxDecoration(
              color:chosen?emerald.withValues(alpha:isDark ? .25 : .12):null,
              borderRadius:BorderRadius.circular(8)),
             child:Column(mainAxisAlignment:MainAxisAlignment.center,
              children:[
               WaffraText('$d',style:TextStyle(fontSize:13,
                color:chosen?emerald:null,
                fontWeight:dots.isNotEmpty?
                 FontWeight.bold:FontWeight.normal)),
               const SizedBox(height:3),
               Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                for(final kind in dots)Padding(
                 padding:const EdgeInsets.symmetric(horizontal:1.5),
                 child:Container(width:5,height:5,
                  decoration:BoxDecoration(shape:BoxShape.circle,
                   color:calendarDotColor(kind,dialog)))),
               ]),
              ])),
           );
          }),
         const SizedBox(height:12),
         Wrap(spacing:12,runSpacing:7,children:[
          for(final item in const <(String,String,String)>[
           ('income','Income','دخل'),('expense','Expense','مصروف'),
           ('transfer','Transfer','تحويل'),('due','Paid due','استحقاق مدفوع')])
           Row(mainAxisSize:MainAxisSize.min,children:[
            Container(width:7,height:7,decoration:BoxDecoration(
             shape:BoxShape.circle,
             color:calendarDotColor(item.$1,dialog))),
            const SizedBox(width:4),
            WaffraText(waffraIsEnglish?item.$2:item.$3,
             style:const TextStyle(fontSize:11)),
           ]),
         ]),
         const SizedBox(height:8),
         WaffraText(waffraIsEnglish?
          'Dots mark SMS received on each day (max 3); confirmed paid dues are counted separately.':
          'النقاط حسب تاريخ وصول الرسالة (بحد أقصى ٣)؛ الاستحقاقات المدفوعة منفصلة عن عدد الرسائل.',
          style:const TextStyle(fontSize:11)),
        ])),
       actions:[
        TextButton(key:const Key('m984-calendar-clear-day'),
         onPressed:()=>Navigator.pop(dialog,'clear'),
         child:WaffraText(waffraIsEnglish?'All dates':'كل الأيام')),
        TextButton(onPressed:()=>Navigator.pop(dialog),
         child:WaffraText(waffraIsEnglish?'Close':'إغلاق')),
       ],
      );
     }));
   if(!ctx.mounted||selected==null)return;
   refresh((){
    selectedDay=selected=='clear'?null:DateTime.tryParse(selected);
    selectedSender=null;
    messageWindow.reset();
    refreshReviewIds();
    if(selectedDay!=null){
     selectedIds.removeWhere((id)=>
      !calendarIndex.matchesId(id,selectedDay!));
    }
   });
  }
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(
    builder:(ctx,refresh)=>PopScope(
     // Explicit SMS selection must bypass Back-to-senders guard.
     canPop:selectedSender==null||openingReviewId!=null,
     onPopInvokedWithResult:(didPop,result){
      if(!didPop&&selectedSender!=null&&openingReviewId==null){
       refresh((){
        selectedSender=null;
        refreshReviewIds();
       });
      }
     },
     child:SafeArea(
     child:SizedBox(height:selectedSender==null?
       min(MediaQuery.sizeOf(ctx).height*.78,550.0):
       MediaQuery.sizeOf(ctx).height*.84,
      child:Column(children:[
       Padding(padding:const EdgeInsets.fromLTRB(14,3,14,8),
        child:Row(children:[
         IconButton(key:const Key('waffra-sms-senders-back'),
          icon:const Icon(Icons.arrow_back_rounded,color:forest),
          onPressed:(){
           if(selectedSender==null){Navigator.pop(ctx);}
           else{refresh((){
            selectedSender=null;
            refreshReviewIds();
           });}
          }),
         Expanded(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          WaffraText(selectedSender??(waffraIsEnglish?
           'Messages to review':'مراجعة الرسائل البنكية'),maxLines:2,
           style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          WaffraText(visibleIds().length.toString()+
           (waffraIsEnglish?' messages from ':' رسالة من ')+
           visibleSenderNames.length.toString()+
           (waffraIsEnglish?' senders':' مرسلين'),
           style:TextStyle(fontSize:12,
            color:Theme.of(ctx).colorScheme.onSurfaceVariant)),
         ])),
        ])),
       Padding(padding:const EdgeInsets.fromLTRB(12,1,12,6),
        child:WaffraSmsReviewMetrics(
         shown:visibleIds().length,selected:selectedIds.length,
         senderCount:senders.length,english:waffraIsEnglish)),
       Padding(padding:const EdgeInsets.fromLTRB(13,4,13,7),
        child:Container(
         decoration:BoxDecoration(
          color:Theme.of(ctx).brightness==Brightness.dark?
           const Color(0xFF193E31):const Color(0xFFF2F8F4),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          Checkbox(
           key:const Key('waffra-sms-select-all-visible'),
           value:visibleIds().isNotEmpty&&
            visibleIds().every(selectedIds.contains),
           onChanged:bulkBusy?null:(value)=>refresh((){
            if(value==true){selectedIds.addAll(visibleIds());}
            else{selectedIds.removeAll(visibleIds());}
           })),
          Expanded(child:WaffraText(waffraIsEnglish?
           'Select all shown messages':'تحديد كل الرسائل المعروضة',
           style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
          WaffraText(selectedIds.length.toString()+
           (waffraIsEnglish?' selected':' محددة'),
           style:const TextStyle(fontSize:12,color:emerald)),
          IconButton(
           key:const Key('m984-sms-calendar-button'),
           tooltip:waffraIsEnglish?'View SMS calendar':'عرض تقويم الرسائل',
           onPressed:bulkBusy?null:()=>openReviewCalendar(ctx,refresh),
           icon:const Icon(Icons.calendar_month_outlined,color:emerald)),
          if(selectedDay!=null)IconButton(
           key:const Key('m984-calendar-reset-filter'),
           tooltip:waffraIsEnglish?'Clear date filter':'إلغاء فلتر اليوم',
           icon:const Icon(Icons.filter_alt_off_outlined),
           onPressed:()=>refresh((){
            selectedDay=null;
            selectedSender=null;
            messageWindow.reset();
            refreshReviewIds();
           })),
         ]),
        )),
       if(selectedDay!=null)Padding(
        padding:const EdgeInsets.symmetric(horizontal:14,vertical:4),
        child:Row(children:[
         const Icon(Icons.event_note_outlined,size:17,color:emerald),
         const SizedBox(width:6),
         Expanded(child:WaffraText(waffraIsEnglish?
          'Received ${calendarIndex.smsCount(selectedDay!)} SMS on ${dayText(selectedDay!)} • ${calendarIndex.dueCount(selectedDay!)} paid dues':
          'وصل ${calendarIndex.smsCount(selectedDay!)} رسالة يوم ${dayText(selectedDay!)} • ${calendarIndex.dueCount(selectedDay!)} استحقاق مدفوع',
          style:const TextStyle(fontSize:12))),
        ])),
       if(selectedSender!=null&&visibleSenderNames.length>1)Padding(
        padding:const EdgeInsets.symmetric(horizontal:12),
        child:Row(children:[
         IconButton(key:const Key('m984-sender-previous'),
          tooltip:waffraIsEnglish?'Previous sender':'المرسل السابق',
          onPressed:bulkBusy||openingReviewId!=null||
           visibleSenderNames.indexOf(selectedSender!)<=0?null:
           ()=>refresh(()=>moveSender(-1)),
          icon:const Icon(Icons.chevron_right_rounded)),
         Expanded(child:WaffraText(
          '${visibleSenderNames.indexOf(selectedSender!)+1} / ${visibleSenderNames.length}',
          textAlign:TextAlign.center,
          style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold))),
         IconButton(key:const Key('m984-sender-next'),
          tooltip:waffraIsEnglish?'Next sender':'المرسل التالي',
          onPressed:bulkBusy||openingReviewId!=null||
           visibleSenderNames.indexOf(selectedSender!)>=visibleSenderNames.length-1?
           null:()=>refresh(()=>moveSender(1)),
          icon:const Icon(Icons.chevron_left_rounded)),
        ])),
       if(selectedDay!=null&&visibleSenderNames.isEmpty)Padding(
        padding:const EdgeInsets.all(12),
        child:WaffraText(waffraIsEnglish?
         'No SMS currently awaiting review on this day.':
         'لا توجد رسائل بانتظار المراجعة في اليوم المختار.',
         textAlign:TextAlign.center)),
       Expanded(child:GestureDetector(
        behavior:HitTestBehavior.translucent,
        onHorizontalDragEnd:selectedSender==null||bulkBusy||
         openingReviewId!=null?null:(details){
         final velocity=details.primaryVelocity??0;
         if(velocity.abs()<160)return;
         final rtl=Directionality.of(ctx)==TextDirection.rtl;
         final offset=velocity<0?(rtl?-1:1):(rtl?1:-1);
         refresh(()=>moveSender(offset));
        },
        child:NotificationListener<ScrollNotification>(
        onNotification:(notification){
         if(selectedSender==null||
            notification.metrics.axis!=Axis.vertical||
            notification.metrics.extentAfter>360)return false;
         final count=bySender[selectedSender]?.length??0;
         if(messageWindow.visibleCount(count)>=count)return false;
         // M486: do not post a frame callback inside the sender picker:
         // this route must stay mounted throughout nested SMS editing.
         // A coalesced event-loop turn occurs after current layout/scroll,
         // and cannot reveal rows for a sender already switched or closed.
         if(pageRevealScheduled)return false;
         pageRevealScheduled=true;
         final requestedSender=selectedSender;
         unawaited(Future<void>.delayed(Duration.zero,(){
          pageRevealScheduled=false;
          if(!ctx.mounted||selectedSender!=requestedSender)return;
          final latest=bySender[requestedSender]?.length??0;
          if(messageWindow.visibleCount(latest)<latest){
           refresh(()=>messageWindow.revealNext(latest));
          }
         }));
         return false;
        },
        child:ListView.builder(
        key:Key(selectedSender==null?'waffra-sms-sender-list':
         'waffra-sms-sender-transactions'),
        itemCount:selectedSender==null?visibleSenderNames.length:
         messageWindow.visibleCount(visibleSenderRows.length),
        itemBuilder:(rowContext,index){
         if(selectedSender==null){
          final sender=visibleSenderNames[index];
          final count=selectedDay==null?bySender[sender]!.length:
           bySender[sender]!.where((row){
            final id=row['id'];
            return id is String&&calendarIndex.matchesId(id,selectedDay!);
           }).length;
          return Card(
           margin:const EdgeInsets.symmetric(horizontal:13,vertical:5),
           elevation:0,
           shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
            side:BorderSide(color:forest.withValues(alpha:.14))),
           child:ListTile(
            key:Key('waffra-sms-sender-group-'+index.toString()),
            contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
            leading:WaffraSmsSenderBrand(sender:sender),
            title:WaffraText(sender,maxLines:2,
             style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15)),
            subtitle:Directionality(
             textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,
             child:WaffraText(waffraIsEnglish?
              '$count messages awaiting review':
              '\u2068$count\u2069 رسائل بانتظار المراجعة',
              style:const TextStyle(fontSize:12,color:emerald))),
            trailing:Row(mainAxisSize:MainAxisSize.min,children:[
             Checkbox(
              key:Key('waffra-sms-select-sender-'+index.toString()),
              value:idsOf(bySender[sender]!).isNotEmpty&&
               idsOf(bySender[sender]!).every(selectedIds.contains),
              onChanged:bulkBusy?null:(value)=>refresh((){
               final ids=idsOf(bySender[sender]!);
               if(value==true){selectedIds.addAll(ids);}
               else{selectedIds.removeAll(ids);}
              })),
             const Icon(Icons.chevron_left_rounded,color:forest),
            ]),
            onTap:()=>refresh((){
             selectedSender=sender;
             messageWindow.reset();
             refreshReviewIds();
            }),
           ));
         }
         final item=visibleSenderRows[index];
         final id=item['id'],at=item['receivedAt'];
         final date=at is int?DateTime.fromMillisecondsSinceEpoch(at)
          .toLocal().toString().substring(0,16):'';
         // M983: when a typed SMS editor returns, refresh this same modal
         // against current owner-verified native IDs and ALL four local rules.
         Future<void> openTypedRow({String? kind})async{
          if(id is! String||bulkBusy||openingReviewId!=null)return;
          refresh(()=>openingReviewId=id);
          try{
           if(kind==null)await _reviewAutoSmsCandidates(targetId:id);
           else await _m983OpenSmsTypedTemplate(id:id,kind:kind);
           if(mounted)await _refreshAutoSmsInbox();
          }finally{
           if(ctx.mounted)refresh((){
            openingReviewId=null;
            if(!_autoSmsPending.any((row)=>row['id']==id)){
             grouped.removeReviewedId(id);
             selectedIds.remove(id);
            }
            final fresh=WaffraSmsReviewGroups.from(_autoSmsPending,
             unknownSender:waffraIsEnglish?
              'Unknown sender':'مرسل غير محدد');
            bySender..clear()..addAll(fresh.bySender);
            senders..clear()..addAll(fresh.senders);
            rebuildCalendarIndex();
            refreshReviewIds();
            final active=allReviewIds.toSet();
            selectedIds.removeWhere((selected)=>!active.contains(selected));
            if(selectedSender!=null&&!visibleSenderNames.contains(selectedSender)){
             selectedSender=null;
             messageWindow.reset();
            }
           });
          }
         }
         // Legacy external guesses remain untrusted; the user reviews SMS text.
         final local=item['local'] is Map?item['local'] as Map:null;
         final smsFacts=WaffraBankSmsFactsParser.parse(
          item['body'] is String?item['body'] as String:'');
         final suggestedKind=local?['kind'] is String?
          local!['kind'] as String:switch(smsFacts.kind){
           WaffraBankOperationKind.income=>'income',
           WaffraBankOperationKind.expense=>'expense',
           WaffraBankOperationKind.transfer=>'transfer',
           _=>null,
          };
         final confidential=item['sensitiveOtp']==true||
          (item['body'] is String&&
           WaffraBankSmsFactsParser.isVerificationChallenge(item['body'] as String));
         return ListTile(
          key:Key('waffra-sms-sender-message-'+index.toString()),
          leading:const Icon(Icons.sms_outlined,color:emerald),
          title:WaffraText(local==null?
           (confidential||
            !const <String>{'income','expense','transfer'}.contains(suggestedKind)?
            (waffraIsEnglish?'Needs review':'عملية تحتاج مراجعة'):
            (waffraIsEnglish?'Suggested • ':'مقترح • ')+
             (suggestedKind=='income'?(waffraIsEnglish?'Income':'دخل'):
              suggestedKind=='expense'?(waffraIsEnglish?'Expense':'مصروف'):
              (waffraIsEnglish?'Transfer':'تحويل'))):
           (local['suggestedOnly']==true?
            (waffraIsEnglish?'Suggested • ':'مقترح • '):
            (waffraIsEnglish?'Local rule • ':'قاعدة محلية • '))+
            (local['kind']=='transfer'?
             (waffraIsEnglish?'Transfer':'تحويل'):
             local['kind']=='excluded'?
             (waffraIsEnglish?'Excluded':'مستبعدة'):
             local['income']==true?
              (waffraIsEnglish?'Income':'دخل'):
              (waffraIsEnglish?'Expense':'مصروف'))),
          // Preserve the real original SMS text in the history review, with
          // sender and date without presenting untrusted suggestions.
          subtitle:Column(
           crossAxisAlignment:CrossAxisAlignment.start,children:[
            WaffraText(
             ((item['body'] as String?)??'')+'\n'+
             (local!=null?"${local['category']} • ":'')+
             (waffraIsEnglish?'Review amount, category and budget':
              'راجع المبلغ والقسم والميزانية')+
             (date.isEmpty?'':' • '+date),maxLines:5),
            if(!confidential)Padding(
             padding:const EdgeInsets.only(top:7),
             child:Wrap(spacing:6,runSpacing:5,children:[
              for(final kind in const <String>['income','expense','transfer'])
               ActionChip(
                key:Key('m983-sms-direct-'+kind+'-'+index.toString()),
                avatar:Icon(kind=='income'?Icons.south_west_rounded:
                 kind=='expense'?Icons.north_east_rounded:
                  Icons.swap_horiz_rounded,
                 size:16,color:kind=='income'?emerald:
                  kind=='expense'?Colors.red:const Color(0xFFD8A400)),
                label:WaffraText(kind=='income'?
                 (waffraIsEnglish?'Income':'دخل'):
                 kind=='expense'?(waffraIsEnglish?'Expense':'مصروف'):
                  (waffraIsEnglish?'Transfer':'تحويل'),
                 style:TextStyle(fontSize:11,
                  fontWeight:suggestedKind==kind?
                   FontWeight.bold:FontWeight.normal)),
                onPressed:bulkBusy||openingReviewId!=null?null:
                 ()=>openTypedRow(kind:kind)),
             ])),
           ]),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[
           Checkbox(
            key:Key('waffra-sms-select-message-'+index.toString()),
            value:id is String&&selectedIds.contains(id),
            onChanged:bulkBusy||id is! String?null:(value)=>refresh((){
             if(value==true){selectedIds.add(id);}
             else{selectedIds.remove(id);}
            })),
           const Icon(Icons.chevron_left_rounded),
          ]),
          onTap:bulkBusy||openingReviewId!=null||id is! String?null:
           ()=>openTypedRow(kind:!confidential&&
            const <String>{'income','expense','transfer'}.contains(suggestedKind)?
             suggestedKind:null),
         );
        })))),
       if(selectedIds.isNotEmpty)Padding(
        padding:const EdgeInsets.fromLTRB(12,8,12,4),
        child:SizedBox(width:double.infinity,child:FilledButton.icon(
         key:const Key('waffra-sms-bulk-exclude-selected'),
         icon:bulkBusy?
          const SizedBox(width:18,height:18,
           child:CircularProgressIndicator(strokeWidth:2)):
          const Icon(Icons.delete_outline_rounded),
         label:WaffraText(waffraIsEnglish?
          'Exclude ${selectedIds.length} selected':
          'استبعاد ${selectedIds.length} رسالة محددة'),
         onPressed:bulkBusy?null:()async{
          // Explicit queue removal first, followed by a SEPARATE sender opt-in.
          // No Android SMS or financial ledger entries are deleted.
          final ids=selectedIds.toList(growable:false);
          final idSet=ids.toSet();
          // Selection is an explicit owner decision. Do not synchronously
          // parse up to 1000 SMS on the UI isolate before painting the dialog.
          // This removes an O(N) CPU-heavy path from every bulk exclusion tap.
          final confirmed=await showWaffraDialog<bool>(
           context:ctx,builder:(dialog)=>AlertDialog(
            title:WaffraText(waffraIsEnglish?
             'Exclude selected messages?':'استبعاد الرسائل المحددة؟'),
            content:WaffraText(waffraIsEnglish?
             'Remove ${ids.length} items from Waffra review only. '
             'Your phone SMS and saved financial transactions are untouched. '
             'Some messages may describe finances; review your selection.':
             'سيتم استبعاد ${ids.length} رسالة من مراجعة وفرة فقط، '
             'دون حذف رسائل الهاتف أو أي عمليات مالية محفوظة. '
             'قد تتضمن الرسائل معاملات مالية؛ راجع اختيارك.'),
            actions:[
             TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
             FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:WaffraText(waffraIsEnglish?'Exclude':'تأكيد الاستبعاد')),
            ]));
          if(confirmed!=true||!ctx.mounted)return;
          // M479 / #417: no native message acknowledgement occurs until
          // both confirmations are settled. 'Back' preserves selected IDs
          // and returns to this still-open review rather than hiding SMS.
          // One sender decision for the entire selection rather than one
          // confirmation dialog PER SENDER (1000 dialogs were possible).
          final fullySelectedSenders=senders.where((sender){
           final groupIds=idsOf(bySender[sender]??const []);
           return groupIds.isNotEmpty&&groupIds.every(idSet.contains);
          }).toList(growable:false);
          final senderChoice=fullySelectedSenders.isEmpty?'messages':
           await showWaffraDialog<String>(
            context:context,builder:(dialog)=>AlertDialog(
             title:WaffraText(waffraIsEnglish?
              'Exclude these senders too?':'هل تريد استبعاد المرسلين أيضًا؟'),
             content:WaffraText(waffraIsEnglish?
              'Exclude selected messages only, or block the selected senders '
              'from future reviews too? Sender blocking stores names only.':
              'تستبعد الرسائل المحددة فقط، أو تستبعد المرسلين كمان '
              'من المراجعات القادمة؟ عند استبعاد المرسل هنحتفظ باسمه فقط.'),
             actions:[
              TextButton(onPressed:()=>Navigator.pop(dialog,'back'),
               child:WaffraText(waffraIsEnglish?'Back':'العودة')),
              TextButton(onPressed:()=>Navigator.pop(dialog,'messages'),
               child:WaffraText(waffraIsEnglish?'Messages only':'الرسائل فقط')),
              FilledButton(onPressed:()=>Navigator.pop(dialog,'senders'),
               child:WaffraText(waffraIsEnglish?'Block senders':'استبعاد المرسلين')),
             ]));
          if(senderChoice==null||senderChoice=='back'||!ctx.mounted)return;
          final senderBlockChoices=senderChoice=='senders'?
           fullySelectedSenders.toSet():<String>{};
          final blockedIds=<String>{};
          for(final sender in senderBlockChoices){
           blockedIds.addAll(idsOf(bySender[sender]??const []));
          }
          refresh(()=>bulkBusy=true);
          final done=<String>{};
          var failed=false;
          try{
           // One native encrypted commit blocks selected senders and purges
           // their queued and previous individually excluded SMS metadata.
           if(senderBlockChoices.isNotEmpty){
            if(await WaffraAutoSms.excludeSenders(senderBlockChoices.toList())){
             done.addAll(blockedIds);
            }else{failed=true;}
           }
           // Unblocked individual SMS need durable anti-replay IDs. Native
           // policy commits up to 100 IDs per batch and preserves failures.
           final remainingMessageIds=ids.where((id)=>!blockedIds.contains(id))
            .toList(growable:false);
           if(!failed)for(var at=0;at<remainingMessageIds.length;at+=100){
            final batch=remainingMessageIds.skip(at).take(100)
             .toList(growable:false);
            if(!await WaffraAutoSms.excludeMessages(batch)){
             failed=true;break;
            }
            done.addAll(batch);
           }
           if(done.isNotEmpty){
            // Bulk and individual exclusions learn identical safe,
            // owner-encrypted review-only keywords after native success.
            if(_smsRuleOwnerKey.isNotEmpty){
             try{
              final store=const WaffraSmsLocalRuleStore();
              final previous=await store.read(_smsRuleOwnerKey);
              var next=previous;
              for(final row in _autoSmsPending.where(
                  (row)=>done.contains(row['id']))){
               final body=row['body'],sender=row['sender'];
               if(body is! String||sender is! String||
                  blockedIds.contains(row['id']))continue;
               final candidate=WaffraSmsLocalRules.suggestedRule(
                body:body,sender:sender,kind:'excluded',
                confidentOnly:true);
               if(candidate!=null){
                next=WaffraSmsLocalRules.upsertLearned(
                 existing:next,candidate:candidate);
               }
              }
              // Do not retain automatically learned exclusion keywords for
              // sender-blocked messages. Keep explicit user-authored rules.
              final blocked=senderBlockChoices.map(
               WaffraSmsLocalRules.normalized).toSet();
              final clean=next.where((rule)=>!(rule.id.startsWith('smart_')&&
               rule.resolvedKind=='excluded'&&blocked.contains(
                WaffraSmsLocalRules.normalized(rule.sender)))).toList();
              if(clean.length!=next.length)next=clean;
              if(!identical(previous,next)){
               await store.write(_smsRuleOwnerKey,next);
              }
             }catch(_){
              if(mounted)snack(context,waffraIsEnglish?
               'Messages excluded; safe rule learning unavailable.':
               'تم الاستبعاد، لكن تعذر حفظ قاعدة تعلم آمنة.',isError:true);
             }
            }
            if(mounted)setState(()=>
             _autoSmsPending.removeWhere((row)=>done.contains(row['id'])));
            for(final rows in bySender.values){
             rows.removeWhere((row)=>done.contains(row['id']));
            }
            senders.removeWhere((sender)=>bySender[sender]!.isEmpty);
            rebuildCalendarIndex();
            refreshReviewIds();
            selectedIds.removeAll(done);
           }
           // On a partial native failure, keep the list mounted so the
           // unprocessed selection is still visible and safely retryable.
           if(!failed&&ctx.mounted)Navigator.pop(ctx);
           if(mounted){
            if(failed)snack(context,waffraIsEnglish?
             'Only ${done.length} messages were excluded. Retry remaining items.':
             'تم استبعاد ${done.length} فقط. أعد محاولة الباقي.',isError:true);
            else snackSuccess(context,waffraIsEnglish?
             'Excluded ${done.length} messages from review.':
             'تم استبعاد ${done.length} رسالة من المراجعة.');
            // Keep the queue and counts synced without silently launching
            // another historical import during the bulk-exclusion animation.
            // The user can continue an incomplete history via Rescan.
            unawaited(_refreshAutoSmsInbox());
           }
          }catch(_){
           if(mounted)snack(context,waffraIsEnglish?
            'Bulk exclusion failed. Unconfirmed messages remain in review.':
            'تعذر الاستبعاد الجماعي. الرسائل غير المؤكدة باقية للمراجعة.',
            isError:true);
          }finally{
           if(ctx.mounted)refresh(()=>bulkBusy=false);
          }
         },
        ))),
       Padding(padding:const EdgeInsets.fromLTRB(13,8,13,14),
        child:Container(padding:const EdgeInsets.all(12),
         decoration:BoxDecoration(color:const Color(0xFFE8F4EB),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          const Icon(Icons.info_outline_rounded,color:forest,size:20),
          const SizedBox(width:9),
          Expanded(child:WaffraText(waffraIsEnglish?
           'Nothing is recorded before your review and confirmation.':
           'لن تُسجَّل أي عملية مالية إلا بعد مراجعتك وتأكيدك.',
           style:const TextStyle(color:forest,fontSize:12),maxLines:3)),
         ]))),
      ]),
     ),
    ),
    ),
   ),
  );
  // The sender inbox route remains beneath the message review.
 }
}

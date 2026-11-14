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
  final selectedIds=<String>{};
  var bulkBusy=false;
  List<String> idsOf(Iterable<Map<String,Object?>> rows)=>
   rows.map((row)=>row['id']).whereType<String>().toList(growable:false);
  List<String> visibleIds()=>selectedSender==null?
   idsOf(bySender.values.expand((rows)=>rows)):
   idsOf(bySender[selectedSender]??const <Map<String,Object?>>[]);
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   builder:(sheet)=>StatefulBuilder(
    builder:(ctx,refresh)=>PopScope(
     // Explicit SMS selection must bypass Back-to-senders guard.
     canPop:selectedSender==null||openingReviewId!=null,
     onPopInvokedWithResult:(didPop,result){
      if(!didPop&&selectedSender!=null&&openingReviewId==null){
       refresh(()=>selectedSender=null);
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
           else{refresh(()=>selectedSender=null);}
          }),
         Expanded(child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          WaffraText(selectedSender??(waffraIsEnglish?
           'Messages to review':'مراجعة الرسائل البنكية'),maxLines:2,
           style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
          WaffraText(visibleIds().length.toString()+
           (waffraIsEnglish?' messages from ':' رسالة من ')+
           senders.length.toString()+
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
          const SizedBox(width:12),
         ]),
        )),
       Expanded(child:ListView.builder(
        key:Key(selectedSender==null?'waffra-sms-sender-list':
         'waffra-sms-sender-transactions'),
        itemCount:selectedSender==null?senders.length:
         (bySender[selectedSender]?.length??0),
        itemBuilder:(rowContext,index){
         if(selectedSender==null){
          final sender=senders[index],count=bySender[sender]!.length;
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
            onTap:()=>refresh(()=>selectedSender=sender),
           ));
         }
         final item=bySender[selectedSender]![index];
         final id=item['id'],at=item['receivedAt'];
         final date=at is int?DateTime.fromMillisecondsSinceEpoch(at)
          .toLocal().toString().substring(0,16):'';
         // Legacy external guesses remain untrusted; the user reviews SMS text.
         final local=item['local'] is Map?item['local'] as Map:null;
         return ListTile(
          key:Key('waffra-sms-sender-message-'+index.toString()),
          leading:const Icon(Icons.sms_outlined,color:emerald),
          title:WaffraText(local==null?
           (waffraIsEnglish?'Needs review':'عملية تحتاج مراجعة'):
           (waffraIsEnglish?'Local rule • ':'قاعدة محلية • ')+
            (local['kind']=='transfer'?
             (waffraIsEnglish?'Transfer':'تحويل'):
             local['kind']=='excluded'?
             (waffraIsEnglish?'Excluded':'مستبعدة'):
             local['income']==true?
              (waffraIsEnglish?'Income':'دخل'):
              (waffraIsEnglish?'Expense':'مصروف'))),
          // Preserve the real original SMS text in the history review, with
          // sender and date without presenting untrusted suggestions.
          subtitle:WaffraText(
           ((item['body'] as String?)??'')+'\n'+
           (local!=null?"${local['category']} • ":'')+
           (waffraIsEnglish?'Review amount, category and budget':
            'راجع المبلغ والقسم والميزانية')+
           (date.isEmpty?'':' • '+date),maxLines:5),
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
          onTap:bulkBusy||openingReviewId!=null?null:(id is String)?()async{
           // M486: keep the sender inbox underneath review/editor so Back
           // returns one level and preserves the sender's selection.
           refresh(()=>openingReviewId=id);
           try{
            await _reviewAutoSmsCandidates(targetId:id);
           }finally{
            if(ctx.mounted)refresh((){
             openingReviewId=null;
             if(!_autoSmsPending.any((row)=>row['id']==id)){
              for(final group in bySender.values){
               group.removeWhere((row)=>row['id']==id);
              }
              selectedIds.remove(id);
              senders.removeWhere((name)=>bySender[name]?.isEmpty??true);
              if(selectedSender!=null&&!senders.contains(selectedSender)){
               selectedSender=null;
              }
             }
            });
           }
          }:null,
         );
        })),
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

import 'package:flutter/material.dart';

/// One already-detected SMS; each row has its own non-posting suggestion.
class WaffraReviewNotice {
 const WaffraReviewNotice({
  required this.id,required this.sender,required this.preview,
  this.kind,this.amount,
 });
 final String id,sender,preview;
 final String? kind;
 final double? amount;
}

/// Notifications list is the review entry point, not a second overview sheet.
/// Sender filters use only sender metadata; never decrypt 1000 SMS here.
class WaffraApprovedNotificationsPage extends StatefulWidget {
 const WaffraApprovedNotificationsPage({
  super.key,required this.english,required this.readPending,
  required this.onReviewAll,required this.onReviewOne,
  required this.onRescan,required this.canRescan,this.onBulkExclude,
 });
 final bool english;
 final List<WaffraReviewNotice> Function() readPending;
 // Retained for source compatibility with prior route callers.
 final Future<void> Function() onReviewAll;
 final Future<void> Function(String id) onReviewOne;
 final Future<void> Function() onRescan;
 final bool Function() canRescan;
 /// Exact selected pending IDs and sender labels *explicitly* approved by
 /// the user. The caller still verifies the live encrypted owner queue.
 final Future<bool> Function(List<String> ids,List<String> senders)?
  onBulkExclude;
 @override State<WaffraApprovedNotificationsPage> createState()=>
  _WaffraApprovedNotificationsPageState();
}

class _WaffraApprovedNotificationsPageState
    extends State<WaffraApprovedNotificationsPage> {
 String filter='all';
 bool busy=false,selecting=false;
 final selectedIds=<String>{};
 void toggle(String id)=>setState((){
  if(!selectedIds.add(id))selectedIds.remove(id);
 });

 static const green=Color(0xFF064D3B), emerald=Color(0xFF087A54);
 static const cream=Color(0xFFF8F6EF);
 Future<void> run(Future<void> Function() action)async{
  if(busy)return;
  setState(()=>busy=true);
  try{await WidgetsBinding.instance.endOfFrame;await action();}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Widget category(String key,String label,int count){
  final active=filter==key;
  return ChoiceChip(
   key:Key('m580-notification-filter-'+key),selected:active,
   showCheckmark:false,side:BorderSide(color:active?emerald:const Color(0xFFDCE8E2)),
   backgroundColor:Colors.white,selectedColor:green,
   label:Text(label+' ('+count.toString()+')',
    maxLines:1,overflow:TextOverflow.ellipsis,
    style:TextStyle(color:active?Colors.white:green,
     fontWeight:FontWeight.w700,fontSize:11)),
   onSelected:(_)=>setState((){
    // A filter change cannot accidentally act on hidden selections.
    filter=key;selectedIds.clear();
   }));
 }
 Widget noticeTile(WaffraReviewNotice notice){
  final kind=switch(notice.kind){
   'income'=>widget.english?'Income':'دخل',
   'expense'=>widget.english?'Expense':'مصروف',
   'transfer'=>widget.english?'Transfer':'تحويل',
   'excluded'=>widget.english?'Excluded':'مستبعدة',
   'otpReview'=>widget.english?'Verification • review only':
    'رسالة تحقق — تحتاج مراجعة',
   'excludeSuggestion'=>widget.english?'Suggested for exclusion':
    'مقترحة للاستبعاد',
   _=>widget.english?'Needs review':'تحتاج مراجعة',
  };
  final color=notice.kind=='expense'?const Color(0xFFB94838):
   (notice.kind=='excluded'||notice.kind=='otpReview'||
    notice.kind=='excludeSuggestion')?const Color(0xFF6A6A60):emerald;
  return Padding(
   padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
   child:Material(color:Colors.white,borderRadius:BorderRadius.circular(15),
    child:InkWell(
     key:Key('m549-notification-message-'+notice.id),
     borderRadius:BorderRadius.circular(15),
     onTap:busy?null:selecting?
      ()=>toggle(notice.id):()=>run(()=>widget.onReviewOne(notice.id)),
     child:Container(
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
       border:Border.all(color:const Color(0xFFE2ECE6)),
       borderRadius:BorderRadius.circular(15)),
      child:Row(children:[
       if(selecting)Checkbox(
        key:Key('m592-notice-select-'+notice.id),
        value:selectedIds.contains(notice.id),
        onChanged:busy?null:(_)=>toggle(notice.id)),
       Container(width:35,height:35,decoration:BoxDecoration(
        color:const Color(0xFFE7F3EA),borderRadius:BorderRadius.circular(12)),
        child:const Icon(Icons.account_balance_outlined,color:green,size:20)),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(notice.sender,maxLines:1,overflow:TextOverflow.ellipsis,
         style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
        const SizedBox(height:3),
        Text(notice.preview,maxLines:2,overflow:TextOverflow.ellipsis,
         style:const TextStyle(fontSize:11,color:Color(0xFF64766E))),
        Padding(padding:const EdgeInsets.only(top:5),
         child:Text(kind,style:TextStyle(fontSize:11,
          color:color,fontWeight:FontWeight.bold))),
       ])),
       if(notice.amount!=null&&
          notice.kind!='excluded'&&notice.kind!='needsReview')
        Padding(padding:const EdgeInsets.symmetric(horizontal:5),
         child:Text(notice.amount!.toStringAsFixed(2),
          style:TextStyle(fontSize:12,color:color,fontWeight:FontWeight.bold))),
       const Icon(Icons.chevron_left_rounded,color:green),
      ]),
     ),
    ),
   ),
  );
 }
 @override Widget build(BuildContext context){
  final items=widget.readPending();
  // One linear pass and sender-key reuse; no message body parsing in build.
  final senderLabels=<String,String>{};
  final senderGroups=<String,List<WaffraReviewNotice>>{};
  for(final item in items){
   final senderKey=item.sender.trim().toLowerCase();
   senderLabels.putIfAbsent(senderKey,()=>item.sender.trim());
   senderGroups.putIfAbsent(senderKey,()=><WaffraReviewNotice>[]).add(item);
  }
  final keys=senderGroups.keys.toList(growable:false);
  final selected=filter.startsWith('sender:')?filter.substring(7):null;
  final shown=selected==null?items:
   (senderGroups[selected]??const <WaffraReviewNotice>[]);
  return Directionality(
   textDirection:widget.english?TextDirection.ltr:TextDirection.rtl,
   child:Scaffold(
    backgroundColor:cream,
    appBar:AppBar(
     key:const Key('m549-notifications-appbar'),
     backgroundColor:green,foregroundColor:Colors.white,centerTitle:true,
     title:Text(widget.english?'Notifications':'الإشعارات',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
     actions:[
     IconButton(
      key:const Key('m589-open-bulk-sms-review'),
      tooltip:widget.english?'Select or exclude messages':'تحديد أو استبعاد الرسائل',
      onPressed:busy?null:widget.onBulkExclude==null?
       ()=>run(widget.onReviewAll):()=>setState((){
        selecting=!selecting;selectedIds.clear();
       }),
      icon:Icon(selecting?Icons.close_rounded:Icons.fact_check_outlined)),
     IconButton(
      tooltip:widget.english?'Refresh bank messages':'إعادة فحص الرسائل',
      onPressed:busy||!widget.canRescan()?null:()=>run(widget.onRescan),
      icon:busy?
       const SizedBox(width:21,height:21,child:CircularProgressIndicator(
        strokeWidth:2,color:Colors.white)):
       const Icon(Icons.refresh_rounded))],
    ),
    body:Column(children:[
     if(busy)const LinearProgressIndicator(minHeight:2),
     SizedBox(height:59,child:ListView.builder(
      key:const Key('m580-sender-filters'),
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
      scrollDirection:Axis.horizontal,
      itemCount:keys.length+1,
      itemBuilder:(ctx,index)=>Padding(
       padding:const EdgeInsetsDirectional.only(end:7),
       child:index==0?
        category('all',widget.english?'All':'الكل',items.length):
        category('sender:'+keys[index-1],senderLabels[keys[index-1]]!,
         senderGroups[keys[index-1]]!.length)),
     )),
     if(selecting&&widget.onBulkExclude!=null)Padding(
      padding:const EdgeInsets.fromLTRB(12,0,12,7),
      child:Row(children:[
       Expanded(child:OutlinedButton.icon(
        key:const Key('m592-select-all-visible'),
        icon:Icon(shown.isNotEmpty&&
         shown.every((row)=>selectedIds.contains(row.id))?
          Icons.deselect_rounded:Icons.select_all_rounded),
        label:Text(shown.isNotEmpty&&
          shown.every((row)=>selectedIds.contains(row.id))?
         (widget.english?'Deselect all':'إلغاء التحديد'):
         (widget.english?'Select all':'تحديد الكل')),
        onPressed:busy||shown.isEmpty?null:()=>setState((){
         final allSelected=shown.every((r)=>selectedIds.contains(r.id));
         if(allSelected){for(final item in shown){selectedIds.remove(item.id);}}
         else{for(final item in shown){selectedIds.add(item.id);}}
        }),
       )),
       const SizedBox(width:8),
       Text((widget.english?'Selected: ':'المحدد: ')+
        selectedIds.length.toString(),
        style:const TextStyle(color:green,fontWeight:FontWeight.w700)),
      ]),
     ),
     Expanded(child:shown.isEmpty?
      Center(child:Text(widget.english?'No messages to review':
       'لا توجد رسائل تحتاج للمراجعة',
       style:const TextStyle(color:Color(0xFF708177)))):
      ListView.builder(
       key:const Key('m549-notification-list'),itemCount:shown.length,
       itemBuilder:(ctx,index)=>RepaintBoundary(
        key:ValueKey('m580-notice-'+shown[index].id),
        child:noticeTile(shown[index])),
      )),
     if(selecting&&widget.onBulkExclude!=null&&selectedIds.isNotEmpty)
      SafeArea(top:false,child:Padding(
       padding:const EdgeInsets.fromLTRB(12,8,12,10),
       child:SizedBox(width:double.infinity,
        child:FilledButton.icon(
         key:const Key('m592-confirm-bulk-exclude'),
         style:FilledButton.styleFrom(backgroundColor:green),
         icon:const Icon(Icons.block_outlined),
         label:Text(widget.english?
          'Exclude ${selectedIds.length} selected':
          'استبعاد ${selectedIds.length} رسالة محددة'),
         onPressed:busy?null:()async{
          // IDs from the selected current filter only. Full sender blocking
          // requires all of that sender's visible pending queue to be chosen.
          final ids=shown.where((r)=>selectedIds.contains(r.id))
           .map((r)=>r.id).toList(growable:false);
          final fullKeys=senderGroups.keys.where((key)=>
           senderGroups[key]!.isNotEmpty&&
           senderGroups[key]!.every((r)=>ids.contains(r.id))).toList();
          final senders=fullKeys.map((key)=>senderLabels[key]!)
           .toList(growable:false);
          if(ids.isEmpty)return;
          final approved=await showDialog<bool>(context:context,
           builder:(dialog)=>AlertDialog(
            title:Text(widget.english?'Confirm exclusion':'تأكيد الاستبعاد'),
            content:Text(widget.english?
             'Exclude ${ids.length} Waffra review messages; '
             'block ${senders.length} complete senders (future SMS too). '
             'Phone messages and saved transactions are untouched.':
             'سيتم استبعاد ${ids.length} رسالة من مراجعة وفرة، '
             'واستبعاد ${senders.length} مرسل كامل من الرسائل القادمة. '
             'رسائل الهاتف والعمليات المالية المحفوظة لن تتأثر.'),
            actions:[
             TextButton(onPressed:()=>Navigator.pop(dialog,false),
              child:Text(widget.english?'Back':'العودة')),
             FilledButton(onPressed:()=>Navigator.pop(dialog,true),
              child:Text(widget.english?'Confirm':'تأكيد')),
            ]));
          if(approved!=true||!mounted)return;
          await run(()async{
           final ok=await widget.onBulkExclude!(ids,senders);
           if(ok&&mounted)setState((){
            selectedIds.clear();selecting=false;
           });
          });
         },
        )),
      )),
    ]),
   ));
 }
}

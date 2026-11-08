import 'package:flutter/material.dart';

/// A pending bank-SMS notice; no fabricated finance or system alerts.
class WaffraReviewNotice {
 const WaffraReviewNotice({
  required this.id,required this.sender,required this.preview,
  this.kind,this.amount,
 });
 final String id,sender,preview;
 final String? kind;
 final double? amount;
}

/// M549: notifications center matching the approved 2026-11-08 reference.
/// Live callbacks keep list and counters synced after a confirmed SMS.
class WaffraApprovedNotificationsPage extends StatefulWidget {
 const WaffraApprovedNotificationsPage({
  super.key,required this.english,required this.readPending,
  required this.onReviewAll,required this.onReviewOne,
  required this.onRescan,required this.canRescan,
 });
 final bool english;
 final List<WaffraReviewNotice> Function() readPending;
 final Future<void> Function() onReviewAll;
 final Future<void> Function(String id) onReviewOne;
 final Future<void> Function() onRescan;
 final bool Function() canRescan;
 @override State<WaffraApprovedNotificationsPage> createState()=>
  _WaffraApprovedNotificationsPageState();
}
class _WaffraApprovedNotificationsPageState
    extends State<WaffraApprovedNotificationsPage> {
 String filter='all';
 bool busy=false;
 static const green=Color(0xFF064D3B), emerald=Color(0xFF087A54);
 static const cream=Color(0xFFF8F6EF);
 Future<void> run(Future<void> Function() action)async{
  if(busy)return;
  setState(()=>busy=true);
  try{await action();}
  finally{if(mounted)setState(()=>busy=false);}
 }
 Widget category(String key,String ar,String en,int count){
  final active=filter==key;
  return ChoiceChip(
   key:Key('m549-notification-filter-'+key),selected:active,
   showCheckmark:false,side:BorderSide(color:active?emerald:const Color(0xFFDCE8E2)),
   backgroundColor:Colors.white,selectedColor:green,
   label:Text((widget.english?en:ar)+(count>0?' ('+count.toString()+')':''),
    style:TextStyle(color:active?Colors.white:green,
     fontWeight:FontWeight.w700,fontSize:11)),
   onSelected:(_)=>setState(()=>filter=key));
 }
 Widget noticeTile(WaffraReviewNotice notice){
  final kind=notice.kind=='income'?
   (widget.english?'Income':'دخل'):
   notice.kind=='expense'?(widget.english?'Expense':'مصروف'):null;
  final color=notice.kind=='expense'?const Color(0xFFB94838):emerald;
  return Padding(
   padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
   child:Material(color:Colors.white,borderRadius:BorderRadius.circular(15),
    child:InkWell(
     key:Key('m549-notification-message-'+notice.id),
     borderRadius:BorderRadius.circular(15),
     onTap:busy?null:()=>run(()=>widget.onReviewOne(notice.id)),
     child:Container(
      padding:const EdgeInsets.all(12),
      decoration:BoxDecoration(
       border:Border.all(color:const Color(0xFFE2ECE6)),
       borderRadius:BorderRadius.circular(15)),
      child:Row(children:[
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
        if(kind!=null)Padding(padding:const EdgeInsets.only(top:5),
         child:Text(kind,style:TextStyle(fontSize:11,
          color:color,fontWeight:FontWeight.bold))),
       ])),
       if(notice.amount!=null)Padding(padding:const EdgeInsets.symmetric(horizontal:5),
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
  // No parsing 1000 encrypted SMS bodies on the UI isolate each frame.
  final count=items.length;
  final shown=filter=='updates'?<WaffraReviewNotice>[]:items;
  return Directionality(
   textDirection:widget.english?TextDirection.ltr:TextDirection.rtl,
   child:Scaffold(
    backgroundColor:cream,
    appBar:AppBar(
     key:const Key('m549-notifications-appbar'),
     backgroundColor:green,foregroundColor:Colors.white,centerTitle:true,
     title:Text(widget.english?'Notifications':'الإشعارات',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:19)),
     actions:[IconButton(
      tooltip:widget.english?'Refresh bank messages':'إعادة فحص الرسائل',
      onPressed:busy||!widget.canRescan()?null:()=>run(widget.onRescan),
      icon:const Icon(Icons.refresh_rounded))],
    ),
    body:Column(children:[
     SizedBox(height:59,child:ListView(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
      scrollDirection:Axis.horizontal,
      children:[
       category('all','الكل','All',count),
       const SizedBox(width:7),
       category('review','مراجعة العمليات','Review',count),
       const SizedBox(width:7),
       category('bank','البنكية','Banking',count),
       const SizedBox(width:7),
       category('updates','التطبيق','App',0),
      ],
     )),
     if(filter!='updates')Container(
      key:const Key('m549-notification-review-hero'),
      margin:const EdgeInsets.fromLTRB(12,5,12,10),
      padding:const EdgeInsets.all(13),
      decoration:BoxDecoration(
       color:const Color(0xFFFFF8EB),
       border:Border.all(color:const Color(0xFFE2BB72)),
       borderRadius:BorderRadius.circular(18)),
      child:Row(children:[
       Container(width:42,height:42,decoration:BoxDecoration(
        color:const Color(0xFFFFEBCD),borderRadius:BorderRadius.circular(13)),
        child:const Icon(Icons.fact_check_outlined,color:Color(0xFFB27B18))),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(widget.english?'Transactions awaiting review':'عمليات بانتظار مراجعتك',
         style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
        const SizedBox(height:3),
        Text(widget.english?
         count.toString()+' bank messages awaiting confirmation':
         count.toString()+' رسالة بنكية تنتظر التصنيف والتأكيد',
         style:const TextStyle(fontSize:11,color:Color(0xFF6A6A60))),
        const SizedBox(height:8),
        SizedBox(height:34,child:FilledButton.icon(
         key:const Key('m549-open-all-sms-review'),
         style:FilledButton.styleFrom(backgroundColor:green,
          padding:const EdgeInsets.symmetric(horizontal:8)),
         onPressed:count==0||busy?null:()=>run(widget.onReviewAll),
         icon:const Icon(Icons.arrow_forward_rounded,size:15),
         label:Text(widget.english?'Review transactions':'مراجعة العمليات',
          style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12)))),
       ])),
      ]),
     ),
     Expanded(child:shown.isEmpty?
      Center(child:Text(widget.english?'No notifications here':
       'لا توجد إشعارات في هذا القسم',
       style:const TextStyle(color:Color(0xFF708177)))):
      ListView.builder(
       key:const Key('m549-notification-list'),itemCount:shown.length,
       itemBuilder:(ctx,index)=>noticeTile(shown[index]),
      )),
    ]),
   ));
 }
}

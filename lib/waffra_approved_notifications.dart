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
  required this.onRescan,required this.canRescan,
 });
 final bool english;
 final List<WaffraReviewNotice> Function() readPending;
 // Retained for source compatibility with prior route callers.
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
   onSelected:(_)=>setState(()=>filter=key));
 }
 Widget noticeTile(WaffraReviewNotice notice){
  final kind=switch(notice.kind){
   'income'=>widget.english?'Income':'دخل',
   'expense'=>widget.english?'Expense':'مصروف',
   'transfer'=>widget.english?'Transfer':'تحويل',
   'excluded'=>widget.english?'Excluded • verification':'مستبعدة — رمز تحقق',
   _=>widget.english?'Needs review':'تحتاج مراجعة',
  };
  final color=notice.kind=='expense'?const Color(0xFFB94838):
   notice.kind=='excluded'?const Color(0xFF6A6A60):emerald;
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
     actions:[IconButton(
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
    ]),
   ));
 }
}

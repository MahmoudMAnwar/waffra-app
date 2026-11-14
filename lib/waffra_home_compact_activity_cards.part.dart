part of 'main.dart';

/// M790 / Issue #633: exact original compact activity cards and finance shortcut.
/// Same Dart library; source amounts, colors, receipts and routes unchanged.
extension _WaffraHomeCompactActivityCards on _HomeScreenState {
 Widget compactTransaction(MoneyEntry entry){
  final cat=categoryFor(entry.category,entry.income);
  final attachmentCount=waffraReceiptPaths(entry.receiptPath).length;
  // M650: paid recurring/goal-due rows are already persisted MoneyEntry
  // rows. Violet is a visual facet, never a new ledger debit.
  final paidDue=entry.sourceType=='recurring'||entry.sourceType=='goal_due';
  final darkMode=Theme.of(context).brightness==Brightness.dark;
  final valueColor=paidDue?(darkMode?const Color(0xFFD6BBFF):
   const Color(0xFF7653AA)):(entry.income?waffraIncomeTone(context):Colors.deepOrange);
  final rowColor=paidDue?(darkMode?const Color(0xFF302744):
   const Color(0xFFEFE9F8)):entry.income?
   (darkMode?const Color(0xFF244C3A):const Color(0xFFB2D5C2)):
   (darkMode?const Color(0xFF49302C):const Color(0xFFFCECE8));
  return Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Container(
   constraints:const BoxConstraints(minHeight:98),
   decoration:BoxDecoration(color:rowColor,borderRadius:BorderRadius.circular(17),
    border:Border.all(color:forest.withValues(alpha:darkMode ? 0.18 : 0.08))),
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:EdgeInsets.fromLTRB(10,attachmentCount>0?20:9,10,9),child:Row(children:[
     CircleAvatar(radius:16,
      backgroundColor:(entry.sourceType=='goal_due'?valueColor:Color(cat.color))
       .withValues(alpha:0.13),
      child:entry.sourceType=='goal_due'?
       Icon(Icons.flag_outlined,color:valueColor,size:21):
       WaffraIllustration(topic:cat.icon,size:36)),
     const SizedBox(width:8),
     Expanded(child:InkWell(onTap:WaffraHaptics.tap(()=>transactionDetails(entry)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       if(paidDue)WaffraText(waffraIsEnglish?'Paid due':'استحقاق مدفوع',
        style:TextStyle(fontSize:11,color:valueColor,fontWeight:FontWeight.w700)),
       Tooltip(message:entry.title,child:WaffraText(entry.title,maxLines:3,
        style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600))),
       if(entry.title.startsWith('معاملة بعملة تحتاج'))
        Padding(padding:const EdgeInsets.only(top:2,bottom:2),
         child:WaffraText(waffraIsEnglish?'Review source currency':
          'راجع عملة المعاملة قبل اعتماد قيمتها',
          maxLines:2,style:const TextStyle(
           fontSize:10,color:Colors.deepOrange,fontWeight:FontWeight.w600))),
       const SizedBox(height:2),
       WaffraText((entry.sourceType=='goal_due'?
        (waffraIsEnglish?'Savings goal due':'استحقاق هدف'):
        waffraTr(entry.category))+' • '+dayText(entry.date),
        maxLines:1,style:const TextStyle(fontSize:11,color:Colors.grey)),
        const SizedBox(height:2),
        if(!paidDue)Row(children:[
         Icon(entry.sourceType=='sms'?Icons.sms_outlined:
          Icons.edit_note_outlined,size:13,color:Colors.grey),
         const SizedBox(width:4),
         Expanded(child:WaffraText(
          WaffraTransactionDetailsDialog.sourceLabel(
           entry.sourceType,waffraIsEnglish),
          maxLines:1,style:const TextStyle(fontSize:11,color:Colors.grey))),
        ]),
        // A settled due is linked to the *verified* financial source,
        // not its mutable schedule title or sender label.
        if(paidDue&&_m468VerifiedAccountsLoaded)
         FutureBuilder<String?>(
          future:_m650DueVerifiedAccount(entry),
          builder:(ctx,snapshot){
           if(snapshot.connectionState!=ConnectionState.done){
            return const SizedBox.shrink();
           }
           if(entry.sourceType=='goal_due'){
            return Padding(padding:const EdgeInsets.only(top:5),
             child:Row(children:[
              Expanded(child:WaffraText(
               (waffraIsEnglish?'From money account: ':'من الحساب المالي: ')+
               (snapshot.data??(waffraIsEnglish?
                'Unverified account':'حساب غير محدد')),
               maxLines:2,style:TextStyle(color:valueColor,fontSize:11))),
              const SizedBox(width:5),
              Flexible(child:WaffraCurrencyAmount(
               waffraGoalDueCashMinor(entry)/100,fontSize:12,color:valueColor)),
             ]));
           }
           return Padding(padding:const EdgeInsets.only(top:4),
            child:WaffraText(
             (waffraIsEnglish?'Paid from: ':'تم السداد من: ')+
             (snapshot.data??(waffraIsEnglish?
              'Unverified account':'حساب غير محدد')),
             maxLines:2,style:TextStyle(
              color:valueColor,fontSize:11,fontWeight:FontWeight.w600)));
          }),
        if(entry.sourceType=='goal_due')
         Padding(padding:const EdgeInsets.only(top:3),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
           WaffraText(waffraIsEnglish?
            'From goal wallet: ':'من محفظة الهدف: ',
            style:TextStyle(color:valueColor,fontSize:11)),
           Flexible(child:WaffraCurrencyAmount(
            entry.goalWalletPaidMinor/100,fontSize:11,color:valueColor)),
          ])),
       const SizedBox(height:4),
       if(entry.sourceType=='goal_due')
        Row(children:[
         Expanded(child:WaffraText(waffraIsEnglish?
          'Total goal due':'إجمالي الاستحقاق',
          style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:valueColor))),
         WaffraText(waffraIsEnglish?'Amount':'المبلغ',
          style:TextStyle(fontSize:11,color:valueColor)),
         const SizedBox(width:5),
         Flexible(child:WaffraCurrencyAmount(
          entry.amount,fontSize:15,color:valueColor)),
        ])
       else Align(alignment:AlignmentDirectional.centerStart,
        child:Row(mainAxisSize:MainAxisSize.min,children:[
         WaffraText(waffraIsEnglish?'Amount':'المبلغ',style:TextStyle(color:valueColor,fontSize:11)),
         const SizedBox(width:5),
         WaffraCurrencyAmount(entry.income?entry.amount:-entry.amount,
          fontSize:15,color:valueColor),
        ])),
      ]))),
     const SizedBox(width:2),
     IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
      onPressed:WaffraHaptics.tap(()=>transactionActions(entry)),icon:const Icon(Icons.more_vert,size:18)),
    ])),
    if(attachmentCount>0)PositionedDirectional(top:0,start:0,
     child:WaffraReceiptCornerAction(
      key:Key('waffra-receipt-corner-home-'+entry.id),
      count:attachmentCount,english:waffraIsEnglish,
      onTap:()=>showReceipt(entry.receiptPath!,entryId:entry.id))),
   ])));
 }
 Widget _m549HomeFinanceAction({
  required String title,required IconData icon,
  required Color background,required Color iconColor,
  required VoidCallback onTap,
 })=>this._m684HomeFinanceAction(title:title,icon:icon,
  background:background,iconColor:iconColor,onTap:onTap);
 // M733: unchanged dashboard, forecast and financial analytics views moved to registered Home part.
 // M735: Home category workflows extracted unchanged to registered same-library part.
}

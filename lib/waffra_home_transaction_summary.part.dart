part of 'main.dart';

/// M810 / Issue #633: original filtered verified income/expense summary UI.
/// Same-library source relocation, zero finance writer modifications.
extension _WaffraHomeTransactionSummary on _HomeScreenState {
 Future<void> showSummaryTransactions(bool income)async {
  final items=_m467ScopedEntries().where((e)=>e.income==income).toList()
   ..sort((a,b)=>b.date.compareTo(a.date));
  if(items.isEmpty){
   if(!mounted)return;
   await showWaffraDialog<void>(context:context,builder:(ctx){
    final dark=Theme.of(ctx).brightness==Brightness.dark;
    final accent=income?emerald:const Color(0xFFE57373);
    return AlertDialog(
     backgroundColor:dark?const Color(0xFF171D1B):const Color(0xFFF9FDFB),
     shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
     contentPadding:const EdgeInsets.fromLTRB(22,25,22,10),
     content:Column(mainAxisSize:MainAxisSize.min,children:[
      CircleAvatar(radius:32,backgroundColor:accent.withValues(alpha:.12),
       child:Icon(income?Icons.account_balance_wallet_outlined:Icons.wallet_outlined,
        color:accent,size:32)),
      const SizedBox(height:16),
      WaffraText(waffraIsEnglish?'No transactions yet':'لا توجد معاملات حالية',
       textAlign:TextAlign.center,
       style:Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
      const SizedBox(height:10),
      WaffraText(income?
       (waffraIsEnglish?'No income transactions recorded yet. You can add a new income transaction.':'لا توجد عمليات دخل مسجلة حاليًا. يمكنك إضافة معاملة دخل جديدة.'):
       (waffraIsEnglish?'No expense transactions recorded yet. You can add a new expense transaction.':'لا توجد عمليات مصروف مسجلة حاليًا. يمكنك إضافة معاملة مصروف جديدة.'),
       textAlign:TextAlign.center),
      const SizedBox(height:18),
      SizedBox(width:double.infinity,child:FilledButton(
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
       child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))),
     ]),
    );
   });
   return;
  }
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,showDragHandle:true,
   useSafeArea:true,builder:(ctx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.58,minChildSize:.32,maxChildSize:.90,
    builder:(ctx,scroll)=>Column(children:[
     Padding(padding:const EdgeInsets.fromLTRB(18,4,18,12),
      child:Row(children:[
       Icon(income?Icons.trending_up:Icons.trending_down,
        color:income?waffraIncomeTone(context):Colors.deepOrange),
       const SizedBox(width:9),
       Expanded(child:WaffraText(income?
        (waffraIsEnglish?'Income transactions':'عمليات الدخل'):
        (waffraIsEnglish?'Expense transactions':'عمليات المصروفات'),
        style:Theme.of(ctx).textTheme.titleLarge)),
       IconButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),icon:const Icon(Icons.close)),
      ])),
     if(items.isNotEmpty)...[
      Container(
       margin:const EdgeInsets.symmetric(horizontal:16),
       padding:const EdgeInsets.all(16),width:double.infinity,
       decoration:BoxDecoration(color:(income?emerald:Colors.deepOrange).withValues(alpha:.10),
        borderRadius:BorderRadius.circular(18)),
       child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
         WaffraText(waffraIsEnglish?'Number of transactions':'عدد العمليات'),
         WaffraText(waffraIsEnglish?'${items.length} transactions':'${items.length} عملية',
          style:const TextStyle(fontWeight:FontWeight.bold)),
        ]),
        const Divider(height:22),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
         WaffraText(income?(waffraIsEnglish?'Total income':'إجمالي الدخل'):
          (waffraIsEnglish?'Total expenses':'إجمالي المصروفات')),
         Flexible(child:WaffraText(cash(sum(items,income)),
          textAlign:TextAlign.end,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),
        ]),
       ])),
      const SizedBox(height:10),
     ],
     Expanded(child:items.isEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(income?Icons.account_balance_wallet_outlined:Icons.receipt_long_outlined,
       size:66,color:emerald.withValues(alpha:.6)),
      const SizedBox(height:10),
      WaffraText(waffraIsEnglish?'No transactions yet':'لا توجد عمليات حتى الآن'),
     ])):ListView.separated(controller:scroll,padding:const EdgeInsets.fromLTRB(16,4,16,24),
      itemCount:items.length,separatorBuilder:(_,__)=>const Divider(height:1),
      itemBuilder:(_,index){
       final e=items[index],cat=categoryFor(e.category,e.income);
       return ListTile(
        leading:CircleAvatar(backgroundColor:Color(cat.color).withValues(alpha:.13),
         child:Icon(categoryIcon(cat.icon),color:Color(cat.color))),
        title:WaffraText(e.title,maxLines:2,overflow:TextOverflow.ellipsis),
        subtitle:WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(fontSize:12)),
        trailing:WaffraText(cash(e.amount),
         style:TextStyle(fontWeight:FontWeight.bold,color:income?waffraIncomeTone(context):Colors.deepOrange)));
      })),
    ])));
 }
 /// M611: read the actual owner-scoped encrypted transfer journal.
 /// A Home history tile cannot post any money.
}

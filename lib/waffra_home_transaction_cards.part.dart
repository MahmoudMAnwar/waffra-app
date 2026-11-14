part of 'main.dart';

/// M781 / Issue #633: original transaction details, cards and user action UI.
/// Render-only extraction, preserves all financial/attachment/goal route guards.
extension _WaffraHomeTransactionCards on _HomeScreenState {
 Widget stat(String label,double value,IconData icon,Color color)=>Expanded(
  child:Card(child:Padding(padding:const EdgeInsets.all(12),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(icon,color:color),const SizedBox(height:8),WaffraText(label),const SizedBox(height:6),
    FittedBox(child:RiyalAmount(value,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
   ]))));
 Future<void> transactionActions(MoneyEntry entry)async {
  final action=await showWaffraDialog<String>(context:context,builder:(ctx)=>AlertDialog(
   insetPadding:const EdgeInsets.symmetric(horizontal:26,vertical:24),
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24)),
   title:WaffraText(entry.title,maxLines:2,
    style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold),textAlign:TextAlign.center),
   content:SizedBox(width:340,child:Column(mainAxisSize:MainAxisSize.min,children:[
    GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
     crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.55,
     children:[
      _transactionActionTile(ctx,'open',Icons.open_in_new_rounded,
       waffraIsEnglish?'View details':'عرض التفاصيل',emerald),
      _transactionActionTile(ctx,'edit',Icons.edit_outlined,
       waffraIsEnglish?'Edit':'تعديل',emerald),
      _transactionActionTile(ctx,'delete',Icons.delete_outline_rounded,
       waffraIsEnglish?'Delete':'حذف',Colors.red),
      _transactionActionTile(ctx,'cancel',Icons.close_rounded,
       waffraIsEnglish?'Cancel':'إلغاء',Theme.of(ctx).colorScheme.onSurface),
     ]),

   ])),
  ));
  if(!mounted)return;
  switch(action){
   case 'open':await transactionDetails(entry);break;
   case 'edit':
    if(entry.sourceType=='goal_due'){
     await _m665ExplainLinkedGoalEdit(paid:true);
    }else{
     await entrySheet(initial:entry);
    }
    break;
   case 'delete':await deleteEntry(entry);break;
  }
 }
 Widget _transactionActionTile(BuildContext dialogContext,String value,
  IconData icon,String label,Color color)=>Material(
   color:color.withValues(alpha:.08),
   borderRadius:BorderRadius.circular(16),
   child:InkWell(
    borderRadius:BorderRadius.circular(16),
    onTap:WaffraHaptics.tap(()=>Navigator.pop(dialogContext,value)),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:6,vertical:10),
     child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:color,size:24),
      const SizedBox(height:6),
      Flexible(child:WaffraText(label,maxLines:2,textAlign:TextAlign.center,
       style:TextStyle(color:color,fontWeight:FontWeight.w600,fontSize:13))),
     ])),
   ),
  );
 Future<void> transactionDetails(MoneyEntry entry)async {
  // Only after confirming this ID is in the authoritative SMS ledger may
  // a full original message be loaded from its separate SQLCipher note vault.
  // The decrypted text remains in this dialog's memory, never preferences.
  String? originalBankSms;
  // Fetch on EVERY SMS detail open, including after user notes are edited.
  // The vault verifies the saved SMS ID and authorization independently.
  if(entry.sourceType=='sms'){
   try{
    originalBankSms=await _financeAuthority.readProtectedOriginalSms(entry.id);
   }catch(_){
    if(mounted)snack(context,waffraIsEnglish?
     'Encrypted bank message cannot be opened. Your transaction is unchanged.':
     'تعذر فتح الرسالة البنكية المشفّرة. بيانات المعاملة لم تتغير.');
    return;
   }
  }
  if(!mounted)return;
  await showWaffraDialog<void>(
   context:context,
   builder:(ctx)=>WaffraTransactionDetailsDialog(
    entry:entry,
    protectedOriginalSms:originalBankSms,
    linkedBudgetName:namedBudgets.where((b)=>b.id==entry.budgetId)
      .map((b)=>b.name).firstOrNull,
    linkedBudgetPaused:namedBudgets.any((b)=>b.id==entry.budgetId&&
      (!b.budgetActive||b.deleted)),
    showBudgetInfo:entry.budgetId!=null||waffraHasSelectableBudget(namedBudgets),
    onLinkBudget:entry.income||entry.budgetId!=null||
      !waffraHasSelectableBudget(namedBudgets)?null:(){
      Navigator.pop(ctx);
      unawaited(assignExistingExpenseToBudget(entry));
    },
    onClose:()=>Navigator.pop(ctx),
    onViewReceipt:waffraReceiptPaths(entry.receiptPath).isNotEmpty
      ?(){Navigator.pop(ctx);showReceipt(entry.receiptPath!,entryId:entry.id);}
      :null,
   ),
  );
 }

 Widget tile(MoneyEntry e){
  final c=categoryFor(e.category,e.income);
  // Restored M384 corner count uses persisted receipt references only.
  // Never migrate, move or modify existing receipt files during rendering.
  final attachmentCount=waffraReceiptPaths(e.receiptPath).length;
  return Card(color:e.income?waffraIncomeBackground:waffraExpenseBackground,
   clipBehavior:Clip.antiAlias,child:Stack(children:[
    Padding(padding:EdgeInsets.only(top:attachmentCount>0?16:0),child:ListTile(
   textColor:waffraInk,iconColor:forest,
   leading:CircleAvatar(backgroundColor:Color(c.color).withValues(alpha:.15),
      child:Icon(categoryIcon(c.icon),color:Color(c.color))),
   title:WaffraText(e.title,style:const TextStyle(color:waffraInk,fontWeight:FontWeight.w600)),subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
    WaffraText('${e.category} • ${dayText(e.date)}',style:const TextStyle(color:waffraInk)),
    WaffraText(WaffraTransactionDetailsDialog.sourceLabel(
     e.sourceType,waffraIsEnglish),
     style:const TextStyle(fontSize:11,color:waffraInk)),

   ]),
   trailing:Row(mainAxisSize:MainAxisSize.min,children:[
    Column(mainAxisSize:MainAxisSize.min,children:[
     FittedBox(fit:BoxFit.scaleDown,child:RiyalAmount(e.amount,
      prefix:e.income?'+':'-',style:TextStyle(fontFamily:'Tajawal',fontSize:18,
       fontWeight:FontWeight.w800,color:e.income?const Color(0xFF075C40):waffraInk))),
    ]),
    IconButton(tooltip:waffraIsEnglish?'Transaction options':'خيارات المعاملة',
     onPressed:WaffraHaptics.tap(()=>transactionActions(e)),icon:const Icon(Icons.more_vert,color:forest)),
   ]))),
    if(attachmentCount>0)PositionedDirectional(top:0,start:0,
     child:WaffraReceiptCornerAction(
      key:Key('waffra-receipt-corner-list-'+e.id),
      count:attachmentCount,english:waffraIsEnglish,
      onTap:()=>showReceipt(e.receiptPath!,entryId:e.id))),
   ]));
 }
 String get greeting=>WaffraSaudiGreetings.compose(
  name:widget.profile.name,gender:widget.profile.gender,
  english:waffraIsEnglish,greetingIndex:widget.greetingIndex,
  countryIso:WaffraRegionalCopy.countryIso.value);
}

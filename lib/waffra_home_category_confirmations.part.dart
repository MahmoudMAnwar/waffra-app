part of 'main.dart';

/// M906: exact original Home category, summaries and confirmation UI.
extension _WaffraHomeCategoryConfirmations on _HomeScreenState {
 double sum(Iterable<MoneyEntry> list,bool income)=>
  list.where((e)=>e.income==income).fold<int>(0,(v,e)=>v+WaffraRecurringPolicy.toHalalas(e.amount))/100;
 BudgetCategory categoryFor(String name,bool income) {
  for(final c in categories){if(c.name==name&&c.income==income)return c;}
  return BudgetCategory(id:'fallback',name:name,icon:'category',color:colors[7],income:income);
 }
 List<BudgetCategory> forType(bool income)=>categories.where((c)=>c.income==income).toList();
 // Manual entries may only select leaf categories; stored parent references
 // in older transactions remain unchanged until a user deliberately edits.
 List<BudgetCategory> forManualTransactionType(bool income)=>
  categories.where((c)=>c.income==income&&c.isSubcategory&&
   waffraCategoryAvailableForNewEntry(categories,c)).toList();
 // Used in NEW recurring selections. forType stays historical/complete.
 List<BudgetCategory> forSelectableType(bool income)=>
  forManualTransactionType(income);
 Future<bool?> confirm(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(title:WaffraText(title),content:WaffraText(body),
  actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),child:const WaffraText('إلغاء')),
   FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),child:const WaffraText('تأكيد'))]));
 Future<bool?> confirmDeletion(String title,String body)=>showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(title),content:WaffraText(body),
   actionsPadding:const EdgeInsets.fromLTRB(14,6,14,14),
   actions:[SizedBox(width:double.maxFinite,child:Row(children:[
    Expanded(child:OutlinedButton(
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',maxLines:2,
      textAlign:TextAlign.center))),
    const SizedBox(width:10),
    Expanded(child:FilledButton(
     style:FilledButton.styleFrom(backgroundColor:Colors.red),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
     child:WaffraText(waffraIsEnglish?'Confirm delete':'تأكيد الحذف',
      maxLines:2,textAlign:TextAlign.center))),
   ]))]));
}

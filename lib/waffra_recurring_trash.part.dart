part of 'main.dart';

extension WaffraRecurringRecycleBin on _HomeScreenState {
 String waffraRecurringDeleteWarning(String name,bool hasHistory,bool english) {
  return english
   ?'Move “$name” to Deleted Recurring for 30 days. ${hasHistory?'Completed transactions remain in your financial history. ':''}Restoring this schedule does not charge you; it stays paused until you set a new due date.'
   :'سيتم نقل «$name» إلى العمليات المتكررة المحذوفة لمدة 30 يومًا. ${hasHistory?'ستبقى المعاملات المالية السابقة محفوظة. ':''}عند الاسترجاع تعود الجدولة متوقفة حتى تحدد موعد استحقاق جديد.';
 }

 Future<void> deletedRecurringDialog()async{
  final now=DateTime.now();
  final expired=deletedRecurring.length;
  deletedRecurring.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!now.isBefore(when.add(const Duration(days:30)));
  });
  if(deletedRecurring.length!=expired)await persist();
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>
   StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Deleted recurring transactions':'العمليات المتكررة المحذوفة'),
    content:SizedBox(width:360,height:min(450.0,MediaQuery.sizeOf(ctx).height*.6),
     child:deletedRecurring.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted recurring transactions':'لا توجد عمليات متكررة محذوفة'))
      :ListView.builder(itemCount:deletedRecurring.length,itemBuilder:(ctx,index){
       final item=deletedRecurring[index];
       final original=RecurringBill.fromJson(Map<String,dynamic>.from(item['recurring'] as Map));
       final deletedAt=DateTime.tryParse('${item['deletedAt']??''}')??DateTime.now();
       final left=max(0,(deletedAt.add(const Duration(days:30))
         .difference(DateTime.now()).inHours/24).ceil());
       return ListTile(
        leading:const Icon(Icons.event_repeat_outlined,color:emerald),
        title:WaffraText(original.title,maxLines:2),
        subtitle:WaffraText(waffraIsEnglish?
         '$left days remaining • restores paused':
         'متبقي $left يوم • تسترجع متوقفة'),
        trailing:IconButton(
         tooltip:waffraIsEnglish?'Restore':'استرجاع',
         icon:const Icon(Icons.restore_rounded,color:emerald),
         onPressed:()async {
          if(recurring.any((r)=>r.id==original.id)){
           snack(ctx,waffraIsEnglish?'Recurring schedule already exists':'الجدولة موجودة بالفعل');
           return;
          }
          final ok=await showWaffraDialog<bool>(context:ctx,builder:(c)=>AlertDialog(
           title:WaffraText(waffraIsEnglish?'Restore recurring schedule?':'استرجاع العملية المتكررة؟'),
           content:WaffraText(waffraIsEnglish?
            'The restored schedule will be paused. Choose a future due date when reactivating. No past payments will be added.':
            'ستعود العملية متوقفة. عند تفعيلها اختر تاريخ الاستحقاق القادم؛ لن يتم تسجيل أي مدفوعات سابقة.'),
           actions:[
            TextButton(onPressed:()=>Navigator.pop(c,false),
             child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
            FilledButton(onPressed:()=>Navigator.pop(c,true),
             child:WaffraText(waffraIsEnglish?'Restore':'استرجاع')),
           ]));
          if(ok!=true||!mounted)return;
          setState((){
           recurring.add(original.copy(active:false,startAt:DateTime.now()));
           deletedRecurring.remove(item);
           recurringPostponed.removeWhere((key,value)=>
            key.startsWith('rec_${original.id}_'));
          });
          await persist();
          await syncRecurringReminders();
          if(ctx.mounted)refresh((){});
         },
        ),
       );
      })),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق')),
    ],
   )));
 }
}

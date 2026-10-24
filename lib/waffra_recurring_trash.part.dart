part of 'main.dart';

extension WaffraRecurringRecycleBin on _HomeScreenState {
 String waffraRecurringDeleteWarning(String name,bool hasHistory,bool english) {
  return english
   ?'Move “$name” to Deleted Recurring for 30 days. ${hasHistory?'Completed transactions remain in your financial history. ':''}Restoring this schedule does not charge you; it stays paused until you set a new due date.'
   :'سيتم نقل «$name» إلى العمليات المتكررة المحذوفة لمدة 30 يومًا. ${hasHistory?'ستبقى المعاملات المالية السابقة محفوظة. ':''}عند الاسترجاع تعود الجدولة متوقفة حتى تحدد موعد استحقاق جديد.';
 }

 Future<void> deletedRecurringDialog()async {
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _showVerifiedModuleTrash(WaffraFinanceModule.recurring);
   return;
  }
  final now=DateTime.now();
  final before=deletedRecurring.length;
  deletedRecurring.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!now.isBefore(when.add(const Duration(days:30)));
  });
  if(deletedRecurring.length!=before)await persist(route:WaffraFinanceRoute.recurringCreateEditDeleteRestore);
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>
   StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Deleted recurring transactions':'العمليات المتكررة المحذوفة'),
    content:SizedBox(
     width:double.maxFinite,
     height:waffraDeletedListHeight(ctx,deletedRecurring.length),
     child:deletedRecurring.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish
       ?'No deleted recurring transactions':'لا توجد عمليات متكررة محذوفة'))
      :ListView(children:deletedRecurring.map((item){
       final original=RecurringBill.fromJson(Map<String,dynamic>.from(item['recurring'] as Map));
       final deletedAt=DateTime.tryParse('${item['deletedAt']??''}')??DateTime.now();
       final left=max(0,(deletedAt.add(const Duration(days:30))
        .difference(DateTime.now()).inHours/24).ceil());
       return waffraDeletedItemCard(
        context:ctx,
        icon:Icons.event_repeat_outlined,
        iconColor:emerald,
        title:original.title,
        subtitle:waffraIsEnglish
         ?'Recurring transaction • $left days remaining'
         :'عملية متكررة • متبقي $left يوم',
        onRestore:()async {
         if(recurring.any((r)=>r.id==original.id)){
          snack(ctx,waffraIsEnglish?'Recurring schedule already exists':'الجدولة موجودة بالفعل');
          return;
         }
         final ok=await showWaffraDialog<bool>(context:ctx,builder:(confirmCtx)=>AlertDialog(
          title:WaffraText(waffraIsEnglish?'Restore recurring schedule?':'استرجاع العملية المتكررة؟'),
          content:WaffraText(waffraIsEnglish
           ?'Past linked transactions remain unchanged. The schedule is restored paused, with no new payments posted. Choose a new due date before reactivating.'
           :'ستبقى جميع المعاملات القديمة المرتبطة بها محفوظة. تعود الجدولة متوقفة دون تسجيل أي دفعة، ويجب تحديد تاريخ استحقاق جديد عند تفعيلها.'),
          actions:[
           TextButton(onPressed:()=>Navigator.pop(confirmCtx,false),
            child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
           FilledButton(onPressed:()=>Navigator.pop(confirmCtx,true),
            child:WaffraText(waffraIsEnglish?'Restore':'استرجاع')),
          ]));
         if(ok!=true||!mounted)return;
         setState((){
          // Keep the original configured amount, but NEVER post a payment
          // or reactivate a historical due date during restore.
          recurring.add(original.copy(active:false,startAt:DateTime.now()));
          deletedRecurring.remove(item);
          recurringPostponed.removeWhere((key,value)=>
           key.startsWith('rec_${original.id}_'));
         });
         await persist(route:WaffraFinanceRoute.recurringCreateEditDeleteRestore);
         await syncRecurringReminders();
         if(!ctx.mounted)return;
         Navigator.pop(ctx);
         if(mounted)snackSuccess(context,waffraIsEnglish
          ?'Recurring item restored paused. Previous transactions remain untouched, and no payment has been added. Choose a new due date to resume.'
          :'تم استرجاع العملية المتكررة متوقفة وبدون إضافة أي مبلغ جديد. معاملاتك القديمة محفوظة، وحدد تاريخ استحقاق جديدًا لإعادة التفعيل.');
        },
        onDeleteForever:()async {
         final yes=await confirmDeletion(
          waffraIsEnglish?'Permanently delete recurring item?':'حذف العملية المتكررة نهائيًا',
          waffraIsEnglish
           ?'Permanently delete “${original.title}”? You cannot restore this schedule. Past payments stay in your financial history.'
           :'هل تريد حذف «${original.title}» نهائيًا؟ لن يمكن استرجاع الجدولة، وستبقى المعاملات المالية السابقة محفوظة.');
         if(yes!=true||!mounted)return;
         setState(()=>deletedRecurring.remove(item));
         await persist(route:WaffraFinanceRoute.recurringCreateEditDeleteRestore);
         if(ctx.mounted)refresh((){});
        },
       );
      }).toList())),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
}

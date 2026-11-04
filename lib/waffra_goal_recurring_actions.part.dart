part of 'main.dart';

/// Goal progress is the sole source of truth. A linked schedule holds a goal ID,
/// NOT its own saved amount. Reaching the date alone never posts money;
/// payment requires explicit confirmation and a verified finance writer.
extension WaffraGoalRecurringActions on _HomeScreenState {
 /// Creating a financial due entry is optional and requires explicit consent.
 /// Declining preserves the goal, its due-date hint, and all saved money.
 Future<bool> _confirmGoalDueRecurringLink(SavingGoal goal)async{
  if(!mounted||goal.dueDate==null||goal.target<=0||!goal.active)return false;
  final choice=await showWaffraDialog<bool>(
   context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?
     'Create a linked recurring due date?':'ربط استحقاق الهدف بالعمليات المتكررة؟'),
    content:WaffraText(waffraIsEnglish?
     'This adds a reminder for ${goal.name} on ${dayText(goal.dueDate!)}. No money is deducted now.':
     'هيتم إضافة تذكير لاستحقاق «${goal.name}» بتاريخ ${dayText(goal.dueDate!)}، من غير خصم أي فلوس دلوقتي.'),
    actions:[
     TextButton(
      onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
      child:WaffraText(waffraIsEnglish?'Not now':'ليس الآن')),
     FilledButton(
      onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
      child:WaffraText(waffraIsEnglish?'Link due date':'ربط الاستحقاق')),
    ]));
  return choice==true;
 }
 Future<bool> _ensureLinkedRecurringForGoal(SavingGoal goal)async{
  final deadline=goal.dueDate;
  final linkedIndex=recurring.indexWhere((r)=>r.linkedGoalId==goal.id);
  if(deadline==null||goal.target<=0||!goal.active){
   if(linkedIndex<0)return true;
   setState(()=>recurring[linkedIndex]=recurring[linkedIndex].copy(active:false));
  }else{
   final available=categories.where((c)=>!c.income&&c.isSubcategory).toList();
   if(available.isEmpty){
    if(mounted)snack(context,waffraIsEnglish?
     'An expense subcategory is required for the linked recurring reminder.':
     'يلزم وجود قسم مصروف فرعي لإنشاء الاستحقاق المتكرر.');
    return false;
   }
   final rent=available.where((c)=>goal.name.contains('إيجار')&&
    c.name=='سكن / إيجار شهري').toList();
   final category=linkedIndex>=0?recurring[linkedIndex].category:
    (rent.isNotEmpty?rent.first.name:available.first.name);
   final next=linkedIndex>=0?recurring[linkedIndex].copy(
    amount:goal.target,day:deadline.day,startAt:deadline,
    active:goal.active):
    RecurringBill(id:newId(),title:'استحقاق '+goal.name,category:category,
     amount:goal.target,income:false,day:deadline.day,startAt:deadline,
     linkedGoalId:goal.id);
   setState((){
    if(linkedIndex>=0){recurring[linkedIndex]=next;}
    else{recurring.add(next);}
   });
  }
  if(!await _persistModuleOrReload(WaffraFinanceRoute.recurringCreateEditDeleteRestore,
    operation:'goal-recurring-link'))return false;
  await syncRecurringReminders();
  return true;
 }

 /// Pause/resume keeps the saved wallet intact and suspends linked due entries.
 Future<void> setGoalActive(SavingGoal original,bool enabled)async{
  if(!mounted)return;
  await _ensureFinanceBound();
  if(!mounted)return;
  final matches=goals.where((g)=>g.id==original.id).toList();
  if(matches.length!=1||matches.single.active==enabled)return;
  final current=matches.single;
  final updated=current.copy(active:enabled);
  setState((){
   final index=goals.indexWhere((g)=>g.id==current.id);
   if(index>=0)goals[index]=updated;
  });
  if(!await _persistModuleOrReload(
   WaffraFinanceRoute.goalCreateEditDeleteRestore,
   operation:'goal-active-toggle'))return;
  if(updated.dueDate!=null&&updated.target>0){
   final linked=await _ensureLinkedRecurringForGoal(updated);
   if(!linked&&mounted)snack(context,waffraIsEnglish?
    'Goal saved, but linked due date needs review.':
    'تم حفظ الهدف، لكن الاستحقاق المرتبط يحتاج مراجعة.');
  }
 }
 Future<void> editGoal(SavingGoal existing)async{
  final name=TextEditingController(text:existing.name);
  final target=TextEditingController(text:existing.target<=0?'':formatWaffraEditAmount(existing.target));
  bool noTarget=existing.target<=0;
  bool goalAlertsEnabled=existing.progressAlertsEnabled;
  int goalAlertPercent=existing.progressAlertPercent;
  DateTime? deadline=existing.dueDate;
  bool removeDeadline=false;
  String? nameError,amountError;
  try{
   final updated=await showWaffraDialog<SavingGoal>(
    context:context,builder:(dialog)=>StatefulBuilder(builder:(dialog,update)=>
     AlertDialog(
      title:WaffraText(waffraIsEnglish?'Edit savings goal':'تعديل الهدف'),
      scrollable:true,
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       TextField(controller:name,maxLength:100,
        onChanged:(_)=>update(()=>nameError=null),
        decoration:InputDecoration(labelText:waffraIsEnglish?'Goal name *':'اسم الهدف *',
         border:const OutlineInputBorder(),errorText:nameError)),
       const SizedBox(height:10),
       SwitchListTile.adaptive(
        contentPadding:EdgeInsets.zero,
        value:noTarget,activeTrackColor:emerald,
        title:WaffraText(waffraIsEnglish?'Open-ended savings':'ادخار مفتوح بدون مبلغ مستهدف'),
        onChanged:WaffraHaptics.selection((value)=>update(()=>noTarget=value))),
       if(!noTarget)TextField(controller:target,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
        onChanged:(_)=>update(()=>amountError=null),
        decoration:InputDecoration(labelText:waffraIsEnglish?'Target amount *':'المبلغ المستهدف *',
         errorText:amountError,border:const OutlineInputBorder())),
       if(!noTarget)waffraBudgetAlertControls(
        enabled:goalAlertsEnabled,percent:goalAlertPercent,
        english:waffraIsEnglish,goal:true,
        onEnabled:(value)=>update(()=>goalAlertsEnabled=value),
        onPercent:(value)=>update(()=>goalAlertPercent=value)),
       const SizedBox(height:12),
       OutlinedButton.icon(
        onPressed:WaffraHaptics.tap(()async{
         final picked=await waffraPickDateWithToday(english:waffraIsEnglish,
          context:dialog,initialDate:deadline!=null&&deadline!.isAfter(DateTime.now())?
           deadline!:DateTime.now().add(const Duration(days:1)),
          firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+10));
         if(picked!=null&&dialog.mounted)update((){
          deadline=picked;removeDeadline=false;
         });
        }),
        icon:const Icon(Icons.calendar_month_outlined),
        label:WaffraText(deadline==null||removeDeadline?
         (waffraIsEnglish?'Set due date':'تحديد موعد الاستحقاق'):
         dayText(deadline!))),
       if(deadline!=null&&!removeDeadline)TextButton(
        onPressed:WaffraHaptics.tap(()=>update(()=>removeDeadline=true)),
        child:WaffraText(waffraIsEnglish?
         'Remove date and pause linked recurring':
         'إلغاء الموعد وإيقاف الاستحقاق المتكرر')),
      ]),
      actions:[
       TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialog)),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
       FilledButton(onPressed:WaffraHaptics.tap((){
        final n=name.text.trim(),v=amountOfDisplay(target.text);
        update((){
         nameError=waffraGoalNameIssue(n,goals.where((g)=>g.id!=existing.id)
          .map((g)=>g.name))==null?null:
          (waffraIsEnglish?'Enter a unique goal name':'أدخل اسم هدف صحيحًا وغير مكرر');
         amountError=noTarget?null:waffraAmountFieldError(target.text);
        });
        if(nameError!=null||amountError!=null||(!noTarget&&(v==null||v<=0)))return;
        Navigator.pop(dialog,SavingGoal(id:existing.id,name:n,target:noTarget?0.0:v!,
         saved:existing.saved,dueDate:removeDeadline?null:deadline,
         active:existing.active,
         progressAlertsEnabled:!noTarget&&goalAlertsEnabled,
         progressAlertPercent:goalAlertPercent));
       }),child:WaffraText(waffraIsEnglish?'Save changes':'حفظ التعديل')),
      ],
     )));
   if(updated==null||!mounted)return;
   if(updated.progressAlertsEnabled&&!existing.progressAlertsEnabled){
    try{await WaffraReminders.requestPermission();}catch(_){/* In-app remains available. */}
   }
   if(!mounted)return;
   final oldLinked=recurring.any((r)=>r.linkedGoalId==existing.id);
   setState((){
    final i=goals.indexWhere((g)=>g.id==existing.id);
    if(i>=0)goals[i]=updated;
   });
   if(!await _persistModuleOrReload(WaffraFinanceRoute.goalCreateEditDeleteRestore,
     operation:'goal-edit'))return;
   if(oldLinked){
    await _ensureLinkedRecurringForGoal(updated);
   }else if(updated.dueDate!=null&&updated.target>0&&updated.active&&
     await _confirmGoalDueRecurringLink(updated)){
    await _ensureLinkedRecurringForGoal(updated);
   }
  }finally{disposeLater([name,target]);}
 }
}

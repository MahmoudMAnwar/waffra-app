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
 Future<bool> _saveGoalAndLinkedDueAtomically(
  SavingGoal updated,{required bool creating,required bool linkNew,
  required String operation})async{
  final i=goals.indexWhere((g)=>g.id==updated.id);
  if((creating&&i>=0)||(!creating&&i<0)){
   if(mounted)snack(context,waffraIsEnglish?
    'Goal changed; reload first.':'الهدف اتغير؛ حدّث البيانات.');
   return false;
  }
  // M641: an inline account creation refreshes the Home snapshot while an
  // edit dialog can still be open. Never overwrite a newer verified saving
  // contribution with the stale saved amount captured when the edit opened.
  if(!creating&&WaffraRecurringPolicy.toHalalas(goals[i].saved)!=
      WaffraRecurringPolicy.toHalalas(updated.saved)){
   if(mounted)snack(context,waffraIsEnglish?
    'Goal savings changed. Reopen the goal before editing.':
    'مبلغ الادخار اتغير أثناء التعديل. افتح الهدف من جديد قبل الحفظ.',
    isError:true);
   return false;
  }
  final linked=recurring.where((r)=>r.linkedGoalId==updated.id).toList();
  if(linked.length>1){
   if(mounted)snack(context,waffraIsEnglish?
    'Duplicate linked due dates need review.':'الاستحقاقات المرتبطة تحتاج مراجعة.');
   return false;
  }
  final date=updated.dueDate;
  RecurringBill? next;
  if(linked.isNotEmpty){
   final old=linked.single;
   final originalDue=DateTime(
    old.startAt.year,old.startAt.month,old.startAt.day);
   final settledKey=WaffraRecurringPolicy.entryId(old.id,originalDue);
   // A one-time goal due that was actually paid cannot be revived by
   // editing the goal's name, account or date. Reopening would generate
   // a fresh due ID on a new date and risk charging the same goal twice.
   final alreadySettled=entries.any((entry)=>
    entry.id==settledKey&&entry.sourceType=='goal_due');
   next=date==null||updated.target<=0||!updated.active||alreadySettled?
    old.copy(active:false,title:'استحقاق '+updated.name,
     accountId:updated.accountId):
    old.copy(title:'استحقاق '+updated.name,amount:updated.target,
     day:date.day,startAt:date,active:true,accountId:updated.accountId);
  }else if(linkNew){
   if(date==null||updated.target<=0||!updated.active)return false;
   final available=categories.where((c)=>!c.income&&c.isSubcategory&&
    waffraCategoryAvailableForNewEntry(categories,c)).toList();
   if(available.isEmpty){
    if(mounted)snack(context,waffraIsEnglish?
     'Add an active expense subcategory before linking the due date.':
     'أضف قسم مصروف فرعي مفعّل قبل ربط الاستحقاق.');
    return false;
   }
   final chosen=available.firstWhere(
    (c)=>updated.name.contains('إيجار')&&c.name=='سكن / إيجار شهري',
    orElse:()=>available.first);
   next=RecurringBill(id:newId(),title:'استحقاق '+updated.name,
    category:chosen.name,amount:updated.target,income:false,
    day:date.day,startAt:date,linkedGoalId:updated.id,
    accountId:updated.accountId);
  }
  // Mutate both in-memory collections before the ONE source-aware save.
  // The SQLCipher projection and snapshot commit succeed or roll back together.
  setState((){
   if(creating){goals.add(updated);}else{goals[i]=updated;}
   if(next!=null){
    final j=recurring.indexWhere((r)=>r.linkedGoalId==updated.id);
    if(j<0){recurring.add(next!);}else{recurring[j]=next!;}
   }
  });
  final saved=await _persistModuleOrReload(
   WaffraFinanceRoute.goalCreateEditDeleteRestore,operation:operation);
  if(saved&&next!=null)await syncRecurringReminders();
  return saved;
 }

 /// Pause/resume edits its linked schedule in the same transaction.
 Future<void> setGoalActive(SavingGoal original,bool enabled)async{
  if(!mounted)return;
  await _ensureFinanceBound();
  if(!mounted)return;
  final found=goals.where((g)=>g.id==original.id).toList();
  if(found.length!=1||found.single.active==enabled)return;
  await _saveGoalAndLinkedDueAtomically(found.single.copy(active:enabled),
   creating:false,linkNew:false,operation:'goal-active-and-due');
 }
 Future<void> editGoal(SavingGoal existing)async{
  final verifiedAccountOptions=await _m641VerifiedGoalRecurringAccounts();
  if(verifiedAccountOptions==null||!mounted)return;
  List<WaffraAccountBalance> accountOptions=verifiedAccountOptions;
  String? linkedAccount=existing.accountId;
  if(!accountOptions.any((a)=>a.id==linkedAccount&&!a.archived)){
   linkedAccount=null; // Legacy goals must be linked by explicit choice.
  }
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
       WaffraGoalRecurringAccountPicker(
        key:const Key('m641-edit-goal-account-cascade'),
        idPrefix:'m641-edit-goal',english:waffraIsEnglish,
        accounts:accountOptions,selectedAccountId:linkedAccount,
        onChanged:(id)=>update(()=>linkedAccount=id),
        onError:(message)=>snack(context,message),
        onCreateAccount:(provider)async{
         final created=await _m641CreateGoalRecurringAccount(provider);
         if(created!=null)accountOptions=[...accountOptions,created];
         return created;
        }),
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
        if(linkedAccount==null||!accountOptions.any(
          (a)=>a.id==linkedAccount&&!a.archived)){
         snack(dialog,waffraIsEnglish?
          'Select a verified money account.':
          'اختر حسابًا ماليًا تابعًا موثّقًا.');
         return;
        }
        Navigator.pop(dialog,SavingGoal(id:existing.id,name:n,target:noTarget?0.0:v!,
         saved:existing.saved,dueDate:removeDeadline?null:deadline,
         active:existing.active,accountId:linkedAccount,
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
   final wasLinked=recurring.any((r)=>r.linkedGoalId==existing.id);
   final linkNew=!wasLinked&&updated.dueDate!=null&&updated.target>0&&
    updated.active&&await _confirmGoalDueRecurringLink(updated);
   await _saveGoalAndLinkedDueAtomically(updated,
    creating:false,linkNew:linkNew,operation:'goal-edit-and-due');
  }finally{disposeLater([name,target]);}
 }
}

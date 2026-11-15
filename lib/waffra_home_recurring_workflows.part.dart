part of 'main.dart';

/// M944 #653: original recurring editor, schedule and linked-goal actions.
/// Same library + verified finance writer; no behavior or widget changes.
extension _WaffraHomeRecurringWorkflows on _HomeScreenState {
 Future<void> recurringDialog({String? suggestedTitle,double? suggestedAmount,RecurringBill? initial,RecurringBill? duplicate})async {
  // Linked schedules are projections of a goal; never open a second editor.
  if(initial?.linkedGoalId!=null){
   await _m665ExplainLinkedGoalEdit();
   return;
  }
  // M641: the editor opens even on a fresh install with ZERO accounts.
  // Account selection remains mandatory at SAVE, not before opening.
  final verifiedRecurringAccounts=await _m641VerifiedGoalRecurringAccounts();
  if(verifiedRecurringAccounts==null||!mounted)return;
  List<WaffraAccountBalance> liveAccounts=verifiedRecurringAccounts;
  String? selectedRecurringAccount=initial?.accountId??duplicate?.accountId;
  if(initial!=null){
   try{
    final bridge=_financeBinding?.accountsBridge;
    if(bridge!=null){
     selectedRecurringAccount=
      await WaffraVerifiedAccountsApi(bridge:bridge)
       .recurringDefaultAccount(initial.id)??selectedRecurringAccount;
    }
   }catch(error){
    debugPrint('M641 recurring default read failed: '+error.runtimeType.toString());
   }
  }
  // A goal-linked due gets its identity ONLY from its parent goal.
  // Change the account in Goals, where both records commit atomically.
  if(initial?.linkedGoalId!=null){
   final linked=goals.where((g)=>g.id==initial!.linkedGoalId).toList();
   if(linked.length!=1){
    if(mounted)snack(context,waffraIsEnglish?
     'Linked goal unavailable; edit the goal before this due.':
     'الهدف المرتبط غير متاح. راجع الهدف قبل تعديل الاستحقاق.',
     isError:true);
    return;
   }
   selectedRecurringAccount=linked.single.accountId;
  }
  if(!liveAccounts.any((a)=>a.id==selectedRecurringAccount&&!a.archived)){
   selectedRecurringAccount=null;
  }
  final title=TextEditingController(text:initial?.title??duplicate?.title??suggestedTitle??''),
   amount=TextEditingController(text:initial!=null?formatWaffraEditAmount(initial.amount):duplicate!=null?formatWaffraEditAmount(duplicate.amount):suggestedAmount==null?'':formatWaffraEditAmount(suggestedAmount)),
   day=TextEditingController(text:(initial?.day??duplicate?.day??1).toString());
  bool income=initial?.income??duplicate?.income??false;String category=initial?.category??duplicate?.category??(forSelectableType(false).isNotEmpty?
    forSelectableType(false).first.name:'');bool attempted=false;
  DateTime startAt=initial?.startAt??(duplicate!=null&&duplicate.startAt.isAfter(DateTime.now())?duplicate.startAt:DateTime.now());
  final r=await showWaffraDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forSelectableType(income);
    // An old recurring schedule may refer to a now-paused category.
    // Editing its title/date must not silently reassign it to another leaf.
    // New or duplicated schedules must explicitly select an active leaf.
    final historicalSelected=initial!=null&&initial.income==income&&
     initial.category==category;
    final selected=options.any((x)=>x.name==category)||historicalSelected
     ?category:'';
    final validNames=[
     ...options.map((c)=>c.name),
     if(historicalSelected)initial.category,
    ];
    return AlertDialog(title:WaffraText(initial==null?(waffraIsEnglish?'New due item':'استحقاق جديد'):(waffraIsEnglish?'Edit due item':'تعديل الاستحقاق')),
     content:SizedBox(width:340,child:SingleChildScrollView(
      padding:const EdgeInsetsDirectional.only(end:18),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'الوصف *',
       errorText:attempted?waffraTextFieldError(title.text):null)),
      if(initial?.linkedGoalId!=null)WaffraText(waffraIsEnglish?
       'Edit target and due date from the linked goal in Goals.':
       'تعديل المبلغ والاستحقاق يكون من الهدف المرتبط في الأهداف.',
       style:const TextStyle(fontSize:12,color:emerald)),
      const SizedBox(height:12),
      TextField(controller:amount,readOnly:initial?.linkedGoalId!=null,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(amount.text):null)),
      const SizedBox(height:12),
      if(initial?.linkedGoalId!=null)
       InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Goal account (edit in Goals)':
          'حساب الهدف (التعديل من الأهداف)',
         border:const OutlineInputBorder()),
        child:WaffraText(
         selectedRecurringAccount==null?
          (waffraIsEnglish?'Set account in linked goal first':
           'اختر حساب الهدف من صفحة الأهداف أولًا'):
          liveAccounts.where((a)=>a.id==selectedRecurringAccount)
           .map((a)=>a.name).firstOrNull??
           (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'),
         maxLines:2),
       )
      else WaffraGoalRecurringAccountPicker(
       key:const Key('m641-recurring-account-cascade'),
       idPrefix:'m641-recurring',english:waffraIsEnglish,
       accounts:liveAccounts,selectedAccountId:selectedRecurringAccount,
       onChanged:(id)=>update(()=>selectedRecurringAccount=id),
       onError:(message)=>snack(context,message),
       onCreateAccount:(provider)async{
        final added=await _m641CreateGoalRecurringAccount(provider);
        if(added!=null)liveAccounts=[...liveAccounts,added];
        return added;
       }),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:initial?.linkedGoalId!=null?null:WaffraHaptics.selection((v){if(v!=null)update((){
         income=v;category=forSelectableType(v).isNotEmpty?forSelectableType(v).first.name:'';
        });})),
      const SizedBox(height:12),
      InkWell(
       borderRadius:BorderRadius.circular(14),
       onTap:WaffraHaptics.tap(()async{
        final picked=await showWaffraDialog<String>(context:ctx,
         builder:(searchCtx){
          String query='';
          return StatefulBuilder(builder:(searchCtx,refresh){
           final filtered=options.where((c)=>
            waffraSearchAny([c.name,waffraTr(c.name)],query)).toList();
           return AlertDialog(
            title:WaffraText(waffraIsEnglish?'Search categories':'البحث عن قسم'),
            content:SizedBox(
             width:double.maxFinite,
             height:min(430.0,MediaQuery.sizeOf(searchCtx).height*.58),
             child:Column(children:[
              TextField(
               autofocus:true,
               onChanged:(value)=>refresh(()=>query=value),
               decoration:InputDecoration(
                prefixIcon:const Icon(Icons.search_rounded),
                hintText:waffraIsEnglish?'Type a category name…':'اكتب اسم القسم للبحث…',
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
              ),
              const SizedBox(height:10),
              Expanded(child:filtered.isEmpty
               ?Center(child:WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'))
               :ListView.builder(
                itemCount:filtered.length,
                itemBuilder:(searchCtx,index){
                 final option=filtered[index];
                 return ListTile(
                  dense:true,
                  selected:option.name==selected,
                  leading:Icon(categoryIcon(option.icon),color:Color(option.color),size:21),
                  title:WaffraText(option.name,maxLines:3),
                  onTap:WaffraHaptics.tap(()=>Navigator.pop(searchCtx,option.name)));
                })),
             ]),
            ),
           );
          });
         });
        if(picked!=null&&ctx.mounted)update(()=>category=picked);
       }),
       child:InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Category *':'القسم *',
         errorText:attempted&&WaffraValidators.requiredCategory(
          selected,validNames)!=null?waffraRequiredFieldMessage:null,
         suffixIcon:const Icon(Icons.search_rounded),
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
         contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:15)),
        child:Row(children:[
         Expanded(child:WaffraText(selected.isEmpty?
          (waffraIsEnglish?'Choose a category':'اختر قسمًا'):selected,maxLines:2,
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600))),
         const SizedBox(width:8),
         const Icon(Icons.arrow_drop_down_rounded,size:20),
        ]),
       ),
      ),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:initial?.linkedGoalId!=null?null:WaffraHaptics.tap(()async{
       final picked=await waffraPickDateWithToday(english:waffraIsEnglish,context:ctx,initialDate:startAt.isBefore(DateTime.now())?
         DateTime.now():startAt,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime(DateTime.now().year+5));
       if(picked!=null)update((){startAt=picked;day.text=picked.day.toString();});
      }),icon:const Icon(Icons.calendar_month_outlined),label:WaffraText(waffraIsEnglish?'First due: ${dayText(startAt)}':'أول استحقاق: ${dayText(startAt)}')),
      const SizedBox(height:8),
      TextField(controller:day,readOnly:initial?.linkedGoalId!=null,keyboardType:TextInputType.number,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Day of month *':'يوم الشهر *',helperText:waffraIsEnglish?'1–31':'من 1 إلى 31',
       errorText:attempted?waffraDayFieldError(day.text):null)),
     ]))),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final n=amountOfDisplay(amount.text),d=int.tryParse(digits(day.text));update(()=>attempted=true);
       if(WaffraValidators.requiredText(title.text)==null&&
        WaffraValidators.positiveAmount(amount.text)==null&&
        WaffraValidators.dayOfMonth(day.text)==null&&
        WaffraValidators.requiredCategory(selected,validNames)==null&&
        selectedRecurringAccount!=null&&
        liveAccounts.any((a)=>a.id==selectedRecurringAccount&&!a.archived)&&
        n!=null&&d!=null){
        Navigator.pop(ctx,RecurringBill(id:initial?.id??newId(),title:title.text.trim(),category:selected,
         amount:initial?.linkedGoalId!=null?initial!.amount:n,income:income,
         day:initial?.linkedGoalId!=null?initial!.day:d,
         startAt:initial?.linkedGoalId!=null?initial!.startAt:startAt,
         active:initial?.active??duplicate?.active??true,linkedGoalId:initial?.linkedGoalId,
         accountId:selectedRecurringAccount));
       }
      }),child:const WaffraText('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState((){
    if(initial==null){recurring.add(r);}else{
     final index=recurring.indexWhere((e)=>e.id==initial.id);
     if(index>=0)recurring[index]=r;
    }
   });
   if(!await _persistModuleOrReload(WaffraFinanceRoute.recurringCreateEditDeleteRestore,
     operation:initial==null?'recurring-create':'recurring-edit'))return;
   await applyRecurring();
   await syncRecurringReminders();
  }
 }
 DateTime nextRecurringDue(RecurringBill r,{Set<String>? paidEntryIds}) {
  if(r.linkedGoalId!=null){
   final once=DateTime(r.startAt.year,r.startAt.month,r.startAt.day);
   final stableId=WaffraRecurringPolicy.entryId(r.id,once);
   final postponed=DateTime.tryParse(recurringPostponed[stableId]??'');
   return postponed!=null&&postponed.isAfter(once)?postponed:once;
  }
  final today=DateTime.now();
  final monthlyDue=WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
  final monthId=WaffraRecurringPolicy.entryId(r.id,monthlyDue);
  return WaffraRecurringPolicy.nextActionableDue(
   today:today,startAt:r.startAt,day:r.day,
   currentMonthPaid:paidEntryIds?.contains(monthId)??
    entries.any((entry)=>entry.id==monthId),
   postponedUntil:DateTime.tryParse(recurringPostponed[monthId]??''));
 }
 Future<void> _setRecurringActiveFromCard(RecurringBill r,bool enabled)async{
  // The linked schedule is a projection of its goal. Changing it here
  // would bypass the goal's atomic target/date/account and paid replay guard.
  if(r.linkedGoalId!=null){
   await _m665ExplainLinkedGoalEdit();
   return;
  }
       final index=recurring.indexWhere((item)=>item.id==r.id);
       if(index<0)return;
       if(enabled){
        final chosen=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:DateTime.now().add(const Duration(days:1)),
         firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+5));
        if(chosen==null||!mounted)return;
        setState(()=>recurring[index]=r.copy(active:true,startAt:chosen,day:chosen.day));
       }else{
        setState(()=>recurring[index]=r.copy(active:false));
       }
       if(!await _persistModuleOrReload(
        WaffraFinanceRoute.recurringCreateEditDeleteRestore,
        operation:'recurring-active-toggle'))return;
       if(enabled)await applyRecurring();
       await syncRecurringReminders();

 }
 Future<void> _m665ExplainLinkedGoalEdit({bool paid=false})async{
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,
   builder:(dialog)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?
     'Edit the linked goal first':'عدّل الهدف المرتبط أولًا'),
    content:WaffraText(paid?
     (waffraIsEnglish?
      'This is an already paid goal settlement. Its saved wallet and bank debit cannot be edited as an ordinary transaction. Change goal settings in Goals; this does not rewrite a paid receipt.':
      'ده استحقاق هدف مدفوع ومحفوظ. لا يمكن تعديل مبلغ محفظة الهدف أو خصم الحساب كعملية عادية. عدّل بيانات الهدف من صفحة الأهداف، بدون تغيير سجل الدفع السابق.'):
     (waffraIsEnglish?
      'This due date belongs to a savings goal. Edit the goal in Goals first; the linked due will follow that change automatically.':
      'الاستحقاق ده مربوط بهدف ادخاري. عدّل الهدف من صفحة الأهداف أولًا، والتعديل هينعكس على الاستحقاق المرتبط تلقائيًا.')),
    actions:[TextButton(
     onPressed:()=>Navigator.pop(dialog),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
 }
 Future<void> _handleRecurringCardAction(RecurringBill r,String v)async{
       if(v=='edit'){
        if(r.linkedGoalId!=null){
         await _m665ExplainLinkedGoalEdit();
         return;
        }
        await recurringDialog(initial:r);
        return;
       }
       if(v!='delete')return;
       final hasHistory=entries.any((e)=>e.id.startsWith('rec_${r.id}_'));
       final ok=await confirmDeletion(waffraIsEnglish?'Delete due item?':'حذف الاستحقاق',
        waffraRecurringDeleteWarning(r.title,hasHistory,waffraIsEnglish));
       if(ok==true&&mounted){
        if(_lastFinanceAuthorityRead?.source==
           WaffraRuntimeFinanceBackend.verifiedEncrypted){
         await _deleteVerifiedModule(
          module:WaffraFinanceModule.recurring,displayed:r.toJson());
         return;
        }
        setState((){
         deletedRecurring.add({'recurring':r.toJson(),'deletedAt':DateTime.now().toIso8601String()});
         recurring.removeWhere((e)=>e.id==r.id);
         recurringPostponed.removeWhere((key,value)=>key.startsWith('rec_${r.id}_'));
        });
        if(!await _persistModuleOrReload(
         WaffraFinanceRoute.recurringCreateEditDeleteRestore,
         operation:'recurring-delete'))return;
        await syncRecurringReminders();
       }

 }
}

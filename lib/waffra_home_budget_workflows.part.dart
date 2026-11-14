part of 'main.dart';

/// M715 / #633: original budget editor, historical links, and budget
/// activation/dialog logic extracted verbatim into same-library extension.
/// Ledger writers, imported transactions, and balance sources unchanged.
extension _WaffraHomeBudgetWorkflows on _HomeScreenState {
 Future<void> editMonthlyBudget()async {
  final amount=TextEditingController(text:monthlyBudget>0?formatWaffraEditAmount(monthlyBudget):'');
  bool enabled=monthlyBudgetEnabled;
  String? validation;
  try{
   final next=await showWaffraDialog<({bool enabled,double amount})>(
    context:context,builder:(ctx)=>BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:7,sigmaY:7),child:StatefulBuilder(builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Monthly budget':'الميزانية الشهرية'),
     content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      SwitchListTile.adaptive(
       contentPadding:EdgeInsets.zero,
       title:WaffraText(waffraIsEnglish?'Enable monthly budget':'تفعيل الميزانية الشهرية',
        style:const TextStyle(fontWeight:FontWeight.bold)),
       value:enabled,activeTrackColor:emerald,
       onChanged:WaffraHaptics.selection((value)=>update((){enabled=value;validation=null;})),
      ),
      const SizedBox(height:8),
      WaffraText(enabled?
       (waffraIsEnglish?'Set the amount allocated for monthly spending.':'حدد المبلغ الذي ترغب في تخصيصه لمصروفاتك الشهرية.'):
       (waffraIsEnglish?'Monthly spending limit tracking is paused.':'تم إيقاف متابعة حد المصروفات الشهرية.')),
      const SizedBox(height:16),
      TextField(controller:amount,autofocus:false,
       onChanged:(_){if(validation!=null)update(()=>validation=null);},
       style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Theme.of(ctx).colorScheme.onSurface),
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:(waffraIsEnglish?'Spending limit':'حد المصروفات')+' ('+WaffraDisplayCurrency.label(waffraIsEnglish)+') *',
        hintText:waffraIsEnglish?'Example: 3000':'مثال: 3000',
        errorText:validation,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
        filled:true,fillColor:Theme.of(ctx).brightness==Brightness.dark?
         const Color(0xFF1E3A31):Colors.white)),
     ]),
     actionsPadding:const EdgeInsets.fromLTRB(16,4,16,14),
     actions:[SizedBox(width:double.maxFinite,child:Row(children:[
      Expanded(child:OutlinedButton(
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',maxLines:1))),
      const SizedBox(width:12),
      Expanded(child:FilledButton(onPressed:WaffraHaptics.tap((){
       final v=amountOfDisplay(amount.text);
       final fieldError=waffraMonthlyBudgetSaveError(amount.text);
       if(fieldError!=null||v==null||!v.isFinite||v<=0){
        update(()=>validation=fieldError??(waffraIsEnglish?
         'Enter an amount greater than zero':'أدخل مبلغًا صحيحًا أكبر من صفر'));
        return;
       }
       Navigator.pop(ctx,(enabled:enabled,amount:v));
      }),child:WaffraText(waffraIsEnglish?'Save':'حفظ',maxLines:1))),
     ]))],
    ))));
   if(next!=null&&mounted){
    setState((){monthlyBudgetEnabled=next.enabled;monthlyBudget=next.amount;});
    if(!await _persistModuleOrReload(
     WaffraFinanceRoute.challengeAndBudgetUpdate,
     operation:'monthly-budget-save'))return;
    if(mounted)snackSuccess(context,waffraIsEnglish?'Monthly budget settings saved':'تم حفظ إعدادات الميزانية الشهرية');
   }
  }finally{disposeLater([amount]);}
 }
 Future<void> editTransactionFilters()async {
  final min=TextEditingController(text:minTransactionAmount==null?'':formatWaffraEditAmount(minTransactionAmount!));
  final max=TextEditingController(text:maxTransactionAmount==null?'':formatWaffraEditAmount(maxTransactionAmount!));
  String? minError,maxError;
  DateTimeRange? chosen=transactionsDateRange;
  try{
   await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(
    builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Advanced filters':'فلترة بالتاريخ والمبلغ'),
     content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:min,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>minError=null),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Minimum amount':'أقل مبلغ',
        errorText:minError,
        border:const OutlineInputBorder())),
      const SizedBox(height:10),
      TextField(controller:max,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       onChanged:(_)=>update(()=>maxError=null),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Maximum amount':'أعلى مبلغ',
        errorText:maxError,
        border:const OutlineInputBorder())),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
       final range=await showDateRangePicker(context:ctx,
        firstDate:DateTime(2000),lastDate:DateTime.now(),
        initialDateRange:chosen);
       if(range!=null)update(()=>chosen=range);
      }),icon:const Icon(Icons.date_range),
       label:WaffraText(chosen==null
        ?(waffraIsEnglish?'Choose date range':'حدد فترة زمنية')
        :dayText(chosen!.start)+' - '+dayText(chosen!.end))),
     ])),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap((){
       setState((){
        transactionsDateRange=null;minTransactionAmount=null;maxTransactionAmount=null;
       });
       Navigator.pop(ctx);
      }),child:WaffraText(waffraIsEnglish?'Clear':'مسح الفلاتر')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final lo=min.text.trim().isEmpty?null:amountOfDisplay(min.text.trim());
       final hi=max.text.trim().isEmpty?null:amountOfDisplay(max.text.trim());
       if((min.text.trim().isNotEmpty&&lo==null)||
          (max.text.trim().isNotEmpty&&hi==null)||
          (lo!=null&&(!lo.isFinite||lo<0))||
          (hi!=null&&(!hi.isFinite||hi<0))||
          (lo!=null&&hi!=null&&lo>hi)){
        update((){
         minError=min.text.trim().isNotEmpty&&(lo==null||!lo.isFinite||lo<0)?(waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا'):null;
         maxError=max.text.trim().isNotEmpty&&(hi==null||!hi.isFinite||hi<0)?(waffraIsEnglish?'Enter a valid amount':'أدخل مبلغًا صحيحًا'):null;
         if(lo!=null&&hi!=null&&lo>hi)maxError=waffraIsEnglish?'Maximum must not be less than minimum':'الحد الأعلى يجب ألا يقل عن الحد الأدنى';
        });
        return;
       }
       setState((){
        transactionsDateRange=chosen;minTransactionAmount=lo;maxTransactionAmount=hi;
       });
       Navigator.pop(ctx);
      }),child:WaffraText(waffraIsEnglish?'Apply':'تطبيق')),
     ])));
  }finally{disposeLater([min,max]);}
 }
 /// Edit only budget fields; the category name and transaction history must
 /// never be mutated by the budget editor.
 /// Ask before assigning historical unbudgeted purchases.
 /// Never infer a historic budget link from the transaction category.
 Future<void> offerHistoricBudgetLink(BudgetCategory budget)async{
  if(!mounted||budget.budget<=0||!budget.budgetActive)return;
  if(entries.any((e)=>!e.income&&e.budgetId==null)){
   snack(context,waffraIsEnglish?
    'Older unassigned expenses may be linked individually under My Budgets.':
    'في عمليات قديمة غير مرتبطة؛ تقدر تراجعها وتربطها يدويًا من ميزانياتي.',
    isError:false);
  }
 }

 /// User-approved historic linking. This does NOT invent a ledger entry.
 Future<void> reviewUnlinkedHistoricalExpenses()async{
  if(!mounted)return;
  final pending=entries.where((e)=>!e.income&&e.budgetId==null)
   .toList(growable:false);
  if(pending.isEmpty){
   snack(context,waffraIsEnglish?'No unassigned expenses.':
    'ما فيه مصروفات غير مرتبطة تحتاج مراجعة.');
   return;
  }
  String entryQuery='';
  final old=await showWaffraDialog<MoneyEntry>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
    final visible=pending.where((e)=>waffraSearchAny(
     [e.title,e.category,e.notes,cash(e.amount),dayText(e.date)],
      entryQuery)).toList(growable:false);
    return AlertDialog(
    title:WaffraText(waffraIsEnglish?'Review saved expenses':
     'مراجعة المصروفات القديمة غير المرتبطة'),
    content:SizedBox(width:430,height:370,child:Column(children:[
     WaffraText(waffraIsEnglish?
      pending.length.toString()+' saved expense(s) need optional budget review.':
      'عندك '+pending.length.toString()+' عملية مصروف محفوظة بدون ميزانية. '
      'الربط اختياري ومش هنغيّر المبالغ ولا التواريخ.',
      style:const TextStyle(fontSize:13)),
     const SizedBox(height:9),
     TextField(
      key:const Key('waffra-historical-expense-search'),
      onChanged:(text)=>refresh(()=>entryQuery=text),
      decoration:InputDecoration(
       prefixIcon:const Icon(Icons.search_rounded),
       hintText:waffraIsEnglish?'Search saved expenses':'ابحث في العمليات المحفوظة',
       border:const OutlineInputBorder())),
     const SizedBox(height:8),
     Expanded(child:visible.isEmpty?
      Center(child:WaffraText(waffraIsEnglish?
       'No matching expenses':'ما فيه عمليات مطابقة')):
      ListView.builder(itemCount:visible.length,
      itemBuilder:(_,i){
       final item=visible[i];
       return ListTile(
        key:Key('waffra-retro-unlinked-'+item.id),
        dense:true,title:WaffraText(item.title,maxLines:1),
        subtitle:WaffraText(item.category,maxLines:1),
        trailing:WaffraText(cash(item.amount)),
        onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,item)),
       );
      })),
    ])),
    actions:[TextButton(
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
     child:WaffraText(waffraIsEnglish?'Not now':'مش دلوقتي'))]);
   }));
  if(old==null||!mounted)return;
  await assignExistingExpenseToBudget(old);
 }

 Future<void> assignExistingExpenseToBudget(MoneyEntry old)async{
  if(!mounted)return;
  final original=entries.where((e)=>e.id==old.id).toList(growable:false);
  if(original.length!=1||original.single.income||
     original.single.budgetId!=null){
   snack(context,waffraIsEnglish?'Refresh before reviewing this record.':
    'العملية اتغيرت أو معرفها مكرر. حدّث الصفحة قبل المراجعة.');
   return;
  }
  final budgets=namedBudgets.where((b)=>b.budget>0&&b.budgetActive&&!b.deleted)
   .toList(growable:false);
  if(budgets.isEmpty){
   snack(context,waffraIsEnglish?'Create a budget first.':
    'ضيف ميزانية الأول، وبعدها اربط العملية لو حابب.');
   return;
  }
  String budgetQuery='';
  final selected=await showWaffraDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
    final visible=budgets.where((b)=>waffraSearchAny(
     [b.name,b.budgetLabel??'',b.displayName],budgetQuery))
     .toList(growable:false);
    return AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose a budget':'اختار الميزانية'),
    content:SizedBox(width:430,height:360,child:Column(children:[
     TextField(
      key:const Key('waffra-budget-link-search'),
      onChanged:(text)=>refresh(()=>budgetQuery=text),
      decoration:InputDecoration(
       prefixIcon:const Icon(Icons.search_rounded),
       hintText:waffraIsEnglish?'Search active budgets':'ابحث في الميزانيات المفعّلة',
       border:const OutlineInputBorder())),
     const SizedBox(height:8),
     Expanded(child:visible.isEmpty?
      Center(child:WaffraText(waffraIsEnglish?
       'No matching budgets':'ما فيه ميزانيات مطابقة')):
      ListView.builder(
     itemCount:visible.length,itemBuilder:(_,i){
      final b=visible[i];
      return _borderedMenuChoice(
       key:Key('waffra-retro-budget-option-'+b.id),
       title:WaffraText(b.budgetLabel??b.name,maxLines:2),
       subtitle:WaffraText(waffraIsEnglish?
        'Monthly limit: '+cash(b.budget):'حد الميزانية: '+cash(b.budget)),
       onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,b)),
      );
     })),])),
    actions:[TextButton(
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
     child:WaffraText(waffraIsEnglish?'Leave unassigned':'بدون ربط'))]);
   }));
  if(selected==null||!mounted)return;
  final ok=await showWaffraDialog<bool>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Confirm link':'تأكيد الربط'),
    content:WaffraText(waffraIsEnglish?
     'Link the saved '+cash(original.single.amount)+' expense to '+
       (selected.budgetLabel??selected.name)+
       '? No new expense will be created or amount changed.':
     'ربط مصروف '+cash(original.single.amount)+' بميزانية «'+
       (selected.budgetLabel??selected.name)+
       '» فقط؟ المبلغ والتاريخ والقسم والملاحظات هيفضلوا زي ما هم.'),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
      child:WaffraText(waffraIsEnglish?'Link only':'ربط فقط')),
    ]));
  if(ok!=true||!mounted)return;
  // Dialogs are asynchronous: never rely on stale selection after await.
  final latest=entries.where((e)=>e.id==old.id).toList(growable:false);
  if(latest.length!=1||latest.single.income||
     latest.single.budgetId!=null||
     latest.single.amount!=old.amount||
     latest.single.date!=old.date||
     latest.single.category!=old.category||
     latest.single.title!=old.title||
     latest.single.notes!=old.notes||
     latest.single.receiptPath!=old.receiptPath||
     latest.single.sourceType!=old.sourceType||
     !namedBudgets.any((b)=>b.id==selected.id&&b.budget>0&&
      b.budgetActive&&!b.deleted)){
   snack(context,waffraIsEnglish?'Record changed; nothing saved.':
    'العملية أو الميزانية اتغيرت. لم يتم حفظ أي ربط.');
   return;
  }
  setState((){
   _m684InvalidatePeriodRead();
   final index=entries.indexWhere((e)=>e.id==old.id);
   if(index>=0)entries[index]=entries[index].withBudget(selected.id);
  });
  await _persistModuleOrReload(WaffraFinanceRoute.transactionEdit,
   operation:'retroactive-opt-in-budget-link');
 }

 Future<void> deleteNamedBudget(BudgetCategory selected)async{
  final active=namedBudgets.where((b)=>b.id==selected.id&&!b.deleted).toList();
  if(active.length!=1)return;
  final affected=entries.where((e)=>e.budgetId==selected.id).length;
  final ok=await confirmDeletion(
   waffraIsEnglish?'Delete budget?':'حذف الميزانية',
   waffraIsEnglish?
    'Archive this budget? $affected historical allocation(s) stay intact and no financial transactions will be deleted.':
    'أرشفة الميزانية؟ هنحتفظ بارتباط $affected عملية تاريخية بدون حذف أي معاملة مالية.');
  if(ok!=true||!mounted)return;
  final current=namedBudgets.where((b)=>b.id==selected.id&&!b.deleted).toList();
  if(current.length!=1)return;
  setState((){
   final i=namedBudgets.indexWhere((b)=>b.id==selected.id);
   namedBudgets[i]=namedBudgets[i].copy(budgetActive:false,deleted:true);
   if(selectedNamedBudgetCategoryId==selected.id)selectedNamedBudgetCategoryId=null;
  });
  await _persistModuleOrReload(
   WaffraFinanceRoute.challengeAndBudgetUpdate,
   operation:'standalone-budget-soft-delete');
 }

 Future<void> setNamedBudgetActive(BudgetCategory selected,bool enabled)async{
  final current=namedBudgets.where((b)=>b.id==selected.id&&!b.deleted).toList();
  if(current.length!=1||current.single.budgetActive==enabled)return;
  final ok=await showWaffraDialog<bool>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(enabled?
     (waffraIsEnglish?'Resume budget?':'إعادة تفعيل الميزانية؟'):
     (waffraIsEnglish?'Pause budget?':'إيقاف الميزانية؟')),
    content:WaffraText(waffraIsEnglish?
     'Existing allocations stay unchanged. Expenses saved while paused will not be linked automatically.':
     'كل الروابط القديمة محفوظة. العمليات وقت الإيقاف مش هترتبط تلقائيًا.'),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
      child:WaffraText(enabled?
       (waffraIsEnglish?'Resume':'تفعيل'):
       (waffraIsEnglish?'Pause':'إيقاف'))),
    ]));
  if(ok!=true||!mounted)return;
  final live=namedBudgets.where((b)=>b.id==selected.id&&!b.deleted).toList();
  if(live.length!=1||live.single.budgetActive==enabled)return;
  setState((){
   final index=namedBudgets.indexWhere((b)=>b.id==selected.id);
   namedBudgets[index]=namedBudgets[index].copy(budgetActive:enabled);
   if(selectedNamedBudgetCategoryId==selected.id)selectedNamedBudgetCategoryId=null;
  });
  await _persistModuleOrReload(
   WaffraFinanceRoute.challengeAndBudgetUpdate,
   operation:'standalone-budget-toggle');
 }

 Future<void> editBudgetForCategory(BudgetCategory selected,{String? suggestedName})async{
  final name=TextEditingController(text:selected.budgetLabel??selected.name);
  final amount=TextEditingController(text:selected.budget>0?
   formatWaffraEditAmount(selected.budget):'');
  var alert=selected.alertPercent;
  var alertsEnabled=selected is WaffraNamedBudget?selected.alertsEnabled:true;
  String? budgetSource=selected is WaffraNamedBudget?
   selected.assignedAccountId:null;
  final verifiedBudgetAccounts=_m467Accounts.where((a)=>!a.archived).toList();
  String? nameError,amountError;
  try{
   final edited=await showWaffraDialog<({String label,double amount,int alert,bool alertsEnabled,String? accountId})>(
    context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Set named budget':'تحديد ميزانية باسم'),
     scrollable:true,
     content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      WaffraText(waffraIsEnglish?'Independent of categories':'مستقلة عن الأقسام',style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:12),
      TextField(controller:name,maxLength:80,
       onChanged:(_)=>update(()=>nameError=null),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Budget name *':'اسم الميزانية *',
        errorText:nameError,border:const OutlineInputBorder())),
      const SizedBox(height:12),
      TextField(controller:amount,
       keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
       onChanged:(_)=>update(()=>amountError=null),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Monthly limit *':'الحد الشهري *',
        errorText:amountError,border:const OutlineInputBorder())),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<String>(
       key:const Key('m470-budget-edit-account'),
       initialValue:budgetSource??'shared',isExpanded:true,
       decoration:InputDecoration(labelText:waffraIsEnglish?
        'Monthly budget for account':'الميزانية الشهرية للحساب',
        border:const OutlineInputBorder()),
       items:[
        DropdownMenuItem(value:'shared',child:WaffraText(waffraIsEnglish?
         'Shared budget (all accounts only)':'ميزانية مشتركة (كل الحسابات)')),
        ...verifiedBudgetAccounts.map((a)=>DropdownMenuItem<String>(
         value:a.id,child:WaffraText(a.name,maxLines:1))),
       ],
       onChanged:(value)=>update(()=>budgetSource=value=='shared'?null:value)),
      const SizedBox(height:12),
      waffraBudgetAlertControls(
       enabled:alertsEnabled,percent:alert,english:waffraIsEnglish,
       onEnabled:(value)=>update(()=>alertsEnabled=value),
       onPercent:(value)=>update(()=>alert=value)),
     ]),
     actionsPadding:const EdgeInsets.fromLTRB(16,4,16,14),
     actions:[SizedBox(width:double.maxFinite,child:Row(children:[
      Expanded(child:OutlinedButton(
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء',maxLines:1))),
      const SizedBox(width:12),
      Expanded(child:FilledButton(onPressed:WaffraHaptics.tap((){
       final label=name.text.trim(),value=amountOfDisplay(amount.text);
       update((){
        nameError=label.isEmpty?waffraRequiredFieldMessage:
         namedBudgets.any((c)=>c.id!=selected.id&&!c.deleted&&
           c.name.trim().toLowerCase()==label.toLowerCase())?
          (waffraIsEnglish?'A budget with this name already exists':
           'اسم الميزانية مستخدم بالفعل'):null;
        amountError=waffraAmountFieldError(amount.text);
       });
       if(nameError!=null||amountError!=null||value==null||value<=0)return;
       Navigator.pop(ctx,(label:label,amount:value,alert:alert,
        alertsEnabled:alertsEnabled,accountId:budgetSource));
      }),child:WaffraText(waffraIsEnglish?'Save budget':'حفظ الميزانية',
       maxLines:1))),
     ]))],
    )));
   if(edited==null||!mounted)return;
   if(edited.alertsEnabled&&!(selected is WaffraNamedBudget&&selected.alertsEnabled)){
    await _requestPercentageAlertPermission();
   }
   if(!mounted)return;
   final live=namedBudgets.where((b)=>b.id==selected.id&&!b.deleted).toList();
   if(live.length!=1)return;
   setState((){
    final index=namedBudgets.indexWhere((b)=>b.id==selected.id);
    namedBudgets[index]=namedBudgets[index].copy(
     name:edited.label,budget:edited.amount,alertPercent:edited.alert,
     alertsEnabled:edited.alertsEnabled,
     assignedAccountId:edited.accountId,
     clearAssignedAccount:edited.accountId==null);
    selectedNamedBudgetCategoryId=selected.id;
   });
   await _persistModuleOrReload(WaffraFinanceRoute.challengeAndBudgetUpdate,
    operation:'standalone-budget-edit');
  }finally{disposeLater([name,amount]);}
 }
 /// No category selection: a budget is a standalone financial envelope.
 Future<String?> chooseBudgetCategory({String? suggestedName,
  String? suggestedParentId,String? suggestedSubcategory})async{
  final name=TextEditingController(text:suggestedName??'');
  final amount=TextEditingController();
  var alert=80;
  var alertsEnabled=true;
  String? budgetSource;
  final verifiedBudgetAccounts=_m467Accounts.where((a)=>!a.archived).toList();
  String? nameError,amountError;
  try{
   final selected=await showWaffraDialog<({String name,double cap,int alert,bool alertsEnabled,String? accountId})>(
    context:context,builder:(ctx)=>StatefulBuilder(
     builder:(ctx,update)=>AlertDialog(
      key:const Key('waffra-independent-budget-create'),
      scrollable:true,
      title:WaffraText(waffraIsEnglish?'New budget':'إنشاء ميزانية جديدة'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
       TextField(controller:name,maxLength:80,
        onChanged:(_)=>update(()=>nameError=null),
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Budget name *':'اسم الميزانية *',
         errorText:nameError,border:const OutlineInputBorder())),
       const SizedBox(height:12),
       TextField(controller:amount,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
        onChanged:(_)=>update(()=>amountError=null),
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Monthly amount *':'الحد الشهري *',
         errorText:amountError,border:const OutlineInputBorder())),
       const SizedBox(height:12),
       WaffraCenteredDropdownFormField<String>(
        key:const Key('m470-budget-create-account'),
        initialValue:budgetSource??'shared',isExpanded:true,
        decoration:InputDecoration(labelText:waffraIsEnglish?
         'Monthly budget for account':'الميزانية الشهرية للحساب',
         border:const OutlineInputBorder()),
        items:[
         DropdownMenuItem(value:'shared',child:WaffraText(waffraIsEnglish?
          'Shared budget (all accounts only)':'ميزانية مشتركة (كل الحسابات)')),
         ...verifiedBudgetAccounts.map((a)=>DropdownMenuItem<String>(
          value:a.id,child:WaffraText(a.name,maxLines:1))),
        ],
        onChanged:(value)=>update(()=>budgetSource=value=='shared'?null:value)),
       const SizedBox(height:12),
       waffraBudgetAlertControls(
        enabled:alertsEnabled,percent:alert,english:waffraIsEnglish,
        onEnabled:(value)=>update(()=>alertsEnabled=value),
        onPercent:(value)=>update(()=>alert=value)),
      ]),
      actions:[
       TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
       FilledButton(onPressed:WaffraHaptics.tap((){
        final text=name.text.trim(),cap=amountOfDisplay(amount.text);
        update((){
         nameError=text.isEmpty?waffraRequiredFieldMessage:
          namedBudgets.any((b)=>!b.deleted&&
           b.name.trim().toLowerCase()==text.toLowerCase())?
           (waffraIsEnglish?'Budget name already exists':
            'اسم الميزانية مستخدم بالفعل'):null;
         amountError=waffraAmountFieldError(amount.text);
        });
        if(nameError!=null||amountError!=null||cap==null||cap<=0)return;
        Navigator.pop(ctx,(name:text,cap:cap,alert:alert,
         alertsEnabled:alertsEnabled,accountId:budgetSource));
       }),child:WaffraText(waffraIsEnglish?'Save budget':'حفظ الميزانية')),
      ],
     )));
   if(selected==null||!mounted)return null;
   if(selected.alertsEnabled){
    await _requestPercentageAlertPermission();
   }
   if(!mounted)return null;
   // Dialogs may be open while another budget operation finishes.
   if(namedBudgets.any((b)=>!b.deleted&&b.name.toLowerCase()==
      selected.name.toLowerCase()))return null;
   final id='budget:'+newId();
   if(selected.accountId!=null&&
      !verifiedBudgetAccounts.any((a)=>a.id==selected.accountId))return null;
   setState(()=>namedBudgets.add(WaffraNamedBudget(
    id:id,name:selected.name,budget:selected.cap,alertPercent:selected.alert,
    alertsEnabled:selected.alertsEnabled,
    assignedAccountId:selected.accountId)));
   final saved=await _persistModuleOrReload(
    WaffraFinanceRoute.challengeAndBudgetUpdate,
    operation:'standalone-budget-create');
   if(!saved||!mounted)return null;
   setState(()=>selectedNamedBudgetCategoryId=id);
   return id;
  }finally{disposeLater([name,amount]);}
 }
 // Cross-screen refresh stays inside State, not the budgets extension.
 void refreshFromBudgetDirectory(){if(mounted)setState((){});}
 // M691: Budget, monthly summary and insight cards moved to same-library State extension.
}

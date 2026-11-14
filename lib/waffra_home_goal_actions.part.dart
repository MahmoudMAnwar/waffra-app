part of 'main.dart';

/// M711 / #633: byte-for-byte original goal wallet and challenge workflows
/// extracted from Home State. Same Dart library; original SQLCipher writer,
/// goal balance checks and user confirmations are unchanged.
extension _WaffraHomeGoalActions on _HomeScreenState {
 Future<void> goalDialog({SavingGoal? duplicate,bool openEnded=false})async {
  // M641 account helper already verifies the source; don't bind twice.
  final verifiedGoalAccounts=await _m641VerifiedGoalRecurringAccounts();
  if(verifiedGoalAccounts==null||!mounted)return;
  List<WaffraAccountBalance> goalAccounts=verifiedGoalAccounts;
  String? chosenGoalAccount=duplicate?.accountId;
  if(!goalAccounts.any((a)=>a.id==chosenGoalAccount&&!a.archived)){
   chosenGoalAccount=null;
  }
  final name=TextEditingController(text:duplicate==null?'':(waffraIsEnglish?'Copy of ':'نسخة من ')+duplicate.name),
   target=TextEditingController(text:duplicate==null||duplicate.target<=0?'':formatWaffraEditAmount(duplicate.target));
  DateTime? selectedDeadline=duplicate?.dueDate!=null&&duplicate!.dueDate!.isAfter(DateTime.now())?duplicate.dueDate:null;
  final customGoals=await _financeAuthority.loadCustomGoalSuggestions();
  if(!mounted){name.dispose();target.dispose();return;}
  final defaults=waffraDefaultGoalNames(waffraIsEnglish);
  final allDefaultNames={
   ...waffraDefaultGoalNames(false).map(waffraNormalizeGoal),
   ...waffraDefaultGoalNames(true).map(waffraNormalizeGoal),
  };
  final suggested=<String>[];
  final seen=<String>{};
  for(final entry in [...defaults,...customGoals]){
   final key=waffraNormalizeGoal(entry);
   if(key.isNotEmpty&&seen.add(key))suggested.add(entry.trim());
  }
  const otherGoal='__other_goal__';
  String selectedGoal=duplicate==null?'':'__other_goal__';
  bool attempted=false;
  bool noTarget=openEnded||(duplicate!=null&&duplicate.target<=0);
  bool goalAlertsEnabled=duplicate?.progressAlertsEnabled??false;
  int goalAlertPercent=duplicate?.progressAlertPercent??80;
  String? validateGoalName(){
   final issue=waffraGoalNameIssue(name.text,goals.map((g)=>g.name));
   if(issue=='required'||issue=='too_long')return waffraTextFieldError(name.text);
   if(issue=='duplicate')return waffraIsEnglish?'A goal with this name already exists':'يوجد هدف بنفس الاسم بالفعل';
   if(selectedGoal==otherGoal&&suggested.any(
    (v)=>waffraNormalizeGoal(v)==waffraNormalizeGoal(name.text))){
    return waffraIsEnglish?'Already suggested. Please choose it from the list.':'هذا الهدف ضمن الاقتراحات. اختره من القائمة.';
   }
   return null;
  }
  final g=await showWaffraSmoothDialog<SavingGoal>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,updateGoal)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Add savings goal':'إضافة هدف ادخار'),
    scrollable:true,
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     InkWell(
      borderRadius:BorderRadius.circular(14),
      onTap:WaffraHaptics.tap(()async{
       final picked=await showWaffraDialog<String>(context:ctx,
        builder:(pickCtx){
         String query='';
         return StatefulBuilder(builder:(pickCtx,refresh){
          final matches=suggested.where(
           (item)=>waffraSearchMatches(item,query)).toList();
          return AlertDialog(
           title:WaffraText(waffraIsEnglish?'Choose savings goal':'اختر هدف الادخار'),
           content:SizedBox(
            width:double.maxFinite,
            height:min(450.0,MediaQuery.sizeOf(pickCtx).height*.60),
            child:Column(children:[
             TextField(autofocus:true,onChanged:(value)=>refresh(()=>query=value),
              decoration:InputDecoration(
               prefixIcon:const Icon(Icons.search_rounded),
               hintText:waffraIsEnglish?'Search among suggested goals…':'ابحث بين الأهداف المقترحة…',
               border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))),
             const SizedBox(height:8),
             ListTile(
              dense:true,
              leading:const Icon(Icons.add_circle_outline_rounded,color:emerald),
              title:WaffraText(waffraIsEnglish?'Other goal (custom name)':'هدف آخر (اسم مخصص)'),
              onTap:WaffraHaptics.tap(()=>Navigator.pop(pickCtx,otherGoal))),
             const Divider(height:10),
             Expanded(child:matches.isEmpty
              ?Center(child:WaffraText(waffraIsEnglish?'No matching goals':'لا توجد أهداف مطابقة'))
              :ListView.builder(itemCount:matches.length,itemBuilder:(pickCtx,index)=>
               ListTile(
                dense:true,
                title:WaffraText(matches[index],maxLines:2),
                onTap:WaffraHaptics.tap(()=>Navigator.pop(pickCtx,matches[index]))))),
            ]),
           ),
          );
         });
        });
       if(picked!=null&&ctx.mounted)updateGoal((){
        selectedGoal=picked;
        name.text=picked==otherGoal?'':picked;
       });
      }),
      child:InputDecorator(
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Savings goal *':'اختر هدف الادخار *',
        errorText:attempted&&selectedGoal.isEmpty?waffraRequiredFieldMessage:
         attempted&&selectedGoal!=otherGoal?validateGoalName():null,
        errorMaxLines:2,
        suffixIcon:const Icon(Icons.search_rounded),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
       child:Row(children:[
        Expanded(child:WaffraText(
         selectedGoal==otherGoal?(waffraIsEnglish?'Other goal':'هدف آخر'):
         selectedGoal.isEmpty?(waffraIsEnglish?'Select a goal':'اختر هدفًا'):selectedGoal,
         maxLines:2,
         style:TextStyle(fontSize:14,color:selectedGoal.isEmpty?Theme.of(ctx).hintColor:null))),
        const Icon(Icons.arrow_drop_down_rounded,size:20),
       ]),
      ),
     ),
     if(selectedGoal==otherGoal)...[
      const SizedBox(height:12),
      TextField(controller:name,textInputAction:TextInputAction.next,
       maxLength:100,onChanged:(_)=>updateGoal((){}),
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Other goal name *':'اسم الهدف الآخر *',
        hintText:waffraIsEnglish?'e.g. Home renovation':'مثال: تجديد المنزل',
        errorText:attempted?validateGoalName():null,
        errorMaxLines:2,
        border:const OutlineInputBorder())),
     ],
     const SizedBox(height:12),
     WaffraGoalRecurringAccountPicker(
      key:const Key('m641-goal-account-cascade'),
      idPrefix:'m641-goal',english:waffraIsEnglish,
      accounts:goalAccounts,selectedAccountId:chosenGoalAccount,
      onChanged:(id)=>updateGoal(()=>chosenGoalAccount=id),
     onError:(message)=>snack(context,message),
      onCreateAccount:(provider)async{
       final newAccount=await _m641CreateGoalRecurringAccount(provider);
       if(newAccount!=null){
        goalAccounts=[...goalAccounts,newAccount];
       }
       return newAccount;
      }),
     const SizedBox(height:12),
     OutlinedButton.icon(onPressed:WaffraHaptics.tap(()async{
      final date=await waffraPickDateWithToday(english:waffraIsEnglish,context:ctx,
       initialDate:selectedDeadline??DateTime.now().add(const Duration(days:1)),
       firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+10));
      if(date!=null&&ctx.mounted)updateGoal(()=>selectedDeadline=date);
     }),icon:const Icon(Icons.calendar_month_outlined),
     label:WaffraText(selectedDeadline==null?
      (waffraIsEnglish?'Due date':'تاريخ الاستحقاق'):
      dayText(selectedDeadline!))),
     const SizedBox(height:12),
     SwitchListTile.adaptive(
      contentPadding:EdgeInsets.zero,
      title:WaffraText(waffraIsEnglish?'Open-ended savings':'ادخار مفتوح بدون مبلغ مستهدف'),
      subtitle:WaffraText(waffraIsEnglish?'Save any amount, without a target or completion percentage':'ادّخر براحتك من غير حدّ أو رقم مستهدف'),
      value:noTarget,activeTrackColor:emerald,
      onChanged:WaffraHaptics.selection((value)=>updateGoal(()=>noTarget=value))),
     if(!noTarget)TextField(controller:target,
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
      onChanged:(_)=>updateGoal((){}),
      decoration:InputDecoration(
       labelText:waffraIsEnglish?'Target amount *':'المبلغ المستهدف *',
       hintText:waffraIsEnglish?'e.g. 25000':'مثال: 25000',
       errorText:attempted?waffraAmountFieldError(target.text):null,
       border:const OutlineInputBorder())),
     if(!noTarget)...[
      const SizedBox(height:12),
      waffraBudgetAlertControls(
       enabled:goalAlertsEnabled,percent:goalAlertPercent,
       english:waffraIsEnglish,goal:true,
       onEnabled:(value)=>updateGoal(()=>goalAlertsEnabled=value),
       onPercent:(value)=>updateGoal(()=>goalAlertPercent=value)),
     ],
    ]),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      updateGoal(()=>attempted=true);
      final n=amountOfDisplay(target.text);
      if(selectedGoal.isEmpty||validateGoalName()!=null||
       (!noTarget&&(WaffraValidators.positiveAmount(target.text)!=null||n==null)))return;
      if(chosenGoalAccount==null||!goalAccounts.any(
         (a)=>a.id==chosenGoalAccount&&!a.archived)){
       snack(ctx,waffraIsEnglish?
        'Select or create a financial account for this goal.':
        'اختر حسابًا ماليًا تابعًا للهدف أو أضف حسابًا جديدًا.',
        isError:true);
       return;
      }
      Navigator.pop(ctx,SavingGoal(id:newId(),name:name.text.trim(),
       target:noTarget?0.0:n!,saved:0,dueDate:selectedDeadline,
       accountId:chosenGoalAccount,
       progressAlertsEnabled:!noTarget&&goalAlertsEnabled,
       progressAlertPercent:goalAlertPercent));
     }),child:WaffraText(waffraIsEnglish?'Add goal':'إضافة الهدف')),
    ],
   )));
  disposeLater([name,target]);
  if(g!=null&&mounted){
   if(g.progressAlertsEnabled)await _requestPercentageAlertPermission();
   if(!mounted)return;
   if(selectedGoal==otherGoal){
    final key=waffraNormalizeGoal(g.name);
    if(!allDefaultNames.contains(key)&&
       !customGoals.any((x)=>waffraNormalizeGoal(x)==key)){
     await _financeAuthority.addCustomGoalSuggestion(g.name);
    }
   }
   if(!mounted)return;
   // Approval BEFORE write: goal and linked recurring due use one atomic
   // SQLCipher snapshot+relational projection commit, or both roll back.
   final linkNew=g.dueDate!=null&&g.target>0&&g.active&&
    await _confirmGoalDueRecurringLink(g);
   if(!mounted)return;
   final saved=await this._saveGoalAndLinkedDueAtomically(g,
    creating:true,linkNew:linkNew,operation:'goal-create-and-due');
   if(!saved||!mounted)return;
   snackSuccess(context,linkNew?
    (waffraIsEnglish?'Goal and due saved together.':
     'تم حفظ الهدف والاستحقاق المرتبط معًا.'):
    (waffraIsEnglish?'Savings goal added successfully':
     'تمت إضافة الهدف بنجاح'));
  }
 }

 /// M641: both form types use the same owner-verified account source.
 /// An empty result means a valid first installation, not a navigation error.
 Future<List<WaffraAccountBalance>?> _m641VerifiedGoalRecurringAccounts()async{
  try{
   await _ensureFinanceBound();
   final bridge=_financeBinding?.accountsBridge;
   if(bridge==null)throw StateError('No verified financial account source');
   final records=await WaffraVerifiedAccountsApi(bridge:bridge).balances();
   return records.where((a)=>!a.archived).toList();
  }catch(error){
   debugPrint('M641 verified accounts load failed: '+error.runtimeType.toString());
   if(mounted)snack(context,waffraIsEnglish?
    'Financial accounts could not be verified. Try again.':
    'تعذر التحقق من الحسابات المالية. حاول مرة أخرى.',isError:true);
   return null;
  }
 }

 /// Uses the same trusted SQLCipher create API as manual income/expense.
 /// Cancellation never changes the draft or creates a phantom account.
 Future<WaffraAccountBalance?> _m641CreateGoalRecurringAccount(
  String? requestedGroupId)async{
  await _ensureFinanceBound();
  final bridge=_financeBinding?.accountsBridge;
  if(bridge==null)throw StateError('Verified account writer unavailable');
  final api=WaffraVerifiedAccountsApi(bridge:bridge);
  final before=await api.balances();
  if(!mounted)return null;
  WaffraSaudiProvider? selectedProvider;
  if(requestedGroupId!=null&&requestedGroupId.contains(':institution:')){
   final identifier=requestedGroupId.split(':').last;
   selectedProvider=WaffraSaudiFinancialProviders.byId(identifier);
  }
  final kinds=<String,List<String>>{
   for(final kind in const ['bank','wallet'])
    kind:before.where((a)=>!a.archived&&a.kind==kind&&
      a.customSubtypeLabel!=null)
      .map((a)=>a.customSubtypeLabel!).toSet().toList()..sort(),
  };
  final draft=await showWaffraDialog<WaffraNewAccountDraft>(
   context:context,builder:(dialog)=>WaffraNewAccountDialog(
    english:waffraIsEnglish,
    suggestedProviderId:selectedProvider?.id,
    customSubtypeOptions:kinds));
  if(draft==null||!mounted)return null;
  if(selectedProvider!=null&&
     (draft.providerId!=selectedProvider.id||
      draft.kind!=(selectedProvider.category==WaffraSaudiFinancialProviders.wallet?
       'wallet':'bank'))){
   throw StateError('New financial account provider changed');
  }
  // The account form may stay open while SMS/widget writes change finance.
  // Take a fresh verified witness after the user confirms this draft.
  await api.balances();
  final id='m641-goal-recurring-'+newId();
  await api.createTypedAccountWithIdentity(
   id:id,name:draft.name,kind:draft.kind,
   providerId:draft.providerId??'none',
   subtype:draft.subtype??'other',
   openingMinor:draft.openingMinor,
   createdIso:DateTime.now().toUtc().toIso8601String(),
   lastFour:draft.lastFour,
   customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
  final refreshed=await api.balances();
  final created=refreshed.where((a)=>a.id==id&&!a.archived).toList();
  if(created.length!=1)throw StateError('New account lacked verified ledger');
  // Account creation increments the canonical SQLCipher generation. Refresh
  // the Home authority witness before saving the goal/recurring draft;
  // otherwise its subsequent persist rejects as stale even though the first
  // account was created successfully. Do not restart Home or clear the form.
  await _refreshFromVerifiedFinance();
  if(!mounted||!ready||_financeLoadFailure!=null){
   throw StateError('Account created, but fresh finance was not verified.');
  }
  return created.single;
 }
 /// Release an earmark back to spendable cash. The eventual expense is
 /// recorded once using the normal finance entry editor, not in this transfer.
 Future<void> releaseGoalFunds(SavingGoal goal)async{
  if(goal.saved<=0)return;
  await _ensureFinanceBound();
  final bridge=_financeBinding?.accountsBridge;
  var possible=<WaffraAccountBalance>[];
  if(bridge!=null){
   try{
    possible=(await WaffraVerifiedAccountsApi(
     bridge:bridge).balances()).where((a)=>!a.archived).toList();
   }catch(error){
    debugPrint('Verified goal release accounts unavailable: $error');
    if(mounted)snack(context,waffraIsEnglish?
     'Cannot verify the receiving account; reload first.':
     'تعذر التحقق من الحساب المستلم؛ حدّث الصفحة أولًا.');
    return;
   }
  }
  if(!mounted)return;
  var chosen='none';
  final ctl=TextEditingController(text:formatWaffraEditAmount(goal.saved));
  try{
   final choice=await showWaffraDialog<({double amount,String? accountId})>(
    context:context,builder:(ctx)=>StatefulBuilder(
     builder:(ctx,refresh)=>AlertDialog(
      title:WaffraText(waffraIsEnglish?
       'Release goal savings':'سحب من محفظة الهدف'),
      content:SingleChildScrollView(child:Column(
       mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,
       children:[
        WaffraText(waffraIsEnglish?
         'Move savings out of the separate goal wallet. This is not income and never creates a second expense.':
         'السحب من محفظة الهدف المستقلة ليس دخلًا جديدًا ولا يسجّل مصروفًا ثانيًا.'),
        const SizedBox(height:12),
        TextField(controller:ctl,
         keyboardType:const TextInputType.numberWithOptions(decimal:true),
         inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
         decoration:InputDecoration(
          labelText:waffraIsEnglish?'Amount to release':'مبلغ السحب',
          border:const OutlineInputBorder())),
        if(bridge!=null)...[
         const SizedBox(height:12),
         WaffraCenteredDropdownFormField<String>(
          key:const Key('waffra-goal-release-destination-account'),
          isExpanded:true,initialValue:chosen,
          decoration:InputDecoration(
           labelText:waffraIsEnglish?
            'Receive savings in account':'الحساب المستلم للادخار',
           border:const OutlineInputBorder()),
          items:[
           DropdownMenuItem<String>(value:'none',
            child:WaffraText(waffraIsEnglish?
             'No linked account':'بدون حساب')),
           ...possible.map((a)=>DropdownMenuItem<String>(
            value:a.id,child:WaffraText(a.name,maxLines:1))),
          ],
          onChanged:(value)=>refresh(()=>chosen=value??'none'),
         ),
         const SizedBox(height:6),
         WaffraText(waffraIsEnglish?
          'A selected SAR account is credited exactly once; no account means no bank balance change.':
          'الحساب المختار يُضاف له المبلغ مرة واحدة؛ بدون حساب لا يتغير أي رصيد بنكي.',
          style:const TextStyle(fontSize:12)),
        ],
       ])),
      actions:[
       TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
       FilledButton(onPressed:WaffraHaptics.tap((){
        final value=amountOfDisplay(ctl.text);
        if(value==null||value<=0||value>goal.saved)return;
        Navigator.pop(ctx,(amount:value,
         accountId:chosen=='none'?null:chosen));
       }),child:WaffraText(waffraIsEnglish?'Confirm release':'تأكيد السحب')),
      ],
     ),
    ),
   );
   if(choice==null||!mounted)return;
   final matching=goals.where((g)=>g.id==goal.id).toList();
   if(matching.length!=1||matching.single.saved<choice.amount){
    snack(context,waffraIsEnglish?
     'Goal balance changed; reload before release.':
     'رصيد الهدف اتغير؛ حدّث الصفحة قبل السحب.');
    return;
   }
   if(bridge!=null){
    try{
     await _financialWriteQueue.drain();
     final baseline=await _financeAuthority.load(
      route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
     if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
        baseline.encryptedWitness==null){
      throw StateError('Verified goal release source changed.');
     }
     await bridge.fundVerifiedGoal(
      baseline:baseline.encryptedWitness!,goalId:goal.id,
      amountMinor:(choice.amount*100).round(),
      movementId:'goal-release:${newId()}',
      occurredIso:DateTime.now().toUtc().toIso8601String(),
      sourceAccountId:choice.accountId,userConfirmed:true,release:true,
     );
     if(mounted)await _loadFinanceSafely();
     if(mounted)unawaited(_refreshWidget());
    }catch(error){
     debugPrint('Verified savings release rejected: $error');
     if(mounted)await _loadFinanceSafely();
     if(mounted)snack(context,waffraIsEnglish?
      'Release was not confirmed. Balances were safely refreshed.':
      'لم يتأكد السحب. تم تحديث الأرصدة بأمان.');
    }
   }else{
    // Existing guarded legacy data has no verified bank-account ledger.
    setState((){
     final idx=goals.indexWhere((g)=>g.id==goal.id);
     if(idx>=0)goals[idx]=matching.single.copy(
      saved:matching.single.saved-choice.amount);
    });
    await _persistModuleOrReload(WaffraFinanceRoute.goalCreateEditDeleteRestore,
     operation:'release-goal-earmark');
   }
  }finally{disposeLater([ctl]);}
 }
 Future<void> fundGoal(SavingGoal g)async {
  // M641: an independent goal wallet credit and one verified source debit.
  final verifiedFundingAccounts=await _m641VerifiedGoalRecurringAccounts();
  final fundingBridge=_financeBinding?.accountsBridge;
  if(fundingBridge==null||verifiedFundingAccounts==null||!mounted)return;
  List<WaffraAccountBalance> fundingAccounts=verifiedFundingAccounts;
  // M689: verified linked goals never offer another bank as a debit source.
  if(g.accountId!=null &&
     !fundingAccounts.any((a)=>a.id==g.accountId&&!a.archived)){
   snack(context,waffraIsEnglish?
    'The linked goal account is unavailable. Edit the goal account first.':
    'الحساب المرتبط بالهدف غير متاح. عدّل حساب الهدف أولًا قبل الادخار.');
   return;
  }
  String? chosenSource=g.accountId;
  if(!fundingAccounts.any((a)=>a.id==chosenSource&&!a.archived)){
   chosenSource=null; // old goals need explicit source choice
  }
  final amount=TextEditingController();
  bool attempted=false;
  final funding=await showWaffraDialog<({double amount,String? sourceAccountId})>(
   context:context,builder:(dialogCtx)=>StatefulBuilder(
    builder:(dialogCtx,update){
     final theme=Theme.of(dialogCtx);
     final dark=theme.brightness==Brightness.dark;
     final accent=dark?const Color(0xFF82E2B4):emerald;
     final currentProgress=g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0);
     // M689: do not let an unaffordable amount dismiss the dialog.
     // The encrypted writer checks cash again at commit time.
     final selectedFundingAccounts=fundingAccounts.where((a)=>
      a.id==chosenSource&&!a.archived).toList();
     final enteredFundingAmount=amountOfDisplay(amount.text);
     final fundingExceedsBalance=enteredFundingAmount!=null&&
      selectedFundingAccounts.length==1&&
      (enteredFundingAmount*100).round()>selectedFundingAccounts.single.balanceMinor;
     final availableFundingText=selectedFundingAccounts.length==1?
      cash(selectedFundingAccounts.single.balanceMinor/100):'';
     void addQuickAmount(double increment){
      final current=amountOf(amount.text)??0;
      amount.text=formatWaffraMoney(current+increment);
      amount.selection=TextSelection.collapsed(offset:amount.text.length);
      update((){});
     }
     return AlertDialog(
      title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Add savings':'إضافة ادخار',
        style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
       const SizedBox(height:3),
       WaffraText(waffraIsEnglish?'To ${g.name}':'إلى هدف ${g.name}',
        maxLines:2,style:TextStyle(fontSize:14,color:theme.hintColor)),
      ]),
      content:SingleChildScrollView(child:Column(
       mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,
       children:[
        Container(
         padding:const EdgeInsets.symmetric(horizontal:13,vertical:14),
         decoration:BoxDecoration(
          color:accent.withValues(alpha:dark ? 0.12 : 0.06),
          borderRadius:BorderRadius.circular(20),
          border:Border.all(color:accent.withValues(alpha:.14))),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
           CircleAvatar(radius:20,backgroundColor:accent.withValues(alpha:.15),
            child:Icon(goalIcon(g.name),color:accent,size:21)),
           const SizedBox(width:9),
           Expanded(child:WaffraText(g.name,maxLines:2,
            style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14))),
          ]),
          const SizedBox(height:9),
          WaffraText(g.target<=0?(waffraIsEnglish?'Saved '+cash(g.saved)+' · Open-ended':'المدخر '+cash(g.saved)+' · ادخار مفتوح'):(waffraIsEnglish
           ?'${WaffraDisplayCurrency.money(g.saved,english:true)} of ${WaffraDisplayCurrency.money(g.target,english:true)}'
           :'${WaffraDisplayCurrency.money(g.saved,english:false)} من ${WaffraDisplayCurrency.money(g.target,english:false)}'),
           textAlign:TextAlign.center,style:const TextStyle(fontSize:13)),
          const SizedBox(height:9),
          if(g.target>0)LinearProgressIndicator(value:currentProgress,minHeight:8,
           color:accent,backgroundColor:accent.withValues(alpha:.14),
           borderRadius:BorderRadius.circular(12)),
          const SizedBox(height:7),
          if(g.target>0)WaffraText('${(currentProgress*100).round()}%',
           textAlign:TextAlign.start,
           style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:accent)),
         ])),
        const SizedBox(height:17),
        WaffraText(waffraIsEnglish?'Amount to add *':'المبلغ المراد إضافته *',
         style:const TextStyle(fontWeight:FontWeight.bold,fontSize:14)),
        const SizedBox(height:8),
        TextField(
         controller:amount,
         keyboardType:const TextInputType.numberWithOptions(decimal:true),
         inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],
         onChanged:(_)=>update((){}),
         decoration:InputDecoration(
          hintText:'0.00',
          suffixText:WaffraDisplayCurrency.label(waffraIsEnglish),
          errorText:fundingExceedsBalance?
           (waffraIsEnglish
            ?'Insufficient account balance. Available: $availableFundingText.'
            :'رصيد الحساب غير كافٍ. المتاح: $availableFundingText.')
           :attempted?waffraAmountFieldError(amount.text):null,
          errorMaxLines:2,
          enabledBorder:OutlineInputBorder(
           borderRadius:BorderRadius.circular(15),
           borderSide:BorderSide(color:accent,width:1.5)),
          focusedBorder:OutlineInputBorder(
           borderRadius:BorderRadius.circular(15),
           borderSide:BorderSide(color:accent,width:2)),
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15)),
         )),
        const SizedBox(height:12),
        if(g.accountId!=null)
         InputDecorator(
          decoration:InputDecoration(
           labelText:waffraIsEnglish?'Linked funding account':'الحساب المرتبط بالهدف',
           border:const OutlineInputBorder()),
          child:WaffraText(fundingAccounts
           .where((a)=>a.id==g.accountId&&!a.archived)
           .map((a)=>a.name).first,
           maxLines:2),
         )
        else WaffraGoalRecurringAccountPicker(
         key:const Key('m641-goal-funding-account-cascade'),
         idPrefix:'m641-fund-goal',english:waffraIsEnglish,
         accounts:fundingAccounts,selectedAccountId:chosenSource,
         onChanged:(id)=>update(()=>chosenSource=id),
         onError:(message)=>snack(context,message),
         onCreateAccount:(provider)async{
          final added=await _m641CreateGoalRecurringAccount(provider);
          if(added!=null)fundingAccounts=[...fundingAccounts,added];
          return added;
         }),
        const SizedBox(height:7),
        WaffraText(waffraIsEnglish
         ?'This credits the goal wallet and debits the selected account once.'
         :'إضافة الادخار تزود رصيد الهدف وتخصم من الحساب المالي المحدد مرة واحدة، بدون تسجيل مصروف.',
         style:const TextStyle(fontSize:12)),
        const SizedBox(height:10),
        Row(children:[
         for(final quick in [500.0,1000.0,2000.0])...[
          Expanded(child:TextButton(
           style:TextButton.styleFrom(
            backgroundColor:accent.withValues(alpha:.08),
            padding:const EdgeInsets.symmetric(vertical:10,horizontal:2),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
           onPressed:WaffraHaptics.tap(()=>addQuickAmount(quick)),
           child:WaffraText('+${quick.toInt()}',
            style:TextStyle(fontWeight:FontWeight.bold,fontSize:12,color:accent)))),
          if(quick!=2000.0)const SizedBox(width:7),
         ],
        ]),
        const SizedBox(height:13),
        Container(
         padding:const EdgeInsets.all(11),
         decoration:BoxDecoration(color:accent.withValues(alpha:.09),
          borderRadius:BorderRadius.circular(15)),
         child:Row(children:[
          Icon(Icons.info_outline_rounded,size:19,color:accent),
          const SizedBox(width:8),
          Expanded(child:WaffraText(waffraIsEnglish
           ?'This is a separate savings-wallet movement, not an expense. A verified funding account is debited once, if selected.'
           :'هذه حركة في محفظة الادخار المستقلة وليست مصروفًا. الحساب المحدد كمصدر يُخصم منه مرة واحدة فقط.',
           style:const TextStyle(fontSize:12))),
         ])),
       ],
      )),
      actionsPadding:const EdgeInsets.fromLTRB(16,0,16,16),
      actions:[SizedBox(width:double.infinity,
       child:Column(children:[
        SizedBox(width:double.infinity,child:FilledButton(
         onPressed:fundingExceedsBalance?null:WaffraHaptics.tap((){
          update(()=>attempted=true);
          if(waffraAmountFieldError(amount.text)!=null)return;
          final value=amountOfDisplay(amount.text);
          if(value==null||value<=0)return;
          if(chosenSource==null||!fundingAccounts.any(
             (a)=>a.id==chosenSource&&!a.archived)){
           snack(dialogCtx,waffraIsEnglish?
            'Choose or create a verified savings account.':
            'اختار أو أضف حسابًا ماليًا موثّقًا لمصدر الادخار.');
           return;
          }
          Navigator.pop(dialogCtx,(amount:value,sourceAccountId:chosenSource));
         }),
         child:WaffraText(waffraIsEnglish?'Add amount':'إضافة'))),
        const SizedBox(height:7),
        SizedBox(width:double.infinity,child:OutlinedButton(
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
         child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))),
       ]))],
     );
    },
   ),
  );
  disposeLater([amount]);
  if(funding!=null&&mounted){
   final n=funding.amount;
   // The selected verified money account, not the global income/expense
   // ledger, owns this funding debit. Opening cash on a new account must
   // never display a false 0 SAR balance warning.
   final source=fundingAccounts.where((account)=>
    account.id==funding.sourceAccountId&&!account.archived).toList();
   if(source.length!=1){
    snack(context,waffraIsEnglish?
     'Funding account changed. Reopen and verify the account.':
     'الحساب المحدد للادخار اتغير. افتح الإضافة واختار حسابًا موثّقًا.',
     isError:true);
    return;
   }
   final available=source.single.balanceMinor/100;
   if(n>available){
    // M689: never offer Continue for a payment SQLCipher must reject.
    // This is informational and fail-closed; no wallet/account mutation.
    snack(context,waffraIsEnglish?
     'Available verified account balance is ${cash(available)}. Savings of ${cash(n)} cannot be added.':
     'رصيد الحساب المتاح ${cash(available)}، ولا يمكن إضافة ادخار بقيمة ${cash(n)}. اختر مبلغًا لا يتجاوز الرصيد.',
     isError:true);
    return;
   }
   // Never overwrite concurrent edits to this goal after a warning dialog.
   final matching=goals.where((x)=>x.id==g.id).toList();
   if(matching.length!=1){
    snack(context,waffraIsEnglish?
     'Goal changed; refresh and try again.':
     'بيانات الهدف اتغيرت؛ حدّث الصفحة وحاول تاني.');
    return;
   }
   final current=matching.single;
   final achieved=current.saved<current.target&&
    current.saved+n>=current.target;
    // One trusted writer handles the goal-wallet movement, funding account
    // attribution and canonical snapshot in one SQLCipher transaction.
    try{
     await _financialWriteQueue.drain();
     final baseline=await _financeAuthority.load(
      route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
     if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
        baseline.encryptedWitness==null){
      throw StateError('Verified goal source changed.');
     }
     await fundingBridge.fundVerifiedGoal(
      baseline:baseline.encryptedWitness!,
      goalId:g.id,amountMinor:(n*100).round(),
      movementId:'goal-fund:${newId()}',
      occurredIso:DateTime.now().toUtc().toIso8601String(),
      sourceAccountId:funding.sourceAccountId,userConfirmed:true,
     );
     // A verified same-owner refresh updates goal and bank account balances
     // without reinitializing Home or scheduling another SMS startup scan.
     if(mounted)await _refreshFromVerifiedFinance();
    }catch(error){
     debugPrint('Atomic goal funding was not confirmed: $error');
     if(mounted)await _loadFinanceSafely();
     if(mounted)snack(context,waffraIsEnglish?
      'Savings transfer was not confirmed. Financial balances were reloaded.':
      'لم تتأكد حركة الادخار. أعدنا تحميل الأرصدة بدون خصم غير مؤكد.');
     return;
    }
   final progressCrossed=WaffraFinancialInsights.crossedBudgetThreshold(
    previousSpent:current.saved,spent:current.saved+n,
    limit:current.target,alertPercent:current.progressAlertPercent,
    enabled:current.active&&current.progressAlertsEnabled);
   if(progressCrossed!=0){
    try{await WaffraReminders.showGoalProgress(
     goalId:current.id,stage:progressCrossed,english:waffraIsEnglish);}
    catch(error){debugPrint('Goal progress notification unavailable: $error');}
   }
   if(achieved&&mounted){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'🎉 Goal achieved!':'🎉 مبروك!'),
     content:WaffraText(waffraIsEnglish
      ?'You achieved your savings goal “${g.name}”!'
      :'تم تحقيق هدف الادخار «${g.name}» بنجاح!'),
     actions:[FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Great':'رائع'))]));
   }else if(progressCrossed!=0&&mounted){
    await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Savings progress':'تنبيه تقدّم الادخار'),
     content:WaffraText(waffraIsEnglish?
      'Your savings reached $progressCrossed% of the target.':
      'مدخراتك وصلت إلى $progressCrossed٪ من المبلغ المستهدف.'),
     actions:[FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   }
  }
 }
 IconData goalIcon(String name){
  final x=name.toLowerCase();
  if(RegExp(r'سيار|عرب|car').hasMatch(x))return Icons.directions_car;
  if(RegExp(r'بيت|منزل|شقة|home').hasMatch(x))return Icons.home;
  if(RegExp(r'سفر|رحل|عمرة|حج|travel').hasMatch(x))return Icons.flight_takeoff;
  if(RegExp(r'زواج|عرس|فرح').hasMatch(x))return Icons.favorite;
  if(RegExp(r'دراس|تعليم|جامعة|school').hasMatch(x))return Icons.school;
  if(RegExp(r'جوال|هاتف|موبايل').hasMatch(x))return Icons.smartphone;
  if(RegExp(r'مشروع|تجارة').hasMatch(x))return Icons.storefront;
  return Icons.account_balance_wallet;
 }

 Future<void> createSavingChallenge()async {
  final name=TextEditingController(),amount=TextEditingController();
  var attempted=false,days=30;
  final challenge=await showWaffraDialog<SavingChallenge>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'New savings challenge':'تحدي ادخار جديد'),
    content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Challenge name *':'اسم التحدي *',
      errorText:attempted?waffraTextFieldError(name.text):null)),
     const SizedBox(height:12),
     TextField(controller:amount,onChanged:(_)=>update((){}),
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],decoration:InputDecoration(
       labelText:waffraIsEnglish?'Daily amount *':'الادخار اليومي *',
       errorText:attempted?waffraAmountFieldError(amount.text):null)),
     const SizedBox(height:12),
     WaffraCenteredDropdownFormField<int>(initialValue:days,
      decoration:InputDecoration(labelText:waffraIsEnglish?'Duration *':'مدة التحدي *'),
      items:[7,14,30].map((n)=>DropdownMenuItem<int>(value:n,
       child:WaffraText(waffraIsEnglish?'$n days':'$n يوم'))).toList(),
      onChanged:WaffraHaptics.selection((n){if(n!=null)update(()=>days=n);})),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?
      'This tracks your habit manually and never deducts money.':
      'التحدي لتتبّع عادتك يدويًا، ولن يخصم أو يحوّل أموالًا تلقائيًا.',
      style:const TextStyle(color:Colors.grey,fontSize:12)),
    ])),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      update(()=>attempted=true);
      if(WaffraValidators.requiredText(name.text)!=null||
       WaffraValidators.positiveAmount(amount.text)!=null)return;
      final value=amountOfDisplay(amount.text);
      if(value==null)return;
      Navigator.pop(ctx,SavingChallenge(id:newId(),title:name.text.trim(),
       dailyAmount:value,days:days));
     }),child:WaffraText(waffraIsEnglish?'Save challenge':'إضافة التحدي')),
    ])));
  disposeLater([name,amount]);
  if(challenge==null||!mounted)return;
  setState(()=>challenges.add(challenge));
  await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
 }
 Widget savingsChallengesSection()=>Card(
  margin:const EdgeInsets.symmetric(vertical:12),elevation:1,
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
  child:ExpansionTile(
   initiallyExpanded:challenges.isNotEmpty,
   leading:const Icon(Icons.emoji_events_outlined,color:emerald),
   title:WaffraText(waffraIsEnglish?'Savings challenges':'تحديات الادخار',
    style:const TextStyle(fontWeight:FontWeight.bold)),
   subtitle:WaffraText(waffraIsEnglish?'Build your saving habit':'حوّل التوفير إلى عادة يومية'),
   children:[
    if(challenges.isEmpty)Padding(padding:const EdgeInsets.all(14),
     child:WaffraText(waffraIsEnglish?'Try a daily savings challenge':
      'ابدأ تحديًا بسيطًا ووفّر مبلغًا كل يوم.',textAlign:TextAlign.center)),
    ...challenges.map((c){
     final completed=c.completedDays>=c.days,allowed=c.canComplete(DateTime.now());
     return Padding(padding:const EdgeInsets.fromLTRB(14,7,14,12),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[
        Expanded(child:WaffraText(c.title,style:const TextStyle(fontWeight:FontWeight.bold))),
        IconButton(icon:const Icon(Icons.delete_outline,size:20),
         tooltip:waffraIsEnglish?'Delete challenge':'حذف التحدي',
         onPressed:WaffraHaptics.tap(()async{
          final ok=await confirmDeletion(waffraIsEnglish?'Delete challenge?':'حذف التحدي',
           waffraIsEnglish?'Progress cannot be recovered.':
            'هل أنت متأكد من حذف هذا التحدي؟ سيتم حذف التحدي نهائيًا، ولن تتمكن من استعادته لاحقًا.');
          if(ok==true&&mounted){
           setState(()=>challenges.removeWhere((x)=>x.id==c.id));await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
          }
         })),
       ]),
       WaffraText(waffraIsEnglish?
        'Daily: ${cash(c.dailyAmount)} • Target: ${cash(c.days*c.dailyAmount)}':
        'يوميًا: ${cash(c.dailyAmount)} • المستهدف: ${cash(c.days*c.dailyAmount)}',
        style:const TextStyle(fontSize:12)),
       const SizedBox(height:7),
       LinearProgressIndicator(value:(c.completedDays/c.days).clamp(0.0,1.0),
        minHeight:8,borderRadius:BorderRadius.circular(8)),
       const SizedBox(height:8),
       Row(children:[
        Expanded(child:WaffraText(waffraIsEnglish?
         '${c.completedDays} of ${c.days} days':
         '${c.completedDays} من ${c.days} يوم',
         style:const TextStyle(fontSize:12))),
        TextButton.icon(onPressed:WaffraHaptics.tap(allowed?()async{
          final i=challenges.indexWhere((x)=>x.id==c.id);
          if(i<0||!challenges[i].canComplete(DateTime.now()))return;
          setState(()=>challenges[i]=challenges[i].complete());
          await persist(route:WaffraFinanceRoute.challengeAndBudgetUpdate);
         }:null),icon:Icon(completed?Icons.check_circle_outline:Icons.check,size:18),
         label:WaffraText(completed?(waffraIsEnglish?'Complete':'مكتمل'):
          allowed?(waffraIsEnglish?'Saved today':'وفّرت اليوم'):
          (waffraIsEnglish?'Marked today':'تم اليوم'))),
       ]),
      ]));
    }),
    Padding(padding:const EdgeInsets.fromLTRB(14,0,14,14),
     child:OutlinedButton.icon(onPressed:WaffraHaptics.tap(createSavingChallenge),
      icon:const Icon(Icons.add),
      label:WaffraText(waffraIsEnglish?'New challenge':'تحدي جديد'))),
   ],
  ));

 Widget savingsBenefit(String name,IconData icon){
  final color=Theme.of(context).brightness==Brightness.dark?
   const Color(0xFF72DCAC):emerald;
  return Expanded(child:Container(
   padding:const EdgeInsets.symmetric(vertical:13,horizontal:5),
   decoration:BoxDecoration(color:color.withValues(alpha:.10),
    border:Border.all(color:color.withValues(alpha:.18)),borderRadius:BorderRadius.circular(18)),
   child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,color:color,size:23),const SizedBox(height:10),
    Row(mainAxisAlignment:MainAxisAlignment.center,children:[
     Flexible(child:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(name,
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)))),
    ]),
   ]),
  ));
 }
 String waffraGoalDeleteWarning(String name,bool linked,bool english)=>english
  ?'Move “$name” to Deleted Goals for 30 days. ${linked?'This goal has saved amounts or linked transactions; financial history will stay untouched.':''} Restored goals restart with zero saved balance.'
  :'نقل «$name» إلى الأهداف المحذوفة لمدة 30 يومًا. ${linked?'هذا الهدف مرتبط بمبالغ ادخار أو معاملات مالية؛ ستبقى المعاملات محفوظة.':''} عند الاسترجاع يبدأ رصيد الادخار من صفر.';
 Future<void> deletedGoalsDialog()async{
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _showVerifiedModuleTrash(WaffraFinanceModule.goals);
   return;
  }
  final before=deletedGoals.length;
  deletedGoals.removeWhere((item){
   final date=DateTime.tryParse('${item['deletedAt']??''}');
   return date==null||!DateTime.now().isBefore(date.add(const Duration(days:30)));
  });
  if(before!=deletedGoals.length)await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>
   StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Deleted goals':'الأهداف المحذوفة'),
    content:SizedBox(width:double.maxFinite,
     height:waffraDeletedListHeight(ctx,deletedGoals.length),
     child:deletedGoals.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted goals':'لا توجد أهداف محذوفة'))
      :ListView(children:deletedGoals.map((item){
       final goal=SavingGoal.fromJson(Map<String,dynamic>.from(item['goal'] as Map));
       final deletedAt=DateTime.tryParse('${item['deletedAt']??''}')??DateTime.now();
       final left=max(0,(deletedAt.add(const Duration(days:30))
        .difference(DateTime.now()).inHours/24).ceil());
       return waffraDeletedItemCard(
        context:ctx,
        icon:goalIcon(goal.name),
        iconColor:emerald,
        title:goal.name,
        subtitle:waffraIsEnglish?'Savings goal • $left days remaining':
         'هدف ادخاري • متبقي $left يوم',
        onRestore:()async{
         if(goals.any((g)=>g.id==goal.id||g.name==goal.name)){
          snack(ctx,waffraIsEnglish?'Goal already exists':'الهدف موجود بالفعل');
          return;
         }
         setState((){
          goals.add(goal.copy(saved:0));
          deletedGoals.remove(item);
         });
         await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
         if(!ctx.mounted)return;
         Navigator.pop(ctx);
         if(mounted)snackSuccess(context,waffraIsEnglish
          ?'Goal restored with zero savings. Past transactions are unchanged.'
          :'تم استرجاع الهدف بمدخرات صفر. جميع المعاملات القديمة المرتبطة به محفوظة في السجل المالي.');
        },
        onDeleteForever:()async{
         final yes=await confirmDeletion(
          waffraIsEnglish?'Permanently delete goal?':'حذف الهدف نهائيًا',
          waffraIsEnglish
           ?'Permanently delete “${goal.name}”? Cannot undo. Transactions stay saved.'
           :'حذف الهدف «${goal.name}» نهائيًا؟ لا يمكن التراجع. معاملاتك محفوظة.');
         if(yes!=true||!mounted)return;
         setState(()=>deletedGoals.remove(item));
         await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
         if(ctx.mounted)refresh((){});
        },
       );
      }).toList())),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
 Future<void> _handleGoalCardAction(SavingGoal g,String v)async{
        if(v=='edit'){await this.editGoal(g);return;}
        if(v=='release'){await releaseGoalFunds(g);return;}
         if(v=='delete'){
         final linked=g.saved>0||entries.any((e)=>e.category==g.name);
         final yes=await confirmDeletion(waffraIsEnglish?'Delete savings goal?':'حذف هدف الادخار',
          waffraGoalDeleteWarning(g.name,linked,waffraIsEnglish));
         if(yes==true&&mounted){
          if(_lastFinanceAuthorityRead?.source==
             WaffraRuntimeFinanceBackend.verifiedEncrypted){
           await _deleteVerifiedModule(
            module:WaffraFinanceModule.goals,displayed:g.toJson());
          }else{
           setState((){deletedGoals.add({'goal':g.toJson(),'deletedAt':DateTime.now().toIso8601String()});goals.removeWhere((x)=>x.id==g.id);});
           await persist(route:WaffraFinanceRoute.goalCreateEditDeleteRestore);
          }
         }
        }

 }
 Future<void> _m689GoalActions(SavingGoal g)async{
  await showModalBottomSheet<void>(
   context:context,showDragHandle:true,
   builder:(sheet)=>SafeArea(child:Column(
    mainAxisSize:MainAxisSize.min,children:[
     ListTile(
      title:WaffraText(g.name,style:const TextStyle(
       fontSize:18,fontWeight:FontWeight.bold)),
      subtitle:WaffraText(waffraIsEnglish?
       'Choose an action for this goal':'اختر إجراء للهدف')),
     if(g.target<=0||g.saved<g.target)ListTile(
      leading:const Icon(Icons.toll_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Save now':'ادخر الآن'),
      onTap:(){Navigator.pop(sheet);unawaited(fundGoal(g));}),
     ListTile(
      leading:const Icon(Icons.edit_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Edit goal':'تعديل الهدف'),
      onTap:(){Navigator.pop(sheet);
       unawaited(_handleGoalCardAction(g,'edit'));}),
     if(g.saved>0)ListTile(
      leading:const Icon(Icons.account_balance_wallet_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Release savings':'سحب المدخرات'),
      onTap:(){Navigator.pop(sheet);
       unawaited(_handleGoalCardAction(g,'release'));}),
     SwitchListTile.adaptive(
      key:Key('waffra-goal-active-switch-'+g.id),
      title:WaffraText(waffraIsEnglish?'Goal active':'حالة الهدف'),
      value:g.active,
      onChanged:(enabled){Navigator.pop(sheet);
       unawaited(setGoalActive(g,enabled));}),
     ListTile(
      leading:const Icon(Icons.delete_outline_rounded,color:Colors.deepOrange),
      title:WaffraText(waffraIsEnglish?'Delete goal':'حذف الهدف'),
      onTap:(){Navigator.pop(sheet);
       unawaited(_handleGoalCardAction(g,'delete'));}),
    ])));
 }
}

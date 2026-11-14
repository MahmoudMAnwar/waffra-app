part of 'main.dart';

/// M812 / Issue #633: original owner-confirmed bank SMS account/budget selectors.
/// Preserve verified bank identity, generation, explicit choice and finance guards.
extension _WaffraHomeVerifiedFinancePickers on _HomeScreenState {
 /// Read a single authoritative SQLCipher account witness immediately
 /// before posting an explicitly reviewed bank SMS. Guarded legacy keeps the
 /// existing SMS save behavior, without a shadow account database.
 Future<({List<String?>? ids,int? generation})?> reviewSmsAccountLinks(
  List<MoneyEntry> candidates,{String? recurringId,String smsSender='',
   List<String?>? initialSelectedIds})async{
  final manualRequiresAccount=candidates.any((c)=>c.sourceType=='manual');
  // A confirmed due payment is a new finance entry, not an unassigned SMS.
  final dueRequiresAccount=recurringId!=null||
   candidates.any((c)=>c.sourceType=='goal_due');
  // User-approved M470: no NEW posted income/expense, SMS, receipt or due
  // can be saved without an active account. Old unassigned history is kept.
  final mustSelectAccount=candidates.isNotEmpty;
  assert(!mustSelectAccount||manualRequiresAccount||dueRequiresAccount||
   candidates.isNotEmpty);
  final bridge=_financeBinding?.accountsBridge;
  if(bridge==null){
   if(mustSelectAccount&&mounted)snack(context,waffraIsEnglish?
    'Create a verified money account in My Accounts before adding income or expenses.':
    'أنشئ حسابًا ماليًا موثّقًا من حساباتي قبل إضافة دخل أو مصروف.',isError:true);
   return mustSelectAccount?null:(ids:null,generation:null);
  }
  if(candidates.isEmpty)return (ids:null,generation:null);
  try{
   var verified=await bridge.readVerifiedAccounts();
   if(!mounted)return null;
   var active=verified.balances.where((a)=>!a.archived).toList();
   String? createdFromSmsAccountId;
   // One owner-bound evidence snapshot governs first-time prompt and exact reuse.
   var learned=<WaffraSmsAccountEvidence>[];
   if(smsSender.isNotEmpty&&_smsRuleOwnerKey.isNotEmpty){
    try{learned=await const WaffraSmsAccountLearningStore()
     .read(_smsRuleOwnerKey);}
    catch(_){/* Missing evidence must never auto-select an account. */}
   }
   // First *reviewed* SMS from a known bank with no existing verified
   // account for that institution can offer a NEW account. Neither sender
   // text nor a suggested bank automatically creates a financial account.
   final knownBank=WaffraSmsAccountLearning.bankGroup(smsSender);
   final firstSenderIncomeExpense=knownBank!=null&&candidates.length==1&&
    candidates.single.sourceType=='sms'&&
    candidates.single.notes.trim().isNotEmpty&&
    WaffraBankSmsFactsParser.parse(candidates.single.notes)
     .canAutoPostAsIncomeExpense;
   final sameBankIdsForOffer=<String>{
    if(knownBank!=null)
     for(final account in active)
      if((account.kind=='bank'||account.kind=='wallet')&&
       (account.providerId!=null?account.providerId==knownBank:
        WaffraSmsAccountLearning.bankGroup(account.name)==knownBank))
       account.id,
   };
   final alreadyLinkedToBank=sameBankIdsForOffer.isNotEmpty;
   final firstSmsFacts=firstSenderIncomeExpense?
    WaffraBankSmsFactsParser.parse(candidates.single.notes):null;
   final identitySuffix=firstSmsFacts==null?null:
    WaffraSmsAccountLearning.suffix4(
     firstSmsFacts.kind==WaffraBankOperationKind.income?
      firstSmsFacts.destinationSuffix:firstSmsFacts.sourceSuffix);
   final verifiedIdentity=identitySuffix==null?null:
    WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
     suffix:identitySuffix,
     activeAccountIds:active.map((account)=>account.id).toSet(),
     sameBankAccountIds:sameBankIdsForOffer);
   // A second account at the SAME bank is a new identity with different
   // last four. First time: choose an existing account or create a new one.
   // A previously confirmed exact sender+four must not be prompted again.
   final needsNewIdentityChoice=firstSenderIncomeExpense&&
    (!alreadyLinkedToBank||
     (identitySuffix!=null&&verifiedIdentity==null));
   if(needsNewIdentityChoice&&
       (initialSelectedIds==null||initialSelectedIds.every((id)=>id==null))){
    final offered=await showWaffraDialog<bool>(
     context:context,builder:(dialog)=>AlertDialog(
      title:WaffraText(waffraIsEnglish?
       'Create an account for this bank?':
       'إنشاء حساب مالي لهذا البنك؟'),
      content:WaffraText(waffraIsEnglish?
       'Bank identity "$smsSender"'+
        (identitySuffix==null?'':' ••••$identitySuffix')+
        ' needs account confirmation. Choose an existing bank account or '
        'create a new one with an editable 0 SAR opening balance. '
        'No transaction is posted without consent.':
       'هوية البنك "$smsSender"'+
        (identitySuffix==null?'':' ••••$identitySuffix')+
        ' محتاجة ربط أول مرة. اختار حساب موجود أو أنشئ حساب بنكي جديد '
        'برصيد افتتاحي صفر ريال قابل للتعديل. '
        'لن تُسجل العملية من غير موافقتك.'),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog,false),
        child:WaffraText(waffraIsEnglish?'Choose existing':'اختيار حساب موجود')),
       FilledButton(onPressed:()=>Navigator.pop(dialog,true),
        child:WaffraText(waffraIsEnglish?'Add account':'إضافة حساب')),
      ],
     ));
    if(!mounted)return null;
    if(offered==true){
     // M483 / #407: prefill only the masked source for outgoing
     // transactions or masked destination for incoming transactions.
     // Nothing is linked or posted until the user explicitly confirms.
     final verifiedFacts=WaffraBankSmsFactsParser.parse(
      candidates.single.notes);
     final reviewedIncome=verifiedFacts.kind==WaffraBankOperationKind.income;
     final proposedSuffix=WaffraSmsAccountLearning.suffix4(
      reviewedIncome?verifiedFacts.destinationSuffix:
       verifiedFacts.sourceSuffix);
     final savedCustomTypes=active.where((account)=>
       account.kind=='bank'&&account.customSubtypeLabel!=null)
       .map((account)=>account.customSubtypeLabel!).toSet().toList()..sort();
     final draft=await showWaffraDialog<WaffraNewAccountDraft>(
      context:context,builder:(dialog)=>WaffraNewAccountDialog(
       english:waffraIsEnglish,suggestedProviderId:knownBank,
       suggestedSenderName:smsSender,suggestedLastFour:proposedSuffix,
       customSubtypeOptions:{'bank':savedCustomTypes}));
     if(!mounted)return null;
     if(draft!=null){
      // Users may edit the form. Never silently approve a different bank
      // than the reviewed sender or convert a bank SMS to a cash account.
      if(draft.kind!='bank'||draft.providerId!=knownBank||
         draft.subtype==null)throw StateError(
        'New SMS account does not match verified sender institution.');
      final id='m470-sms-'+DateTime.now().microsecondsSinceEpoch.toString();
      final createdIso=DateTime.now().toUtc().toIso8601String();
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      await api.balances();
      await api.createTypedAccountWithIdentity(
       id:id,name:draft.name,kind:'bank',providerId:knownBank,
       subtype:draft.subtype!,openingMinor:draft.openingMinor,
       createdIso:createdIso,lastFour:draft.lastFour,
       customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
      // A bank account creation is one verified SQLCipher transaction.
      // The later SMS posting is a SEPARATE user-confirmed transaction;
      // failure cannot debit twice or erase the newly confirmed account.
      await _refreshFromVerifiedFinance();
      if(!mounted||_financeLoadFailure!=null)return null;
      verified=await bridge.readVerifiedAccounts();
      active=verified.balances.where((a)=>!a.archived).toList();
      if(!active.any((a)=>a.id==id))throw StateError(
       'Created SMS account was not verified after save.');
      createdFromSmsAccountId=id;
     }
    }
   }
   if(active.isEmpty){
    if(mustSelectAccount){
     snack(context,waffraIsEnglish?
      'Add at least one bank, cash, or wallet account in My Accounts first.':
      'لازم تضيف حسابًا ماليًا واحدًا على الأقل من حساباتي أولًا.',isError:true);
     return null;
    }
    return (
     ids:List<String?>.filled(candidates.length,null),
     generation:verified.witness.generation);
   }
   final assigned=List<String?>.filled(candidates.length,null);
   if(createdFromSmsAccountId!=null){
    assigned[0]=createdFromSmsAccountId;
   }
   if(initialSelectedIds!=null){
    if(initialSelectedIds.length!=candidates.length)return null;
    for(var index=0;index<assigned.length;index++){
     final requested=initialSelectedIds[index];
     if(requested==null)continue;
     if(!active.any((a)=>a.id==requested))return null;
     assigned[index]=requested;
    }
   }
   // Only verified masked bank evidence can suggest a specific SMS account.
   // Manual, recurring, goal-due and uncertain bank messages stay unassigned
   // until the user makes an explicit choice; never inherit Home's header.
   final accountEvidence=WaffraVerifiedAccountsApi(bridge:bridge);
   // Sender-only learning needs two confirmations AND exactly one account
   // whose user-chosen bank name matches the sender. No sender guesses for
   // two accounts at the same bank; suffix evidence remains authoritative.
   // Reuse the evidence snapshot read before the first-identity prompt.
   final bankGroup=WaffraSmsAccountLearning.bankGroup(smsSender);
   final sameBankIds=<String>{
    if(bankGroup!=null)
     for(final account in active)
      if((account.kind=='bank'||account.kind=='wallet')&&
         (account.providerId!=null?account.providerId==bankGroup:
          WaffraSmsAccountLearning.bankGroup(account.name)==bankGroup))
       account.id,
   };
   final activeAccountIds=active.map((account)=>account.id).toSet();
   // A recurring template owns its default, not the active Home header.
   // A change in this review applies to this payment only; users manage
   // future defaults separately in Accounts -> Recurring defaults.
   if(recurringId!=null&&candidates.length==1){
    try{
     final saved=await accountEvidence.recurringDefaultAccount(recurringId);
     if(saved!=null&&active.any((a)=>a.id==saved))assigned[0]=saved;
    }catch(_){
     // Missing/unverified template means explicit choice or unassigned.
    }
   }
   for(var i=0;i<candidates.length;i++){
    final item=candidates[i];
    if(assigned[i]!=null||item.sourceType!='sms'||item.notes.trim().isEmpty)continue;
    final facts=WaffraBankSmsFactsParser.parse(item.notes);
    if(!facts.canAutoPostAsIncomeExpense||
       (facts.kind==WaffraBankOperationKind.income)!=item.income)continue;
    try{
     final exactFour=WaffraSmsAccountLearning.suffix4(
      item.income?facts.destinationSuffix:facts.sourceSuffix);
     final previouslyConfirmed=exactFour==null?null:
      WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
       suffix:exactFour,activeAccountIds:activeAccountIds,
       sameBankAccountIds:sameBankIds);
     if(previouslyConfirmed!=null){assigned[i]=previouslyConfirmed;continue;}
     final match=await accountEvidence.suggestSmsAccount(facts);
     if(match.confident&&match.accountId!=null&&
        bankGroup!=null&&sameBankIds.contains(match.accountId)&&
        active.any((a)=>a.id==match.accountId)){
      // A suffix by itself cannot prove the SMS belongs to this sender's bank.
      assigned[i]=match.accountId;
     }
    }catch(_){
     // Suggestion failure must never guess or silently link an account.
    }
   }
   if(!mounted)return null;
   // M475 #412: don't ask for the same money account twice after an
   // explicit entry-editor choice or user-approved account creation.
   final allEditorAccountsConfirmed=initialSelectedIds!=null&&
    initialSelectedIds.length==assigned.length&&
    initialSelectedIds.every((id)=>id!=null);
   final newAccountConfirmed=createdFromSmsAccountId!=null&&
    candidates.length==1;
   // Only a previously owner-confirmed, exact sender+four identity may
   // bypass REPEATING account linking. The finance writer still requires
   // the owner's transaction Yes and a fresh SQLCipher account witness.
   final exactSmsIdentityConfirmed=candidates.length==1&&
    assigned.single!=null&&candidates.single.sourceType=='sms'&&
    WaffraSmsAccountLearning.suggest(learned,sender:smsSender,
     suffix:WaffraSmsAccountLearning.suffix4(
      candidates.single.income?
       WaffraBankSmsFactsParser.parse(candidates.single.notes).destinationSuffix:
       WaffraBankSmsFactsParser.parse(candidates.single.notes).sourceSuffix),
     activeAccountIds:activeAccountIds,
     sameBankAccountIds:sameBankIds)==assigned.single;
   if((allEditorAccountsConfirmed||newAccountConfirmed||
      exactSmsIdentityConfirmed)&&assigned.every((id)=>id!=null)){
    // Read a fresh SQLCipher account witness, not a stale picker snapshot.
    final latest=await bridge.readVerifiedAccounts();
    final liveIds=latest.balances.where((a)=>!a.archived)
     .map((a)=>a.id).toSet();
    if(!assigned.every((id)=>liveIds.contains(id))){
     if(mounted)snack(context,waffraIsEnglish?
      'Selected account changed; choose it again before saving.':
      'الحساب المختار اتغير؛ اختاره مرة تانية قبل الحفظ.',isError:true);
     return null;
    }
    return (ids:List<String?>.unmodifiable(assigned),
     generation:latest.witness.generation);
   }
   final providerGroups=WaffraRecurringAccountGroups.fromAccounts(active);
   final chosenProviders=List<String?>.generate(assigned.length,(index){
    for(final group in providerGroups){
     if(group.accounts.any((a)=>a.id==assigned[index]))return group.id;
    }
    return null;
   });
   final approved=await showWaffraDialog<bool>(context:context,
    builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
     title:WaffraText(mustSelectAccount?
      (waffraIsEnglish?'Choose a money account':'اختار الحساب المالي للعملية'):
      (waffraIsEnglish?
       'Which account for each bank transaction?':
       'تسجيل كل معاملة بنكية في أي حساب؟')),
     content:SizedBox(width:double.maxFinite,
      height:waffraKeyboardDialogListHeight(ctx,desired:500),
      child:ListView(children:[
       WaffraText(recurringId!=null
        ?(waffraIsEnglish
          ?'This selection is for this payment only. Change future defaults from Accounts.'
          :'الاختيار لهذه الدفعة فقط. غيّر الحساب للدفعات القادمة من الحسابات.')
        :manualRequiresAccount?
         (waffraIsEnglish?
          'Manual income and expenses must use an existing money account.':
          'الدخل والمصروف اليدوي لازم يرتبطوا بحساب مالي موجود.')
        :(waffraIsEnglish
          ?'Choose a verified money account; new entries cannot be unassigned.'
          :'اختار حسابًا ماليًا موثّقًا لكل عملية؛ الحفظ بدون حساب غير مسموح.')),
       const SizedBox(height:12),
       for(var n=0;n<candidates.length;n++)
        Padding(padding:const EdgeInsets.only(bottom:12),
         child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          WaffraText(candidates[n].title+' · '+cash(candidates[n].amount),
           maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold)),
          const SizedBox(height:5),
          WaffraCenteredDropdownFormField<String>(
           key:ValueKey('m470-review-provider-'+n.toString()+'-'+
            (chosenProviders[n]??'none')),
           initialValue:chosenProviders[n],isExpanded:true,
           menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
           decoration:InputDecoration(
            labelText:waffraIsEnglish?'Bank or provider':'الجهة أو البنك',
            border:const OutlineInputBorder()),
           items:providerGroups.map((group)=>DropdownMenuItem<String>(
            value:group.id,child:WaffraText(waffraIsEnglish?
             group.labelEn:group.labelAr,maxLines:1))).toList(),
           onChanged:WaffraHaptics.selection((value)=>update((){
            chosenProviders[n]=value;
            assigned[n]=null; // Provider never silently approves an account.
           })),
          ),
          const SizedBox(height:7),
          WaffraCenteredDropdownFormField<String>(
           key:ValueKey('waffra-sms-account-'+n.toString()+'-'+
            (assigned[n]??'none')),
           initialValue:mustSelectAccount?
            assigned[n]:assigned[n]??'none',isExpanded:true,
           menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
           decoration:InputDecoration(
            labelText:waffraIsEnglish?'Money account':'الحساب المالي',
            border:const OutlineInputBorder()),
           items:providerGroups.where((p)=>p.id==chosenProviders[n])
            .expand((p)=>p.accounts).map((a)=>DropdownMenuItem(
             value:a.id,child:WaffraText(a.name,maxLines:1))).toList(),
           onChanged:chosenProviders[n]==null?null:
            WaffraHaptics.selection((value)=>update(
             ()=>assigned[n]=value)),
          ),
         ])),
      ])),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(
       onPressed:mustSelectAccount&&assigned.any((account)=>account==null)?
        null:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
       child:WaffraText(waffraIsEnglish?'Confirm':'تأكيد')),
     ],
    )));
   if(approved!=true)return null;
   if(mustSelectAccount&&assigned.any((account)=>account==null))return null;
   return (ids:List<String?>.unmodifiable(assigned),
    generation:verified.witness.generation);
  }catch(_){
   if(mounted)snack(context,waffraIsEnglish?
    'Accounts could not be verified. Open My accounts before saving.':
    'تعذر التحقق من الحسابات. افتح حساباتي قبل حفظ العملية.');
   return null;
  }
 }
/// Budget assignment is OPTIONAL in every bank import: no assignment never blocks saving.
 Future<List<String?>?> reviewSmsBudgetLinks(List<MoneyEntry> candidates)async{
  final choices=namedBudgets.where((b)=>
   !b.deleted&&b.budget>0&&b.budgetActive).toList();
  final assigned=List<String?>.filled(candidates.length,null);
  if(!candidates.any((e)=>!e.income)||choices.isEmpty)return assigned;
  return showWaffraDialog<List<String?>>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose budgets for expenses':'تسجيل كل مصروف في أي ميزانية؟'),
    content:SizedBox(width:double.maxFinite,
     height:waffraKeyboardDialogListHeight(ctx,desired:500),
     child:ListView(children:[
      WaffraText(waffraIsEnglish?
       'Choose a budget for each expense, or leave it unlinked.':
       'اختار ميزانية لكل مصروف، أو سيبه بدون ربط.'),
      const SizedBox(height:12),
      for(var n=0;n<candidates.length;n++)
       if(!candidates[n].income)Padding(
        padding:const EdgeInsets.only(bottom:12),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         WaffraText(candidates[n].title+' · '+cash(candidates[n].amount),
          style:const TextStyle(fontWeight:FontWeight.bold),maxLines:2),
         const SizedBox(height:5),
         WaffraCenteredDropdownFormField<String>(
          key:ValueKey('waffra-sms-budget-'+n.toString()+'-'+(assigned[n]??'none')),
          menuMaxHeight:min(340.0,MediaQuery.sizeOf(ctx).height*.48),
          initialValue:assigned[n]??'none',isExpanded:true,
          decoration:InputDecoration(labelText:waffraIsEnglish?'Budget':'الميزانية',
           border:const OutlineInputBorder()),
          items:[
           DropdownMenuItem(value:'none',child:WaffraText(
            waffraIsEnglish?'Without a budget':'بدون ميزانية',maxLines:1)),
           ...choices.map((c)=>DropdownMenuItem(value:c.id,child:WaffraText(
            c.budgetLabel??'ميزانية '+c.displayName,maxLines:1))),
          ],
          onChanged:WaffraHaptics.selection((value)=>update(
           ()=>assigned[n]=value=='none'?null:value)),
         ),
         Align(alignment:AlignmentDirectional.centerStart,
          child:TextButton.icon(
           key:Key('waffra-sms-batch-create-budget-'+n.toString()),
           icon:const Icon(Icons.add_circle_outline_rounded,size:17),
           label:WaffraText(waffraIsEnglish?
            'Create new budget':'إنشاء ميزانية جديدة'),
           onPressed:WaffraHaptics.tap(()async{
            final id=await chooseBudgetCategory();
            if(id==null||!ctx.mounted)return;
            final found=namedBudgets.where((b)=>b.id==id&&
             b.budget>0&&b.budgetActive&&!b.deleted).toList();
            if(found.length!=1)return;
            update((){
             choices
              ..clear()
              ..addAll(namedBudgets.where((b)=>
               b.budget>0&&b.budgetActive&&!b.deleted));
             assigned[n]=id;
            });
           }),
          )),
        ])),
     ])),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Cancel batch':'إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap(()async{
      final unlinked=List<int>.generate(candidates.length,(i)=>i)
       .where((i)=>!candidates[i].income&&assigned[i]==null).length;
      if(unlinked>0){
       final confirmed=await waffraConfirmUnlinkedBudgetSave(
        context:ctx,expenseCount:unlinked);
       if(!confirmed||!ctx.mounted)return;
      }
      if(ctx.mounted)Navigator.pop(ctx,List<String?>.from(assigned));
     }),
      child:WaffraText(waffraIsEnglish?
       'Continue saving':'متابعة الحفظ')),
    ],
   )));
 }
}

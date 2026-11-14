part of 'main.dart';

/// M762 / Issue #633: original authenticated finance persistence and recurring dues.
/// SQLCipher ownership, saved balances and user-confirmed writes are unchanged.
extension _WaffraHomeFinancePersistenceDue on _HomeScreenState {
 Future<void> persist({
  WaffraFinanceRoute route = WaffraFinanceRoute.transactionEdit,
  bool userConfirmed = false,
  String? selectedAccountId,
 }) {
  // Freeze a snapshot BEFORE any await. Previously Future.wait launched
  // overlapping multi-key saves, so a slower old save could finish last.
  // This protects in-app ordering, not cross-process widget writes or a crash
  // in the middle of SharedPreferences' non-atomic multi-key update.
  // Snapshot immutable final-field MoneyEntry references before ANY await.
  // The expensive per-entry toJson conversion now runs after the spinner
  // frame and off the UI isolate for large ledgers, without moving the
  // source snapshot capture past another pending write.
  final frozenEntries=List<MoneyEntry>.unmodifiable(entries);
  final snapshot=<String,Object>{
   'entries':'', // replaced by the exact frozen payload under the save overlay
   // Migrate old category caps together with the independent budget list.
   // Historic ledger budget IDs are kept unchanged.
   'waffra_categories_v24':jsonEncode(categories.map((c)=>
    route==WaffraFinanceRoute.challengeAndBudgetUpdate&&
    c.budget>0&&namedBudgets.any((b)=>b.id==c.id)?
     c.copy(budget:0,clearBudget:true).toJson():c.toJson()).toList()),
   'waffra_named_budgets_v1':jsonEncode(
    namedBudgets.map((b)=>b.toJson()).toList()),
   'waffra_goals_v24':jsonEncode(goals.map((e)=>e.toJson()).toList()),
   'waffra_recurring_v24':jsonEncode(recurring.map((e)=>e.toJson()).toList()),
   'waffra_challenges_v1':jsonEncode(challenges.map((e)=>e.toJson()).toList()),
   'waffra_deleted_categories_v1':jsonEncode(deletedCategories),
   'waffra_deleted_goals_v1':jsonEncode(deletedGoals),
   'waffra_deleted_recurring_v1':jsonEncode(deletedRecurring),
   'waffra_recurring_postponed_v1':jsonEncode(recurringPostponed),
   'waffra_monthly_budget_v1':monthlyBudget,
   'waffra_monthly_budget_enabled_v1':monthlyBudgetEnabled,
   'waffra_learned_merchants_v1':jsonEncode(learnedMerchantCategories),
  };
  final baseline=_lastFinanceAuthorityRead;
  // Fresh verified SQLCipher vaults intentionally omit optional empty modules.
  // A manual append may change ONLY the ledger; the authoritative writer
  // still checks its exact witness and the one-entry append invariant.
  final previousWrite=_m468PersistSequence;
  final saving=_saveProgress.track<void>(
   'persist-financial-change',() async {
   // The frozen capture cannot overtake an earlier confirmed finance write.
   await previousWrite;
   // The overlay is on screen; move large JSON serialization off the UI
   // isolate without changing a single byte or the source witness.
   snapshot['entries']=frozenEntries.length>=
     WaffraLargeJsonDecode.encodeRowThreshold
      ?await compute(MoneyEntry.encodeFrozenSnapshot,frozenEntries)
      :await WaffraLargeJsonDecode.encodeRecords(
       frozenEntries.map((e)=>e.toJson()).toList(growable:false));
   WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
    route:route,source:baseline?.source,snapshot:snapshot);
   WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
    route:route,source:baseline?.source,snapshot:snapshot,
    witnessedValues:baseline?.encryptedWitness?.snapshot.values);
   return _financialWriteQueue.submit(snapshot,(captured)async {
   if(baseline==null){
    throw StateError('Verified dashboard baseline is unavailable.');
   }
   // One source-aware write entry point for the entire Home finance capture.
   // Every individual category/goal/recurring editor funnels through here.
   // The selected SQLCipher source and witness are rechecked before writing.
   await _ensureFinanceBound();
   final committed=await _financeAuthority.saveCaptured(
    route:route,
    baseline:baseline,
    captured:captured,
    userConfirmed:userConfirmed,
    selectedAccountId:selectedAccountId,
   );
   _lastFinanceAuthorityRead=committed;
   _lastLedgerSavedRaw=committed.ledgerRaw;
   _lastWidgetRevision=committed.widgetRevision;
  }).then((_){unawaited(_refreshWidget());});
  });
  _m468PersistSequence=saving.then<void>(
   (_){},onError:(Object error,StackTrace stack){});
  return saving;
 }

 /// Optimistic UI updates must never masquerade as committed finance.
 /// A failed verified writer may have left a newer authoritative state, so
 /// read it back rather than blindly restoring a stale in-memory snapshot.
 Future<bool> _persistModuleOrReload(
   WaffraFinanceRoute route,{required String operation})async{
  try{
   await persist(route:route);
   return true;
  }catch(error){
   debugPrint('Verified $operation write refused: $error');
   if(mounted)await _refreshFromVerifiedFinance();
   if(mounted)snack(context,waffraIsEnglish?
    'Changes were not confirmed. Financial records were reloaded safely.':
    'لم يتم تأكيد الحفظ. أعدنا تحميل بياناتك المالية بشكل آمن.');
   return false;
  }
 }

 Future<void> _persistSmsHashes(Set<String> hashesToSave)async {
  // Home and Widget now merge only SHA-256 fingerprints through the same
  // source selector. SQLCipher activation cannot fall back to preferences.
  await _ensureFinanceBound();
  final committed=await _financeAuthority.mergeSmsHashes(hashesToSave);
  _lastFinanceAuthorityRead=committed;
  _lastLedgerSavedRaw=committed.ledgerRaw;
  _lastWidgetRevision=committed.widgetRevision;
  smsHashes..clear()..addAll(
   committed.finance.getStringList('waffra_sms_hashes_v1')??const <String>[]);
 }

 Future<void> syncRecurringReminders()async {
  if(!recurringRemindersEnabled)return;
  try {
   await WaffraReminders.schedule(
    recurring.where((r)=>r.active&&waffraCategoryNameAvailableForPosting(
     categories,r.income,r.category)&&(r.linkedGoalId==null||
      goals.any((g)=>g.id==r.linkedGoalId&&g.dueDate!=null)))
     .map((r)=>WaffraReminder(id:r.id,title:r.title,day:r.day,
      startAt:r.startAt,
      oneTimeDueAt:r.linkedGoalId==null?null:r.startAt)).toList(),
    english:waffraIsEnglish);
  }catch(e){debugPrint('Reminder scheduling failed: $e');}
 }
 Future<void> toggleRecurringReminders(bool enabled,
   {bool permissionAlreadyGranted=false})async {
  if(enabled){
   try {
    final granted=permissionAlreadyGranted?
     await WaffraReminders.alreadyPermitted():
     await WaffraReminders.requestPermission();
    if(!granted){
     if(mounted)snack(context,waffraIsEnglish?
      'Allow notifications in Android settings to enable reminders.':
      'يرجى السماح بالإشعارات في إعدادات أندرويد لتفعيل التذكيرات.');
     return;
    }
   }catch(e){
    if(mounted)snack(context,waffraIsEnglish?'Could not activate reminders.':'تعذر تفعيل التذكيرات.');
    return;
   }
  }
  await _ensureFinanceBound();
  final committed=await _financeAuthority.setRecurringReminderPreference(enabled);
  _lastFinanceAuthorityRead=committed;
  _lastLedgerSavedRaw=committed.ledgerRaw;
  _lastWidgetRevision=committed.widgetRevision;
  if(!mounted)return;
  setState(()=>recurringRemindersEnabled=enabled);
  try {
   if(enabled)await syncRecurringReminders();
   else await WaffraReminders.clear();
  }catch(e){debugPrint('Reminder toggle failed: $e');}
 }

 // No recurring schedule may post money without a user's explicit confirmation.
 Future<void> applyRecurring()async {
  if(!mounted||!ready||_dueDialogShowing)return;
  final today=DateTime.now();
  for(final r in recurring){
   if(!r.active||!waffraCategoryNameAvailableForPosting(
    categories,r.income,r.category))continue;
   // A goal is a one-time obligation. Its immutable original due month
   // remains the same even when the user returns to the app much later.
   final isGoalDue=r.linkedGoalId!=null;
   final linkedGoals=isGoalDue?
    goals.where((g)=>g.id==r.linkedGoalId&&g.dueDate!=null).toList():
    <SavingGoal>[];
   if(isGoalDue&&linkedGoals.length!=1)continue;
   final linkedAccount=r.accountId==null
    ?const <WaffraAccountBalance>[]
    :_m467Accounts.where((a)=>a.id==r.accountId&&!a.archived).toList();
   final accountLabel=linkedAccount.length==1?
    linkedAccount.single.name:(r.accountId==null?null:
     (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'));
   final due=isGoalDue?
    DateTime(r.startAt.year,r.startAt.month,r.startAt.day):
    WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
   final goalPreview=isGoalDue?WaffraGoalDueAllocation.allocate(
    dueAmount:r.amount,goalSaved:linkedGoals.single.saved):null;
   final id=WaffraRecurringPolicy.entryId(r.id,due);
   final postponed=DateTime.tryParse(recurringPostponed[id]??'');
   if(!WaffraRecurringPolicy.isOutstanding(
       due:due,today:today,startAt:r.startAt,
       alreadyPaid:entries.any((e)=>e.id==id),postponedUntil:postponed))continue;
   _dueDialogShowing=true;
   try{
    final action=await showWaffraDialog<String>(context:context,
     builder:(ctx)=>AlertDialog(
      title:Column(mainAxisSize:MainAxisSize.min,children:[
       const Icon(Icons.event_repeat_rounded,color:emerald,size:34),
       const SizedBox(height:8),
       WaffraText(isGoalDue?
        (waffraIsEnglish?'Savings goal payment due':'استحقاق هدف ادخار'):
        (waffraIsEnglish?'Recurring payment due':'عملية متكررة مستحقة'),
        textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w800,fontSize:20)),
      ]),
      content:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraText(r.title,textAlign:TextAlign.center,
        style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)),
       const SizedBox(height:12),
       Directionality(textDirection:TextDirection.ltr,
        child:Center(child:WaffraText(cash(r.amount),
         style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)))),
       const SizedBox(height:12),
       Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        const Icon(Icons.calendar_today_outlined,size:17,color:emerald),
        const SizedBox(width:7),
        WaffraText(waffraIsEnglish?'Due: ':'تاريخ الاستحقاق: '),
        Directionality(textDirection:TextDirection.ltr,
         child:Text(dayText(postponed??due))),
       ]),
       if(accountLabel!=null)...[
        const SizedBox(height:8),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
         const Icon(Icons.account_balance_wallet_outlined,size:16,color:emerald),
         const SizedBox(width:6),
         Flexible(child:WaffraText(
          (waffraIsEnglish?'Linked account: ':'الحساب المرتبط: ')+accountLabel,
          maxLines:2,textAlign:TextAlign.center)),
        ]),
       ],
       const SizedBox(height:15),
       if(goalPreview!=null)...[
        const SizedBox(height:8),
        WaffraText(waffraIsEnglish?
         'Goal wallet: ${cash(goalPreview.fromGoalWallet)} • '
         'Spendable cash: ${cash(goalPreview.fromCurrentBalance)}':
         'من محفظة الهدف: ${cash(goalPreview.fromGoalWallet)} • '
         'من الرصيد الحالي: ${cash(goalPreview.fromCurrentBalance)}',
         textAlign:TextAlign.center,
         style:const TextStyle(fontSize:12,color:emerald)),
        const SizedBox(height:8),
       ],
       WaffraText(isGoalDue?
        (waffraIsEnglish?
         'Record this goal payment once, or postpone it?':
         'هل تم دفع استحقاق الهدف؟ أكّد الخصم مرة واحدة أو أجّل الموعد.'):
        (waffraIsEnglish?
         'Have you paid, or would you like to postpone?':
         'هل تم الدفع، أم ترغب في تأجيل الاستحقاق؟'),
        textAlign:TextAlign.center),
      ]),
      actionsAlignment:MainAxisAlignment.center,
      actionsPadding:const EdgeInsets.fromLTRB(12,0,12,16),
      actions:[SizedBox(width:min(330.0,MediaQuery.sizeOf(ctx).width-80),
       child:Row(children:[
        Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'later')),
         child:WaffraText(waffraIsEnglish?'Not now':'ليس الآن',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
        const SizedBox(width:5),
        Expanded(child:OutlinedButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'postpone')),
         child:WaffraText(waffraIsEnglish?'Postpone':'تأجيل',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
        const SizedBox(width:5),
        Expanded(child:FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,'paid')),
         child:WaffraText(waffraIsEnglish?'Paid':'تم الدفع',
          maxLines:1,style:const TextStyle(fontSize:11.5)))),
       ]))],
     ));
    if(!mounted)return;
    if(action=='paid'){
     if(isGoalDue){
      if(_lastFinanceAuthorityRead?.source==
        WaffraRuntimeFinanceBackend.verifiedEncrypted){
       final cashMinor=WaffraRecurringPolicy.toHalalas(r.amount)-
        goalPreview!.fromGoalMinor;
       final activeAccounts=await _m641VerifiedGoalRecurringAccounts();
       if(activeAccounts==null||!mounted)return;
       final defaultId=r.accountId;
       if(defaultId!=null&&
          !activeAccounts.any((a)=>a.id==defaultId&&!a.archived)){
        snack(context,waffraIsEnglish?
         'The goal account is unavailable. Edit the goal before paying.':
         'الحساب المرتبط بالهدف غير متاح. عدّل حساب الهدف قبل تسجيل الدفع.',
         isError:true);
        return;
       }
       // The linked goal account is the default; don't require another
       // picker or debit saved funds twice. Old unlinked goals still ask.
       final chosen=cashMinor>0&&defaultId==null?
        await reviewSmsAccountLinks([
         MoneyEntry(id:id,title:r.title,category:r.category,
          amount:r.amount,income:false,date:DateTime.now(),
          sourceType:'goal_due',goalWalletPaidMinor:goalPreview.fromGoalMinor)]):null;
       if(cashMinor>0&&defaultId==null&&chosen==null)return;
       final chosenId=defaultId??chosen?.ids?.single;
       if(cashMinor>0&&chosenId==null)return;
       if(chosen!=null&&chosenId!=null&&chosen.generation!=
          _lastFinanceAuthorityRead?.encryptedWitness?.generation){
        if(mounted)await _loadFinanceSafely();
        if(mounted)snack(context,waffraIsEnglish?
         'Account changed; review the goal due again.':
         'الحساب اتغير؛ راجع استحقاق الهدف مرة تانية.');
        return;
       }
       try{
        await _financialWriteQueue.drain();
        final baseline=_lastFinanceAuthorityRead;
        if(baseline==null||baseline.encryptedWitness==null){
         throw StateError('Verified goal due witness unavailable.');
        }
        await _saveProgress.track('settle-verified-goal-due',()=>
         _financeAuthority.settleLinkedGoalDue(
          baseline:baseline,goalId:r.linkedGoalId!,recurringId:r.id,
          dueKey:id,amountMinor:WaffraRecurringPolicy.toHalalas(r.amount),
          confirmedAtIso:DateTime.now().toIso8601String(),
          userConfirmed:true,selectedAccountId:chosenId));
        if(mounted)await _loadFinanceSafely();
        if(mounted)await syncRecurringReminders();
       }catch(error){
        debugPrint('Goal due SQLCipher commit rejected: $error');
        if(mounted)await _loadFinanceSafely();
        if(mounted)snack(context,waffraIsEnglish?
         'Goal payment was not verified. Reload before retrying.':
         'لم يتم تأكيد استحقاق الهدف؛ أعد تحميل البيانات قبل المحاولة.');
       }
       return;
      }
      // The same deterministic recurring ID cannot settle a goal twice.
      if(entries.any((e)=>e.id==id))continue;
      final currentGoal=goals.where((g)=>g.id==r.linkedGoalId).toList();
      final currentSchedule=recurring.where((x)=>x.id==r.id&&x.active).toList();
      if(currentGoal.length!=1||currentSchedule.length!=1){
       snack(context,waffraIsEnglish?
        'Goal or due date changed; refresh before paying.':
        'الهدف أو موعده اتغير؛ حدّث البيانات قبل تسجيل الدفع.');
       return;
      }
      final allocation=WaffraGoalDueAllocation.allocate(
       dueAmount:r.amount,goalSaved:currentGoal.single.saved);
      if(allocation.fromGoalMinor!=goalPreview!.fromGoalMinor||
        currentSchedule.single.startAt!=r.startAt){
       snack(context,waffraIsEnglish?
        'Wallet allocation changed. Reopen and confirm the new split.':
        'توزيع الدفع اتغير؛ افتح الاستحقاق وراجع المبالغ قبل التأكيد.');
       return;
      }
      // A confirmed goal settlement changes ledger, goal and schedule in
      // the guarded legacy batch. Encrypted mode is refused above until a
      // separately audited atomic SQLCipher writer supports this exact delta.
      setState((){
       final goalIndex=goals.indexWhere((g)=>g.id==r.linkedGoalId);
       final scheduleIndex=recurring.indexWhere((x)=>x.id==r.id);
       goals[goalIndex]=currentGoal.single.copy(
        saved:allocation.remainingGoalSavings);
       recurring[scheduleIndex]=currentSchedule.single.copy(active:false);
       recurringPostponed.remove(id);
       _m684InvalidatePeriodRead();
       entries.insert(0,MoneyEntry(
        id:id,title:r.title,category:r.category,
        amount:allocation.amount,income:false,date:DateTime.now(),
        sourceType:'goal_due',goalWalletPaidMinor:allocation.fromGoalMinor,
        notes:waffraIsEnglish?
         'From goal wallet: ${cash(allocation.fromGoalWallet)}; '
         'from current balance: ${cash(allocation.fromCurrentBalance)}':
         'من محفظة الهدف: ${cash(allocation.fromGoalWallet)}؛ '
         'من الرصيد الحالي: ${cash(allocation.fromCurrentBalance)}'));
      });
      try{
       // The guarded source checks the loaded finance witness; a failed
       // multi-module save is reloaded rather than assuming success.
       await persist(route:WaffraFinanceRoute.transactionEdit,
        userConfirmed:true);
       if(mounted)await syncRecurringReminders();
      }catch(error){
       debugPrint('Goal due settlement could not be confirmed: $error');
       if(mounted)await _loadFinanceSafely();
       if(mounted)snack(context,waffraIsEnglish?
        'Goal payment not confirmed. Records refreshed safely.':
        'لم يتم تأكيد خصم استحقاق الهدف؛ أعدنا تحميل البيانات بأمان.');
       return;
      }
     }else{
      // Select the destination/source money account BEFORE changing the
      // in-memory ledger. A cancellation does not post or clear postponement.
      final chosen=await reviewSmsAccountLinks([MoneyEntry(
       id:id,title:r.title,category:r.category,amount:r.amount,
       income:r.income,date:DateTime.now(),sourceType:'recurring')],
       recurringId:r.id);
      if(chosen==null)return;
      if(!entries.any((e)=>e.id==id)){
       _m684InvalidatePeriodRead();
       setState(()=>entries.insert(0,MoneyEntry(
        id:id,title:r.title,category:r.category,amount:r.amount,
        income:r.income,date:DateTime.now(),sourceType:'recurring')));
      }
      recurringPostponed.remove(id);
      // SQLCipher commits the posted due, cleared postponement, and account
      // link atomically; guarded legacy preserves its existing safe writer.
      try{
       await persist(route:WaffraFinanceRoute.recurringPostingAndPostponement,
        userConfirmed:true,selectedAccountId:chosen.ids?.single);
      }catch(error){
       debugPrint('Recurring payment commit could not be confirmed: $error');
       if(mounted)await _loadFinanceSafely();
       if(mounted)snack(context,waffraIsEnglish?
        'Payment not confirmed. Records refreshed; check before retrying.':
        'لم يتم تأكيد الدفع. تم تحديث البيانات؛ تحقق منها قبل إعادة المحاولة.');
       return;
      }
     }
    }else if(action=='postpone'){
     final selected=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:today.add(const Duration(days:1)),
      firstDate:DateTime(today.year,today.month,today.day).add(const Duration(days:1)),
      lastDate:DateTime(today.year+3,12,31));
     if(selected!=null){
      recurringPostponed[id]=selected.toIso8601String();
      if(!await _persistModuleOrReload(
       WaffraFinanceRoute.recurringPostingAndPostponement,
       operation:'recurring-postpone'))return;
     }
    }else{return;}
   }finally{_dueDialogShowing=false;}
  }
 }
}

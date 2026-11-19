part of 'main.dart';

/// M770 / Issue #633: original verified bank-SMS review and confirmation.
/// No UI, encrypted ledger, owner, SAR/date, hash or ACK behavior changes.
extension _WaffraHomeSmsConfirmation on _HomeScreenState {
 Future<List<MoneyEntry>> _m593BuildVerifiedEntries(List<dynamic> raw)async{
  final items=<MoneyEntry>[];
  const batchSize=96;
  for(var at=0;at<raw.length;at+=batchSize){
   final end=min(at+batchSize,raw.length);
   for(var i=at;i<end;i++){
    final row=raw[i];
    if(row is! Map)throw const FormatException(
     'Invalid verified financial record');
    items.add(MoneyEntry.fromJson(Map<String,dynamic>.from(row)));
   }
   if(end<raw.length){
    await Future<void>.delayed(Duration.zero);
   }
  }
  return items;
 }
 /// M565: a reviewed bank SMS posts only with a verified account, exact
 /// date and source SAR amount; the original hash is committed atomically.
 Future<void> _m565ConfirmSms({
  required String id,required String body,required String sender,
  required String category,required bool income,
  required double value,required DateTime date,
  required ({List<String?>? ids,int? generation}) selectedAccount})async{
  if(!mounted||_financeLoadFailure!=null)return;
  // Account was explicitly reviewed BEFORE the final Yes, not in a second
  // account dialog after it. The atomic writer rechecks the SQLCipher witness.
  if(selectedAccount.ids?.length!=1||
     selectedAccount.ids!.single==null||
     selectedAccount.generation==null)return;
  final hash=bankSmsHash(body,nativeId:id);
  final facts=WaffraBankSmsFactsParser.parse(body);
  final original=WaffraSmsCurrencies.originalAmount(body);
  // Explicit owner review differs from unattended AutoPost permission:
  // a confirmed external outgoing transfer is an Expense, not an own
  // account Transfer. The secure finance writer still rechecks all fields.
  if(!facts.canOwnerConfirmAsIncomeExpense||
    (facts.kind==WaffraBankOperationKind.income)!=income||
    original==null||original.currency!='SAR'||
    (original.amount-value).abs()>0.00001||
    bankSmsDate(body)==null||bankSmsHasUnverifiedTimestamp(body)){
   if(mounted)snack(context,'راجع المبلغ والتاريخ والعملة من شاشة التعديل.',isError:true);
   return;
  }
  if(smsHashes.contains(hash)){
   final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
   if(ack&&mounted)setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
   return;
  }
  final valid=categories.where((c)=>c.income==income&&c.isSubcategory&&
   c.name==category&&waffraCategoryAvailableForNewEntry(categories,c)).toList();
  if(valid.length!=1){if(mounted)snack(context,'راجع القسم الفرعي أولًا.',isError:true);return;}
  final parsed=BankParser.parse(body);
  final record=MoneyEntry(id:newId(),title:parsed.title,
   category:category,amount:value,income:income,date:date,
   notes:body,sourceType:'sms');
  final budgets=await reviewSmsBudgetLinks([record]);
  if(budgets==null||!mounted)return;
  final reviewed=record.withBudget(budgets.single);
  final chosen=selectedAccount;
  if(!mounted)return;
  try{
   final applied=await _saveProgress.track('m565-confirm-sms',()=>
    _financeAuthority.commitConfirmedSms(
     route:WaffraFinanceRoute.bulkSmsConfirmedSave,
     records:[Map<String,Object?>.from(reviewed.toJson())],
     hashes:[hash],userConfirmed:true,allowDuplicateHashes:false,
     selectedAccountIds:chosen.ids,
     expectedAccountGeneration:chosen.generation));
   if(applied.saved!=1){
    if(mounted)snack(context,'العملية محفوظة سابقًا؛ لم يتم تكرارها.');
    return;
   }
   final decoded=await WaffraLargeJsonDecode.parse(applied.current.ledgerRaw??'[]');
   if(decoded is! List)throw StateError('Verified SMS ledger missing');
   final updated=await _m593BuildVerifiedEntries(decoded);
   if(!updated.any((v)=>v.id==reviewed.id))throw StateError('Missing committed SMS');
   if(!mounted)return;
   setState((){
    // M1008: invalidate the month/history cache as well as the ledger;
    // merely replacing entries leaves filtered Home cards on old IDs.
    _m684InvalidatePeriodRead();
    entries..clear()..addAll(updated);
    smsHashes..clear()..addAll(
     applied.current.finance.getStringList('waffra_sms_hashes_v1')??
     const <String>[]);
    _lastFinanceAuthorityRead=applied.current;
    _lastLedgerSavedRaw=applied.current.ledgerRaw;
    _lastWidgetRevision=applied.current.widgetRevision;
   });
   // M1008 P0: commit and SMS hash are durable, but scoped account
   // IDs and balances must be re-read from the authenticated SQLCipher
   // source. Never treat failure to redraw as a reason to replay the debit.
   var accountProjectionVerified=false;
   try{
    await _m467RefreshHomeAccounts();
    accountProjectionVerified=mounted&&_m468VerifiedAccountsLoaded;
   }catch(_){/* Post-commit presentation failure is not a failed save. */}
   if(sender.trim().isNotEmpty){
    unawaited(_recordConfirmedSmsAccountAssociation(
     record:reviewed,sender:sender,accountId:chosen.ids!.single));
   }
   try{
    await _m1031RecordConfirmedLearning(reviewed);
    await _learnManualCategoryPreference(reviewed);
   }catch(error){
    // The SQLCipher charge was already committed; warn, never replay it.
    if(mounted)snack(context,waffraIsEnglish?
     'Bank transaction saved; encrypted local learning could not be verified.':
     'العملية البنكية محفوظة لكن تعذر التحقق من التعلم المحلي المشفر.',
     isError:true);
   }
   if(sender.trim().isNotEmpty){
    try{await _learnSafeSmsRule(body:body,sender:sender,
     kind:income?'income':'expense',category:category);}catch(_){}
   }
   unawaited(_refreshWidget());
   if(mounted&&!accountProjectionVerified){
    snack(context,waffraIsEnglish?
     'Saved successfully. Account balance is not verified yet; refresh accounts.':
     'العملية اتحفظت بنجاح، لكن رصيد الحساب لم يتم التحقق منه بعد. حدّث الحسابات.',
     isError:true);
   }
   final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
   if(ack&&mounted){
    setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
    snackSuccess(context,'تم تسجيل العملية المؤكدة.');
   }else if(mounted){
    snack(context,'تم الحفظ لكن تأكيد إزالة الرسالة لم يكتمل. لا يوجد خصم مكرر.',isError:true);
   }
  }catch(e){
   debugPrint('M565 verified SMS save rejected: ${e.runtimeType}');
   if(mounted){
    await _refreshFromVerifiedFinance();
    if(mounted)snack(context,'تعذر تأكيد حفظ العملية؛ أعد المراجعة.',isError:true);
   }
  }
 }
 // M615: consistent, responsive detail rows with clear RTL text margins.
 Widget _m615ReviewDetail(String label,String value,IconData symbol)=>
  Padding(padding:const EdgeInsets.symmetric(vertical:6),
   child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Icon(symbol,size:17,color:emerald),
    const SizedBox(width:7),
    Expanded(flex:4,child:WaffraText(label,
     style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
    const SizedBox(width:8),
    Expanded(flex:5,child:WaffraText(value,
     textAlign:TextAlign.start,style:const TextStyle(fontSize:12))),
   ]));

 /// M983: the selected SMS kind opens ONLY its own verified/editor form.
 /// The native ID is re-read under the active owner before it is used.
 /// No rule suggestion can choose a bank account or commit a ledger entry.
 /// M1007: a committed manual correction learns safe, non-posting
 /// category hints automatically. Do not ask the owner to "teach" Waffra
 /// again; the confirmed save IS the learning signal. Bank-direction
 /// conflicts and unverified phrases must never become posting authority.
 Future<void> _m985AutoLearnManualCorrection({
  required String body,required String sender,required bool income,
  required Set<String> beforeIds,
 })async{
  if(!mounted||_smsRuleOwnerKey.isEmpty)return;
  final confirmed=entries.where((e)=>!beforeIds.contains(e.id)&&
   e.sourceType=='manual'&&e.income==income&&
   categories.any((c)=>c.isSubcategory&&c.income==income&&
    c.name==e.category&&
    waffraCategoryAvailableForNewEntry(categories,c))).toList();
  if(confirmed.length!=1)return;
  // The entry form already learns its saved category; an idempotent
  // recheck protects routes where the form was returned after a cold read.
  try{await _learnManualCategoryPreference(confirmed.single);}catch(_){}
  if(sender.trim().isEmpty)return;
  try{
   await _learnSafeSmsRule(body:body,sender:sender,
    kind:income?'income':'expense',category:confirmed.single.category,
    confirmedCorrection:true,description:confirmed.single.title);
  }catch(_){
   // No learning failure may roll back or repeat a committed finance entry.
  }
 }

 /// M1011 / #728: a reviewed SMS stays a BANK-SMS source even when the
 /// classifier guessed another kind. Only a user-confirmed SQLCipher SMS
 /// commit (body + hash + selected financial account) can ACK its native ID.
 /// A cancellation, failed write or failed ACK never posts/reposts money.
 Future<void> _m1011SaveReviewedSmsKind({
  required String id,required String body,required String sender,
  required bool income,
  String? reviewedCategoryParentId,String? reviewedCategoryLeafId,
  String? reviewedAccountId,
 })async{
  if(!mounted)return;
  final facts=WaffraBankSmsFactsParser.parse(body);
  final lifecycle=WaffraSmsLifecycleEvidence.inspect(body,sender:sender);
  final unsafe=facts.pending||
   WaffraBankSmsFactsParser.isVerificationChallenge(body)||
   WaffraSmsStructuredBankContext.multipleEvents(body)||
   lifecycle.stage==WaffraSmsLifecycleStage.reversed||
   lifecycle.stage==WaffraSmsLifecycleStage.refunded;
  if(unsafe){
   snack(context,waffraIsEnglish?
    'This bank message contains an unresolved or combined event. Review it separately.':
    'الرسالة فيها عملية معلقة أو مركبة وتحتاج مراجعة منفصلة.',
    isError:true);
   return;
  }
  final hash=bankSmsHash(body,nativeId:id);
  if(!smsHashes.contains(hash)){
   // NEVER use manualIncomeOverride/reviewedOriginalSms for a reviewed SMS.
   // The manual writer loses sourceType and immutable original text/hash.
   await entrySheet(sms:true,initialSms:body,reviewedSender:sender,reviewedSmsId:id,
    reviewedIncomeOverride:income,
    reviewedSmsCategoryParentId:reviewedCategoryParentId,
    reviewedSmsCategoryLeafId:reviewedCategoryLeafId,
    reviewedSmsAccountId:reviewedAccountId);
  }
  if(!mounted)return;
  // Verify the exact original bank body AND owner-chosen direction from
  // the source-reloaded ledger, not a dialog success/toast or a rule match.
  final committed=entries.where((e)=>e.sourceType=='sms'&&
   e.notes==body&&e.income==income).toList(growable:false);
  if(!smsHashes.contains(hash)||committed.isEmpty)return;
  final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
  if(!mounted)return;
  if(!ack){
   snack(context,waffraIsEnglish?
    'Saved once, but SMS acknowledgement failed. Reopen the message to retry safely.':
    'العملية اتحفظت مرة واحدة، لكن إزالة الرسالة فشلت. افتحها تاني لإعادة التأكيد بأمان.',
    isError:true);
   return;
  }
  setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
  // Classification hints are learned only after an authoritative owner
  // choice and durable finance commit, never from an uncertain SMS alone.
  if(sender.trim().isNotEmpty&&committed.length==1){
   try{await _learnSafeSmsRule(body:body,sender:sender,
    kind:income?'income':'expense',category:committed.single.category,
    confirmedCorrection:true,description:committed.single.title);}catch(_){}
  }
  if(mounted)await _refreshAutoSmsInbox();
 }

  Future<void> _m983OpenSmsTypedTemplate({
  required String id,required String kind,
 })async{
  if(!mounted||!ready||_financeLoadFailure!=null||
     !const <String>{'income','expense','transfer'}.contains(kind))return;
  final row=await WaffraAutoSms.pendingById(id);
  if(!mounted||row==null||row['id']!=id)return;
  final body=row['body'],sender=row['sender'];
  if(body is! String||body.trim().isEmpty||sender is! String)return;
  final facts=WaffraBankSmsFactsParser.parse(body);
  final sensitive=row['sensitiveOtp']==true||
   WaffraBankSmsFactsParser.isVerificationChallenge(body);
  if(sensitive){
   // Never show OTP details in the money editor.
   await _reviewAutoSmsCandidates(targetId:id);
   return;
  }
  final lifecycle=WaffraSmsLifecycleEvidence.inspect(body,sender:sender);
  final requiresSeparateReview=
   WaffraSmsStructuredBankContext.multipleEvents(body)||
   lifecycle.stage==WaffraSmsLifecycleStage.reversed||
   lifecycle.stage==WaffraSmsLifecycleStage.refunded;
  if(requiresSeparateReview){
   // A combined/refunded/reversed SMS must not use the ordinary
   // single-income/expense editor or silently ACK the original bank SMS.
   await _reviewAutoSmsCandidates(targetId:id);
   return;
  }
  if(kind=='transfer'){
   if(facts.kind==WaffraBankOperationKind.transfer&&!facts.pending){
    await _reviewSmsAccountTransfer(item:row,facts:facts);
   }else{
    // The SMS does not prove both accounts belong to the owner. A manual
    // two-account transfer form requires independent verified ownership.
    snack(context,waffraIsEnglish?
     'This message does not verify a transfer between your accounts. Select both accounts manually.':
     'الرسالة لا تثبت تحويلًا بين حساباتك. اختار حسابَي التحويل بنفسك.');
    await openReviewedSmsManualTransfer(id:id,body:body,sender:sender);
   }
  }else{
   await _m1011SaveReviewedSmsKind(
    id:id,body:body,sender:sender,income:kind=='income');
  }
  // M983: refresh all FOUR saved/default rule kinds and native ACK state
  // before showing this sender again (the inbox rebuilds its group snapshot).
  if(mounted)await _refreshAutoSmsInbox();
 }

 Future<void> _reviewAutoSmsCandidates({String? targetId})async {
  if(!mounted||!ready||_autoSmsReviewOpen||
     _financeLoadFailure!=null)return;
  _autoSmsReviewOpen=true;
  try{
   // The tapped notification knows its exact native SMS ID: retrieve only
   // that item, not a 1000-row encrypted queue on every tap. Native still
   // verifies owner/session and never posts or acknowledges during lookup.
   final direct=targetId==null?null:await WaffraAutoSms.pendingById(targetId);
   final items=targetId==null?await WaffraAutoSms.pending():
    direct==null?<Map<String,Object?>>[]:<Map<String,Object?>>[direct];
   if(!mounted)return;
   if(items.isEmpty){
    // M1005: an already excluded or stale native ID must not look like
    // a button that did nothing. Recheck the native owner queue and report
    // on the visible Notifications route without inventing an ACK.
    if(targetId!=null){
     await _refreshAutoSmsInbox();
     if(mounted){
      final visibleContext=Navigator.of(context).canPop()?
       Navigator.of(context).context:context;
      snack(visibleContext,waffraIsEnglish?
       'This message is no longer in verified review. List refreshed.':
       'الرسالة لم تعد موجودة في قائمة المراجعة الموثقة. تم تحديث القائمة.',
       isError:true);
     }
    }
    return;
   }
   Map<String,Object?>? selected;
   for(final item in items){
    final id=item['id'],body=item['body'];
    if(id is! String||body is! String||body.trim().isEmpty)continue;
    if(targetId!=null&&id!=targetId)continue;
    if(smsHashes.contains(bankSmsHash(body,nativeId:id))){
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }
     continue;
    }
    selected=item;break;
   }
   if(!mounted||selected==null)return;
   final id=selected['id'],body=selected['body'];
   final sender=selected['sender'] is String?selected['sender'] as String:'';
   if(id is! String||body is! String)return;
   final facts=WaffraBankSmsFactsParser.parse(body);
   final sensitive=selected['sensitiveOtp']==true||
    WaffraBankSmsFactsParser.isVerificationChallenge(body);
   final localMatches=_autoSmsPending.where((row)=>row['id']==id);
   final lifecycle=WaffraSmsLifecycleEvidence.inspect(body,sender:sender);
   final composite=WaffraSmsStructuredBankContext.multipleEvents(body);
   final requiresSeparateReview=composite||
    lifecycle.stage==WaffraSmsLifecycleStage.reversed||
    lifecycle.stage==WaffraSmsLifecycleStage.refunded;
   final local=localMatches.isEmpty?null:localMatches.first['local'];
   final localFacts=local is Map?local:null;
   final understood=facts.kind==WaffraBankOperationKind.income||
    facts.kind==WaffraBankOperationKind.expense;
   final originalAmount=WaffraSmsCurrencies.originalAmount(body);
   final originalDate=bankSmsDate(body);
   final parsed=BankParser.parse(body);
   final proposedCategory=localFacts?['category'] is String?
    localFacts!['category'] as String:parsed.category;
   final expectedIncome=facts.kind==WaffraBankOperationKind.income;
   // M669: a bank classifier can suggest a ROOT (e.g. تحويلات) without
   // providing any leaf. The root is shown as MAIN only; a user must pick
   // an actual child. Same-name/legacy hints need exact parent validation.
   final previewHint=waffraResolveSmsReviewCategory(categories,
    income:expectedIncome,proposed:proposedCategory);
   final previewMainName=previewHint.parent?.displayName??
    (waffraIsEnglish?'Choose main category':'يحتاج اختيار القسم الرئيسي');
   // The first account is an independent setup step, NOT a valid-category
   // confirmation. A user must be able to create it before fixing category.
   final hasActiveMoneyAccount=_m467Accounts.any((a)=>!a.archived);
   final previewSuffix=WaffraSmsAccountLearning.suffix4(
    expectedIncome?facts.destinationSuffix:facts.sourceSuffix);
   final previewAccountLabel=previewSuffix==null?
    (waffraIsEnglish?'Account needs confirmation':'الحساب يحتاج تأكيد'):
    (waffraIsEnglish?'Account ••••':'الحساب ••••')+previewSuffix;
   final previewDateTime=originalDate==null?
    (waffraIsEnglish?'Date/time needs review':'التاريخ والوقت يحتاجان مراجعة'):
    originalDate.toIso8601String().replaceFirst('T',' ').substring(0,16);
   // The SMS category can be corrected inline without re-opening a money-account
   // selector. A verified account alone never bypasses mandatory category checks.
   String reviewedCategory=previewHint.leaf?.name??
    (waffraIsEnglish?'Choose subcategory':'يحتاج اختيار القسم الفرعي');
   // Carry the ACTUAL reviewed category identities to the editor, not
   // a separately re-parsed category guess. These still require revalidation.
   String? reviewedCategoryParentId=previewHint.parent?.id;
   String? reviewedCategoryLeafId=previewHint.leaf?.id;
   String reviewedMainName=previewMainName;
   bool reviewCategoryValid=previewHint.leaf!=null&&
    previewHint.parent!=null;
   // M669: an independent conservative BankParser may decline to extract
   // an amount even when verified original SAR facts did extract one.
   // The atomic writer validates original facts, NOT that optional second
   // parser. A present conflicting parsed amount/direction still blocks Yes.
   // A money prefill parser can pick an account balance or fee, or
   // confuse the banking word "transfer" with own-account movement.
   // It is not an independent financial authority. Verified original
   // SAR amount, SAMA direction, date and selected leaf are authoritative.
   String? ownerBlocker()=>WaffraBankSmsFactsParser.ownerConfirmationBlocker(
    facts:facts,requiresSeparateReview:requiresSeparateReview,
    amountVerifiedSar:originalAmount!=null&&
     originalAmount.currency=='SAR',
    timestampVerified:originalDate!=null&&
     !bankSmsHasUnverifiedTimestamp(body),
    leafVerified:reviewCategoryValid);
   bool canConfirm=ownerBlocker()==null;
   // A type selection in compact review is only a requested correction;
   // it must never ACK or post money until the verified ledger editor saves.
   String? reviewType=sensitive?null:switch(facts.kind){
    WaffraBankOperationKind.income=>'income',
    WaffraBankOperationKind.expense=>'expense',
    WaffraBankOperationKind.transfer=>'transfer',
    _=>null,
   };
   final firstChoice=sensitive?'exclude':
    facts.kind==WaffraBankOperationKind.transfer?'transfer':
    understood?'no':'manual';
   // Verified institution/sub-account selection must occur IN this review
   // before enabling Yes. A second picker after Yes is prohibited.
   ({List<String?>? ids,int? generation})? reviewedAccount;
   String? reviewedAccountName;
   bool choosingAccount=false;
   // M669: a disabled Yes must say WHY and offer the safe editor. The
   // conditions mirror the verified atomic writer; choosing a category or
   // account alone never bypasses currency, source and timestamp checks.
   // M689: verification remains in canConfirm; no verbose blocking panel.
   Future<void> selectReviewCategory(StateSetter redraw,BuildContext dialog)async{
    // M669: the SMS hint is only a suggestion. Choose a real ACTIVE parent
    // and then one of its ACTIVE children; both steps are searchable.
    // No category, bank balance or SMS is modified on cancel/back.
    final mainChoices=categories.where((c)=>
     !c.isSubcategory&&c.income==expectedIncome&&
     c.categoryActive).toList();
    BudgetCategory? chosenMain;
    var query='';
    final chosen=await showWaffraDialog<BudgetCategory>(
     context:dialog,builder:(picker)=>
      StatefulBuilder(builder:(picker,choose){
       final children=chosenMain==null?<BudgetCategory>[]:
        waffraManualCategoryChildren(categories,expectedIncome,chosenMain!.id);
       final mainMatches=mainChoices.where((parent)=>
        waffraSearchAny([parent.name,parent.displayName,
         waffraTr(parent.name)],query)||
        categories.any((child)=>child.isSubcategory&&
         child.parentId==parent.id&&child.income==expectedIncome&&
         waffraCategoryAvailableForNewEntry(categories,child)&&
         waffraSearchAny([child.name,child.displayName,
          waffraTr(child.displayName)],query))).toList();
       final leafMatches=children.where((leaf)=>
        waffraSearchAny([leaf.name,leaf.displayName,
         waffraTr(leaf.displayName)],query)).toList();
       return AlertDialog(
       title:WaffraText(waffraIsEnglish?
        'Choose main and subcategory':'اختيار القسم الرئيسي والفرعي'),
       content:SizedBox(width:360,height:350,child:Column(children:[
        TextField(
         key:ValueKey('m669-review-category-search-${chosenMain?.id??'main'}'),
         onChanged:(value)=>choose(()=>query=value),
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search_rounded),
          hintText:waffraIsEnglish?'Search categories':'ابحث في الأقسام',
          border:const OutlineInputBorder())),
        const SizedBox(height:8),
        Expanded(child:ListView(children:[
         if(chosenMain!=null)ListTile(
          leading:const Icon(Icons.arrow_back_rounded),
          title:WaffraText(chosenMain!.displayName),
          onTap:()=>choose((){
           chosenMain=null;query='';
          })),
         if(chosenMain==null)...[
          for(final parent in mainMatches)ListTile(
           title:WaffraText(parent.displayName),
           trailing:const Icon(Icons.chevron_left_rounded),
           onTap:()=>choose((){
            chosenMain=parent;query='';
           })),
          if(mainMatches.isEmpty)ListTile(
           key:const Key('m669-review-category-no-results'),
           title:WaffraText(waffraIsEnglish?
            'No matching main categories':'لا توجد أقسام رئيسية مطابقة')),
         ]else...[
          for(final leaf in leafMatches)ListTile(
           title:WaffraText(leaf.displayName),
           onTap:()=>Navigator.pop(picker,leaf)),
          if(leafMatches.isEmpty)ListTile(
           key:const Key('m669-review-category-no-results'),
           title:WaffraText(waffraIsEnglish?
            'No matching subcategories':'لا توجد أقسام فرعية مطابقة')),
         ],
        ])),
       ])),
       actions:[TextButton(
        onPressed:()=>Navigator.pop(picker),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))],
      );
      }));
    if(chosen==null||!mounted||!dialog.mounted)return;
    final parent=categories.where((c)=>!c.isSubcategory&&
      c.id==chosen.parentId&&c.income==expectedIncome&&
      c.categoryActive).toList();
    if(parent.length!=1)return;
    // The persisted finance record still stores category name. Do not
    // falsely enable Yes when two active children share the same name.
    final unambiguous=categories.where((c)=>c.isSubcategory&&
      c.income==expectedIncome&&c.name==chosen.name&&
      waffraCategoryAvailableForNewEntry(categories,c)).length==1;
    redraw((){
     reviewedCategory=chosen.name;
     reviewedMainName=parent.single.displayName;
     reviewedCategoryParentId=parent.single.id;
     reviewedCategoryLeafId=unambiguous?chosen.id:null;
     reviewCategoryValid=unambiguous;
     canConfirm=ownerBlocker()==null;
    });
   }
   Future<void> selectAccountBeforeYes(StateSetter redraw,BuildContext dialog)async{
    // Account setup/selection may happen BEFORE category/date corrections;
    // only Yes authorizes posting and retains the full canConfirm guard.
    if(choosingAccount)return;
    redraw(()=>choosingAccount=true);
    try{
     final bridge=_financeBinding?.accountsBridge;
     if(bridge==null)return;
     final before=await bridge.readVerifiedAccounts();
     if(!mounted||!dialog.mounted)return;
     String? pickedId;
     if(!before.balances.any((a)=>!a.archived)){
      // No account: the one clear action opens account creation directly,
      // without an extra bank-account prompt or a transaction save.
      final knownBank=WaffraSmsAccountLearning.bankGroup(sender);
      final suffix=WaffraSmsAccountLearning.suffix4(
       expectedIncome?facts.destinationSuffix:facts.sourceSuffix);
      final draft=await showWaffraDialog<WaffraNewAccountDraft>(
       context:dialog,builder:(ctx)=>WaffraNewAccountDialog(
        english:waffraIsEnglish,suggestedProviderId:knownBank,
        suggestedSenderName:sender,suggestedLastFour:suffix));
      if(draft==null||!mounted||!dialog.mounted)return;
      final suggestedInstitution=WaffraSaudiFinancialProviders.byId(knownBank);
      final suggestedKind=suggestedInstitution?.category==
       WaffraSaudiFinancialProviders.wallet?'wallet':'bank';
      if(knownBank!=null&&(draft.kind!=suggestedKind||
         draft.providerId!=knownBank||draft.subtype==null)){
       throw StateError('SMS account must match the verified bank sender');
      }
      final api=WaffraVerifiedAccountsApi(bridge:bridge);
      final newId='m632-sms-'+DateTime.now().microsecondsSinceEpoch.toString();
      await api.balances();
      await api.createTypedAccountWithIdentity(
       id:newId,name:draft.name,kind:draft.kind,
       providerId:draft.providerId??'none',
       subtype:draft.subtype??'other',
       openingMinor:draft.openingMinor,
       createdIso:DateTime.now().toUtc().toIso8601String(),
       lastFour:draft.lastFour,
       customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
      pickedId=newId;
     }else{
      // An existing account can be selected even when the transaction's
      // category/date needs editing; the trial is never posted.
      final trial=MoneyEntry(
       id:newId(),title:parsed.title,category:proposedCategory,
       amount:originalAmount?.amount??parsed.amount??0.0,
       income:expectedIncome,date:originalDate??DateTime.now(),
       notes:body,sourceType:'sms');
      final picked=await reviewSmsAccountLinks([trial],smsSender:sender);
      pickedId=picked?.ids?.single;
     }
     if(pickedId==null||!mounted||!dialog.mounted)return;
     // Always read the CURRENT SQLCipher witness after selecting/creating.
     final fresh=await bridge.readVerifiedAccounts();
     final active=fresh.balances.where(
      (a)=>!a.archived&&a.id==pickedId).toList();
     if(active.length!=1)return;
     redraw((){
      reviewedAccount=(ids:<String?>[pickedId],
       generation:fresh.witness.generation);
      reviewedAccountName=active.single.name;
     });
     // Refresh dashboard accounts without reloading the Home ledger and
     // without opening a second account-confirmation dialog.
     unawaited(_m467RefreshHomeAccounts());
    }catch(e){
     debugPrint('M632 pre-Yes account setup: ${e.runtimeType}');
     if(mounted)snack(context,waffraIsEnglish?
      'Could not verify or add this account. Please retry.':
      'تعذر إضافة الحساب أو التحقق منه. حاول مرة أخرى.',isError:true);
    }finally{
     if(dialog.mounted)redraw(()=>choosingAccount=false);
    }
   }
   final reviewScroll=ScrollController();
   var decision=await showWaffraDialog<String>(context:context,
    builder:(dialog)=>StatefulBuilder(builder:(dialog,redraw)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?
      'Review bank message':'مراجعة رسالة بنكية'),
     content:Scrollbar(controller:reviewScroll,thumbVisibility:true,
      thickness:4,radius:const Radius.circular(8),
      child:SingleChildScrollView(controller:reviewScroll,
       child:Padding(
        // End in RTL is the left edge: never let scrollbar cover text.
        padding:const EdgeInsetsDirectional.only(start:6,end:24),
        child:Column(
      mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
      children:[
       // M689: the duplicated bank sender/type preview was removed.
       // Original SMS and review details below stay unchanged.
       // M662: no duplicate type picker above the original SMS. Uncertain
       // SMS keeps explicit user-driven choices BELOW the message.
       // M669: all actual financial SMS review confirmations show the
       // UNCHANGED original message, not just a parser's summary. This
       // shared dialog serves sender inbox, notification tap and per-message
       // review. A genuine OTP/security challenge must remain hidden.
       if(!sensitive)Padding(
        padding:const EdgeInsets.only(top:10),
        child:Card(
         color:Theme.of(dialog).colorScheme.surfaceContainerLow,
         child:ExpansionTile(
         key:const Key('waffra-sms-original-expand'),
         initiallyExpanded:true,
         title:WaffraText(waffraIsEnglish?
          'Read original bank message':'عرض نص الرسالة البنكية الأصلي'),
         children:[Padding(padding:const EdgeInsets.all(14),
          child:KeyedSubtree(
           key:const Key('m669-review-original-sms-text'),
           child:SelectableText(body,textAlign:TextAlign.start)))],
        )))
       else Card(child:Padding(
        padding:const EdgeInsets.all(12),
        child:WaffraText(waffraIsEnglish?
         'Verification SMS content is hidden for your safety.':
         'نص رسالة التحقق مخفي لحمايتك.'))),
       if(requiresSeparateReview)Card(
        key:const Key('m989-lifecycle-manual-review-warning'),
        child:Padding(padding:const EdgeInsets.all(12),
         child:Row(children:[
          const Icon(Icons.report_problem_outlined),
          const SizedBox(width:8),
          Expanded(child:WaffraText(waffraIsEnglish?
           'Multiple events, a refund, or a reversal require separate review. No automatic financial confirmation is allowed.':
           'الرسالة فيها أكثر من حدث أو استرداد أو عكس. تحتاج مراجعة مستقلة، وممنوع تأكيدها تلقائيًا كعملية عادية.')),
         ]))),
       if(!sensitive&&!understood&&
          facts.kind!=WaffraBankOperationKind.transfer)...[
        const SizedBox(height:8),
        for(final kind in const <String>['income','expense','transfer'])
         Padding(padding:const EdgeInsets.only(bottom:6),
          child:OutlinedButton(
           key:Key('m662-unknown-correct-to-'+kind),
           onPressed:()=>Navigator.pop(dialog,'m662-type-'+kind),
           child:WaffraText(switch(kind){
            'income'=>waffraIsEnglish?'Income':'دخل',
            'expense'=>waffraIsEnglish?'Expense':'مصروف',
            _=>waffraIsEnglish?'Transfer':'تحويل',
           }))),
       ],
       if(understood&&!sensitive&&
          reviewType==(expectedIncome?'income':'expense'))...[
        const SizedBox(height:10),
        Card(color:Theme.of(dialog).colorScheme.surfaceContainerLow,
         child:Padding(padding:const EdgeInsets.all(12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Row(children:[
            const Icon(Icons.check_circle_outline_rounded,color:emerald),
            const SizedBox(width:8),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Is this transaction correct?':'هل العملية صحيحة؟',
             style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),
           ]),
           const Divider(height:18),
           _m615ReviewDetail(waffraIsEnglish?'Type':'نوع العملية',
            expectedIncome?(waffraIsEnglish?'Income':'دخل'):
             (waffraIsEnglish?'Expense':'مصروف'),Icons.category_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Amount':'المبلغ',
            originalAmount==null?'—':
             '${originalAmount.amount.toStringAsFixed(2)} ${originalAmount.currency}',
            Icons.payments_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Description':'الوصف',
            parsed.title,Icons.edit_note_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Main category':'القسم الرئيسي',
            reviewedMainName,Icons.grid_view_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Subcategory':'القسم الفرعي',
            reviewedCategory,Icons.list_alt_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Sender':'المرسل',
            sender,Icons.account_balance_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Money account':'الحساب المالي',
            (reviewedAccountName??(hasActiveMoneyAccount?
              previewAccountLabel:(waffraIsEnglish?
               'No money account yet':'لم تضف حسابًا ماليًا بعد')))+' • '+
            (reviewedAccount!=null?
             (waffraIsEnglish?'Verified':'تم تأكيد الحساب'):
             (waffraIsEnglish?'Choose before saving':'اختار الحساب قبل الحفظ')),
            Icons.account_balance_wallet_outlined),
           _m615ReviewDetail(waffraIsEnglish?'Original date/time':'تاريخ ووقت العملية',
            previewDateTime,Icons.calendar_month_outlined),
          ]))),
        const SizedBox(height:8),
        OutlinedButton.icon(
         key:const Key('m665-review-pick-category'),
         onPressed:()=>selectReviewCategory(redraw,dialog),
         icon:const Icon(Icons.category_outlined),
         label:WaffraText(reviewCategoryValid?
          (waffraIsEnglish?'Change category':'تغيير القسم الرئيسي والفرعي'):
          (waffraIsEnglish?'Choose category':'اختيار القسم الرئيسي والفرعي')),
        ),
        const SizedBox(height:8),
        OutlinedButton.icon(
         key:const Key('m590-sms-choose-account-before-yes'),
         onPressed:!choosingAccount?
          ()=>selectAccountBeforeYes(redraw,dialog):null,
         icon:choosingAccount?
          const SizedBox(width:17,height:17,
           child:CircularProgressIndicator(strokeWidth:2)):
          const Icon(Icons.account_balance_wallet_outlined),
         label:WaffraText(reviewedAccountName??(!hasActiveMoneyAccount?
          (waffraIsEnglish?'Add account':'إضافة حساب'):
          (waffraIsEnglish?'Choose money account':'اختيار الحساب المالي'))),
        ),
        const SizedBox(height:6),
        if(!canConfirm)Padding(
         padding:const EdgeInsets.only(bottom:8),
         child:WaffraText(ownerBlocker()=='category'?
          (waffraIsEnglish?
           'Select a valid active main and subcategory above to enable Done.':
           'اختر قسمًا رئيسيًا وفرعيًا نشطين من زر تغيير القسم لتفعيل «تم».'):
          ownerBlocker()=='date'?
           (waffraIsEnglish?
            'The original SMS date/time is unverified. Open Edit to confirm it.':
            'تاريخ أو وقت الرسالة الأصلية غير مؤكد. اضغط تعديل لتأكيده.'):
          ownerBlocker()=='amount_or_currency'?
           (waffraIsEnglish?
            'The SMS amount or SAR currency could not be verified. Open Edit.':
            'تعذر التحقق من مبلغ الرسالة الأصلي أو عملته بالريال. اضغط تعديل.'):
          ownerBlocker()=='multi_event'?
           (waffraIsEnglish?
            'This message includes multiple or reversed events. Review separately.':
            'الرسالة تحتوي أحداثًا متعددة أو عملية معكوسة؛ راجعها منفصلة.'):
          (waffraIsEnglish?
           'The transaction is not a verified settled income/expense. Open Edit.':
           'اتجاه العملية أو اكتمالها غير مؤكد. اضغط تعديل لمراجعتها.'),
          style:TextStyle(fontSize:12,
           color:Theme.of(dialog).colorScheme.error))),
        // Two readable actions on the first row, with Exclude at full
        // width below. Three narrow Expanded buttons truncated Arabic text.
        Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(children:[
          Expanded(child:FilledButton.icon(
           key:const Key('m565-sms-yes-confirm'),
           onPressed:canConfirm&&reviewedAccount?.ids?.single!=null&&
            reviewedAccount?.generation!=null&&
            !choosingAccount?()=>Navigator.pop(dialog,'yes'):null,
           icon:const Icon(Icons.check_rounded,size:18),
           label:WaffraText(waffraIsEnglish?'Done':'تم',maxLines:1))),
          const SizedBox(width:8),
          Expanded(child:OutlinedButton.icon(
           key:const Key('m565-sms-no-edit'),
           onPressed:()=>Navigator.pop(dialog,'m983-direct-edit'),
           icon:const Icon(Icons.edit_outlined,size:18),
           label:WaffraText(waffraIsEnglish?'Edit':'تعديل',maxLines:1))),
         ]),
         if(!sensitive&&facts.kind!=WaffraBankOperationKind.transfer)...[
          const SizedBox(height:8),
          OutlinedButton.icon(
           key:const Key('m595-review-single-exclude'),
           onPressed:()=>Navigator.pop(dialog,'exclude'),
           icon:const Icon(Icons.block_outlined,size:18),
           label:WaffraText(waffraIsEnglish?'Exclude message':
            'استبعاد الرسالة',textAlign:TextAlign.center)),
         ],
        ]),
       ],
       // Unknown non-sensitive senders also need a direct exclusion
       // action. Selection must never force a misleading Income/Expense
       // choice just to remove a beneficiary activation or bulletin.
       if(!sensitive&&facts.kind!=WaffraBankOperationKind.transfer&&
          !(understood&&reviewType==(expectedIncome?'income':'expense')))
        Padding(padding:const EdgeInsets.only(top:10),
         child:OutlinedButton.icon(
          key:const Key('m953-unknown-sms-exclude'),
          onPressed:()=>Navigator.pop(dialog,'exclude'),
          icon:const Icon(Icons.block_outlined),
          label:WaffraText(waffraIsEnglish?'Exclude message':
           'استبعاد الرسالة'))),
       const SizedBox(height:12),
       const SizedBox(height:8),
       if(facts.kind==WaffraBankOperationKind.transfer&&!sensitive&&
          reviewType=='transfer')
        Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         FilledButton.icon(
          key:const Key('m587-sms-transfer-yes'),
          onPressed:()=>Navigator.pop(dialog,'transfer'),
          icon:const Icon(Icons.swap_horiz_rounded),
          label:WaffraText(waffraIsEnglish?
           'Confirm transfer details':'تأكيد التحويل')),
         const SizedBox(height:6),
         OutlinedButton(
          key:const Key('m587-sms-transfer-no'),
          onPressed:()=>Navigator.pop(dialog,'transfer-manual'),
          child:WaffraText(waffraIsEnglish?
           'No, add income or expense':'لا، إضافة دخل أو مصروف')),
         const SizedBox(height:4),
         TextButton.icon(
          key:const Key('m587-sms-transfer-exclude'),
          onPressed:()=>Navigator.pop(dialog,'exclude'),
          icon:const Icon(Icons.block_outlined),
          label:WaffraText(waffraIsEnglish?
           'Exclude this message':'استبعاد الرسالة')),
        ])
       else if(sensitive)Card(child:ListTile(
        key:const Key('waffra-sms-understood-action'),
        leading:Icon(sensitive?Icons.shield_outlined:
         facts.kind==WaffraBankOperationKind.transfer?Icons.sync_alt_rounded:
         understood?Icons.account_balance_wallet_outlined:Icons.edit_note_outlined),
        title:WaffraText(sensitive?
         (waffraIsEnglish?'Exclude verification SMS':'استبعاد رسالة التحقق'):
         facts.kind==WaffraBankOperationKind.transfer?
          (waffraIsEnglish?'Review bank transfer':'مراجعة حوالة بنكية'):
         understood?(waffraIsEnglish?'I understand this transaction':'مراجعة العملية'):
         (waffraIsEnglish?'Add a separate manual transaction':'إضافة عملية يدوية')),
        subtitle:WaffraText(sensitive?
         (waffraIsEnglish?'Exclude only this reviewed message':'استبعاد الرسالة دي فقط'):
         (waffraIsEnglish?'Continue with verified transaction review':
          'استكمال المراجعة قبل تسجيل أي مبلغ')),
        onTap:()=>Navigator.pop(dialog,firstChoice),
       )),
      ])))),
     actions:[
      if(facts.kind!=WaffraBankOperationKind.transfer)
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:WaffraText(waffraIsEnglish?'Later':'لاحقًا')),
     ])));
   reviewScroll.dispose();
   if(decision=='m983-direct-edit'&&understood&&!sensitive&&mounted){
    // Edit means the current verified kind, not another three-kind picker.
    reviewType=expectedIncome?'income':'expense';
    decision='correct-type';
   }
   if(decision=='no'&&understood&&!sensitive&&
      facts.kind!=WaffraBankOperationKind.transfer&&mounted){
    // For suggested Expense, only Income / Transfer are alternative types.
    final alternatives=expectedIncome?
     const <String>['expense','transfer']:
     const <String>['income','transfer'];
    final corrected=await showWaffraDialog<String>(context:context,
     builder:(pick)=>AlertDialog(
      title:Row(children:[
       Expanded(child:WaffraText(waffraIsEnglish?
        'Choose the correct transaction type':'اختار نوع العملية الصحيح')),
       IconButton(icon:const Icon(Icons.close),
        onPressed:()=>Navigator.pop(pick)),
      ]),
      content:Column(mainAxisSize:MainAxisSize.min,
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        for(final kind in alternatives)Padding(
         padding:const EdgeInsets.only(bottom:8),
         child:OutlinedButton.icon(
          key:Key('m618-correct-to-'+kind),
          onPressed:()=>Navigator.pop(pick,kind),
          icon:Icon(kind=='transfer'?Icons.swap_horiz_rounded:
           kind=='income'?Icons.south_west_rounded:Icons.north_east_rounded),
          label:WaffraText(switch(kind){
           'income'=>waffraIsEnglish?'Income':'دخل',
           'expense'=>waffraIsEnglish?'Expense':'مصروف',
           _=>waffraIsEnglish?'Transfer':'تحويل',
          }))),
       ]),
     ));
    if(corrected!=null){reviewType=corrected;decision='correct-type';}
    else decision=null;
   }
   if(decision!=null&&decision.startsWith('m662-type-')){
    reviewType=decision.substring('m662-type-'.length);
    decision='correct-type';
   }
   if(decision=='correct-type'&&mounted&&reviewType!=null){
    if(reviewType=='transfer'){
     // A correction from unknown/income/expense to internal transfer cannot
     // infer ownership of the source or destination from SMS wording.
     // It opens a SEPARATE manual transfer with fresh account confirmation.
     // The original SMS remains pending and can still be excluded/reviewed.
     final approved=await showWaffraDialog<bool>(context:context,
      builder:(ctx)=>AlertDialog(
       title:WaffraText(waffraIsEnglish?
        'Confirm separate internal transfer':'تأكيد تحويل منفصل بين حساباتي'),
       content:WaffraText(waffraIsEnglish?
        'The message does not prove both accounts are yours. Continue only '
        'to a new manual transfer with two verified accounts. The bank SMS '
        'will stay pending, and nothing is saved by this choice alone.':
        'الرسالة لا تثبت أن الحسابين ملكك. المتابعة هتفتح تحويلًا يدويًا '
        'بحسابين موثّقين، والرسالة بتخرج من المراجعة بعد الحفظ المؤكد فقط. '
        'الاختيار وحده مش هيسجل أي مبلغ.'),
       actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx,false),
         child:WaffraText(waffraIsEnglish?'Back':'عودة')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),
         child:WaffraText(waffraIsEnglish?'Continue':'متابعة')),
       ],
      ));
     if(approved==true&&mounted)await openReviewedSmsManualTransfer(id:id,body:body,sender:sender);
    }else{
     await _m1011SaveReviewedSmsKind(id:id,body:body,
      sender:sender,income:reviewType=='income',
      reviewedCategoryParentId:reviewedCategoryParentId,
      reviewedCategoryLeafId:reviewCategoryValid?
       reviewedCategoryLeafId:null,
      reviewedAccountId:reviewedAccount?.ids?.length==1?
       reviewedAccount!.ids!.single:null);
    }
   }else if(decision=='exclude'&&mounted){
    // M1005: if Notifications is pushed above Home, feedback must be
    // displayed on that visible Navigator, not Home's obscured footer.
    final visibleContext=Navigator.of(context).canPop()?
     Navigator.of(context).context:context;
    // Never mark user-excluded SMS as a financially committed transaction.
    final acknowledged=await WaffraAutoSms.excludeMessages([id]);
    if(acknowledged&&mounted){
     setState(()=>_autoSmsPending.removeWhere((item)=>item['id']==id));
     // M661: a durable single-message exclusion is NOT a learned pattern.
     // The user sees the distinction instead of a misleading silent success.
     var learned=false;
     String? learningFailure;
     try{
      learned=await _learnSafeSmsRule(
       body:body,sender:sender,kind:'excluded',
       onFailure:(reason)=>learningFailure=reason);
     }catch(_){learningFailure??='rule_storage_unavailable';}
     if(mounted){
      snackSuccess(visibleContext,learned?
       (waffraIsEnglish?
        'Message excluded for 30 days; a reusable safe rule was saved.':
        'تم استبعاد الرسالة لمدة 30 يوم، واتحفظت قاعدة آمنة للرسائل المشابهة.'):
       (waffraIsEnglish?
        'Only this message was excluded for 30 days. No reusable rule was learned. ':
        'تم استبعاد الرسالة دي فقط لمدة 30 يوم. لم يتم تعلّم قاعدة للرسائل المشابهة. ')+
        waffraExclusionLearningReason(learningFailure,english:waffraIsEnglish));
      await _refreshAutoSmsInbox();
     }
    }else if(mounted){
     snack(visibleContext,waffraIsEnglish?
      'Could not exclude the message safely. Try again.':
      'تعذر استبعاد الرسالة بأمان. حاول تاني.',isError:true);
    }
   }else if(decision=='transfer'&&mounted){
    // The transfer editor itself requires two different verified accounts,
    // original principal amount, and an additional owner save confirmation.
    await _reviewSmsAccountTransfer(item:selected,facts:facts);
   }else if(decision=='transfer-manual'&&mounted){
    final kind=await showWaffraDialog<String>(context:context,
     builder:(dialog)=>AlertDialog(
      title:WaffraText(waffraIsEnglish?
       'Choose the type of transaction to add:':
       'اختر نوع العملية التي تريد إضافتها:'),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(dialog),
        child:WaffraText(waffraIsEnglish?'Back':'العودة')),
       OutlinedButton(onPressed:()=>Navigator.pop(dialog,'expense'),
        child:WaffraText(waffraIsEnglish?'Expense':'مصروف')),
       FilledButton(onPressed:()=>Navigator.pop(dialog,'income'),
        child:WaffraText(waffraIsEnglish?'Income':'دخل')),
      ]));
    if(mounted&&(kind=='income'||kind=='expense')){
     await _m1011SaveReviewedSmsKind(
      id:id,body:body,sender:sender,income:kind=='income');
    }
   }else if(decision=='yes'&&mounted&&canConfirm&&
             reviewedAccount!=null&&originalAmount!=null&&
             originalDate!=null){
    await _m565ConfirmSms(id:id,body:body,sender:sender,
     category:reviewedCategory,income:expectedIncome,
     value:originalAmount.amount,date:originalDate,
     selectedAccount:reviewedAccount!);
   }else if(decision=='no'&&mounted){
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender,reviewedSmsId:id);
    if(smsHashes.contains(bankSmsHash(body,nativeId:id))){
     final ack=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(ack&&mounted){
      setState(()=>_autoSmsPending.removeWhere((r)=>r['id']==id));
     }
    }
   }else if(decision=='manual'&&mounted){
    // Keep the SMS's verified source/hash instead of replacing it with
    // a blank 'manual' record. Uncertain fields remain editable.
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender,reviewedSmsId:id);
    if(smsHashes.contains(bankSmsHash(body,nativeId:id))){
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }else if(mounted){
      // The confirmed finance hash prevents a duplicate debit on retry.
      // A failed Android acknowledgement must retain the review row.
      snack(context,waffraIsEnglish?
       'Saved transaction, but could not remove the SMS from review. Retry safely.':
       'تم حفظ العملية، لكن تعذر إزالة الرسالة من المراجعة. أعد المحاولة بأمان.',
       isError:true);
     }
    }
   }else if(decision=='review'&&mounted){
    // M636: the verified SMS editor remains, while the paste template is retired.
    await entrySheet(sms:true,initialSms:body,reviewedSender:sender,reviewedSmsId:id);
    if(smsHashes.contains(bankSmsHash(body,nativeId:id))){
     // M484 #411: remove from review only after an exact saved SMS hash
     // and the native acknowledgement both succeed.
     final acknowledged=await WaffraAutoSms.acknowledgeCommitted([id]);
     if(acknowledged&&mounted){
      setState(()=>_autoSmsPending.removeWhere((row)=>row['id']==id));
     }else if(mounted){
      snack(context,waffraIsEnglish?
       'Saved transaction, but message removal failed. Retry safely.':
       'تم حفظ العملية، لكن تعذر إزالة الرسالة من المراجعة. أعد المحاولة.',
       isError:true);
     }
     if(acknowledged&&mounted&&_smsRuleOwnerKey.isNotEmpty){
      // Once a confirmed entry is committed, learn only a specific and
      // verified bank direction; generic/uncertain categories need review.
      try{
       // The user's FINAL saved category wins over pre-review guesses.
       // Only use a record verified back from the encrypted ledger.
       final confirmed=entries.where((entry)=>entry.sourceType=='sms'&&
        entry.notes.isNotEmpty&&
        bankSmsHash(entry.notes)==bankSmsHash(body)).toList();
       final match=confirmed.length==1?confirmed.single:null;
       final expectedIncome=facts.kind==WaffraBankOperationKind.income;
       final specific=match!=null&&
        (facts.kind==WaffraBankOperationKind.income||
         facts.kind==WaffraBankOperationKind.expense)&&
        match.income==expectedIncome&&
        categories.any((c)=>c.name==match.category&&
         c.income==match.income&&c.isSubcategory&&
         waffraCategoryAvailableForNewEntry(categories,c));
       final learned=specific?
        await _learnSafeSmsRule(
         body:body,sender:sender,
         kind:expectedIncome?'income':'expense',
         category:match.category):false;
       // Unsafe keywords? Preserve the saved entry, no forced rule popup.
       if(learned&&mounted){
        snackSuccess(context,waffraIsEnglish?
         'Matching SMS rule saved automatically.':
         'اتحفظت قاعدة الرسائل المطابقة تلقائيًا.');
       }
      }catch(_){
       if(mounted)snack(context,waffraIsEnglish?
        'Could not securely save a rule; your confirmed transaction is unchanged.':
        'تعذر حفظ قاعدة التصنيف بأمان. العملية المالية المؤكدة لم تتغير.',
        isError:true);
      }
     }
    }
   }
  }finally{
   _autoSmsReviewOpen=false;
   // Another Android notice tapped during this review is still waiting.
   if(mounted&&waffraFinanceNoticeTap.value!=null){
    WidgetsBinding.instance.addPostFrameCallback((_){
     if(mounted)_m621OnFinanceNoticeTap();
    });
   }
   // A simple Back/Cancel only inspected an already loaded SMS. Reloading
   // and reclassifying 1000 encrypted messages after every closed dialog
   // caused avoidable jank. Successful exclusion, transfer and
   // finance-save paths already update the live queue or refresh explicitly.
   // An unchanged review never posts, ACKs, or invalidates the snapshot.
  }
 }
}

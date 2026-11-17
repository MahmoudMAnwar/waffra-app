part of 'main.dart';

/// M452: no cloud network calls from WorkManager. The owner can authorize
/// recurring FINANCIAL posting only by explicitly saving a custom rule bound
/// to a named, verified account and its four-digit bank SMS suffix.
///
/// All failed, uncertain, unbound, transfer and sensitive verification
/// messages remain review-only. Nothing touches Cash by default.
abstract final class WaffraAutoSmsAutoPoster {
 static bool get reviewOnly => false; // Only an approved per-rule match can post.

 static Future<Map<String,int>> run()async{
  final stopwatch=Stopwatch()..start();
  const budget=Duration(seconds:35);
  final summary=<String,int>{
   'saved':0,'duplicates':0,'review':0,'remaining':0,
  };
  if(!await WaffraAutoSms.enabled())return summary;
  final pending=await WaffraAutoSms.pendingChecked();
  if(pending==null){
   // Missing native data is NOT a clean or completed queue.
   throw StateError('Encrypted SMS queue unavailable');
  }
  final prefs=await SharedPreferences.getInstance();
  await prefs.reload();
  final rawProfile=prefs.getString('waffra_profile');
  // Reuse the same source-independent rule evaluator as Home's isolate:
  // built-in safe exclusions must work even if account/rule recovery fails.
  // A missing owner or unreadable custom store only disables custom rules
  // and account-bound auto posting; never invents a bank account.
  String owner='';
  if(rawProfile!=null&&rawProfile.isNotEmpty){
   try{
    final profile=Person.fromJson(
     Map<String,dynamic>.from(jsonDecode(rawProfile) as Map));
    owner=WaffraSmsLocalRuleStore.ownerKey(
     provider:profile.provider,phone:profile.phone,email:profile.email);
   }catch(_){}
  }
  var ruleStoreReady=false;
  var rules=<WaffraSmsLocalRule>[];
  if(owner.isNotEmpty){
   try{
    rules=await const WaffraSmsLocalRuleStore().read(owner);
    ruleStoreReady=true;
   }catch(_){
    // Do not silently apply unknown/corrupt custom rules.
    // All non-excluded SMS remain available for owner review.
   }
  }
  // Rules unavailability is part of the revision. A later successful
  // owner-rule load makes a previously reviewed SMS eligible for REVIEW
  // reclassification, but never a retroactive unconfirmed money write.
  final ruleRevision=waffraSmsRulesRevision(owner,ruleStoreReady,
   rules.map((r)=>Map<String,Object?>.from(r.toJson())).toList(growable:false));
  final notificationsAllowed=await WaffraAutoSms.notificationsAllowed();
  final pass=WaffraSmsBackgroundCheckpoint.select(pending,maxPerPass:25,
   currentRulesRevision:ruleRevision,notificationsAllowed:notificationsAllowed);
  if(pass.candidates.isEmpty)return summary;
  var completed=0;
  summary['remaining']=pass.unattempted;
  void completedOne(){
   completed++;
   summary['remaining']=WaffraSmsBackgroundCheckpoint.remainingAfter(
    pass.unattempted,completed);
  }
  // A failed native ACK or encrypted checkpoint cannot be called complete.
  final retryAck=StateError('Native SMS ACK pending verification');
  final retryCheckpoint=StateError('Encrypted SMS checkpoint unavailable');

  Future<void> keepForReview(Map<String,Object?> candidate)async{
   final id=candidate['id'];
   final body=candidate['body'];
   if(id is String){
    final kind=body is String?
     (WaffraBankSmsFactsParser.reviewSuggestedKind(
      body:body,sensitiveOtp:candidate['sensitiveOtp']==true)??
      'uncertain'):'uncertain';
    // A classification is not a verified financial commit. Every suggested
    // transaction, including transfers, still opens explicit user review.
    final delivered=await WaffraAutoSms.notifyReview(id,kind:kind);
    if(!await WaffraAutoSms.markBackgroundReviewed(id,revision:ruleRevision,
      notificationDelivered:delivered)){
     throw retryCheckpoint;
    }
    summary['review']=summary['review']!+1;
    completedOne();
   }else{
    throw retryCheckpoint;
   }
  }

  final actionable=<Map<String,Object?>>[];
  // M980: classify each original, owner-scoped SMS against four rule kinds
  // exactly once, then reuse the same matches for safe posting eligibility.
  final matchedById=<String,List<WaffraSmsLocalRule>>{};
  summary['excluded']=0;
  for(final row in pass.candidates){
   if(stopwatch.elapsed>=budget)break;
   final id=row['id'],body=row['body'],sender=row['sender'];
   if(id is String&&body is String&&sender is String){
    final facts=WaffraBankSmsFactsParser.parse(body);
    final kind=row['sensitiveOtp']==true?
     WaffraBankOperationKind.uncertain:facts.kind;
    final fourWay=WaffraSmsLocalRules.matchAllFourKinds(
     body:body,sender:sender,custom:rules);
    matchedById[id]=fourWay;
    final rule=WaffraSmsLocalRules.resolveSpecial(
     body:body,sender:sender,bankKind:kind,custom:rules,
     nativeSensitiveOtp:row['sensitiveOtp']==true,
     matchedRules:fourWay);
    if(rule?.resolvedKind=='excluded'){
     // The exact native fingerprint goes into the durable 30-day excluded
     // ledger, not just a transient acknowledge(). No repeat after rescan.
     // resolveSpecial already rejects posted and mixed financial notices.
     if(await WaffraAutoSms.excludeMessages([id])){
      summary['excluded']=summary['excluded']!+1;
      completedOne();
      continue;
     }
    }
   }
   actionable.add(row);
  }
  if(actionable.isEmpty)return summary;
  if(!ruleStoreReady||!rules.any((r)=>r.autoPost)){
   for(final row in actionable){
    if(stopwatch.elapsed>=budget)break;
    await keepForReview(row);
   }
   return summary;
  }

  WaffraProductionFinanceAuthorityBinding? binding;
  try{
   // The account-aware writer exists only for a verified, activated source.
   // Guarded legacy must not gain a second/shadow money authority.
   binding=await WaffraProductionFinanceAuthorityBinding.bind(
    installedApp:true,legacy:const WaffraHomeFinancePersistence(),
    startupRoute:WaffraFinanceRoute.widgetStartup);
   if(binding.accountsBridge==null){
    for(final row in actionable){
     if(stopwatch.elapsed>=budget)break;
     await keepForReview(row);
    }
    return summary;
   }
   // M1017: traverse every candidate; 25 is batch size, NOT a hard cap.
   for(final batch in waffraSmsBackgroundBatches(actionable)){
    if(stopwatch.elapsed>=budget)break;
    for(final candidate in batch){
    if(stopwatch.elapsed>=budget)break;
    final id=candidate['id'];
    // Once a prior incoming SMS was review-only, a new rule revision may
    // update its suggestion but must not silently post historical money.
    final previouslyAttempted=candidate['backgroundAttempted']==true;
    if(previouslyAttempted){
     await keepForReview(candidate);continue;
    }
    final body=candidate['body'];
    final sender=candidate['sender'];
    final at=candidate['receivedAt'];
    if(id is! String||body is! String||sender is! String||
       at is! int||body.trim().isEmpty||candidate['sensitiveOtp']==true){
     await keepForReview(candidate);
     continue;
    }
    try{
     final facts=WaffraBankSmsFactsParser.parse(body);
     final parsed=BankParser.parse(body);
     // Transfers and card settlements must NOT be saved as income/expense.
     if(facts.pending||!facts.canAutoPostAsIncomeExpense||
        parsed.amount==null||parsed.amount!<=0||
        parsed.requiresCurrencyReview||
        WaffraSmsCurrencies.requiresReviewForSarLedger(body)||
        (facts.kind==WaffraBankOperationKind.income)!=parsed.income){
      await keepForReview(candidate);continue;
     }
     final matched=WaffraSmsLocalRules.resolve(
      body:body,sender:sender,bankKind:facts.kind,custom:rules,
      matchedRules:matchedById[id]);
     if(matched==null||matched.builtIn||!matched.autoPost||
        matched.sender.isEmpty||matched.accountId.isEmpty||
        matched.accountSuffix.isEmpty||matched.income!=parsed.income){
      await keepForReview(candidate);continue;
     }
     // The rule is bound to the exact account suffix and sender that the
     // user reviewed. Other accounts at the same bank remain review-only.
     final suffix=parsed.income?
      facts.destinationSuffix:facts.sourceSuffix;
     if(suffix==null||suffix!=matched.accountSuffix){
      await keepForReview(candidate);continue;
     }
     final arrived=DateTime.fromMillisecondsSinceEpoch(at);
     final date=bankSmsDate(body,referenceDate:arrived);
     if(date==null||bankSmsHasUnverifiedTimestamp(body,referenceDate:arrived)){
      await keepForReview(candidate);continue;
     }
     final decision=WaffraAutoSmsPolicy.decide(
      sender:sender,sms:body,parsedAmount:parsed.amount,
      parsedIncome:parsed.income,foreignCurrency:false,
      arrived:arrived,verifiedDate:date,
      accountLinked:true,sourceAccountVerified:true);
     if(!decision.canPost){
      await keepForReview(candidate);continue;
     }
     final bridge=binding.accountsBridge!;
     final accounts=await bridge.readVerifiedAccounts();
     final accountValid=accounts.balances.any((a)=>
      a.id==matched.accountId&&!a.archived&&
      (a.kind=='bank'||a.kind=='wallet'));
     if(!accountValid){
      await keepForReview(candidate);continue;
     }
     final before=await binding.authority.load(
      route:WaffraFinanceRoute.widgetRead);
     before.finance.requireIntegrity();
     final catalogRaw=before.finance.getString('waffra_categories_v24');
     if(catalogRaw==null){
      await keepForReview(candidate);continue;
     }
     final categories=(jsonDecode(catalogRaw) as List).map((row)=>
      BudgetCategory.fromJson(Map<String,dynamic>.from(row as Map)))
      .toList(growable:false);
     // A named budget must be explicitly selected by the owner; never guess
     // a budget for background SMS, and never auto-create one from a message.
     // This guard runs AFTER the trusted account and finance-source read but
     // BEFORE the atomic SMS ledger commit. Income has no budget allocation.
     final budgetRaw=before.finance.getString('waffra_named_budgets_v1');
     final budgets=budgetRaw==null?const <WaffraNamedBudget>[]:
      (jsonDecode(budgetRaw) as List).map((row)=>
       WaffraNamedBudget.fromJson(Map<String,dynamic>.from(row as Map)))
       .toList(growable:false);
     final needsBudgetChoice=!parsed.income&&(
      budgets.any((b)=>!b.deleted&&b.budgetActive&&b.budget>0)||
      // Historic category budgets can exist before stand-alone migration.
      categories.any((c)=>!c.income&&c.budgetActive&&c.budget>0));
     if(needsBudgetChoice){
      await keepForReview(candidate);
      continue;
     }
     if(!categories.any((c)=>c.isSubcategory&&
       c.name==matched.category&&c.income==matched.income&&
       waffraCategoryAvailableForNewEntry(categories,c))){
      await keepForReview(candidate);continue;
     }
     final fingerprint=bankSmsHash(body,nativeId:id);
     final finalHashesLegacy=before.finance.getStringList('waffra_sms_hashes_v1')??
         const <String>[];
     if(finalHashesLegacy.contains(fingerprint)){
      if(!await WaffraAutoSms.acknowledgeCommitted([id])){
       throw retryAck;
      }
      summary['duplicates']=summary['duplicates']!+1;
      completedOne();
      continue;
     }
     if(finalHashesLegacy.contains(bankSmsHash(body))){
      // An old body-only hash does not prove whether this independently
      // received SMS is a duplicate. Leave it for owner review.
      await keepForReview(candidate);
      continue;
     }
     final entry=MoneyEntry(
      id:newId(),
      title:waffraSafeSmsTransactionTitle(
       parsed.title,body,income:parsed.income),
      category:matched.category,
      amount:parsed.amount!,income:parsed.income,
      date:date,notes:body,sourceType:'sms',
      merchantKey:waffraMerchantKey(body,income:parsed.income)??'',
     );
     // Saving the account-bound AutoPost checkbox and rule was the user's
     // standing confirmation for future EXACT matches; no separate UI tap
     // is fabricated by the worker.
     final committed=await binding.authority.commitConfirmedSms(
      route:WaffraFinanceRoute.widgetSmsConfirmedSave,
      records:[Map<String,Object?>.from(entry.toJson())],
      hashes:[fingerprint],
      userConfirmed:true,allowDuplicateHashes:false,
      selectedAccountIds:[matched.accountId],
      expectedAccountGeneration:accounts.witness.generation,
     );
     final finalHashes=committed.current.finance
      .getStringList('waffra_sms_hashes_v1')??const <String>[];
     final ledgerRaw=committed.current.ledgerRaw;
     final persisted=ledgerRaw!=null&&
      (jsonDecode(ledgerRaw) as List).any((item)=>
       item is Map&&item['id']==entry.id);
     if(committed.saved==1&&persisted&&
        finalHashes.contains(fingerprint)){
      if(!await WaffraAutoSms.acknowledgeCommitted([id])){
       throw retryAck;
      }
      completedOne();
      // M1031: bank-SMS AutoPost is a verified income/expense commit too.
      // Record its encrypted owner-scoped learning receipt; a failure
      // must never replay the money writer or undo its acknowledged hash.
      try{
       if(owner.isNotEmpty){
        final store=const WaffraSmsLocalRuleStore();
        await store.recordConfirmedFinanceLearning(
         owner:owner,transactionId:entry.id,sourceType:'sms',
         income:entry.income,category:entry.category);
        final safe=WaffraSmsLocalRules.manualCategoryPattern(
         description:entry.title,category:entry.category,
         income:entry.income);
        if(safe!=null){
         await store.learnReviewedCandidates(owner,[safe]);
        }
       }
      }catch(_){
       // The ledger was committed and the native ID acknowledged. Preserve
       // that authority; the original ledger can be reconciled later.
      }
      await WaffraAutoSms.notifyCommitted(
       hash:id,amount:parsed.amount!,income:parsed.income,
       linkedBudget:false,entryId:entry.id);
      summary['saved']=summary['saved']!+1;
     }else if(committed.saved==0&&
         finalHashes.contains(fingerprint)){
      if(!await WaffraAutoSms.acknowledgeCommitted([id])){
       throw retryAck;
      }
      summary['duplicates']=summary['duplicates']!+1;
      completedOne();
     }else{
      await keepForReview(candidate);
     }
    }catch(error){
     if(identical(error,retryAck)||identical(error,retryCheckpoint))rethrow;
     // Never log bank SMS, account ID, or secure-store exceptions.
     await keepForReview(candidate);
    }
    }
    // Let platform-channel delivery and cancellation signals run between
    // groups. Never perform parallel encrypted financial writes.
    await Future<void>.delayed(Duration.zero);
   }
  }catch(error){
   if(identical(error,retryAck)||identical(error,retryCheckpoint))rethrow;
   // Vault unavailable: keep the limited pass for human review, no legacy
   // writes. Any remaining uncheckpointed SMS is resumed by WorkManager.
   final latest=await WaffraAutoSms.pendingChecked();
   if(latest==null)rethrow; // Never mistake vault failure for an empty queue.
   final stillUnattempted=latest.where(
    (row)=>row['backgroundAttempted']!=true,
   ).map((row)=>row['id']).whereType<String>().toSet();
   for(final row in actionable){
    if(stopwatch.elapsed>=budget)break;
    if(!stillUnattempted.contains(row['id']))continue;
    await keepForReview(row);
   }
  }finally{
   await binding?.close();
  }
  return summary;
 }
}

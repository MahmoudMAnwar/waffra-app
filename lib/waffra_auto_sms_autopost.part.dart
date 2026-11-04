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
  final summary=<String,int>{'saved':0,'duplicates':0,'review':0};
  if(!await WaffraAutoSms.enabled())return summary;
  final pending=await WaffraAutoSms.pendingChecked();
  if(pending==null)return summary;
  if(pending.isEmpty)return summary;

  Future<void> keepForReview(Map<String,Object?> candidate)async{
   summary['review']=summary['review']!+1;
   final id=candidate['id'];
   if(id is String)await WaffraAutoSms.notifyReview(id);
  }

  final prefs=await SharedPreferences.getInstance();
  await prefs.reload();
  final rawProfile=prefs.getString('waffra_profile');
  if(rawProfile==null||rawProfile.isEmpty){
   for(final row in pending)await keepForReview(row);
   return summary;
  }
  String owner='';
  try{
   final profile=Person.fromJson(
    Map<String,dynamic>.from(jsonDecode(rawProfile) as Map));
   owner=WaffraSmsLocalRuleStore.ownerKey(
    provider:profile.provider,phone:profile.phone,email:profile.email);
  }catch(_){}
  if(owner.isEmpty){
   for(final row in pending)await keepForReview(row);
   return summary;
  }
  List<WaffraSmsLocalRule> rules;
  try{
   rules=await const WaffraSmsLocalRuleStore().read(owner);
  }catch(_){
   // A broken user-specific key may not silently fall back to generic
   // rules or erase the encrypted review queue.
   for(final row in pending)await keepForReview(row);
   return summary;
  }
  if(!rules.any((r)=>r.autoPost)){
   for(final row in pending)await keepForReview(row);
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
    for(final row in pending)await keepForReview(row);
    return summary;
   }
   for(final candidate in pending.take(25)){
    final id=candidate['id'];
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
      body:body,sender:sender,bankKind:facts.kind,custom:rules);
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
     if(bankSmsHasUnverifiedTimestamp(body,referenceDate:arrived)){
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
     if(!categories.any((c)=>c.isSubcategory&&
       c.name==matched.category&&c.income==matched.income&&
       waffraCategoryAvailableForNewEntry(categories,c))){
      await keepForReview(candidate);continue;
     }
     final fingerprint=bankSmsHash(body);
     if((before.finance.getStringList('waffra_sms_hashes_v1')??
         const <String>[]).contains(fingerprint)){
      await WaffraAutoSms.acknowledge([id]);
      summary['duplicates']=summary['duplicates']!+1;
      continue;
     }
     final entry=MoneyEntry(
      id:newId(),
      title:waffraSafeSmsTransactionTitle(
       parsed.title,body,income:parsed.income),
      category:matched.category,
      amount:parsed.amount!,income:parsed.income,
      date:date??arrived,notes:body,sourceType:'sms',
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
      expectedAccountGeneration:accounts.generation,
     );
     final finalHashes=committed.current.finance
      .getStringList('waffra_sms_hashes_v1')??const <String>[];
     final ledgerRaw=committed.current.ledgerRaw;
     final persisted=ledgerRaw!=null&&
      (jsonDecode(ledgerRaw) as List).any((item)=>
       item is Map&&item['id']==entry.id);
     if(committed.saved==1&&persisted&&
        finalHashes.contains(fingerprint)){
      await WaffraAutoSms.acknowledge([id]);
      await WaffraAutoSms.notifyCommitted(
       hash:id,amount:parsed.amount!,income:parsed.income,
       linkedBudget:false);
      summary['saved']=summary['saved']!+1;
     }else if(committed.saved==0&&
         finalHashes.contains(fingerprint)){
      await WaffraAutoSms.acknowledge([id]);
      summary['duplicates']=summary['duplicates']!+1;
     }else{
      await keepForReview(candidate);
     }
    }catch(_){
     // Never log bank SMS, account ID, or secure-store exceptions.
     await keepForReview(candidate);
    }
   }
  }catch(_){
   // Vault unavailable: keep all SMS for human review, no legacy writes.
   for(final row in pending)await keepForReview(row);
  }finally{
   await binding?.close();
  }
  return summary;
 }
}

part of 'main.dart';

/// M418: a one-time explicit opt-in authorizes confirmed, high-confidence
/// automatic bank transaction imports. A sender or LLM is never a finance
/// authority; the existing cross-engine writer owns ALL money and SMS hashes.
///
/// Separate from the user's main UI: the Android SMS worker can execute the
/// identical code when Waffra is closed. On failure, the encrypted message
/// stays queued; never report that a transaction was recorded.
abstract final class WaffraAutoSmsAutoPoster {
 static Future<Map<String,int>> run()async{
  final summary=<String,int>{'saved':0,'duplicates':0,'review':0};
  if(!await WaffraAutoSms.enabled())return summary;
  final prefs=await SharedPreferences.getInstance();
  await prefs.reload();
  // No guest data writes before first-run profile setup. Old installed
  // profiles remain unchanged and their finance source is never reset.
  final profile=prefs.getString('waffra_profile');
  if(profile==null||profile.isEmpty||
     prefs.getBool('waffra_onboarding_completed')!=true)return summary;
  final batch=await WaffraAutoSms.pending();
  if(batch.isEmpty)return summary;
  final binding=await WaffraProductionFinanceAuthorityBinding.bind(
   legacy:const WaffraHomeFinancePersistence(),
   startupRoute:WaffraFinanceRoute.widgetStartup);
  try{
   for(final candidate in batch.take(25)){
    if(!await WaffraAutoSms.enabled())break;
    final id=candidate['id'],body=candidate['body'];
    final sender=candidate['sender'];
    final at=candidate['receivedAt'];
    if(id is! String||body is! String||sender is! String||
       at is! int||body.trim().isEmpty)continue;
    final hash=bankSmsHash(body);
    // Never trust a stale in-memory Home cache: verify each message under the
    // shared Home/Widget finance journal and retry safely after partial saves.
    final loaded=await binding.authority.load(route:WaffraFinanceRoute.widgetRead);
    loaded.finance.requireIntegrity();
    final known=loaded.finance.getStringList('waffra_sms_hashes_v1')??const <String>[];
    if(known.contains(hash)){
     await WaffraAutoSms.acknowledge([id]);
     summary['duplicates']=summary['duplicates']!+1;
     continue;
    }
    // When a user separately enabled cloud analysis, process matching SMS
    // through the authenticated Firebase -> OpenRouter path even with the UI
    // closed. Only redacted payloads leave the device; suggestions are cached
    // inside the already-encrypted Android SMS queue.
    Map<String,Object?>? cloud;
    if(candidate['cloud'] is Map){
     cloud=Map<String,Object?>.from(candidate['cloud'] as Map);
    }else{
     cloud=await WaffraSmsCloudService.analyzeIfConsented(body);
     if(cloud!=null)await WaffraAutoSms.stageCloudAnalysis(id,cloud);
    }
    final parsed=BankParser.parse(body);
    final arrived=DateTime.fromMillisecondsSinceEpoch(at);
    final date=bankSmsDate(body,referenceDate:arrived);
    final preliminary=WaffraAutoSmsPolicy.decide(
     sender:sender,sms:body,parsedAmount:parsed.amount,
     parsedIncome:parsed.income,foreignCurrency:
      parsed.requiresCurrencyReview||WaffraSmsCurrencies.requiresReviewForSarLedger(body),
     arrived:arrived,verifiedDate:date,
    );
    // The LLM may veto an unsafe candidate, never fabricate a verified
    // bank amount. Conflicts go to review instead of changing balances.
    final cloudAmount=cloud?['amount'];
    final cloudCurrency=cloud?['currency'];
    final cloudKind=cloud?['kind'];
    final disagree=cloud!=null&&(
      cloud['requiresReview']==true||
      cloudAmount is! num||parsed.amount==null||
      (cloudAmount.toDouble()-parsed.amount!).abs()>0.001||
      cloudCurrency!='SAR'||
      cloudKind!=(parsed.income?'income':'expense'));
    if(disagree||!preliminary.canPost||
       bankSmsHasUnverifiedTimestamp(body,referenceDate:arrived)){
     summary['review']=summary['review']!+1;
     await WaffraAutoSms.notifyReview(id);
     continue;
    }
    final categoriesRaw=loaded.finance.getString('waffra_categories_v24');
    final categories=categoriesRaw==null?defaultCategories():
     (jsonDecode(categoriesRaw) as List).map((row)=>
      BudgetCategory.fromJson(Map<String,dynamic>.from(row as Map))).toList();
    final merchant=waffraMerchantKey(body,income:parsed.income)??'';
    final rulesRaw=loaded.finance.getString('waffra_learned_merchants_v1');
    final rules=rulesRaw==null?<String,String>{}:
     Map<String,String>.from(jsonDecode(rulesRaw) as Map);
    final safeLeaf=waffraRecognizedSmsLeaf(body,
     income:parsed.income,
     merchant:waffraMerchantName(body,income:parsed.income));
    final suggestions=<String>[
     if(merchant.isNotEmpty&&rules[merchant]!=null)rules[merchant]!,
     if(safeLeaf!=null)safeLeaf,
     if(parsed.suggestedCategory!=null)parsed.suggestedCategory!,
     parsed.category,
     if(parsed.income)'دخل آخر / دخل غير مصنف'
     else 'أخرى / مصروف غير مصنف',
    ];
    BudgetCategory? category;
    for(final label in suggestions){
     for(final c in categories){
      if(c.name==label&&c.income==parsed.income&&c.isSubcategory&&
         waffraCategoryAvailableForNewEntry(categories,c)){
       category=c;
       break;
      }
     }
     if(category!=null)break;
    }
    if(category==null){
     summary['review']=summary['review']!+1;
     await WaffraAutoSms.notifyReview(id);
     continue;
    }
    // Only a user's earlier budget selection for the SAME merchant may be
    // inherited. Budget names do not imply an accounting link.
    String? budgetId;
    if(!parsed.income&&merchant.isNotEmpty){
     final ledgerRaw=loaded.ledgerRaw;
     final budgetsRaw=loaded.finance.getString('waffra_named_budgets_v1');
     if(ledgerRaw!=null&&budgetsRaw!=null){
      final budgets=(jsonDecode(budgetsRaw) as List)
       .map((row)=>WaffraNamedBudget.fromJson(
        Map<String,dynamic>.from(row as Map)))
       .where((b)=>!b.deleted&&b.budgetActive&&b.budget>0)
       .toList();
      final activeIds={for(final b in budgets)b.id};
      final previous=(jsonDecode(ledgerRaw) as List)
       .map((row)=>MoneyEntry.fromJson(Map<String,dynamic>.from(row as Map)))
       .where((e)=>!e.income&&e.merchantKey==merchant&&
         e.budgetId!=null&&activeIds.contains(e.budgetId))
       .map((e)=>e.budgetId!).toSet();
      if(previous.length==1)budgetId=previous.single;
     }
    }
    final transaction=MoneyEntry(
     id:newId(),
     title:waffraSafeSmsTransactionTitle(parsed.title,body,income:parsed.income),
     category:category.name,
     amount:parsed.amount!,
     income:parsed.income,
     date:date??arrived,
     sourceType:'sms',notes:body,merchantKey:merchant,
     budgetId:budgetId,
    );
    // The user enabled automatic posting with the initial prominent consent.
    // The legacy writer's confirmation flag represents THIS standing consent
    // plus the strict local eligibility gate, not a tap on every bank message.
    final committed=await binding.authority.commitConfirmedSms(
     route:WaffraFinanceRoute.widgetSmsConfirmedSave,
     records:[Map<String,Object?>.from(transaction.toJson())],
     hashes:[hash],userConfirmed:true,allowDuplicateHashes:false);
    final resulting=committed.current;
    resulting.finance.requireIntegrity();
    final actualHashes=resulting.finance.getStringList('waffra_sms_hashes_v1')??const <String>[];
    final ledger=resulting.ledgerRaw;
    if(ledger==null||!actualHashes.contains(hash)){
     // Do not claim success without verified atomic hash + finance witness.
     throw StateError('Automatic bank SMS commit witness is missing');
    }
    final persisted=(jsonDecode(ledger) as List).any((row)=>
      row is Map&&row['id']==transaction.id);
    if(committed.saved==1&&persisted){
     await WaffraAutoSms.acknowledge([id]);
     await WaffraAutoSms.notifyCommitted(hash:id,amount:parsed.amount!,
      income:parsed.income,linkedBudget:budgetId!=null);
     summary['saved']=summary['saved']!+1;
    }else if(committed.saved==0){
     await WaffraAutoSms.acknowledge([id]);
     summary['duplicates']=summary['duplicates']!+1;
    }else{
     throw StateError('Automatic SMS finance ID mismatch');
    }
   }
  }finally{await binding.close();}
  return summary;
 }
}

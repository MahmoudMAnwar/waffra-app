part of 'main.dart';

/// M741 / Issue #633: original local SMS classification and learning.
/// Preserve owner key, verified account choices, currency/date and no-cloud policy.
extension _WaffraHomeSmsRules on _HomeScreenState {
 Future<void> _openSmsRules({String? seedMessage,String? seedKind,
  String seedSender='',String seedCategory=''})async{
  if(_smsRuleOwnerKey.isEmpty){
   if(mounted)snack(context,waffraIsEnglish?
    'Sign in with a verified phone or email before editing SMS rules.':
    'سجل دخولك برقم جوال أو بريد مؤكد قبل تعديل القواعد.',isError:true);
   return;
  }
  final bankAccounts=<String,String>{};
  try{
   final verified=await _financeBinding?.accountsBridge?.readVerifiedAccounts();
   if(verified!=null){
    for(final account in verified.balances.where((a)=>!a.archived)){
     if(account.kind=='bank'||account.kind=='wallet'){
      bankAccounts[account.id]=account.name;
     }
    }
   }
  }catch(_){ /* Local rules still work without SQLCipher accounts. */ }
  if(!mounted)return;
  final facts=seedMessage==null?null:
   WaffraBankSmsFactsParser.parse(seedMessage);
  final suffix=seedKind=='income'?
   (facts?.destinationSuffix??''):
   (facts?.sourceSuffix??'');
  final ruleSaved=await Navigator.push<bool>(context,MaterialPageRoute(
   builder:(_)=>WaffraSmsRuleSettingsPage(
    english:waffraIsEnglish,ownerKey:_smsRuleOwnerKey,
    seedKind:seedKind,seedSender:seedSender,
    seedCategory:seedCategory,
    seedAccountSuffix:suffix,bankAccounts:bankAccounts,
    scannedMessages:_autoSmsPending.map((row)=>
     row['body'] is String?row['body'] as String:'').toList(),
    scannedSenders:_autoSmsPending.map((row)=>
     row['sender'] is String?row['sender'] as String:'').toList(),
    incomeCategories:categories.where((c)=>c.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c))
     .map((c)=>c.name).toList(),
    expenseCategories:categories.where((c)=>!c.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c))
     .map((c)=>c.name).toList(),
    seedMessage:seedMessage,
    onNotice:(message)=>snack(context,message),
    // M661: manual (+) rule saves also reclassify the current native queue.
    onRulesChanged:()=>_receiveAutoSmsNotice(),
   )));
  // Apply saved local rules to the already queued SMS only. Never perform
  // hidden Android history paging during the rule editor's return animation.
  // A partial original-month scan continues only on explicit Rescan.
  if(mounted&&ruleSaved==true)unawaited(_refreshAutoSmsInbox());
 }

 Future<void> _recordConfirmedSmsAccountAssociation({
  required MoneyEntry record,required String sender,
  required String? accountId,
 })async{
  // Learning happens only AFTER a confirmed finance commit. It never posts
  // money, changes a past entry, or sets autoPost classification permissions.
  if(accountId==null||accountId.isEmpty||sender.trim().isEmpty||
     record.sourceType!='sms'||_smsRuleOwnerKey.isEmpty)return;
  final facts=WaffraBankSmsFactsParser.parse(record.notes);
  if(!facts.canAutoPostAsIncomeExpense||
     (facts.kind==WaffraBankOperationKind.income)!=record.income)return;
  try{
   final verified=await _financeBinding?.accountsBridge?.readVerifiedAccounts();
   if(verified==null||!verified.balances.any((a)=>
       !a.archived&&a.id==accountId))return;
   final suffix=record.income?
    facts.destinationSuffix:facts.sourceSuffix;
   await const WaffraSmsAccountLearningStore().confirm(
    owner:_smsRuleOwnerKey,sender:sender,accountId:accountId,
    suffix:suffix);
  }catch(_){
   // Learning is best-effort; a confirmed financial write is never rolled
   // back because a nonauthoritative suggestion could not be persisted.
  }
 }

 // Local classification learning never authorizes financial posting.
 // Only a specific, independently classified message may produce a rule.
 Future<bool> _learnSafeSmsRule({
  required String body,required String sender,
  required String kind,String category='',
 })async{
  if(_smsRuleOwnerKey.isEmpty)return false;
  final candidate=WaffraSmsLocalRules.suggestedRule(
   body:body,sender:sender,kind:kind,category:category,confidentOnly:true);
  if(candidate==null)return false;
  final store=const WaffraSmsLocalRuleStore();
  final prior=await store.read(_smsRuleOwnerKey);
  // Same sender, category and direction are reused. Never change an
  // already-authorized autoPost rule's matching criteria behind the user.
  final updated=WaffraSmsLocalRules.upsertLearned(
   existing:prior,candidate:candidate);
  if(identical(updated,prior))return prior.any((r)=>
   r.resolvedKind==kind&&r.category==category&&
   WaffraSmsLocalRules.matches(r,body,sender:sender));
  await store.write(_smsRuleOwnerKey,updated);
  // M651: a newly confirmed sender-specific rule must update old pending
  // SMS suggestions too. The existing debounce refresh imports no history,
  // classifies on a worker isolate, and never authorizes a money posting.
  _receiveAutoSmsNotice();
  return true;
 }

 /// Manual entries have no bank SMS sender. Learn only a non-posting
 /// description/category hint after an independently verified save.
 Future<void> _learnManualTransferPreference()async{
  if(_smsRuleOwnerKey.isEmpty)return;
  final store=const WaffraSmsLocalRuleStore();
  final original=await store.read(_smsRuleOwnerKey);
  final updated=WaffraSmsLocalRules.upsertLearned(
   existing:original,candidate:WaffraSmsLocalRules.manualTransferPattern());
  if(!identical(original,updated)){
   await store.write(_smsRuleOwnerKey,updated);
   // Debounced non-posting review refresh; no Android history import.
   _receiveAutoSmsNotice();
  }
 }
 // Reuse one senderless review-only category bucket after a committed
 // manual OR bank-SMS entry; sender/suffix account learning stays separate.
 Future<void> _learnManualCategoryPreference(MoneyEntry record)async{
  if(_smsRuleOwnerKey.isEmpty||
     (record.sourceType!='manual'&&record.sourceType!='sms'))return;
  final merchant=waffraMerchantKey(record.title,income:record.income)??record.title;
  final candidate=WaffraSmsLocalRules.manualCategoryPattern(
   description:merchant,category:record.category,income:record.income);
  if(candidate==null)return;
  final store=const WaffraSmsLocalRuleStore();
  final previous=await store.read(_smsRuleOwnerKey);
  final next=WaffraSmsLocalRules.upsertLearned(
   existing:previous,candidate:candidate);
  if(!identical(next,previous)){
   await store.write(_smsRuleOwnerKey,next);
   // The pending queue is reclassified on its existing background isolate.
   _receiveAutoSmsNotice();
  }
 }

 // Retained single-message reference for on-demand review and M473 parity;
 // the production bulk queue now uses the background compute worker.
 // ignore: unused_element
 Map<String,Object?>? _localSmsClassification(
  Map<String,Object?> item,List<WaffraSmsLocalRule> custom){
  final body=item['body'],sender=item['sender'];
  if(body is! String||body.trim().isEmpty)return null;
  final parsed=BankParser.parse(body);
  final facts=WaffraBankSmsFactsParser.parse(body);
  final special=WaffraSmsLocalRules.resolveSpecial(
   body:body,sender:sender is String?sender:'',
   bankKind:item['sensitiveOtp']==true?
    WaffraBankOperationKind.uncertain:facts.kind,
   custom:custom);
  if(special!=null)return <String,Object?>{
   'rule':special.name,'kind':special.resolvedKind,
   'category':special.category,'income':false,
   'defaultSeed':special.builtIn,
  };
  if(facts.pending||parsed.amount==null||parsed.amount!<=0||
     parsed.requiresCurrencyReview||
     WaffraSmsCurrencies.requiresReviewForSarLedger(body))return null;
  if((facts.kind==WaffraBankOperationKind.income)!=parsed.income &&
     (facts.kind==WaffraBankOperationKind.income||
      facts.kind==WaffraBankOperationKind.expense))return null;
  final rule=WaffraSmsLocalRules.resolve(
   body:body,sender:sender is String?sender:'',
   bankKind:facts.kind,custom:custom);
  if(rule==null||!categories.any((c)=>c.name==rule.category&&
     c.income==rule.income&&c.isSubcategory&&
     waffraCategoryAvailableForNewEntry(categories,c)))return null;
  return <String,Object?>{
   'rule':rule.name,'kind':rule.resolvedKind,
   'category':rule.category,'income':rule.income,
  };
 }

}

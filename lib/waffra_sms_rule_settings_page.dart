import 'package:flutter/material.dart';

import 'waffra_sms_local_rules.dart';
import 'waffra_auto_sms.dart';
import 'waffra_sms_rule_simulator.dart';
import 'waffra_bank_sms_facts.dart';
import 'waffra_centered_dropdown.dart';

/// Rules configure offline review suggestions only. This screen has no ledger,
/// bank-account, SMS-permission, or cloud-provider write capability.
class WaffraSmsRuleSettingsPage extends StatefulWidget {
 const WaffraSmsRuleSettingsPage({
  super.key,required this.english,required this.ownerKey,
  required this.scannedMessages,required this.incomeCategories,
  required this.expenseCategories,this.seedMessage,this.seedKind,
  this.seedSender='',this.seedAccountSuffix='',this.seedCategory='',
  this.bankAccounts=const {},this.scannedSenders=const [],
  required this.onNotice,this.onRulesChanged,
 });
 final bool english;
 final String ownerKey;
 final List<String> scannedMessages,incomeCategories,expenseCategories;
 final List<String> scannedSenders;
 final String? seedMessage,seedKind;
 final String seedSender,seedAccountSuffix,seedCategory;
 final Map<String,String> bankAccounts;
 final void Function(String) onNotice;
 final VoidCallback? onRulesChanged;
 @override State<WaffraSmsRuleSettingsPage> createState()=>_WaffraSmsRuleSettingsPageState();
}

class _WaffraSmsRuleSettingsPageState extends State<WaffraSmsRuleSettingsPage>{
 final store=const WaffraSmsLocalRuleStore();
 List<WaffraSmsLocalRule> saved=const [];
 Map<String,int>? confirmedLearningCounts;
 bool loading=true,busy=false,canUndo=false;
 String? error;
 // Native exclusions are a DIFFERENT owner-encrypted policy from keyword rules.
 // A missing Android/consent read is unknown, never reported as zero.
 int? excludedSmsCount,blockedSenderCount;
 List<Map<String,Object?>>? nativeExcluded;
 List<String>? nativeBlockedSenders;
 @override void initState(){
  super.initState();
  _load();
 }
 Future<void> _load()async{
  try{
   final rules=await store.read(widget.ownerKey);
   final undoAvailable=await store.hasUndo(widget.ownerKey);
   Map<String,int>? confirmed;
   try{
    confirmed=await store.confirmedFinanceLearningCounts(widget.ownerKey);
   }catch(_){
    // Learning receipts and classification rules use separate encrypted
    // records. An unreadable receipt must not hide otherwise valid rules.
   }
   List<Map<String,Object?>>? excluded;
   List<String>? blocked;
   try{
    excluded=await WaffraAutoSms.excludedMessages();
    blocked=await WaffraAutoSms.excludedSenders();
   }catch(_){/* Native exclusions unavailable; do NOT show a false zero. */}
   if(!mounted)return;
   setState((){
    saved=rules;confirmedLearningCounts=confirmed;
    canUndo=undoAvailable;loading=false;error=null;
    excludedSmsCount=excluded?.length;
    blockedSenderCount=blocked?.length;
    nativeExcluded=excluded;
    nativeBlockedSenders=blocked;
   });
   if(widget.seedMessage!=null){
    WidgetsBinding.instance.addPostFrameCallback((_){
     if(mounted)_edit(seed:widget.seedMessage,kindHint:widget.seedKind);
    });
   }
  }catch(_){
   if(mounted)setState((){
    loading=false;
    error=widget.english?'Could not unlock your encrypted SMS rules. No rules were changed.':
     'تعذر فتح قواعدك المشفرة. لم يتم تغيير أي قاعدة.';
   });
  }
 }
 Future<bool> _persist(List<WaffraSmsLocalRule> next)async{
  if(busy||error!=null)return false;
  setState(()=>busy=true);
  try{
   await store.writeIfCurrent(widget.ownerKey,expected:saved,next:next);
   if(mounted){
    setState((){saved=next;canUndo=true;});
    // M661: a seedless user-created rule has no route result to signal Home.
    // Persist first, then notify the existing debounced pending-SMS refresh.
    widget.onRulesChanged?.call();
   }
   return true;
  }catch(_){
   if(mounted){
    widget.onNotice(widget.english?
     'Rules changed or could not be saved securely. Reloaded the current rules; no overwrite was performed.':
     'القواعد اتغيرت أو تعذر حفظها. أعدنا تحميل القواعد الحالية بدون الكتابة فوقها.');
    await _load();
   }
   return false;
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _undoLastRuleChange()async{
  if(!mounted||busy||error!=null||!canUndo)return;
  setState(()=>busy=true);
  try{
   final previous=await store.undoLast(widget.ownerKey);
   if(previous==null||!mounted)return;
   final stillUndo=await store.hasUndo(widget.ownerKey);
   if(!mounted)return;
   setState((){saved=previous;canUndo=stillUndo;});
   widget.onRulesChanged?.call();
   widget.onNotice(widget.english?
    'Restored the previous encrypted rule version.':
    'تم استرجاع الإصدار السابق من القواعد المشفرة.');
  }catch(_){
   if(mounted)widget.onNotice(widget.english?
    'Could not restore the previous encrypted rules. Nothing was removed.':
    'تعذر استعادة الإصدار السابق بأمان. لم تُحذف قواعدك.');
  }finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> _remove(WaffraSmsLocalRule rule)async{
  final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
   title:Text(widget.english?'Delete this rule?':'حذف هذه القاعدة؟'),
   content:Text(rule.name),
   actions:[
    TextButton(onPressed:()=>Navigator.pop(ctx,false),
     child:Text(widget.english?'Cancel':'إلغاء')),
    FilledButton(onPressed:()=>Navigator.pop(ctx,true),
     child:Text(widget.english?'Delete':'حذف')),
   ]));
  if(ok==true)await _persist(saved.where((r)=>r.id!=rule.id).toList());
 }
 Future<void> _edit({WaffraSmsLocalRule? existing,String? seed,String? kindHint})async{
  if(busy||error!=null)return;
  if(existing==null&&saved.length>=WaffraSmsLocalRules.maxStoredRules){
   widget.onNotice(widget.english?
    'Rule storage is full. Delete an unused rule before adding another.':
    'وصلت للحد الأقصى للقواعد. احذف قاعدة غير مستخدمة قبل إضافة واحدة جديدة.');
   return;
  }
  final proposed=seed==null?null:WaffraSmsLocalRules.suggestedRule(
   body:seed,sender:widget.seedSender,kind:kindHint??'expense',
   category:widget.seedCategory);
  final name=TextEditingController(text:existing?.name??
   proposed?.name??(seed==null?'':switch(kindHint){
    'income'=>'دخل من البنك','expense'=>'مصروف بنكي',
    'transfer'=>'تحويل بنكي','excluded'=>'رسائل تحقق',
    _=>'رسالة بنكية',
   }));
  final customKeyword=TextEditingController();
  final search=TextEditingController();
  final sender=TextEditingController(text:existing?.sender??widget.seedSender);
  final suffix=TextEditingController(text:existing?.accountSuffix??
   widget.seedAccountSuffix);
  var kind=existing?.resolvedKind??kindHint??'expense';
  var income=kind=='income';
  var autoPost=existing?.autoPost??false;
  var accountId=existing?.accountId??'';
  // M1007: legacy rules keep their original sender. Empty sender is global
  // only after the owner deliberately picks that scope and saves the rule.
  // New rules learn globally by default; historic rules keep their saved
  // sender scope unless their owner explicitly edits it.
  var allSenders=existing==null||existing.sender.trim().isEmpty;
  if(allSenders)autoPost=false;
  // Exclusion rules normally match ANY verified keyword, not every word
  // suggested from one SMS. Matching all is an explicit advanced option.
  var all=existing?.matchAll??(seed==null&&kind!='excluded');
  var category=existing?.category??
   (widget.seedCategory.isNotEmpty?widget.seedCategory:proposed?.category);
  var searchQuery='';
  String? validation;
  final selected=<String>{...?existing?.keywords};
  // Never fall back to the first generic word (e.g. "خصم") for a
  // seeded transfer. Only a rule verified against this SMS may be preselected.
  if(existing==null&&proposed!=null)selected.addAll(proposed.keywords);
  Future<void> addKeyword(StateSetter update)async{
   final keyword=customKeyword.text.trim();
   if(!WaffraSmsLocalRules.safeRuleKeyword(keyword,kind)){
    update(()=>validation=widget.english?
     'Choose a safe word without numbers or account details.':
     'اكتب كلمة واضحة بدون أرقام أو تفاصيل الحساب.');
    return;
   }
   if(selected.length>=12){
    update(()=>validation=widget.english?'Maximum 12 keywords.':'الحد الأقصى ١٢ كلمة.');
    return;
   }
   update((){selected.add(keyword);validation=null;customKeyword.clear();});
  }
  try{
   final result=await showModalBottomSheet<WaffraSmsLocalRule>(
    context:context,isScrollControlled:true,showDragHandle:true,
    builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
     final financial=kind=='income'||kind=='expense';
     final categories=financial?
      (income?widget.incomeCategories:widget.expenseCategories):
      const <String>[];
     if(category!=null&&!categories.contains(category))category=null;
     final candidates=seed==null?
      WaffraSmsLocalRules.suggestions(widget.scannedMessages):
      (WaffraSmsLocalRules.suggestedRule(body:seed,
       sender:widget.seedSender,kind:kind,category:widget.seedCategory)
        ?.keywords??const <String>[]);
     final visible=candidates.where((item)=>WaffraSmsLocalRules.normalized(item)
      .contains(WaffraSmsLocalRules.normalized(searchQuery))).take(60).toList();
     final previewRule=WaffraSmsLocalRule(
      id:'preview',name:name.text.trim().isEmpty?'Preview':name.text,
      keywords:selected.toList(),income:income,category:category??'',
      kind:kind,
      matchAll:kind=='excluded'&&existing?.templateFamily.isNotEmpty==true?
       true:all,
      sender:allSenders?'':sender.text.trim(),
      templateFamily:kind=='excluded'?existing?.templateFamily??'':'',
      contextFragments:kind=='excluded'?
       existing?.contextFragments??const <String>[]:const <String>[]);
     // A seeded bank sender is known. Never fake a 0-match preview by
     // evaluating a sender-scoped rule against senderless queue text.
     // When teaching a specific SMS, preview THAT sender and SMS only.
     final inspected=seed!=null?
      <MapEntry<String,String>>[
       // A global rule must preview pending SMS from all senders, not
       // just the selected teaching message.
       if(allSenders)...[
        for(var i=0;i<widget.scannedMessages.length;i++)
         MapEntry(i<widget.scannedSenders.length?
          widget.scannedSenders[i]:'',widget.scannedMessages[i]),
       ],
       MapEntry(widget.seedSender,seed),
      ]:
      <MapEntry<String,String>>[
       for(var i=0;i<widget.scannedMessages.length;i++)
        MapEntry(i<widget.scannedSenders.length?
         widget.scannedSenders[i]:'',widget.scannedMessages[i]),
      ];
     final previewMatches=inspected.where((row)=>
      WaffraSmsLocalRules.matches(previewRule,row.value,
       sender:row.key)).toList(growable:false);
     final matches=previewMatches.length;
     // M985: previews show conflict and unsettled-money impact. Read-only.
     final conflicts=previewMatches.where((row)=>saved.any((old)=>
      old.id!=existing?.id&&old.resolvedKind!=kind&&
      WaffraSmsLocalRules.matches(old,row.value,sender:row.key))).length;
     final statusBlocked=previewMatches.where((row)=>
      WaffraBankSmsFactsParser.parse(row.value).pending&&
      kind!='excluded').length;
     final otpSensitive=previewMatches.where((row)=>
      WaffraBankSmsFactsParser.isVerificationChallenge(row.value)).length;
     // M988 sample-only before/after impact, never a write or approval.
     final impact=WaffraSmsRuleSimulator.compare(
      samples:inspected,existing:saved,preview:previewRule,
      replacingId:existing?.id,maxMessages:2000);
     return SafeArea(top:false,child:Padding(
      padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.viewInsetsOf(ctx).bottom+12),
      child:ConstrainedBox(constraints:BoxConstraints(
       maxHeight:MediaQuery.sizeOf(ctx).height*.81),
       child:ListView(shrinkWrap:true,children:[
        Text(existing!=null?(widget.english?'Edit classification':'تعديل القاعدة'):
         (widget.english?'Review suggested rule':'راجع القاعدة المقترحة'),
         style:Theme.of(ctx).textTheme.titleLarge),
        if(seed!=null)...[
         const SizedBox(height:9),
         Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(
           color:Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha:.38),
           borderRadius:BorderRadius.circular(14)),
          child:Row(children:[
           const Icon(Icons.auto_awesome_outlined,size:22),
           const SizedBox(width:9),
           Expanded(child:Text(widget.english?
            'Waffra filled this rule from the message. Review and confirm.':
            'وفرة جهّز القاعدة من الرسالة. راجع البيانات واحفظ.')),
          ])),
         const SizedBox(height:8),
         // M669: even the suggested-rule review must expose the original
         // message verbatim. Genuine verification/OTP text is redacted.
         Card(child:Padding(
          padding:const EdgeInsets.all(12),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Text(widget.english?'Original bank SMS':'نص الرسالة البنكية الأصلي',
            style:Theme.of(ctx).textTheme.titleSmall),
           const SizedBox(height:6),
           WaffraBankSmsFactsParser.isVerificationChallenge(seed)?
            Text(widget.english?'Verification content is hidden.':
             'نص التحقق مخفي لحمايتك.'):
            SelectableText(seed,
             key:const Key('m669-sms-rule-original-text'),
             textAlign:TextAlign.start),
          ]),
         )),
        ],
        const SizedBox(height:10),
        TextField(controller:name,textInputAction:TextInputAction.next,
         decoration:InputDecoration(
          labelText:widget.english?'Rule name':'اسم القاعدة',
          border:const OutlineInputBorder())),
        const SizedBox(height:12),
        Text(widget.english?'Rule type':'نوع القاعدة'),
        const SizedBox(height:6),
        Wrap(spacing:7,runSpacing:7,children:[
         for(final option in const <String>['income','expense','transfer','excluded'])
          ChoiceChip(
           label:Text(option=='income'?(widget.english?'Income':'دخل'):
            option=='expense'?(widget.english?'Expense':'مصروف'):
            option=='transfer'?(widget.english?'Transfer':'تحويل'):
            (widget.english?'Excluded':'مستبعدة')),
           selected:kind==option,
           onSelected:(_)=>refresh((){
            kind=option;income=option=='income';
            if(existing==null)all=option!='excluded';
            category=null;autoPost=false;accountId='';
            // A change of rule type invalidates every old keyword choice.
            if(seed!=null&&existing==null){
             selected.clear();
             selected.addAll(WaffraSmsLocalRules.suggestedRule(
              body:seed,sender:widget.seedSender,kind:option,
              category:widget.seedCategory)?.keywords??const <String>[]);
            }
           })),
        ]),
        const SizedBox(height:12),
        if(financial)...[
         WaffraCenteredDropdownFormField<String>(
          key:ValueKey('sms-rule-category-$kind'),
          initialValue:category,
          isExpanded:true,
          decoration:InputDecoration(labelText:widget.english?
           'Main / subcategory':'القسم الرئيسي والفرعي',
           border:const OutlineInputBorder()),
          items:categories.map((c)=>DropdownMenuItem(
           value:c,child:Text(c,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:(value)=>refresh(()=>category=value)),
         const SizedBox(height:12),
        ],
        Text(widget.english?'Apply this rule to':'نطاق تطبيق القاعدة',
         style:Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height:6),
        Wrap(spacing:8,runSpacing:6,children:[
         ChoiceChip(
          key:const Key('waffra-sms-scope-all-senders'),
          label:Text(widget.english?'All senders':'كل المرسلين'),
          selected:allSenders,
          onSelected:(_)=>refresh((){
           allSenders=true;autoPost=false;accountId='';validation=null;
          })),
         ChoiceChip(
          key:const Key('waffra-sms-scope-specific-sender'),
          label:Text(widget.english?'Specific sender':'مرسل محدد'),
          selected:!allSenders,
          onSelected:(_)=>refresh((){
           allSenders=false;validation=null;
          })),
        ]),
        const SizedBox(height:10),
        if(!allSenders)TextField(controller:sender,
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.account_balance_outlined),
          labelText:widget.english?'SMS sender':'مرسل الرسالة',
          border:const OutlineInputBorder())),
        if(allSenders)Padding(padding:const EdgeInsets.only(top:4),
         child:Text(widget.english?
          'Matches safe phrases from all senders. Financial messages and conflicts stay in review; global rules never auto-post.':
          'تُقارن المقاطع الآمنة مع كل المرسلين. الرسائل المالية والتعارضات تفضل للمراجعة، ومفيش تسجيل مالي تلقائي من القاعدة العامة.',
          style:Theme.of(ctx).textTheme.bodySmall)),
        const SizedBox(height:14),
        Row(children:[
         const Icon(Icons.tag_outlined,size:21),
         const SizedBox(width:7),
         Expanded(child:Text(widget.english?'Suggested keywords':'الكلمات المقترحة',
          style:Theme.of(ctx).textTheme.titleMedium)),
        ]),
        const SizedBox(height:7),
        if(selected.isEmpty)Text(widget.english?
         'No safe keywords found. Add one under Advanced edit.':
         'لم نجد كلمات كافية. أضف كلمة من تعديل متقدم.'),
        if(selected.isNotEmpty)Wrap(spacing:6,runSpacing:4,children:[
         for(final word in selected)InputChip(
          label:Text(word),onDeleted:()=>refresh(()=>selected.remove(word))),
        ]),
        const SizedBox(height:12),
        Text(widget.english?'When should this rule match?':'متى تنطبق القاعدة؟',
         style:Theme.of(ctx).textTheme.titleSmall),
        const SizedBox(height:5),
        Wrap(spacing:8,runSpacing:5,children:[
         ChoiceChip(
          key:const Key('waffra-sms-any-keyword'),
          label:Text(widget.english?'Any keyword':'أي كلمة تكفي'),
          selected:!all,onSelected:(_)=>refresh(()=>all=false)),
         ChoiceChip(
          key:const Key('waffra-sms-all-keywords'),
          label:Text(widget.english?'All keywords':'كل الكلمات'),
          selected:all,onSelected:(_)=>refresh(()=>all=true)),
        ]),
        const SizedBox(height:7),
        Text(widget.english?
         'Matches $matches checked messages (preview, not deletion).':
         'تنطبق على $matches رسالة تم فحصها (معاينة فقط).',
         style:Theme.of(ctx).textTheme.bodySmall),
        const SizedBox(height:5),
        Text(widget.english?
         'Estimated change: ${impact.changed} of ${impact.examined} queued messages checked (max 2000, nothing saved).':
         'التغيير المتوقع: ${impact.changed} من ${impact.examined} رسالة في طابور المراجعة (بحد ٢٠٠٠، دون حفظ).',
         style:Theme.of(ctx).textTheme.bodySmall),
        if(impact.blockedExclusions>0)Padding(
         padding:const EdgeInsets.only(top:6),
         child:Text(widget.english?
          '${impact.blockedExclusions} keyword exclusion matches are blocked by financial safety rules and stay in review.':
          '${impact.blockedExclusions} رسالة طابقت قاعدة الاستبعاد لكن شروط الأمان تمنع استبعادها وستبقى للمراجعة.',
          style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        const SizedBox(height:8),
        if(conflicts>0)Padding(
         padding:const EdgeInsets.only(top:5),
         child:Text(widget.english?
          '$conflicts messages conflict with another saved rule; they stay in review.':
          '$conflicts رسالة متعارضة مع قاعدة أخرى وستبقى للمراجعة.',
          style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        if(statusBlocked>0||otpSensitive>0)Padding(
         padding:const EdgeInsets.only(top:5),
         child:Text(widget.english?
          '$statusBlocked unsettled transactions and $otpSensitive verification messages need review.':
          '$statusBlocked عملية معلقة أو فاشلة، و$otpSensitive رسالة تحقق تحتاج تعامل آمن.',
          style:Theme.of(ctx).textTheme.bodySmall)),
        ExpansionTile(
         key:const Key('waffra-sms-advanced-rule-edit'),
         tilePadding:EdgeInsets.zero,
         title:Text(widget.english?'Advanced edit':'تعديل متقدم'),
         children:[
          Text(widget.english?
           'Choose keywords or add a safe phrase. Never enter OTP numbers.':
           'اختار كلمات إضافية أو اكتب عبارة آمنة. لا تكتب رمز التحقق نفسه.'),
          const SizedBox(height:8),
          TextField(controller:search,
           onChanged:(value)=>refresh(()=>searchQuery=value),
           decoration:InputDecoration(
            prefixIcon:const Icon(Icons.search),
            hintText:widget.english?'Search suggestions':'ابحث في الاقتراحات',
            border:const OutlineInputBorder())),
          const SizedBox(height:8),
          if(visible.isEmpty)Text(widget.english?
           'No suggestions; enter a safe word below.':
           'مفيش اقتراحات؛ أضف كلمة آمنة بنفسك.'),
          Wrap(spacing:7,runSpacing:6,children:[
           for(final word in visible)FilterChip(
            label:Text(word),selected:selected.contains(word),
            onSelected:(value)=>refresh((){
             if(value&&selected.length<12)selected.add(word);
             if(!value)selected.remove(word);
             validation=null;
            })),
          ]),
          const SizedBox(height:10),
          Row(children:[
           Expanded(child:TextField(controller:customKeyword,
            decoration:InputDecoration(
             labelText:widget.english?'Add keyword':'أضف كلمة جديدة',
             border:const OutlineInputBorder()))),
           IconButton(onPressed:()=>addKeyword(refresh),
            icon:const Icon(Icons.add_circle_outline),
            tooltip:widget.english?'Add':'إضافة'),
          ]),
          const SizedBox(height:10),
          if(financial)Text(widget.english?
           'Automatic financial posting requires separate verified consent.':
           'التسجيل المالي التلقائي يحتاج تحقق وموافقة مستقلة.'),
        if(financial)...[
         SwitchListTile.adaptive(
          key:const Key('waffra-sms-rule-auto-post'),
          contentPadding:EdgeInsets.zero,
          value:autoPost,
          title:Text(widget.english?
           'Automatically record future verified matches':
           'سجّل العمليات المطابقة والموثّقة القادمة تلقائيًا'),
          subtitle:Text(widget.english?
           'Only with a confirmed bank account, exact SMS sender and '
           'matching 4-digit account suffix. Otherwise review manually.':
           'فقط عند تطابق البنك وآخر ٤ أرقام مع حساب مالي مؤكد. '
           'أي اختلاف يرجع للمراجعة.'),
          onChanged:allSenders||widget.bankAccounts.isEmpty?null:
           (v)=>refresh(()=>autoPost=v)),
         if(autoPost)...[
          WaffraCenteredDropdownFormField<String>(
           key:ValueKey('waffra-sms-rule-account-$accountId'),
           initialValue:widget.bankAccounts.containsKey(accountId)?
            accountId:null,
           isExpanded:true,
           decoration:InputDecoration(
            labelText:widget.english?'Verified account':'الحساب المالي الموثّق',
            border:const OutlineInputBorder()),
           items:widget.bankAccounts.entries.map((pair)=>DropdownMenuItem(
            value:pair.key,child:Text(pair.value,overflow:TextOverflow.ellipsis))).toList(),
           onChanged:(value)=>refresh(()=>accountId=value??'')),
          const SizedBox(height:10),
          TextField(
           controller:suffix,keyboardType:TextInputType.number,
           maxLength:4,
           decoration:InputDecoration(
            labelText:widget.english?
             'Last four bank account digits':'آخر ٤ أرقام من حساب البنك',
            border:const OutlineInputBorder())),
         ],
        ],

         ]),
        const SizedBox(height:6),
        if(validation!=null)Padding(padding:const EdgeInsets.only(top:6),
         child:Text(validation!,style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        const SizedBox(height:14),
        FilledButton(
         key:const Key('waffra-save-custom-sms-rule'),
         onPressed:(){
          final rule=WaffraSmsLocalRule(
           id:existing?.id??'custom_${DateTime.now().microsecondsSinceEpoch}',
           name:name.text.trim(),keywords:selected.toList(),
           kind:kind,income:income,category:financial?(category??''):'',
           matchAll:kind=='excluded'&&existing?.templateFamily.isNotEmpty==true?
            true:all,
           sender:allSenders?'':sender.text.trim(),
           // Keep a reviewed structural exclusion structural when its scope
           // changes; broad literal conversion would hide unrelated SMS.
           templateFamily:kind=='excluded'?existing?.templateFamily??'':'',
           contextFragments:kind=='excluded'?
            existing?.contextFragments??const <String>[]:const <String>[],
           autoPost:autoPost&&financial&&!allSenders,
           accountId:autoPost&&!allSenders?accountId:'',
           accountSuffix:autoPost?suffix.text.trim():'',
          );
          if(name.text.trim().length<2){
           refresh(()=>validation=widget.english?
            'Give the rule a name of at least two characters.':
            'اكتب اسمًا للقاعدة من حرفين على الأقل.');
           return;
          }
          if(!allSenders&&sender.text.trim().isEmpty){
           refresh(()=>validation=widget.english?
            'Choose a sender for this rule, or switch to All senders.':
            'اكتب اسم المرسل أو اختار كل المرسلين.');
           return;
          }
          if(selected.isEmpty){
           refresh(()=>validation=widget.english?
            'Tap at least one suggested keyword above, or add your own.':
            'اضغط على كلمة من الاقتراحات لاختيارها أو أضف كلمة جديدة.');
           return;
          }
          if(financial&&(categories.isEmpty||category==null)){
           refresh(()=>validation=widget.english?
            'Select a valid category.':'اختار قسم رئيسي وفرعي صحيح.');
           return;
          }
          // An explicitly seeded rule must be semantically consistent with
          // the actual reviewed message, and match its confirmed sender.
          if(seed!=null){
           final facts=WaffraBankSmsFactsParser.parse(seed);
           final consistent=!facts.pending&&switch(kind){
            'income'=>facts.kind==WaffraBankOperationKind.income,
            'expense'=>facts.kind==WaffraBankOperationKind.expense,
            'transfer'=>facts.kind==WaffraBankOperationKind.transfer,
            'excluded'=>facts.kind==WaffraBankOperationKind.uncertain,
            _=>false,
           };
           if(!consistent||!WaffraSmsLocalRules.matches(
              rule,seed,sender:widget.seedSender)){
            refresh(()=>validation=widget.english?
             'This rule does not match the original sender, message or type.':
             'القاعدة لا تطابق المرسل أو الرسالة الأصلية أو نوع العملية.');
            return;
           }
          }
          try{WaffraSmsLocalRules.validate(rule);}
          on FormatException{
           refresh(()=>validation=widget.english?
            'Enter a name and choose 1–12 safe keywords.':
            'اكتب اسم القاعدة واختار من ١ إلى ١٢ كلمة آمنة.');
           return;
          }
          Navigator.pop(ctx,rule);
         },
         child:Text(widget.english?'Save rule':'حفظ القاعدة')),
       ])),
      ));
    }),
   );
   if(result==null||!mounted)return;
   final next=[
    for(final rule in saved)if(rule.id!=result.id)rule,
    result,
   ];
   final savedSuccessfully=await _persist(next);
   if(savedSuccessfully&&seed!=null&&mounted){
    Navigator.pop(context,true); // Explicit review-flow rule created.
   }
  }finally{
   name.dispose();customKeyword.dispose();search.dispose();sender.dispose();
   suffix.dispose();
  }
 }
 String _m1037SmsTimestamp(Object? ms){
  if(ms is! int||ms<=0)return widget.english?'Unknown':'غير معروف';
  return DateTime.fromMillisecondsSinceEpoch(ms).toLocal()
   .toString().split('.').first;
 }
 /// Load the original, owner-authorized message ONLY after deliberate tap.
 Future<void> _m1037ShowExcludedMessage(Map<String,Object?> message)async{
  final id=message['id'];
  if(id is! String||!mounted)return;
  final detail=await WaffraAutoSms.excludedMessageDetails(id);
  if(!mounted)return;
  final sender=(detail?['sender'] as String?)??
   (message['sender'] as String?)??'';
  final body=detail?['body'] as String?;
  final status=detail?['status'] as String?;
  final content=status=='available'&&body!=null&&body.trim().isNotEmpty?
   body:(status=='otp_protected'?
    (widget.english?'This verification code was not retained.':
     'رسالة تحقق محمية؛ رمز التحقق الأصلي غير محفوظ ولا يُعرض.'):
    (widget.english?'Original SMS text unavailable. It may have been deleted from Android SMS.':
     'تعذر استرجاع نص الرسالة. قد تكون الرسالة الأصلية اتحذفت من رسائل الهاتف.'));
  await showDialog<void>(context:context,builder:(dialog)=>AlertDialog(
   title:Text(widget.english?'Excluded SMS details':'تفاصيل الرسالة المستبعدة'),
   content:SingleChildScrollView(child:Column(
    mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text((widget.english?'Sender: ':'المرسل: ')+sender),
    const SizedBox(height:8),
    Text((widget.english?'Received: ':'وصلت في: ')+
     _m1037SmsTimestamp(detail?['receivedAt']??message['receivedAt'])),
    Text((widget.english?'Excluded: ':'استُبعدت في: ')+
     _m1037SmsTimestamp(detail?['excludedAt']??message['excludedAt'])),
    const SizedBox(height:14),
    Text(widget.english?'Original SMS text':'نص الرسالة الأصلي',
     style:Theme.of(dialog).textTheme.titleSmall),
    const SizedBox(height:8),
    SelectableText(content,textAlign:TextAlign.start),
   ])),
   actions:[TextButton(onPressed:()=>Navigator.pop(dialog),
    child:Text(widget.english?'Close':'إغلاق'))],
  ));
 }
 /// Curated built-in patterns are read-only and lazily rendered. Avoid
 /// constructing hundreds of ListTiles on each tap or panel scroll.
 Widget _defaultRuleBucket(String kind) {
  final values=WaffraSmsLocalRules.allDefaultRules.where(
   (rule)=>rule.resolvedKind==kind).toList(growable:false);
  final keywords=values.fold<int>(0,(sum,r)=>sum+r.keywords.length);
  final title=switch(kind){
   'income'=>widget.english?'Income':'دخل',
   'expense'=>widget.english?'Expenses':'مصروف',
   'transfer'=>widget.english?'Transfers':'تحويلات',
   _=>widget.english?'Excluded':'مستبعدة',
  };
  return Card(child:ExpansionTile(
   key:Key('waffra-sms-default-rule-bucket-$kind'),
   leading:Icon(switch(kind){
    'income'=>Icons.call_received_rounded,
    'expense'=>Icons.call_made_rounded,
    'transfer'=>Icons.sync_alt_rounded,
    _=>Icons.shield_outlined,
   }),
   title:Text(title),
   subtitle:Text(widget.english?
    '${values.length} default rules • $keywords keywords':
    '${values.length} قواعد افتراضية • $keywords كلمة مفتاحية'),
   children:[SizedBox(height:values.length<=5?values.length*78.0:370,
    child:ListView.builder(
     primary:false,itemCount:values.length,itemExtent:78,
     itemBuilder:(context,i){
      final rule=values[i];
      return ListTile(dense:true,
       leading:const Icon(Icons.lock_outline,size:17),
       title:Text(rule.name,maxLines:1,overflow:TextOverflow.ellipsis),
       subtitle:Text(
        '${rule.category.isEmpty?'':rule.category+' • '}${rule.keywords.join('، ')}',
        maxLines:2,overflow:TextOverflow.ellipsis),
      );
     })),
   ],
  ));
 }

 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(widget.english?
   'Bank SMS classification rules':'قواعد تحليل الرسائل البنكية')),
  floatingActionButton:loading||error!=null?null:FloatingActionButton.extended(
   key:const Key('waffra-add-custom-sms-rule'),
   onPressed:busy||saved.length>=WaffraSmsLocalRules.maxStoredRules?
    null:()=>_edit(),
   icon:const Icon(Icons.add),
   label:Text(widget.english?'Add rule':'إضافة قاعدة')),
  body:loading?const Center(child:CircularProgressIndicator()):
   error!=null?Center(child:Padding(padding:const EdgeInsets.all(20),
    child:Text(error!,textAlign:TextAlign.center))):
   ListView(padding:const EdgeInsets.fromLTRB(16,12,16,90),children:[
    Text(widget.english?
     'Rules run locally on your device and suggest categories; financial changes require your verified approval.':
     'القواعد تحلل الرسائل محليًا على جهازك وتقترح النوع والقسم، والعملية المالية تتطلب تأكيدك الموثق.',
     style:Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height:12),
    Text(widget.english?
     'Saved rules: ${saved.length} / ${WaffraSmsLocalRules.maxStoredRules}':
     'القواعد المحفوظة: ${saved.length} من ${WaffraSmsLocalRules.maxStoredRules}',
     key:const Key('m1032-rule-capacity-count')),
    Card(child:ListTile(
     key:const Key('m1031-confirmed-learning-counts'),
     leading:const Icon(Icons.school_outlined),
     title:Text(widget.english?
      'Confirmed local financial learning':
      'التعلم المحلي من العمليات المؤكدة'),
     subtitle:Text(confirmedLearningCounts==null?
      (widget.english?
       'Encrypted learning counts unavailable — this is not zero.':
       'تعذر قراءة عدادات التعلم المشفرة؛ ده مش معناه إن العدد صفر.'):
      (widget.english?
       'Manual income ${confirmedLearningCounts!['manual|income']} • manual expense ${confirmedLearningCounts!['manual|expense']}\n'
       'Bank SMS income ${confirmedLearningCounts!['sms|income']} • bank SMS expense ${confirmedLearningCounts!['sms|expense']}\n'
       'Reusable safe patterns: ${saved.where((r)=>r.financial).length}':
       'دخل يدوي ${confirmedLearningCounts!['manual|income']} • مصروف يدوي ${confirmedLearningCounts!['manual|expense']}\n'
       'دخل بنكي ${confirmedLearningCounts!['sms|income']} • مصروف بنكي ${confirmedLearningCounts!['sms|expense']}\n'
       'قواعد كلمات آمنة قابلة لإعادة الاستخدام: ${saved.where((r)=>r.financial).length}')),
     trailing:IconButton(
      tooltip:widget.english?'Refresh learning counts':'تحديث عداد التعلم',
      onPressed:busy?null:_load,icon:const Icon(Icons.refresh_outlined)),
    )),
    const SizedBox(height:12),
    Card(child:ListTile(
     key:const Key('m1002-native-exclusion-counts'),
     leading:const Icon(Icons.shield_outlined),
     title:Text(widget.english?'Previously excluded SMS':'الرسائل المستبعدة بالفعل'),
     subtitle:Text(excludedSmsCount==null||blockedSenderCount==null?
      (widget.english?'Native exclusion counts unavailable. This does not mean zero.':
       'تعذر قراءة سجل الاستبعاد على الجهاز. ده مش معناه إن العدد صفر.'):
      (widget.english?
       '${excludedSmsCount!} individually excluded SMS • ${blockedSenderCount!} blocked senders':
       '${excludedSmsCount!} رسالة مستبعدة • ${blockedSenderCount!} مرسل مستبعد')),
     trailing:IconButton(
      tooltip:widget.english?'Refresh exclusion counts':'تحديث عداد الاستبعاد',
      onPressed:busy?null:_load,icon:const Icon(Icons.refresh_outlined)),
    )),
    Text(widget.english?
     'Saved patterns below are reusable classification rules, not a count of SMS you excluded. Financial messages do not automatically become future-blocking rules.':
     'الأنماط المحفوظة تحت هي قواعد قابلة لإعادة الاستخدام، مش عدد الرسائل اللي استبعدتها. الرسائل المالية لا تتحول تلقائيًا لقواعد تحجب رسائل مستقبلية.'),
    const SizedBox(height:16),
    if(canUndo)Align(alignment:AlignmentDirectional.centerStart,
     child:OutlinedButton.icon(
      key:const Key('m988-sms-undo-last-rule-revision'),
      onPressed:busy?null:_undoLastRuleChange,
      icon:const Icon(Icons.undo_rounded),
      label:Text(widget.english?'Undo last rule change':'التراجع عن آخر تعديل للقواعد'))),
    Text(widget.english?'Learned classifications':'التصنيفات التي تعلّمها وفرة',
     style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:8),
    for(final kind in const <String>['income','expense','transfer','excluded'])
     Card(child:ExpansionTile(
      key:Key('waffra-sms-rule-bucket-$kind'),
      leading:Icon(switch(kind){
       'income'=>Icons.call_received_rounded,
       'expense'=>Icons.call_made_rounded,
       'transfer'=>Icons.sync_alt_rounded,
       _=>Icons.shield_outlined,
      }),
      title:Text(switch(kind){
       'income'=>widget.english?'Income':'دخل',
       'expense'=>widget.english?'Expenses':'مصروف',
       'transfer'=>widget.english?'Transfers':'تحويل',
       _=>widget.english?'Excluded messages':'الرسائل المستبعدة',
      }),
      subtitle:Text(kind=='excluded'&&
        excludedSmsCount!=null&&blockedSenderCount!=null?
       (widget.english?
        '${saved.where((r)=>r.resolvedKind==kind).length} reusable patterns • ${excludedSmsCount!} excluded SMS • ${blockedSenderCount!} blocked senders':
        '${saved.where((r)=>r.resolvedKind==kind).length} قواعد متعلّمة • ${excludedSmsCount!} رسالة مستبعدة • ${blockedSenderCount!} مرسل مستبعد'):
       (widget.english?
        '${saved.where((r)=>r.resolvedKind==kind).length} saved patterns':
        '${saved.where((r)=>r.resolvedKind==kind).length} أنماط محفوظة')),
      children:[
       if(kind=='excluded'&&nativeExcluded!=null&&
          nativeBlockedSenders!=null)...[
        ListTile(
         leading:const Icon(Icons.lock_outline),
         title:Text(widget.english?'Stored Android exclusions':
          'الاستبعادات المحفوظة فعليًا في أندرويد'),
         subtitle:Text(widget.english?
          'These are saved message IDs or whole blocked senders, not reusable keyword rules. You can restore them from Settings > Excluded.':
          'دي رسائل مستبعدة أو مرسلون محجوبون فعليًا، مش قواعد كلمات. تقدر ترجعهم من إعدادات المستبعدين.'),
        ),
        if(nativeBlockedSenders!.isNotEmpty)
         Padding(padding:const EdgeInsets.fromLTRB(12,8,12,6),
          child:Text(widget.english?'Blocked senders':'المرسلون المستبعدون',
           style:Theme.of(context).textTheme.titleSmall)),
        for(final blocked in nativeBlockedSenders!.take(30))
         ListTile(dense:true,leading:const Icon(Icons.block_outlined),
          title:Text(blocked,maxLines:1,overflow:TextOverflow.ellipsis),
          subtitle:Text(widget.english?'Blocked sender':'مرسل مستبعد')),
        Padding(padding:const EdgeInsets.fromLTRB(12,12,12,6),
         child:Text(widget.english?'Individually excluded messages':
          'الرسائل المستبعدة فرديًا',
          style:Theme.of(context).textTheme.titleSmall)),
        for(final message in nativeExcluded!.take(40))
         ListTile(dense:true,leading:const Icon(Icons.mark_email_read_outlined),
          title:Text((message['sender'] as String?)?.trim().isNotEmpty==true?
           message['sender'] as String:
           (widget.english?'Unknown sender':'مرسل غير معروف'),
           maxLines:1,overflow:TextOverflow.ellipsis),
          subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
           if(message['body'] is String&&
              (message['body'] as String).trim().isNotEmpty)
            Text(message['body'] as String,maxLines:3,
             overflow:TextOverflow.ellipsis),
           if(message['body'] is! String)
            Text(widget.english?'Tap to recover older original SMS':
             'اضغط لاسترجاع نص الرسالة القديمة من الهاتف'),
           Text((widget.english?'Excluded SMS • ':'رسالة مستبعدة فرديًا • ')+
            _m1037SmsTimestamp(message['receivedAt'])),
          ]),
          onTap:()=>_m1037ShowExcludedMessage(message)),
        if(nativeExcluded!.length>40||nativeBlockedSenders!.length>30)
         Padding(padding:const EdgeInsets.all(12),
          child:Text(widget.english?
           'Only the first 40 messages and 30 senders are shown here. Open Settings > Excluded for full management.':
           'يظهر أول 40 رسالة و30 مرسل هنا. افتح الإعدادات > المستبعدون للإدارة الكاملة.')),
       ],
       Padding(padding:const EdgeInsets.fromLTRB(12,10,12,5),
        child:Text(widget.english?'Learned reusable rules':
         'القواعد المتعلّمة',style:Theme.of(context).textTheme.titleSmall)),
       if(!saved.any((r)=>r.resolvedKind==kind))
        Padding(padding:const EdgeInsets.all(14),
         child:Text(widget.english?
          'Waffra will learn from your confirmed SMS.':
          'وفرة هيتعلّم من الرسائل اللي بتراجعها وتأكدها.')),
       for(final rule in saved.where((r)=>r.resolvedKind==kind))
        ListTile(
         title:Text(rule.name),
         subtitle:Text(
          '${rule.category.isNotEmpty?rule.category+' • ':''}'
          '${rule.sender.isNotEmpty?rule.sender+' • ':''}'
          '${rule.keywords.join('، ')}',
          maxLines:3,overflow:TextOverflow.ellipsis),
         onTap:()=>_edit(existing:rule),
         trailing:IconButton(
          tooltip:widget.english?'Delete this pattern':'حذف هذا النمط',
          icon:const Icon(Icons.delete_outline),
          onPressed:busy?null:()=>_remove(rule)),
        ),
      ],
     )),
    const SizedBox(height:18),
    Text(widget.english?'Ready-made rules':'القواعد الجاهزة',
     style:Theme.of(context).textTheme.titleMedium),
    const SizedBox(height:8),
    for(final kind in const <String>['income','expense','transfer','excluded'])
     _defaultRuleBucket(kind),
   ]),
 );
}

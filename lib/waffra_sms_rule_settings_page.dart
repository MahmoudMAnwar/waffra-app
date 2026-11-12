import 'package:flutter/material.dart';

import 'waffra_sms_local_rules.dart';
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
 bool loading=true,busy=false;
 String? error;
 @override void initState(){
  super.initState();
  _load();
 }
 Future<void> _load()async{
  try{
   final rules=await store.read(widget.ownerKey);
   if(!mounted)return;
   setState((){saved=rules;loading=false;error=null;});
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
   await store.write(widget.ownerKey,next);
   if(mounted){
    setState(()=>saved=next);
    // M661: a seedless user-created rule has no route result to signal Home.
    // Persist first, then notify the existing debounced pending-SMS refresh.
    widget.onRulesChanged?.call();
   }
   return true;
  }catch(_){
   if(mounted)widget.onNotice(widget.english?
    'Could not save rules securely. Nothing changed.':
    'تعذر حفظ القواعد بأمان. لم يتغير شيء.');
   return false;
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
      kind:kind,matchAll:all,sender:sender.text.trim());
     // A seeded bank sender is known. Never fake a 0-match preview by
     // evaluating a sender-scoped rule against senderless queue text.
     // When teaching a specific SMS, preview THAT sender and SMS only.
     final previewMessages=seed!=null?<String>{seed}:<String>{};
     // M661: manual preview used sender='' for every current SMS, so a
     // properly scoped rule incorrectly showed zero matches. Pair each body
     // with its verified live native sender; do not store extra SMS data.
     final matches=seed!=null?
      previewMessages.where((sms)=>WaffraSmsLocalRules.matches(
       previewRule,sms,sender:widget.seedSender)).length:
      widget.scannedMessages.asMap().entries.where((row)=>
       WaffraSmsLocalRules.matches(previewRule,row.value,
        sender:row.key<widget.scannedSenders.length?
         widget.scannedSenders[row.key]:'')).length;
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
        TextField(controller:sender,
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.account_balance_outlined),
          labelText:widget.english?'SMS sender':'مرسل الرسالة',
          border:const OutlineInputBorder())),
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
        const SizedBox(height:8),
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
          onChanged:widget.bankAccounts.isEmpty?null:
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
           matchAll:all,sender:sender.text.trim(),
           autoPost:autoPost&&financial,accountId:autoPost?accountId:'',
           accountSuffix:autoPost?suffix.text.trim():'',
          );
          if(name.text.trim().length<2){
           refresh(()=>validation=widget.english?
            'Give the rule a name of at least two characters.':
            'اكتب اسمًا للقاعدة من حرفين على الأقل.');
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
   onPressed:busy?null:()=>_edit(),
   icon:const Icon(Icons.add),
   label:Text(widget.english?'Add rule':'إضافة قاعدة')),
  body:loading?const Center(child:CircularProgressIndicator()):
   error!=null?Center(child:Padding(padding:const EdgeInsets.all(20),
    child:Text(error!,textAlign:TextAlign.center))):
   ListView(padding:const EdgeInsets.fromLTRB(16,12,16,90),children:[
    Text(widget.english?
     'Rules run offline before AI. A rule only suggests the type and category; transactions need your approval.':
     'القواعد بتحلل محليًا قبل الذكاء الاصطناعي، وبتقترح نوع العملية والقسم فقط. الحفظ بعد موافقتك.',
     style:Theme.of(context).textTheme.bodyMedium),
    const SizedBox(height:16),
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
      subtitle:Text(widget.english?
       '${saved.where((r)=>r.resolvedKind==kind).length} saved patterns':
       '${saved.where((r)=>r.resolvedKind==kind).length} أنماط محفوظة'),
      children:[
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

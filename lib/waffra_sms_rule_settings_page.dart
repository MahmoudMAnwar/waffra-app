import 'package:flutter/material.dart';

import 'waffra_sms_local_rules.dart';

/// Rules configure offline review suggestions only. This screen has no ledger,
/// bank-account, SMS-permission, or cloud-provider write capability.
class WaffraSmsRuleSettingsPage extends StatefulWidget {
 const WaffraSmsRuleSettingsPage({
  super.key,required this.english,required this.ownerKey,
  required this.scannedMessages,required this.incomeCategories,
  required this.expenseCategories,this.seedMessage,
 });
 final bool english;
 final String ownerKey;
 final List<String> scannedMessages,incomeCategories,expenseCategories;
 final String? seedMessage;
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
     if(mounted)_edit(seed:widget.seedMessage);
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
 Future<void> _persist(List<WaffraSmsLocalRule> next)async{
  if(busy||error!=null)return;
  setState(()=>busy=true);
  try{
   await store.write(widget.ownerKey,next);
   if(mounted)setState(()=>saved=next);
  }catch(_){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text(widget.english?'Could not save rules securely. Nothing changed.':
     'تعذر حفظ القواعد بأمان. لم يتغير شيء.')));
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
 Future<void> _edit({WaffraSmsLocalRule? existing,String? seed})async{
  if(busy||error!=null)return;
  final name=TextEditingController(text:existing?.name??'');
  final customKeyword=TextEditingController();
  final search=TextEditingController();
  final sender=TextEditingController(text:existing?.sender??'');
  var income=existing?.income??false;
  var all=existing?.matchAll??true;
  var category=existing?.category;
  var searchQuery='';
  String? validation;
  final selected=<String>{...?existing?.keywords};
  final candidates=WaffraSmsLocalRules.suggestions([
   if(seed!=null)seed,...widget.scannedMessages,
  ]);
  final seedChoices=seed==null?const <String>[]:
   WaffraSmsLocalRules.suggestions([seed]);
  if(existing==null&&seedChoices.isNotEmpty)selected.add(seedChoices.first);
  Future<void> addKeyword(StateSetter update)async{
   final keyword=customKeyword.text.trim();
   if(!WaffraSmsLocalRules.safeKeyword(keyword)){
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
     final categories=income?widget.incomeCategories:widget.expenseCategories;
     if(category!=null&&!categories.contains(category))category=null;
     final visible=candidates.where((item)=>WaffraSmsLocalRules.normalized(item)
      .contains(WaffraSmsLocalRules.normalized(searchQuery))).take(60).toList();
     final previewRule=WaffraSmsLocalRule(
      id:'preview',name:name.text.trim().isEmpty?'Preview':name.text,
      keywords:selected.toList(),income:income,category:category??'Preview',
      matchAll:all,sender:sender.text.trim());
     final matches=widget.scannedMessages.where((sms)=>
      WaffraSmsLocalRules.matches(previewRule,sms)).length;
     return SafeArea(top:false,child:Padding(
      padding:EdgeInsets.fromLTRB(18,8,18,MediaQuery.viewInsetsOf(ctx).bottom+12),
      child:ConstrainedBox(constraints:BoxConstraints(
       maxHeight:MediaQuery.sizeOf(ctx).height*.81),
       child:ListView(shrinkWrap:true,children:[
        Text(widget.english?'Add classification rule':'إضافة قاعدة تحليل',
         style:Theme.of(ctx).textTheme.titleLarge),
        const SizedBox(height:10),
        TextField(controller:name,textInputAction:TextInputAction.next,
         decoration:InputDecoration(
          labelText:widget.english?'Rule name':'اسم القاعدة',
          border:const OutlineInputBorder())),
        const SizedBox(height:12),
        Text(widget.english?'Operation type':'نوع العملية'),
        const SizedBox(height:6),
        SegmentedButton<bool>(
         segments:[
          ButtonSegment(value:true,label:Text(widget.english?'Income':'دخل')),
          ButtonSegment(value:false,label:Text(widget.english?'Expense':'مصروف')),
         ],
         selected:{income},onSelectionChanged:(set)=>refresh((){income=set.first;category=null;})),
        const SizedBox(height:12),
        DropdownButtonFormField<String>(
         key:ValueKey('sms-rule-category-$income'),
         initialValue:category,
         isExpanded:true,
         decoration:InputDecoration(labelText:widget.english?
          'Main / subcategory':'القسم الرئيسي والفرعي',
          border:const OutlineInputBorder()),
         items:categories.map((c)=>DropdownMenuItem(
          value:c,child:Text(c,overflow:TextOverflow.ellipsis))).toList(),
         onChanged:(value)=>refresh(()=>category=value)),
        const SizedBox(height:12),
        TextField(controller:sender,
         decoration:InputDecoration(labelText:widget.english?
          'Bank sender (optional)':'المرسل (اختياري)',
          border:const OutlineInputBorder())),
        const SizedBox(height:12),
        Text(widget.english?'Choose keywords from scanned messages':
         'اختار الكلمات المفتاحية من الرسائل الممسوحة'),
        const SizedBox(height:6),
        TextField(controller:search,
         onChanged:(value)=>refresh(()=>searchQuery=value),
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search),
          hintText:widget.english?'Search suggestions':'ابحث في الاقتراحات',
          border:const OutlineInputBorder())),
        const SizedBox(height:7),
        if(visible.isEmpty)Text(widget.english?
         'No suggestions yet. Add a word below.':
         'لسه مفيش اقتراحات؛ تقدر تضيف كلمة بنفسك.'),
        Wrap(spacing:6,runSpacing:4,children:[
         for(final word in visible)FilterChip(
          label:Text(word),selected:selected.contains(word),
          onSelected:(value)=>refresh((){
           if(value&&selected.length<12)selected.add(word);
           if(!value)selected.remove(word);
          })),
        ]),
        const SizedBox(height:9),
        Row(children:[
         Expanded(child:TextField(controller:customKeyword,
          decoration:InputDecoration(
           labelText:widget.english?'Or add a keyword':'أو أضف كلمة جديدة',
           border:const OutlineInputBorder()))),
         IconButton(onPressed:()=>addKeyword(refresh),
          icon:const Icon(Icons.add_circle_outline),tooltip:widget.english?'Add':'إضافة'),
        ]),
        if(selected.isNotEmpty)Wrap(spacing:5,runSpacing:3,children:[
         for(final word in selected)InputChip(label:Text(word),onDeleted:()=>
          refresh(()=>selected.remove(word))),
        ]),
        const SizedBox(height:10),
        SwitchListTile.adaptive(
         contentPadding:EdgeInsets.zero,value:all,
         title:Text(widget.english?'All selected keywords must match':
          'لازم كل الكلمات المختارة تظهر'),
         subtitle:Text(widget.english?
          'Turn off to match any one keyword.':
          'اقفل الاختيار لو يكفي ظهور أي كلمة.'),
         onChanged:(value)=>refresh(()=>all=value)),
        Text(widget.english?
         'Matches $matches scanned messages (preview only).':
         'القاعدة تطابق $matches رسالة ممسوحة (معاينة فقط).'),
        if(validation!=null)Padding(padding:const EdgeInsets.only(top:6),
         child:Text(validation!,style:TextStyle(color:Theme.of(ctx).colorScheme.error))),
        const SizedBox(height:14),
        FilledButton(
         key:const Key('waffra-save-custom-sms-rule'),
         onPressed:(){
          final rule=WaffraSmsLocalRule(
           id:existing?.id??'custom_${DateTime.now().microsecondsSinceEpoch}',
           name:name.text.trim(),keywords:selected.toList(),
           income:income,category:category??'',
           matchAll:all,sender:sender.text.trim(),
          );
          if(categories.isEmpty||category==null){
           refresh(()=>validation=widget.english?
            'Select a valid category.':'اختار قسم رئيسي وفرعي صحيح.');
           return;
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
      )));
    }),
   );
   if(result==null||!mounted)return;
   final next=[
    for(final rule in saved)if(rule.id!=result.id)rule,
    result,
   ];
   await _persist(next);
  }finally{
   name.dispose();customKeyword.dispose();search.dispose();sender.dispose();
  }
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
    Text(widget.english?'My rules':'قواعدي',
     style:Theme.of(context).textTheme.titleMedium),
    if(saved.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:12),
     child:Text(widget.english?
      'No custom rules yet. Use Add rule to choose keywords from scanned messages.':
      'لسه ما أضفتش قواعد. اضغط إضافة قاعدة واختار كلمات من الرسائل الممسوحة.')),
    for(final rule in saved)Card(child:ListTile(
     title:Text(rule.name),
     subtitle:Text('${rule.income?(widget.english?'Income':'دخل'):(widget.english?'Expense':'مصروف')} • ${rule.category}\n${rule.keywords.join('، ')}'),
     isThreeLine:true,
     onTap:()=>_edit(existing:rule),
     trailing:IconButton(
      tooltip:widget.english?'Delete rule':'حذف القاعدة',
      icon:const Icon(Icons.delete_outline),
      onPressed:busy?null:()=>_remove(rule)))),
    const SizedBox(height:18),
    Text(widget.english?'Built-in rules':'قواعد جاهزة',
     style:Theme.of(context).textTheme.titleMedium),
    Text(widget.english?
     'Included with Waffra and available from the first SMS.':
     'موجودة في وفرة من أول رسالة بدون أي إعداد.'),
    for(final rule in WaffraSmsLocalRules.builtIn)ListTile(
     dense:true,leading:Icon(rule.income?Icons.south_west:Icons.north_east),
     title:Text(rule.name),
     subtitle:Text('${rule.income?(widget.english?'Income':'دخل'):(widget.english?'Expense':'مصروف')} • ${rule.keywords.join('، ')}',
      maxLines:2,overflow:TextOverflow.ellipsis)),
   ]),
 );
}

import 'package:flutter/material.dart';

import 'storage/waffra_accounts_repository.dart';

/// User-facing transaction modes, independent from old income/expense bool.
/// The transfer variant must never be encoded as a MoneyEntry expense.
enum WaffraAccountOperation { income, expense, transfer }

int? waffraSarAmountMinor(String raw,{bool allowZero=false}) {
 const arabic='٠١٢٣٤٥٦٧٨٩',persian='۰۱۲۳۴۵۶۷۸۹';
 final digits=raw.trim().runes.map((r){
  final char=String.fromCharCode(r);
  final a=arabic.indexOf(char),p=persian.indexOf(char);
  return a>=0?a.toString():p>=0?p.toString():char;
 }).join();
 final input=digits.replaceAll('٫','.');
 if(!RegExp(r'^[0-9]{1,12}([.][0-9]{1,2})?$').hasMatch(input))return null;
 final parts=input.split('.');
 final major=int.tryParse(parts[0]);
 final cents=parts.length==2?int.tryParse(parts[1].padRight(2,'0')):0;
 if(major==null||cents==null)return null;
 final minor=major*100+cents;
 return minor>0||(allowZero&&minor==0)?minor:null;
}

class WaffraAccountTransactionDraft {
 const WaffraAccountTransactionDraft({
  required this.requestId,required this.operation,
  required this.accountId,required this.amountMinor,required this.memo,
  required this.title,required this.category,this.budgetId,
 });
 final String requestId,accountId,memo,title,category;
 final String? budgetId;
 final WaffraAccountOperation operation;
 final int amountMinor;
}

class WaffraInternalTransferDraft {
 const WaffraInternalTransferDraft({
  required this.requestId,required this.fromId,required this.toId,
  required this.occurredIso,required this.amountMinor,required this.memo,
 });
 final String requestId,fromId,toId,memo,occurredIso;
 final int amountMinor;
}

/// Form prepared for the verified finance-writer integration. Callbacks are
/// deliberately injected: no fallback to legacy preferences, no silent
/// SQLCipher activation, and no copy of an existing financial ledger.
class WaffraAccountTransactionForm extends StatefulWidget {
 const WaffraAccountTransactionForm({
  super.key,required this.accounts,this.english=false,
  this.onConfirmEntry,this.onConfirmTransfer,
  this.incomeCategories=const [],this.expenseCategories=const [],
  this.availableBudgets=const {},this.requireKnownCategory=false,
 });
 final List<WaffraAccountBalance> accounts;
 final List<String> incomeCategories,expenseCategories;
 final Map<String,String> availableBudgets;
 final bool requireKnownCategory;
 final bool english;
 final Future<void> Function(WaffraAccountTransactionDraft)? onConfirmEntry;
 final Future<void> Function(WaffraInternalTransferDraft)? onConfirmTransfer;
 @override
 State<WaffraAccountTransactionForm> createState()=>_WaffraAccountTransactionFormState();
}

class _WaffraAccountTransactionFormState extends State<WaffraAccountTransactionForm> {
 final amount=TextEditingController(),memo=TextEditingController();
 final title=TextEditingController(),category=TextEditingController();
 late final DateTime requestTime=DateTime.now();
 late final String requestId='m440-'+requestTime.microsecondsSinceEpoch.toString();
 WaffraAccountOperation mode=WaffraAccountOperation.income;
 String? source,destination,error,selectedBudgetId;
 List<String> get choices=>mode==WaffraAccountOperation.income?
  widget.incomeCategories:widget.expenseCategories;
 bool saving=false,saved=false;
 List<WaffraAccountBalance> get active=>
  widget.accounts.where((a)=>!a.archived).toList(growable:false);
 String tr(String ar,String en)=>widget.english?en:ar;

 @override void dispose(){
  amount.dispose();memo.dispose();title.dispose();category.dispose();
  super.dispose();
 }
 Future<void> submit()async{
  if(saving||saved)return;
  final value=waffraSarAmountMinor(amount.text);
  if(value==null){
   setState(()=>error=tr('أدخل مبلغًا صحيحًا بالريال','Enter a valid SAR amount'));
   return;
  }
  if(source==null||!active.any((a)=>a.id==source)){
   setState(()=>error=tr('اختر حسابًا أولًا','Choose an account first'));
   return;
  }
  if(mode==WaffraAccountOperation.transfer &&
    (destination==null||destination==source||
     !active.any((a)=>a.id==destination))){
   setState(()=>error=tr('اختر حساب وجهة مختلفًا','Select a different destination account'));
   return;
  }
  if(mode!=WaffraAccountOperation.transfer &&
    (title.text.trim().isEmpty || category.text.trim().isEmpty ||
     (widget.requireKnownCategory && !choices.contains(category.text.trim())))) {
   setState(()=>error=tr('أدخل عنوان العملية والقسم',
    'Enter a transaction title and category'));
   return;
  }
  if(mode==WaffraAccountOperation.expense && selectedBudgetId==null &&
     widget.availableBudgets.isNotEmpty){
   final approved=await showDialog<bool>(context:context,builder:(ctx)=>
    AlertDialog(title:Text(tr('حفظ بدون ميزانية؟','Save without budget?')),
     content:Text(tr('المصروف مش هيتربط بميزانية. تقدر تربطه لاحقًا.',
      'This expense will remain unlinked to a budget. You may link it later.')),
     actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),
       child:Text(tr('إلغاء','Cancel'))),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),
       child:Text(tr('حفظ بدون ميزانية','Save without budget')))]));
   if(approved!=true || !mounted)return;
  }
  if(!mounted)return;
  setState((){saving=true;error=null;});
  try{
   if(mode==WaffraAccountOperation.transfer){
    final commit=widget.onConfirmTransfer;
    if(commit==null)throw StateError('Verified transfer source unavailable.');
    await commit(WaffraInternalTransferDraft(requestId:requestId,
     fromId:source!,toId:destination!,amountMinor:value,
     occurredIso:requestTime.toIso8601String(),memo:memo.text.trim()));
   }else{
    final commit=widget.onConfirmEntry;
    if(commit==null)throw StateError('Verified income/expense source unavailable.');
    await commit(WaffraAccountTransactionDraft(requestId:requestId,
     operation:mode,accountId:source!,amountMinor:value,memo:memo.text.trim(),
     title:title.text.trim(),category:category.text.trim(),
     budgetId:mode==WaffraAccountOperation.expense?selectedBudgetId:null));
   }
   if(mounted)setState(()=>saved=true);
  }catch(_){
   if(mounted)setState(()=>error=tr(
    'تعذر تأكيد الحفظ في قاعدة البيانات. لم نعتبر العملية ناجحة.',
    'The finance database did not confirm the save. No success was recorded.'));
  }finally{
   if(mounted)setState(()=>saving=false);
  }
 }
 @override Widget build(BuildContext context){
  final accounts=active;
  Widget accountField(String? value,String label,ValueChanged<String?> onChanged,
   {String? exclude}){
   return DropdownButtonFormField<String>(
    isExpanded:true,
    initialValue:accounts.any((a)=>a.id==value)?value:null,
    decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
    items:accounts.where((a)=>a.id!=exclude).map((a)=>DropdownMenuItem(
     value:a.id,child:Text(a.name,overflow:TextOverflow.ellipsis))).toList(),
    onChanged:saving||saved?null:onChanged,
   );
  }
  return SafeArea(child:SingleChildScrollView(
   padding:const EdgeInsets.all(16),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(tr('معاملة جديدة','New transaction'),
     style:Theme.of(context).textTheme.titleLarge),
    const SizedBox(height:12),
    SegmentedButton<WaffraAccountOperation>(
     showSelectedIcon:false,
     segments:[
      ButtonSegment(value:WaffraAccountOperation.income,
       label:Text(tr('دخل','Income'))),
      ButtonSegment(value:WaffraAccountOperation.expense,
       label:Text(tr('مصروف','Expense'))),
      ButtonSegment(value:WaffraAccountOperation.transfer,
       label:Text(tr('تحويل','Transfer'))),
     ],
     selected:{mode},onSelectionChanged:saving||saved?null:(choice){
      setState((){mode=choice.first;error=null;selectedBudgetId=null;
       category.clear();});
     }),
    const SizedBox(height:16),
    TextField(key:const Key('m440-amount'),controller:amount,
     keyboardType:const TextInputType.numberWithOptions(decimal:true),
     decoration:InputDecoration(labelText:tr('المبلغ (ر.س)','Amount (SAR)'),
      border:const OutlineInputBorder())),
    const SizedBox(height:12),
    accountField(source,mode==WaffraAccountOperation.transfer?
     tr('من حساب','From account'):tr('الحساب','Account'),(v){
      setState((){source=v;if(destination==v)destination=null;error=null;});
     }),
    if(mode==WaffraAccountOperation.transfer)...[
     const SizedBox(height:12),
     accountField(destination,tr('إلى حساب','To account'),(v){
      setState((){destination=v;error=null;});
     },exclude:source),
     const SizedBox(height:10),
     Text(tr('التحويل بين حساباتك لا يُحسب دخلًا أو مصروفًا.',
      'Moving money between your own accounts is not income or spending.')),
    ],
    if(mode!=WaffraAccountOperation.transfer)...[
     const SizedBox(height:12),
     TextField(key:const Key('m440-title'),controller:title,maxLength:120,
      decoration:InputDecoration(labelText:tr('عنوان العملية','Transaction title'),
       border:const OutlineInputBorder())),
     const SizedBox(height:12),
     if(widget.requireKnownCategory)
      DropdownButtonFormField<String>(
       key:const Key('m440-category-picker'),isExpanded:true,
       initialValue:choices.contains(category.text)?category.text:null,
       decoration:InputDecoration(labelText:tr('القسم','Category'),
        border:const OutlineInputBorder()),
       items:choices.toSet().map((name)=>DropdownMenuItem(
        value:name,child:Text(name,overflow:TextOverflow.ellipsis))).toList(),
       onChanged:saving||saved?null:(value)=>setState(
        ()=>category.text=value??'')),
     if(!widget.requireKnownCategory)
      TextField(key:const Key('m440-category'),controller:category,maxLength:100,
       decoration:InputDecoration(labelText:tr('القسم','Category'),
        border:const OutlineInputBorder())),
     if(widget.requireKnownCategory && choices.isEmpty)
      Padding(padding:const EdgeInsets.only(top:8),
       child:Text(tr('أضف قسمًا فرعيًا أولًا من صفحة الأقسام.',
        'Add a subcategory in Categories before posting.'),
        style:TextStyle(color:Theme.of(context).colorScheme.error))),
     if(mode==WaffraAccountOperation.expense && widget.availableBudgets.isNotEmpty)...[
      const SizedBox(height:12),
      DropdownButtonFormField<String>(key:const Key('m440-budget-picker'),
       isExpanded:true,initialValue:selectedBudgetId??'none',
       decoration:InputDecoration(labelText:tr('تسجيل في أي ميزانية؟','Budget'),
        border:const OutlineInputBorder()),
       items:[DropdownMenuItem(value:'none',child:Text(tr('بدون ميزانية','Unlinked'))),
        ...widget.availableBudgets.entries.map((e)=>DropdownMenuItem(
         value:e.key,child:Text(e.value,overflow:TextOverflow.ellipsis)))],
       onChanged:saving||saved?null:(value)=>setState(
        ()=>selectedBudgetId=value=='none'?null:value)),
     ],
    ],
    const SizedBox(height:12),
    TextField(key:const Key('m440-note'),controller:memo,
     maxLength:2000,minLines:1,maxLines:3,
     decoration:InputDecoration(labelText:tr('التفاصيل / الملاحظة','Details / note'),
      border:const OutlineInputBorder())),
    if(mode!=WaffraAccountOperation.transfer && widget.onConfirmEntry==null)
     Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Text(tr('تسجيل الدخل والمصروف في الحسابات ينتظر ربط الحفظ المالي الموثّق.',
       'Account income and expense require the verified finance save connection.'),
       style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(mode==WaffraAccountOperation.transfer && widget.onConfirmTransfer==null)
     Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Text(tr('التحويل غير متاح قبل تفعيل مصدر الحسابات الموثّق.',
       'Transfer requires the verified accounts source.'),
       style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:8),
     child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
    if(saved)Padding(padding:const EdgeInsets.symmetric(vertical:8),
     child:Text(tr('تم تأكيد العملية في قاعدة البيانات','Database confirmed the operation'),
      style:const TextStyle(color:Colors.green))),
    const SizedBox(height:12),
    FilledButton(
     key:const Key('m440-confirm'),
     onPressed:saving||saved ||
      (mode==WaffraAccountOperation.transfer?widget.onConfirmTransfer==null:
       widget.onConfirmEntry==null)?null:submit,
     child:Text(saving?tr('جاري الحفظ…','Saving…'):
      tr('تأكيد وحفظ العملية','Confirm transaction')),
    ),
   ]),
  ));
 }
}

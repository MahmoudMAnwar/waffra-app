import 'package:flutter/material.dart';
import 'main.dart' show snack;

import 'storage/waffra_accounts_repository.dart';
import 'storage/waffra_verified_accounts_api.dart';
import 'waffra_account_transaction_form.dart';

/// M440 optional SQLCipher account page. A production Home route must only
/// open this after the same certified finance source is active for SMS/widget.
class WaffraAccountsManagerPage extends StatefulWidget {
 const WaffraAccountsManagerPage({
  super.key,required this.repository,this.english=false,this.onConfirmEntry,
  this.incomeCategories=const [],this.expenseCategories=const [],
  this.availableBudgets=const {},
 });
 final WaffraAccountOperations repository;
 final bool english;
 final List<String> incomeCategories,expenseCategories;
 final Map<String,String> availableBudgets;
 final Future<void> Function(WaffraAccountTransactionDraft)? onConfirmEntry;
 @override State<WaffraAccountsManagerPage> createState()=>
  _WaffraAccountsManagerPageState();
}
class _WaffraAccountsManagerPageState extends State<WaffraAccountsManagerPage> {
 late Future<List<WaffraAccountBalance>> current;
 String t(String ar,String en)=>widget.english?en:ar;
 @override void initState(){super.initState();current=widget.repository.balances();}
 void reload(){if(mounted)setState(()=>current=widget.repository.balances());}
 void failed(){
  if(mounted)snack(context,
   t('تعذر التحقق من الحفظ. الرصيد لم يتغير.',
    'Save was not verified; no change was confirmed.'));
 }

 Future<void> addAccount()async{
  final name=TextEditingController(),opening=TextEditingController(text:'0');
  String kind='cash';
  try{
   final draft=await showDialog<({String name,String kind,int opening})>(
    context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,redraw)=>
     AlertDialog(title:Text(t('حساب جديد','New account')),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
       TextField(controller:name,maxLength:80,
        decoration:InputDecoration(labelText:t('اسم الحساب','Account name'))),
       DropdownButtonFormField<String>(initialValue:kind,
        decoration:InputDecoration(labelText:t('النوع','Type')),
        items:[
         DropdownMenuItem(value:'cash',child:Text(t('كاش','Cash'))),
         DropdownMenuItem(value:'bank',child:Text(t('حساب بنكي','Bank'))),
         DropdownMenuItem(value:'wallet',child:Text(t('محفظة','Wallet'))),
         DropdownMenuItem(value:'other',child:Text(t('أخرى','Other'))),
        ],onChanged:(v){if(v!=null)redraw(()=>kind=v);}),
       TextField(controller:opening,
        keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:InputDecoration(labelText:t('الرصيد الافتتاحي (ر.س)','Opening balance (SAR)'))),
      ])),
      actions:[
       TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('إلغاء','Cancel'))),
       FilledButton(onPressed:(){
        final minor=waffraSarAmountMinor(opening.text,allowZero:true);
        if(minor==null||name.text.trim().isEmpty)return;
        Navigator.pop(ctx,(name:name.text.trim(),kind:kind,opening:minor));
       },child:Text(t('إضافة','Add'))),
      ])));
   if(draft==null)return;
   await widget.repository.createAccount(
    id:'m440-'+DateTime.now().microsecondsSinceEpoch.toString(),
    name:draft.name,kind:draft.kind,openingMinor:draft.opening,
    createdIso:DateTime.now().toIso8601String(),userConfirmed:true);
   reload();
  }catch(_){failed();}
  finally{name.dispose();opening.dispose();}
 }

 Future<void> rename(WaffraAccountBalance item)async{
  final name=TextEditingController(text:item.name);
  try{
   final next=await showDialog<String>(context:context,builder:(ctx)=>
    AlertDialog(title:Text(t('تعديل اسم الحساب','Rename account')),
     content:TextField(controller:name,maxLength:80),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(t('إلغاء','Cancel'))),
      FilledButton(onPressed:()=>Navigator.pop(ctx,name.text.trim()),
       child:Text(t('حفظ','Save'))),
     ]));
   if(next==null||next.isEmpty)return;
   await widget.repository.renameAccount(
    id:item.id,name:next,userConfirmed:true);
   reload();
  }catch(_){failed();}
  finally{name.dispose();}
 }

 Future<void> archive(WaffraAccountBalance item)async{
  final approved=await showDialog<bool>(context:context,builder:(ctx)=>
   AlertDialog(title:Text(t('أرشفة الحساب؟','Archive account?')),
    content:Text(t('الحساب ذو الرصيد الصفري فقط يمكن أرشفته مع بقاء السجل.',
     'Only zero-balance accounts can be archived; history is preserved.')),
    actions:[
     TextButton(onPressed:()=>Navigator.pop(ctx,false),
      child:Text(t('إلغاء','Cancel'))),
     FilledButton(onPressed:()=>Navigator.pop(ctx,true),
      child:Text(t('تأكيد','Confirm'))),
    ]));
  if(approved!=true)return;
  try{
   await widget.repository.archiveEmptyAccount(
    id:item.id,userConfirmed:true);
   reload();
  }catch(_){failed();}
 }

 /// The verified adapter is the only permitted default manual writer.
 /// A caller-supplied callback may instead provide its own certified budget
 /// and category review before posting this confirmed transaction.
 Future<void> _saveClassifiedEntry(WaffraAccountTransactionDraft draft)async{
  final injected=widget.onConfirmEntry;
  if(injected!=null){await injected(draft);return;}
  final repository=widget.repository;
  if(repository is! WaffraVerifiedAccountsApi){
   throw StateError('Manual finance save requires a verified SQLCipher writer.');
  }
  final result=await repository.postAccountLinkedManual(
   record:<String,Object?>{
    'id':draft.requestId,
    'title':draft.title,
    'category':draft.category,
    'amount':draft.amountMinor/100,
    'income':draft.operation==WaffraAccountOperation.income,
    'date':DateTime.now().toIso8601String(),
    'receiptPath':null,
    'notes':draft.memo,
    'sourceType':'manual',
    if(draft.budgetId!=null)'budgetId':draft.budgetId,
   },
   accountId:draft.accountId,userConfirmed:true,
  );
  if(result.saved!=1){
   throw StateError('Account-linked manual save was not confirmed.');
  }
 }

 Future<void> compose(List<WaffraAccountBalance> accounts)async{
  await Navigator.of(context).push<void>(MaterialPageRoute(builder:(ctx)=>
   Scaffold(appBar:AppBar(title:Text(t('معاملة جديدة','New transaction'))),
    body:WaffraAccountTransactionForm(
     accounts:accounts,english:widget.english,
     incomeCategories:widget.incomeCategories,
     expenseCategories:widget.expenseCategories,
     availableBudgets:widget.availableBudgets,
     requireKnownCategory:true,
     onConfirmEntry:_saveClassifiedEntry,
     onConfirmTransfer:(draft)async{
      // The verified repository returns false for an exact same-ID replay:
      // that means the transfer is ALREADY committed. It is a successful
      // idempotent confirmation, not a failed banking transaction.
      await widget.repository.transfer(
       id:draft.requestId,fromAccountId:draft.fromId,
       toAccountId:draft.toId,amountMinor:draft.amountMinor,
       occurredIso:draft.occurredIso,
       note:draft.memo,userConfirmed:true);
     },
    ))));
  reload();
 }

 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(t('حساباتي','My accounts'))),
  body:FutureBuilder<List<WaffraAccountBalance>>(future:current,
   builder:(ctx,snapshot){
    if(snapshot.connectionState!=ConnectionState.done){
     return const Center(child:CircularProgressIndicator());
    }
    if(snapshot.hasError){
     return Center(child:Padding(padding:const EdgeInsets.all(24),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       Text(t('الحسابات غير جاهزة أو تحتاج إعدادًا موثّقًا.',
        'Accounts are unavailable or require verified setup.')),
       const SizedBox(height:12),
       FilledButton(onPressed:()async{
        final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>
         AlertDialog(
          title:Text(t('إعداد حساباتي؟','Set up accounts?')),
          content:Text(t(
           'هنجهز جدول الحسابات داخل نفس قاعدة البيانات المالية المشفّرة. '
           'مش هنعدّل أي عملية قديمة أو نفترض رصيدًا افتتاحيًا.',
           'Set up accounts inside the existing encrypted finance database. '
           'No historical transaction or opening balance will be modified.')),
          actions:[
           TextButton(onPressed:()=>Navigator.pop(ctx,false),
            child:Text(t('إلغاء','Cancel'))),
           FilledButton(onPressed:()=>Navigator.pop(ctx,true),
            child:Text(t('متابعة','Continue'))),
          ]));
        if(confirmed!=true)return;
        try{
         await widget.repository.initializeAccounts(userConfirmed:true);
         reload();
        }catch(_){failed();}
       },child:Text(t('إعداد الحسابات','Set up accounts'))),
      ])));
    }
    final accounts=snapshot.data??const <WaffraAccountBalance>[];
    final sum=accounts.fold<int>(0,(value,account)=>value+account.balanceMinor);
    String amount(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';
    return Column(children:[
     Card(child:ListTile(
      title:Text(t('إجمالي أرصدة حساباتي','Total account balances')),
      subtitle:Text(amount(sum),textDirection:TextDirection.ltr))),
     Expanded(child:accounts.isEmpty?
      Center(child:Text(t('أضف حسابًا أولًا','Add your first account'))):
      ListView.builder(itemCount:accounts.length,itemBuilder:(ctx,i){
       final a=accounts[i];
       return Card(child:ListTile(
        leading:Icon(a.kind=='bank'?Icons.account_balance:
         a.kind=='cash'?Icons.payments_outlined:Icons.account_balance_wallet_outlined),
        title:Text(a.name),
        subtitle:Text(amount(a.balanceMinor),textDirection:TextDirection.ltr),
        trailing:PopupMenuButton<String>(
         onSelected:(action){
          if(action=='rename')rename(a);
          if(action=='archive')archive(a);
         },
         itemBuilder:(ctx)=>[
          PopupMenuItem(value:'rename',child:Text(t('تعديل','Rename'))),
          if(!a.archived)PopupMenuItem(value:'archive',
           child:Text(t('أرشفة','Archive'))),
         ]),
       ));
      })),
     SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(12),
      child:Row(children:[
       Expanded(child:OutlinedButton.icon(onPressed:addAccount,
        icon:const Icon(Icons.add),label:Text(t('حساب جديد','New account')))),
       const SizedBox(width:8),
       Expanded(child:FilledButton.icon(
        onPressed:accounts.any((a)=>!a.archived)?()=>compose(accounts):null,
        icon:const Icon(Icons.swap_horiz),
        label:Text(t('معاملة جديدة','New transaction')))),
      ]))),
    ]);
   }),
 );
}

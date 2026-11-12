import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart' show snack;

import 'storage/waffra_accounts_repository.dart';
import 'storage/waffra_verified_accounts_api.dart';
import 'waffra_account_transaction_form.dart';
import 'waffra_account_context_page.dart';
import 'waffra_new_account_dialog.dart';
import 'waffra_saudi_financial_providers.dart';
import 'waffra_i18n.dart';

/// M440 optional SQLCipher account page. A production Home route must only
/// open this after the same certified finance source is active for SMS/widget.
class WaffraAccountsManagerPage extends StatefulWidget {
 const WaffraAccountsManagerPage({
  super.key,required this.repository,this.english=false,this.onConfirmEntry,
  this.incomeCategories=const [],this.expenseCategories=const [],
  this.availableBudgets=const {},this.onTransferConfirmed,
  this.onCreateHomeTransaction,
 });
 final Future<void> Function(WaffraInternalTransferDraft)? onTransferConfirmed;
 /// M667: the Home parent injects its real three-mode entrySheet, not a
 /// cloned form or a second financial writer. Standalone clients keep the
 /// existing verified composer until they can provide the Home entry owner.
 final Future<void> Function()? onCreateHomeTransaction;
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
  try{
   // The form only creates a draft. Existing verified account creation
   // remains the sole finance writer and rejects any stale SQLCipher witness.
   final options=await widget.repository.balances();
   if(!mounted)return;
   final customSubtypes=<String,List<String>>{
    for(final kind in const ['bank','wallet'])
     kind:options.where((a)=>!a.archived&&a.kind==kind&&
      a.customSubtypeLabel!=null).map((a)=>a.customSubtypeLabel!)
      .toSet().toList(growable:false)..sort(),
   };
   final draft=await showDialog<WaffraNewAccountDraft>(
    context:context,builder:(ctx)=>WaffraNewAccountDialog(
     english:widget.english,customSubtypeOptions:customSubtypes));
   if(draft==null)return;
   final id='m440-'+DateTime.now().microsecondsSinceEpoch.toString();
   final createdIso=DateTime.now().toIso8601String();
   final repository=widget.repository;
   if(repository is WaffraVerifiedAccountsApi){
    final subtype=draft.subtype,provider=draft.providerId;
    if(subtype==null||provider==null)throw StateError(
     'Account subtype and provider must be explicitly selected.');
    await repository.createTypedAccountWithIdentity(
     id:id,name:draft.name,kind:draft.kind,
     providerId:provider,subtype:subtype,
     openingMinor:draft.openingMinor,createdIso:createdIso,
     lastFour:draft.lastFour,
     customSubtypeLabel:draft.customSubtypeLabel,userConfirmed:true);
   }else if(draft.kind=='cash'||draft.kind=='other'){
    // Pure QA account adapters can still exercise historical cash/other
    // contracts; real production always uses the verified typed writer.
    await repository.createAccount(
     id:id,name:draft.name,kind:draft.kind,openingMinor:draft.openingMinor,
     createdIso:createdIso,userConfirmed:true);
   }else{
    throw StateError('Typed money accounts require verified SQLCipher.');
   }
   reload();
  }catch(_){failed();}
 }

 Future<void> rename(WaffraAccountBalance item)async{
  final verified=widget.repository is WaffraVerifiedAccountsApi
   ?widget.repository as WaffraVerifiedAccountsApi:null;
  final bankWithVerifiedSource=item.kind=='bank'&&verified!=null;
  String? savedSuffix;
  if(bankWithVerifiedSource){
   try{
    // The suffix shown here must come from the verified SQLCipher source.
    savedSuffix=await verified.verifiedBankSuffix(item.id);
   }catch(_){failed();return;}
  }
  final name=TextEditingController(text:item.name);
  final suffix=TextEditingController(text:savedSuffix??'');
  try{
   final edited=await showDialog<({String name,String? lastFour})>(
    context:context,builder:(ctx)=>StatefulBuilder(
     builder:(ctx,update){
      final candidate=name.text.trim();
      final digits=suffix.text.trim();
      final suffixValid=!bankWithVerifiedSource||
       (digits.isEmpty&&savedSuffix==null)||
       RegExp(r'^[0-9]{4}$').hasMatch(digits);
      return AlertDialog(
       title:Text(t('تعديل بيانات الحساب','Edit account details')),
       content:SingleChildScrollView(child:Column(
        mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         TextField(
          key:const Key('waffra-account-edit-name'),
          controller:name,maxLength:80,
          onChanged:(_)=>update((){}),
          decoration:InputDecoration(
           labelText:t('اسم الحساب','Account name'),
           border:const OutlineInputBorder())),
         if(bankWithVerifiedSource)...[
          const SizedBox(height:12),
          TextField(
           key:const Key('waffra-account-edit-last-four'),
           controller:suffix,maxLength:4,
           keyboardType:TextInputType.number,
           inputFormatters:[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
           ],
           onChanged:(_)=>update((){}),
           decoration:InputDecoration(
            labelText:t('آخر 4 أرقام للحساب','Account last four digits'),
            hintText:t('أدخل 4 أرقام','Enter 4 digits'),
            helperText:savedSuffix==null?t(
             'لم تُحفظ أرقام لهذا الحساب بعد.',
             'No verified last-four have been saved yet.'):t(
             'القيمة المحفوظة ظاهرة ويمكنك تصحيحها.',
             'The saved digits are displayed and editable.'),
            border:const OutlineInputBorder())),
         ],
        ])),
       actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),
         child:Text(t('إلغاء','Cancel'))),
        FilledButton(
         onPressed:candidate.isEmpty||candidate.runes.length>80||!suffixValid
          ?null:()=>Navigator.pop(ctx,(
           name:candidate,
           lastFour:bankWithVerifiedSource&&digits.isNotEmpty?digits:null)),
         child:Text(t('حفظ','Save'))),
       ],
      );
     }));
   if(edited==null)return;
   if(edited.name==item.name&&edited.lastFour==savedSuffix)return;
   if(verified!=null){
    // Revalidate what the user actually reviewed before a witnessed write.
    final latest=await verified.balances();
    final same=latest.where((a)=>a.id==item.id&&!a.archived&&
     a.name==item.name&&a.kind==item.kind).toList();
    if(same.length!=1)throw StateError('Account changed while being edited.');
    if(bankWithVerifiedSource&&
      await verified.verifiedBankSuffix(item.id)!=savedSuffix){
     throw StateError('Bank suffix changed while being edited.');
    }
   }
   if(bankWithVerifiedSource&&edited.lastFour!=null){
    await verified.renameAccountWithSuffix(
     id:item.id,name:edited.name,lastFour:edited.lastFour!,
     userConfirmed:true);
   }else{
    await widget.repository.renameAccount(
     id:item.id,name:edited.name,userConfirmed:true);
   }
   reload();
  }catch(_){failed();}
  finally{name.dispose();suffix.dispose();}
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

 Future<WaffraAccountBalance?> createAccountInsideComposer(
  String? providerGroup,bool createProvider)async{
  final verified=widget.repository;
  if(verified is! WaffraVerifiedAccountsApi){
   throw StateError('Inline Add requires a verified SQLCipher writer');
  }
  final existing=await verified.balances();
  if(!mounted)return null;
  final requestedGroup=createProvider?'':providerGroup??'';
  final requestedId=requestedGroup.split(':').last;
  final chosenProvider=WaffraSaudiFinancialProviders.byId(requestedId);
  final bank=chosenProvider!=null&&
   requestedGroup==chosenProvider.groupId?chosenProvider.id:null;
  final custom=<String,List<String>>{
   for(final kind in const ['bank','wallet'])
    kind:existing.where((a)=>!a.archived&&a.kind==kind&&
     a.customSubtypeLabel!=null).map((a)=>a.customSubtypeLabel!)
     .toSet().toList()..sort(),
  };
  final choice=await showDialog<WaffraNewAccountDraft>(
   context:context,builder:(ctx)=>WaffraNewAccountDialog(
    english:widget.english,suggestedProviderId:bank,
    customSubtypeOptions:custom));
  if(choice==null||!mounted)return null;
  if(bank!=null&&(
   choice.kind!=(chosenProvider!.category==WaffraSaudiFinancialProviders.wallet?'wallet':'bank')||
   choice.providerId!=bank)){
   throw StateError('Child account must be under the selected bank');
  }
  final newId='m499-account-composer-'+
   DateTime.now().microsecondsSinceEpoch.toString();
  await verified.createTypedAccountWithIdentity(
   id:newId,name:choice.name,kind:choice.kind,
   providerId:choice.providerId??'none',
   subtype:choice.subtype??'other',openingMinor:choice.openingMinor,
   createdIso:DateTime.now().toIso8601String(),
   lastFour:choice.lastFour,customSubtypeLabel:choice.customSubtypeLabel,
   userConfirmed:true);
  final refreshed=await verified.balances();
  final found=refreshed.where((a)=>a.id==newId&&!a.archived).toList();
  if(found.length!=1)throw StateError('Created account not verified');
  reload();
  return found.single;
 }

 Future<void> compose(List<WaffraAccountBalance> accounts)async{
  // M667: My Accounts in the app must open exactly the SAME Home form as +.
  // The callback owns all income/expense/transfer validation and commits.
  // Never run the older account-only composer after this route returns.
  final homeComposer=widget.onCreateHomeTransaction;
  if(homeComposer!=null){
   await homeComposer();
   if(mounted)reload();
   return;
  }
  await Navigator.of(context).push<void>(MaterialPageRoute(builder:(ctx)=>
   Scaffold(appBar:AppBar(title:Text(t('معاملة جديدة','New transaction'))),
    body:WaffraAccountTransactionForm(
     accounts:accounts,english:widget.english,
     onCreateAccount:createAccountInsideComposer,
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
      // Learning failures cannot retry or roll back a verified transfer.
      try{await widget.onTransferConfirmed?.call(draft);}catch(_){}
     },
    ))));
  reload();
 }

 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(
   title:Text(t('حساباتي','My accounts')),
   actions:[
    if(widget.repository is WaffraVerifiedAccountsApi)
     IconButton(
      tooltip:t('كل الحسابات والعمليات بدون حساب','All and unassigned transactions'),
      icon:const Icon(Icons.receipt_long_outlined),
      onPressed:()async{
       final api=widget.repository as WaffraVerifiedAccountsApi;
       try{
        final accounts=await api.balances();
        if(!mounted)return;
        await Navigator.of(context).push<void>(MaterialPageRoute(
         builder:(ctx)=>WaffraAccountContextPage(
          api:api,accounts:accounts,english:widget.english)));
        reload();
       }catch(_){failed();}
      },
     ),
   ],
  ),
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
      subtitle:WaffraText(amount(sum),currencyEnglish:widget.english,textDirection:TextDirection.ltr))),
     Expanded(child:accounts.isEmpty?
      Center(child:Text(t('أضف حسابًا أولًا','Add your first account'))):
      ListView.builder(itemCount:accounts.length,itemBuilder:(ctx,i){
       final a=accounts[i];
       return Card(child:ListTile(
        leading:Icon(a.kind=='bank'?Icons.account_balance:
         a.kind=='cash'?Icons.payments_outlined:Icons.account_balance_wallet_outlined),
        title:Text(a.name),
        subtitle:Column(mainAxisSize:MainAxisSize.min,
         crossAxisAlignment:CrossAxisAlignment.start,children:[
         if(a.customSubtypeLabel!=null)
          Text(t('نوع الحساب: ','Account subtype: ')+a.customSubtypeLabel!,
           key:Key('m497-custom-subtype-${a.id}'),
           style:Theme.of(ctx).textTheme.bodySmall),
         WaffraText(amount(a.balanceMinor),currencyEnglish:widget.english,textDirection:TextDirection.ltr),
        ]),
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

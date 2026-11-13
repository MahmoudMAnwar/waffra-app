import 'package:flutter/material.dart';
import 'waffra_centered_dropdown.dart';
import 'main.dart' show snack;
import 'waffra_account_context_settings.dart';
import 'waffra_i18n.dart';

import 'storage/waffra_account_context_read.dart';
import 'storage/waffra_accounts_repository.dart';
import 'storage/waffra_verified_accounts_api.dart';

/// Account-aware ledger review, with a real "unassigned" work queue.
/// Nothing is assigned based on the Home header selection.
class WaffraAccountContextPage extends StatefulWidget {
 const WaffraAccountContextPage({
  super.key, required this.api, required this.accounts,
  this.english=false,
 });
 final WaffraVerifiedAccountsApi api;
 final List<WaffraAccountBalance> accounts;
 final bool english;
 @override State<WaffraAccountContextPage> createState()=>_WaffraAccountContextPageState();
}

class _WaffraAccountContextPageState extends State<WaffraAccountContextPage> {
 String filter='all';
 int pageOffset=0;
 static const int pageSize=50;
 DateTime selectedMonth=DateTime(DateTime.now().year,DateTime.now().month,1);
 late Future<WaffraAccountContextReadResult> future;
 late Future<List<WaffraAccountLedgerRow>> ledgerPage;
 late Future<({int count,int netMinor})> unassignedPreview;
 String t(String ar,String en)=>widget.english?en:ar;
 String get month=>selectedMonth.year.toString().padLeft(4,'0')+'-'+
  selectedMonth.month.toString().padLeft(2,'0');
 String? get accountId=>filter.startsWith('account:')?
  filter.substring('account:'.length):null;
 @override void initState(){super.initState();reload();}
 void reload(){
  future=widget.api.readAccountContext(
   monthIso:month,selectedAccountId:accountId,summaryOnly:true);
  ledgerPage=filter=='none'
   ?widget.api.readUnassignedPage(limit:pageSize,offset:pageOffset)
   :widget.api.readMonthlyPage(monthIso:month,selectedAccountId:accountId,
     limit:pageSize,offset:pageOffset);
  unassignedPreview=widget.api.readUnassignedSummary();
 }
 String money(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';

 Future<void> link(WaffraAccountLedgerRow entry)async{
  String? selected;
  bool openingVerified=false;
  final active=widget.accounts.where((a)=>!a.archived).toList();
  if(active.isEmpty)return;
  final chosen=await showDialog<String>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,rebuild)=>
    AlertDialog(
     title:Text(t('ربط العملية بحساب','Assign transaction to account')),
     content:SingleChildScrollView(child:Column(
      mainAxisSize:MainAxisSize.min,children:[
      Text(entry.title),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<String>(
       isExpanded:true,initialValue:selected,
       decoration:InputDecoration(
        labelText:t('اختر الحساب','Select account'),
        border:const OutlineInputBorder()),
       items:active.map((a)=>DropdownMenuItem(
        value:a.id,child:Text(a.name))).toList(),
       onChanged:(v)=>rebuild(()=>selected=v),
      ),
      const SizedBox(height:12),
      WaffraText((entry.income?'+':'−')+money(entry.amountMinor),
       currencyEnglish:widget.english,textDirection:TextDirection.ltr),
      const SizedBox(height:8),
      Text(t('مش هنسجل دخل أو مصروف جديد. لو الحساب له رصيد افتتاحي، تأكد إن العملية القديمة مش محسوبة فيه قبل الربط.',
       'No new income or expense. If the account has opening cash, confirm it does not already include this historic entry.')),
      CheckboxListTile(
       key:const Key('m681-opening-balance-attestation'),
       contentPadding:EdgeInsets.zero,
       controlAffinity:ListTileControlAffinity.leading,
       value:openingVerified,
       onChanged:(value)=>rebuild(()=>openingVerified=value??false),
       title:Text(t('تأكدت إن الرصيد الافتتاحي لا يشمل العملية دي',
        'I confirm this transaction is not included in opening balance'),
        style:const TextStyle(fontSize:12)),
      ),
     ])),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),
       child:Text(t('إلغاء','Cancel'))),
      FilledButton(onPressed:selected==null||!openingVerified?null:
       ()=>Navigator.pop(ctx,selected),
       child:Text(t('تأكيد الربط','Confirm'))),
     ],
    )));
  if(chosen==null||!mounted)return;
  try{
   // Reads are witnessed under the same source lock. Refresh the witness
   // before mutating in case this page remained open while widget posted.
   await widget.api.balances();
   await widget.api.linkUnassignedEntry(
    entryId:entry.id,accountId:chosen,userConfirmed:true,
    openingExcludesHistory:openingVerified);
   if(mounted)setState(reload);
  }catch(error){
   final opening=error is StateError &&
    error.toString().contains('opening balance');
   if(mounted)snack(context,opening?
    t('راجع الرصيد الافتتاحي وأكّد إن العملية مش محسوبة فيه.',
      'Verify this entry is excluded from opening balance.'):
    t('تعذر تأكيد الربط؛ حدّث الصفحة وحاول مرة أخرى.',
      'Could not confirm account link. Refresh and retry.'));
  }
 }

 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(t('عمليات الحسابات','Account transactions'))),
  body:FutureBuilder<WaffraAccountContextReadResult>(
   future:future,builder:(ctx,snapshot){
    if(snapshot.connectionState!=ConnectionState.done){
     return const Center(child:CircularProgressIndicator());
    }
    if(snapshot.hasError){
     return Center(child:Text(t('تعذر قراءة السجل المالي المشفر.',
      'The encrypted finance ledger is unavailable.')));
    }
    final data=snapshot.data!;
    final labels={for(final a in widget.accounts)a.id:a.name};
    return ListView(children:[
     FutureBuilder<({int count,int netMinor})>(
      future:unassignedPreview,builder:(ctx,preview){
       if(!preview.hasData)return const SizedBox.shrink();
       final v=preview.data!;
       return Card(
        key:const Key('m681-unassigned-reconciliation-summary'),
        child:ListTile(
         leading:const Icon(Icons.fact_check_outlined),
         title:Text(t('عمليات قديمة بدون حساب: ${v.count}',
          'Historical unassigned entries: ${v.count}')),
         subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          WaffraText(money(v.netMinor),
           currencyEnglish:widget.english,textDirection:TextDirection.ltr),
          Text(t('صافي تاريخي، مش رصيد بنكي متاح.',
           'Historical net, not available bank cash.')),
         ]),
         trailing:v.count==0?null:TextButton(
          onPressed:()=>setState((){filter='none';pageOffset=0;reload();}),
          child:Text(t('مراجعة','Review'))),
        ));}),
     if(filter!='none')Padding(
      padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
      child:Row(children:[
       IconButton(
        key:const Key('m684-previous-month'),
        tooltip:t('الشهر السابق','Previous month'),
        onPressed:()=>setState((){
         selectedMonth=DateTime(selectedMonth.year,selectedMonth.month-1,1);
         pageOffset=0;reload();
        }),icon:const Icon(Icons.chevron_right)),
       Expanded(child:Text(month,textAlign:TextAlign.center,
        style:Theme.of(context).textTheme.titleMedium)),
       IconButton(
        key:const Key('m684-next-month'),
        tooltip:t('الشهر التالي','Next month'),
        onPressed:()=>setState((){
         selectedMonth=DateTime(selectedMonth.year,selectedMonth.month+1,1);
         pageOffset=0;reload();
        }),icon:const Icon(Icons.chevron_left)),
      ])),
     Padding(padding:const EdgeInsets.all(12),
      child:WaffraCenteredDropdownFormField<String>(
       key:ValueKey(filter),initialValue:filter,isExpanded:true,
       decoration:InputDecoration(
        labelText:t('فلتر الحساب','Account filter'),
        border:const OutlineInputBorder()),
       items:[
        DropdownMenuItem(value:'all',
         child:Text(t('كل الحسابات','All accounts'))),
        DropdownMenuItem(value:'none',
         child:Text(t('بدون حساب','Unassigned'))),
        ...widget.accounts.map((account)=>DropdownMenuItem(
         value:'account:'+account.id,child:Text(account.name))),
       ],
       onChanged:(value){if(value==null)return;setState((){
        filter=value;pageOffset=0;reload();
       });},
      )),
     WaffraAccountContextSettings(
      api:widget.api,accounts:widget.accounts,english:widget.english),
     if(data.goals.isNotEmpty)...[
      Padding(padding:const EdgeInsets.all(12),
       child:Text(t('الأهداف ومحفظة الادخار','Savings goals and wallet'),
        style:Theme.of(context).textTheme.titleMedium)),
      ...data.goals.map((goal)=>Card(child:ListTile(
       title:Text(goal.name),
       subtitle:WaffraText(accountId==null
        ?t('إجمالي الادخار: ','Total saved: ')+money(goal.totalSavedMinor)
        :t('مساهمة الحساب: ','Account contribution: ')+
          money(goal.selectedAccountNetMinor)+'\n'+
          t('إجمالي الادخار: ','Total saved: ')+money(goal.totalSavedMinor)),
      ))),
     ],
     if(data.budgets.isNotEmpty)...[
      Padding(padding:const EdgeInsets.all(12),
       child:Text(t('الميزانيات هذا الشهر','This month’s budgets'),
        style:Theme.of(context).textTheme.titleMedium)),
      ...data.budgets.map((item)=>Card(child:ListTile(
       title:Text(item.name),
       subtitle:WaffraText(accountId==null
        ?t('إجمالي المصروف: ','Overall spent: ')+
         money(item.usage.globalSpentMinor)+' / '+money(item.usage.limitMinor)
        :t('من هذا الحساب: ','From this account: ')+
         money(item.usage.selectedAccountSpentMinor)+'\n'+
         t('الإجمالي: ','Overall: ')+
         money(item.usage.globalSpentMinor)+' / '+money(item.usage.limitMinor)),
      ))),
     ],
     Padding(padding:const EdgeInsets.all(12),
      child:Text(t('العمليات','Transactions'),
       style:Theme.of(context).textTheme.titleMedium)),
     FutureBuilder<List<WaffraAccountLedgerRow>>(
      future:ledgerPage,builder:(ctx,result){
       if(result.connectionState!=ConnectionState.done){
        return const Center(child:Padding(padding:EdgeInsets.all(18),
         child:CircularProgressIndicator()));
       }
       if(result.hasError){
        return Padding(padding:const EdgeInsets.all(16),
         child:Text(t('تعذر تحميل صفحة العمليات.', 'Failed loading entries.')));
       }
       final items=result.data??const <WaffraAccountLedgerRow>[];
       return Column(children:[
        if(items.isEmpty)Padding(padding:const EdgeInsets.all(16),
         child:Text(t('لا توجد عمليات في هذا الفلتر.', 'No entries for this filter.'))),
        for(final entry in items)Card(
         key:Key('m681-ledger-row-'+entry.id),
         child:ListTile(
          title:Text(entry.title),
          subtitle:Text(entry.occurredIso.split('T').first+' • '+
           (entry.accountId==null?t('بدون حساب','Unassigned'):
            labels[entry.accountId]??t('حساب سابق','Previous account'))),
          trailing:Column(mainAxisSize:MainAxisSize.min,
           mainAxisAlignment:MainAxisAlignment.center,children:[
           WaffraText((entry.income?'+':'-')+money(entry.amountMinor),
            currencyEnglish:widget.english,textDirection:TextDirection.ltr),
           if(entry.accountId==null)Text(t('ربط','Link'),
            style:Theme.of(context).textTheme.labelSmall),
          ]),
          onTap:entry.accountId==null?()=>link(entry):null,
         )),
        Padding(padding:const EdgeInsets.all(8),child:Row(children:[
         if(pageOffset>0)TextButton(
          key:const Key('m684-ledger-page-previous'),
          onPressed:()=>setState((){pageOffset-=pageSize;reload();}),
          child:Text(t('السابق','Previous'))),
         const Spacer(),
         if(items.length==pageSize)TextButton(
          key:const Key('m684-ledger-page-next'),
          onPressed:()=>setState((){pageOffset+=pageSize;reload();}),
          child:Text(t('التالي','Next'))),
        ])),
       ]);
      }),
    ]);
   },
  ),
 );
}

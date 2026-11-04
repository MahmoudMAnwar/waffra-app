import 'package:flutter/material.dart';
import 'waffra_account_context_settings.dart';

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
 int visibleCount=100;
 late Future<WaffraAccountContextReadResult> future;
 String t(String ar,String en)=>widget.english?en:ar;
 String get month {
  final now=DateTime.now();
  return now.year.toString().padLeft(4,'0')+'-'+
   now.month.toString().padLeft(2,'0');
 }
 String? get accountId=>filter.startsWith('account:')?
  filter.substring('account:'.length):null;
 @override void initState(){super.initState();reload();}
 void reload(){
  future=widget.api.readAccountContext(
    monthIso:month,selectedAccountId:accountId);
 }
 String money(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';

 Future<void> link(WaffraAccountLedgerRow entry)async{
  String? selected;
  final active=widget.accounts.where((a)=>!a.archived).toList();
  if(active.isEmpty)return;
  final chosen=await showDialog<String>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,rebuild)=>
    AlertDialog(
     title:Text(t('ربط العملية بحساب','Assign transaction to account')),
     content:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(entry.title),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
       isExpanded:true,initialValue:selected,
       decoration:InputDecoration(
        labelText:t('اختر الحساب','Select account'),
        border:const OutlineInputBorder()),
       items:active.map((a)=>DropdownMenuItem(
        value:a.id,child:Text(a.name))).toList(),
       onChanged:(v)=>rebuild(()=>selected=v),
      ),
      const SizedBox(height:12),
      Text(t('لن نضيف دخلًا أو مصروفًا مرة ثانية. هيتغيّر رصيد الحساب بعد التأكيد فقط.',
       'No second income or expense will be created. Only the chosen balance changes.')),
     ]),
     actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx),
       child:Text(t('إلغاء','Cancel'))),
      FilledButton(onPressed:selected==null?null:
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
    entryId:entry.id,accountId:chosen,userConfirmed:true);
   if(mounted)setState(reload);
  }catch(_){
   if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content:Text(t('تعذر تأكيد الربط؛ حدّث الصفحة وحاول مرة أخرى.',
     'Could not confirm account link. Refresh and retry.'))));
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
    final entries=data.entries.where((entry){
     if(filter=='none')return entry.accountId==null;
     if(filter=='all')return true;
     return entry.accountId==accountId;
    }).toList();
    return ListView(children:[
     Padding(padding:const EdgeInsets.all(12),
      child:DropdownButtonFormField<String>(
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
        filter=value;visibleCount=100;reload();
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
       subtitle:Text(accountId==null
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
       subtitle:Text(accountId==null
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
     if(entries.isEmpty)Padding(padding:const EdgeInsets.all(16),
      child:Text(t('لا توجد عمليات في هذا الفلتر.',
       'No entries for this filter.'))),
     ...entries.take(visibleCount).map((entry)=>Card(child:ListTile(
      title:Text(entry.title),
      subtitle:Text(entry.occurredIso.split('T').first+' • '+
       (entry.accountId==null?t('بدون حساب','Unassigned'):
        labels[entry.accountId]??t('حساب سابق','Previous account'))),
      trailing:Column(mainAxisSize:MainAxisSize.min,
       mainAxisAlignment:MainAxisAlignment.center,children:[
       Text((entry.income?'+':'-')+money(entry.amountMinor),
        textDirection:TextDirection.ltr),
       if(entry.accountId==null)Text(t('ربط','Link'),
        style:Theme.of(context).textTheme.labelSmall),
      ]),
      onTap:entry.accountId==null?()=>link(entry):null,
     ))),
     if(entries.length>visibleCount)Padding(
      padding:const EdgeInsets.all(12),
      child:OutlinedButton.icon(
       onPressed:()=>setState(()=>visibleCount+=100),
       icon:const Icon(Icons.expand_more),
       label:Text(t('عرض المزيد من العمليات','Show more transactions')+
        ' (${entries.length-visibleCount})'),
      )),
    ]);
   },
  ),
 );
}

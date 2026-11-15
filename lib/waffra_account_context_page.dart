import 'package:flutter/material.dart';
import 'waffra_centered_dropdown.dart';
import 'main.dart' show snack;
import 'waffra_account_context_settings.dart';
import 'waffra_financial_trust_page.dart';
import 'waffra_financial_trust_policy.dart';
import 'waffra_i18n.dart';

import 'storage/waffra_account_context_read.dart';
import 'storage/waffra_sqlcipher_history_pager.dart';
import 'storage/waffra_accounts_repository.dart';
import 'storage/waffra_verified_accounts_api.dart';

/// Account-aware ledger review, with a real "unassigned" work queue.
/// Nothing is assigned based on the Home header selection.
class WaffraAccountContextPage extends StatefulWidget {
 const WaffraAccountContextPage({
  super.key, required this.api, required this.accounts,
  this.english=false,this.upcomingDues=const <WaffraTrustDue>[],
 });
 final WaffraVerifiedAccountsApi api;
 final List<WaffraAccountBalance> accounts;
 final bool english;
 final List<WaffraTrustDue> upcomingDues;
 @override State<WaffraAccountContextPage> createState()=>_WaffraAccountContextPageState();
}

class _WaffraAccountContextPageState extends State<WaffraAccountContextPage> {
 final _search=TextEditingController();
 final _category=TextEditingController();
 final _minimum=TextEditingController();
 final _maximum=TextEditingController();
 String searchTerm='',categoryTerm='';
 int? minimumMinor,maximumMinor;
 bool? incomeFilter;
 DateTimeRange? searchDates;
 String? searchError;
 int? parseMinor(String raw){
  if(raw.trim().isEmpty)return null;
  final value=num.tryParse(raw.trim());
  if(value==null||!value.isFinite||value<0||value>1000000000000){
   throw const FormatException('Invalid amount');
  }
  final minor=(value*100).round();
  if((minor/100-value).abs()>0.000001)throw const FormatException('Non-SAR fraction');
  return minor;
 }
 bool get advancedActive=>searchTerm.isNotEmpty||categoryTerm.isNotEmpty||
  minimumMinor!=null||maximumMinor!=null||incomeFilter!=null||
  searchDates!=null;
 void applySearch(){
  try{
   final min=parseMinor(_minimum.text),max=parseMinor(_maximum.text);
   if(min!=null&&max!=null&&min>max)throw const FormatException('Invalid range');
   setState((){
    searchTerm=_search.text.trim();categoryTerm=_category.text.trim();
    minimumMinor=min;maximumMinor=max;searchError=null;
    resetPages();reload();
   });
  }catch(_){setState(()=>searchError=t('راجع حدود المبالغ بالريال والهللة.',
    'Check the SAR amount range.'));}
 }
 void clearSearch(){
  _search.clear();_category.clear();_minimum.clear();_maximum.clear();
  setState((){
   searchTerm='';categoryTerm='';minimumMinor=null;maximumMinor=null;
   incomeFilter=null;searchDates=null;searchError=null;
   resetPages();reload();
  });
 }
 @override void dispose(){
  _search.dispose();_category.dispose();_minimum.dispose();_maximum.dispose();
  super.dispose();
 }
 String filter='all';
 int pageOffset=0;
 static const int pageSize=50;
 // M952: one cursor per visited page for BOTH monthly ledger and historical
 // unassigned entries. Do not OFFSET-scan older 1,000–10,000 rows.
 final Map<int,WaffraSqlcipherHistoryCursor?> _m944MonthCursors={0:null};
 void resetPages(){
  pageOffset=0;
  _m944MonthCursors.clear();
  _m944MonthCursors[0]=null;
 }
 DateTime selectedMonth=DateTime(DateTime.now().year,DateTime.now().month,1);
 late Future<WaffraAccountContextReadResult> future;
 late Future<WaffraSqlcipherHistoryPage> ledgerPage;
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
  // Both filters must have a verified cursor from the previous displayed
  // page. Reset whenever month, account or link state changes.
  if(!_m944MonthCursors.containsKey(pageOffset)){
   throw StateError('Missing encrypted history cursor; refresh before paging.');
  }
  ledgerPage=widget.api.readKeysetHistoryPage(
   monthIso:filter=='none'||advancedActive?null:month,
   selectedAccountId:filter=='none'?null:accountId,
   unassignedOnly:filter=='none',
   income:incomeFilter,
   searchTerm:searchTerm,categoryTerm:categoryTerm,
   minimumMinor:minimumMinor,maximumMinor:maximumMinor,
   startDate:searchDates?.start,endDate:searchDates?.end,
   limit:pageSize,after:_m944MonthCursors[pageOffset]);
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
   if(mounted)setState((){resetPages();reload();});
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
  appBar:AppBar(title:Text(t('عمليات الحسابات','Account transactions')),
   actions:[IconButton(
    tooltip:t('فحص سلامة البيانات المالية','Financial integrity check'),
    icon:const Icon(Icons.fact_check_outlined),
    onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(
     builder:(_)=>WaffraFinancialTrustPage(
      api:widget.api,english:widget.english,
      upcomingDues:widget.upcomingDues))),
   )]),
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
          onPressed:()=>setState((){filter='none';resetPages();reload();}),
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
         resetPages();reload();
        }),icon:const Icon(Icons.chevron_right)),
       Expanded(child:Text(month,textAlign:TextAlign.center,
        style:Theme.of(context).textTheme.titleMedium)),
       IconButton(
        key:const Key('m684-next-month'),
        tooltip:t('الشهر التالي','Next month'),
        onPressed:()=>setState((){
         selectedMonth=DateTime(selectedMonth.year,selectedMonth.month+1,1);
         resetPages();reload();
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
        filter=value;resetPages();reload();
       });},
      )),
     Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:6),
      child:Padding(padding:const EdgeInsets.all(12),child:Column(
       crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Text(t('بحث موحّد في سجل SQLCipher','Verified ledger search'),
        style:Theme.of(context).textTheme.titleSmall),
       const SizedBox(height:8),
       TextField(controller:_search,maxLength:160,
        textInputAction:TextInputAction.search,onSubmitted:(_)=>applySearch(),
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
         labelText:t('التاجر أو وصف المعاملة','Merchant or description'),
         border:const OutlineInputBorder())),
       TextField(controller:_category,maxLength:120,
        textInputAction:TextInputAction.search,onSubmitted:(_)=>applySearch(),
        decoration:InputDecoration(
         labelText:t('القسم الرئيسي أو الفرعي','Main or subcategory'),
         border:const OutlineInputBorder())),
       const SizedBox(height:6),
       DropdownButtonFormField<String>(
        value:incomeFilter==null?'all':incomeFilter!?'in':'out',
        isExpanded:true,
        decoration:InputDecoration(labelText:t('نوع العملية','Transaction type'),
         border:const OutlineInputBorder()),
        items:[
         DropdownMenuItem(value:'all',child:Text(t('الكل','All'))),
         DropdownMenuItem(value:'in',child:Text(t('دخل','Income'))),
         DropdownMenuItem(value:'out',child:Text(t('مصروف','Expense'))),
        ],
        onChanged:(value)=>setState((){
         incomeFilter=value=='all'?null:value=='in';
         resetPages();reload();
        })),
       const SizedBox(height:8),
       Row(children:[
        Expanded(child:TextField(controller:_minimum,
         keyboardType:const TextInputType.numberWithOptions(decimal:true),
         decoration:InputDecoration(labelText:t('من ريال','Minimum SAR'),
          border:const OutlineInputBorder()),
         onSubmitted:(_)=>applySearch())),
        const SizedBox(width:8),
        Expanded(child:TextField(controller:_maximum,
         keyboardType:const TextInputType.numberWithOptions(decimal:true),
         decoration:InputDecoration(labelText:t('إلى ريال','Maximum SAR'),
          border:const OutlineInputBorder()),
         onSubmitted:(_)=>applySearch())),
       ]),
       const SizedBox(height:8),
       Wrap(spacing:8,runSpacing:4,children:[
        OutlinedButton.icon(icon:const Icon(Icons.date_range_outlined),
         label:Text(searchDates==null?t('التاريخ','Date range'):
          t('التاريخ محدد','Date selected')),
         onPressed:()async{
          final chosen=await showDateRangePicker(context:context,
           firstDate:DateTime(2000),lastDate:DateTime(2100),
           initialDateRange:searchDates);
          if(chosen!=null&&mounted)setState((){
           searchDates=chosen;resetPages();reload();
          });
         }),
        FilledButton.icon(icon:const Icon(Icons.search),
         onPressed:applySearch,label:Text(t('بحث','Search'))),
        TextButton(onPressed:clearSearch,child:Text(t('مسح','Clear'))),
       ]),
       if(searchError!=null)Text(searchError!,
        style:TextStyle(color:Theme.of(context).colorScheme.error)),
       if(advancedActive)Text(t('البحث في كل الفترات، دون تحميل كل العمليات.',
        'Searching all periods with bounded SQLCipher pages.')),
      ]))),
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
     FutureBuilder<WaffraSqlcipherHistoryPage>(
      future:ledgerPage,builder:(ctx,result){
       if(result.connectionState!=ConnectionState.done){
        return const Center(child:Padding(padding:EdgeInsets.all(18),
         child:CircularProgressIndicator()));
       }
       if(result.hasError){
        return Padding(padding:const EdgeInsets.all(16),
         child:Text(t('تعذر تحميل صفحة العمليات.', 'Failed loading entries.')));
       }
       final page=result.data;
       final items=page?.entries??const <WaffraAccountLedgerRow>[];
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
         if(page?.hasMore==true)TextButton(
          key:const Key('m684-ledger-page-next'),
          onPressed:()=>setState((){
           final next=page!.nextCursor;
           if(next==null)throw StateError('Missing encrypted next-page cursor.');
           _m944MonthCursors[pageOffset+pageSize]=next;
           pageOffset+=pageSize;
           reload();
          }),
          child:Text(t('التالي','Next'))),
        ])),
       ]);
      }),
    ]);
   },
  ),
 );
}

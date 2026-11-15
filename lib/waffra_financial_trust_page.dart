import 'package:flutter/material.dart';

import 'storage/waffra_verified_accounts_api.dart';
import 'waffra_financial_trust_policy.dart';

/// M1000 trust center: ONLY witnessed financial reads. Never repairs, posts,
/// changes backups, or treats a projected cashflow as the bank balance.
class WaffraFinancialTrustPage extends StatefulWidget {
 const WaffraFinancialTrustPage({
  super.key,required this.api,this.english=false,
  this.upcomingDues=const <WaffraTrustDue>[],
 });
 final WaffraVerifiedAccountsApi api;
 final bool english;
 final List<WaffraTrustDue> upcomingDues;
 @override State<WaffraFinancialTrustPage> createState()=>
  _WaffraFinancialTrustPageState();
}
class _WaffraFinancialTrustPageState extends State<WaffraFinancialTrustPage> {
 late Future<WaffraTrustScan> scan;
 String t(String ar,String en)=>widget.english?en:ar;
 String cash(int minor)=>(minor/100).toStringAsFixed(2)+' SAR';
 @override void initState(){super.initState();scan=widget.api.inspectFinanceIntegrity();}
 Future<void> refresh() async {
  final next=widget.api.inspectFinanceIntegrity();
  if(mounted)setState(()=>scan=next);
  try{await next;}catch(_){/* FutureBuilder owns the safe error UI. */}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:Text(t('سلامة بياناتك المالية','Financial data integrity')),
   actions:[IconButton(
    tooltip:t('تحديث الفحص','Refresh integrity scan'),
    onPressed:refresh,icon:const Icon(Icons.refresh_outlined))]),
  body:FutureBuilder<WaffraTrustScan>(
   future:scan,builder:(context,snapshot){
    if(snapshot.connectionState!=ConnectionState.done){
     return const Center(child:CircularProgressIndicator());
    }
    if(!snapshot.hasData){
     return Center(child:Padding(padding:const EdgeInsets.all(24),
      child:Text(t('تعذر فحص مصدر الحسابات المشفر. لم نغيّر أي رصيد. حدّث الفحص بعد فتح الحسابات.',
       'Unable to verify encrypted accounts. No balances were changed. Refresh after reopening accounts.'),
       textAlign:TextAlign.center)));
    }
    final data=snapshot.data!;
    final collisions=WaffraTrustRecurringReview.possibleDuplicates(
      widget.upcomingDues);
    final verified=data.matches;
    final now=DateTime.now();
    final projected=WaffraTrustCashflow.project(
      verifiedCurrentMinor:data.totalMinor,
      today:now,through:DateTime(now.year,now.month+1,now.day),
      dues:widget.upcomingDues);
    Widget header(String ar,String en)=>Padding(
     padding:const EdgeInsets.fromLTRB(16,18,16,6),
     child:Text(t(ar,en),style:Theme.of(context).textTheme.titleMedium));
    return RefreshIndicator(
     onRefresh:refresh,child:ListView(
      physics:const AlwaysScrollableScrollPhysics(),children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,16,16,6),child:Text(
       t('الفحص للقراءة فقط. لن نعدّل الأرصدة أو نحذف عمليات بدون موافقتك.',
        'Read-only verification. No balances or records are changed.'))),
      Card(margin:const EdgeInsets.symmetric(horizontal:12),child:Semantics(
       label:t(verified?'الأرصدة متطابقة حسابيًا':'يوجد اختلاف في الأرصدة',
        verified?'Balances reconcile':'Balance discrepancy detected'),
       child:ListTile(
        leading:Icon(verified?Icons.verified_outlined:Icons.warning_amber,
         color:verified?Colors.green:Colors.orange),
        title:Text(t(verified?'الأرصدة متطابقة':'فرق يحتاج مراجعة',
         verified?'Balances match':'Difference needs review')),
        subtitle:Text(t('عدد الحسابات: ','Accounts: ')+
         data.accounts.length.toString()+
         '\n'+t('عدد التحويلات الداخلية: ','Internal transfers: ')+
         data.transferCount.toString()),
        isThreeLine:true,
       ))),
      header('أرصدة الحسابات','Account balances'),
      for(final a in data.accounts)Card(
       margin:const EdgeInsets.symmetric(horizontal:12,vertical:3),
       child:ListTile(
        leading:Icon(a.matches?Icons.check_circle_outline:
         Icons.error_outline,color:a.matches?Colors.green:Colors.orange),
        title:Text(a.name),
        subtitle:Text(t('الافتتاحي: ','Opening: ')+cash(a.openingMinor)+
         '\n'+t('المحسوب من الحركات: ','Reconstructed: ')+
         cash(a.expectedMinor)),
        isThreeLine:true,
        trailing:Semantics(label:t('الرصيد الحالي','Current balance'),
         child:Text(cash(a.actualMinor),textDirection:TextDirection.ltr)),
       )),
      Card(margin:const EdgeInsets.fromLTRB(12,8,12,0),child:ListTile(
       leading:const Icon(Icons.link_off_outlined),
       title:Text(t('عمليات قديمة بدون حساب','Unassigned historical entries')),
       subtitle:Text(t('لا تُضاف إلى رصيد أي حساب حتى تربطها بنفسك.',
        'Not added to any account balance until you verify the link.')),
       trailing:Text(data.unassignedEntries.toString()))),
      header('الاستحقاقات المحتملة','Upcoming payments'),
      if(widget.upcomingDues.isEmpty)Padding(
       padding:const EdgeInsets.symmetric(horizontal:16),
       child:Text(t('لم تُمرر بيانات استحقاقات مؤكدة لهذا العرض؛ لن نتوقع مبالغ من عندنا.',
        'No verified upcoming schedule supplied; no estimated amounts are invented.'))),
      if(widget.upcomingDues.isNotEmpty)...[
       ListTile(
        title:Text(t('استحقاقات محتمل تكرارها','Potential duplicate schedules')),
        trailing:Text(collisions.length.toString()),
        subtitle:Text(t('تنبيه للمراجعة فقط، مش خصم تلقائي.',
         'Review warning only; no automatic charge.'))),
       for(final c in collisions.take(20))ListTile(
        dense:true,
        leading:const Icon(Icons.warning_amber_outlined),
        title:Text(t('راجع الاستحقاقين','Review two schedule entries')),
        subtitle:Text(c.firstId+' / '+c.secondId)),
      ],
      header('توقع السيولة','Cashflow forecast'),
      Card(margin:const EdgeInsets.symmetric(horizontal:12),child:ListTile(
       leading:const Icon(Icons.timeline_outlined),
       title:Text(t('المتوقع بنهاية الشهر القادم','Forecast through next month')),
       subtitle:Text(t('توقع مستقل عن الرصيد الحقيقي. لا يشمل إلا الاستحقاقات المؤكدة غير المدفوعة.',
        'Separate from real balance. Includes only supplied confirmed, unpaid dues.')),
       trailing:Text(cash(projected.endingMinor),textDirection:TextDirection.ltr),
      )),
      Padding(padding:const EdgeInsets.all(16),
       child:Text(t('لا يثبت هذا الفحص صحة كل كشف بنكي أو ملف باكب. راجع المعاملات مع البنك عند وجود فرق.',
        'This check does not certify external bank statements or backup archives. Review any discrepancy with the bank.'),
        style:Theme.of(context).textTheme.bodySmall)),
     ]));
   }),
 );
}

import 'package:flutter/material.dart';

import 'waffra_haptic_feedback.dart';
import 'waffra_today_picker.dart';
import 'waffra_smart_features.dart';
/// Read-only financial tools; no bank connection or external data access.
class WaffraCalendarItem {
  final DateTime date;
  final String title;
  final double amount;
  final bool income;
  final bool scheduled;
  const WaffraCalendarItem(this.date,this.title,this.amount,this.income,{this.scheduled=false});
}

class WaffraFinancialCalendar extends StatefulWidget {
  final List<WaffraCalendarItem> items;
  final bool english;
  const WaffraFinancialCalendar({super.key,required this.items,required this.english});
  @override
  State<WaffraFinancialCalendar> createState()=>_WaffraFinancialCalendarState();
}

class _WaffraFinancialCalendarState extends State<WaffraFinancialCalendar> {
 DateTime selected=DateTime.now();
 static const green=Color(0xFF087A54),incomeInk=Color(0xFF075C40),expenseInk=Color(0xFFBB4939);
 String date(DateTime d)=>'${d.day}/${d.month}/${d.year}';
 void moveMonth(int step)=>setState((){
  final next=DateTime(selected.year,selected.month+step);
  final maxDay=DateTime(next.year,next.month+1,0).day;
  selected=DateTime(next.year,next.month,selected.day.clamp(1,maxDay));
 });
 Widget total(double amount,bool income,bool dark)=>Expanded(child:Container(
  padding:const EdgeInsets.all(12),
  decoration:BoxDecoration(
   color:dark?(income?const Color(0xFF244C3A):const Color(0xFF49302C)):
    (income?const Color(0xFFB2D5C2):const Color(0xFFFCECE8)),
   borderRadius:BorderRadius.circular(16)),
  child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Row(children:[
    Icon(income?Icons.south_west:Icons.north_east,size:18,color:dark?Colors.white:income?incomeInk:expenseInk),
    const SizedBox(width:6),
    Expanded(child:Text(income?(widget.english?'Income':'الدخل'):
      (widget.english?'Expenses':'المصروفات'),
      style:TextStyle(fontWeight:FontWeight.bold,color:dark?Colors.white:income?incomeInk:expenseInk))),
   ]),
   const SizedBox(height:7),
   FittedBox(fit:BoxFit.scaleDown,child:Text(
    '${amount.toStringAsFixed(2)} ${widget.english?'SAR':'ريال'}',
    textDirection:TextDirection.ltr,
    style:TextStyle(fontWeight:FontWeight.w800,fontSize:18,
      color:dark?Colors.white:income?incomeInk:expenseInk))),
  ]),
 ));
 Widget transactionCard(WaffraCalendarItem item,bool dark){
  final ink=item.income?incomeInk:expenseInk;
  return Container(
   margin:const EdgeInsets.only(bottom:10),
   padding:const EdgeInsets.symmetric(horizontal:12,vertical:14),
   decoration:BoxDecoration(
    color:dark?(item.income?const Color(0xFF244C3A):const Color(0xFF49302C)):
     (item.income?const Color(0xFFB2D5C2):const Color(0xFFFCECE8)),
    borderRadius:BorderRadius.circular(18)),
   child:Row(children:[
    WaffraIllustration(topic:item.scheduled?'subscriptions':
       item.income?'income':'expense',size:40),
    const SizedBox(width:10),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(item.title,maxLines:3,overflow:TextOverflow.ellipsis,
      style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,
       color:dark?Colors.white:const Color(0xFF19221D))),
     const SizedBox(height:5),
     Text(item.scheduled?
       (widget.english?'Scheduled recurring transaction':'عملية متكررة مجدولة'):
       '${date(item.date)} • ${item.date.hour.toString().padLeft(2,'0')}:${item.date.minute.toString().padLeft(2,'0')}',
       style:TextStyle(fontSize:11,color:dark?Colors.white70:const Color(0xFF64736A))),
    ])),
    const SizedBox(width:6),
    ConstrainedBox(constraints:const BoxConstraints(maxWidth:110),
     child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
      FittedBox(fit:BoxFit.scaleDown,child:Text(
       '${item.income?'+':'-'}${item.amount.toStringAsFixed(2)}',
       textDirection:TextDirection.ltr,
       style:TextStyle(fontSize:17,fontWeight:FontWeight.bold,
        color:dark?Colors.white:ink))),
      Text(widget.english?'SAR':'ريال',
       style:TextStyle(fontSize:11,color:dark?Colors.white70:ink)),
     ])),
   ]),
  );
 }
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  final surface=dark?const Color(0xFF1C3429):Colors.white;
  final ink=dark?Colors.white:const Color(0xFF18231D);
  final muted=dark?Colors.white70:const Color(0xFF67746C);
  final first=DateTime(selected.year,selected.month);
  final offset=widget.english?first.weekday%7:(first.weekday+1)%7;
  final daysCount=DateTime(selected.year,selected.month+1,0).day;
  final month=widget.items.where((e)=>e.date.year==selected.year&&e.date.month==selected.month).toList();
  final incomes=month.where((e)=>e.income).toList();
  final expenses=month.where((e)=>!e.income).toList();
  final dayItems=month.where((e)=>e.date.day==selected.day).toList()
   ..sort((a,b)=>a.scheduled!=b.scheduled?(a.scheduled?1:-1):b.date.compareTo(a.date));
  final weekdays=widget.english?
   ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']:
   ['السبت','الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة'];
  return Scaffold(
   appBar:AppBar(title:Text(widget.english?'Financial calendar':'التقويم المالي')),
   body:ListView(padding:const EdgeInsets.fromLTRB(14,16,14,26),children:[
    Container(padding:const EdgeInsets.all(13),
     decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(23),
      border:Border.all(color:green.withValues(alpha:.12))),
     child:Column(children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
       IconButton(tooltip:widget.english?'Previous month':'الشهر السابق',
        icon:Icon(Icons.chevron_left,color:ink),onPressed:WaffraHaptics.tap(()=>moveMonth(-1))),
       Text('${selected.month}/${selected.year}',
        textDirection:TextDirection.ltr,
        style:TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:ink)),
       IconButton(tooltip:widget.english?'Next month':'الشهر التالي',
        icon:Icon(Icons.chevron_right,color:ink),onPressed:WaffraHaptics.tap(()=>moveMonth(1))),
      ]),
      AnimatedSize(duration:const Duration(milliseconds:230),
       curve:Curves.easeOutCubic,
       child:waffraCalendarIsToday(selected)?const SizedBox.shrink():
        Padding(padding:const EdgeInsets.only(top:4,bottom:8),
         child:Align(alignment:AlignmentDirectional.centerEnd,
          child:FilledButton.tonalIcon(
           key:const Key('waffra-financial-calendar-today'),
           onPressed:WaffraHaptics.tap(()=>setState(()=>
            selected=DateUtils.dateOnly(DateTime.now()))),
           icon:const Icon(Icons.today_rounded,size:18),
           label:Text(widget.english?'Today':'اليوم',
             style:const TextStyle(fontFamily:'Tajawal',fontWeight:FontWeight.w700)))))),
      if(month.isNotEmpty)...[
       const SizedBox(height:9),
       Row(children:[
        if(incomes.isNotEmpty)total(incomes.fold<double>(0,(v,e)=>v+e.amount),true,dark),
        if(incomes.isNotEmpty&&expenses.isNotEmpty)const SizedBox(width:10),
        if(expenses.isNotEmpty)total(expenses.fold<double>(0,(v,e)=>v+e.amount),false,dark),
       ]),
      ],
      const SizedBox(height:18),
      Row(children:weekdays.map((d)=>Expanded(child:Center(
       child:FittedBox(fit:BoxFit.scaleDown,child:Text(d,
        style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:muted)))))).toList()),
      const SizedBox(height:8),
      GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
       gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:7,mainAxisSpacing:4,crossAxisSpacing:4,childAspectRatio:1),
       itemCount:offset+daysCount,itemBuilder:(ctx,i){
        if(i<offset)return const SizedBox.shrink();
        final day=i-offset+1,active=selected.day==day;
        final matches=month.where((e)=>e.date.day==day);
        final hasIncome=matches.any((e)=>e.income);
        final hasExpense=matches.any((e)=>!e.income);
        return Semantics(button:true,selected:active,
         label:'${day}/${selected.month}/${selected.year}',
         child:InkWell(
          onTap:WaffraHaptics.tap(()=>setState(()=>selected=DateTime(selected.year,selected.month,day))),
          borderRadius:BorderRadius.circular(12),
          child:Container(
           decoration:BoxDecoration(
            color:active?(dark?const Color(0xFF246D50):const Color(0xFFADF0C9)):null,
            borderRadius:BorderRadius.circular(12)),
           child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Text('$day',style:TextStyle(fontSize:14,
             fontWeight:active?FontWeight.w800:FontWeight.w500,
             color:active?const Color(0xFF06412E):ink)),
            if(hasIncome||hasExpense)...[
             const SizedBox(height:4),
             Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              if(hasIncome)Container(width:5,height:5,
               decoration:const BoxDecoration(color:green,shape:BoxShape.circle)),
              if(hasIncome&&hasExpense)const SizedBox(width:3),
              if(hasExpense)Container(width:5,height:5,
               decoration:const BoxDecoration(color:expenseInk,shape:BoxShape.circle)),
             ]),
            ],
           ]),
          ),
         ));
       }),
     ]),
    ),
    const SizedBox(height:15),
    Container(padding:const EdgeInsets.fromLTRB(13,17,13,14),
     decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(23),
      border:Border.all(color:green.withValues(alpha:.10))),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
       WaffraIllustration(topic:'calendar',size:33),
       const SizedBox(width:7),
       Expanded(child:Text(widget.english?'Transactions on this day':'معاملات هذا اليوم',
        style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:ink))),
       Text(date(selected),textDirection:TextDirection.ltr,
        style:TextStyle(fontWeight:FontWeight.w700,color:ink)),
      ]),
      const SizedBox(height:15),
      if(dayItems.isEmpty)Padding(
       padding:const EdgeInsets.symmetric(vertical:27,horizontal:12),
       child:Column(children:[
        Icon(Icons.receipt_long_outlined,size:43,color:muted),
        const SizedBox(height:10),
        Text(widget.english?'No transactions on this day':'لا توجد معاملات في هذا اليوم',
         textAlign:TextAlign.center,
         style:TextStyle(fontWeight:FontWeight.bold,color:ink)),
        const SizedBox(height:5),
        Text(widget.english?'No income or expenses recorded for this date.':
         'لم يتم تسجيل أي دخل أو مصروفات في هذا التاريخ.',
         textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:muted)),
       ]),
      )else for(final item in dayItems)transactionCard(item,dark),
     ]),
    ),
   ]),
  );
 }
}

class WaffraSubscriptionCandidate {
  final String title;
  final int payments;
  final double estimatedMonthly;
  const WaffraSubscriptionCandidate(this.title,this.payments,this.estimatedMonthly);
}

List<WaffraSubscriptionCandidate> detectWaffraSubscriptions(List<WaffraCalendarItem> items){
  final groups=<String,List<WaffraCalendarItem>>{};
  for(final item in items){
    if(item.income||item.scheduled)continue;
    final key=item.title.trim().toLowerCase().replaceAll(RegExp(r'\s+'),' ');
    if(key.isEmpty)continue;
    groups.putIfAbsent(key,()=>[]).add(item);
  }
  final results=<WaffraSubscriptionCandidate>[];
  for(final group in groups.values){
    final months=group.map((e)=>e.date.year*12+e.date.month).toSet();
    if(months.length<2)continue;
    final avg=group.fold<double>(0,(a,e)=>a+e.amount)/group.length;
    if(avg<=0||group.any((e)=>(e.amount-avg).abs()>avg*.2))continue;
    results.add(WaffraSubscriptionCandidate(group.first.title,group.length,avg));
  }
  return results..sort((a,b)=>b.payments.compareTo(a.payments));
}


class WaffraSubscriptionScreen extends StatefulWidget {
 final List<WaffraCalendarItem> items;
 final bool english;
 final Future<void> Function(WaffraSubscriptionCandidate)? onAddRecurring;
 const WaffraSubscriptionScreen({super.key,required this.items,required this.english,this.onAddRecurring});
 @override State<WaffraSubscriptionScreen> createState()=>_WaffraSubscriptionScreenState();
}

class _WaffraSubscriptionScreenState extends State<WaffraSubscriptionScreen> {
 static const forest=Color(0xFF063E32),green=Color(0xFF087A54);
 final ignored=<String>{};
 String? adding;
 String t(String en,String ar)=>widget.english?en:ar;
 String money(double value)=>value.toStringAsFixed(2)+' '+t('SAR','ريال');

 Widget panel(Widget child,{Color? bg})=>Container(
  width:double.infinity,padding:const EdgeInsets.all(16),
  decoration:BoxDecoration(
   color:bg??Theme.of(context).cardColor,
   borderRadius:BorderRadius.circular(20),
   border:Border.all(color:green.withValues(alpha:.22))),
  child:child);

 Widget section(String name,IconData icon,int count)=>Row(children:[
  Icon(icon,color:green,size:22),const SizedBox(width:8),
  Expanded(child:Text(name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800))),
  CircleAvatar(radius:15,backgroundColor:green.withValues(alpha:.12),
   child:Text(count.toString(),style:const TextStyle(color:green,fontWeight:FontWeight.bold))),
 ]);

 Widget emptyState(String title,String hint)=>panel(Padding(
  padding:const EdgeInsets.symmetric(vertical:20),
  child:Column(children:[
   CircleAvatar(radius:33,backgroundColor:green.withValues(alpha:.12),
    child:const Icon(Icons.manage_search_rounded,color:green,size:38)),
   const SizedBox(height:12),
   Text(title,textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),
   const SizedBox(height:7),
   Text(hint,textAlign:TextAlign.center,style:TextStyle(color:Theme.of(context).hintColor,fontSize:12)),
  ])));

 Widget candidateTile(WaffraSubscriptionCandidate candidate)=>Padding(
  padding:const EdgeInsets.only(bottom:10),
  child:panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   Row(children:[
    CircleAvatar(backgroundColor:green.withValues(alpha:.12),
     child:const Icon(Icons.subscriptions_outlined,color:green)),
    const SizedBox(width:11),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(candidate.title,maxLines:2,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold)),
     Text(candidate.payments.toString()+t(' similar payments',' مدفوعات متشابهة'),
      style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
    ])),
    Text('~'+money(candidate.estimatedMonthly),textDirection:TextDirection.ltr,
     style:const TextStyle(color:green,fontSize:12,fontWeight:FontWeight.w800)),
   ]),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:FilledButton.icon(
     onPressed:WaffraHaptics.tap(widget.onAddRecurring==null||adding!=null?null:()async{
      setState(()=>adding=candidate.title);
      try{await widget.onAddRecurring!(candidate);}
      finally{if(mounted)setState(()=>adding=null);}
     }),
     style:FilledButton.styleFrom(backgroundColor:forest,
      padding:const EdgeInsets.symmetric(vertical:11),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13))),
     icon:const Icon(Icons.add_circle_outline,size:17),
     label:Text(t('Review & add','مراجعة وإضافة'),maxLines:1,
      style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
    )),
    const SizedBox(width:8),
    OutlinedButton(
     onPressed:WaffraHaptics.tap(adding!=null?null:()=>setState(()=>ignored.add(candidate.title))),
     child:Text(t('Ignore','تجاهل'))),
   ]),
  ])),
 );

 Widget registeredTile(WaffraCalendarItem item)=>Padding(
  padding:const EdgeInsets.only(bottom:9),
  child:panel(Row(children:[
   CircleAvatar(backgroundColor:green.withValues(alpha:.10),
    child:const Icon(Icons.event_repeat_rounded,color:green)),
   const SizedBox(width:10),
   Expanded(child:Text(item.title,maxLines:2,overflow:TextOverflow.ellipsis,
    style:const TextStyle(fontWeight:FontWeight.bold))),
   const SizedBox(width:5),
   Text(money(item.amount),textDirection:TextDirection.ltr,
    style:const TextStyle(color:green,fontWeight:FontWeight.w800)),
  ])));

 @override Widget build(BuildContext context){
  final theme=Theme.of(context);
  final known=widget.items.where((item)=>item.scheduled&&!item.income).toList();
  final suggestions=detectWaffraSubscriptions(widget.items).where((candidate)=>
   !ignored.contains(candidate.title)&&
   !known.any((item)=>item.title.trim().toLowerCase()==candidate.title.trim().toLowerCase())).toList();
  final monthly=known.fold<double>(0,(sum,item)=>sum+item.amount);
  return Scaffold(
   backgroundColor:theme.brightness==Brightness.dark?theme.scaffoldBackgroundColor:const Color(0xFFF4FAF6),
   appBar:AppBar(backgroundColor:forest,foregroundColor:Colors.white,centerTitle:true,
    title:Text(t('Subscription insights','كشف الاشتراكات'),
     style:const TextStyle(fontWeight:FontWeight.w800)),
    leading:IconButton(onPressed:WaffraHaptics.tap(()=>Navigator.maybePop(context)),
     tooltip:t('Back','رجوع'),icon:const Icon(Icons.arrow_back_ios_new))),
   body:ListView(padding:const EdgeInsets.fromLTRB(16,18,16,40),children:[
    Container(
     padding:const EdgeInsets.all(21),
     decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[Color(0xFF087858),forest],
       begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd),
      borderRadius:BorderRadius.circular(24)),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
       const Icon(Icons.autorenew_rounded,color:Colors.white),
       const SizedBox(width:8),
       Expanded(child:Text(t('Recorded recurring expenses','المصروفات المتكررة المسجلة'),
        style:const TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.bold))),
      ]),
      const SizedBox(height:14),
      Row(children:[
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t('Monthly','شهريًا'),style:const TextStyle(color:Color(0xFFC5E6D9))),
        Text(money(monthly),textDirection:TextDirection.ltr,
         style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800)),
       ])),
       Container(height:47,width:1,color:Colors.white24),
       const SizedBox(width:12),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(t('Annual estimate','التقدير السنوي'),style:const TextStyle(color:Color(0xFFC5E6D9))),
        Text(money(monthly*12),textDirection:TextDirection.ltr,
         style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w800)),
       ])),
      ]),
      const SizedBox(height:8),
      Text(t('Estimated from currently registered monthly recurring payments',
       'تقدير بناءً على المصروفات المتكررة الشهرية المسجلة'),
       style:const TextStyle(color:Color(0xFFC5E6D9),fontSize:11)),
     ])),
    const SizedBox(height:22),
    section(t('Potential subscriptions','اشتراكات محتملة'),Icons.saved_search_rounded,suggestions.length),
    const SizedBox(height:12),
    if(suggestions.isEmpty)emptyState(
     t('No patterns detected yet','لا توجد اشتراكات محتملة حاليًا'),
     t('Add transactions from different months to identify recurring charges.',
      'أضف معاملات من أشهر مختلفة لاكتشاف المدفوعات المتشابهة.'))
    else ...suggestions.map(candidateTile),
    const SizedBox(height:20),
    section(t('Registered recurring expenses','المصروفات المتكررة المسجلة'),
     Icons.event_repeat_rounded,known.length),
    const SizedBox(height:12),
    if(known.isEmpty)emptyState(
     t('No recurring payments yet','لا توجد مصروفات متكررة مسجلة'),
     t('Review a detected payment to add it as a recurring operation.',
      'راجع الاشتراك المكتشف لإضافته كعملية متكررة.'))
    else ...known.map(registeredTile),
    const SizedBox(height:18),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Row(children:[
      const Icon(Icons.lightbulb_outline,color:green),
      const SizedBox(width:8),
      Text(t('Smart insights','ملاحظات ذكية'),
       style:const TextStyle(fontSize:15,fontWeight:FontWeight.w800)),
     ]),
     const SizedBox(height:8),
     Text(t('Suggestions are estimates based only on transactions stored on this device. Review all details before adding a recurring payment.',
      'الاقتراحات تقديرية وتعتمد على معاملات الجهاز فقط. راجع التفاصيل قبل إضافة عملية متكررة.'),
      style:TextStyle(fontSize:12,color:theme.hintColor)),
    ]),bg:theme.brightness==Brightness.dark?theme.cardColor:const Color(0xFFE8F4ED)),
   ]),
  );
 }
}

import 'package:flutter/material.dart';

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
  @override Widget build(BuildContext context){
    final first=DateTime(selected.year,selected.month);
    final offset=first.weekday%7;
    final count=DateTime(selected.year,selected.month+1,0).day;
    final monthly=widget.items.where((e)=>e.date.year==selected.year&&e.date.month==selected.month);
    final income=monthly.where((e)=>e.income).fold<double>(0,(a,e)=>a+e.amount);
    final expense=monthly.where((e)=>!e.income).fold<double>(0,(a,e)=>a+e.amount);
    final dayItems=monthly.where((e)=>e.date.day==selected.day).toList();
    return Scaffold(appBar:AppBar(title:Text(widget.english?'Financial calendar':'التقويم المالي')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
          IconButton(icon:const Icon(Icons.chevron_left),onPressed:()=>setState(()=>selected=DateTime(selected.year,selected.month-1,1))),
          Text('${selected.month}/${selected.year}',style:Theme.of(context).textTheme.titleLarge),
          IconButton(icon:const Icon(Icons.chevron_right),onPressed:()=>setState(()=>selected=DateTime(selected.year,selected.month+1,1))),
        ]),
        Text(widget.english?'Income: ${income.toStringAsFixed(2)} • Expenses: ${expense.toStringAsFixed(2)}':
          'الدخل: ${income.toStringAsFixed(2)} • المصروفات: ${expense.toStringAsFixed(2)}'),
        const SizedBox(height:14),
        GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
          gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisSpacing:5,crossAxisSpacing:5),
          itemCount:offset+count,itemBuilder:(ctx,i){
            if(i<offset)return const SizedBox.shrink();
            final day=i-offset+1;
            final has=monthly.any((e)=>e.date.day==day);
            return InkWell(onTap:()=>setState(()=>selected=DateTime(selected.year,selected.month,day)),
              child:DecoratedBox(decoration:BoxDecoration(
                color:selected.day==day?Theme.of(context).colorScheme.primaryContainer:null,
                borderRadius:BorderRadius.circular(10)),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  Text(day.toString(),style:TextStyle(fontWeight:has?FontWeight.bold:FontWeight.normal)),
                  if(has)const Icon(Icons.circle,size:5,color:Colors.green),
                ])));
          }),
        const Divider(),
        Text('${selected.day}/${selected.month}/${selected.year}',style:Theme.of(context).textTheme.titleMedium),
        if(dayItems.isEmpty)Padding(padding:const EdgeInsets.all(20),child:Text(widget.english?'No transactions':'لا توجد عمليات')),
        ...dayItems.map((e)=>ListTile(
          leading:Icon(e.scheduled?Icons.repeat:(e.income?Icons.south_west:Icons.north_east)),
          title:Text(e.title),subtitle:e.scheduled?Text(widget.english?'Scheduled':'مجدولة'):null,
          trailing:Text('${e.income?'+':'-'}${e.amount.toStringAsFixed(2)}'))),
      ]));
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
    final key=item.title.trim().toLowerCase().replaceAll(RegExp(r'\\s+'),' ');
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

class WaffraSubscriptionScreen extends StatelessWidget {
  final List<WaffraCalendarItem> items;
  final bool english;
  const WaffraSubscriptionScreen({super.key,required this.items,required this.english});
  @override Widget build(BuildContext context){
    final known=items.where((e)=>e.scheduled&&!e.income).toList();
    final monthly=known.fold<double>(0,(a,e)=>a+e.amount);
    final possible=detectWaffraSubscriptions(items);
    return Scaffold(appBar:AppBar(title:Text(english?'Subscriptions':'كشف الاشتراكات')),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Text(english?'Registered recurring expenses':'المصروفات المتكررة المسجلة',
          style:Theme.of(context).textTheme.titleMedium),
        Text(english?'Monthly: ${monthly.toStringAsFixed(2)} SAR • Yearly: ${(monthly*12).toStringAsFixed(2)} SAR':
          'شهريًا: ${monthly.toStringAsFixed(2)} ريال • سنويًا: ${(monthly*12).toStringAsFixed(2)} ريال'),
        ...known.map((e)=>ListTile(title:Text(e.title),trailing:Text(e.amount.toStringAsFixed(2)))),
        const Divider(),
        Text(english?'Possible subscriptions':'اشتراكات محتملة',
          style:Theme.of(context).textTheme.titleMedium),
        if(possible.isEmpty)Text(english?'Not enough transaction history':'لا توجد بيانات كافية حاليًا'),
        ...possible.map((e)=>ListTile(leading:const Icon(Icons.search),
          title:Text(e.title),
          subtitle:Text(english?'${e.payments} similar payments':'${e.payments} مدفوعات متشابهة'),
          trailing:Text('~${e.estimatedMonthly.toStringAsFixed(2)}')),
        const SizedBox(height:16),
        Text(english?'Suggestions are estimates from local transactions only.':
          'الاقتراحات تقديرية وتعتمد على معاملات الجهاز فقط.'),
      ]));
  }
}

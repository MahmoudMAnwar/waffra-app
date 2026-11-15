import 'package:flutter/material.dart';

import 'waffra_bank_sms_facts.dart';

/// M984/#691: presentation-only aggregation of current encrypted SMS review.
/// Never reads/writes SMS, finance or private app state outside the given rows.
abstract final class WaffraSmsReviewCalendarData {
 static DateTime? localDay(Map<String,Object?> row) {
  final at=row['receivedAt'];
  if(at is! int||at<946684800000||at>DateTime.now()
    .add(const Duration(days:1)).millisecondsSinceEpoch)return null;
  final date=DateTime.fromMillisecondsSinceEpoch(at).toLocal();
  return DateTime(date.year,date.month,date.day);
 }
 static String kind(Map<String,Object?> row) {
  if(row['sourceType']=='recurring'||row['sourceType']=='goal_due'){
   return 'due';
  }
  if(row['sensitiveOtp']==true)return 'uncertain';
  final local=row['local'];
  final guessed=local is Map?local['kind']:null;
  if(guessed=='income'||guessed=='expense'||guessed=='transfer'||
     guessed=='due'||guessed=='recurring')return guessed as String;
  final body=row['body'];
  if(body is! String||body.isEmpty)return 'uncertain';
  final parsed=WaffraBankSmsFactsParser.parse(body);
  if(parsed.pending)return 'uncertain';
  return switch(parsed.kind){
   WaffraBankOperationKind.income=>'income',
   WaffraBankOperationKind.expense=>'expense',
   WaffraBankOperationKind.transfer=>'transfer',
   _=>'uncertain',
  };
 }
 static Map<DateTime,List<String>> countByLocalDay(
   Iterable<Map<String,Object?>> messages,{String? sender}
 ) {
  final result=<DateTime,List<String>>{};
  for(final row in messages){
   if(sender!=null&&row['sender']!=sender)continue;
   final day=localDay(row);
   if(day==null)continue;
   (result[day]??=<String>[]).add(kind(row));
  }
  return result;
 }
 static Color colorForKind(String kind,{bool dark=false})=>switch(kind){
  'income'=>const Color(0xFF087A54),
  'expense'=>Colors.deepOrange,
  'transfer'=>const Color(0xFFD8BA78),
  'due'||'recurring'=>dark?const Color(0xFFD6BBFF):const Color(0xFF7653AA),
  _=>dark?const Color(0xFFB2B7B4):const Color(0xFF88938E),
 };
}

/// Read-only monthly selector; tapping a day returns its date to its owner.
/// Exactly one dot per pending SMS up to a maximum of THREE visible dots.
class WaffraSmsReviewCalendar extends StatefulWidget {
 const WaffraSmsReviewCalendar({
  super.key,required this.messages,required this.onSelected,
  this.onClear,this.selectedDay,this.sender,this.english=false,
 });
 final List<Map<String,Object?>> messages;
 final String? sender;
 final DateTime? selectedDay;
 final bool english;
 final ValueChanged<DateTime> onSelected;
 final VoidCallback? onClear;

 @override
 State<WaffraSmsReviewCalendar> createState()=>_WaffraSmsReviewCalendarState();
}

class _WaffraSmsReviewCalendarState extends State<WaffraSmsReviewCalendar> {
 late DateTime month;
 @override void initState(){
  super.initState();
  final base=widget.selectedDay??DateTime.now();
  month=DateTime(base.year,base.month);
 }
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  final byDay=WaffraSmsReviewCalendarData.countByLocalDay(
   widget.messages,sender:widget.sender);
  final monthStart=DateTime(month.year,month.month,1);
  final firstOffset=monthStart.weekday-1; // Monday=0.
  final monthDays=DateTime(month.year,month.month+1,0).day;
  final now=DateTime.now();
  final canNext=month.year<now.year||
   month.year==now.year&&month.month<now.month;
  final canPrevious=month.year>2000||
   month.year==2000&&month.month>1;
  final totalInMonth=byDay.entries.where((entry)=>
   entry.key.year==month.year&&entry.key.month==month.month)
    .fold<int>(0,(n,entry)=>n+entry.value.length);
  const weekdaysAr=<String>['إ','ث','أ','خ','ج','س','ح'];
  const weekdaysEn=<String>['M','T','W','T','F','S','S'];
  const legendKinds=<String>['income','expense','transfer','due'];
  final labels=widget.english?
   const <String>['Income','Expense','Transfer','Due']:
   const <String>['دخل','مصروف','تحويل','استحقاق'];
  return Padding(padding:const EdgeInsets.all(12),
   child:Column(mainAxisSize:MainAxisSize.min,
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     IconButton(key:const Key('m984-calendar-prev'),
      onPressed:canPrevious?()=>setState(()=>
       month=DateTime(month.year,month.month-1)):null,
      icon:const Icon(Icons.chevron_left_rounded)),
     Expanded(child:Text(
      MaterialLocalizations.of(context).formatMonthYear(month),
      textAlign:TextAlign.center,
      style:Theme.of(context).textTheme.titleMedium)),
     IconButton(key:const Key('m984-calendar-next'),
      onPressed:canNext?()=>setState(()=>
       month=DateTime(month.year,month.month+1)):null,
      icon:const Icon(Icons.chevron_right_rounded)),
    ]),
    Text(widget.english?
     '$totalInMonth messages awaiting review this month':
     '$totalInMonth رسالة في المراجعة خلال الشهر',
     textAlign:TextAlign.center,
     style:Theme.of(context).textTheme.bodySmall),
    const SizedBox(height:10),
    Row(children:[
     for(final label in widget.english?weekdaysEn:weekdaysAr)
      Expanded(child:Center(child:Text(label,
       style:Theme.of(context).textTheme.labelSmall))),
    ]),
    const SizedBox(height:3),
    GridView.builder(
     key:const Key('m984-sms-calendar-grid'),
     shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
     gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount:7,childAspectRatio:1.05,
      mainAxisSpacing:2,crossAxisSpacing:2),
     itemCount:42,
     itemBuilder:(context,index){
      final dayNumber=index-firstOffset+1;
      if(dayNumber<1||dayNumber>monthDays)return const SizedBox.shrink();
      final day=DateTime(month.year,month.month,dayNumber);
      final allKinds=byDay[day]??const <String>[];
      final selected=widget.selectedDay!=null&&
       DateUtils.isSameDay(widget.selectedDay,day);
      return InkWell(
       key:Key('m984-day-${day.year}-${day.month}-${day.day}'),
       borderRadius:BorderRadius.circular(10),
       onTap:()=>widget.onSelected(day),
       child:Container(
        padding:const EdgeInsets.symmetric(vertical:2),
        decoration:BoxDecoration(
         color:selected?Theme.of(context).colorScheme.primaryContainer:null,
         border:selected?Border.all(color:const Color(0xFF087A54)):null,
         borderRadius:BorderRadius.circular(10)),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
         Text('$dayNumber',style:TextStyle(fontSize:13,
          fontWeight:selected?FontWeight.w700:FontWeight.normal)),
         const SizedBox(height:3),
         Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          for(var i=0;i<allKinds.length&&i<3;i++)...[
           if(i>0)const SizedBox(width:2),
           Container(
            key:Key('m984-dot-${day.year}-${day.month}-${day.day}-$i'),
            width:5,height:5,
            decoration:BoxDecoration(shape:BoxShape.circle,
             color:WaffraSmsReviewCalendarData.colorForKind(
              allKinds[i],dark:dark))),
          ],
         ]),
        ]),
       ),
      );
     },
    ),
    const SizedBox(height:10),
    Wrap(spacing:12,runSpacing:6,children:[
     for(var i=0;i<legendKinds.length;i++)
      Row(mainAxisSize:MainAxisSize.min,children:[
       Container(width:8,height:8,decoration:BoxDecoration(
        shape:BoxShape.circle,
        color:WaffraSmsReviewCalendarData.colorForKind(
         legendKinds[i],dark:dark))),
       const SizedBox(width:4),
       Text(labels[i],style:Theme.of(context).textTheme.labelSmall),
      ]),
    ]),
    if(widget.onClear!=null)...[
     const SizedBox(height:10),
     TextButton.icon(
      key:const Key('m984-calendar-show-all'),
      onPressed:widget.onClear,
      icon:const Icon(Icons.filter_alt_off_outlined),
      label:Text(widget.english?'Show all days':'عرض كل الأيام')),
    ],
   ]));
 }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'waffra_haptic_feedback.dart';

/// The same in-dialog calendar arrangement used by Waffra's financial
/// calendar. Today, Cancel and Confirm are all INSIDE one constrained dialog,
/// even on small Android displays; no button is appended below the modal.
Future<DateTime?> waffraPickDateWithToday({
 required BuildContext context,
 required DateTime initialDate,
 required DateTime firstDate,
 required DateTime lastDate,
 bool english=false,
}) => showDialog<DateTime>(
 context:context,
 builder:(dialogContext)=>_WaffraDateDialog(
  english:english,initialDate:DateUtils.dateOnly(initialDate),
  firstDate:DateUtils.dateOnly(firstDate),
  lastDate:DateUtils.dateOnly(lastDate)),
);

class _WaffraDateDialog extends StatefulWidget {
 const _WaffraDateDialog({
  required this.english,required this.initialDate,
  required this.firstDate,required this.lastDate,
 });
 final bool english;
 final DateTime initialDate,firstDate,lastDate;
 @override State<_WaffraDateDialog> createState()=>_WaffraDateDialogState();
}

class _WaffraDateDialogState extends State<_WaffraDateDialog> {
 late DateTime selected;
 final _dateForm=GlobalKey<FormState>();
 bool manual=false;
 @override void initState(){
  super.initState();
  selected=widget.initialDate;
 }
 void confirm(){
  if(manual){
   if(_dateForm.currentState?.validate()!=true)return;
   _dateForm.currentState!.save();
  }
  if(selected.isBefore(widget.firstDate)||selected.isAfter(widget.lastDate))return;
  Navigator.of(context).pop(DateUtils.dateOnly(selected));
 }
 @override Widget build(BuildContext context){
  final today=DateUtils.dateOnly(DateTime.now());
  final allowed=!today.isBefore(widget.firstDate)&&
   !today.isAfter(widget.lastDate);
  final height=math.min(365.0,math.max(230.0,MediaQuery.sizeOf(context).height-235));
  return AlertDialog(
   key:const Key('waffra-datepicker-dialog'),
   insetPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16),
   contentPadding:const EdgeInsets.fromLTRB(8,0,8,0),
   actionsPadding:const EdgeInsets.fromLTRB(12,4,12,12),
   title:Row(children:[
    Expanded(child:Text(widget.english?'Choose date':'اختيار التاريخ',
     style:const TextStyle(fontFamily:'Tajawal',fontWeight:FontWeight.w700))),
    IconButton(
     key:const Key('waffra-datepicker-edit-mode'),
     tooltip:widget.english?'Enter date':'إدخال التاريخ',
     onPressed:WaffraHaptics.tap(()=>setState(()=>manual=!manual)),
     icon:Icon(manual?Icons.calendar_month_outlined:Icons.edit_outlined)),
   ]),
   content:SizedBox(width:350,child:manual?
    Form(key:_dateForm,child:Padding(
     padding:const EdgeInsets.symmetric(vertical:18,horizontal:8),
     child:InputDatePickerFormField(
      key:ValueKey('waffra-datepicker-input-${selected.toIso8601String()}'),
      initialDate:selected,firstDate:widget.firstDate,lastDate:widget.lastDate,
      fieldLabelText:widget.english?'Date':'التاريخ',
      onDateSaved:(d)=>selected=DateUtils.dateOnly(d),
      onDateSubmitted:(d)=>selected=DateUtils.dateOnly(d),
     ))):
    SizedBox(height:height,child:SingleChildScrollView(
     child:SizedBox(height:365,child:CalendarDatePicker(
      initialDate:selected,firstDate:widget.firstDate,lastDate:widget.lastDate,
      onDateChanged:(value)=>setState(()=>selected=DateUtils.dateOnly(value)),
     )))),
   ),
   actions:[
    FilledButton.tonalIcon(
     key:const Key('waffra-datepicker-today'),
     onPressed:allowed?WaffraHaptics.tap(
      ()=>Navigator.of(context).pop(today)):null,
     icon:const Icon(Icons.today_rounded,size:17),
     label:Text(widget.english?'Today':'اليوم',
      style:const TextStyle(fontFamily:'Tajawal',fontWeight:FontWeight.w700))),
    TextButton(
     key:const Key('waffra-datepicker-cancel'),
     onPressed:WaffraHaptics.tap(()=>Navigator.of(context).pop()),
     child:Text(widget.english?'Cancel':'إلغاء')),
    FilledButton(
     key:const Key('waffra-datepicker-confirm'),
     onPressed:WaffraHaptics.tap(confirm),
     child:Text(widget.english?'OK':'حسنًا')),
   ],
  );
 }
}

/// Shared condition for compact financial-calendar Today controls.
bool waffraCalendarIsToday(DateTime selected,{DateTime? now}) =>
 DateUtils.isSameDay(selected,now??DateTime.now());

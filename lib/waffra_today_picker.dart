import 'package:flutter/material.dart';
import 'waffra_haptic_feedback.dart';

/// Optional local Today shortcut for existing Material date pickers.
/// Does not bypass first/last date constraints or alter picker save behavior.
/// The enclosing form is updated only when the caller receives a valid date.
Future<DateTime?> waffraPickDateWithToday({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool english=false,
}) {
  final today=DateUtils.dateOnly(DateTime.now());
  final allowed=!today.isBefore(DateUtils.dateOnly(firstDate))&&
    !today.isAfter(DateUtils.dateOnly(lastDate));
  return showDatePicker(
   context:context,initialDate:initialDate,
   firstDate:firstDate,lastDate:lastDate,
   builder:(dialogContext,child)=>Column(children:[
    Expanded(child:child??const SizedBox.shrink()),
    SafeArea(top:false,child:Material(
      color:Theme.of(dialogContext).colorScheme.surface,
      child:Padding(padding:const EdgeInsets.fromLTRB(20,5,20,12),
       child:Align(alignment:AlignmentDirectional.centerEnd,
        child:Semantics(button:true,
         label:english?'Go to today':'العودة إلى اليوم',
         child:FilledButton.tonalIcon(
          key:const Key('waffra-datepicker-today'),
          onPressed:allowed?WaffraHaptics.tap(
           ()=>Navigator.of(dialogContext).pop(today)):null,
          icon:const Icon(Icons.today_rounded,size:18),
          label:Text(english?'Today':'اليوم',style:
           const TextStyle(fontFamily:'Tajawal',fontWeight:FontWeight.w700))))))),
   ]),
  );
}

/// Shared condition for compact financial-calendar Today controls.
bool waffraCalendarIsToday(DateTime selected,{DateTime? now}) =>
 DateUtils.isSameDay(selected,now??DateTime.now());

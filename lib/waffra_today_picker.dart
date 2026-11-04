import 'package:flutter/material.dart';
import 'waffra_haptic_feedback.dart';

/// Date picker shared by manual and bank transactions, goals and recurrence.
///
/// Like the Financial Calendar, Today sits in the calendar header region,
/// only appears while a different day is selected, and never overlaps the
/// calendar grid or Android system buttons. The selected day is not committed
/// to the calling financial form until the user presses Confirm.
Future<DateTime?> waffraPickDateWithToday({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  bool english=false,
}) {
  final today=DateUtils.dateOnly(DateTime.now());
  final from=DateUtils.dateOnly(firstDate);
  final until=DateUtils.dateOnly(lastDate);
  // Imported/edited historical records can fall outside the date window.
  // Never pass such a value to CalendarDatePicker (it asserts at build time).
  // Only explicit Confirm changes the calling form's selected date.
  final safeInitial=waffraBoundedCalendarInitialDate(initialDate,from,until);
  if(safeInitial==null)return Future<DateTime?>.value(null);
  final allowed=!today.isBefore(from)&&!today.isAfter(until);
  var selected=safeInitial;
  return showDialog<DateTime>(
   context:context,
   builder:(dialogContext)=>StatefulBuilder(
    builder:(ctx,setDialogState){
     return Dialog(
      insetPadding:const EdgeInsets.symmetric(horizontal:16,vertical:20),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
      clipBehavior:Clip.antiAlias,
      child:ConstrainedBox(
       constraints:const BoxConstraints(maxWidth:380),
       child:Padding(
        padding:const EdgeInsets.fromLTRB(10,16,10,12),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
         Padding(padding:const EdgeInsets.symmetric(horizontal:10),
          child:Align(alignment:AlignmentDirectional.centerStart,
           child:Text(english?'Select date':'اختر التاريخ',
            style:Theme.of(ctx).textTheme.titleMedium?.copyWith(
             fontFamily:'Tajawal',fontWeight:FontWeight.w800)))),
         AnimatedSize(
          duration:const Duration(milliseconds:200),
          curve:Curves.easeOutCubic,
          child:waffraCalendarIsToday(selected)?
           const SizedBox(width:double.infinity,height:8):
           Padding(padding:const EdgeInsets.fromLTRB(10,6,10,0),
            child:Align(alignment:AlignmentDirectional.centerEnd,
             child:FilledButton.tonalIcon(
              key:const Key('waffra-datepicker-today'),
              onPressed:allowed?WaffraHaptics.tap(
               ()=>setDialogState(()=>selected=today)):null,
              icon:const Icon(Icons.today_rounded,size:18),
              label:Text(english?'Today':'اليوم',
               style:const TextStyle(fontFamily:'Tajawal',
                fontWeight:FontWeight.w700))))),
         ),
         Flexible(child:SingleChildScrollView(
          child:CalendarDatePicker(
           key:ValueKey('waffra-datepicker-calendar-${selected.toIso8601String()}'),
           initialDate:selected,
           firstDate:from,
           lastDate:until,
           onDateChanged:(day)=>setDialogState(
            ()=>selected=DateUtils.dateOnly(day))),
         )),
         const SizedBox(height:4),
         Padding(padding:const EdgeInsets.symmetric(horizontal:8),
          child:Row(mainAxisAlignment:MainAxisAlignment.end,children:[
           TextButton(
            onPressed:WaffraHaptics.tap(
             ()=>Navigator.of(dialogContext).pop()),
            child:Text(english?'Cancel':'إلغاء')),
           const SizedBox(width:8),
           FilledButton(
            key:const Key('waffra-datepicker-confirm'),
            onPressed:WaffraHaptics.tap(
             ()=>Navigator.of(dialogContext).pop(selected)),
            child:Text(english?'Confirm':'تأكيد')),
          ])),
        ]),
       ),
      ),
     );
    }),
  );
}

/// Shared condition for compact financial-calendar Today controls.
bool waffraCalendarIsToday(DateTime selected,{DateTime? now}) =>
 DateUtils.isSameDay(selected,now??DateTime.now());

/// Fail closed for invalid ranges; clamp historical initial selections solely
/// for picker display. Cancelling still returns null and never edits finance.
DateTime? waffraBoundedCalendarInitialDate(
 DateTime initialDate,DateTime firstDate,DateTime lastDate) {
 final from=DateUtils.dateOnly(firstDate);
 final until=DateUtils.dateOnly(lastDate);
 if(from.isAfter(until))return null;
 final initial=DateUtils.dateOnly(initialDate);
 if(initial.isBefore(from))return from;
 if(initial.isAfter(until))return until;
 return initial;
}

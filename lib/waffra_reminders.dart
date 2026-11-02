import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;

/// Notifications are opt-in. No bank accounts or financial credentials are used.
class WaffraReminder {
 final String id,title;
 final int day;
 /// A linked goal may not start its monthly reminders before this date.
 final DateTime? startAt;
 const WaffraReminder({required this.id,required this.title,required this.day,this.startAt});
}

class WaffraReminders {
 WaffraReminders._();
 static final FlutterLocalNotificationsPlugin _plugin=FlutterLocalNotificationsPlugin();
 static bool _initialized=false;
 static String? _lastTimeZone;
 static const _budgetDetails=NotificationDetails(android:AndroidNotificationDetails(
  'waffra_budget_threshold_v1','Waffra budget alerts',
  channelDescription:'Optional alerts for confirmed budget thresholds',
  importance:Importance.defaultImportance,priority:Priority.defaultPriority));
 static Future<void> showBudgetAlert({
  required String id,required String month,required int stage,
  required String detail,bool english=false,
 })async{
  if(!Platform.isAndroid)return;
  await initialize();
  if(!await alreadyPermitted())return;
  await _plugin.show(stableId('budget:$id:$month:$stage',0),
   english?'Waffra • Budget alert':'وفرة • تنبيه ميزانية',
   detail,_budgetDetails);
 }
 static const _goalDetails=NotificationDetails(android:AndroidNotificationDetails(
  'waffra_goal_progress_v1','Waffra savings progress',
  channelDescription:'Optional progress alerts after confirmed goal contributions',
  importance:Importance.defaultImportance,priority:Priority.defaultPriority));
 static Future<void> showGoalProgressAlert({
  required String id,required double target,required int stage,
  required String detail,bool english=false,
 })async{
  if(!Platform.isAndroid||target<=0)return;
  await initialize();
  if(!await alreadyPermitted())return;
  await _plugin.show(stableId('goal:$id:$target:$stage',0),
   english?'Waffra • Goal progress':'وفرة • تقدم الهدف',
   detail,_goalDetails);
 }
 static const _details=NotificationDetails(android:AndroidNotificationDetails(
  'waffra_recurring_due_v1','Waffra recurring reminders',
  channelDescription:'Optional reminders before upcoming recurring obligations',
  importance:Importance.defaultImportance,priority:Priority.defaultPriority));

 static Future<void> _useDeviceTimeZone()async {
  tz_data.initializeTimeZones();
  final detected=await FlutterTimezone.getLocalTimezone();
  final identifier=detected.identifier;
  if(identifier.isEmpty)throw StateError('Device timezone not available.');
  // Africa/Cairo observes Egyptian DST; never force Asia/Riyadh globally.
  final location=tz.getLocation(identifier);
  tz.setLocalLocation(location);
  _lastTimeZone=identifier;
 }
 static Future<void> initialize()async {
  if(!Platform.isAndroid)return;
  await _useDeviceTimeZone();
  if(_initialized)return;
  await _plugin.initialize(const InitializationSettings(
   android:AndroidInitializationSettings('@mipmap/ic_launcher')));
  _initialized=true;
 }

 static Future<bool> requestPermission()async {
  if(!Platform.isAndroid)return false;
  await initialize();
  return await _plugin.resolvePlatformSpecificImplementation<
   AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission()??false;
 }
 static Future<bool> alreadyPermitted()async{
  if(!Platform.isAndroid)return false;
  await initialize();
  return await _plugin.resolvePlatformSpecificImplementation<
   AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled()??false;
 }

 static int stableId(String id,int monthOffset){
  var hash=0;
  for(final code in id.codeUnits)hash=(hash*31+code)&0x1fffffff;
  return (hash*3+monthOffset)&0x7fffffff;
 }

 static DateTime dueDate(DateTime monthStart,int day){
  final last=DateTime(monthStart.year,monthStart.month+1,0).day;
  return DateTime(monthStart.year,monthStart.month,day.clamp(1,last));
 }

 static Future<void> schedule(List<WaffraReminder> items,{bool english=false})async {
  if(!Platform.isAndroid)return;
  await initialize();
  await _plugin.cancelAll();
  final now=DateTime.now();
  for(final item in items){
   var scheduled=0;
   for(var offset=0;offset<18&&scheduled<3;offset++){
    final month=DateTime(now.year,now.month+offset,1);
    final due=dueDate(month,item.day);
    if(item.startAt!=null&&due.isBefore(DateTime(
      item.startAt!.year,item.startAt!.month,item.startAt!.day)))continue;
    final remindAt=DateTime(due.year,due.month,due.day-1,9);
    if(!remindAt.isAfter(now.add(const Duration(minutes:2))))continue;
    await _plugin.zonedSchedule(
     stableId(item.id,offset),
     english?'Waffra • Upcoming payment':'وفرة • تذكير بالتزام قادم',
     english?'Upcoming: ${item.title} on ${due.day}/${due.month}':
      'اقترب موعد «${item.title}» بتاريخ ${due.day}/${due.month}',
     tz.TZDateTime.from(remindAt,tz.local),_details,
     androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle);
    scheduled++;
   }
  }
 }

 static Future<void> clear()async{
  if(!Platform.isAndroid)return;
  await initialize();
  await _plugin.cancelAll();
 }
}

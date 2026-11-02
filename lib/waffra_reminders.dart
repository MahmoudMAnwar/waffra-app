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

 /// Dispatched only after a verified user-confirmed expense. This is a
 /// local Android notification, not background bank monitoring/remote push.
 /// Lock-screen preview contains no financial values or budget names.
 static Future<void> showBudgetThreshold({
  required String budgetId,required int stage,bool english=false,
 })async{
  if(!Platform.isAndroid||stage<1||stage>100)return;
  if(!await alreadyPermitted())return;
  final now=DateTime.now();
  final token='budget-alert:$budgetId:${now.year}-${now.month}:$stage';
  const details=NotificationDetails(android:AndroidNotificationDetails(
   'waffra_budget_usage_v1','Waffra budget alerts',
   channelDescription:'Optional budget percentage notifications',
   importance:Importance.defaultImportance,
   priority:Priority.defaultPriority));
  await _plugin.show(stableId(token,0),
   english?'Waffra • Budget alert':'وفرة • تنبيه الميزانية',
   english?'Your spending reached your alert threshold. Open Waffra to review.':
    'وصلت لنسبة التنبيه المحددة. افتح وفرة لمراجعة الميزانية.',
   details);
 }

 static Future<void> showGoalProgress({
  required String goalId,required int stage,bool english=false,
 })async{
  if(!Platform.isAndroid||stage<1||stage>100)return;
  if(!await alreadyPermitted())return;
  final now=DateTime.now();
  final token='goal-progress:$goalId:$stage';
  const details=NotificationDetails(android:AndroidNotificationDetails(
   'waffra_savings_progress_v1','Waffra savings progress',
   channelDescription:'Optional goal progress percentage alerts',
   importance:Importance.defaultImportance,
   priority:Priority.defaultPriority));
  await _plugin.show(stableId(token,0),
   english?'Waffra • Savings progress':'وفرة • تقدّم الادخار',
   english?'Your savings reached your chosen percentage. Open Waffra to review.':
    'وصلت مدخراتك لنسبة التنبيه المحددة. افتح وفرة للمراجعة.',
   details);
 }

 static Future<void> clear()async{
  if(!Platform.isAndroid)return;
  await initialize();
  await _plugin.cancelAll();
 }
}

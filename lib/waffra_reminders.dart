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
 /// A goal-linked due must remind only once, not every month.
 final DateTime? oneTimeDueAt;
 const WaffraReminder({required this.id,required this.title,required this.day,
  this.startAt,this.oneTimeDueAt});
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

 static const _payload='waffra_recurring_due_v1:';
 static bool isManagedRecurringRequest({String? payload,String? title})=>
  (payload?.startsWith(_payload)??false)||
  title=='وفرة • تذكير بالتزام قادم'||
  title=='Waffra • Upcoming payment';

 /// Delete only our recurring schedules, never bank SMS review notices.
 static Future<void> _cancelRecurringOnly()async {
  final pending=await _plugin.pendingNotificationRequests();
  for(final request in pending){
   if(isManagedRecurringRequest(payload:request.payload,title:request.title)){
    await _plugin.cancel(request.id);
   }
  }
 }

 /// Pure calendar function: a goal due gets exactly one notification.
 static List<DateTime> upcomingDueDates(WaffraReminder item,DateTime now){
  bool future(DateTime due)=>DateTime(due.year,due.month,due.day-1,9)
   .isAfter(now.add(const Duration(minutes:2)));
  if(item.oneTimeDueAt!=null){
   final once=item.oneTimeDueAt!;
   final due=DateTime(once.year,once.month,once.day);
   return future(due)?<DateTime>[due]:<DateTime>[];
  }
  final dueDates=<DateTime>[];
  for(var offset=0;offset<18&&dueDates.length<3;offset++){
   final month=DateTime(now.year,now.month+offset,1);
   final due=dueDate(month,item.day);
   if(item.startAt!=null&&due.isBefore(DateTime(
    item.startAt!.year,item.startAt!.month,item.startAt!.day)))continue;
   if(future(due))dueDates.add(due);
  }
  return dueDates;
 }

 static Future<void> schedule(List<WaffraReminder> items,{bool english=false})async {
  if(!Platform.isAndroid)return;
  await initialize();
  await _cancelRecurringOnly();
  final now=DateTime.now();
  for(final item in items){
   for(final due in upcomingDueDates(item,now)){
    final remindAt=DateTime(due.year,due.month,due.day-1,9);
    await _plugin.zonedSchedule(
     stableId(item.id,due.year*12+due.month),
     english?'Waffra • Upcoming payment':'وفرة • تذكير بالتزام قادم',
     english?'Upcoming: ${item.title} on ${due.day}/${due.month}':
      'اقترب موعد «${item.title}» بتاريخ ${due.day}/${due.month}',
     tz.TZDateTime.from(remindAt,tz.local),_details,
     payload:'${_payload}${item.id}',
     androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle);
   }
  }
 }

 static Future<void> clear()async{
  if(!Platform.isAndroid)return;
  await initialize();
  await _cancelRecurringOnly();
 }
}

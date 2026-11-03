import 'dart:io';
import 'package:flutter/services.dart';

/// Bridge between the native permission+encrypted queue and the existing
/// atomic Waffra bank-SMS journal. Never sends messages to the network.
abstract final class WaffraAutoSms {
 static const MethodChannel channel=MethodChannel('waffra/messages');
 static const String firstRunKey='waffra_auto_sms_first_run_consent_v1';

 static Future<bool> _boolCall(String action,[Object? input])async{
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>(action,input)??false;}
  on MissingPluginException{return false;}
  on PlatformException{return false;}
 }
 static Future<bool> enabled()=>_boolCall('autoSmsEnabled');
 static Future<bool> permissionGranted()=>_boolCall('autoSmsPermissionState');
 static Future<bool> notificationPermission()=>_boolCall('autoSmsNotificationsEnabled');
 static Future<bool> requestNotificationPermission()=>_boolCall('requestAutoSmsNotifications');

 static Future<bool> optIn()async{
  if(!await _boolCall('requestAutoSmsPermission'))return false;
  if(!await _boolCall('setAutoSmsEnabled',true))return false;
  // An Android 13+ user may decline notifications; financial capture remains
  // enabled but no system notification can be shown until consent is granted.
  await requestNotificationPermission();
  // Activation-month history is staged only after profile startup.
  // Financial posting and cloud analysis require explicit review.
  return true;
 }

 static Future<bool> disable()=>_boolCall('setAutoSmsEnabled',false);

 /// Resumable batch from first day of month when permission was first granted.
 static Future<int> importConsentMonth()async{
  if(!Platform.isAndroid)return 0;
  try{return await channel.invokeMethod<int>('importConsentMonthBankSms')??0;}
  on MissingPluginException{return 0;}
  on PlatformException{return 0;}
 }

 static Future<List<Map<String,Object?>>> pending()async{
  if(!Platform.isAndroid)return const [];
  try{
   final data=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms')??[];
   return data.whereType<Map>().map((m)=>Map<String,Object?>.from(m)).toList();
  }on MissingPluginException{return const [];}
   on PlatformException{return const [];}
 }
 static Future<bool> claimCloudAttempt(String id)async{
  if(!RegExp(r'^[a-f0-9]{64}  String id,Map<String,Object?> suggestion)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return false;
  return _boolCall('stageAutoBankSmsCloudAnalysis',
   <String,Object?>{'id':id,'analysis':suggestion});
 }
 static Future<bool> acknowledge(List<String> ids)async{
  if(ids.isEmpty||ids.length>100)return false;
  return _boolCall('ackAutoBankSms',ids);
 }
 static Future<bool> notifyCommitted({
  required String hash,required double amount,required bool income,
  required bool linkedBudget,
 })async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)||!amount.isFinite||amount<=0)
   return false;
  return _boolCall('notifyAutoSmsSaved',{
   'hash':hash,'amount':amount.toStringAsFixed(2),
   'income':income,'linkedBudget':linkedBudget,
  });
 }
 static Future<bool> notifyReview(String hash)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))return false;
  return _boolCall('notifyAutoSmsNeedsReview',hash);
 }
}
).hasMatch(id))return false;
  return _boolCall('claimAutoBankSmsCloudAttempt',id);
 }

 static Future<bool> stageCloudAnalysis(
  String id,Map<String,Object?> suggestion)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return false;
  return _boolCall('stageAutoBankSmsCloudAnalysis',
   <String,Object?>{'id':id,'analysis':suggestion});
 }
 static Future<bool> acknowledge(List<String> ids)async{
  if(ids.isEmpty||ids.length>100)return false;
  return _boolCall('ackAutoBankSms',ids);
 }
 static Future<bool> notifyCommitted({
  required String hash,required double amount,required bool income,
  required bool linkedBudget,
 })async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)||!amount.isFinite||amount<=0)
   return false;
  return _boolCall('notifyAutoSmsSaved',{
   'hash':hash,'amount':amount.toStringAsFixed(2),
   'income':income,'linkedBudget':linkedBudget,
  });
 }
 static Future<bool> notifyReview(String hash)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash))return false;
  return _boolCall('notifyAutoSmsNeedsReview',hash);
 }
}

import 'dart:io';
import 'package:flutter/services.dart';

/// Explicit opt-in Android bank-SMS bridge. No network calls.
abstract final class WaffraAutoSms {
 static const MethodChannel channel=MethodChannel('waffra/messages');
 static const firstRunKey='waffra_auto_sms_first_run_consent_v1';
 static Future<bool> permissionGranted()async {
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('autoSmsPermissionState')??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> optIn()async {
  if(!Platform.isAndroid)return false;
  try{
   final granted=await channel.invokeMethod<bool>('requestAutoSmsPermission')??false;
   if(!granted)return false;
   final enabled=await channel.invokeMethod<bool>('setAutoSmsEnabled',true)??false;
   if(enabled){
    await requestNotificationPermission();
    await channel.invokeMethod<int>('importRecentBankSms');
   }
   return enabled;
  }on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> notificationPermission()async{
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('autoSmsNotificationsEnabled')??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> requestNotificationPermission()async{
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('requestAutoSmsNotifications')??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> notifyCommitted({
  required String hash,required double amount,required bool income,
  required bool linkedBudget,
 })async{
  if(!Platform.isAndroid||!RegExp(r'^[a-f0-9]{64}
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('setAutoSmsEnabled',false)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<List<Map<String,Object?>>> pending()async{
  if(!Platform.isAndroid)return [];
  try{
   final rows=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms')??[];
   return rows.whereType<Map>().map((m)=>Map<String,Object?>.from(m)).toList();
  }on PlatformException{return [];}on MissingPluginException{return [];}
 }
 static Future<bool> acknowledge(List<String> ids)async{
  if(!Platform.isAndroid||ids.isEmpty)return false;
  try{return await channel.invokeMethod<bool>('ackAutoBankSms',ids)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
}
).hasMatch(hash)||
     !amount.isFinite||amount<=0)return false;
  try{
   return await channel.invokeMethod<bool>('notifyAutoSmsSaved',{
    'hash':hash,'amount':amount.toStringAsFixed(2),
    'income':income,'linkedBudget':linkedBudget,
   })??false;
  }on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> notifyReview(String hash)async{
  if(!Platform.isAndroid||!RegExp(r'^[a-f0-9]{64}
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('setAutoSmsEnabled',false)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<List<Map<String,Object?>>> pending()async{
  if(!Platform.isAndroid)return [];
  try{
   final rows=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms')??[];
   return rows.whereType<Map>().map((m)=>Map<String,Object?>.from(m)).toList();
  }on PlatformException{return [];}on MissingPluginException{return [];}
 }
 static Future<bool> acknowledge(List<String> ids)async{
  if(!Platform.isAndroid||ids.isEmpty)return false;
  try{return await channel.invokeMethod<bool>('ackAutoBankSms',ids)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
}
).hasMatch(hash))return false;
  try{return await channel.invokeMethod<bool>('notifyAutoSmsNeedsReview',hash)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<bool> disable()async{
  if(!Platform.isAndroid)return false;
  try{return await channel.invokeMethod<bool>('setAutoSmsEnabled',false)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
 static Future<List<Map<String,Object?>>> pending()async{
  if(!Platform.isAndroid)return [];
  try{
   final rows=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms')??[];
   return rows.whereType<Map>().map((m)=>Map<String,Object?>.from(m)).toList();
  }on PlatformException{return [];}on MissingPluginException{return [];}
 }
 static Future<bool> acknowledge(List<String> ids)async{
  if(!Platform.isAndroid||ids.isEmpty)return false;
  try{return await channel.invokeMethod<bool>('ackAutoBankSms',ids)??false;}
  on PlatformException{return false;}on MissingPluginException{return false;}
 }
}

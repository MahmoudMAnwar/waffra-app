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
 // Never confuse OS SMS permission with Waffra's active, account-bound
 // consent. A missing native channel is unknown, NOT an empty inbox.
 static Future<Map<String,bool>?> trackingStatus()async{
  if(!Platform.isAndroid)return null;
  try{
   final value=await channel.invokeMapMethod<String,dynamic>(
    'autoSmsTrackingStatus');
   if(value==null)return null;
   return value.map((key,item)=>MapEntry(key,item==true));
  }on MissingPluginException{return null;}
   on PlatformException{return null;}
 }
 // Logout preserves standing consent for the SAME verified account, but
 // suspends collection and clears encrypted pending SMS until sign-in.
 static Future<Map<String,Object?>?> scanProgress()async{
  if(!Platform.isAndroid)return null;
  try{
   final data=await channel.invokeMapMethod<String,dynamic>(
    'autoSmsScanProgress');
   return data==null?null:Map<String,Object?>.from(data);
  }on MissingPluginException{return null;}
   on PlatformException{return null;}
 }
 // Unlike the legacy importer, this one exposes native failures to the
 // explicit Rescan UI; it never reports an I/O error as an empty inbox.
 // Legacy compatibility hook is non-destructive. Normal Rescan NEVER
 // invokes it: new-only and unfinished first-history scans keep their cursor.
 @Deprecated('History rescans resume the persisted cursor without restart.')
 static Future<bool> restartCompletedHistory()=>
  _boolCall('restartCompletedSmsHistory');

 static Future<int> importConsentMonthChecked()async{
  if(!Platform.isAndroid)throw StateError('Android SMS scan is unavailable.');
  return await channel.invokeMethod<int>('importConsentMonthBankSms')??0;
 }
 static Future<bool> suspendForSignOut()=>_boolCall('pauseAutoSmsForSignOut');
 static Future<bool> resumeAfterSignIn()=>_boolCall('resumeAutoSmsAfterSignIn');
 static Future<bool> notificationPermission()=>_boolCall('autoSmsNotificationsEnabled');
 static Future<bool> requestNotificationPermission()=>_boolCall('requestAutoSmsNotifications');

 static Future<bool> optIn()async{
  if(!await _boolCall('requestAutoSmsPermission'))return false;
  if(!await _boolCall('setAutoSmsEnabled',true))return false;
  // An Android 13+ user may decline notifications; financial capture remains
  // enabled but no system notification can be shown until consent is granted.
  await requestNotificationPermission();
  // Activation-month history is staged only after profile startup.
  // Cloud suggestions require separate opt-in. Posting always needs review.
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

 // Unlike pending(), this method distinguishes an empty inbox from a
 // native/permission failure; the dashboard must not show false zero.
 static Future<List<Map<String,Object?>>?> pendingChecked()async{
  if(!Platform.isAndroid)return null;
  try{
   final data=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms');
   if(data==null)return null;
   return data.whereType<Map>().map(
    (m)=>Map<String,Object?>.from(m)).toList(growable:false);
  }on MissingPluginException{return null;}
   on PlatformException{return null;}
 }
 static Future<List<Map<String,Object?>>> pending()async{
  if(!Platform.isAndroid)return const [];
  try{
   final data=await channel.invokeMethod<List<dynamic>>('pendingAutoBankSms')??[];
   return data.whereType<Map>().map((m)=>Map<String,Object?>.from(m)).toList();
  }on MissingPluginException{return const [];}
   on PlatformException{return const [];}
 }
 /// Read-only, on-demand scan for institutional financial notices that
 /// were not recognized as completed transactions. Never posts or uploads SMS.
 static Future<List<Map<String,Object?>>> scanUnknownFinancialSms()async{
  if(!Platform.isAndroid||!await enabled())return const [];
  try{
   final data=await channel.invokeMethod<List<dynamic>>(
    'scanUnknownFinancialSms')??[];
   return data.whereType<Map>().map(
    (item)=>Map<String,Object?>.from(item)).toList(growable:false);
  }on MissingPluginException{return const [];}
   on PlatformException{return const [];}
 }

 static Future<bool> claimCloudAttempt(String id)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return false;
  return _boolCall('claimAutoBankSmsCloudAttempt',id);
 }

 static Future<bool> stageCloudAnalysis(
  String id,Map<String,Object?> suggestion)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return false;
  return _boolCall('stageAutoBankSmsCloudAnalysis',
   <String,Object?>{'id':id,'analysis':suggestion});
 }
 // Exclusions are stored as encrypted, owner-scoped native SMS policy.
 // A missing native channel is UNKNOWN, not an empty list.
 static Future<List<String>?> excludedSenders()async{
  if(!Platform.isAndroid)return null;
  try{
   final values=await channel.invokeListMethod<String>('excludedAutoSmsSenders');
   return values==null?null:List<String>.unmodifiable(values);
  }on MissingPluginException{return null;}
   on PlatformException{return null;}
 }
 /// Individually excluded SMS are encrypted natively, scoped to the owner.
 /// Only opaque identity, sender label and receipt time cross this boundary.
 /// A missing plugin or malformed payload is UNKNOWN, not an empty policy.
 static Future<List<Map<String,Object?>>?> excludedMessages()async{
  if(!Platform.isAndroid)return null;
  try{
   final items=await channel.invokeListMethod<dynamic>(
    'excludedAutoSmsMessages');
   if(items==null)return null;
   return items.map((item){
    if(item is! Map)throw const FormatException('Invalid excluded SMS item');
    final id=item['id'],sender=item['sender'],receivedAt=item['receivedAt'];
    if(id is! String||
       !RegExp(r'^[a-f0-9]{64}$').hasMatch(id)||
       sender is! String||
       receivedAt is! int||receivedAt<0){
     throw const FormatException('Invalid excluded SMS metadata');
    }
    return Map<String,Object?>.unmodifiable({
     'id':id,'sender':sender,'receivedAt':receivedAt,
    });
   }).toList(growable:false);
  }catch(_){return null;}
 }
 static Future<bool> restoreExcludedMessage(String id)async{
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return false;
  return _boolCall('restoreExcludedAutoSmsMessage',id);
 }
 static Future<bool> excludeSender(String sender)async{
  if(sender.trim().isEmpty)return false;
  return _boolCall('excludeAutoSmsSender',sender.trim());
 }
 /// Atomic native sender exclusion for a large selected review group.
 static Future<bool> excludeSenders(List<String> senders)async{
  if(senders.isEmpty||senders.length>1000||
     senders.any((name)=>name.trim().isEmpty||name.trim().length>100)){
   return false;
  }
  return _boolCall('excludeAutoSmsSenders',senders);
 }
 static Future<bool> restoreExcludedSender(String sender)async{
  if(sender.trim().isEmpty)return false;
  return _boolCall('restoreExcludedAutoSmsSender',sender.trim());
 }
 // Only after verified financial hash is present in SQLCipher.
 static Future<bool> acknowledgeCommitted(List<String> ids)async{
  if(ids.isEmpty||ids.length>100||
     ids.any((id)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)))return false;
  return _boolCall('ackCommittedAutoBankSms',ids);
 }

 /// M514: an SMS explicitly excluded by the user must never be booked as
 /// a completed income/expense. Native exclusion policy is independent.
 static Future<bool> excludeMessages(List<String> ids)async{
  if(ids.isEmpty||ids.length>100||
     ids.any((id)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)))return false;
  return _boolCall('excludeAutoBankSms',ids);
 }
 /// M516: the immutable native fingerprint contains sender, body and time.
 /// It differs from historical body-only financial entry hashes.
 static String transferIdForMessage(String fingerprint){
  if(!RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)){
   throw ArgumentError.value(fingerprint,'fingerprint','Invalid SMS identity');
  }
  return 'sms-transfer-$fingerprint';
 }
 /// Durable completed-transfer ACK; only call after verified SQLCipher save.
 static Future<bool> acknowledgeCompletedTransfer(List<String> ids)async{
  if(ids.isEmpty||ids.length>100||
     ids.any((id)=>!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)))return false;
  return _boolCall('ackCompletedTransferAutoBankSms',ids);
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

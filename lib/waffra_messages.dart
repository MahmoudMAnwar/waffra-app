import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _messageChannel=MethodChannel('waffra/messages');

/// Only holds text the user chose to share. Never reads the inbox.
final ValueNotifier<String?> waffraIncomingSms=ValueNotifier<String?>(null);

/// Native receiver reports *availability*, never raw data, over this event.
final ValueNotifier<int> waffraAutoSmsUpdates=ValueNotifier<int>(0);

// M621: Android supplies only opaque source identity and an optional committed
// ledger ID. The verified Home still checks every pending or saved record.
class WaffraFinanceNotificationTarget {
 final String destination;
 final String id;
 final String? entryId;
 const WaffraFinanceNotificationTarget({
  required this.destination,required this.id,this.entryId,
 });
 static WaffraFinanceNotificationTarget? parse(Object? value){
  if(value is! Map)return null;
  final kind=value['destination'],id=value['id'],entry=value['entryId'];
  if((kind!='review'&&kind!='saved')||
     id is! String||!RegExp(r'^[a-f0-9]{64}$').hasMatch(id))return null;
  if(kind=='saved'&&(entry is! String||entry.isEmpty||
     entry.length>200||entry.runes.any((code)=>code<32)))return null;
  return WaffraFinanceNotificationTarget(
   destination:kind as String,id:id,
   entryId:kind=='saved'?entry as String:null);
 }
}
final ValueNotifier<WaffraFinanceNotificationTarget?> waffraFinanceNoticeTap=
 ValueNotifier<WaffraFinanceNotificationTarget?>(null);
void _receiveWaffraFinanceNotice(Object? value){
 final target=WaffraFinanceNotificationTarget.parse(value);
 if(target!=null)waffraFinanceNoticeTap.value=target;
}

Future<void> initializeWaffraMessages()async{
 if(!Platform.isAndroid)return;
 _messageChannel.setMethodCallHandler((call)async{
  if(call.method=='autoSmsAvailable'){
   waffraAutoSmsUpdates.value++;
  }
  if(call.method=='financeNotificationTap'){
   _receiveWaffraFinanceNotice(call.arguments);
  }
  if(call.method=='sharedText'){
   final value=call.arguments;
   if(value is String&&value.trim().isNotEmpty){
    waffraIncomingSms.value=value.trim();
   }
  }
 });
 try{
  final initial=await _messageChannel.invokeMethod<String>('takeSharedText');
  if(initial!=null&&initial.trim().isNotEmpty){
   waffraIncomingSms.value=initial.trim();
  }
 }on MissingPluginException{
  // Tests and unsupported Android embeddings have no native bridge.
 }on PlatformException catch(error){
  debugPrint('Share-intent initialization failed: ${error.code}');
 }
 try{
  final initial=await _messageChannel.invokeMethod<Object?>(
   'takeFinanceNotificationTap');
  _receiveWaffraFinanceNotice(initial);
 }on MissingPluginException{
  // Widget tests and unsupported embeddings do not have this bridge.
 }on PlatformException catch(error){
  debugPrint('Notification startup failed: ${error.code}');
 }
}

/// Launch the handset's default SMS app; the user must select/copy the text.
Future<bool> openWaffraMessagesApp()async{
 if(!Platform.isAndroid)return false;
 try{
  return (await _messageChannel.invokeMethod<bool>('openMessages'))??false;
 }on MissingPluginException{
  return false;
 }on PlatformException catch(error){
  debugPrint('Could not open messages: ${error.code}');
  return false;
 }
}

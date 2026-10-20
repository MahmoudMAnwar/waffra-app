import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _messageChannel=MethodChannel('waffra/messages');

/// Only holds text the user chose to share. Never reads the inbox.
final ValueNotifier<String?> waffraIncomingSms=ValueNotifier<String?>(null);

Future<void> initializeWaffraMessages()async{
 if(!Platform.isAndroid)return;
 _messageChannel.setMethodCallHandler((call)async{
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

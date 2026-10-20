import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _widgetChannel=MethodChannel('waffra/widget');
final ValueNotifier<String?> waffraWidgetAction=ValueNotifier<String?>(null);

Future<void> initializeWaffraHomeWidget()async{
 if(!Platform.isAndroid)return;
 _widgetChannel.setMethodCallHandler((call)async{
  if(call.method=='quickAdd')waffraWidgetAction.value='add';
 });
 try{
  final action=await _widgetChannel.invokeMethod<String>('takeWidgetAction');
  if(action=='add')waffraWidgetAction.value='add';
 }on MissingPluginException{
 }on PlatformException catch(error){
  debugPrint('Widget initialization: ${error.code}');
 }
}

Future<void> refreshWaffraHomeWidget({
 required String balance,required String monthExpenses,
})async{
 if(!Platform.isAndroid)return;
 try{
  await _widgetChannel.invokeMethod<void>('updateSummary',{
   'balance':balance,'expenses':monthExpenses,
  });
 }on MissingPluginException{
 }on PlatformException catch(error){
  debugPrint('Widget summary failed: ${error.code}');
 }
}

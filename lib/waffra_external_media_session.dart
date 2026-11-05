import 'package:flutter/widgets.dart';

/// Only a live user-launched native picker can suspend immediate relock.
/// A device lock, app detach, expired picker or normal background still locks.
abstract final class WaffraExternalMediaSession {
 static DateTime? _started;
 static int _count=0;
 static DateTime? _lastFinishedAt;
 static const maxLifetime=Duration(minutes:5);
 static const resumeGrace=Duration(seconds:3);

 /// Avoid a second full Home/widget/SMS reload after returning from a picker.
 /// This does not affect biometric locking on a genuine background event.
 static bool get shouldSkipResumeBackgroundWork{
  if(_count>0&&_started!=null&&
     DateTime.now().difference(_started!)<=maxLifetime)return true;
  final finished=_lastFinishedAt;
  return finished!=null&&DateTime.now().difference(finished)<resumeGrace;
 }
 static bool trustedBackgroundTransition(AppLifecycleState state,{DateTime? at}){
  if(state!=AppLifecycleState.paused&&state!=AppLifecycleState.hidden)return false;
  final began=_started;
  if(_count<=0||began==null)return false;
  final age=(at??DateTime.now()).difference(began);
  return !age.isNegative&&age<=maxLifetime;
 }
 static Future<T> runPicker<T>(Future<T> Function() action)async{
  _count++;_started??=DateTime.now();
  try{return await action();}
  finally{
   _count--;
   if(_count<=0){
    _count=0;_started=null;_lastFinishedAt=DateTime.now();
   }
  }
 }
}

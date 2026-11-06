import 'dart:async';

import 'package:flutter/material.dart';
import 'waffra_mandatory_biometric_gate.dart';

/// M470: an inactivity lock ABOVE MaterialApp's Navigator, including open
/// dialogs, bottom sheets and dropdown routes. The underlying Navigator is
/// never disposed when the idle timer expires, so form drafts survive.
class WaffraIdleBiometricOverlay extends StatefulWidget {
 const WaffraIdleBiometricOverlay({
  super.key,required this.child,required this.enabled,
  required this.english,required this.onSignOut,
  this.timeout=const Duration(seconds:60),
  this.now=DateTime.now,
 });
 final Widget child;
 final bool enabled,english;
 final Future<void> Function() onSignOut;
 final Duration timeout;
 /// Wall clock survives Android suspension; test clock is injected only in QA.
 final DateTime Function() now;
 @override State<WaffraIdleBiometricOverlay> createState()=>
  _WaffraIdleBiometricOverlayState();
}

class _WaffraIdleBiometricOverlayState
    extends State<WaffraIdleBiometricOverlay> with WidgetsBindingObserver {
 Timer? _timer;
 bool _idleLocked=false;
 bool _verifiedAwaitingResume=false,_backgroundShield=false;
 DateTime? _lastActivity,_backgroundAt;

 bool get _foreground{
  final state=WidgetsBinding.instance.lifecycleState;
  return state==null||state==AppLifecycleState.resumed;
 }

 void _arm(){
  _timer?.cancel();
  _timer=null;
  if(!mounted||!widget.enabled||_idleLocked||!_foreground)return;
  _timer=Timer(widget.timeout,(){
   if(!mounted||!widget.enabled||_idleLocked||!_foreground)return;
   // Do not continue editing the underlying form using an IME while locked.
   // Unfocusing does not remove the draft or change the current route.
   FocusManager.instance.primaryFocus?.unfocus();
   setState(()=>_idleLocked=true);
  });
 }

 void _onActivity(){
  if(!widget.enabled||_idleLocked)return;
  final now=widget.now();
  if(_lastActivity!=null&&
     now.difference(_lastActivity!)<const Duration(milliseconds:300))return;
  _lastActivity=now;
  _arm();
 }

 void _verified(){
  if(!mounted||!widget.enabled||!_idleLocked)return;
  if(_foreground){
   _verifiedAwaitingResume=false;
   setState(()=>_idleLocked=false);
   _lastActivity=null;
   _arm();
  }else if(WidgetsBinding.instance.lifecycleState==AppLifecycleState.inactive){
   // The native OS prompt may succeed just before Flutter resumes.
   _verifiedAwaitingResume=true;
  }
 }

 @override void initState(){
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _arm();
 }

 @override void didUpdateWidget(covariant WaffraIdleBiometricOverlay old){
  super.didUpdateWidget(old);
  if(!widget.enabled){
   _timer?.cancel();_timer=null;
   _verifiedAwaitingResume=false;
   if(_idleLocked)_idleLocked=false;
   _lastActivity=null;_backgroundAt=null;_backgroundShield=false;
  }else if(!old.enabled||old.timeout!=widget.timeout){
   _arm();
  }
 }

 @override void didChangeAppLifecycleState(AppLifecycleState state){
  if(state==AppLifecycleState.resumed){
   final began=_backgroundAt;
   _backgroundAt=null;
   if(widget.enabled&&began!=null&&
      widget.now().difference(began)>=widget.timeout){
    // Lock BEFORE the green privacy shield is removed. We never dispose the
    // Navigator or underlying form controllers on background/resume.
    FocusManager.instance.primaryFocus?.unfocus();
    setState((){_idleLocked=true;_backgroundShield=false;});
   }else if(_backgroundShield){
    setState(()=>_backgroundShield=false);
   }
   if(_verifiedAwaitingResume&&_idleLocked&&widget.enabled){
    _verified();
   }else if(!_idleLocked){
    _lastActivity=null;_arm();
   }
  }else if(state==AppLifecycleState.hidden||
           state==AppLifecycleState.paused||
           state==AppLifecycleState.detached){
   _timer?.cancel();_timer=null;
   _verifiedAwaitingResume=false;
   if(widget.enabled){
    _backgroundAt??=widget.now();
    // Fully opaque green app switcher privacy surface: not a translucent
    // biometric dialog with the existing dropdown visible underneath.
    if(!_backgroundShield)setState(()=>_backgroundShield=true);
   }
  }
 }

 @override void dispose(){
  _timer?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
 }

 @override Widget build(BuildContext context)=>Listener(
  behavior:HitTestBehavior.translucent,
  // A new user tap always restarts the countdown, even in a fast gesture.
  onPointerDown:(_)=>_arm(),
  onPointerMove:(_)=>_onActivity(),
  onPointerSignal:(_)=>_onActivity(),
  child:Stack(fit:StackFit.expand,children:[
   widget.child,
   if(_backgroundShield&&!_idleLocked)
    const Positioned.fill(child:BlockSemantics(
     blocking:true,
     child:ColoredBox(key:Key('m470-background-green-privacy-shield'),
      color:Color(0xFF064D3B),child:SizedBox.expand()))),
   if(_idleLocked)
    Positioned.fill(child:BlockSemantics(
     blocking:true,
     child:WaffraMandatoryBiometricGate(
      key:const ValueKey('m470-idle-lock-biometric'),
      english:widget.english,
      onVerified:_verified,
      onSignOut:widget.onSignOut,
     ),
    )),
  ]),
 );
}

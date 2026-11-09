import 'package:flutter/material.dart';
import 'waffra_mandatory_biometric_gate.dart';

/// M613: lock after a genuine 60-second background absence, NEVER while
/// Waffra remains visible in the foreground (even with no touch input).
/// Stays ABOVE MaterialApp's Navigator to preserve open drafts and dialogs.
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
 bool _idleLocked=false;
 bool _verifiedAwaitingResume=false,_backgroundShield=false;
 DateTime? _backgroundAt;

 bool get _foreground{
  final state=WidgetsBinding.instance.lifecycleState;
  return state==null||state==AppLifecycleState.resumed;
 }

 void _verified(){
  if(!mounted||!widget.enabled||!_idleLocked)return;
  if(_foreground){
   _verifiedAwaitingResume=false;
   setState(()=>_idleLocked=false);

  }else if(WidgetsBinding.instance.lifecycleState==AppLifecycleState.inactive){
   // The native OS prompt may succeed just before Flutter resumes.
   _verifiedAwaitingResume=true;
  }
 }

 @override void initState(){
  super.initState();
  WidgetsBinding.instance.addObserver(this);
 }

 @override void didUpdateWidget(covariant WaffraIdleBiometricOverlay old){
  super.didUpdateWidget(old);
  if(!widget.enabled){
   _verifiedAwaitingResume=false;
   if(_idleLocked)_idleLocked=false;
   _backgroundAt=null;_backgroundShield=false;
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
   }
  }else if(state==AppLifecycleState.hidden||
           state==AppLifecycleState.paused||
           state==AppLifecycleState.detached){
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
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
 }

 @override Widget build(BuildContext context)=>Stack(
  fit:StackFit.expand,children:[
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
  ]); 
}

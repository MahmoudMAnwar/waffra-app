import 'package:flutter/material.dart';

/// Active options use a modest 1.6dp green outline without neon glow.
abstract final class WaffraSubtleSelection {
 static BorderSide border(bool selected,Brightness brightness){
  final dark=brightness==Brightness.dark;
  return BorderSide(
   color:selected
    ?(dark?const Color(0xFF85D9AB):const Color(0xFF087A54))
    :(dark?const Color(0xFF658475):const Color(0xFFCAD9D1)),
   width:selected?1.6:1.0);
 }
 static SegmentedButtonThemeData segmented(Brightness brightness){
  final dark=brightness==Brightness.dark;
  return SegmentedButtonThemeData(style:ButtonStyle(
   minimumSize:const WidgetStatePropertyAll(Size(0,48)),
   side:WidgetStateProperty.resolveWith<BorderSide>((states)=>
    border(states.contains(WidgetState.selected),brightness)),
   backgroundColor:WidgetStateProperty.resolveWith<Color>((states)=>
    states.contains(WidgetState.selected)
     ?(dark?const Color(0xFF28533C):const Color(0xFFE7F6EE))
     :(dark?const Color(0xFF1B241F):Colors.white)),
   foregroundColor:WidgetStateProperty.resolveWith<Color>((states)=>
    dark?const Color(0xFFE5FFF0):const Color(0xFF073F31)),
   textStyle:WidgetStateProperty.resolveWith<TextStyle>((states)=>
    TextStyle(fontFamily:'Tajawal',
     fontWeight:states.contains(WidgetState.selected)?FontWeight.w800:FontWeight.w600)),
   padding:const WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal:10,vertical:8)),
   shape:const WidgetStatePropertyAll(RoundedRectangleBorder(
    borderRadius:BorderRadius.all(Radius.circular(16)))),
  ));
 }
}

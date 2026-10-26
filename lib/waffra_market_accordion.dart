import 'package:flutter/material.dart';

/// One-open-at-a-time header for the Waffra FX / gold / energy marketplace.
/// Only the parent holds the selected section. Collapsed children are not built,
/// so no quote is fetched for hidden markets.
class WaffraMarketAccordionCard extends StatelessWidget {
 const WaffraMarketAccordionCard({
  super.key,required this.id,required this.title,required this.subtitle,
  required this.icon,required this.expanded,required this.onPressed,
  required this.child,required this.accent,
 });
 final String id,title,subtitle;
 final IconData icon;
 final bool expanded;
 final VoidCallback onPressed;
 final Widget child;
 final Color accent;
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  final forest=dark?const Color(0xFFD4F7E5):const Color(0xFF083D30);
  return Container(
   key:Key('waffra-market-accordion-'+id),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(25),
    border:Border.all(color:accent.withValues(alpha:dark ? 0.65 : 0.34),width:1.35)),
   clipBehavior:Clip.antiAlias,
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Material(color:Colors.transparent,child:InkWell(
     key:Key('waffra-market-toggle-'+id),
     onTap:onPressed,
     child:Container(
      padding:const EdgeInsets.symmetric(horizontal:15,vertical:14),
      decoration:BoxDecoration(gradient:LinearGradient(
       begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,
       colors:dark?
        [accent.withValues(alpha:.20),Theme.of(context).cardColor]:
        [accent.withValues(alpha:.12),Theme.of(context).cardColor])),
      child:Row(children:[
       Container(width:56,height:56,
        decoration:BoxDecoration(color:accent.withValues(alpha:dark ? 0.18 : 0.10),
         borderRadius:BorderRadius.circular(18)),
        child:Icon(icon,color:accent,size:32)),
       const SizedBox(width:12),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(title,maxLines:2,style:TextStyle(color:forest,
         fontSize:19,fontWeight:FontWeight.w900)),
        const SizedBox(height:4),
        Text(subtitle,maxLines:2,style:TextStyle(
         color:Theme.of(context).hintColor,fontSize:12)),
       ])),
       const SizedBox(width:7),
       AnimatedRotation(turns:expanded?0:.5,
        duration:const Duration(milliseconds:220),
        child:Icon(Icons.keyboard_arrow_up_rounded,color:forest,size:29)),
      ]),
     ))),
    if(expanded)Padding(padding:const EdgeInsets.fromLTRB(12,13,12,16),
     child:child),
   ]),
  );
 }
}

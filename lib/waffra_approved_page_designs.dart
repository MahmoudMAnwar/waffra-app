import 'package:flutter/material.dart';

/// M674: owner-approved Home 1 / Goals reference / Recurring 3.
/// Presentation only. Real balances, counts, dates and callbacks come from the
/// verified finance state in main.dart. Nothing in this file writes finance.
abstract final class WaffraApprovedPalette {
 static const forest=Color(0xFF064D3B);
 static const emerald=Color(0xFF087A54);
 static const sand=Color(0xFFF8F6EF);
 static const gold=Color(0xFFD8BA78);
}

class WaffraApprovedPageHero extends StatelessWidget {
 const WaffraApprovedPageHero({
  super.key,required this.title,required this.subtitle,required this.icon,
 });
 final String title,subtitle;
 final IconData icon;
 @override Widget build(BuildContext context){
  final small=MediaQuery.sizeOf(context).width<370;
  return Semantics(header:true,child:Container(
   key:const Key('m674-premium-page-hero'),
   width:double.infinity,
   padding:EdgeInsets.symmetric(horizontal:small?15:20,vertical:18),
   decoration:BoxDecoration(
    gradient:const LinearGradient(
     begin:AlignmentDirectional.topStart,
     end:AlignmentDirectional.bottomEnd,
     colors:[WaffraApprovedPalette.forest,
      WaffraApprovedPalette.emerald,Color(0xFF043B2F)]),
    borderRadius:BorderRadius.circular(23),
    border:Border.all(color:WaffraApprovedPalette.gold.withValues(alpha:.42))),
   child:Row(children:[
    Container(width:48,height:48,
     decoration:BoxDecoration(
      color:WaffraApprovedPalette.gold.withValues(alpha:.18),
      borderRadius:BorderRadius.circular(15)),
     child:Icon(icon,color:WaffraApprovedPalette.gold,size:27)),
    const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Text(title,maxLines:2,style:TextStyle(
      color:Colors.white,fontWeight:FontWeight.w800,fontSize:small?22:26)),
     const SizedBox(height:4),
     Text(subtitle,maxLines:3,style:const TextStyle(
      color:Color(0xFFE6F0E9),fontSize:12,height:1.4)),
    ])),
   ]),
  ));
 }
}

class WaffraApprovedMetric {
 const WaffraApprovedMetric(this.title,this.value,this.icon);
 final String title,value;
 final IconData icon;
}

class WaffraApprovedMetrics extends StatelessWidget {
 const WaffraApprovedMetrics({super.key,required this.metrics});
 final List<WaffraApprovedMetric> metrics;
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(
   key:const Key('m674-verified-metrics'),
   padding:const EdgeInsets.symmetric(horizontal:7,vertical:13),
   decoration:BoxDecoration(
    color:dark?Theme.of(context).cardColor:WaffraApprovedPalette.sand,
    border:Border.all(color:WaffraApprovedPalette.gold.withValues(alpha:.45)),
    borderRadius:BorderRadius.circular(21),
    boxShadow:[BoxShadow(
     color:Colors.black.withValues(alpha:.05),blurRadius:12,
     offset:const Offset(0,4))]),
   child:Row(children:[
    for(var i=0;i<metrics.length;i++)...[
     if(i>0)Container(width:1,height:49,
      color:Theme.of(context).dividerColor.withValues(alpha:.48)),
     Expanded(child:Padding(
      padding:const EdgeInsets.symmetric(horizontal:4),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       Icon(metrics[i].icon,color:WaffraApprovedPalette.emerald,size:21),
       const SizedBox(height:4),
       Text(metrics[i].value,textAlign:TextAlign.center,maxLines:1,
        overflow:TextOverflow.ellipsis,
        style:TextStyle(fontWeight:FontWeight.w800,fontSize:17,
         color:Theme.of(context).colorScheme.onSurface)),
       const SizedBox(height:2),
       Text(metrics[i].title,maxLines:2,textAlign:TextAlign.center,
        style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w600)),
      ]),
     )),
    ],
   ]),
  );
 }
}

class WaffraApprovedDashboardLink extends StatelessWidget {
 const WaffraApprovedDashboardLink({
  super.key,required this.title,required this.count,
  required this.icon,required this.onTap,
 });
 final String title,count;
 final IconData icon;
 final VoidCallback onTap;
 @override Widget build(BuildContext context){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Expanded(child:Material(
   color:dark?Theme.of(context).cardColor:WaffraApprovedPalette.sand,
   borderRadius:BorderRadius.circular(17),
   child:InkWell(
    key:Key('m674-home-link-'+title),
    onTap:onTap,
    borderRadius:BorderRadius.circular(17),
    child:Container(
     constraints:const BoxConstraints(minHeight:88),
     padding:const EdgeInsets.symmetric(horizontal:3,vertical:8),
     decoration:BoxDecoration(
      border:Border.all(color:WaffraApprovedPalette.gold.withValues(alpha:.55)),
      borderRadius:BorderRadius.circular(17)),
     child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:WaffraApprovedPalette.emerald,size:24),
      const SizedBox(height:3),
      Text(title,maxLines:2,textAlign:TextAlign.center,
       style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700)),
      Text(count,textAlign:TextAlign.center,
       style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
     ]),
    ),
   ),
  ));
 }
}

class WaffraApprovedSectionTitle extends StatelessWidget {
 const WaffraApprovedSectionTitle(this.title,{
  super.key,this.icon=Icons.stars_rounded,
 });
 final String title;
 final IconData icon;
 @override Widget build(BuildContext context)=>Padding(
  padding:const EdgeInsets.only(top:8,bottom:10),
  child:Row(children:[
   Icon(icon,color:WaffraApprovedPalette.emerald,size:20),
   const SizedBox(width:6),
   Expanded(child:Text(title,style:const TextStyle(
    fontSize:18,fontWeight:FontWeight.w800))),
  ]),
 );
}

class WaffraApprovedStatusPill extends StatelessWidget {
 const WaffraApprovedStatusPill({
  super.key,required this.label,required this.icon,
  this.attention=false,
 });
 final String label;
 final IconData icon;
 final bool attention;
 @override Widget build(BuildContext context){
  final tone=attention?const Color(0xFFAD583E):WaffraApprovedPalette.emerald;
  return Container(
   padding:const EdgeInsets.symmetric(horizontal:8,vertical:5),
   decoration:BoxDecoration(
    color:tone.withValues(alpha:.12),borderRadius:BorderRadius.circular(20)),
   child:Row(mainAxisSize:MainAxisSize.min,children:[
    Icon(icon,size:14,color:tone),
    const SizedBox(width:4),
    Flexible(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
     style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:tone))),
   ]),
  );
 }
}

/// This deliberately charts actual currently stored progress by GOAL.
/// It must never pretend that a current saved balance proves monthly history.
class WaffraApprovedGoalProgressBars extends StatelessWidget {
 const WaffraApprovedGoalProgressBars({
  super.key,required this.title,required this.labels,required this.progress,
 });
 final String title;
 final List<String> labels;
 final List<double> progress;
 @override Widget build(BuildContext context){
  final n=labels.length<progress.length?labels.length:progress.length;
  if(n==0)return const SizedBox.shrink();
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(
   key:const Key('m674-real-goal-progress-chart'),
   padding:const EdgeInsets.fromLTRB(13,13,13,11),
   decoration:BoxDecoration(
    color:dark?Theme.of(context).cardColor:const Color(0xFFE6F1E9),
    borderRadius:BorderRadius.circular(19)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800)),
    const SizedBox(height:11),
    SizedBox(height:74,child:Row(
     crossAxisAlignment:CrossAxisAlignment.end,
     children:[
      for(var i=0;i<n;i++)Expanded(child:Padding(
       padding:const EdgeInsets.symmetric(horizontal:4),
       child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
        Expanded(child:Align(alignment:Alignment.bottomCenter,
         child:FractionallySizedBox(
          heightFactor:progress[i].clamp(.05,1.0).toDouble(),
          child:Container(decoration:BoxDecoration(
           color:i==n-1?WaffraApprovedPalette.forest:
            WaffraApprovedPalette.emerald.withValues(alpha:.46),
           borderRadius:const BorderRadius.vertical(
            top:Radius.circular(5))))))),
        const SizedBox(height:5),
        Text(labels[i],maxLines:1,overflow:TextOverflow.ellipsis,
         style:const TextStyle(fontSize:9)),
       ]),
      )),
     ],
    )),
   ]),
  );
 }
}

/// Renders the notice NEXT to the existing CompositedTransformTarget FAB.
/// No bottomNavigationBar expansion, no FAB geometry or tap-handler changes.
/// The bottom edge stays anchored even when the message wraps to 2+ lines.
class WaffraApprovedFixedFabNoticePosition extends StatelessWidget {
 const WaffraApprovedFixedFabNoticePosition({
  super.key,required this.link,required this.english,required this.child,
 });
 final LayerLink link;
 final bool english;
 final Widget child;
 @override Widget build(BuildContext context)=>Positioned.fill(
  child:Align(alignment:Alignment.topLeft,
   child:CompositedTransformFollower(
    link:link,showWhenUnlinked:false,
    targetAnchor:english?Alignment.bottomLeft:Alignment.bottomRight,
    followerAnchor:english?Alignment.bottomRight:Alignment.bottomLeft,
    offset:Offset(english?-8:8,0),
    child:SizedBox(
     width:(MediaQuery.sizeOf(context).width-104).clamp(168.0,440.0).toDouble(),
     child:child),
   )),
 );
}

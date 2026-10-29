import 'package:flutter/material.dart';

import 'waffra_haptic_feedback.dart';
/// Five footer destinations: Home, Categories, Smart Tools, Goals and Recurring.
/// Account settings are opened from the profile avatar in the app bar.
class WaffraFooterNavigation extends StatelessWidget {
 final int selectedIndex;
 final ValueChanged<int> onSelected;
 final bool english;
 const WaffraFooterNavigation({
  super.key,required this.selectedIndex,required this.onSelected,
  required this.english,
 });

 static const itemCount=5;
 static const _icons=<IconData>[
  Icons.home_rounded,
  Icons.grid_view_rounded,
  Icons.auto_awesome_rounded,
  Icons.track_changes_rounded,
  Icons.repeat_rounded,
 ];
 String _label(int i){
  final labels=english?
   <String>['Home','Categories','Smart tools','Goals','Recurring']:
   <String>['الرئيسية','الأقسام','الأدوات','الأهداف','المتكررة'];
  return labels[i];
 }

 @override Widget build(BuildContext context){
  final reduced=MediaQuery.disableAnimationsOf(context);
  const neon=Color(0xFF5DFFBD),emerald=Color(0xFF0C7957);
  return Container(
   key:const Key('waffra-modern-footer'),
   decoration:const BoxDecoration(
    gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
     colors:[Color(0xFF004934),Color(0xFF073F31),Color(0xFF003D30)]),
    borderRadius:BorderRadius.vertical(top:Radius.circular(27)),
    boxShadow:[BoxShadow(color:Color(0x33002C1B),blurRadius:19,offset:Offset(0,-3))]),
   child:SafeArea(top:false,child:Padding(
    padding:const EdgeInsets.fromLTRB(7,10,7,6),
    child:Row(
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     children:List.generate(itemCount,(i){
      final active=i==selectedIndex;
      return Expanded(child:Semantics(
       button:true,selected:active,label:_label(i),
       child:InkWell(key:Key('waffra-nav-$i'),
        borderRadius:BorderRadius.circular(22),
        onTap:WaffraHaptics.tap(()=>onSelected(i)),
        child:Padding(
         padding:const EdgeInsets.symmetric(horizontal:2,vertical:4),
         child:Column(mainAxisSize:MainAxisSize.min,children:[
          AnimatedContainer(
           duration:reduced?Duration.zero:const Duration(milliseconds:200),
           curve:Curves.easeOutCubic,
           width:active?53:47,height:active?44:40,
           alignment:Alignment.center,
           decoration:BoxDecoration(
            color:active?emerald.withValues(alpha:.9):Colors.transparent,
            borderRadius:BorderRadius.circular(23),
            border:active?Border.all(color:neon.withValues(alpha:.32),width:1.3):null),
           child:Icon(_icons[i],color:Colors.white,size:active?26:24)),
          const SizedBox(height:4),
          Text(_label(i),maxLines:1,overflow:TextOverflow.ellipsis,
           textAlign:TextAlign.center,
           style:TextStyle(color:Colors.white,fontSize:11,
            fontWeight:active?FontWeight.w800:FontWeight.w600,height:1.2)),
          const SizedBox(height:4),
          AnimatedContainer(
           duration:reduced?Duration.zero:const Duration(milliseconds:200),
           width:active?7:0,height:active?7:0,
           decoration:const BoxDecoration(color:neon,shape:BoxShape.circle)),
         ]),
        ),
       ),
      ));
     }),
    ),
   )),
  );
 }
}

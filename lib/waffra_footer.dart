import 'package:flutter/material.dart';

/// Six original Waffra destinations with a distinct center-stage analysis action.
/// The current page is always reflected by an illuminated selection and dot.
class WaffraFooterNavigation extends StatelessWidget {
 final int selectedIndex;
 final ValueChanged<int> onSelected;
 final bool english;
 final Key? analysisSpotlightKey;
 final Key? profileSpotlightKey;
 const WaffraFooterNavigation({
  super.key,required this.selectedIndex,required this.onSelected,
  required this.english,this.analysisSpotlightKey,this.profileSpotlightKey,
 });
 static const itemCount=6;
 static const _normalIcons=<IconData>[
  Icons.home_rounded,
  Icons.grid_view_rounded,
  Icons.auto_awesome_rounded,
  Icons.track_changes_rounded,
  Icons.repeat_rounded,
  Icons.person_outline_rounded,
 ];
 String _label(int i){
  final labels=english?
   <String>['Home','Categories','Smart analysis','Goals','Recurring','Account']:
   <String>['الرئيسية','الأقسام','التحليل الذكي','الأهداف','المتكررة','حسابي'];
  return labels[i];
 }
 @override Widget build(BuildContext context){
  final reduced=MediaQuery.disableAnimationsOf(context);
  const deep=Color(0xFF073F31);
  const emerald=Color(0xFF0C7957);
  const neon=Color(0xFF5DFFBD);
  return Container(
   key:const Key('waffra-modern-footer'),
   decoration:const BoxDecoration(
    gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
     colors:[Color(0xFF004934),deep,Color(0xFF003D30)]),
    borderRadius:BorderRadius.vertical(top:Radius.circular(27)),
    boxShadow:[BoxShadow(color:Color(0x33002C1B),blurRadius:19,offset:Offset(0,-3))]),
   child:SafeArea(top:false,child:Padding(
    padding:const EdgeInsets.fromLTRB(5,12,5,4),
    child:Row(
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     crossAxisAlignment:CrossAxisAlignment.end,
     children:List.generate(itemCount,(i){
      final active=i==selectedIndex;
      final ai=i==2;
      return Expanded(
       flex:ai?12:10,
       child:Semantics(
        button:true,selected:active,
        label:_label(i),
        child:InkWell(
         key:Key('waffra-nav-$i'),
         borderRadius:BorderRadius.circular(23),
         onTap:()=>onSelected(i),
         child:Padding(
          padding:const EdgeInsets.symmetric(horizontal:1,vertical:3),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
           if(ai)
            Transform.translate(offset:const Offset(0,-11),
             child:Container(
              key:analysisSpotlightKey,
              width:61,height:61,
              alignment:Alignment.center,
              decoration:BoxDecoration(
               shape:BoxShape.circle,
               gradient:const LinearGradient(colors:[Color(0xFF087A54),Color(0xFF003B31)]),
               border:Border.all(color:neon,width:2.4),
               boxShadow:[
                BoxShadow(color:neon.withValues(alpha:active ? .54 : .30),blurRadius:active?24:14,spreadRadius:active?3:0),
                const BoxShadow(color:Color(0x55000000),blurRadius:8,offset:Offset(0,4)),
               ]),
              child:const Icon(Icons.auto_awesome_rounded,color:Colors.white,size:28))),
           else
            AnimatedContainer(
             duration:reduced?Duration.zero:const Duration(milliseconds:190),
             width:49,height:39,
             alignment:Alignment.center,
             decoration:BoxDecoration(
              color:active?emerald.withValues(alpha:.88):Colors.transparent,
              borderRadius:BorderRadius.circular(22)),
             child:KeyedSubtree(
              key:i==5?profileSpotlightKey:null,
              child:Icon(_normalIcons[i],color:Colors.white,size:24))),
           SizedBox(height:ai?0:5),
           Text(_label(i),maxLines:1,overflow:TextOverflow.ellipsis,
            textAlign:TextAlign.center,
            style:TextStyle(
             fontSize:ai?10.2:10.3,fontWeight:active||ai?FontWeight.w800:FontWeight.w600,
             color:Colors.white,height:1.22)),
           const SizedBox(height:4),
           AnimatedContainer(
            duration:reduced?Duration.zero:const Duration(milliseconds:190),
            width:active?6:0,height:active?6:0,
            decoration:const BoxDecoration(color:neon,shape:BoxShape.circle)),
          ]),
         ),
        ),
       ),
      );
     }),
    ),
   )),
  );
 }
}

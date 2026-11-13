part of 'main.dart';

/// M684: pure Home/Recurring card presentation was extracted from the giant
/// Home State. These helpers do not write finance or change the global FAB.
extension _WaffraHomeFinanceTileModule on _HomeScreenState {
 Widget _m684DashboardShortcut(String title,IconData icon,VoidCallback onTap){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Expanded(child:Material(
   color:Theme.of(context).cardColor,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
    side:BorderSide(color:dark?const Color(0xFF354B3E):const Color(0xFFDCEAE1))),
   child:InkWell(
    onTap:WaffraHaptics.tap(onTap),borderRadius:BorderRadius.circular(18),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:5,vertical:12),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:34,height:34,
       decoration:BoxDecoration(color:dark?const Color(0xFF214E37):waffraMint,
        borderRadius:BorderRadius.circular(12)),
       child:Icon(icon,color:dark?const Color(0xFFA2E4C1):forest,size:21)),
      const SizedBox(height:6),
      WaffraText(title,maxLines:2,textAlign:TextAlign.center,
       style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
     ])),
   ),
  ));
 }

 Widget _m684HomeSummaryCard(String label,double value,IconData symbol,Color color,Color tint)=>
  Expanded(child:InkWell(
   onTap:WaffraHaptics.tap(()=>showSummaryTransactions(label=='الدخل'||label=='Income')),
   borderRadius:BorderRadius.circular(19),
   child:Container(
    padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
    decoration:BoxDecoration(
     color:Theme.of(context).brightness==Brightness.dark?
      (label=='الدخل'||label=='Income'?const Color(0xFF244C3A):const Color(0xFF49302C)):tint,
     borderRadius:BorderRadius.circular(19),
     border:Border.all(color:color.withValues(alpha:0.13)),
     boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),
      blurRadius:7,offset:const Offset(0,3))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     Row(textDirection:TextDirection.rtl,children:[
      Expanded(child:WaffraText(label,textAlign:TextAlign.right,
       style:const TextStyle(fontSize:14,fontWeight:FontWeight.bold))),
      const SizedBox(width:6),
      CircleAvatar(backgroundColor:color.withValues(alpha:0.12),
       radius:16,child:Icon(symbol,color:color,size:19)),
     ]),
     const SizedBox(height:5),
     Align(alignment:Alignment.centerRight,
      child:FittedBox(fit:BoxFit.scaleDown,
       child:WaffraCurrencyAmount(value,fontSize:17))),
    ]))));

 Widget _m684HomeFinanceAction({
  required String title,required IconData icon,
  required Color background,required Color iconColor,
  required VoidCallback onTap,
 }){
  return Expanded(child:Material(
   color:background,borderRadius:BorderRadius.circular(18),
   child:InkWell(
    borderRadius:BorderRadius.circular(18),
    onTap:WaffraHaptics.tap(onTap),
    child:Container(
     key:Key('m549-home-action-'+(icon==Icons.swap_horiz_rounded?'transfer':
      icon==Icons.north_east_rounded?'expense':'income')),
     height:60,
     decoration:BoxDecoration(
      borderRadius:BorderRadius.circular(18),
      border:Border.all(color:iconColor.withValues(alpha:.18))),
     child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,size:21,color:iconColor),
      const SizedBox(height:3),
      Padding(padding:const EdgeInsets.symmetric(horizontal:4),
       child:WaffraText(title,textAlign:TextAlign.center,maxLines:2,
        style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,
         color:Theme.of(context).brightness==Brightness.dark?
          const Color(0xFF173D31):const Color(0xFF183C31)))),
     ]),
    ),
   ),
  ));
 }


 Widget _m684RecurringBenefit(String label,IconData icon)=>Container(
  padding:const EdgeInsets.symmetric(horizontal:6,vertical:14),
  decoration:BoxDecoration(color:emerald.withValues(alpha:.08),borderRadius:BorderRadius.circular(18)),
  child:Column(mainAxisSize:MainAxisSize.min,children:[
   Icon(icon,color:emerald,size:25),const SizedBox(height:9),
   WaffraText(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600)),
  ]));

}

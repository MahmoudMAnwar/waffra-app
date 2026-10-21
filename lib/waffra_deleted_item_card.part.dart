part of 'main.dart';

/// One shared visual language for deleted categories, goals and recurring items.
/// A deleted item is a configuration, not a financial transaction: restoration
/// never deletes or rewrites past ledger entries.
double waffraDeletedListHeight(BuildContext context, int count) {
 final available=MediaQuery.sizeOf(context).height*.54;
 return min(available,max(118.0,count*165.0+12.0));
}

Widget waffraDeletedItemCard({
 required BuildContext context,
 required IconData icon,
 required Color iconColor,
 required String title,
 required String subtitle,
 required VoidCallback onRestore,
 required VoidCallback onDeleteForever,
}) {
 final english=waffraIsEnglish;
 final theme=Theme.of(context);
 final dark=theme.brightness==Brightness.dark;
 final foreground=dark?const Color(0xFF9FEAC6):forest;
 return Card(
  margin:const EdgeInsets.only(bottom:10),
  elevation:0,
  color:theme.cardColor,
  shape:RoundedRectangleBorder(
   borderRadius:BorderRadius.circular(21),
   side:BorderSide(color:dark?const Color(0xFF4C806B):const Color(0xFFDDE8E1)),
  ),
  child:Padding(padding:const EdgeInsets.symmetric(horizontal:13,vertical:13),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Icon(icon,color:iconColor,size:25),
     const SizedBox(width:9),
     Expanded(child:WaffraText(title,maxLines:2,
      style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
    ]),
    const SizedBox(height:5),
    Padding(padding:const EdgeInsetsDirectional.only(start:34),
     child:WaffraText(subtitle,maxLines:2,
      style:TextStyle(fontSize:12,color:theme.hintColor,fontWeight:FontWeight.w600))),
    const SizedBox(height:11),
    Row(children:[
     Expanded(child:OutlinedButton.icon(
      onPressed:onRestore,
      icon:Icon(Icons.restore_rounded,size:19,color:foreground),
      label:WaffraText(english?'Restore':'استرجاع',
       style:TextStyle(fontSize:13,color:foreground,fontWeight:FontWeight.bold)),
     )),
     const SizedBox(width:6),
     Expanded(child:OutlinedButton.icon(
      onPressed:onDeleteForever,
      icon:const Icon(Icons.delete_forever_outlined,size:19,color:Colors.red),
      label:WaffraText(english?'Delete forever':'حذف نهائي',
       style:const TextStyle(fontSize:12,color:Colors.red,fontWeight:FontWeight.bold)),
     )),
    ]),
   ])),
 );
}

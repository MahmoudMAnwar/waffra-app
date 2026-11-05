import 'package:flutter/material.dart';

/// Static bank marks, never sender-derived network URLs or transaction data.
/// The original sender string is only displayed locally.
class WaffraSmsSenderBrand extends StatelessWidget {
 const WaffraSmsSenderBrand({super.key,required this.sender});
 final String sender;
 static String? publicLogoUrl(String sender){
  final normalized=sender.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');
  if(const ['alinmapay','alinmabank','alinma'].contains(normalized)){
   return 'https://www.google.com/s2/favicons?domain=alinma.com&sz=128';
  }
  if(const ['alrajhibank','alrajhi'].contains(normalized)){
   return 'https://www.google.com/s2/favicons?domain=alrajhibank.com.sa&sz=128';
  }
  if(const ['snb','saudinationalbank'].contains(normalized)){
   return 'https://www.google.com/s2/favicons?domain=alahli.com&sz=128';
  }
  return null;
 }
 @override Widget build(BuildContext context){
  const green=Color(0xFF087A54);
  final fallback=const Icon(Icons.account_balance_rounded,color:green,size:24);
  final logo=publicLogoUrl(sender);
  return Container(width:48,height:48,alignment:Alignment.center,
   decoration:BoxDecoration(color:Theme.of(context).brightness==Brightness.dark?
    const Color(0xFF194032):const Color(0xFFE8F4EB),
    borderRadius:BorderRadius.circular(13)),
   child:logo==null?fallback:ClipRRect(
    borderRadius:BorderRadius.circular(10),child:Image.network(logo,
     width:34,height:34,fit:BoxFit.contain,
     errorBuilder:(_,__,___)=>fallback)),
  );
 }
}

class WaffraSmsReviewMetrics extends StatelessWidget {
 const WaffraSmsReviewMetrics({super.key,required this.shown,
  required this.selected,required this.senderCount,required this.english});
 final int shown,selected,senderCount;final bool english;
 @override Widget build(BuildContext context){
  Widget metric(String label,int count,IconData symbol)=>Expanded(child:Container(
   padding:const EdgeInsets.symmetric(vertical:9,horizontal:3),
   decoration:BoxDecoration(color:Theme.of(context).brightness==Brightness.dark?
    const Color(0xFF194032):const Color(0xFFE8F4EB),
    borderRadius:BorderRadius.circular(15)),
   child:Column(children:[
    Icon(symbol,color:const Color(0xFF087A54),size:18),
    Text(label,style:const TextStyle(fontSize:11)),
    Text(count.toString(),style:const TextStyle(
     color:Color(0xFF087A54),fontSize:19,fontWeight:FontWeight.bold)),
   ]),
  ));
  return Row(children:[
   metric(english?'Shown':'المعروضة',shown,Icons.mail_outline),
   const SizedBox(width:7),
   metric(english?'Selected':'المحددة',selected,Icons.check_circle_outline),
   const SizedBox(width:7),
   metric(english?'Senders':'المرسلون',senderCount,Icons.account_balance_outlined),
  ]);
 }
}

part of 'main.dart';

/// Analysis is an intentional entry point on Home, not a swipe destination.
extension WaffraSmartAnalysisCard on _HomeScreenState {
 Widget smartAnalysisEntryCard(){
  final now=DateTime.now();
  final spending=<String,int>{};
  for(final item in entries.where((e)=>!e.income&&e.date.year==now.year&&e.date.month==now.month)){
   spending[item.category]=(spending[item.category]??0)+WaffraRecurringPolicy.toHalalas(item.amount);
  }
  final ranked=spending.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final insight=entries.isEmpty
   ?(waffraIsEnglish?'Add your first transaction to unlock insights.':
     'أضف أول عملية دخل أو مصروف لعرض تحليلك المالي.')
   :ranked.isNotEmpty
    ?(waffraIsEnglish?'Most spent this month: ${ranked.first.key} — ${cash(ranked.first.value/100)}':
      'أعلى قسم صرف هذا الشهر: ${ranked.first.key} — ${cash(ranked.first.value/100)}')
    :(waffraIsEnglish?'Explore your recorded financial activity.':
      'اكتشف اتجاهات الدخل والمصروفات المسجلة.');
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(
   key:_tourKeys[3],
   decoration:BoxDecoration(
    color:dark?const Color(0xFF15221D):Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(23),
    border:Border.all(color:dark?const Color(0xFF458566):const Color(0xFFB7DAC8)),
    boxShadow:[BoxShadow(color:emerald.withValues(alpha:.07),blurRadius:12,offset:const Offset(0,3))]),
   child:InkWell(key:const Key('waffra-home-smart-analysis'),
    onTap:()=>showAiAnalysis(),
    borderRadius:BorderRadius.circular(23),
    child:Padding(padding:const EdgeInsets.all(16),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
       Container(padding:const EdgeInsets.all(10),
        decoration:BoxDecoration(color:emerald.withValues(alpha:.14),
         borderRadius:BorderRadius.circular(15)),
        child:const Icon(Icons.auto_awesome_rounded,color:emerald,size:25)),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'Smart analysis':'التحليل الذكي',
         style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18)),
        WaffraText(waffraIsEnglish?'Clear insights into your spending':'رؤية أوضح لقراراتك المالية',
         style:TextStyle(fontSize:12,color:Theme.of(context).hintColor)),
       ])),
       const Icon(Icons.chevron_left_rounded,color:emerald),
      ]),
      const SizedBox(height:14),
      WaffraText(insight,maxLines:3,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600)),
      const SizedBox(height:13),
      Container(
       padding:const EdgeInsets.symmetric(vertical:12,horizontal:14),
       decoration:BoxDecoration(color:forest,borderRadius:BorderRadius.circular(14)),
       child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        const Icon(Icons.insights_rounded,color:Colors.white,size:19),
        const SizedBox(width:9),
        WaffraText(waffraIsEnglish?'Explore financial analysis':'استكشف التحليل المالي',
         style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
       ]),
      ),
     ]),
    ),
   ),
  );
 }
}

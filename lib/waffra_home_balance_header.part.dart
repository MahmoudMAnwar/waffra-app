part of 'main.dart';

class WaffraBalanceHeader extends SliverPersistentHeaderDelegate {
 final double balance;
 final bool english;
 final String? heading;
 final bool goalWallet;
 final bool compact;
 final double? monthlyChangePercent;
 final String? selectedAccountLabel;
 final VoidCallback? onAccountTap;
 final Future<void> Function() refreshVerifiedWidgetBalance;
 const WaffraBalanceHeader({
  required this.balance,required this.english,this.heading,this.goalWallet=false,this.compact=false,
  required this.refreshVerifiedWidgetBalance,this.monthlyChangePercent,
  this.selectedAccountLabel,this.onAccountTap,
 });
 // Reserve space for multiline account names rather than trimming them.
 int get _accountLabelExtraLines=>goalWallet||onAccountTap==null?0:
  (((selectedAccountLabel?.runes.length??0)-25).clamp(0,150)/25).ceil();
 @override double get minExtent=>goalWallet?127.0:(compact?127.0:164.0+20.0*_accountLabelExtraLines);
 @override double get maxExtent=>goalWallet?138.0:(compact?138.0:182.0+20.0*_accountLabelExtraLines);
 @override Widget build(BuildContext context,double shrinkOffset,bool overlapsContent){
  final progress=(shrinkOffset/(maxExtent-minExtent)).clamp(0.0,1.0);
  final dark=Theme.of(context).brightness==Brightness.dark;
  final waveColor=Theme.of(context).scaffoldBackgroundColor;
  final compare=monthlyChangePercent;
  final validCompare=compare!=null&&compare.isFinite;
  final comparisonValue=validCompare?compare:0.0;
  return Container(
   color:waveColor,
   padding:const EdgeInsets.fromLTRB(14,0,14,4),
   child:Container(
    key:Key(goalWallet?'waffra-goal-wallet-balance-card':'waffra-approved-emerald-balance-card'),
    decoration:BoxDecoration(
     borderRadius:BorderRadius.circular(23),
     gradient:const LinearGradient(
      begin:Alignment.topLeft,end:Alignment.bottomRight,
      colors:[Color(0xFF167F5A),Color(0xFF07533E),Color(0xFF00392F)],
      stops:[0,.54,1]),
     border:Border.all(color:const Color(0xFF73CF9A).withValues(alpha:.38)),
     boxShadow:[BoxShadow(color:const Color(0xFF063B2D).withValues(alpha:dark ? 0.25 : 0.17),
      blurRadius:15,offset:const Offset(0,5))]),
    child:ClipRRect(
     borderRadius:BorderRadius.circular(22),
     child:Stack(fit:StackFit.expand,children:[
      Positioned(
       left:-45,top:-84,width:205,height:175,
       child:DecoratedBox(decoration:BoxDecoration(
        border:Border.all(color:const Color(0xFF94EDBC).withValues(alpha:.11)),
        borderRadius:BorderRadius.circular(120)))),
      Positioned(right:-35,top:-95,width:185,height:175,
       child:DecoratedBox(decoration:BoxDecoration(
        color:const Color(0xFF4CCF92).withValues(alpha:.07),
        shape:BoxShape.circle))),
      Positioned(right:0,bottom:-6,width:145,height:137,
       child:IgnorePointer(child:const WaffraBalanceIllustration())),
      Positioned.fill(child:IgnorePointer(child:CustomPaint(
       painter:WaffraBalanceWavePainter(waveColor)))),
      Positioned(left:7,top:10,
       child:ValueListenableBuilder<bool>(
        valueListenable:hideWaffraAmounts,
        builder:(ctx,hidden,_)=>IconButton(
         key:const Key('waffra-balance-privacy-eye'),
         tooltip:hidden?(english?'Show amounts':'إظهار المبالغ'):
          (english?'Hide amounts':'إخفاء المبالغ'),
         onPressed:WaffraHaptics.tap(()async{
          final conceal=!hidden;
          hideWaffraAmounts.value=conceal;
          final prefs=await SharedPreferences.getInstance();
          await prefs.setBool('waffra_hide_amounts',conceal);
          // Keep the existing verified Widget-authority refresh.
          await refreshVerifiedWidgetBalance();
         }),
         icon:Icon(hidden?Icons.visibility_off_outlined:Icons.visibility_outlined,
          size:22,color:const Color(0xFFE2FBEF))))),
      // M549: account filtering has moved to the monthly summary card.
      Positioned(left:47,right:14,top:8,
       child:Center(child:WaffraText(
        heading??(english?'Available balance':'الرصيد المتاح للصرف'),
        style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600,
         color:Color(0xFFD7F1E5))))),
      Positioned(left:47,right:112,
       top:goalWallet?38.0:(compact?36.0:52.0+20.0*_accountLabelExtraLines),
       bottom:compact?8:44,
       child:Center(child:FittedBox(
        alignment:Alignment.center,fit:BoxFit.scaleDown,
        child:WaffraCurrencyAmount(balance,fontSize:31-2*progress,
         color:Colors.white,weight:FontWeight.w800)))),
      if(validCompare)Positioned(left:18,bottom:14,
       child:Column(crossAxisAlignment:CrossAxisAlignment.start,
        mainAxisSize:MainAxisSize.min,children:[
         Container(
          key:const Key('waffra-balance-month-comparison'),
          padding:const EdgeInsets.symmetric(horizontal:9,vertical:4),
          decoration:BoxDecoration(
           color:(comparisonValue>=0?const Color(0xFF1BAC70):const Color(0xFFAA403C))
            .withValues(alpha:.92),
           borderRadius:BorderRadius.circular(17)),
          child:Row(mainAxisSize:MainAxisSize.min,children:[
           Icon(comparisonValue>=0?Icons.trending_up_rounded:Icons.trending_down_rounded,
            size:13,color:Colors.white),
           const SizedBox(width:4),
           Text('${comparisonValue>=0?'+':''}${comparisonValue.toStringAsFixed(0)}%',
            style:const TextStyle(color:Colors.white,fontSize:12,
             fontWeight:FontWeight.w800)),
          ])),
         const SizedBox(height:3),
         Text(english?'Compared with last month':'مقارنة بالشهر الماضي',
          style:const TextStyle(fontFamily:'Tajawal',
           fontSize:10,color:Color(0xFFD3F2E0))),
        ])),
     ])),
   ),
  );
 }
 // The cover also depends on inherited light/dark theme and its background.
 // Preserve the old delegate's rebuild semantics on theme/locale changes.
 @override bool shouldRebuild(covariant WaffraBalanceHeader oldDelegate)=>true;
}
/// A cancelled budget warning keeps the caller's editor/review stack intact.
Future<bool> waffraConfirmUnlinkedBudgetSave({
 required BuildContext context,int expenseCount=1,
})async{
 if(expenseCount<=0)return true;
 final approved=await showWaffraDialog<bool>(
  context:context,builder:(ctx)=>AlertDialog(
   key:const Key('waffra-unlinked-budget-confirmation'),
   title:WaffraText(waffraIsEnglish?'Save without a budget?':'حفظ بدون ميزانية؟'),
   content:WaffraText(waffraIsEnglish?
    (expenseCount==1?
     'This expense will not count toward a budget. You can link it later.':
     '$expenseCount expenses will not count toward a budget. You can link them later.'):
    (expenseCount==1?
     'المصروف ده مش هيتحسب على أي ميزانية. تقدر تربطه بعدين.':
     '$expenseCount مصروفات مش هتتحسب على ميزانية. تقدر تربطها بعدين.')),
   actions:[
    TextButton(key:const Key('waffra-unlinked-budget-cancel'),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
     child:WaffraText(waffraIsEnglish?'Go back':'رجوع')),
    FilledButton(key:const Key('waffra-unlinked-budget-accept'),
     onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
     child:WaffraText(waffraIsEnglish?'Save without budget':'حفظ بدون ميزانية')),
   ],
  ));
 return approved==true;
}


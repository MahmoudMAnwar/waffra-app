part of 'main.dart';

/// M805 / Issue #633: original budget notification and pure SVG chart methods.
/// Same-library structural extraction only, with no monetary behavior changes.
extension _WaffraHomeBudgetAlertCharts on _HomeScreenState {
 Future<void> _requestPercentageAlertPermission()async{
  try{
   final granted=await WaffraReminders.requestPermission();
   if(!granted&&mounted)snack(context,waffraIsEnglish?
    'In-app alerts are on; allow notifications in Android Settings for lock-screen alerts.':
    'تنبيهات التطبيق مفعلة. فعّل إشعارات وفرة من إعدادات أندرويد عشان توصلك خارج التطبيق.');
  }catch(error){
   debugPrint('Optional percentage notification permission unavailable: $error');
  }
 }
 Future<void> budgetAlert(MoneyEntry entry,double previousSpent)async {
  if(entry.income)return;
  final budgets=namedBudgets.where((b)=>b.budget>0&&
    b.budgetActive&&b.alertsEnabled&&!b.deleted&&b.id==entry.budgetId).toList();
  if(budgets.length!=1)return;
  final category=budgets.single;
  final spent=waffraNamedBudgetSpent(entries,categories,category,entry.date);
  final stages=<int>{category.alertPercent,100}.toList()..sort();
  final crossedStages=stages.where((stage)=>
   previousSpent<category.budget*stage/100&&
   spent>=category.budget*stage/100).toList();
  if(crossedStages.isEmpty||!mounted)return;
  // Only non-financial hashed alert markers are stored locally. A later edit
  // that reduces spend must not re-alert for a threshold already shown.
  final newlyCrossed=await WaffraBudgetAlertOnce.claim(
   owner:'${widget.profile.provider}|${widget.profile.phone}|${widget.profile.email}',
   budgetId:category.id,month:entry.date,crossedStages:crossedStages);
  if(!newlyCrossed||!mounted)return;
  final crossed=crossedStages.last;
  try{await WaffraReminders.showBudgetThreshold(
   budgetId:category.id,stage:crossed,english:waffraIsEnglish);}
  catch(error){debugPrint('Budget notification unavailable: $error');}
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
   title:WaffraText(waffraIsEnglish?'Budget alert':'⚠️ تنبيه الميزانية'),
   content:WaffraText(waffraIsEnglish?
    '${category.name} has reached ${(spent/category.budget*100).round()}% of the budget (crossed $crossed%). Spent ${cash(spent)} out of ${cash(category.budget)}.':
    'صرف «${category.name}» ${(spent/category.budget*100).round()}٪ (حد التنبيه $crossed٪). ${cash(spent)} من ${cash(category.budget)}.'),
   actions:[FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
    child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
 }
 /// Draw the same category-colored donut shown on Smart Analysis.
 String expensePieSvg(Map<String,double> totals){
  final positive=totals.entries.where((e)=>e.value>0).toList();
  final total=positive.fold<double>(0,(n,e)=>n+e.value);
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="200" height="200" viewBox="0 0 200 200">');
  if(total<=0)return '$out</svg>';
  var angle=-pi/2;
  for(final category in positive){
   final sweep=2*pi*category.value/total;
   final points=<String>['100,100'];
   final steps=max(12,(sweep*70).ceil());
   for(var j=0;j<=steps;j++){
    final theta=angle+sweep*j/steps;
    points.add('${(100+87*cos(theta)).toStringAsFixed(2)},'
     '${(100+87*sin(theta)).toStringAsFixed(2)}');
   }
   final hex=(categoryFor(category.key,false).color&0xFFFFFF)
    .toRadixString(16).padLeft(6,'0');
   out.write('<polygon points="${points.join(' ')}" '
    'fill="#$hex" stroke="#FFFFFF" stroke-width=".8"/>');
   angle+=sweep;
  }
  out.write('<circle cx="100" cy="100" r="45" fill="#FFFFFF"/>');
  out.write('</svg>');
  return out.toString();
 }
 /// Same four weekly expense points and green curve as Flutter analysis.
 String weeklySpendSvg(List<double> amounts){
  final maximum=amounts.fold<double>(1,(a,b)=>max(a,b));
  final points=List.generate(amounts.length,(i)=>
   (32.0+i*168,117.0-94*amounts[i]/maximum));
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="600" height="150" viewBox="0 0 600 150">');
  for(var i=0;i<4;i++){
   final y=23+i*31;
   out.write('<line x1="30" x2="550" y1="$y" y2="$y" '
    'stroke="#E5EEEA" stroke-width="1"/>');
  }
  final path=StringBuffer();
  if(points.isNotEmpty){
   path.write('M ${points[0].$1.toStringAsFixed(1)} ${points[0].$2.toStringAsFixed(1)}');
   for(var i=1;i<points.length;i++){
    final prev=points[i-1],next=points[i],cx=(prev.$1+next.$1)/2;
    path.write(' C ${cx.toStringAsFixed(1)} ${prev.$2.toStringAsFixed(1)}'
     ' ${cx.toStringAsFixed(1)} ${next.$2.toStringAsFixed(1)}'
     ' ${next.$1.toStringAsFixed(1)} ${next.$2.toStringAsFixed(1)}');
   }
  }
  out.write('<path d="$path" fill="none" stroke="#0C7957" stroke-width="4"/>');
  for(final point in points){
   out.write('<circle cx="${point.$1.toStringAsFixed(1)}" '
    'cy="${point.$2.toStringAsFixed(1)}" r="5" '
    'fill="#0C7957" stroke="#FFFFFF" stroke-width="2"/>');
  }
  out.write('</svg>');
  return out.toString();
 }
 /// Five weekly or twelve monthly grouped bars match the Analytics tab.
 String pairedBarChartSvg(List<(double,double)> values){
  final maximum=values.fold<double>(1,(v,p)=>max(v,max(p.$1,p.$2)));
  final count=values.length,width=max(520,count*56);
  final out=StringBuffer('<svg xmlns="http://www.w3.org/2000/svg" '
   'width="$width" height="160" viewBox="0 0 $width 160">');
  for(var i=0;i<4;i++){
   final y=20+i*36;
   out.write('<line x1="20" x2="${width-12}" y1="$y" y2="$y" '
    'stroke="#E4EBE7" stroke-width="1"/>');
  }
  for(var i=0;i<count;i++){
   final center=33+(width-60)*(i+.5)/count;
   for(var j=0;j<2;j++){
    final amount=j==0?values[i].$1:values[i].$2;
    final height=(amount/maximum*117).clamp(0.0,117.0);
    final x=center+(j==0?-13:2);
    out.write('<rect x="${x.toStringAsFixed(1)}" '
     'y="${(138-height).toStringAsFixed(1)}" '
     'width="11" height="${height.toStringAsFixed(1)}" rx="3" '
     'fill="${j==0?'#075C40':'#FF5722'}"/>');
   }
  }
  out.write('</svg>');
  return out.toString();
 }
 // M687: PDF exporter moved to a same-library State extension.
 /// Only the independently selected SQLCipher source may use the encrypted
 /// 30-day trash. A successful delete/undo MUST be reread from the verified
 /// authority before any balance or transaction tile changes on screen.
 // M780: original verified ledger deletion/undo and source publication moved to registered Home part.
 // M781: original Home transaction cards/details/actions moved to registered same-library part.
}

part of 'main.dart';

/// M691 / #633: byte-identical budget, monthly summary and financial insight
/// presentation methods moved from the same State. No finance writers changed.
extension _WaffraHomeBudgetCardsModule on _HomeScreenState {
 Widget monthlyBudgetCard(){
  final today=DateTime.now();
  final viewedMonth=DateTime(budgetViewedMonth.year,budgetViewedMonth.month,1);
  final viewingToday=viewedMonth.year==today.year&&viewedMonth.month==today.month;
  final selectedFinancialAccount=_m467SelectedAccount;
  // Read only the month visible in Budgets, not the full ledger.
  final relevantEntries=_m684ScopedMonthEntries(
   viewedMonth.year,viewedMonth.month);
  final monthEntries=relevantEntries;
  // A shared legacy budget belongs to All only until its owner explicitly
  // assigns an account. One budget ID is counted once, never once per bank.
  final allBudgets=namedBudgets.where((b)=>b.budget>0&&!b.deleted&&
   (selectedFinancialAccount=='all'||
    b.assignedAccountId==selectedFinancialAccount)).toList();
  // Overall monthly budget is a projection, not an additional saved cap.
  // Paused budgets remain part of the total the user has created.
  final overallLimit=allBudgets.fold<double>(0,(total,c)=>total+c.budget);
  final linkedIds=allBudgets.map((c)=>c.id).toSet();
  final overallSpent=monthEntries.where((e)=>!e.income&&
   e.budgetId!=null&&linkedIds.contains(e.budgetId))
   .fold<double>(0,(total,e)=>total+e.amount);
  final named=allBudgets.where((c)=>
   budgetStatusFilter=='all'||(budgetStatusFilter=='active'?
    c.budgetActive:!c.budgetActive)).toList();
  final selectedRows=named.where((c)=>c.id==selectedNamedBudgetCategoryId).toList();
  final selected=selectedRows.isEmpty?null:selectedRows.single;
  final limit=selected?.budget??overallLimit;
  // Selecting a paused budget must never show it as active or start
  // charging it again; its former limit and historical links remain.
  final spent=selected==null?overallSpent:
   waffraNamedBudgetSpent(relevantEntries.toList(),categories,selected,viewedMonth);
  final used=limit>0?(spent/limit).clamp(0.0,1.0):0.0;
  // Read-only projection. Missing/invalid source amounts must never be
  // converted or rewritten just to display a forecast.
  WaffraBudgetPace? pace;
  if(limit>0&&viewingToday){
   try{
    pace=WaffraBudgetPace(
     spentMinor:waffraSarMinorChecked(spent),
     limitMinor:waffraSarMinorChecked(limit),
     dayOfPeriod:today.day,
     daysInPeriod:DateTime(today.year,today.month+1,0).day);
   }catch(_){/* Hide unverified forecast; ledger is unchanged. */}
  }
  final alertAt=selected?.alertPercent??80;
  return Container(
   padding:const EdgeInsets.all(15),
   decoration:BoxDecoration(color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(20),
    border:Border.all(color:forest.withValues(alpha:0.10)),
    boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:0.04),
     blurRadius:8,offset:const Offset(0,3))]),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    InkWell(
     key:const Key('waffra-month-budget-expand-toggle'),
     borderRadius:BorderRadius.circular(12),
     onTap:WaffraHaptics.tap(()=>setState(()=>(monthlyBudgetDetailsOpen=!monthlyBudgetDetailsOpen))),
     child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[
      const Icon(Icons.donut_large,color:emerald,size:23),
      const SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(waffraIsEnglish?'Monthly budgets':'الميزانيات الشهرية',
        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
       const SizedBox(height:3),
       WaffraText(waffraIsEnglish?
        '${allBudgets.length} saved budgets':'${allBudgets.length} ميزانية مضافة',
        maxLines:2,style:const TextStyle(fontSize:12,color:Colors.grey)),
      ])),
      Icon(monthlyBudgetDetailsOpen?
       Icons.keyboard_arrow_up_rounded:Icons.keyboard_arrow_down_rounded,
       color:emerald,size:26),
     ]))),
    if(monthlyBudgetDetailsOpen)...[
    const SizedBox(height:12),
    Container(
     key:const Key('waffra-budget-month-control'),
     padding:const EdgeInsets.symmetric(horizontal:5,vertical:4),
     decoration:BoxDecoration(
      color:emerald.withValues(alpha:.065),
      borderRadius:BorderRadius.circular(16),
      border:Border.all(color:emerald.withValues(alpha:.19))),
     child:Row(children:[
      IconButton(
       key:const Key('waffra-budget-month-prev'),
       tooltip:waffraIsEnglish?'Previous month':'الشهر السابق',
       style:IconButton.styleFrom(
        minimumSize:const Size(40,42),
        padding:const EdgeInsets.all(6)),
       icon:const Icon(Icons.chevron_left_rounded,color:emerald,size:23),
       onPressed:WaffraHaptics.tap(()=>setState(()=>
        budgetViewedMonth=DateTime(viewedMonth.year,viewedMonth.month-1,1)))),
      Expanded(child:Semantics(
       label:waffraIsEnglish?'Viewing budget month':'شهر الميزانية المعروض',
       value:MaterialLocalizations.of(context).formatMonthYear(viewedMonth),
       child:Center(child:WaffraText(
        MaterialLocalizations.of(context).formatMonthYear(viewedMonth),
        key:const Key('waffra-budget-month-label'),
        maxLines:1,textAlign:TextAlign.center,
        style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))))),
      IconButton(
       key:const Key('waffra-budget-month-next'),
       tooltip:waffraIsEnglish?'Next month':'الشهر التالي',
       style:IconButton.styleFrom(
        minimumSize:const Size(40,42),
        padding:const EdgeInsets.all(6)),
       icon:const Icon(Icons.chevron_right_rounded,color:emerald,size:23),
       onPressed:WaffraHaptics.tap(()=>setState(()=>
        budgetViewedMonth=DateTime(viewedMonth.year,viewedMonth.month+1,1)))),
      const SizedBox(width:5),
      OutlinedButton(
       key:const Key('waffra-budget-month-today'),
       onPressed:viewingToday?null:WaffraHaptics.tap(()=>setState(()=>
        budgetViewedMonth=DateTime(today.year,today.month,1))),
       style:OutlinedButton.styleFrom(
        minimumSize:const Size(53,40),
        padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
        backgroundColor:Theme.of(context).cardColor,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
       child:WaffraText(waffraIsEnglish?'Today':'اليوم',
        maxLines:1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))),
     ]),
    ),
    const SizedBox(height:12),
    LayoutBuilder(builder:(context,box){
     final compact=box.maxWidth<290||
      MediaQuery.textScalerOf(context).scale(16)>22;
     final label=WaffraText(
      waffraIsEnglish?'Budget overview':'متابعة الميزانيات',
      maxLines:2,style:const TextStyle(
       fontWeight:FontWeight.bold,fontSize:16));
     final add=TextButton.icon(
      key:const Key('waffra-budget-create-action'),
      style:TextButton.styleFrom(minimumSize:const Size(0,48),
       padding:const EdgeInsets.symmetric(horizontal:8,vertical:8),
       tapTargetSize:MaterialTapTargetSize.padded),
      onPressed:WaffraHaptics.tap(()=>chooseBudgetCategory()),
      icon:const Icon(Icons.add_rounded,size:18),
      label:WaffraText(waffraIsEnglish?'Add budget':'إضافة ميزانية',
       maxLines:2,style:const TextStyle(fontSize:13)));
     return compact?
      Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       label,const SizedBox(height:6),
       Align(alignment:AlignmentDirectional.centerStart,child:add),
      ]):
      Row(children:[
       Expanded(child:label),const SizedBox(width:8),add,
      ]);
    }),
    const SizedBox(height:8),
    WaffraCenteredDropdownFormField<String>(
     key:ValueKey('waffra-budget-status-filter-'+budgetStatusFilter),
     initialValue:budgetStatusFilter,
     isExpanded:true,
     decoration:InputDecoration(
      labelText:waffraIsEnglish?'Budget status':'حالة الميزانيات',
      border:const OutlineInputBorder(),
      contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:12)),
     items:[
      DropdownMenuItem(value:'all',
       child:WaffraText(waffraIsEnglish?'All budgets':'كل الميزانيات')),
      DropdownMenuItem(value:'active',
       child:WaffraText(waffraIsEnglish?'Active budgets':'الميزانيات الفعّالة')),
      DropdownMenuItem(value:'inactive',
       child:WaffraText(waffraIsEnglish?'Paused budgets':'الميزانيات غير الفعّالة')),
     ],
     onChanged:WaffraHaptics.selection((status){
      if(status==null)return;
      setState((){
       budgetStatusFilter=status;
       selectedNamedBudgetCategoryId=null;
      });
     }),
    ),
    const SizedBox(height:14),
    WaffraCenteredDropdownFormField<String>(
     key:ValueKey('waffra-budget-picker-'+(selected?.id??'all')),
     menuMaxHeight:min(340.0,MediaQuery.sizeOf(context).height*.48),
     initialValue:selected?.id??'all',isExpanded:true,
     decoration:InputDecoration(labelText:waffraIsEnglish?'Choose budget':'اختر الميزانية',
      border:const OutlineInputBorder(),
      contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:8)),
     items:[
      DropdownMenuItem(value:'all',child:WaffraText(waffraIsEnglish?
       'Overall monthly budget':'الميزانية الشهرية العامة')),
      ...named.map((c)=>DropdownMenuItem(value:c.id,
       child:WaffraText((c.budgetLabel??'ميزانية '+c.displayName)+
        (c.budgetActive?'':(waffraIsEnglish?' (paused)':' (متوقفة)')),
        maxLines:1))),
     ],
     onChanged:WaffraHaptics.selection((v)=>setState(
       ()=>selectedNamedBudgetCategoryId=v=='all'?null:v)),
    ),
    if(selected!=null&&!selected.budgetActive)
     Padding(padding:const EdgeInsets.symmetric(vertical:9),
      child:WaffraText(waffraIsEnglish?
       'Paused budget — manage it under Categories > My Budgets.':
       'الميزانية متوقفة — تقدر تديرها من الأقسام ← ميزانياتي.',
       style:const TextStyle(fontSize:12,color:Colors.deepOrange))),
    const SizedBox(height:7),
    if(limit>0)...[
     WaffraText(waffraIsEnglish?
      'Used '+(used*100).toStringAsFixed(0)+'% of your budget':
      'تم إنفاق '+(used*100).toStringAsFixed(0)+'٪ من ميزانيتك',
      style:const TextStyle(fontSize:13)),
     const SizedBox(height:8),
     ClipRRect(borderRadius:BorderRadius.circular(12),
      child:LinearProgressIndicator(value:used,minHeight:9,
       backgroundColor:emerald.withValues(alpha:0.10),
       valueColor:AlwaysStoppedAnimation<Color>(
        spent>=limit?Colors.deepOrange:emerald))),
     const SizedBox(height:14),
     Row(children:[
      Expanded(child:_budgetFigure(waffraIsEnglish?'Budget':'الميزانية',limit)),
      Expanded(child:_budgetFigure(waffraIsEnglish?'Spent':'المصروف',spent)),
      Expanded(child:_budgetFigure(spent>limit?(waffraIsEnglish?'Over budget':'التجاوز'):(waffraIsEnglish?'Remaining':'المتبقي'),
       (limit-spent).abs())), 
     ]),
     if(selected!=null&&selected.budgetActive&&selected.alertsEnabled&&
       spent>=limit*alertAt/100)Padding(
      padding:const EdgeInsets.only(top:10),
      child:WaffraText(waffraIsEnglish?
       (spent>limit?'Monthly budget exceeded by ${cash(spent-limit)}.':spent==limit?'Monthly budget fully used.':'Budget warning: ${alertAt}% threshold reached.'):
       (spent>limit?'تجاوزت الميزانية الشهرية بمبلغ ${cash(spent-limit)}.':spent==limit?'استهلكت الميزانية الشهرية بالكامل.':'تنبيه الميزانية: وصلت إلى حد ${alertAt}٪.'),
       style:const TextStyle(color:Colors.deepOrange,fontSize:13))),
     if(pace?.projectedOverBudget==true && spent<limit&&
        (selected==null||(selected.budgetActive&&selected.alertsEnabled)))
      Padding(padding:const EdgeInsets.only(top:6),
       child:WaffraText(waffraIsEnglish?
         'At the current spending pace, this month may exceed the limit.':
         'حسب متوسط الصرف الحالي، ممكن تتجاوز الميزانية قبل نهاية الشهر.',
         style:const TextStyle(fontSize:12,color:Colors.deepOrange))),
    ]else Padding(padding:const EdgeInsets.symmetric(vertical:7),
     child:WaffraText(selected!=null&&!selected.budgetActive?
       (waffraIsEnglish?
        'This named budget is paused; its original amount and historical links are preserved.':
        'الميزانية متوقفة؛ حدّها وروابط العمليات القديمة محفوظة.'):
       (waffraIsEnglish?
        'Set your monthly budget to track spending here.':
        'حدّد ميزانية شهرية عشان تتابع مصروفاتك والمتبقي منها.'),
      style:const TextStyle(fontSize:14,color:Colors.grey))),
    ],
   ]));
 }
 Widget _budgetFigure(String label,double amount)=>Column(
  mainAxisSize:MainAxisSize.min,children:[
   WaffraText(label,textAlign:TextAlign.center,
    style:const TextStyle(color:Colors.grey,fontSize:12)),
   const SizedBox(height:5),
   FittedBox(fit:BoxFit.scaleDown,
    child:WaffraCurrencyAmount(amount,fontSize:16,color:emerald)),
  ]);
 Widget monthlySummaryCard(){
  final now=DateTime.now();
  final month=_m684ScopedMonthEntries(now.year,now.month);
  final income=sum(month,true),spent=sum(month,false);
  final difference=income-spent;
  final ratio=income>0?(spent/income).clamp(0.0,1.0):0.0;
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(
   key:const Key('m549-monthly-summary-compact'),
   padding:const EdgeInsets.symmetric(horizontal:12,vertical:11),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(18),
    border:Border.all(color:forest.withValues(alpha:.13))),
   child:Column(children:[
    Row(children:[
     const Icon(Icons.bar_chart_rounded,color:emerald,size:20),
     const SizedBox(width:5),
     Expanded(child:WaffraText(waffraIsEnglish?
      'This month summary':'ملخص هذا الشهر',
      style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold))),
    ]),
    const SizedBox(height:6),
    // M611: full-width account filter wraps long bank and child names.
    SizedBox(width:double.infinity,child:OutlinedButton.icon(
     key:const Key('m549-home-account-filter'),
     onPressed:WaffraHaptics.tap(()=>unawaited(_m467PickHomeAccount())),
     icon:const Icon(Icons.account_balance_outlined,size:17),
     label:Text(_m467AccountLabel,softWrap:true,textAlign:TextAlign.center,
      style:const TextStyle(fontSize:12)),
     style:OutlinedButton.styleFrom(
      padding:const EdgeInsets.symmetric(horizontal:8,vertical:6),
      minimumSize:const Size(0,42),
      foregroundColor:dark?Colors.white:forest))),
    const SizedBox(height:8),
    Row(children:[
     SizedBox(width:92,height:92,child:Stack(alignment:Alignment.center,children:[
      SizedBox(width:82,height:82,child:CircularProgressIndicator(
       value:ratio,strokeWidth:10,
       color:emerald,backgroundColor:const Color(0xFFD6EEDF))),
      Column(mainAxisSize:MainAxisSize.min,children:[
       WaffraText(waffraIsEnglish?'Difference':'الفرق',
        style:const TextStyle(fontSize:10)),
       // Bound the actual currency glyphs, not just the outer circle.
       // The old unbounded Column child never gave FittedBox a width to
       // scale against, clipping long RTL values on narrow Android screens.
       SizedBox(key:const Key('m584-monthly-summary-circle-value'),
        width:74,height:27,
        child:FittedBox(fit:BoxFit.scaleDown,
         alignment:Alignment.center,
         child:Directionality(textDirection:TextDirection.ltr,
          child:WaffraCurrencyAmount(difference,fontSize:16)))),
      ]),
     ])),
     const SizedBox(width:12),
     Expanded(child:Column(children:[
      Container(
       padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
       decoration:BoxDecoration(color:dark?const Color(0xFF244C3A):
        const Color(0xFFE4F4EB),borderRadius:BorderRadius.circular(12)),
       child:Row(children:[
        const Icon(Icons.south_west_rounded,color:emerald,size:17),
        const SizedBox(width:6),
        Expanded(child:WaffraText(waffraIsEnglish?'Income':'الدخل',
         style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))),
        WaffraCurrencyAmount(income,fontSize:13),
       ])),
      const SizedBox(height:6),
      Container(
       padding:const EdgeInsets.symmetric(horizontal:11,vertical:8),
       decoration:BoxDecoration(color:dark?const Color(0xFF49302C):
        const Color(0xFFFCECE8),borderRadius:BorderRadius.circular(12)),
       child:Row(children:[
        const Icon(Icons.north_east_rounded,color:Color(0xFFB94838),size:17),
        const SizedBox(width:6),
        Expanded(child:WaffraText(waffraIsEnglish?'Expenses':'المصروفات',
         style:const TextStyle(fontWeight:FontWeight.bold,fontSize:12))),
        WaffraCurrencyAmount(spent,fontSize:13),
       ])),
      const SizedBox(height:4),
      Text(waffraIsEnglish?'Spending / income':
       'نسبة المصروفات من الدخل: '+(income>0?(spent/income*100).toStringAsFixed(0):'0')+'%',
       style:const TextStyle(fontSize:10,color:Color(0xFF718077))),
     ])),
    ]),
   ]));
 }
 Widget smartMoneyInsightsCard(){
  final now=DateTime.now();
  final monthExpenses=entries.where((e)=>!e.income&&e.date.year==now.year&&e.date.month==now.month);
  final spent=sum(monthExpenses,false);
  final variableSpent=sum(monthExpenses.where((e)=>!e.id.startsWith('rec_')),false);
  final remaining=DateTime(now.year,now.month+1,0).day-now.day;
  final pending=recurring.where((r){
   if(!r.active)return false;
   final due=r.linkedGoalId==null
    ?WaffraRecurringPolicy.dueDate(now.year,now.month,r.day)
    :DateTime(r.startAt.year,r.startAt.month,r.startAt.day);
   return WaffraFinancialInsights.pendingCurrentMonth(
    now:now,startAt:r.startAt,day:r.day,
    goalLinked:r.linkedGoalId!=null,
    alreadyPaid:entries.any((e)=>
     e.id==WaffraRecurringPolicy.entryId(r.id,due)));
  });
  final pendingIncome=pending.where((r)=>r.income).fold<double>(0,(v,r)=>v+r.amount);
  final pendingExpense=pending.where((r)=>!r.income).fold<double>(0,(v,r)=>v+r.amount);
  final balance=waffraAvailableCash(entries,goals);
  final projection=WaffraFinancialInsights.projectedEndBalance(
   currentBalance:balance,variableExpensesSoFar:variableSpent,daysElapsed:now.day,
   daysInMonth:DateTime(now.year,now.month+1,0).day,
   pendingRecurringIncome:pendingIncome,pendingRecurringExpense:pendingExpense);
  // The old separately-entered monthly cap is legacy-only. Daily allowance
  // follows the active user-created budgets and their explicitly linked spend.
  final activeBudgets=namedBudgets.where((b)=>
   b.budget>0&&b.budgetActive&&!b.deleted).toList();
  final activeCap=activeBudgets.fold<double>(0,(v,c)=>v+c.budget);
  final activeIds=activeBudgets.map((c)=>c.id).toSet();
  final activeBudgetSpent=monthExpenses.where((e)=>
   e.budgetId!=null&&activeIds.contains(e.budgetId))
   .fold<double>(0,(v,e)=>v+e.amount);
  final daily=WaffraFinancialInsights.dailyAllowance(
   monthlyBudget:activeCap,spent:activeBudgetSpent,daysRemaining:remaining+1);
  final prev=DateTime(now.year,now.month-1);
  final prevTotal=sum(entries.where((e)=>!e.income&&e.date.year==prev.year&&e.date.month==prev.month),false);
  final delta=WaffraFinancialInsights.comparisonPercent(spent,prevTotal);
  final warnings=namedBudgets.where((b)=>!b.deleted&&b.budget>0&&b.budgetActive&&b.alertsEnabled&&
   WaffraFinancialInsights.reachedBudgetThreshold(
    spent:waffraNamedBudgetSpent(entries,categories,b,now),
    budget:b.budget,alertPercent:b.alertPercent)).toList();
  return Card(
   elevation:1.0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(21)),
   child:Padding(padding:const EdgeInsets.all(15),child:Column(
    crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.auto_graph,color:emerald),const SizedBox(width:7),
     Expanded(child:WaffraText(waffraIsEnglish?'Your smart financial snapshot':'نظرتك المالية الذكية',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),
    ]),
    const SizedBox(height:12),
    Row(children:[
     Expanded(child:_summaryBox(waffraIsEnglish?'End-of-month estimate':'الرصيد المتوقع آخر الشهر',
      cash(projection),Icons.trending_up,emerald)),
     const SizedBox(width:8),
     Expanded(child:_summaryBox(waffraIsEnglish?'Daily spending limit':'الحد اليومي المقترح',
      activeCap>0?cash(daily):(waffraIsEnglish?'Set a budget':'حدد ميزانية'),
      Icons.today_outlined,Colors.deepOrange)),
    ]),
    const SizedBox(height:9),
    if(delta!=null)WaffraText(waffraIsEnglish?
     'Monthly comparison: spending ${delta>=0?'up':'down'} ${delta.abs().toStringAsFixed(1)}%':
     'مقارنة بالشهر السابق: المصروفات ${delta>=0?'زادت':'قلت'} ${delta.abs().toStringAsFixed(1)}٪',
     style:const TextStyle(fontSize:12)),
    if(warnings.isNotEmpty)Padding(padding:const EdgeInsets.only(top:9),
     child:WaffraText(waffraIsEnglish?
      'Budget warning: ${warnings.map((c)=>c.name).join('، ')}':
      'تنبيه: اقتربت ميزانية ${warnings.map((c)=>c.name).join('، ')} من النفاد',
      style:const TextStyle(color:Colors.deepOrange,fontWeight:FontWeight.bold,fontSize:12))),
    const SizedBox(height:9),
    WaffraText(waffraIsEnglish?
     'Estimate based on recorded spending and upcoming recurring transactions, not a guaranteed balance.':
     'التوقع تقديري بناءً على الصرف المسجل والعمليات المتكررة القادمة، وليس رصيدًا مضمونًا.',
     style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
   ])));
 }
}

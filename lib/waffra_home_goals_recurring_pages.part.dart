part of 'main.dart';

/// M707 / #633/#635: byte-identical owner-approved Goals/Recurring real pages.
/// Verified SQLCipher source and every user action stay in the parent Home State.
extension _WaffraHomeGoalsRecurringPagesModule on _HomeScreenState {
 Widget goalsPage(){
  final target=goals.fold<double>(0,(v,g)=>v+g.target);
  final saved=goals.fold<double>(0,(v,g)=>v+g.saved);
  final today=DateUtils.dateOnly(DateTime.now());
  bool goalPass(SavingGoal g,String filter){
   final complete=g.target>0&&g.saved>=g.target;
   final due=g.dueDate==null?null:DateUtils.dateOnly(g.dueDate!);
   final delta=due?.difference(today).inDays;
   return switch(filter){
    'active'=>g.active,
    'inactive'=>!g.active,
    'done'=>complete,
    'incomplete'=>!complete,
    'week'=>delta!=null&&delta>=0&&delta<=7,
    'month'=>due!=null&&due.year==today.year&&due.month==today.month,
    _=>true,
   };
  }
  const filterValues=<String>['all','active','inactive','done','incomplete','week','month'];
  final goalCounts=<String,int>{
   for(final filter in filterValues)
    filter:goals.where((g)=>goalPass(g,filter)).length,
  };
  String filterLabel(String filter)=>switch(filter){
   'active'=>waffraIsEnglish?'Active':'نشطة',
   'inactive'=>waffraIsEnglish?'Inactive':'غير نشطة',
   'done'=>waffraIsEnglish?'Completed':'مكتملة',
   'incomplete'=>waffraIsEnglish?'Incomplete':'غير مكتملة',
   'week'=>waffraIsEnglish?'This week':'هذا الأسبوع',
   'month'=>waffraIsEnglish?'This month':'هذا الشهر',
   _=>waffraIsEnglish?'All':'الكل',
  };
  final filtered=goals.where((g)=>
   goalPass(g,goalDisplay)&&
   waffraSearchAny([g.name,waffraTr(g.name)],goalSearch)).toList();
  final ordered=filtered.toList()..sort((a,b){
   if(a.active!=b.active)return a.active?-1:1;
   final pa=a.target>0?(a.saved/a.target).clamp(0.0,1.0):0.0;
   final pb=b.target>0?(b.saved/b.target).clamp(0.0,1.0):0.0;
   final result=pb.compareTo(pa);
   if(result!=0)return result;
   return (a.dueDate??DateTime(9999))
    .compareTo(b.dueDate??DateTime(9999));
  });
  return Scrollbar(
   controller:_goalsScrollController,thumbVisibility:true,
   thickness:3,radius:const Radius.circular(8),
   child:ListView(controller:_goalsScrollController,
    physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
    padding:const EdgeInsets.fromLTRB(12,14,12,28),children:[
     WaffraApprovedPageHero(
      title:waffraIsEnglish?'Savings goals':'أهداف الادخار',
      subtitle:waffraIsEnglish?'Turn dreams into clear goals and follow your progress':
       'حوّل أحلامك إلى أهداف ملموسة وتابع تقدمك بسهولة ووضوح.',
      icon:Icons.flag_outlined),
     const SizedBox(height:12),
     WaffraApprovedMetrics(metrics:[
      WaffraApprovedMetric(waffraIsEnglish?'Total targets':'إجمالي المستهدفات',
       cash(target),Icons.trending_up_rounded,
        valueWidget:WaffraCurrencyAmount(target,fontSize:17)),
      WaffraApprovedMetric(waffraIsEnglish?'Total saved':'إجمالي المدخرات',
       cash(saved),Icons.toll_outlined,
        valueWidget:WaffraCurrencyAmount(saved,fontSize:17)),
      WaffraApprovedMetric(waffraIsEnglish?'Active goals':'أهداف نشطة',
       goals.where((g)=>g.active).length.toString(),Icons.track_changes),
     ]),
     const SizedBox(height:12),
     // M938: accurate status/due counts, grouped in one filter funnel.
     // The independent 3-dot menu contains Deleted/Inactive goal actions.
     SingleChildScrollView(scrollDirection:Axis.horizontal,
      child:Row(children:[
       SizedBox(width:118,child:WaffraOutlinedItemsCount(
        label:waffraIsEnglish?'Goals':'الأهداف',count:goals.length)),
       const SizedBox(width:6),
       PopupMenuButton<String>(
        key:const Key('m938-goals-filter-menu'),
        tooltip:waffraIsEnglish?'Filter goals':'فلترة الأهداف',
        child:Container(
         key:const Key('m945-goals-filter-dropdown'),
         padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
         decoration:BoxDecoration(border:Border.all(color:emerald),
          borderRadius:BorderRadius.circular(24)),
         child:Row(mainAxisSize:MainAxisSize.min,children:[
          WaffraText(filterLabel(goalDisplay),
           style:const TextStyle(fontWeight:FontWeight.bold,color:forest)),
          const SizedBox(width:5),
          WaffraText('(${goalCounts[goalDisplay]??0})',
           style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
          const SizedBox(width:5),
          const Icon(Icons.keyboard_arrow_down_rounded,color:emerald,size:20),
         ])),
        onSelected:(v)=>setState(()=>goalDisplay=v),
        itemBuilder:(ctx)=>[
         for(final filter in filterValues)
          PopupMenuItem<String>(key:Key('m938-goal-filter-'+filter),
           value:filter,child:Row(children:[
            Expanded(child:WaffraText(filterLabel(filter))),
            Text('${goalCounts[filter]??0}',style:const TextStyle(
             color:emerald,fontWeight:FontWeight.bold)),
            if(goalDisplay==filter)...[
             const SizedBox(width:6),
             const Icon(Icons.check_rounded,color:emerald,size:17),
            ],
           ])),
        ]),
       IconButton(key:const Key('m689-goals-search-toggle'),
        tooltip:waffraIsEnglish?'Search goals':'بحث عن هدف',
        onPressed:()=>setState(()=>_m689GoalSearchOpen=!_m689GoalSearchOpen),
        icon:const Icon(Icons.search_rounded,color:emerald)),
       PopupMenuButton<String>(
        key:const Key('m938-goals-more'),
        tooltip:waffraIsEnglish?'More goal actions':'المزيد من إجراءات الأهداف',
        icon:const Icon(Icons.more_vert_rounded,color:emerald),
        onSelected:(v){
         if(v=='trash')unawaited(deletedGoalsDialog());
        },
        itemBuilder:(ctx)=>[
         PopupMenuItem<String>(value:'trash',child:WaffraText(
          waffraIsEnglish?'Deleted goals':'الأهداف المحذوفة')),
        ]),
      ])),
     if(_m689GoalSearchOpen)...[
      const SizedBox(height:9),
      TextField(
       key:const Key('waffra-goals-search'),
       onChanged:(query)=>setState(()=>goalSearch=query),
       decoration:InputDecoration(
        hintText:waffraIsEnglish?'Search savings goals':'ابحث في أهداف الادخار',
        prefixIcon:const Icon(Icons.search_rounded),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
      ),
     ],
     const SizedBox(height:12),
     ...ordered.map((g){
      final percent=g.target<=0?0.0:(g.saved/g.target).clamp(0.0,1.0);
      final storedAccount=g.accountId==null?const <WaffraAccountBalance>[]:
       _m467Accounts.where((a)=>a.id==g.accountId&&!a.archived).toList();
      final accountName=storedAccount.length==1?storedAccount.single.name:
       (g.accountId==null?null:
        (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'));
      final completed=g.target>0&&g.saved>=g.target;
      final stateLabel=completed?
       (waffraIsEnglish?'Completed':'مكتمل'):
       g.active?(waffraIsEnglish?'Active':'نشط'):
       (waffraIsEnglish?'Paused':'متوقف');
      Widget amountColumn(String label,double money){
       return Expanded(child:Column(mainAxisSize:MainAxisSize.min,children:[
        WaffraText(label,style:const TextStyle(fontSize:11)),
        const SizedBox(height:3),
        SizedBox(width:double.infinity,child:FittedBox(
         fit:BoxFit.scaleDown,
         child:WaffraCurrencyAmount(money,fontSize:14,
          color:label==(waffraIsEnglish?'Saved':'المدخر')?emerald:null))),
       ]));
      }
      return Card(
       key:Key('m689-goal-card-'+g.id),
       margin:const EdgeInsets.only(bottom:12),
       elevation:0,color:Theme.of(context).cardColor,
       shape:RoundedRectangleBorder(
        borderRadius:BorderRadius.circular(21),
        side:BorderSide(color:Theme.of(context).brightness==Brightness.dark?
         const Color(0xFF456451):const Color(0xFFD1E1D9))),
       child:InkWell(
        key:Key('waffra-goal-quick-actions-'+g.id),
        borderRadius:BorderRadius.circular(21),
        onTap:WaffraHaptics.tap(()=>unawaited(_m689GoalActions(g))),
        child:Padding(padding:const EdgeInsets.all(12),
         child:Column(children:[
          Row(children:[
           WaffraIllustration(topic:g.name,size:44),
           const SizedBox(width:10),
           Expanded(child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
             WaffraText(g.name,maxLines:2,
              style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),
             if(accountName!=null)WaffraText(
              (waffraIsEnglish?'Linked account: ':'الحساب المرتبط: ')+accountName,
              maxLines:2,style:const TextStyle(fontSize:11,color:emerald)),
            ])),
           const SizedBox(width:6),
           WaffraApprovedStatusPill(label:stateLabel,
            icon:Icons.verified_outlined,attention:!g.active),
          ]),
          const SizedBox(height:13),
          Row(children:[
           Expanded(child:LinearProgressIndicator(
            value:percent,minHeight:9,
            borderRadius:BorderRadius.circular(8),color:emerald,
            backgroundColor:emerald.withValues(alpha:.12))),
           const SizedBox(width:9),
           Text(((percent*100).round()).toString()+'%',
            style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
          ]),
          const SizedBox(height:11),
          Row(children:[
           amountColumn(waffraIsEnglish?'Target':'المستهدف',g.target),
           Container(width:1,height:42,color:Theme.of(context).dividerColor),
           amountColumn(waffraIsEnglish?'Saved':'المدخر',g.saved),
           Container(width:1,height:42,color:Theme.of(context).dividerColor),
           amountColumn(waffraIsEnglish?'Remaining':'المتبقي',
            max(0,g.target-g.saved)),
          ]),
         ]))),
      );
     }),
     if(goals.isEmpty)Padding(padding:const EdgeInsets.all(28),
      child:Column(children:[
       const Icon(Icons.track_changes_rounded,size:48,color:emerald),
       const SizedBox(height:10),
       WaffraText(waffraIsEnglish?'No savings goals yet':'ما أضفت أي هدف ادخاري بعد',
        style:Theme.of(context).textTheme.titleLarge,textAlign:TextAlign.center),
      ])),
     if(goals.isNotEmpty&&filtered.isEmpty)Padding(
      padding:const EdgeInsets.all(28),
      child:WaffraText(waffraIsEnglish?'No goals match this filter':
       'لا توجد أهداف في هذا التصنيف',textAlign:TextAlign.center)),
     // Existing savings challenges remain accessible, after the goal cards.
     savingsChallengesSection(),
     const SizedBox(height:25),
    ]));
 }
 // M944: original recurring editor and linked-goal actions live in the recurring-workflows part.
 Widget recurringPage(){
  final today=DateUtils.dateOnly(DateTime.now());
  // One due amount per payable schedule, excluding income.
  final payable=recurring.where((r)=>!r.income);
  final dueTotal=payable.fold<double>(0,(v,r)=>v+r.amount);
  final dueActive=payable.where((r)=>r.active)
   .fold<double>(0,(v,r)=>v+r.amount);
  bool duePass(RecurringBill r,String filter){
   final date=DateUtils.dateOnly(
    r.linkedGoalId==null?nextRecurringDue(r):r.startAt);
   final days=date.difference(today).inDays;
   return switch(filter){
    'today'=>r.active&&days==0,
    'week'=>r.active&&days>=0&&days<=7,
    'month'=>date.year==today.year&&date.month==today.month,
    'overdue'=>r.active&&days<0,
    'active'=>r.active,
    'paused'=>!r.active,
    _=>true,
   };
  }
  const dueFilters=<String>['all','today','week','month','overdue','active','paused'];
  final dueCounts=<String,int>{
   for(final filter in dueFilters)
    filter:recurring.where((r)=>duePass(r,filter)).length,
  };
  String dueLabel(String filter)=>switch(filter){
   'today'=>waffraIsEnglish?'Today':'اليوم',
   'week'=>waffraIsEnglish?'This week':'هذا الأسبوع',
   'month'=>waffraIsEnglish?'This month':'هذا الشهر',
   'overdue'=>waffraIsEnglish?'Overdue':'متأخرة',
   'active'=>waffraIsEnglish?'Active':'نشطة',
   'paused'=>waffraIsEnglish?'Inactive':'غير نشطة',
   _=>waffraIsEnglish?'All':'الكل',
  };
  final shown=recurring.where((r)=>
   duePass(r,recurringDisplay)&&
   waffraSearchAny([r.title,r.category,waffraTr(r.category)],recurringSearch)
  ).toList()..sort((a,b){
   final aa=a.linkedGoalId==null?nextRecurringDue(a):a.startAt;
   final bb=b.linkedGoalId==null?nextRecurringDue(b):b.startAt;
   return aa.compareTo(bb);
  });
  return Scrollbar(
   controller:_recurringScrollController,thumbVisibility:true,
   thickness:3,radius:const Radius.circular(8),
   child:ListView(controller:_recurringScrollController,
    physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
    padding:const EdgeInsets.fromLTRB(12,14,12,28),children:[
     Row(children:[
      IconButton(
       tooltip:waffraIsEnglish?'Financial calendar':'التقويم المالي',
       onPressed:WaffraHaptics.tap(showWaffraFinancialCalendar),
       icon:const Icon(Icons.calendar_month_outlined,size:29,color:emerald)),
      const SizedBox(width:7),
      Expanded(child:WaffraText(waffraIsEnglish?'Due dates':'الاستحقاقات',
       style:const TextStyle(fontWeight:FontWeight.w800,fontSize:25))),
     ]),
     Padding(padding:const EdgeInsetsDirectional.only(start:5),
      child:WaffraText(waffraIsEnglish?
       'Your upcoming obligations and related transactions':
       'التزاماتك القادمة والعمليات المرتبطة بها',
       style:TextStyle(fontSize:12,color:Theme.of(context).hintColor))),
     const SizedBox(height:12),
     WaffraApprovedMetrics(metrics:[
      WaffraApprovedMetric(waffraIsEnglish?'Total dues':'إجمالي المستحقات',
       cash(dueTotal),Icons.payments_outlined,
       valueWidget:WaffraCurrencyAmount(dueTotal,fontSize:17)),
      WaffraApprovedMetric(waffraIsEnglish?'Active dues':'المستحقات النشطة',
       cash(dueActive),Icons.event_available_outlined,
       valueWidget:WaffraCurrencyAmount(dueActive,fontSize:17)),
      WaffraApprovedMetric(waffraIsEnglish?'Due items':'عدد الاستحقاقات',
       recurring.length.toString(),Icons.event_repeat_rounded),
     ]),
     const SizedBox(height:16),
     SingleChildScrollView(scrollDirection:Axis.horizontal,
      child:Row(children:[
       SizedBox(width:118,child:WaffraOutlinedItemsCount(
        label:waffraIsEnglish?'Due items':'الاستحقاقات',
        count:recurring.length)),
       const SizedBox(width:6),
       PopupMenuButton<String>(
        key:const Key('m938-dues-filter-menu'),
        tooltip:waffraIsEnglish?'Filter due dates':'فلترة الاستحقاقات',
        child:Container(
         key:const Key('m945-dues-filter-dropdown'),
         padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),
         decoration:BoxDecoration(border:Border.all(color:emerald),
          borderRadius:BorderRadius.circular(24)),
         child:Row(mainAxisSize:MainAxisSize.min,children:[
          WaffraText(dueLabel(recurringDisplay),
           style:const TextStyle(fontWeight:FontWeight.bold,color:forest)),
          const SizedBox(width:5),
          WaffraText('(${dueCounts[recurringDisplay]??0})',
           style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
          const SizedBox(width:5),
          const Icon(Icons.keyboard_arrow_down_rounded,color:emerald,size:20),
         ])),
        onSelected:(v)=>setState(()=>recurringDisplay=v),
        itemBuilder:(ctx)=>[
         for(final filter in dueFilters)
          PopupMenuItem<String>(key:Key('m938-due-filter-'+filter),
           value:filter,child:Row(children:[
            Expanded(child:WaffraText(dueLabel(filter))),
            Text('${dueCounts[filter]??0}',style:const TextStyle(
             color:emerald,fontWeight:FontWeight.bold)),
            if(recurringDisplay==filter)...[
             const SizedBox(width:6),
             const Icon(Icons.check_rounded,color:emerald,size:17),
            ],
           ])),
        ]),
       IconButton(
        key:const Key('m689-recurring-search-toggle'),
        tooltip:waffraIsEnglish?'Search due dates':'بحث في الاستحقاقات',
        onPressed:()=>setState(()=>_m689DueSearchOpen=!_m689DueSearchOpen),
        icon:const Icon(Icons.search_rounded,color:emerald)),
       PopupMenuButton<String>(
        key:const Key('m689-due-settings'),
        tooltip:waffraIsEnglish?'More due actions':'إجراءات إضافية',
        icon:const Icon(Icons.more_vert_rounded,color:emerald),
        onSelected:(v){
         if(v=='trash')unawaited(deletedRecurringDialog());
         if(v=='reminders')unawaited(toggleRecurringReminders(!recurringRemindersEnabled));
        },
        itemBuilder:(ctx)=>[
         PopupMenuItem(value:'trash',
          child:WaffraText(waffraIsEnglish?'Deleted recurring':'المتكررة المحذوفة')),
         PopupMenuItem(value:'reminders',
          child:WaffraText(recurringRemindersEnabled?
           (waffraIsEnglish?'Turn reminders off':'إيقاف التذكيرات'):
           (waffraIsEnglish?'Turn reminders on':'تفعيل التذكيرات'))),
        ]),
      ])),
     if(_m689DueSearchOpen)...[
      const SizedBox(height:10),
      TextField(key:const Key('waffra-recurring-search'),
       onChanged:(value)=>setState(()=>recurringSearch=value),
       decoration:InputDecoration(
        prefixIcon:const Icon(Icons.search_rounded),
        hintText:waffraIsEnglish?'Search due dates':'ابحث في الاستحقاقات',
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)))),
     ],
     const SizedBox(height:14),
     ...shown.map((r){
      final linked=goals.where((g)=>g.id==r.linkedGoalId).toList();
      final goal=linked.isEmpty?null:linked.single;
      final due=goal==null?nextRecurringDue(r):r.startAt;
      final settledId=WaffraRecurringPolicy.entryId(r.id,
       DateTime(r.startAt.year,r.startAt.month,r.startAt.day));
      final paid=entries.where((e)=>e.id==settledId&&
       e.sourceType=='goal_due').toList(growable:false);
      final paidGoalDue=goal!=null&&paid.length==1?paid.single:null;
      final activeAccounts=r.accountId==null?const <WaffraAccountBalance>[]:
       _m467Accounts.where((a)=>a.id==r.accountId&&!a.archived).toList();
      final accountLabel=activeAccounts.length==1?activeAccounts.single.name:
       (r.accountId==null?null:
        (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'));
      final savedDue=goal==null?0.0:min(r.amount,max(0,goal.saved));
      final remainingDue=max(0,r.amount-savedDue);
      final dueProgress=goal==null||r.amount<=0?0.0:
       (savedDue/r.amount).clamp(0.0,1.0);
      final status=paidGoalDue!=null?
       (waffraIsEnglish?'Paid goal due':'استحقاق هدف مدفوع'):
       goal!=null?(waffraIsEnglish?'Goal due':'استحقاق هدف'):
       r.income?(waffraIsEnglish?'Recurring income':'دخل متكرر'):
       (waffraIsEnglish?'Recurring expense':'مصروف متكرر');
      Widget amountLabel(String label,double amount){
       return Expanded(child:Column(children:[
        SizedBox(width:double.infinity,child:FittedBox(
         fit:BoxFit.scaleDown,child:WaffraCurrencyAmount(amount,fontSize:19)),
        WaffraText(label,style:const TextStyle(fontSize:11)),
       ]));
      }
      return Card(
       key:Key('m689-due-card-'+r.id),
       elevation:0,margin:const EdgeInsets.only(bottom:13),
       color:Theme.of(context).cardColor,
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22),
        side:BorderSide(color:const Color(0xFFD8BA78).withValues(alpha:.64))),
       child:Padding(padding:const EdgeInsets.all(13),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         Row(children:[
          WaffraIllustration(topic:goal?.name??r.title,size:43),
          const SizedBox(width:9),
          Expanded(child:WaffraText(r.title,maxLines:2,
           style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800))),
          WaffraApprovedStatusPill(label:status,
           icon:goal!=null?Icons.track_changes:Icons.event_repeat_rounded),
         ]),
         const SizedBox(height:14),
         Row(children:[
          amountLabel(waffraIsEnglish?'Due amount':'المبلغ المستحق',r.amount),
          Container(height:48,width:1,color:Theme.of(context).dividerColor),
          Expanded(child:Column(children:[
           WaffraText(dayText(due),textDirection:TextDirection.ltr,
            style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
           WaffraText(waffraIsEnglish?'Due date':'تاريخ الاستحقاق',
            style:const TextStyle(fontSize:11)),
          ])),
         ]),
         if(accountLabel!=null)...[
          const SizedBox(height:11),
          Row(children:[
           const Icon(Icons.account_balance_wallet_outlined,
            color:emerald,size:18),
           const SizedBox(width:6),
           Expanded(child:WaffraText(
            (waffraIsEnglish?'Linked account: ':'الحساب المرتبط: ')+accountLabel,
            maxLines:2,style:const TextStyle(
             color:emerald,fontWeight:FontWeight.w600,fontSize:12))),
          ]),
         ],
         if(goal!=null)...[
          const SizedBox(height:11),
          Container(
           padding:const EdgeInsets.all(9),
           decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(15),
            border:Border.all(color:Theme.of(context).dividerColor)),
           child:Column(children:[
            Row(children:[
             Expanded(child:WaffraText(
              (waffraIsEnglish?'Saved: ':'المدخر: ')+cash(savedDue),
              maxLines:2,style:const TextStyle(fontSize:12))),
             const SizedBox(width:6),
             Expanded(child:WaffraText(
              (waffraIsEnglish?'Remaining: ':'المتبقي: ')+cash(remainingDue),
              maxLines:2,style:const TextStyle(fontSize:12))),
            ]),
            const SizedBox(height:7),
            Row(children:[
             Expanded(child:LinearProgressIndicator(
              value:dueProgress,minHeight:8,
              borderRadius:BorderRadius.circular(8),
              backgroundColor:emerald.withValues(alpha:.12),
              color:emerald)),
             const SizedBox(width:7),
             WaffraText(((dueProgress*100).round()).toString()+'%',
              style:const TextStyle(fontWeight:FontWeight.w800,color:emerald)),
            ]),
           ])),
          if(paidGoalDue!=null)...[
           const SizedBox(height:7),
           WaffraText(waffraIsEnglish?
            'From goal wallet: '+cash(paidGoalDue.goalWalletPaidMinor/100):
            'من محفظة الهدف: '+cash(paidGoalDue.goalWalletPaidMinor/100),
            style:const TextStyle(color:emerald,fontSize:11)),
           WaffraText(waffraIsEnglish?
            'From money account: '+cash(waffraGoalDueCashMinor(paidGoalDue)/100):
            'من الحساب المالي: '+cash(waffraGoalDueCashMinor(paidGoalDue)/100),
            style:const TextStyle(color:emerald,fontSize:11)),
          ],
          const SizedBox(height:10),
          Row(children:[
           Expanded(child:TextButton.icon(
            onPressed:goal.active&&(goal.target<=0||goal.saved<goal.target)?
             WaffraHaptics.tap(()=>unawaited(fundGoal(goal))):null,
            icon:const Icon(Icons.bolt_outlined,size:17),
            label:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(
             waffraIsEnglish?'Quick deposit':'إيداع سريع',
             style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))))),
           Expanded(child:TextButton.icon(
            onPressed:WaffraHaptics.tap(
             ()=>unawaited(_handleGoalCardAction(goal,'edit'))),
            icon:const Icon(Icons.edit_outlined,size:17),
            label:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(
             waffraIsEnglish?'Edit goal':'تعديل الهدف',
             style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))))),
           Expanded(child:TextButton.icon(
            onPressed:WaffraHaptics.tap(()=>unawaited(openVerifiedAccounts())),
            icon:const Icon(Icons.account_balance_wallet_outlined,size:17),
            label:FittedBox(fit:BoxFit.scaleDown,child:WaffraText(
             waffraIsEnglish?'Account details':'تفاصيل الحساب',
             style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))))),
          ]),
         ]else...[
          const SizedBox(height:11),
          Row(children:[
           Expanded(child:TextButton.icon(
            key:Key('m665-recurring-edit-'+r.id),
            onPressed:WaffraHaptics.tap(
             ()=>unawaited(_handleRecurringCardAction(r,'edit'))),
            icon:const Icon(Icons.edit_outlined,size:17),
            label:WaffraText(waffraIsEnglish?'Edit':'تعديل'))),
           Expanded(child:TextButton.icon(
            onPressed:WaffraHaptics.tap(
             ()=>unawaited(_handleRecurringCardAction(r,'delete'))),
            icon:const Icon(Icons.delete_outline_rounded,size:17),
            label:WaffraText(waffraIsEnglish?'Delete':'حذف'))),
           Switch.adaptive(
            key:Key('waffra-recurring-active-switch-'+r.id),
            value:r.active,activeTrackColor:emerald,
            onChanged:WaffraHaptics.selection(
             (value)=>unawaited(_setRecurringActiveFromCard(r,value)))),
          ]),
         ],
        ])),
      );
     }),
     if(recurring.isEmpty)Card(
      key:const Key('m945-dues-empty-state'),
      elevation:0,color:Theme.of(context).cardColor,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),
       side:BorderSide(color:Theme.of(context).dividerColor)),
      child:Padding(padding:const EdgeInsets.symmetric(
       horizontal:20,vertical:28),child:Column(children:[
       const Icon(Icons.event_available_outlined,size:45,color:emerald),
       const SizedBox(height:11),
       WaffraText(waffraIsEnglish?'No due payments yet':
        'ما عندك استحقاقات حتى الآن',
        textAlign:TextAlign.center,
        style:const TextStyle(fontSize:17,fontWeight:FontWeight.bold)),
       const SizedBox(height:7),
       WaffraText(waffraIsEnglish?
        'Add a due date to track upcoming obligations, linked accounts and payments.':
        'أضف استحقاقًا لمتابعة الالتزامات القادمة والحسابات والعمليات المرتبطة بها.',
        textAlign:TextAlign.center),
       const SizedBox(height:14),
       OutlinedButton.icon(
        onPressed:WaffraHaptics.tap(()=>unawaited(recurringDialog())),
        icon:const Icon(Icons.add_rounded),
        label:WaffraText(waffraIsEnglish?'Add due date':'إضافة استحقاق')),
      ]))),
     if(recurring.isNotEmpty&&shown.isEmpty)Padding(
      padding:const EdgeInsets.all(26),
      child:WaffraText(waffraIsEnglish?
       'No items match this filter':'لا توجد عمليات في هذا التصنيف',
       textAlign:TextAlign.center)),
     if(_m468VerifiedAccountsLoaded&&
        recurring.any((r)=>r.linkedGoalId!=null))...[
      WaffraApprovedSectionTitle(waffraIsEnglish?
       'Linked transactions':'العمليات المرتبطة',
       icon:Icons.layers_outlined),
      WaffraText(waffraIsEnglish?
       'Only verified savings movements tied to these goals':
       'حركات الادخار المؤكدة المرتبطة بهذه الأهداف',
       style:TextStyle(color:Theme.of(context).hintColor,fontSize:11)),
      const SizedBox(height:8),
      FutureBuilder<List<WaffraVerifiedGoalMovement>>(
       future:_m649HomeSavings('all'),
       builder:(ctx,snapshot){
        if(snapshot.hasError)return WaffraText(waffraIsEnglish?
         'Savings history could not be verified. Refresh to retry.':
         'تعذر التحقق من حركات الادخار. أعد التحديث.');
        if(!snapshot.hasData)return const SizedBox(
         height:28,child:Center(child:CircularProgressIndicator(strokeWidth:2)));
        final goalIds=recurring.where((r)=>r.linkedGoalId!=null)
         .map((r)=>r.linkedGoalId).toSet();
        final movements=snapshot.data!.where(
         (m)=>goalIds.contains(m.goalId)).take(8).toList();
        if(movements.isEmpty)return WaffraText(waffraIsEnglish?
         'No linked savings movements yet':
         'لا توجد حركات ادخار مرتبطة مؤكدة بعد.');
        return Card(elevation:0,
         shape:RoundedRectangleBorder(
          borderRadius:BorderRadius.circular(18),
          side:BorderSide(color:Theme.of(context).dividerColor)),
         child:Column(children:[
          for(final movement in movements)ListTile(
           dense:true,
           leading:const Icon(Icons.toll_outlined,color:emerald),
           title:WaffraText(movement.goalName,maxLines:2),
           subtitle:WaffraText(movement.occurredIso.substring(0,10)),
           trailing:WaffraText(
            (movement.kind=='release'?'-':'+')+
             cash(movement.amountMinor/100),
            style:const TextStyle(fontWeight:FontWeight.bold,color:emerald)),
          ),
         ]));
       }),
     ],
     const SizedBox(height:20),
    ]));
 }
}

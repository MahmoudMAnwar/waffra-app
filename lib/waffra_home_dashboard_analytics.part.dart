part of 'main.dart';

/// M733 / #633: original production Home dashboard, forecast and financial
/// analytics methods moved together without changing calculations or UI.
extension _WaffraHomeDashboardAnalyticsModule on _HomeScreenState {
 Widget dashboard(){
  final scopedEntries=_m467ScopedEntries().toList();
  final unverifiedFxEntries=entries.where(waffraNeedsLegacyFxReview).toList();
  // Show the month comparison only when there are genuine prior-month
  // transactions and a positive comparison base. Never show a fake +12%.
  final nowBalanceDate=DateTime.now();
  final monthStart=DateTime(nowBalanceDate.year,nowBalanceDate.month);
  final priorMonthStart=DateTime(nowBalanceDate.year,nowBalanceDate.month-1);
  final hasPreviousMonthEntries=_m684Periods.month(
   priorMonthStart.year,priorMonthStart.month).isNotEmpty;
  final previousClosingBalance=waffraAvailableCash(
   _m684Periods.before(monthStart),goals);
  final monthChange=hasPreviousMonthEntries&&previousClosingBalance>0
   ?((waffraAvailableCash(entries,goals)-previousClosingBalance)/previousClosingBalance)*100:null;
  final visible=scopedEntries.where((e){
   final q=search.trim();
   return(waffraSearchAny([e.title,e.category,waffraTr(e.category)],q))&&
    (transactionsDateRange==null||(e.date.isAfter(transactionsDateRange!.start.subtract(const Duration(days:1)))&&e.date.isBefore(transactionsDateRange!.end.add(const Duration(days:1)))))&&
    (minTransactionAmount==null||e.amount>=minTransactionAmount!)&&
    (maxTransactionAmount==null||e.amount<=maxTransactionAmount!)&&
    (typeFilter=='الكل'||(typeFilter=='الدخل'&&e.income)||
     (typeFilter=='المصروفات'&&!e.income)||
     (typeFilter=='الاستحقاقات'&&
      (e.sourceType=='recurring'||e.sourceType=='goal_due')))&&
    (categoryFilter=='الكل'||categoryFilter==e.category);
  }).toList()..sort((a,b)=>b.date.compareTo(a.date));
  final filterCats=<String>{'الكل',...scopedEntries.where((e)=>typeFilter=='الكل'||
   (typeFilter=='الدخل'&&e.income)||(typeFilter=='المصروفات'&&!e.income)||
   (typeFilter=='الاستحقاقات'&&
    (e.sourceType=='recurring'||e.sourceType=='goal_due'))).map((e)=>e.category)}.toList();
  final selected=filterCats.contains(categoryFilter)?categoryFilter:'الكل';
  final shown=visible.take(waffraDashboardTransactionDisplayCount(
   visible.length,expanded:showAllTransactions)).toList();
  return RefreshIndicator(
   onRefresh:()=>_refreshAndSettle(_dashboardScrollController,0),
   child:NotificationListener<ScrollStartNotification>(
    onNotification:(notification){
     if(addFabExpanded){
      WidgetsBinding.instance.addPostFrameCallback((_){
       if(mounted&&addFabExpanded)setState(()=>addFabExpanded=false);
      });
     }
     return false;
    },
    child:CustomScrollView(
     controller:_dashboardScrollController,
     physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
     slivers:[
      SliverToBoxAdapter(child:Padding(
       padding:const EdgeInsets.fromLTRB(14,14,14,4),
       child:WaffraApprovedPageHero(
        title:greeting,
        subtitle:waffraIsEnglish?'Your finances at a glance':
         'تابع رصيدك ومعاملاتك وخططك المالية بسهولة.',
        icon:Icons.spa_outlined))),
      // Not pinned: the shrinking balance scrolls away without covering data.
      SliverPersistentHeader(
       pinned:false,
       delegate:WaffraBalanceHeader(
         balance:_m467ShownBalance(),english:waffraIsEnglish,
         heading:waffraIsEnglish?'Total balance':'إجمالي الرصيد',
         compact:true,
         monthlyChangePercent:_m467SelectedAccount=='all'&&
          _m467AccountContext==null?monthChange:null,
         refreshVerifiedWidgetBalance:_refreshWidget)),
      SliverPadding(padding:const EdgeInsets.fromLTRB(14,10,14,96),
       sliver:SliverToBoxAdapter(child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         if(_m467SelectedAccount=='all'&&_m468VerifiedAccountsLoaded&&
            _m467Accounts.isEmpty&&entries.isNotEmpty)...[
          Container(
           key:const Key('m620-accountless-legacy-net-explanation'),
           margin:const EdgeInsets.only(bottom:10),
           padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
           decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:emerald.withValues(alpha:.28))),
           child:WaffraText(waffraIsEnglish?
            'No active financial accounts exist, so verified account balance is 0. '
            'Net recorded transactions: ${cash(sum(entries,true)-sum(entries,false))}. '
            'This is NOT an available bank balance. Review accounts before linking old transactions.':
            'لا توجد حسابات مالية نشطة، لذلك رصيد الحسابات صفر. '
            'صافي العمليات المسجلة: ${cash(sum(entries,true)-sum(entries,false))}. '
            'هذا ليس رصيدًا بنكيًا متاحًا. راجع الحسابات قبل ربط العمليات القديمة.'),
          ),
         ],
         // M674 Home concept #1: data-backed navigation tiles, not new ledger writes.
         Row(key:const Key('m674-home-approved-shortcuts'),children:[
          WaffraApprovedDashboardLink(
           title:waffraIsEnglish?'Recurring':'المتكررة',
           count:recurring.where((r)=>r.active).length.toString(),
           icon:Icons.event_repeat_rounded,
           onTap:()=>unawaited(selectFooter(4))),
          const SizedBox(width:7),
          WaffraApprovedDashboardLink(
           title:waffraIsEnglish?'Goals':'الأهداف',
           count:goals.where((g)=>g.active).length.toString(),
           icon:Icons.track_changes_outlined,
           onTap:()=>unawaited(selectFooter(3))),
          const SizedBox(width:7),
          WaffraApprovedDashboardLink(
           title:waffraIsEnglish?'Accounts':'الحسابات',
           count:_m467Accounts.where((a)=>!a.archived).length.toString(),
           icon:Icons.account_balance_wallet_outlined,
           onTap:()=>unawaited(openVerifiedAccounts())),
         ]),
         const SizedBox(height:12),
         // M549: user-approved screenshot: three compact, equal-width
         // direct finance actions, no duplicated large income/expense tiles.
         // This is NOT the floating + and never changes its geometry.
         Row(key:const Key('m549-three-home-finance-actions'),children:[
          _m549HomeFinanceAction(
           title:waffraIsEnglish?'Income':'دخل',
           icon:Icons.south_west_rounded,
           background:const Color(0xFFE6F7EC),
           iconColor:const Color(0xFF087A54),
           onTap:()=>unawaited(showSummaryTransactions(true))),
          const SizedBox(width:7),
          _m549HomeFinanceAction(
           title:waffraIsEnglish?'Expense':'مصروف',
           icon:Icons.north_east_rounded,
           background:const Color(0xFFFCECE8),
           iconColor:const Color(0xFFB94838),
           onTap:()=>unawaited(showSummaryTransactions(false))),
          const SizedBox(width:7),
          _m549HomeFinanceAction(
           title:waffraIsEnglish?'Between my accounts':'تحويل بين حساباتي',
           icon:Icons.swap_horiz_rounded,
           background:const Color(0xFFFAF0DD),
           iconColor:const Color(0xFF7F561C),
           onTap:()=>unawaited(showInternalTransferTransactions())),
         ]),
         const SizedBox(height:10),
         monthlySummaryCard(),
         const SizedBox(height:10),
         Container(
          decoration:BoxDecoration(
           color:Theme.of(context).cardColor,
           borderRadius:BorderRadius.circular(16),
           border:Border.all(color:Theme.of(context).brightness==Brightness.dark
            ?const Color(0xFF506A5A):const Color(0xFFD3E3D9))),
          child:Column(mainAxisSize:MainAxisSize.min,children:[
           Semantics(button:true,toggled:quickActionsExpanded,
            child:InkWell(
             key:const Key('waffra-quick-actions-toggle'),
             borderRadius:BorderRadius.circular(16),
             onTap:WaffraHaptics.tap(
              ()=>setState(()=>quickActionsExpanded=!quickActionsExpanded)),
             child:Padding(
              padding:const EdgeInsets.symmetric(horizontal:13,vertical:12),
              child:Row(children:[
               const Icon(Icons.bolt_rounded,color:emerald,size:20),
               const SizedBox(width:7),
               Expanded(child:WaffraText(waffraIsEnglish?'Quick actions':'إجراءات سريعة',
                style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
               AnimatedRotation(
                turns:quickActionsExpanded ? 0.5 : 0.0,
                duration:waffraMotion(180),
                child:const Icon(Icons.keyboard_arrow_down_rounded,size:23)),
              ]))),
            ),
           AnimatedSize(
            duration:waffraMotion(200),alignment:Alignment.topCenter,
            curve:Curves.easeOutCubic,
            child:quickActionsExpanded
             ?Padding(padding:const EdgeInsets.fromLTRB(10,0,10,10),
               child:Row(children:[
                _dashboardShortcut(waffraIsEnglish?'Export report':'تصدير تقرير',
                 Icons.analytics_outlined,()=>exportEntriesPdf(entries,'تقرير عمليات وفرة')),
                const SizedBox(width:10),
                _dashboardShortcut(waffraIsEnglish?'Financial calendar':'التقويم المالي',
                 Icons.calendar_month_outlined,openFinancialCalendar),
               ]))
             :const SizedBox.shrink()),
          ])),
         // M549: the SMS review queue now lives in Notifications.
         if(unverifiedFxEntries.isNotEmpty)...[
          const SizedBox(height:10),
          Container(
           key:const Key('waffra-legacy-foreign-currency-review-warning'),
           padding:const EdgeInsets.all(12),
           decoration:BoxDecoration(
            color:Theme.of(context).colorScheme.errorContainer,
            borderRadius:BorderRadius.circular(12)),
           child:Row(children:[
            const Icon(Icons.warning_amber_rounded,size:21),
            const SizedBox(width:9),
            Expanded(child:WaffraText(waffraIsEnglish?
             '${unverifiedFxEntries.length} imported bank transaction(s) need currency review. Current totals may include unverified amounts.':
             'تحتاج ${unverifiedFxEntries.length} معاملة بنكية قديمة مراجعة العملة. قد تشمل الإجماليات مبالغ غير مؤكدة.',
             maxLines:3,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w600))),
           ])),
         ],
         const SizedBox(height:12),
         monthlyBudgetCard(),
         const SizedBox(height:12),

         Container(
          padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(
           color:Theme.of(context).cardColor,
           borderRadius:BorderRadius.circular(20),
           border:Border.all(color:forest.withValues(alpha:0.10))),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
           Row(children:[
            const Icon(Icons.receipt_long_outlined,color:emerald),
            const SizedBox(width:7),
            Expanded(child:WaffraText(waffraIsEnglish?
             'Your transactions':'عملياتك المالية',
             style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
           ]),
           // M689: the financial history and its tools are always mounted.
            if(waffraCanExpandDashboardTransactions(visible.length)&&
               (!_m468VerifiedAccountsLoaded||
                (typeFilter!='التحويلات'&&typeFilter!='الادخار'&&
                 typeFilter!='الكل')))
             Align(alignment:AlignmentDirectional.centerEnd,
              child:TextButton(
               key:const Key('waffra-dashboard-transactions-expand'),
               onPressed:WaffraHaptics.tap(
                ()=>setState(()=>showAllTransactions=!showAllTransactions)),
               child:WaffraText(showAllTransactions?
                (waffraIsEnglish?'Show less':'عرض أقل'):
                (waffraIsEnglish?'Show more':'عرض أكثر')))),
           const SizedBox(height:10),
           Divider(color:forest.withValues(alpha:0.10)),
           Row(children:[
            IconButton(
             tooltip:waffraIsEnglish?'Filter':'فلترة',
             onPressed:WaffraHaptics.tap(()=>setState(()=>showTransactionFilters=!showTransactionFilters)),
             icon:Icon(showTransactionFilters?
              Icons.filter_alt:Icons.filter_alt_outlined,color:emerald)),
            IconButton(
             tooltip:waffraIsEnglish?'Search':'بحث',
             onPressed:WaffraHaptics.tap(()=>setState((){
              showTransactionSearch=!showTransactionSearch;
              if(!showTransactionSearch)search='';
             })),icon:const Icon(Icons.search)),
            if(showTransactionSearch)Expanded(child:TextField(
             onChanged:(v)=>setState(()=>search=v),
             decoration:InputDecoration(isDense:true,
              hintText:waffraIsEnglish?'Search':'ابحث عن عملية',
              border:const OutlineInputBorder()))),
            if(!showTransactionSearch)const Spacer(),
            PopupMenuButton<String>(
             tooltip:waffraIsEnglish?'More actions':'المزيد من الخيارات',
             icon:const Icon(Icons.more_vert),
             onSelected:WaffraHaptics.selection((action){
              if(action=='delete-all')confirmDeleteAllEntries();
              if(action=='restore-transactions')_showVerifiedDeletedTransactions();
              if(action=='pdf')exportEntriesPdf(visible,'تقرير عمليات وفرة',activityFilter:typeFilter);
             }),
             itemBuilder:(ctx)=>[
              if(_lastFinanceAuthorityRead?.source==
                 WaffraRuntimeFinanceBackend.verifiedEncrypted)
               PopupMenuItem(value:'restore-transactions',child:Row(children:[
                const Icon(Icons.restore_rounded,color:emerald),
                const SizedBox(width:8),
                WaffraText(waffraIsEnglish?
                 'Recently deleted (30 days)':'المعاملات المحذوفة (30 يومًا)'),
               ])),
              PopupMenuItem(value:'pdf',child:Row(children:[
               const Icon(Icons.picture_as_pdf_outlined,color:emerald),
               const SizedBox(width:8),
               WaffraText(waffraIsEnglish?'Export PDF':'تصدير PDF'),
              ])),
              PopupMenuItem(value:'delete-all',enabled:entries.isNotEmpty,
               child:Row(children:[
                const Icon(Icons.delete_outline,color:Colors.red),
                const SizedBox(width:8),
                WaffraText(waffraIsEnglish?'Delete all transactions':'حذف كل المعاملات',
                 style:const TextStyle(color:Colors.red)),
               ])),
             ],
            ),
           ]),
           if(showTransactionFilters)...[
            const SizedBox(height:12),
            Wrap(
             key:const Key('waffra-activity-single-filter-chips'),
             spacing:10,runSpacing:12,
             children:['الكل','الدخل','المصروفات','التحويلات','الادخار','الاستحقاقات']
              .map((choice)=>ChoiceChip(
              selected:typeFilter==choice,
              label:WaffraText(waffraIsEnglish?switch(choice){
               'الدخل'=>'Income','المصروفات'=>'Expenses',
               'التحويلات'=>'Transfers','الادخار'=>'Savings',
               'الاستحقاقات'=>'Paid dues',
               _=>'All',
              }:choice),
              onSelected:WaffraHaptics.selection((_)=>setState((){
               typeFilter=choice;categoryFilter='الكل';
               showAllTransactions=false;
              })))).toList()),
            const SizedBox(height:14), // M677: separated outlined filter from chip borders.
            WaffraCenteredDropdownFormField<String>(
             key:ValueKey(typeFilter+'-'+selected),initialValue:selected,
             decoration:InputDecoration(labelText:waffraIsEnglish?
              'Category':'تصفية حسب القسم'),
             items:filterCats.map((value)=>DropdownMenuItem(
              value:value,child:WaffraText(waffraTr(value)))).toList(),
             onChanged:WaffraHaptics.selection((value)=>setState((){
              categoryFilter=value??'الكل';
              showAllTransactions=false;
             }))),
            Align(alignment:AlignmentDirectional.centerStart,
             child:TextButton.icon(onPressed:WaffraHaptics.tap(editTransactionFilters),
              icon:const Icon(Icons.date_range),
              label:WaffraText(waffraIsEnglish?
               'Date and amount filters':'فلترة بالتاريخ والمبلغ'))),
           ],
           const SizedBox(height:6),
           // One chronological activity projection; non-posting event reads
           // never hold the first Home frame or create a second money entry.
           if(_m468VerifiedAccountsLoaded&&
              (typeFilter=='الكل'||typeFilter=='التحويلات'||
               typeFilter=='الادخار'))
            FutureBuilder<({
             List<WaffraInternalTransferHistory> transfers,
             List<WaffraVerifiedGoalMovement> savings,
            })>(
             future:_m652UnifiedActivities(_m467SelectedAccount),
             builder:(ctx,snapshot){
              if(snapshot.hasError)return Column(children:[
               if(typeFilter=='الكل')...shown.map(compactTransaction),
               Padding(padding:const EdgeInsets.all(12),
                child:WaffraText(waffraIsEnglish?
                 'Transfer or savings history could not be verified. Refresh to retry.':
                 'تعذر التحقق من التحويلات أو الادخار. أعد التحديث.')),
              ]);
              if(!snapshot.hasData)return Column(children:[
               if(typeFilter=='الكل')...shown.map(compactTransaction),
              ]);
              final names={for(final a in _m467Accounts)a.id:_m647VerifiedAccountLabel(a)};
              bool accepted(DateTime? when,int amountMinor,List<String> terms)=>
               waffraSearchAny(terms,search)&&
               (transactionsDateRange==null||when==null||
                (!when.isBefore(transactionsDateRange!.start)&&
                 when.isBefore(transactionsDateRange!.end.add(
                  const Duration(days:1)))))&&
               (minTransactionAmount==null||
                amountMinor>=minTransactionAmount!*100)&&
               (maxTransactionAmount==null||
                amountMinor<=maxTransactionAmount!*100);
              final transfers=(typeFilter=='الكل'||typeFilter=='التحويلات')?
               snapshot.data!.transfers.where((t)=>accepted(
                DateTime.tryParse(t.occurredIso),t.amountMinor,[
                 names[t.fromAccountId]??'',names[t.toAccountId]??'',t.note,
                 waffraIsEnglish?'Transfer':'تحويل',
                ])).toList(growable:false):
               <WaffraInternalTransferHistory>[];
              final savings=(typeFilter=='الكل'||typeFilter=='الادخار')?
               snapshot.data!.savings.where((m)=>accepted(
                DateTime.tryParse(m.occurredIso),m.amountMinor,[
                 m.goalName,m.kind,waffraIsEnglish?'Savings':'ادخار',
                ])).toList(growable:false):
               <WaffraVerifiedGoalMovement>[];
              final history=<({DateTime when,Object activity})>[
               if(typeFilter=='الكل')for(final e in visible)
                (when:e.date,activity:e),
               for(final t in transfers)
                (when:DateTime.tryParse(t.occurredIso)??DateTime(1970),
                 activity:t),
               for(final m in savings)
                (when:DateTime.tryParse(m.occurredIso)??DateTime(1970),
                 activity:m),
              ]..sort((a,b)=>b.when.compareTo(a.when));
              final maxShown=waffraDashboardTransactionDisplayCount(
               history.length,expanded:showAllTransactions);
              return Column(children:[
               // Count the verified unified timeline (not just money entries).
               // Applies to All, Transfers and Savings alike.
               if(waffraCanExpandDashboardTransactions(history.length))
                Align(alignment:AlignmentDirectional.centerEnd,
                 child:TextButton(
                  key:const Key('waffra-dashboard-unified-activity-expand'),
                  onPressed:WaffraHaptics.tap(
                   ()=>setState(()=>showAllTransactions=!showAllTransactions)),
                  child:WaffraText(showAllTransactions?
                   (waffraIsEnglish?'Show less':'عرض أقل'):
                   (waffraIsEnglish?'Show more':'عرض أكثر')))),
               if(history.isEmpty)Padding(
                padding:const EdgeInsets.symmetric(vertical:26),
                child:WaffraText(waffraIsEnglish?
                 'No matching transactions':'ما عندك عمليات مطابقة')),
               for(final event in history.take(maxShown))
                if(event.activity is MoneyEntry)
                 compactTransaction(event.activity as MoneyEntry)
                else if(event.activity is WaffraInternalTransferHistory)
                 InkWell(
                  key:Key('m648-home-transfer-'+
                   (event.activity as WaffraInternalTransferHistory).id),
                  onTap:WaffraHaptics.tap(()=>
                   _m647ShowInternalTransfers(focusId:
                    (event.activity as WaffraInternalTransferHistory).id)),
                  child:_m647TransferCard(
                   event.activity as WaffraInternalTransferHistory,
                   compact:true))
                else if(event.activity is WaffraVerifiedGoalMovement)
                 _m649SavingsCard(event.activity as WaffraVerifiedGoalMovement),
               if(history.isNotEmpty)Padding(
                padding:const EdgeInsets.only(top:7),
                child:Row(children:[
                 WaffraText(waffraIsEnglish?
                  'Transactions: ${history.length}':
                  'عدد العمليات: ${history.length}',
                  style:const TextStyle(color:Colors.grey,fontSize:12)),
                 const Spacer(),
                 TextButton.icon(onPressed:WaffraHaptics.tap(()=>
                  exportEntriesPdf(visible,'تقرير عمليات وفرة',
                   activityFilter:typeFilter)),
                  icon:const Icon(Icons.picture_as_pdf_outlined,size:18),
                  label:WaffraText(waffraIsEnglish?'Export PDF':'تصدير PDF')),
                ])),
              ]);
             }),
           if(!_m468VerifiedAccountsLoaded||
              (typeFilter!='الكل'&&typeFilter!='التحويلات'&&
               typeFilter!='الادخار'))...[
            if(visible.isEmpty)Padding(
             padding:const EdgeInsets.symmetric(vertical:26),
             child:WaffraText(waffraIsEnglish?
              'No matching transactions':'ما عندك عمليات مطابقة')),
            ...shown.map(compactTransaction),
            if(visible.isNotEmpty)Padding(
             padding:const EdgeInsets.only(top:7),
             child:Row(children:[
              WaffraText(waffraIsEnglish?
               'Transactions: ${visible.length}':
               'عدد العمليات: ${visible.length}',
               style:const TextStyle(color:Colors.grey,fontSize:12)),
              const Spacer(),
              TextButton.icon(onPressed:WaffraHaptics.tap(()=>
               exportEntriesPdf(visible,'تقرير عمليات وفرة',
                activityFilter:typeFilter)),
               icon:const Icon(Icons.picture_as_pdf_outlined,size:18),
               label:WaffraText(waffraIsEnglish?'Export PDF':'تصدير PDF')),
             ])),
           ],
          ])),
        ]))),
     ],
    )));
 }
 List<MoneyEntry> get analysisEntries=>period=='سنوي'?
  _m684Periods.year(year):_m684Periods.month(year,month);

 Widget nextMonthForecast(){
  final now=DateTime.now();
  final months=List.generate(3,(i)=>DateTime(now.year,now.month-i));
  final used=months.where((m)=>
   _m684Periods.month(m.year,m.month).isNotEmpty).toList();
  final history=_m684Periods.months(used);
  final divisor=max(1,used.length);
  final nextIncome=sum(history,true)/divisor,nextExpenses=sum(history,false)/divisor;
  final current=_m684Periods.month(now.year,now.month);
  final thisIncome=sum(current,true),thisExpenses=sum(current,false);
  final next=DateTime(now.year,now.month+1);
  final categoryAmounts=<String,double>{};
  for(final e in history.where((e)=>!e.income)){
   categoryAmounts[e.category]=(categoryAmounts[e.category]??0)+e.amount/divisor;
  }
  final ranked=categoryAmounts.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final top=ranked.take(5).toList();
  final chosen=top.any((e)=>e.key==forecastCategory)?forecastCategory:(top.isEmpty?null:top.first.key);
  final saving=(categoryAmounts[chosen]??0)*forecastReduction/100;
  String compare(double future,double previous){
   if(previous<=0)return waffraIsEnglish?'Not enough data':'بيانات المقارنة غير كافية';
   final p=(future-previous)/previous*100;
   return '${p>=0?'+':''}${p.toStringAsFixed(1)}%';
  }
  Widget tile(String label,double amount,Color color,IconData icon,String delta)=>Expanded(
   child:Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(
    borderRadius:BorderRadius.circular(17),border:Border.all(color:color.withValues(alpha:.6)),
    color:color.withValues(alpha:.10)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Icon(icon,color:color),const SizedBox(height:7),
     WaffraText(label,style:const TextStyle(fontSize:12)),
     FittedBox(fit:BoxFit.scaleDown,child:WaffraText(cash(amount),
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),
     WaffraText(delta,style:const TextStyle(fontSize:11)),
    ])));
  return Card(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
   child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[const Icon(Icons.auto_awesome,color:emerald),
     const SizedBox(width:8),Expanded(child:WaffraText(waffraIsEnglish?
      'Your smart financial forecast':'توقعاتك المالية الذكية',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)))]),
    const SizedBox(height:6),
    WaffraText(waffraIsEnglish?'Next month: ${next.month}/${next.year}':'الشهر القادم: ${next.month}/${next.year}',
     style:const TextStyle(fontSize:12)),
    const SizedBox(height:12),
    Row(children:[
     tile(waffraIsEnglish?'Expected income':'الدخل المتوقع',nextIncome,emerald,Icons.south_west,compare(nextIncome,thisIncome)),
     const SizedBox(width:8),
     tile(waffraIsEnglish?'Expected expenses':'المصروفات المتوقعة',nextExpenses,Colors.deepOrange,Icons.north_east,compare(nextExpenses,thisExpenses)),
    ]),
    const SizedBox(height:10),
    Row(children:[const Icon(Icons.account_balance_wallet_outlined,color:emerald),
     const SizedBox(width:8),Expanded(child:WaffraText(waffraIsEnglish?'Expected balance':'الرصيد المتوقع')),
     WaffraText(cash(waffraAvailableCash(entries,goals)+nextIncome-nextExpenses),
      style:const TextStyle(fontWeight:FontWeight.bold))]),
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Current month vs forecast':'مقارنة الشهر الحالي بالشهر القادم',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:8),
    FinanceChart(points:[
     ChartPoint(waffraIsEnglish?'Current':'الحالي',thisIncome,thisExpenses),
     ChartPoint(waffraIsEnglish?'Forecast':'المتوقع',nextIncome,nextExpenses),
    ]),
    const SizedBox(height:14),
    WaffraText(waffraIsEnglish?'Forecast by category':'توقعات المصروفات حسب الأقسام',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    if(top.isEmpty)Padding(padding:const EdgeInsets.all(12),
     child:WaffraText(waffraIsEnglish?'Record transactions to see forecasts.':'سجل معاملات لعرض التوقعات.')),
    ...top.map((item)=>Padding(padding:const EdgeInsets.only(top:8),child:Row(children:[
     Expanded(child:WaffraText(item.key)),WaffraText(cash(item.value)),
     const SizedBox(width:8),WaffraText(nextExpenses>0?
      '${(item.value/nextExpenses*100).toStringAsFixed(0)}%':'0%',
      style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
    ]))),
    if(chosen!=null)...[
     const SizedBox(height:15),
     Row(children:[const Icon(Icons.tune,color:emerald),const SizedBox(width:8),
      WaffraText(waffraIsEnglish?'What if?':'ماذا لو؟',
       style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))]),
     WaffraCenteredDropdownFormField<String>(initialValue:chosen,
      decoration:InputDecoration(labelText:waffraIsEnglish?'Reduce category expenses':'تقليل مصروفات قسم'),
      items:top.map((e)=>DropdownMenuItem(value:e.key,child:WaffraText(e.key))).toList(),
      onChanged:WaffraHaptics.selection((v)=>setState((){forecastCategory=v;forecastReduction=20;}))),
     Row(children:[Expanded(child:Slider(value:forecastReduction.toDouble(),min:0,max:50,divisions:10,
      onChanged:(v)=>setState(()=>forecastReduction=v.round()))),WaffraText('${forecastReduction}%')]),
     WaffraText(waffraIsEnglish?'Adjusted expenses: ${cash(nextExpenses-saving)} • Save ${cash(saving)}':
      'المصروفات بعد التخفيض: ${cash(nextExpenses-saving)} • التوفير ${cash(saving)}',
      style:const TextStyle(color:emerald,fontWeight:FontWeight.bold)),
    ],
    const SizedBox(height:12),
    WaffraText(waffraIsEnglish?'Estimates use up to 3 months of locally recorded transactions. Actual results may differ.':
     'تقديرات من معاملات آخر 3 أشهر المسجلة محليًا، وقد تختلف النتائج الفعلية.',
     style:const TextStyle(fontSize:11)),
   ])));
 }


 Future<void> showAiAnalysis()async {
  final now=DateTime.now();
  final recent=_m684Periods.between(
   now.subtract(const Duration(days:90)),now,
   startInclusive:false,endInclusive:true);
  // A clear next step is more helpful than displaying empty charts.
  if(recent.isEmpty){
   if(!mounted)return;
   final add=await showWaffraDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
    title:Row(children:[
     const Icon(Icons.insights_rounded,color:emerald,size:25),
     const SizedBox(width:8),
     Expanded(child:WaffraText(
      waffraIsEnglish?'No transactions to analyze yet':'لا توجد معاملات لتحليلها بعد',
      style:const TextStyle(fontWeight:FontWeight.bold,fontSize:18))),
    ]),
    content:WaffraText(waffraIsEnglish?
     'Add an income or expense transaction first, then Waffra can show you your financial insights.':
     'أضف أول عملية دخل أو مصروف، وبعدها تقدر تشوف تحليلك المالي وتتابع مصروفاتك بوضوح.',
     textAlign:TextAlign.start),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop(false)),
      child:WaffraText(waffraIsEnglish?'Later':'لاحقًا')),
     FilledButton.icon(onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop(true)),
      icon:const Icon(Icons.add_circle_outline),
      label:WaffraText(waffraIsEnglish?'Add transaction':'إضافة معاملة')),
    ],
   ));
   if(add==true&&mounted)await entrySheet();
   return;
  }
  final income=sum(recent,true),spending=sum(recent,false);
  final hasEnoughData=recent.length>=3&&income>0;
  final ratio=income>0?(income-spending)/income:0.0;
  final score=hasEnoughData?((ratio+1)*50).clamp(0.0,100.0).round():null;
  final smartCharts=waffraSmartChartData(recent,now);
  final top=smartCharts.topCategories;
  final monthStart=DateTime(now.year,now.month);
  final priorStart=DateTime(now.year,now.month-1);
  final currentRows=_m684Periods.between(monthStart,now,endInclusive:true);
  final previousRows=_m684Periods.month(priorStart.year,priorStart.month);
  final currentExpense=sum(currentRows.where((e)=>!e.income),false);
  final priorExpense=sum(previousRows.where((e)=>!e.income),false);
  final hasPrior=previousRows.isNotEmpty;
  final thisMonthCount=currentRows.length;
  final monthDays=DateTime(now.year,now.month+1,0).day;
  final upcoming=recurring.where((r)=>r.active&&!r.income&&r.day>now.day&&r.day<=monthDays).fold<double>(0,(v,r)=>v+r.amount);
  final forecast=now.day>=5&&thisMonthCount>=3?(currentExpense/now.day*monthDays+upcoming):null;
  final weeklySpend=smartCharts.weeklySpend;
  if(!mounted)return;
  // M526: the local financial results have already been computed.
  // Open the existing results route immediately; do not show a timed
  // 1.5-second blocking animation that performs no work.
  await showGeneralDialog<void>(
   context:context,
   barrierDismissible:true,
   barrierLabel:waffraIsEnglish?'Close analysis':'إغلاق التحليل',
   barrierColor:Colors.black.withValues(alpha:.24),
   transitionDuration:waffraMotion(300),
   transitionBuilder:(ctx,animation,secondary,child)=>BackdropFilter(
    filter:ui.ImageFilter.blur(sigmaX:7*animation.value,sigmaY:7*animation.value),
    child:SlideTransition(
     position:Tween<Offset>(begin:const Offset(0,1),end:Offset.zero)
      .animate(CurvedAnimation(parent:animation,curve:Curves.easeOutCubic)),
     child:child)),
   pageBuilder:(ctx,animation,secondary){

   final deficit=spending-income;
   final accent=score==null?Colors.grey:score<45?Colors.red:score<70?Colors.orange:emerald;
   final periods=smartCharts.periods;
   final highest=periods.fold<double>(1,(v,p)=>max(v,max(p.$1,p.$2)));
   return Align(alignment:Alignment.bottomCenter,child:FractionallySizedBox(
    heightFactor:.90,
    child:Material(
     color:Theme.of(ctx).scaffoldBackgroundColor,
     clipBehavior:Clip.antiAlias,
     shape:const RoundedRectangleBorder(borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
     child:SafeArea(top:false,child:Column(children:[
      const SizedBox(height:12),
      Center(child:Container(width:48,height:5,decoration:BoxDecoration(
       color:emerald.withValues(alpha:.28),borderRadius:BorderRadius.circular(12)))),
      Padding(padding:const EdgeInsets.symmetric(horizontal:18,vertical:14),child:Row(children:[
       Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(
        color:emerald.withValues(alpha:.1),borderRadius:BorderRadius.circular(14)),
        child:const Icon(Icons.insights_rounded,color:emerald)),
       const SizedBox(width:10),
       Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'Financial insights':'التحليل المالي التفصيلي',
         style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
        WaffraText(waffraIsEnglish?'Your last 90 days at a glance':'نظرة شاملة على آخر 90 يوم',
         style:const TextStyle(fontSize:12)),
       ])),
       IconButton(tooltip:waffraIsEnglish?'Close':'إغلاق',icon:const Icon(Icons.close_rounded),
        onPressed:WaffraHaptics.tap(()=>Navigator.of(ctx).pop())),
      ])),
      const Divider(height:1),
      Expanded(child:ListView(padding:const EdgeInsets.all(16),children:[
     Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
      color:Theme.of(ctx).cardColor,
      border:Border.all(color:emerald.withValues(alpha:.18)),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.04),blurRadius:14,offset:const Offset(0,5))],
      borderRadius:BorderRadius.circular(22)),
      child:Column(children:[
       WaffraText(waffraIsEnglish?'Income & expense balance indicator':'مؤشر توازن الدخل والمصروفات',
        style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17),textAlign:TextAlign.center),
       const SizedBox(height:12),
       WaffraText(score==null?'— / 100':'$score / 100',
        style:TextStyle(color:accent,fontWeight:FontWeight.bold,fontSize:34)),
       const SizedBox(height:10),
       LinearProgressIndicator(value:(score??0)/100,minHeight:9,color:accent,
        borderRadius:BorderRadius.circular(10)),
       const SizedBox(height:10),
       WaffraText(score==null?(waffraIsEnglish?'Not enough data':'البيانات غير كافية'):
        deficit>0?(waffraIsEnglish?'Expenses exceed income. Review your spending.':
         'مصروفاتك أعلى من دخلك. راجع مصروفاتك لإعادة التوازن.'):
        (waffraIsEnglish?'Keep tracking your spending to maintain balance.':
         'واصل متابعة مصروفاتك للحفاظ على التوازن.'),
        textAlign:TextAlign.center),
       const SizedBox(height:6),
       WaffraText(waffraIsEnglish?'Indicative cash-flow measure, not a credit score.':
        'مؤشر إرشادي مبني على العمليات المسجلة، وليس تصنيفًا ائتمانيًا.',
        style:const TextStyle(fontSize:11),textAlign:TextAlign.center),
      ])),
     const SizedBox(height:22),
     WaffraText(waffraIsEnglish?'Last 90 days':'ملخص آخر 90 يوم',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     Wrap(spacing:8,runSpacing:8,children:[
      _analysisStat(waffraIsEnglish?'Income':'الدخل',income,emerald),
      _analysisStat(waffraIsEnglish?'Expenses':'المصروفات',spending,Colors.deepOrange),
      _analysisStat(deficit>0?(waffraIsEnglish?'Deficit':'العجز'):(waffraIsEnglish?'Surplus':'الفائض'),
       deficit.abs(),deficit>0?Colors.red:emerald),
     ]),
     const SizedBox(height:24),
     Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(
      crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       WaffraText(waffraIsEnglish?'Compared with last month':'مقارنة بالشهر السابق',
        style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
       const SizedBox(height:8),
       WaffraText(!hasPrior?
        (waffraIsEnglish?'Not enough previous-month data for comparison.':'لا توجد بيانات كافية للشهر السابق للمقارنة.'):
        priorExpense==0?(waffraIsEnglish?'No expenses last month.':'لم يتم تسجيل مصروفات في الشهر السابق.'):
        (waffraIsEnglish?'Expenses ${currentExpense<=priorExpense?'decreased':'increased'} by ${((currentExpense-priorExpense).abs()/priorExpense*100).toStringAsFixed(1)}%.':
         'المصروفات ${currentExpense<=priorExpense?'انخفضت':'ارتفعت'} بنسبة ${((currentExpense-priorExpense).abs()/priorExpense*100).toStringAsFixed(1)}%.')),
       const SizedBox(height:12),
       WaffraText(waffraIsEnglish?'Estimated month-end spending':'توقع المصروفات بنهاية الشهر',
        style:const TextStyle(fontWeight:FontWeight.bold)),
       WaffraText(forecast==null?
        (waffraIsEnglish?'At least three transactions and five elapsed days are needed.':'يلزم تسجيل ثلاث معاملات ومرور خمسة أيام على الأقل من الشهر.'):
        (waffraIsEnglish?'Approximately ${cash(forecast)} at the current pace.':
         'حوالي ${cash(forecast)} إذا استمر معدل الإنفاق الحالي.')),
       WaffraText(waffraIsEnglish?'Estimate from recorded transactions and upcoming recurring expenses, not a guarantee.':
        'تقدير مبني على معاملاتك والعمليات المتكررة القادمة، وليس مبلغًا مؤكدًا.',
        style:const TextStyle(fontSize:11)),
      ]))),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Income vs expenses':'اتجاه الدخل والمصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     ...List.generate(3,(i)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),
      child:Row(children:[
       SizedBox(width:65,child:WaffraText(waffraIsEnglish?'Period ${i+1}':'فترة ${i+1}')),
       Expanded(child:Column(children:[
        LinearProgressIndicator(value:periods[i].$1/highest,minHeight:10,color:emerald,
         backgroundColor:emerald.withValues(alpha:.08)),
        const SizedBox(height:5),
        LinearProgressIndicator(value:periods[i].$2/highest,minHeight:10,color:Colors.deepOrange,
         backgroundColor:Colors.deepOrange.withValues(alpha:.08)),
       ])),
      ]))),
     Row(children:[
      const Icon(Icons.circle,color:emerald,size:12),const SizedBox(width:5),
      WaffraText(waffraIsEnglish?'Income':'الدخل'),
      const SizedBox(width:15),const Icon(Icons.circle,color:Colors.deepOrange,size:12),
      const SizedBox(width:5),WaffraText(waffraIsEnglish?'Expenses':'المصروفات'),
     ]),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Weekly spending trend':'اتجاه المصروفات الأسبوعية',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:8),
     Card(child:Padding(padding:const EdgeInsets.all(16),child:SizedBox(height:170,
      child:LineChart(LineChartData(minY:0,
       gridData:const FlGridData(show:true,drawVerticalLine:false),
       titlesData:const FlTitlesData(show:false),borderData:FlBorderData(show:false),
       lineBarsData:[LineChartBarData(
        spots:List.generate(weeklySpend.length,(i)=>FlSpot(i.toDouble(),weeklySpend[i])),
        isCurved:true,color:emerald,barWidth:3,dotData:const FlDotData(show:true),
        belowBarData:BarAreaData(show:true,color:emerald.withValues(alpha:.10))),
       ]))))),
     const SizedBox(height:10),
     WaffraText(waffraIsEnglish?'Four weeks from oldest to newest.':'آخر أربعة أسابيع من الأقدم للأحدث.',style:const TextStyle(fontSize:12)),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Top spending categories':'أعلى أقسام المصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:10),
     if(top.isEmpty)WaffraText(waffraIsEnglish?'No expenses recorded.':'لا توجد مصروفات مسجلة.'),
     ...top.take(5).map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),
      child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
       Row(children:[Expanded(child:WaffraText(waffraTr(e.key))),
        WaffraText(cash(e.value),style:const TextStyle(fontWeight:FontWeight.bold))]),
       const SizedBox(height:5),
       LinearProgressIndicator(value:spending>0?e.value/spending:0,minHeight:7,
        color:Colors.deepOrange,borderRadius:BorderRadius.circular(8)),
      ]))),
     const SizedBox(height:24),
     WaffraText(waffraIsEnglish?'Spending distribution chart':'الرسم البياني لتوزيع المصروفات',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:12),
     if(top.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),
      child:SizedBox(height:240,child:PieChart(PieChartData(
       centerSpaceRadius:40,
       sections:top.map((e){
        final c=categoryFor(e.key,false);
        return PieChartSectionData(value:e.value,color:Color(c.color),radius:77,
         title:'${(e.value/spending*100).toStringAsFixed(0)}%',
         titleStyle:const TextStyle(fontSize:12,color:Colors.white,fontWeight:FontWeight.bold));
       }).toList(),
      ))))),
     const SizedBox(height:16),
     OutlinedButton.icon(
      onPressed:WaffraHaptics.tap(recent.isEmpty?null:()=>exportEntriesPdf(recent,
       waffraIsEnglish?'Waffra analytics - Last 90 days':'تحليلات وفرة - آخر 90 يوم',
       analytics:true)),
      icon:const Icon(Icons.picture_as_pdf_outlined),
      label:WaffraText(waffraIsEnglish?'Export analytics PDF':'تصدير التحليلات إلى PDF')),
     const SizedBox(height:24),
     ExpansionTile(leading:const Icon(Icons.info_outline,color:emerald),
      title:WaffraText(waffraIsEnglish?'Why this result?':'ليه النتيجة دي؟'),
      children:[Padding(padding:const EdgeInsets.all(14),
       child:WaffraText(waffraIsEnglish?
        'Last 90 days (${recent.length} transactions): income ${cash(income)}, expenses ${cash(spending)}. Indicative score.':
        'آخر 90 يومًا: ${recent.length} معاملة، دخل ${cash(income)}، مصروف ${cash(spending)}. مؤشر تقريبي.'))]),
     const SizedBox(height:20),
     WaffraText(waffraIsEnglish?'Tips for you':'نصائح مخصصة لك',
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
     const SizedBox(height:10),
     ListTile(leading:const Icon(Icons.lightbulb_outline,color:emerald),
      title:WaffraText(deficit>0?
       (waffraIsEnglish?'Reduce optional spending to close the gap.':'قلّل المصروفات الاختيارية لتقليل العجز.'):
       (waffraIsEnglish?'Keep your expenses below your income.':'حافظ على مصروفات أقل من دخلك.'))),
     if(top.isNotEmpty)ListTile(leading:const Icon(Icons.category_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'Reduce spending on ${waffraTr(top.first.key)} by 15% to save roughly ${cash(top.first.value*.15)} over this period.':
       'تقليل مصروفات «${waffraTr(top.first.key)}» بنسبة 15% قد يوفر حوالي ${cash(top.first.value*.15)} خلال فترة التحليل.')),
     if(goals.isNotEmpty&&income>spending)ListTile(
      leading:const Icon(Icons.account_balance_wallet_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'You could allocate part of your surplus to ${goals.first.name}; nothing is moved automatically.':
       'ممكن تخصص جزءًا من الفائض لهدف «${goals.first.name}»، ولن نضيف أي مبالغ تلقائيًا.')),
     ListTile(leading:const Icon(Icons.track_changes_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'Set monthly budgets for your categories.':
       'حدد ميزانية شهرية لكل قسم للتحكم في الإنفاق.')),
     const SizedBox(height:24),
    ])),
    ]))),
   ));
  });
 }
 Widget _analysisStat(String label,double value,Color color)=>Container(
  width:MediaQuery.of(context).size.width/3-18,
  padding:const EdgeInsets.symmetric(horizontal:7,vertical:15),
  decoration:BoxDecoration(color:color.withValues(alpha:.09),borderRadius:BorderRadius.circular(15)),
  child:Column(children:[
   WaffraText(label,style:const TextStyle(fontSize:12),textAlign:TextAlign.center),
   const SizedBox(height:7),
   FittedBox(fit:BoxFit.scaleDown,child:WaffraText(cash(value),
    style:TextStyle(color:color,fontWeight:FontWeight.bold,fontSize:15))),
  ]),
 );
 Widget analytics(){
  final data=analysisEntries,inc=sum(data,true),exp=sum(data,false);
  final years=<int>{DateTime.now().year,year,..._m684Periods.years}.toList()..sort((a,b)=>b.compareTo(a));
  final points=period=='شهري'?List.generate(5,(i){
   final v=data.where((e)=>(e.date.day-1)~/7==i);
   return ChartPoint(waffraIsEnglish?'Week ${i+1}':'الأسبوع ${i+1}',sum(v,true),sum(v,false));
  }):List.generate(12,(i){
   final v=data.where((e)=>e.date.month==i+1);
   return ChartPoint(waffraIsEnglish?'Month ${i+1}':'شهر ${i+1}',sum(v,true),sum(v,false));
  });
  final breakdown=<String,double>{};
  for(final e in data.where((e)=>!e.income)){breakdown[e.category]=(breakdown[e.category]??0)+e.amount;}
  return ListView(padding:const EdgeInsets.all(16),children:[
   Row(children:[
    Expanded(child:WaffraText(waffraIsEnglish?'Your financial analytics':'تحليلاتك المالية',style:Theme.of(context).textTheme.titleLarge)),
   ]),
   const SizedBox(height:12),
   SegmentedButton<String>(segments:const [ButtonSegment(value:'شهري',label:WaffraText('شهري')),
    ButtonSegment(value:'سنوي',label:WaffraText('سنوي'))],
    selected:{period},onSelectionChanged:WaffraHaptics.selection((v)=>setState(()=>period=v.first))),
   const SizedBox(height:12),
   Row(children:[
    Expanded(child:WaffraCenteredDropdownFormField<int>(initialValue:year,
     decoration:InputDecoration(labelText:waffraTr('السنة')),
     items:years.map((x)=>DropdownMenuItem(value:x,child:WaffraText('$x'))).toList(),
     onChanged:WaffraHaptics.selection((v){if(v!=null)setState(()=>year=v);}))),
    if(period=='شهري')Expanded(child:WaffraCenteredDropdownFormField<int>(initialValue:month,
     decoration:InputDecoration(labelText:waffraTr('الشهر')),
     items:List.generate(12,(i)=>DropdownMenuItem(value:i+1,child:WaffraText('شهر ${i+1}'))),
     onChanged:WaffraHaptics.selection((v){if(v!=null)setState(()=>month=v);}))),
   ]),
   const SizedBox(height:12),
   nextMonthForecast(),
   const SizedBox(height:12),
   Row(children:[stat('الدخل',inc,Icons.south_west,waffraIncomeTone(context)),stat('المصروفات',exp,Icons.north_east,Colors.deepOrange)]),
   Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(children:[
    const WaffraText('الدخل مقابل المصروفات',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:16),FinanceChart(points:points),
   ]))),
   const SizedBox(height:16),
   OutlinedButton.icon(onPressed:WaffraHaptics.tap(()=>exportEntriesPdf(data,'تحليلات وفرة - $period ${period=='شهري'?'$month/':''}$year',analytics:true)),
    icon:const Icon(Icons.picture_as_pdf_outlined),label:const WaffraText('تصدير التحليلات إلى PDF')),
   const SizedBox(height:12),
   Card(child:Padding(padding:const EdgeInsets.all(16),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraText(waffraIsEnglish?'Horizontal income and expense comparison':
      'مقارنة الدخل والمصروفات بأشرطة أفقية',
      style:const TextStyle(fontWeight:FontWeight.bold)),
     const SizedBox(height:6),
     WaffraText(waffraIsEnglish?'Bar length = amount in SAR.':
      'طول الشريط يوضح المبلغ بالريال.',
      style:const TextStyle(fontSize:11)),
     const SizedBox(height:13),
     Row(children:[
      Expanded(child:WaffraText(waffraIsEnglish?'Income':'الدخل')),
      WaffraText(cash(inc),style:TextStyle(fontWeight:FontWeight.bold,color:waffraIncomeTone(context))),
     ]),
     const SizedBox(height:6),
     LinearProgressIndicator(value:(inc/max(1.0,max(inc,exp))).clamp(0.0,1.0),
      minHeight:15,borderRadius:BorderRadius.circular(8),color:waffraIncomeTone(context)),
     const SizedBox(height:14),
     Row(children:[
      Expanded(child:WaffraText(waffraIsEnglish?'Expenses':'المصروفات')),
      WaffraText(cash(exp),style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.deepOrange)),
     ]),
     const SizedBox(height:6),
     LinearProgressIndicator(value:(exp/max(1.0,max(inc,exp))).clamp(0.0,1.0),
      minHeight:15,borderRadius:BorderRadius.circular(8),color:Colors.deepOrange),
    ]))),
   if(breakdown.isNotEmpty)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
    const WaffraText('توزيع المصروفات - دائري',style:TextStyle(fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    SizedBox(height:210,child:PieChart(PieChartData(centerSpaceRadius:32,sections:breakdown.entries.map((e){
     final c=categoryFor(e.key,false);
     return PieChartSectionData(value:e.value,color:Color(c.color),radius:70,
      title:'${(e.value/exp*100).toStringAsFixed(0)}٪',titleStyle:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold));
    }).toList()))),
   ]))),
   const SizedBox(height:16),
   WaffraText('توزيع مصروفاتك',style:Theme.of(context).textTheme.titleMedium),
   ...breakdown.entries.map((x){
    final c=categoryFor(x.key,false);
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
     Row(children:[Icon(categoryIcon(c.icon),color:Color(c.color)),const SizedBox(width:8),
      Expanded(child:WaffraText(x.key)),RiyalAmount(x.value)]),
     const SizedBox(height:10),
     LinearProgressIndicator(value:exp==0?0:x.value/exp,color:Color(c.color),minHeight:8,borderRadius:BorderRadius.circular(8)),
    ])));
   }),
   if(breakdown.isEmpty)const Padding(padding:EdgeInsets.all(20),child:WaffraText('ما فيه مصروفات في هالفترة')),
   const SizedBox(height:80),
  ]);
 }

}

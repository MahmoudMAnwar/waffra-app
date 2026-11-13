part of 'main.dart';

/// M707 / #633/#635: byte-identical owner-approved Goals/Recurring real pages.
/// Verified SQLCipher source and every user action stay in the parent Home State.
extension _WaffraHomeGoalsRecurringPagesModule on _HomeScreenState {
 Widget goalsPage(){
  final target=goals.fold<double>(0,(v,g)=>v+g.target);
  final saved=goals.fold<double>(0,(v,g)=>v+g.saved);
  final filtered=goals.where((g)=>
   (goalDisplay=='all'||
    (goalDisplay=='done'?(g.target>0&&g.saved>=g.target):
     (g.active&&(g.target<=0||g.saved<g.target))))&&
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
       cash(target),Icons.trending_up_rounded),
      WaffraApprovedMetric(waffraIsEnglish?'Total saved':'إجمالي المدخرات',
       cash(saved),Icons.toll_outlined),
      WaffraApprovedMetric(waffraIsEnglish?'Active goals':'أهداف نشطة',
       goals.where((g)=>g.active).length.toString(),Icons.track_changes),
     ]),
     const SizedBox(height:12),
     // Keep filter controls a single scrollable row at 320dp. The global
     // floating + stays on the unchanged scaffold, not inside this list.
     SingleChildScrollView(scrollDirection:Axis.horizontal,
      child:Row(children:[
       _filterChip(waffraIsEnglish?'All':'الكل',goalDisplay=='all',
        ()=>setState(()=>goalDisplay='all')),
       const SizedBox(width:7),
       _filterChip(waffraIsEnglish?'Active':'نشطة',goalDisplay=='active',
        ()=>setState(()=>goalDisplay='active')),
       const SizedBox(width:7),
       _filterChip(waffraIsEnglish?'Completed':'مكتملة',goalDisplay=='done',
        ()=>setState(()=>goalDisplay='done')),
       const SizedBox(width:9),
       IconButton(
        key:const Key('m689-goals-search-toggle'),
        tooltip:waffraIsEnglish?'Search goals':'بحث عن هدف',
        onPressed:()=>setState(()=>_m689GoalSearchOpen=!_m689GoalSearchOpen),
        icon:const Icon(Icons.search_rounded,color:emerald)),
       IconButton(
        key:const Key('m689-goals-archive'),
        tooltip:waffraIsEnglish?'Deleted goals':'الأهداف المحذوفة',
        onPressed:WaffraHaptics.tapRequired(deletedGoalsDialog),
        icon:const Icon(Icons.filter_alt_outlined,color:emerald)),
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
         child:WaffraText(cash(money),maxLines:1,
          style:TextStyle(fontSize:14,fontWeight:FontWeight.bold,
           color:label==(waffraIsEnglish?'Saved':'المدخر')?emerald:null)))),
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
 Future<void> recurringDialog({String? suggestedTitle,double? suggestedAmount,RecurringBill? initial,RecurringBill? duplicate})async {
  // Linked schedules are projections of a goal; never open a second editor.
  if(initial?.linkedGoalId!=null){
   await _m665ExplainLinkedGoalEdit();
   return;
  }
  // M641: the editor opens even on a fresh install with ZERO accounts.
  // Account selection remains mandatory at SAVE, not before opening.
  final verifiedRecurringAccounts=await _m641VerifiedGoalRecurringAccounts();
  if(verifiedRecurringAccounts==null||!mounted)return;
  List<WaffraAccountBalance> liveAccounts=verifiedRecurringAccounts;
  String? selectedRecurringAccount=initial?.accountId??duplicate?.accountId;
  if(initial!=null){
   try{
    final bridge=_financeBinding?.accountsBridge;
    if(bridge!=null){
     selectedRecurringAccount=
      await WaffraVerifiedAccountsApi(bridge:bridge)
       .recurringDefaultAccount(initial.id)??selectedRecurringAccount;
    }
   }catch(error){
    debugPrint('M641 recurring default read failed: '+error.runtimeType.toString());
   }
  }
  // A goal-linked due gets its identity ONLY from its parent goal.
  // Change the account in Goals, where both records commit atomically.
  if(initial?.linkedGoalId!=null){
   final linked=goals.where((g)=>g.id==initial!.linkedGoalId).toList();
   if(linked.length!=1){
    if(mounted)snack(context,waffraIsEnglish?
     'Linked goal unavailable; edit the goal before this due.':
     'الهدف المرتبط غير متاح. راجع الهدف قبل تعديل الاستحقاق.',
     isError:true);
    return;
   }
   selectedRecurringAccount=linked.single.accountId;
  }
  if(!liveAccounts.any((a)=>a.id==selectedRecurringAccount&&!a.archived)){
   selectedRecurringAccount=null;
  }
  final title=TextEditingController(text:initial?.title??duplicate?.title??suggestedTitle??''),
   amount=TextEditingController(text:initial!=null?formatWaffraEditAmount(initial.amount):duplicate!=null?formatWaffraEditAmount(duplicate.amount):suggestedAmount==null?'':formatWaffraEditAmount(suggestedAmount)),
   day=TextEditingController(text:(initial?.day??duplicate?.day??1).toString());
  bool income=initial?.income??duplicate?.income??false;String category=initial?.category??duplicate?.category??(forSelectableType(false).isNotEmpty?
    forSelectableType(false).first.name:'');bool attempted=false;
  DateTime startAt=initial?.startAt??(duplicate!=null&&duplicate.startAt.isAfter(DateTime.now())?duplicate.startAt:DateTime.now());
  final r=await showWaffraDialog<RecurringBill>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final options=forSelectableType(income);
    // An old recurring schedule may refer to a now-paused category.
    // Editing its title/date must not silently reassign it to another leaf.
    // New or duplicated schedules must explicitly select an active leaf.
    final historicalSelected=initial!=null&&initial.income==income&&
     initial.category==category;
    final selected=options.any((x)=>x.name==category)||historicalSelected
     ?category:'';
    final validNames=[
     ...options.map((c)=>c.name),
     if(historicalSelected)initial.category,
    ];
    return AlertDialog(title:WaffraText(initial==null?(waffraIsEnglish?'New recurring item':'عملية شهرية متكررة'):(waffraIsEnglish?'Edit recurring item':'تعديل العملية المتكررة')),
     content:SizedBox(width:340,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,mainAxisSize:MainAxisSize.min,children:[
      const SizedBox(height:12),
      TextField(controller:title,onChanged:(_)=>update((){}),decoration:InputDecoration(labelText:waffraIsEnglish?'Description *':'الوصف *',
       errorText:attempted?waffraTextFieldError(title.text):null)),
      if(initial?.linkedGoalId!=null)WaffraText(waffraIsEnglish?
       'Edit target and due date from the linked goal in Goals.':
       'تعديل المبلغ والاستحقاق يكون من الهدف المرتبط في الأهداف.',
       style:const TextStyle(fontSize:12,color:emerald)),
      const SizedBox(height:12),
      TextField(controller:amount,readOnly:initial?.linkedGoalId!=null,keyboardType:const TextInputType.numberWithOptions(decimal:true),
       inputFormatters:[const WaffraAmountFormatter(truncateExcess:false)],onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Amount *':'المبلغ *',
        errorText:attempted?waffraAmountFieldError(amount.text):null)),
      const SizedBox(height:12),
      if(initial?.linkedGoalId!=null)
       InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Goal account (edit in Goals)':
          'حساب الهدف (التعديل من الأهداف)',
         border:const OutlineInputBorder()),
        child:WaffraText(
         selectedRecurringAccount==null?
          (waffraIsEnglish?'Set account in linked goal first':
           'اختر حساب الهدف من صفحة الأهداف أولًا'):
          liveAccounts.where((a)=>a.id==selectedRecurringAccount)
           .map((a)=>a.name).firstOrNull??
           (waffraIsEnglish?'Account needs verification':'الحساب يحتاج مراجعة'),
         maxLines:2),
       )
      else WaffraGoalRecurringAccountPicker(
       key:const Key('m641-recurring-account-cascade'),
       idPrefix:'m641-recurring',english:waffraIsEnglish,
       accounts:liveAccounts,selectedAccountId:selectedRecurringAccount,
       onChanged:(id)=>update(()=>selectedRecurringAccount=id),
       onError:(message)=>snack(context,message),
       onCreateAccount:(provider)async{
        final added=await _m641CreateGoalRecurringAccount(provider);
        if(added!=null)liveAccounts=[...liveAccounts,added];
        return added;
       }),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<bool>(initialValue:income,
       items:const [DropdownMenuItem(value:true,child:WaffraText('دخل')),
        DropdownMenuItem(value:false,child:WaffraText('مصروف'))],
       onChanged:initial?.linkedGoalId!=null?null:WaffraHaptics.selection((v){if(v!=null)update((){
         income=v;category=forSelectableType(v).isNotEmpty?forSelectableType(v).first.name:'';
        });})),
      const SizedBox(height:12),
      InkWell(
       borderRadius:BorderRadius.circular(14),
       onTap:WaffraHaptics.tap(()async{
        final picked=await showWaffraDialog<String>(context:ctx,
         builder:(searchCtx){
          String query='';
          return StatefulBuilder(builder:(searchCtx,refresh){
           final filtered=options.where((c)=>
            waffraSearchAny([c.name,waffraTr(c.name)],query)).toList();
           return AlertDialog(
            title:WaffraText(waffraIsEnglish?'Search categories':'البحث عن قسم'),
            content:SizedBox(
             width:double.maxFinite,
             height:min(430.0,MediaQuery.sizeOf(searchCtx).height*.58),
             child:Column(children:[
              TextField(
               autofocus:true,
               onChanged:(value)=>refresh(()=>query=value),
               decoration:InputDecoration(
                prefixIcon:const Icon(Icons.search_rounded),
                hintText:waffraIsEnglish?'Type a category name…':'اكتب اسم القسم للبحث…',
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(14))),
              ),
              const SizedBox(height:10),
              Expanded(child:filtered.isEmpty
               ?Center(child:WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'))
               :ListView.builder(
                itemCount:filtered.length,
                itemBuilder:(searchCtx,index){
                 final option=filtered[index];
                 return ListTile(
                  dense:true,
                  selected:option.name==selected,
                  leading:Icon(categoryIcon(option.icon),color:Color(option.color),size:21),
                  title:WaffraText(option.name,maxLines:3),
                  onTap:WaffraHaptics.tap(()=>Navigator.pop(searchCtx,option.name)));
                })),
             ]),
            ),
           );
          });
         });
        if(picked!=null&&ctx.mounted)update(()=>category=picked);
       }),
       child:InputDecorator(
        decoration:InputDecoration(
         labelText:waffraIsEnglish?'Category *':'القسم *',
         errorText:attempted&&WaffraValidators.requiredCategory(
          selected,validNames)!=null?waffraRequiredFieldMessage:null,
         suffixIcon:const Icon(Icons.search_rounded),
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(14)),
         contentPadding:const EdgeInsets.symmetric(horizontal:13,vertical:15)),
        child:Row(children:[
         Expanded(child:WaffraText(selected.isEmpty?
          (waffraIsEnglish?'Choose a category':'اختر قسمًا'):selected,maxLines:2,
          style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600))),
         const SizedBox(width:8),
         const Icon(Icons.arrow_drop_down_rounded,size:20),
        ]),
       ),
      ),
      const SizedBox(height:12),
      OutlinedButton.icon(onPressed:initial?.linkedGoalId!=null?null:WaffraHaptics.tap(()async{
       final picked=await waffraPickDateWithToday(english:waffraIsEnglish,context:ctx,initialDate:startAt.isBefore(DateTime.now())?
         DateTime.now():startAt,firstDate:DateTime.now().subtract(const Duration(days:1)),lastDate:DateTime(DateTime.now().year+5));
       if(picked!=null)update((){startAt=picked;day.text=picked.day.toString();});
      }),icon:const Icon(Icons.calendar_month_outlined),label:WaffraText(waffraIsEnglish?'First due: ${dayText(startAt)}':'أول استحقاق: ${dayText(startAt)}')),
      const SizedBox(height:8),
      TextField(controller:day,readOnly:initial?.linkedGoalId!=null,keyboardType:TextInputType.number,onChanged:(_)=>update((){}),
       decoration:InputDecoration(labelText:waffraIsEnglish?'Day of month *':'يوم الشهر *',helperText:waffraIsEnglish?'1–31':'من 1 إلى 31',
       errorText:attempted?waffraDayFieldError(day.text):null)),
     ]))),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap((){
       final n=amountOfDisplay(amount.text),d=int.tryParse(digits(day.text));update(()=>attempted=true);
       if(WaffraValidators.requiredText(title.text)==null&&
        WaffraValidators.positiveAmount(amount.text)==null&&
        WaffraValidators.dayOfMonth(day.text)==null&&
        WaffraValidators.requiredCategory(selected,validNames)==null&&
        selectedRecurringAccount!=null&&
        liveAccounts.any((a)=>a.id==selectedRecurringAccount&&!a.archived)&&
        n!=null&&d!=null){
        Navigator.pop(ctx,RecurringBill(id:initial?.id??newId(),title:title.text.trim(),category:selected,
         amount:initial?.linkedGoalId!=null?initial!.amount:n,income:income,
         day:initial?.linkedGoalId!=null?initial!.day:d,
         startAt:initial?.linkedGoalId!=null?initial!.startAt:startAt,
         active:initial?.active??duplicate?.active??true,linkedGoalId:initial?.linkedGoalId,
         accountId:selectedRecurringAccount));
       }
      }),child:const WaffraText('حفظ')),
     ]);
   }));
  disposeLater([title,amount,day]);
  if(r!=null&&mounted){
   setState((){
    if(initial==null){recurring.add(r);}else{
     final index=recurring.indexWhere((e)=>e.id==initial.id);
     if(index>=0)recurring[index]=r;
    }
   });
   if(!await _persistModuleOrReload(WaffraFinanceRoute.recurringCreateEditDeleteRestore,
     operation:initial==null?'recurring-create':'recurring-edit'))return;
   await applyRecurring();
   await syncRecurringReminders();
  }
 }
 DateTime nextRecurringDue(RecurringBill r) {
  if(r.linkedGoalId!=null){
   final once=DateTime(r.startAt.year,r.startAt.month,r.startAt.day);
   final stableId=WaffraRecurringPolicy.entryId(r.id,once);
   final postponed=DateTime.tryParse(recurringPostponed[stableId]??'');
   return postponed!=null&&postponed.isAfter(once)?postponed:once;
  }
  final today=DateTime.now();
  final monthlyDue=WaffraRecurringPolicy.dueDate(today.year,today.month,r.day);
  final monthId=WaffraRecurringPolicy.entryId(r.id,monthlyDue);
  return WaffraRecurringPolicy.nextActionableDue(
   today:today,startAt:r.startAt,day:r.day,
   currentMonthPaid:entries.any((entry)=>entry.id==monthId),
   postponedUntil:DateTime.tryParse(recurringPostponed[monthId]??''));
 }
 Future<void> _setRecurringActiveFromCard(RecurringBill r,bool enabled)async{
  // The linked schedule is a projection of its goal. Changing it here
  // would bypass the goal's atomic target/date/account and paid replay guard.
  if(r.linkedGoalId!=null){
   await _m665ExplainLinkedGoalEdit();
   return;
  }
       final index=recurring.indexWhere((item)=>item.id==r.id);
       if(index<0)return;
       if(enabled){
        final chosen=await waffraPickDateWithToday(english:waffraIsEnglish,context:context,initialDate:DateTime.now().add(const Duration(days:1)),
         firstDate:DateTime.now(),lastDate:DateTime(DateTime.now().year+5));
        if(chosen==null||!mounted)return;
        setState(()=>recurring[index]=r.copy(active:true,startAt:chosen,day:chosen.day));
       }else{
        setState(()=>recurring[index]=r.copy(active:false));
       }
       if(!await _persistModuleOrReload(
        WaffraFinanceRoute.recurringCreateEditDeleteRestore,
        operation:'recurring-active-toggle'))return;
       if(enabled)await applyRecurring();
       await syncRecurringReminders();

 }
 Future<void> _m665ExplainLinkedGoalEdit({bool paid=false})async{
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,
   builder:(dialog)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?
     'Edit the linked goal first':'عدّل الهدف المرتبط أولًا'),
    content:WaffraText(paid?
     (waffraIsEnglish?
      'This is an already paid goal settlement. Its saved wallet and bank debit cannot be edited as an ordinary transaction. Change goal settings in Goals; this does not rewrite a paid receipt.':
      'ده استحقاق هدف مدفوع ومحفوظ. لا يمكن تعديل مبلغ محفظة الهدف أو خصم الحساب كعملية عادية. عدّل بيانات الهدف من صفحة الأهداف، بدون تغيير سجل الدفع السابق.'):
     (waffraIsEnglish?
      'This due date belongs to a savings goal. Edit the goal in Goals first; the linked due will follow that change automatically.':
      'الاستحقاق ده مربوط بهدف ادخاري. عدّل الهدف من صفحة الأهداف أولًا، والتعديل هينعكس على الاستحقاق المرتبط تلقائيًا.')),
    actions:[TextButton(
     onPressed:()=>Navigator.pop(dialog),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
 }
 Future<void> _handleRecurringCardAction(RecurringBill r,String v)async{
       if(v=='edit'){
        if(r.linkedGoalId!=null){
         await _m665ExplainLinkedGoalEdit();
         return;
        }
        await recurringDialog(initial:r);
        return;
       }
       if(v!='delete')return;
       final hasHistory=entries.any((e)=>e.id.startsWith('rec_${r.id}_'));
       final ok=await confirmDeletion(waffraIsEnglish?'Delete recurring transaction?':'حذف العملية المتكررة',
        waffraRecurringDeleteWarning(r.title,hasHistory,waffraIsEnglish));
       if(ok==true&&mounted){
        if(_lastFinanceAuthorityRead?.source==
           WaffraRuntimeFinanceBackend.verifiedEncrypted){
         await _deleteVerifiedModule(
          module:WaffraFinanceModule.recurring,displayed:r.toJson());
         return;
        }
        setState((){
         deletedRecurring.add({'recurring':r.toJson(),'deletedAt':DateTime.now().toIso8601String()});
         recurring.removeWhere((e)=>e.id==r.id);
         recurringPostponed.removeWhere((key,value)=>key.startsWith('rec_${r.id}_'));
        });
        if(!await _persistModuleOrReload(
         WaffraFinanceRoute.recurringCreateEditDeleteRestore,
         operation:'recurring-delete'))return;
        await syncRecurringReminders();
       }

 }
 Widget recurringPage(){
  final today=DateUtils.dateOnly(DateTime.now());
  final shown=recurring.where((r){
   final goalDue=r.linkedGoalId!=null;
   final due=goalDue?r.startAt:nextRecurringDue(r);
   final date=DateUtils.dateOnly(due);
   final days=date.difference(today).inDays;
   final inView=switch(recurringDisplay){
    'today'=>r.active&&days==0,
    'week'=>r.active&&days>=0&&days<=7,
    'month'=>date.year==today.year&&date.month==today.month,
    'overdue'=>r.active&&days<0,
    'active'=>r.active,
    'paused'=>!r.active,
    _=>true,
   };
   return inView&&waffraSearchAny(
    [r.title,r.category,waffraTr(r.category)],recurringSearch);
  }).toList()..sort((a,b){
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
     const SizedBox(height:16),
     SingleChildScrollView(scrollDirection:Axis.horizontal,
      child:Row(children:[
       _filterChip(waffraIsEnglish?'All':'الكل',recurringDisplay=='all',
        ()=>setState(()=>recurringDisplay='all')),
       const SizedBox(width:8),
       _filterChip(waffraIsEnglish?'This week':'هذا الأسبوع',
        recurringDisplay=='week',()=>setState(()=>recurringDisplay='week')),
       const SizedBox(width:8),
       _filterChip(waffraIsEnglish?'This month':'هذا الشهر',
        recurringDisplay=='month',()=>setState(()=>recurringDisplay='month')),
       const SizedBox(width:8),
       _filterChip(waffraIsEnglish?'Overdue':'متأخرة',
        recurringDisplay=='overdue',()=>setState(()=>recurringDisplay='overdue')),
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
         fit:BoxFit.scaleDown,child:WaffraText(cash(amount),maxLines:1,
          style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)))),
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
     if(recurring.isEmpty)Padding(padding:const EdgeInsets.all(26),
      child:WaffraText(waffraIsEnglish?
       'No due payments yet':'ما عندك استحقاقات حتى الآن',
       textAlign:TextAlign.center)),
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

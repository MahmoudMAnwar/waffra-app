part of 'main.dart';

/// M735 / Issue #633: original verified category and recycle-bin flows.
/// Same-library extraction only; original source data and writers untouched.
extension _WaffraHomeCategoryWorkflows on _HomeScreenState {
 Future<BudgetCategory?> categoryDialog({BudgetCategory? initial,bool income=false,String? suggested,String parentId=''})async {
  final name=TextEditingController(text:initial?.displayName??suggested??'');
  final effectiveParentId=initial?.parentId??parentId;
  String fullName(){
   final text=name.text.trim();
   if(effectiveParentId.isEmpty)return text;
   final parent=categories.where((c)=>c.id==effectiveParentId).toList();
   return parent.isEmpty?text:'${parent.first.name} / $text';
  }
  // Category appearance and hierarchy are independent of budget setup.
  // Existing legacy limits/labels must survive editing this category.
  String icon=initial?.icon??'category';int color=initial?.color??colors[0];
  bool attempted=false;
  final result=await showWaffraDialog<BudgetCategory>(context:context,
   builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
    scrollable:true,
    insetPadding:const EdgeInsets.symmetric(horizontal:20,vertical:16),
    title:WaffraText(initial!=null?'تعديل القسم':effectiveParentId.isNotEmpty?'قسم فرعي جديد':'قسم رئيسي جديد'),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     TextField(controller:name,onChanged:(_)=>update((){}),decoration:InputDecoration(
      labelText:waffraIsEnglish?'Category name *':'اسم القسم *',
      errorText:attempted?(
       WaffraValidators.requiredText(name.text)!=null?waffraTextFieldError(name.text):
       WaffraValidators.uniqueCategory(fullName(),categories.where((c)=>c.id!=initial?.id&&c.income==(initial?.income??income)).map((c)=>c.name))!=null?(waffraIsEnglish?'Category already exists':'اسم القسم مستخدم بالفعل'):null):null)),
     const SizedBox(height:12),const WaffraText('اختر أيقونة'),
     Wrap(spacing:8,runSpacing:9,alignment:WrapAlignment.center,children:iconNames.map((x)=>IconButton(
      style:IconButton.styleFrom(backgroundColor:icon==x?emerald.withValues(alpha:.2):null),
      onPressed:WaffraHaptics.tap(()=>update(()=>icon=x)),icon:Icon(categoryIcon(x),color:icon==x?emerald:null))).toList()),
     const WaffraText('اختر لون'),
     const SizedBox(height:12),
     Wrap(spacing:12,runSpacing:12,alignment:WrapAlignment.center,children:colors.map((x)=>InkWell(
      onTap:WaffraHaptics.tap(()=>update(()=>color=x)),
      child:CircleAvatar(radius:15,backgroundColor:Color(x),
       child:color==x?const Icon(Icons.check,color:Colors.white,size:17):null))).toList()),
    ]),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('إلغاء')),
     FilledButton(onPressed:WaffraHaptics.tap((){
      final n=name.text.trim();update(()=>attempted=true);
      if(WaffraValidators.requiredText(n)!=null||
       WaffraValidators.uniqueCategory(fullName(),
        categories.where((c)=>c.id!=initial?.id&&
         c.income==(initial?.income??income)).map((c)=>c.name))!=null)return;
      Navigator.pop(ctx,BudgetCategory(id:initial?.id??newId(),name:fullName(),icon:icon,color:color,
       income:initial?.income??income,parentId:effectiveParentId,
       budget:initial?.budget??0,alertPercent:initial?.alertPercent??80,
       budgetActive:initial?.budgetActive??true,
       categoryActive:initial?.categoryActive??true,
       origin:initial?.origin??'user',budgetLabel:initial?.budgetLabel));
     }),child:const WaffraText('حفظ')),
    ])));
  disposeLater([name]);return result;
 }
 Future<void> chooseCategoryLevel({required bool income})async{
  final parents=categories.where((c)=>!c.isSubcategory&&c.income==income).toList();
  final choice=await showWaffraDialog<String>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(income
     ?(waffraIsEnglish?'Add income category':'إضافة قسم دخل')
     :(waffraIsEnglish?'Add expense category':'إضافة قسم مصروفات')),
    content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     ListTile(leading:const Icon(Icons.create_new_folder_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'New main category':'إضافة قسم رئيسي'),
      onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'main'))),
     ListTile(leading:const Icon(Icons.account_tree_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?'New subcategory':'إضافة قسم فرعي'),
      onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,'sub'))),
    ]),
   ));
  if(!mounted||choice==null)return;
  if(choice=='main'){await addCategory(income:income);return;}
  if(parents.isEmpty){
   snack(context,waffraIsEnglish?'Create a main category first':'يجب إضافة قسم رئيسي أولًا');
   return;
  }
  final parentId=await showWaffraDialog<String>(context:context,
   builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Choose main category':'اختر القسم الرئيسي'),
    content:SizedBox(width:double.maxFinite,height:waffraKeyboardDialogListHeight(ctx,desired:360),
     child:ListView.builder(itemCount:parents.length,itemBuilder:(ctx,index){
      final parent=parents[index];
      return ListTile(
       leading:Icon(categoryIcon(parent.icon),color:Color(parent.color)),
       title:WaffraText(parent.name),
       onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,parent.id)));
     })),
   ));
  if(!mounted||parentId==null)return;
  await addCategory(income:income,parentId:parentId);
 }
 /// Category actions are reversible and never rewrite ledger, budgets, goal
 /// funds or historical references. Only new-category eligibility changes.
 Future<void> setCategoryActive(BudgetCategory selected,bool enabled)async{
  final current=categories.where((c)=>c.id==selected.id).toList();
  if(current.length!=1||current.single.categoryActive==enabled)return;
  if(!enabled){
   final affected=selected.isSubcategory?0:
    categories.where((c)=>c.parentId==selected.id).length;
   final approved=await showWaffraDialog<bool>(
    context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?'Pause category?':'إيقاف القسم مؤقتًا؟'),
     content:WaffraText(waffraIsEnglish?
      'The category and ${affected>0?'its $affected subcategories ':''}will no longer be selectable for new transactions. Existing transactions, recurring references and budgets are kept unchanged.':
      'القسم ${affected>0?'وعدد $affected قسم فرعي تابع له ':''}لن يكون متاحًا للعمليات الجديدة. معاملاتك القديمة والعمليات المتكررة والميزانيات محفوظة بدون تغيير.'),
     actions:[
      TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,false)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
      FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx,true)),
       child:WaffraText(waffraIsEnglish?'Pause':'إيقاف')),
     ],
    ));
   if(approved!=true||!mounted)return;
  }
  final live=categories.where((c)=>c.id==selected.id).toList();
  if(live.length!=1||live.single.categoryActive==enabled)return;
  setState((){
   final index=categories.indexWhere((c)=>c.id==selected.id);
   categories[index]=categories[index].copy(categoryActive:enabled);
  });
  final saved=await _persistModuleOrReload(
   WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   operation:'category-availability-toggle');
  if(saved&&mounted){
   await syncRecurringReminders();
   if(mounted)snackSuccess(context,waffraIsEnglish?
    (enabled?'Category enabled':'Category paused'):
    (enabled?'تم تفعيل القسم':'تم إيقاف القسم مؤقتًا'));
  }
 }
 Future<void> addCategory({bool income=false,String parentId=''})async {
  if(parentId.isNotEmpty&&!categories.any((c)=>
   c.id==parentId&&!c.isSubcategory&&c.categoryActive)){
   snack(context,waffraIsEnglish?
    'Enable the main category before adding a subcategory.':
    'فعّل القسم الرئيسي قبل إضافة قسم فرعي.');
   return;
  }
  final c=await categoryDialog(income:income,parentId:parentId);
  if(c==null||!mounted)return;
  if(WaffraValidators.uniqueCategory(c.name,
    categories.where((x)=>x.income==c.income).map((x)=>x.name))=='duplicate'){
   snack(context,'القسم موجود بالفعل');return;
  }
  setState(()=>categories.add(c));
  await _persistModuleOrReload(WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   operation:'category-create');
 }
 Future<void> updateCategory(BudgetCategory c)async {
  final revised=await categoryDialog(initial:c);
  if(revised==null||!mounted)return;
  if(WaffraValidators.uniqueCategory(revised.name,
    categories.where((x)=>x.id!=c.id&&x.income==c.income).map((x)=>x.name))=='duplicate'){
   snack(context,waffraIsEnglish?'Category already exists':'القسم موجود بالفعل');return;
  }
  final renames=<String,String>{c.name:revised.name};
  if(!c.isSubcategory&&c.name!=revised.name){
   for(final child in categories.where((x)=>x.parentId==c.id)){
    renames[child.name]='${revised.name} / ${child.displayName}';
   }
  }
  setState((){
   final i=categories.indexWhere((x)=>x.id==c.id);
   if(i>=0)categories[i]=revised;
   for(var j=0;j<categories.length;j++){
    final child=categories[j];
    if(child.parentId==c.id&&renames.containsKey(child.name)){
     categories[j]=child.copy(name:renames[child.name]);
    }
   }
   for(var j=0;j<entries.length;j++){
    final old=entries[j];
    final renamed=renames[old.category];
    if(renamed!=null&&old.income==c.income){
     entries[j]=old.withCategory(renamed);
    }
   }
   for(var j=0;j<recurring.length;j++){
    final old=recurring[j];
    final renamed=renames[old.category];
    if(renamed!=null&&old.income==c.income){
     recurring[j]=old.withCategory(renamed);
    }
   }
  });
  try{
   await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  }catch(error){
   debugPrint('Category edit not committed by verified finance source: $error');
   if(mounted)await _loadFinanceSafely();
   if(mounted)snack(context,waffraIsEnglish?
    'Category edit was not saved. Financial data was reloaded safely.':
    'لم يتم حفظ تعديل القسم. أعدنا تحميل بياناتك المالية بشكل آمن.');
  }
 }
 WaffraFinanceRoute _moduleMutationRoute(WaffraFinanceModule module)=>
  switch(module){
   WaffraFinanceModule.categories=>WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   WaffraFinanceModule.goals=>WaffraFinanceRoute.goalCreateEditDeleteRestore,
   WaffraFinanceModule.recurring=>WaffraFinanceRoute.recurringCreateEditDeleteRestore,
  };

 Future<void> _deleteVerifiedModule({
  required WaffraFinanceModule module,
  required Map<String,dynamic> displayed,
 })async{
  try{
   await _financialWriteQueue.drain();
   final baseline=await _financeAuthority.load(route:_moduleMutationRoute(module));
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
      baseline.encryptedWitness==null){
    throw StateError('Verified encrypted finance source is unavailable.');
   }
   WaffraVerifiedModuleUiGuard.requireUnchanged(
    activeRaw:baseline.finance.getString(
     WaffraVerifiedModuleUiGuard.activeKey(module)),
    selected:displayed,
   );
   final id=displayed['id'] as String;
   await _financialWriteQueue.submit(<String,Object>{'id':id},(_)async{
    // No optimistic mutation to goals/categories/recurring; only the typed
    // SQLCipher tombstone writer may remove the source entity.
    await _financeAuthority.deleteVerifiedModuleToRecycle(
     baseline:baseline,module:module,entityId:id,
     now:DateTime.now().toUtc(),userConfirmed:true);
   });
   if(!mounted)return;
   await _loadFinanceSafely();
   if(module==WaffraFinanceModule.recurring)await syncRecurringReminders();
   if(mounted&&ready)snackSuccess(context,waffraIsEnglish?
    'Moved to encrypted Recently Deleted for 30 days':
    'تم النقل إلى المحذوفات لمدة 30 يومًا');
  }catch(error){
   debugPrint('Encrypted module delete refused: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Cannot verify deletion. Your financial data was not reset. Reload and retry.':
     'تعذر التحقق من الحذف. لم يتم تصفير البيانات المالية. أعد التحميل وحاول مجددًا.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _restoreVerifiedModule({
  required WaffraFinanceModule module,
  required String entityId,
 })async{
  try{
   await _financialWriteQueue.drain();
   await _financialWriteQueue.submit(<String,Object>{'id':entityId},(_)async{
    final baseline=await _financeAuthority.load(route:_moduleMutationRoute(module));
    if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted||
       baseline.encryptedWitness==null){
     throw StateError('Verified encrypted module restore source is missing.');
    }
    await _financeAuthority.restoreVerifiedDeletedModule(
     baseline:baseline,module:module,entityId:entityId,
     now:DateTime.now().toUtc());
   });
   if(!mounted)return;
   await _loadFinanceSafely();
   if(module==WaffraFinanceModule.recurring)await syncRecurringReminders();
   if(mounted&&ready)snackSuccess(context,waffraIsEnglish?
    'Item restored':'تم استرجاع العنصر');
  }catch(error){
   debugPrint('Encrypted finance module restoration blocked safely: $error');
   if(mounted){
    snack(context,waffraIsEnglish?
     'Restore was not verified. Restore the deleted parent first or retry safely.':
     'تعذر التحقق من الاسترجاع. استرجع القسم الرئيسي أولًا أو حاول مجددًا.');
    unawaited(_loadFinanceSafely());
   }
  }
 }

 Future<void> _showVerifiedModuleTrash(WaffraFinanceModule module)async{
  try{
   final route=_moduleMutationRoute(module);
   final baseline=await _financeAuthority.load(route:route);
   if(baseline.source!=WaffraRuntimeFinanceBackend.verifiedEncrypted){
    throw StateError('Encrypted module trash source was not selected.');
   }
   final expiries=await _financeAuthority.listVerifiedDeletedModules(module);
   final items=WaffraVerifiedModuleUiGuard.verifiedTrash(
    module:module,
    trashRaw:baseline.finance.getString(
     WaffraVerifiedModuleUiGuard.trashKey(module)),
    encryptedExpiries:expiries,
   );
   if(!mounted)return;
   final labels=module==WaffraFinanceModule.categories
    ?<String>['Categories','الأقسام']
    :module==WaffraFinanceModule.goals
     ?<String>['Savings goals','الأهداف']
     :<String>['Recurring','المتكررة'];
   final choice=await showWaffraDialog<String>(
    context:context,builder:(ctx)=>AlertDialog(
     title:WaffraText(waffraIsEnglish?
      'Encrypted Recently Deleted — ${labels[0]}':
      'المحذوفات — ${labels[1]}'),
     content:SizedBox(
      width:double.maxFinite,
      height:min(365.0,items.length*78.0+35.0),
      child:items.isEmpty
       ?Center(child:WaffraText(waffraIsEnglish?
        'No items available to restore':'لا توجد عناصر قابلة للاسترجاع'))
       :ListView.builder(itemCount:items.length,itemBuilder:(ctx,index){
        final item=items[index];
        final body=item[WaffraVerifiedModuleUiGuard.trashPayloadKey(module)]
          as Map<String,dynamic>;
        final id=body['id'] as String;
        final until=expiries[id]!;
        final expired=DateTime.now().toUtc().millisecondsSinceEpoch>=until;
        return ListTile(
         leading:Icon(Icons.restore_rounded,
          color:expired?Colors.grey:emerald),
         title:WaffraText('${body['name']??body['title']??id}',maxLines:1),
         subtitle:WaffraText(expired
          ?(waffraIsEnglish?'Recovery expired':'انتهت مدة الاسترجاع')
          :(waffraIsEnglish
           ?'Restore until ${dayText(DateTime.fromMillisecondsSinceEpoch(until,isUtc:true).toLocal())}'
           :'الاسترجاع حتى ${dayText(DateTime.fromMillisecondsSinceEpoch(until,isUtc:true).toLocal())}')),
         enabled:!expired,
         onTap:WaffraHaptics.tap(expired?null:()=>Navigator.pop(ctx,id)),
        );
       })),
     actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]));
   if(choice!=null&&mounted)await _restoreVerifiedModule(
    module:module,entityId:choice);
  }catch(error){
   debugPrint('Encrypted module trash could not be verified: $error');
   if(mounted)snack(context,waffraIsEnglish?
    'Encrypted Recently Deleted is unavailable until source verification succeeds.':
    'المحذوفات المشفرة غير متاحة حتى ينجح التحقق من المصدر.');
  }
 }

 Future<void> deleteCategory(BudgetCategory c)async {
  final children=categories.where((item)=>item.parentId==c.id).toList();
  if(children.isNotEmpty){
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Delete subcategories first':'احذف الأقسام الفرعية أولاً'),
    content:WaffraText(waffraIsEnglish?'This category has ${children.length} subcategories. Delete or move them first to protect your categorization.':'القسم يحتوي على ${children.length} قسم فرعي. احذف الأقسام الفرعية أولاً للحفاظ على تصنيف المعاملات.'),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:WaffraText(waffraIsEnglish?'OK':'حسنًا'))]));
   return;
  }
  final linkedEntries=entries.where((e)=>e.category==c.name&&e.income==c.income).length;
  final linkedRecurring=recurring.where((e)=>e.category==c.name&&e.income==c.income).length;
  if(linkedEntries>0||linkedRecurring>0){
   if(!mounted)return;
   await showWaffraDialog<void>(context:context,builder:(ctx)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Category cannot be deleted':'لا يمكن حذف القسم'),
    content:WaffraText(waffraIsEnglish
     ?'This category has $linkedEntries transactions and $linkedRecurring recurring items. Remove linked items first.'
     :'القسم مرتبط بـ$linkedEntries معاملة و$linkedRecurring عملية متكررة. احذف العناصر المرتبطة أولًا.'),
    actions:[
     TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),child:const WaffraText('حسنًا')),
     if(linkedEntries>0)TextButton(onPressed:WaffraHaptics.tap((){
      Navigator.pop(ctx);
      setState((){
       tab=0;addFabExpanded=false;showAllTransactions=true;
       showTransactionFilters=true;categoryFilter=c.name;
       typeFilter=c.income?'الدخل':'المصروفات';
       search='';transactionsDateRange=null;
       minTransactionAmount=null;maxTransactionAmount=null;
      });
     }),child:WaffraText(waffraIsEnglish?'View transactions':'عرض المعاملات المرتبطة'))
     else TextButton(onPressed:WaffraHaptics.tap((){
      Navigator.pop(ctx);setState((){tab=4;goalsOpened=false;addFabExpanded=false;});
     }),child:WaffraText(waffraIsEnglish?'View recurring':'عرض العمليات المتكررة')),
    ]));
   return;
  }
  final yes=await confirmDeletion(
   waffraIsEnglish?'Delete category?':'حذف القسم',
   waffraIsEnglish
    ?'Delete «${c.name}» for 30 days? Restore is possible, but its budget resets to zero.'
    :'هل تريد نقل القسم «${c.name}» إلى المحذوفات لمدة 30 يومًا؟ عند استرجاعه سيعود بميزانية صفر.');
  if(yes!=true||!mounted)return;
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _deleteVerifiedModule(
    module:WaffraFinanceModule.categories,displayed:c.toJson());
   return;
  }
  setState((){
   categories.removeWhere((e)=>e.id==c.id);
   deletedCategories.add({'category':c.toJson(),'deletedAt':DateTime.now().toIso8601String()});
  });
  await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  if(mounted)snackSuccess(context,waffraIsEnglish?'Category moved to Recently Deleted for 30 days':'تم نقل القسم للمحذوفات لمدة 30 يومًا');
 }
 Future<void> showCategoryTrash()async {
  if(_lastFinanceAuthorityRead?.source==
     WaffraRuntimeFinanceBackend.verifiedEncrypted){
   await _showVerifiedModuleTrash(WaffraFinanceModule.categories);
   return;
  }
  final before=deletedCategories.length;
  deletedCategories.removeWhere((item){
   final when=DateTime.tryParse('${item['deletedAt']??''}');
   return when==null||!DateTime.now().isBefore(when.add(const Duration(days:30)));
  });
  if(before!=deletedCategories.length)await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
  if(!mounted)return;
  await showWaffraDialog<void>(context:context,builder:(dialogCtx)=>StatefulBuilder(
   builder:(dialogCtx,refresh)=>AlertDialog(
    title:WaffraText(waffraIsEnglish?'Recently deleted categories':'الأقسام المحذوفة'),
    content:SizedBox(width:double.maxFinite,height:waffraDeletedListHeight(dialogCtx,deletedCategories.length),
     child:deletedCategories.isEmpty
      ?Center(child:WaffraText(waffraIsEnglish?'No deleted categories':'لا توجد أقسام محذوفة'))
      :ListView(children:deletedCategories.map((item){
        final original=BudgetCategory.fromJson(Map<String,dynamic>.from(item['category'] as Map));
        final deletedAt=DateTime.parse(item['deletedAt'] as String);
        final daysLeft=max(0,(deletedAt.add(const Duration(days:30))
         .difference(DateTime.now()).inHours/24).ceil());
        return waffraDeletedItemCard(
         context:dialogCtx,
         icon:categoryIcon(original.icon),
         iconColor:Color(original.color),
         title:original.name,
         subtitle:waffraIsEnglish
          ?'${original.income?'Income':'Expense'} • $daysLeft days remaining'
          :'${original.income?'دخل':'مصروفات'} • متبقي $daysLeft يوم',
         onRestore:()async{
             if(WaffraValidators.uniqueCategory(original.name,
               categories.where((c)=>c.income==original.income).map((c)=>c.name))=='duplicate'){
              snack(dialogCtx,waffraIsEnglish?'A category with this name already exists':'يوجد قسم نشط بنفس الاسم بالفعل');return;
             }
             BudgetCategory? restoreParent;
             if(original.isSubcategory&&
              !categories.any((c)=>c.id==original.parentId)){
              final deletedParent=deletedCategories.where((record){
               final raw=record['category'];
               return raw is Map&&raw['id']==original.parentId;
              }).toList();
              if(deletedParent.isEmpty){
               snack(dialogCtx,waffraIsEnglish
                ?'Restore the main category first. It is no longer in Recently Deleted.'
                :'يجب استرجاع القسم الرئيسي أولًا؛ لأنه غير موجود في الأقسام المحذوفة.');
               return;
              }
              restoreParent=BudgetCategory.fromJson(
               Map<String,dynamic>.from(deletedParent.first['category'] as Map));
              if(categories.any((c)=>c.income==restoreParent!.income&&c.name==restoreParent.name)){
               snack(dialogCtx,waffraIsEnglish
                ?'Cannot restore the parent: another category has the same name.'
                :'لا يمكن استرجاع القسم الرئيسي لوجود قسم آخر بنفس الاسم.');
               return;
              }
              final approved=await showWaffraDialog<bool>(context:dialogCtx,
               builder:(confirmCtx)=>AlertDialog(
                title:WaffraText(waffraIsEnglish?'Restore main category too?':'استرجاع القسم الرئيسي أيضًا؟'),
                content:WaffraText(waffraIsEnglish
                 ?'Restoring also restores «${restoreParent!.name}». Both budgets reset to zero. Continue?'
                 :'سيُسترجع أيضًا القسم الرئيسي «${restoreParent!.name}»، وتُصفّر الميزانيتان. متابعة؟'),
                actions:[
                 TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(confirmCtx,false)),
                  child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
                 FilledButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(confirmCtx,true)),
                  child:WaffraText(waffraIsEnglish?'Restore both':'استرجاع الاثنين')),
                ]));
              if(approved!=true||!dialogCtx.mounted)return;
             }
             final restored=original.copy(budget:0);
             setState((){
              if(restoreParent!=null){
               categories.add(restoreParent.copy(budget:0));
               deletedCategories.removeWhere((record){
                final raw=record['category'];
                return raw is Map&&raw['id']==restoreParent!.id;
               });
              }
              categories.add(restored);
              deletedCategories.remove(item);
             });
             await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
             if(!dialogCtx.mounted)return;
             Navigator.pop(dialogCtx);
             if(mounted)snackSuccess(context,waffraIsEnglish
              ?'Category restored with zero budget. Past transactions are unchanged.'
              :'تم استرجاع القسم بميزانية صفر. معاملاتك القديمة محفوظة.');
            },
         onDeleteForever:()async{
             final yes=await confirmDeletion(
              waffraIsEnglish?'Permanently delete category?':'حذف القسم نهائيًا',
              waffraIsEnglish?'Delete «${original.name}» forever? You cannot restore it.'
               :'هل تريد حذف القسم «${original.name}» نهائيًا؟ لا يمكن استرجاعه بعد ذلك.');
             if(yes==true&&mounted){
              setState(()=>deletedCategories.remove(item));
              refresh((){});
              await persist(route:WaffraFinanceRoute.categoryCreateEditDeleteRestore);
             }
            },
        );
       }).toList())),
    actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
     child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
   )));
 }
}

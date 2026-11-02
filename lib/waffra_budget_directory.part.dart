part of 'main.dart';

/// Budget directory lives in Categories but does not create a second ledger,
/// alter category IDs, or infer transactions from names.
extension WaffraBudgetDirectory on _HomeScreenState {
 /// A separate bounded sheet keeps the budget controls out of the lazy
 /// Categories ListView. The old nested ExpansionTile/LayoutBuilder could
 /// render as a large grey ErrorWidget on narrow Android devices.
 Future<void> showBudgetsDirectorySheet() async {
  // Only state for this modal instance: reopening must not restore stale
  // PageStorage expansion state or reuse an already-disposed sheet context.
  var directoryScope='all';
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
   backgroundColor:Theme.of(context).scaffoldBackgroundColor,
   builder:(sheetCtx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.82,minChildSize:.45,maxChildSize:.96,
    builder:(ctx,scroll)=>StatefulBuilder(
     builder:(ctx,refresh)=>ListView(
      controller:scroll,
      padding:EdgeInsets.fromLTRB(
       14,0,14,28+MediaQuery.viewInsetsOf(ctx).bottom),
      children:[_budgetDirectoryPanel(
       refresh,scope:directoryScope,
       onScopeChanged:(value)=>refresh(()=>directoryScope=value))],
     ),
    ),
   ),
  );
  // Refresh the summary card after any modal budget edit/delete/toggle.
  refreshFromBudgetDirectory();
 }
 Widget budgetsDirectory(){
  final count=namedBudgets.where((b)=>!b.deleted).length;
  return Container(
   key:const Key('waffra-my-budgets-entry'),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    border:Border.all(color:emerald.withValues(alpha:.24)),
    borderRadius:BorderRadius.circular(18)),
   child:ListTile(
    onTap:WaffraHaptics.tap(showBudgetsDirectorySheet),
    leading:const Icon(Icons.account_balance_wallet_outlined,color:emerald),
    title:WaffraText(waffraIsEnglish?'My budgets':'ميزانياتي',
      style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:WaffraText(waffraIsEnglish?
      '$count saved budgets':'$count ميزانية محفوظة',
      style:const TextStyle(fontSize:12)),
    trailing:const Icon(Icons.chevron_right_rounded,color:emerald),
   ),
  );
 }
 Widget _budgetDirectoryPanel(StateSetter refresh,{
  required String scope,required ValueChanged<String> onScopeChanged,
 }){

  final now=DateTime.now();
  // Standalone budgets are not filtered by main/subcategory.
  final saved=namedBudgets.where((b)=>!b.deleted).toList();
  final filtered=saved.where((b){
   if(budgetStatusFilter=='active'&&!b.budgetActive)return false;
   if(budgetStatusFilter=='inactive'&&b.budgetActive)return false;
   return waffraSearchAny([
    b.budgetLabel??b.name,b.name,waffraTr(b.name),
   ],budgetSearch);
  }).toList();
  if(budgetSort=='name')filtered.sort((a,b)=>
   (a.budgetLabel??a.displayName).compareTo(b.budgetLabel??b.displayName));
  if(budgetSort=='limit')filtered.sort((a,b)=>b.budget.compareTo(a.budget));
  if(budgetSort=='spent')filtered.sort((a,b)=>
   waffraNamedBudgetSpent(entries,categories,b,now).compareTo(
    waffraNamedBudgetSpent(entries,categories,a,now)));
  final templates=waffraBudgetStarterTemplates.where((t)=>
   waffraSearchAny([
   t.nameAr,t.nameEn,
  ],budgetSearch)).toList();
  return Container(
   key:const Key('waffra-my-budgets-panel'),
   padding:const EdgeInsets.fromLTRB(14,8,14,16),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    border:Border.all(color:emerald.withValues(alpha:.24)),
    borderRadius:BorderRadius.circular(18)),
   // No nested root ExpansionTile: the draggable sheet is itself the sole
   // scrolling surface. This also avoids stale PageStorage on reopen.
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Padding(padding:const EdgeInsets.only(bottom:12),
     child:Row(children:[
      const Icon(Icons.account_balance_wallet_outlined,color:emerald),
      const SizedBox(width:10),
      Expanded(child:Column(
       crossAxisAlignment:CrossAxisAlignment.start,children:[
        WaffraText(waffraIsEnglish?'My budgets':'ميزانياتي',
         style:const TextStyle(fontWeight:FontWeight.bold)),
        WaffraText(waffraIsEnglish?
         '${saved.length} saved budgets':'${saved.length} ميزانية محفوظة',
         style:const TextStyle(fontSize:12)),
       ])),
     ])),

     TextFormField(
      key:const Key('waffra-budget-directory-search'),
      initialValue:budgetSearch,
      onChanged:(v)=>refresh(()=>budgetSearch=v),
      decoration:InputDecoration(
       labelText:waffraIsEnglish?'Search budgets':'ابحث في الميزانيات',
       prefixIcon:const Icon(Icons.search_rounded),
       border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))),
     ),
     const SizedBox(height:14),
     // Stable single-column filters avoid unbounded Wrap/Dropdown sizing
     // failures under Android text scaling and the draggable sheet.
     Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      // All displays owned budgets plus optional unsaved suggestions.
      // Every saved standalone budget belongs to this user, even when
      // created using a suggested template or migrated from legacy data.
      WaffraCenteredDropdownFormField<String>(
       key:ValueKey('waffra-budget-directory-scope-'+scope),
       initialValue:scope,isExpanded:true,
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Show':'عرض',
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))),
       items:[
        DropdownMenuItem(value:'all',child:WaffraText(
         waffraIsEnglish?'Budgets and suggestions':'الميزانيات والمقترحات')),
        DropdownMenuItem(value:'mine',child:WaffraText(
         waffraIsEnglish?'Budgets I added':'ميزانياتي المضافة بواسطتي')),
       ],
       onChanged:WaffraHaptics.selection((v){
        if(v!=null)onScopeChanged(v);
       }),
      ),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<String>(
       key:ValueKey('waffra-budget-directory-status-'+budgetStatusFilter),
       initialValue:const {'all','active','inactive'}.contains(budgetStatusFilter)?
        budgetStatusFilter:'all',isExpanded:true,
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Status':'الحالة',
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))),
       items:[
        DropdownMenuItem(value:'all',child:WaffraText(
         waffraIsEnglish?'All budgets':'كل الميزانيات')),
        DropdownMenuItem(value:'active',child:WaffraText(
         waffraIsEnglish?'Active budgets':'الميزانيات الفعّالة')),
        DropdownMenuItem(value:'inactive',child:WaffraText(
         waffraIsEnglish?'Paused budgets':'الميزانيات غير الفعّالة')),
       ],
       onChanged:WaffraHaptics.selection((v){
        if(v!=null)refresh((){
         budgetStatusFilter=v;
         selectedNamedBudgetCategoryId=null;
        });
       }),
      ),
      const SizedBox(height:12),
      WaffraCenteredDropdownFormField<String>(
       key:ValueKey('waffra-budget-directory-sort-'+budgetSort),
       initialValue:const {'default','name','limit','spent'}.contains(budgetSort)?
        budgetSort:'default',isExpanded:true,
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Sort by':'الترتيب حسب',
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))),
       items:[
        DropdownMenuItem(value:'default',child:WaffraText(
         waffraIsEnglish?'Default':'الافتراضي')),
        DropdownMenuItem(value:'name',child:WaffraText(
         waffraIsEnglish?'Name':'الاسم')),
        DropdownMenuItem(value:'limit',child:WaffraText(
         waffraIsEnglish?'Largest limit':'أعلى ميزانية')),
        DropdownMenuItem(value:'spent',child:WaffraText(
         waffraIsEnglish?'Highest spent':'الأكثر صرفًا')),
       ],
       onChanged:WaffraHaptics.selection((v){
        if(v!=null)refresh(()=>budgetSort=v);
       }),
      ),
     ]),
     const SizedBox(height:10),
     Align(alignment:AlignmentDirectional.centerStart,
      child:TextButton.icon(
       key:const Key('waffra-budgets-directory-create'),
       onPressed:WaffraHaptics.tap(()async{
        await chooseBudgetCategory();
        if(mounted)refresh((){});
       }),
       icon:const Icon(Icons.add_circle_outline_rounded),
       label:WaffraText(waffraIsEnglish?'Create budget':'إضافة ميزانية جديدة'))),
     const SizedBox(height:14),
     if(filtered.isEmpty)Padding(
      padding:const EdgeInsets.symmetric(vertical:14),
      child:WaffraText(waffraIsEnglish?'No matching saved budgets':
       'لا توجد ميزانيات محفوظة مطابقة',
       textAlign:TextAlign.center)),
     ...filtered.map((b){
      final spent=waffraNamedBudgetSpent(entries,categories,b,now);
      final ratio=(spent/b.budget).clamp(0.0,1.0);
      return Padding(
       padding:const EdgeInsets.only(bottom:12),
       child:Container(
        key:Key('waffra-saved-budget-'+b.id),
        padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(
         border:Border.all(color:emerald.withValues(alpha:.23)),
         borderRadius:BorderRadius.circular(14)),
        child:ExpansionTile(
         key:PageStorageKey<String>('waffra-saved-budget-details-'+b.id),
         initiallyExpanded:false,
         tilePadding:EdgeInsets.zero,
         childrenPadding:const EdgeInsets.only(bottom:8),
         title:WaffraText(b.budgetLabel??('ميزانية '+b.displayName),
          maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold)),
         subtitle:Row(mainAxisSize:MainAxisSize.min,children:[
          Expanded(child:WaffraText(b.budgetActive?
           (waffraIsEnglish?'Active':'مفعلة'):
           (waffraIsEnglish?'Paused':'متوقفة'),
           style:const TextStyle(fontSize:12))),
          Switch.adaptive(
           key:Key('waffra-budget-activation-'+b.id),
           value:b.budgetActive,
           onChanged:WaffraHaptics.selection((enabled)async{
            if(enabled==b.budgetActive)return;
            await setNamedBudgetActive(b,!b.budgetActive);
            if(mounted)refresh((){});
           })),
         ]),
         children:[
         if(!b.alertsEnabled)Padding(
          padding:const EdgeInsets.only(bottom:8),
          child:WaffraText(waffraIsEnglish?
           'Percentage alerts off — edit budget to enable':
           'تنبيهات النسبة متوقفة — فعّلها من تعديل الميزانية',
           style:const TextStyle(fontSize:12,color:Colors.grey))),
         const SizedBox(height:8),
         LinearProgressIndicator(value:ratio,minHeight:7,
          color:spent>b.budget?Colors.deepOrange:emerald,
          backgroundColor:emerald.withValues(alpha:.1)),
         const SizedBox(height:6),
         WaffraText(waffraIsEnglish?
          'Limit: '+cash(b.budget)+'  •  Spent: '+cash(spent)+'  •  Left: '+cash(b.budget-spent):
          'الحد: '+cash(b.budget)+'  •  المصروف: '+cash(spent)+'  •  المتبقي: '+cash(b.budget-spent),
          maxLines:3,style:const TextStyle(fontSize:12)),
         const SizedBox(height:8),
         ExpansionTile(
          key:PageStorageKey<String>('waffra-budget-quick-actions-'+b.id),
          initiallyExpanded:false,
          tilePadding:EdgeInsets.zero,
          childrenPadding:const EdgeInsets.only(bottom:8),
          leading:const Icon(Icons.settings_rounded,color:emerald,size:20),
          title:WaffraText(waffraIsEnglish?'Quick actions':'إجراءات سريعة',
           style:const TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
          children:[
           Wrap(spacing:8,runSpacing:8,children:[
          TextButton.icon(
           onPressed:WaffraHaptics.tap(()async{
            await editBudgetForCategory(b);
            if(mounted)refresh((){});
           }),
           icon:const Icon(Icons.edit_outlined,size:17),
           label:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
          TextButton.icon(
           onPressed:WaffraHaptics.tap(()async{
            await deleteNamedBudget(b);
            if(mounted)refresh((){});
           }),
           icon:const Icon(Icons.delete_outline_rounded,size:17,
            color:Colors.deepOrange),
           label:WaffraText(waffraIsEnglish?'Delete':'حذف',
            style:const TextStyle(color:Colors.deepOrange))),

           ]),
          ],
         ),
        ]),
       ),
      );
     }),
     const SizedBox(height:20),
     if(scope!='mine')ExpansionTile(
      key:const PageStorageKey<String>('waffra-budget-starter-templates'),
      initiallyExpanded:false,
      tilePadding:EdgeInsets.zero,
      childrenPadding:const EdgeInsets.only(bottom:12),
      leading:const Icon(Icons.auto_awesome_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'Suggested budgets':'ميزانيات مقترحة',
       style:const TextStyle(fontWeight:FontWeight.bold)),

      children:[
       if(templates.isEmpty)
        WaffraText(waffraIsEnglish?'No matching templates':
         'لا توجد قوالب مطابقة'),
       Wrap(spacing:10,runSpacing:12,children:[
        for(final t in templates)
         ActionChip(
          key:Key('waffra-budget-template-'+t.nameAr),
          materialTapTargetSize:MaterialTapTargetSize.padded,
          padding:const EdgeInsets.symmetric(horizontal:11,vertical:10),
          avatar:const Icon(Icons.add_rounded,size:19,color:emerald),
          label:WaffraText(t.name(waffraIsEnglish),
           style:const TextStyle(fontSize:14,fontWeight:FontWeight.w600)),
          onPressed:WaffraHaptics.tap(()=>
           chooseBudgetCategory(
            suggestedName:t.name(waffraIsEnglish))),
         ),
       ]),
      ]),
    ],
   ),
  );
 }
}

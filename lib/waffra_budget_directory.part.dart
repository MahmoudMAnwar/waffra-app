part of 'main.dart';

/// Budget directory lives in Categories but does not create a second ledger,
/// alter category IDs, or infer transactions from names.
extension WaffraBudgetDirectory on _HomeScreenState {
 /// A separate bounded sheet keeps the budget controls out of the lazy
 /// Categories ListView. The old nested ExpansionTile/LayoutBuilder could
 /// render as a large grey ErrorWidget on narrow Android devices.
 Future<void> showBudgetsDirectorySheet() async {
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
   backgroundColor:Theme.of(context).scaffoldBackgroundColor,
   builder:(sheetCtx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.82,minChildSize:.45,maxChildSize:.96,
    builder:(ctx,scroll)=>StatefulBuilder(
     builder:(ctx,refresh)=>ListView(
      controller:scroll,
      padding:const EdgeInsets.fromLTRB(14,0,14,28),
      children:[_budgetDirectoryPanel(refresh)],
     ),
    ),
   ),
  );
  // Refresh the summary card after any modal budget edit/delete/toggle.
  refreshFromBudgetDirectory();
 }
 Widget budgetsDirectory(){
  final count=categories.where((c)=>!c.income&&c.budget>0).length;
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
 Widget _budgetDirectoryPanel(StateSetter refresh){

  final now=DateTime.now();
  // Preserve the visibility of legacy parent-category budgets on upgrades.
  final saved=categories.where((c)=>!c.income&&c.budget>0).toList();
  final parents={for(final c in categories.where((c)=>!c.isSubcategory))c.id:c.name};
  final filtered=saved.where((b){
   if(budgetStatusFilter=='active'&&!b.budgetActive)return false;
   if(budgetStatusFilter=='inactive'&&b.budgetActive)return false;
   return waffraSearchAny([
    b.budgetLabel??('ميزانية '+b.displayName),b.name,
    b.displayName,waffraTr(b.name),parents[b.parentId]??'',
    waffraTr(parents[b.parentId]??''),
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
   t.nameAr,t.nameEn,t.subcategoryAr,parents[t.mainCategoryId]??'',
  ],budgetSearch)).toList();
  return Container(
   key:const Key('waffra-my-budgets-panel'),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    border:Border.all(color:emerald.withValues(alpha:.24)),
    borderRadius:BorderRadius.circular(18)),
   child:ExpansionTile(
    key:const PageStorageKey<String>('waffra-my-budgets-directory-sheet'),
    initiallyExpanded:true,
    tilePadding:const EdgeInsets.symmetric(horizontal:14),
    childrenPadding:const EdgeInsets.fromLTRB(14,6,14,16),
    leading:const Icon(Icons.account_balance_wallet_outlined,color:emerald),
    title:WaffraText(waffraIsEnglish?'My budgets':'ميزانياتي',
     style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle:WaffraText(waffraIsEnglish?
     saved.length.toString()+' saved budgets':
     saved.length.toString()+' ميزانية محفوظة',
     style:const TextStyle(fontSize:12)),
    children:[
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
      DropdownButtonFormField<String>(
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
      DropdownButtonFormField<String>(
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
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
         WaffraText(b.budgetLabel??('ميزانية '+b.displayName),
          maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold)),

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
            await setNamedBudgetActive(b,!b.budgetActive);
            if(mounted)refresh((){});
           }),
           icon:Icon(b.budgetActive?
            Icons.pause_circle_outline:Icons.play_circle_outline,size:17),
           label:WaffraText(b.budgetActive?
            (waffraIsEnglish?'Pause':'إيقاف'):
            (waffraIsEnglish?'Resume':'تفعيل'))),
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
     const SizedBox(height:10),
     ExpansionTile(
      key:const PageStorageKey<String>('waffra-budget-starter-templates'),
      initiallyExpanded:true,
      tilePadding:EdgeInsets.zero,
      childrenPadding:const EdgeInsets.only(bottom:8),
      leading:const Icon(Icons.auto_awesome_outlined,color:emerald),
      title:WaffraText(waffraIsEnglish?
       'Suggested budgets':'ميزانيات مقترحة',
       style:const TextStyle(fontWeight:FontWeight.bold)),
      subtitle:WaffraText(waffraIsEnglish?
       'Optional templates — enter your own monthly limit':
       'قوالب اختيارية — انت اللي بتحدد الحد الشهري',
       style:const TextStyle(fontSize:12)),
      children:[
       if(templates.isEmpty)
        WaffraText(waffraIsEnglish?'No matching templates':
         'لا توجد قوالب مطابقة'),
       Wrap(spacing:8,runSpacing:10,children:[
        for(final t in templates)
         ActionChip(
          key:Key('waffra-budget-template-'+t.mainCategoryId+'-'+t.subcategoryAr),
          avatar:const Icon(Icons.add_rounded,size:16,color:emerald),
          label:WaffraText(t.name(waffraIsEnglish),
           style:const TextStyle(fontSize:12)),
          onPressed:WaffraHaptics.tap(()=>
           chooseBudgetCategory(
            suggestedName:t.name(waffraIsEnglish),
            suggestedParentId:t.mainCategoryId,
            suggestedSubcategory:t.subcategoryAr)),
         ),
       ]),
      ]),
    ],
   ),
  );
 }
}

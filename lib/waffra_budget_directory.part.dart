part of 'main.dart';

/// Budget directory lives in Categories but does not create a second ledger,
/// alter category IDs, or infer transactions from names.
extension WaffraBudgetDirectory on _HomeScreenState {
 /// A separate bounded sheet keeps the budget controls out of the lazy
 /// Categories ListView. The old nested ExpansionTile/LayoutBuilder could
 /// render as a large grey ErrorWidget on narrow Android devices.
 Future<void> showBudgetsDirectorySheet() async {
  // Modal-local filters: reopening the sheet never inherits a stale chooser.
  var view='all',templateGroup='all';
  await showModalBottomSheet<void>(
   context:context,isScrollControlled:true,useSafeArea:true,showDragHandle:true,
   backgroundColor:Theme.of(context).scaffoldBackgroundColor,
   builder:(sheetCtx)=>DraggableScrollableSheet(
    expand:false,initialChildSize:.82,minChildSize:.45,maxChildSize:.96,
    builder:(ctx,scroll)=>StatefulBuilder(
     builder:(ctx,refresh)=>ListView(
      controller:scroll,
      padding:const EdgeInsets.fromLTRB(14,0,14,28),
      children:[_budgetDirectoryPanel(refresh,
       view:view,onViewChange:(v)=>refresh(()=>view=v),
       templateGroup:templateGroup,
       onTemplateGroupChange:(g)=>refresh(()=>templateGroup=g))],
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
  required String view,required ValueChanged<String> onViewChange,
  required String templateGroup,
  required ValueChanged<String> onTemplateGroupChange,
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
   (templateGroup=='all'||t.group==templateGroup)&&
   waffraSearchAny([
   t.nameAr,t.nameEn,
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
     // Saved records and optional starter templates are separate concepts.
     // These view chips are read-only and never relink an expense.
     Wrap(spacing:7,runSpacing:7,children:[
      ChoiceChip(label:WaffraText(waffraIsEnglish?'All':'الكل'),
       selected:view=='all',onSelected:(_)=>onViewChange('all')),
      ChoiceChip(label:WaffraText(waffraIsEnglish?
       'My saved budgets':'ميزانياتي المضافة'),
       selected:view=='mine',onSelected:(_)=>onViewChange('mine')),
      ChoiceChip(label:WaffraText(waffraIsEnglish?
       'Suggested':'المقترحة'),
       selected:view=='suggested',onSelected:(_)=>onViewChange('suggested')),
     ]),
     const SizedBox(height:13),
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
     const SizedBox(height:16),
     Align(alignment:AlignmentDirectional.centerStart,
      child:OutlinedButton.icon(
       key:const Key('waffra-budgets-directory-create'),
       style:OutlinedButton.styleFrom(minimumSize:const Size(0,48),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:10)),
       onPressed:WaffraHaptics.tap(()async{
        await chooseBudgetCategory();
        if(mounted)refresh((){});
       }),
       icon:const Icon(Icons.add_circle_outline_rounded),
       label:WaffraText(waffraIsEnglish?'Create budget':'إضافة ميزانية جديدة'))),
     if(view!='suggested')...[
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
        decoration:BoxDecoration(
         color:Theme.of(context).cardColor,
         border:Border.all(color:emerald.withValues(alpha:.23)),
         borderRadius:BorderRadius.circular(14)),
        // Collapsed by default: no nested expansion tiles or tall action
        // regions inside the draggable modal. Historic budget IDs stay put.
        child:ExpansionTile(
         key:PageStorageKey<String>('waffra-budget-details-'+b.id),
         initiallyExpanded:false,
         shape:const RoundedRectangleBorder(side:BorderSide.none),
         collapsedShape:const RoundedRectangleBorder(side:BorderSide.none),
         tilePadding:const EdgeInsets.symmetric(horizontal:12,vertical:2),
         childrenPadding:const EdgeInsets.fromLTRB(12,2,12,12),
         title:WaffraText(b.budgetLabel??('ميزانية '+b.displayName),
          maxLines:2,style:const TextStyle(fontWeight:FontWeight.bold)),
         subtitle:WaffraText(waffraIsEnglish?
          'Limit: '+cash(b.budget)+' • Spent: '+cash(spent):
          'الحد: '+cash(b.budget)+' • المصروف: '+cash(spent),
          maxLines:2,style:const TextStyle(fontSize:11)),
         children:[
          ClipRRect(
           borderRadius:BorderRadius.circular(6),
           child:LinearProgressIndicator(value:ratio,minHeight:7,
            color:spent>b.budget?Colors.deepOrange:emerald,
            backgroundColor:emerald.withValues(alpha:.10))),
          const SizedBox(height:8),
          WaffraText(waffraIsEnglish?
           'Remaining: '+cash(b.budget-spent):
           'المتبقي: '+cash(b.budget-spent),
           style:const TextStyle(fontSize:12)),
          const SizedBox(height:12),
          Container(
           width:double.infinity,
           padding:const EdgeInsets.symmetric(horizontal:10,vertical:11),
           decoration:BoxDecoration(
            border:Border.all(color:emerald.withValues(alpha:.30)),
            borderRadius:BorderRadius.circular(12)),
           child:Row(children:[
            const Icon(Icons.settings_rounded,color:emerald,size:18),
            const SizedBox(width:8),
            Expanded(child:WaffraText(
             waffraIsEnglish?'Quick actions':'إجراءات سريعة',
             style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12))),
           ])),
          const SizedBox(height:8),
          Wrap(spacing:7,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,
           children:[
            OutlinedButton.icon(
             style:OutlinedButton.styleFrom(
              minimumSize:const Size(0,48),
              padding:const EdgeInsets.symmetric(horizontal:9,vertical:7)),
             onPressed:WaffraHaptics.tap(()async{
              await editBudgetForCategory(b);
              if(mounted)refresh((){});
             }),
             icon:const Icon(Icons.edit_outlined,size:16),
             label:WaffraText(waffraIsEnglish?'Edit':'تعديل',
              style:const TextStyle(fontSize:12))),
            OutlinedButton.icon(
             style:OutlinedButton.styleFrom(
              minimumSize:const Size(0,48),
              padding:const EdgeInsets.symmetric(horizontal:9,vertical:7)),
             onPressed:WaffraHaptics.tap(()async{
              await deleteNamedBudget(b);
              if(mounted)refresh((){});
             }),
             icon:const Icon(Icons.delete_outline_rounded,
              size:16,color:Colors.deepOrange),
             label:WaffraText(waffraIsEnglish?'Delete':'حذف',
              style:const TextStyle(color:Colors.deepOrange,fontSize:12))),
            Container(
             padding:const EdgeInsetsDirectional.only(start:8,end:2),
             decoration:BoxDecoration(
              border:Border.all(color:emerald.withValues(alpha:.30)),
              borderRadius:BorderRadius.circular(12)),
             child:Row(mainAxisSize:MainAxisSize.min,children:[
              WaffraText(b.budgetActive?
               (waffraIsEnglish?'Enabled':'مفعّل'):
               (waffraIsEnglish?'Paused':'متوقف'),
               style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700)),
              Switch.adaptive(
               key:Key('waffra-budget-active-'+b.id),
               value:b.budgetActive,
               activeTrackColor:emerald,
               onChanged:WaffraHaptics.selection((enabled)async{
                await setNamedBudgetActive(b,enabled);
                if(mounted)refresh((){});
               })),
             ])),
           ]),
         ],
        ),
       ),
      );
     }),
     ],
     if(view!='mine')...[
     const SizedBox(height:10),
     ExpansionTile(
      key:const PageStorageKey<String>('waffra-budget-starter-templates'),
      initiallyExpanded:false,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),
       side:BorderSide(color:emerald.withValues(alpha:.30))),
      collapsedShape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),
       side:BorderSide(color:emerald.withValues(alpha:.30))),
      tilePadding:const EdgeInsets.symmetric(horizontal:10),
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
       Padding(padding:const EdgeInsets.symmetric(vertical:8),
        child:SingleChildScrollView(scrollDirection:Axis.horizontal,
         child:Row(children:[
          ChoiceChip(
           label:WaffraText(waffraIsEnglish?'All types':'كل الأنواع'),
           selected:templateGroup=='all',
           onSelected:(_)=>onTemplateGroupChange('all')),
          for(final type in waffraBudgetTemplateGroups)...[
           const SizedBox(width:6),
           ChoiceChip(label:WaffraText(type.name(waffraIsEnglish)),
            selected:templateGroup==type.id,
            onSelected:(_)=>onTemplateGroupChange(type.id)),
          ],
         ]))),
       if(templates.isEmpty)
        WaffraText(waffraIsEnglish?'No matching templates':
         'لا توجد قوالب مطابقة'),
       Wrap(spacing:8,runSpacing:10,children:[
        for(final t in templates)
         ActionChip(
          key:Key('waffra-budget-template-'+t.nameAr),
          avatar:const Icon(Icons.add_rounded,size:16,color:emerald),
          label:WaffraText(t.name(waffraIsEnglish),
           style:const TextStyle(fontSize:12)),
          onPressed:WaffraHaptics.tap(()=>
           chooseBudgetCategory(
            suggestedName:t.name(waffraIsEnglish))),
         ),
       ]),
      ]),
     ],
    ],
   ),
  );
 }
}

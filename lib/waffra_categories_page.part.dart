part of 'main.dart';

/// Grouped, searchable category display. Kept in the main library as a part
/// so it shares the existing home state without copying financial data.
extension WaffraCategoryScreen on _HomeScreenState {
 Widget _compactCategoryStat(String heading,String count,IconData icon,Color color)=>
  Container(
   padding:const EdgeInsets.symmetric(horizontal:11,vertical:9),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,
    borderRadius:BorderRadius.circular(16),
    border:Border.all(color:color.withValues(alpha:.20))),
   child:Row(children:[
    Icon(icon,size:19,color:color),
    const SizedBox(width:7),
    Expanded(child:WaffraText(heading,maxLines:1,
     style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600))),
    WaffraText(count,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)),
   ]),
  );
 Widget categoriesPageV2(){
  final now=DateTime.now();
  final recent=entries.where((e)=>e.date.year==now.year&&e.date.month==now.month).toList();
  final expenseTotal=recent.where((e)=>!e.income).fold<double>(0,(total,e)=>total+e.amount);
  final roots=categories.where((c)=>!c.isSubcategory).toList();
  List<BudgetCategory> children(BudgetCategory root)=>
   categories.where((c)=>c.parentId==root.id).toList();
  double monthlyFor(BudgetCategory root){
   final names={root.name,...children(root).map((c)=>c.name)};
   return recent.where((e)=>e.income==root.income&&names.contains(e.category))
    .fold<double>(0,(total,e)=>total+e.amount);
  }
  final shown=roots.where((root){
   if(categoryTypeFilter=='income'&&!root.income)return false;
   if(categoryTypeFilter=='expense'&&root.income)return false;
   final subs=children(root);
   final budgeted=root.budget>0||subs.any((c)=>c.budget>0);
   if(categoryDisplay=='budget'&&!budgeted)return false;
   if(categoryDisplay=='none'&&budgeted)return false;
   final query=categorySearch.trim().toLowerCase();
   return query.isEmpty||root.name.toLowerCase().contains(query)||
    waffraTr(root.name).toLowerCase().contains(query)||
    subs.any((c)=>c.displayName.toLowerCase().contains(query)||
     waffraTr(c.displayName).toLowerCase().contains(query));
  }).toList();

  Widget rootCard(BudgetCategory root){
   final color=Color(root.color);
   final opened=expandedCategoryIds.contains(root.id);
   final amount=monthlyFor(root);
   return Card(margin:EdgeInsets.zero,elevation:0,clipBehavior:Clip.antiAlias,
    color:Theme.of(context).cardColor,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(19),
     side:BorderSide(color:color.withValues(alpha:.32))),
    child:InkWell(onTap:()=>setState((){
     if(opened){expandedCategoryIds.clear();}else{expandedCategoryIds..clear()..add(root.id);}
    }),child:Padding(padding:const EdgeInsets.all(9),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
       CircleAvatar(radius:19,backgroundColor:color.withValues(alpha:.14),
        child:Icon(categoryIcon(root.icon),size:20,color:color)),
       const Spacer(),
       PopupMenuButton<String>(
        tooltip:waffraIsEnglish?'Category actions':'خيارات القسم',
        onSelected:(action){
         if(action=='add')addCategory(income:root.income,parentId:root.id);
         if(action=='edit')updateCategory(root);
         if(action=='delete')deleteCategory(root);
        },
        itemBuilder:(_)=>[
         PopupMenuItem(value:'add',child:WaffraText(waffraIsEnglish?'Add subcategory':'إضافة قسم فرعي')),
         PopupMenuItem(value:'edit',child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
         PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف')),
        ],
        child:const Icon(Icons.more_vert,size:20)),
      ]),
      const SizedBox(height:5),
      WaffraText(root.name,maxLines:2,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700)),
      const SizedBox(height:5),
      WaffraText(waffraIsEnglish?'${children(root).length} subcategories':'${children(root).length} قسم فرعي',
       style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
      const SizedBox(height:5),
      WaffraText(root.income?
       (waffraIsEnglish?'Income: ${cash(amount)}':'الدخل: ${cash(amount)}'):
       (waffraIsEnglish?'Spent: ${cash(amount)}':'المصروف: ${cash(amount)}'),
       maxLines:1,style:TextStyle(fontSize:11,color:color,fontWeight:FontWeight.bold)),
      if(!root.income&&root.budget>0)...[
       const SizedBox(height:6),
       LinearProgressIndicator(value:(amount/root.budget).clamp(0.0,1.0),
        minHeight:5,color:amount>root.budget?Colors.red:color,
        backgroundColor:color.withValues(alpha:.12),
        borderRadius:BorderRadius.circular(8)),
      ],
      const SizedBox(height:3),
      Row(mainAxisAlignment:MainAxisAlignment.end,children:[
       WaffraText(waffraIsEnglish?'Subcategories':'الأقسام الفرعية',style:const TextStyle(fontSize:10)),
       Icon(opened?Icons.keyboard_arrow_up:Icons.keyboard_arrow_down,size:20,color:color),
      ]),
     ]))));
  }

  Widget childCard(BudgetCategory sub){
   final color=Color(sub.color);
   final total=recent.where((e)=>e.category==sub.name&&e.income==sub.income)
    .fold<double>(0,(value,e)=>value+e.amount);
   return Card(margin:EdgeInsets.zero,elevation:0,
    color:color.withValues(alpha:.08),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),
     side:BorderSide(color:color.withValues(alpha:.20))),
    child:InkWell(borderRadius:BorderRadius.circular(15),
     onTap:()=>updateCategory(sub),
     child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
      Icon(categoryIcon(sub.icon),size:17,color:color),
      const SizedBox(width:7),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(sub.displayName,maxLines:2,
        style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
       if(total>0)WaffraText(cash(total),maxLines:1,
        style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
      ])),
      PopupMenuButton<String>(tooltip:waffraIsEnglish?'Subcategory actions':'خيارات القسم الفرعي',
       onSelected:(action){
        if(action=='edit')updateCategory(sub);
        if(action=='delete')deleteCategory(sub);
       },itemBuilder:(_)=>[
        PopupMenuItem(value:'edit',child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
        PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف')),
       ],child:const Icon(Icons.more_vert,size:17)),
     ]))));
  }
  final groupRows=<Widget>[];
  for(var i=0;i<shown.length;i+=2){
   final left=shown[i];
   final right=i+1<shown.length?shown[i+1]:null;
   groupRows.add(Padding(padding:const EdgeInsets.only(bottom:10),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(child:rootCard(left)),const SizedBox(width:10),
     Expanded(child:right==null?const SizedBox.shrink():rootCard(right)),
    ])));
   for(final root in [left,if(right!=null)right]){
    if(!expandedCategoryIds.contains(root.id))continue;
    final items=children(root);
    groupRows.add(Container(
     margin:const EdgeInsets.only(bottom:14),
     padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(color:Theme.of(context).cardColor,
      borderRadius:BorderRadius.circular(19),
      border:Border.all(color:Color(root.color).withValues(alpha:.28))),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
       Expanded(child:WaffraText(root.name,
        style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
       TextButton.icon(onPressed:()=>addCategory(income:root.income,parentId:root.id),
        icon:const Icon(Icons.add,size:16),
        label:WaffraText(waffraIsEnglish?'Add subcategory':'إضافة فرعي')),
      ]),
      if(items.isEmpty)
       Padding(padding:const EdgeInsets.all(12),
        child:WaffraText(waffraIsEnglish?'No subcategories':'لا توجد أقسام فرعية'))
      else LayoutBuilder(builder:(ctx,size){
       final width=(size.maxWidth-9)/2;
       final usableLabelWidth=(width-91).clamp(18.0,double.infinity).toDouble();
       bool needsTwoLines(BudgetCategory sub){
        final painter=TextPainter(
         text:TextSpan(text:waffraTr(sub.displayName),
          style:const TextStyle(fontFamily:'Tajawal',fontSize:12,fontWeight:FontWeight.bold)),
         maxLines:1,
         textDirection:waffraIsEnglish?TextDirection.ltr:TextDirection.rtl,
         textScaler:MediaQuery.textScalerOf(ctx),
        )..layout(maxWidth:usableLabelWidth);
        final needsWrap=painter.didExceedMaxLines;
        painter.dispose();
        return needsWrap;
       }
       final ordered=[...items]..sort((a,b)=>
        (needsTwoLines(a)?1:0).compareTo(needsTwoLines(b)?1:0));
       return Wrap(spacing:9,runSpacing:9,children:[
        for(final sub in ordered)SizedBox(width:width,child:childCard(sub)),
       ]);
      }),
     ])));
   }
  }
  return ListView(padding:const EdgeInsets.fromLTRB(16,14,16,116),children:[
   WaffraPageHero(
    title:waffraIsEnglish?'Categories & budgets':'أقسامك وميزانياتك',
    subtitle:waffraIsEnglish?'All income and expense types with subcategories':
     'كل أنواع الدخل والمصروفات في أقسام رئيسية وفرعية منظمة.',
    icon:Icons.category_outlined,titleKey:_tourKeys[2]),
   SizedBox(width:double.infinity,child:WaffraDeletedItemsButton(
    onPressed:showCategoryTrash,
    label:waffraIsEnglish?'Deleted categories (${deletedCategories.length})':'الأقسام المحذوفة (${deletedCategories.length})')),
   const SizedBox(height:14),
   Row(children:[
    Expanded(child:_compactCategoryStat(waffraIsEnglish?'Main categories':'الأقسام الرئيسية',
     roots.length.toString(),Icons.layers,emerald)),
    const SizedBox(width:10),
    Expanded(child:_compactCategoryStat(waffraIsEnglish?'Subcategories':'الأقسام الفرعية',
     categories.where((c)=>c.isSubcategory).length.toString(),Icons.account_tree,Colors.deepPurple)),
   ]),
   const SizedBox(height:10),
   _summaryBox(waffraIsEnglish?'Monthly expenses':'المصروف الشهري',
    cash(expenseTotal),Icons.trending_down,Colors.deepOrange),
   const SizedBox(height:13),
   Wrap(spacing:7,runSpacing:7,children:[
    _filterChip(waffraIsEnglish?'All':'الكل',categoryTypeFilter=='all',()=>setState(()=>categoryTypeFilter='all')),
    _filterChip(waffraIsEnglish?'Expenses':'المصروفات',categoryTypeFilter=='expense',()=>setState(()=>categoryTypeFilter='expense')),
    _filterChip(waffraIsEnglish?'Income':'الدخل',categoryTypeFilter=='income',()=>setState(()=>categoryTypeFilter='income')),
   ]),
   const SizedBox(height:7),
   Wrap(spacing:7,runSpacing:7,children:[
    _filterChip(waffraIsEnglish?'All budgets':'كل الميزانيات',categoryDisplay=='all',()=>setState(()=>categoryDisplay='all')),
    _filterChip(waffraIsEnglish?'Budgeted':'بميزانية',categoryDisplay=='budget',()=>setState(()=>categoryDisplay='budget')),
    _filterChip(waffraIsEnglish?'No budget':'بدون ميزانية',categoryDisplay=='none',()=>setState(()=>categoryDisplay='none')),
   ]),
   const SizedBox(height:12),
   TextField(onChanged:(text)=>setState(()=>categorySearch=text),
    decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
     hintText:waffraIsEnglish?'Search categories and subcategories':'البحث عن قسم أو قسم فرعي...',
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(20)),isDense:true)),
   const SizedBox(height:15),
   ...groupRows,
   if(shown.isEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:46),
    child:Column(children:[
     const Icon(Icons.search_off_rounded,size:48,color:emerald),
     const SizedBox(height:11),
     WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'),
    ])),
   const SizedBox(height:75),
  ]);
 }
}

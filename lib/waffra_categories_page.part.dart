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
  // One finance-history scan for month totals and legacy unassigned review.
  // Never infer named-budget links or change stored finance records here.
  var unassignedExpenseCount=0;
  final monthly=WaffraCategoryMonthTotals.build<MoneyEntry>(
   entries,now,date:(e)=>e.date,income:(e)=>e.income,
   category:(e)=>e.category,amount:(e)=>e.amount,
   onRow:(e){if(!e.income&&e.budgetId==null)unassignedExpenseCount++;});
  final monthlyTotals=monthly.byCategory;
  final expenseTotal=monthly.expenses;
  final roots=<BudgetCategory>[];
  final childrenByParent=<String,List<BudgetCategory>>{};
  for(final c in categories){
   if(c.isSubcategory){
    (childrenByParent[c.parentId]??=<BudgetCategory>[]).add(c);
   }else{roots.add(c);}
  }
  List<BudgetCategory> children(BudgetCategory root)=>
   childrenByParent[root.id]??const <BudgetCategory>[];
  double monthlyFor(BudgetCategory root){
   var amount=monthlyTotals[(root.income,root.name)]??0;
   for(final child in children(root)){
    amount+=monthlyTotals[(child.income,child.name)]??0;
   }
   return amount;
  }
  final shown=roots.where((root){
   if(categoryMineOnly&&!root.isUserAdded&&
     !children(root).any((sub)=>sub.isUserAdded))return false;
   if(categoryTypeFilter=='income'&&!root.income)return false;
   if(categoryTypeFilter=='expense'&&root.income)return false;
   final subs=children(root);
   final budgeted=root.budget>0||subs.any((c)=>c.budget>0);
   if(categoryDisplay=='budget'&&!budgeted)return false;
   if(categoryDisplay=='none'&&budgeted)return false;
   final query=categorySearch.trim();
   return waffraSearchAny([root.name,waffraTr(root.name)],query)||
    subs.any((c)=>(!categoryMineOnly||c.isUserAdded)&&
     waffraSearchAny([c.displayName,waffraTr(c.displayName)],query));
  }).toList();
  // Income sort prioritizes income roots, expense sort prioritizes expense
  // roots, using posted current-month totals including each root's children.
  final sorted=waffraRankCategoryRoots<BudgetCategory>(shown,
   mode:categorySort,label:(c)=>waffraTr(c.name),
   isIncome:(c)=>c.income,monthlyTotal:monthlyFor);
  final filterLabels=<String>[
   if(categoryTypeFilter=='income')(waffraIsEnglish?'Income':'الدخل'),
   if(categoryTypeFilter=='expense')(waffraIsEnglish?'Expenses':'المصروفات'),
   if(categoryDisplay=='budget')(waffraIsEnglish?'Budgeted':'بميزانية'),
   if(categoryDisplay=='none')(waffraIsEnglish?'No budget':'بدون ميزانية'),
   if(categorySort=='income')(waffraIsEnglish?'Highest income':'الأكثر دخلًا'),
   if(categorySort=='spent')(waffraIsEnglish?'Highest expenses':'الأكثر مصروفًا'),
   if(categorySort=='alpha')(waffraIsEnglish?'A–Z':'أبجديًا'),
   if(categoryMineOnly)(waffraIsEnglish?'Added by me':'مضاف بواسطتي'),
  ];

  Widget rootCard(BudgetCategory root){
   final color=Color(root.color);
   final visibleChildren=children(root).where((c)=>!categoryMineOnly||c.isUserAdded).toList();
   final opened=expandedCategoryIds.contains(root.id);
   final amount=monthlyFor(root);
   final assigned=waffraNamedBudgetSpent(entries,categories,root,now);
   return Card(margin:EdgeInsets.zero,elevation:0,clipBehavior:Clip.antiAlias,
    color:Theme.of(context).cardColor,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(19),
     side:BorderSide(color:color.withValues(alpha:.32))),
    child:InkWell(onTap:WaffraHaptics.tap(()=>setState((){
     if(opened){expandedCategoryIds.clear();}else{expandedCategoryIds..clear()..add(root.id);}
    })),child:Padding(padding:const EdgeInsets.all(9),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
       WaffraIllustration(topic:root.icon,size:40),
       const Spacer(),
       PopupMenuButton<String>(
        tooltip:waffraIsEnglish?'Category actions':'خيارات القسم',
        onSelected:WaffraHaptics.selection((action){
         if(action=='add')addCategory(income:root.income,parentId:root.id);
         if(action=='edit')updateCategory(root);
         if(action=='delete')deleteCategory(root);
        }),
        itemBuilder:(_)=>[
         PopupMenuItem(value:'add',child:WaffraText(waffraIsEnglish?'Add subcategory':'إضافة قسم فرعي')),
         PopupMenuItem(value:'edit',child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
         PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف')),
        ],
        child:const Icon(Icons.more_vert,size:20)),
      ]),
      const SizedBox(height:5),
      WaffraText(root.name,maxLines:2,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700)),
      if(!root.income&&root.budget>0&&!root.budgetActive)
       Padding(padding:const EdgeInsets.only(top:4),
        child:WaffraText(waffraIsEnglish?
         'Budget paused':'الميزانية متوقفة مؤقتًا',
         style:const TextStyle(fontSize:11,color:Colors.deepOrange,
          fontWeight:FontWeight.w600))),
      const SizedBox(height:5),
      WaffraText(waffraIsEnglish?'${visibleChildren.length} subcategories':'${visibleChildren.length} قسم فرعي',
       style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
      const SizedBox(height:5),
      WaffraText(root.income?
       (waffraIsEnglish?'Income: ${cash(amount)}':'الدخل: ${cash(amount)}'):
       (waffraIsEnglish?'Spent: ${cash(amount)}':'المصروف: ${cash(amount)}'),
       maxLines:1,style:TextStyle(fontSize:11,color:color,fontWeight:FontWeight.bold)),
      if(!root.income&&root.budget>0&&root.budgetActive)...[
       const SizedBox(height:6),
       LinearProgressIndicator(value:(assigned/root.budget).clamp(0.0,1.0),
        minHeight:5,color:assigned>root.budget?Colors.red:color,
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
   final total=monthlyTotals[(sub.income,sub.name)]??0;
   return Card(margin:EdgeInsets.zero,elevation:0,
    color:color.withValues(alpha:.08),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(15),
     side:BorderSide(color:color.withValues(alpha:.20))),
    child:InkWell(borderRadius:BorderRadius.circular(15),
     onTap:WaffraHaptics.tap(()=>updateCategory(sub)),
     child:Padding(padding:const EdgeInsets.all(10),child:Row(children:[
      WaffraIllustration(topic:sub.icon,size:30),
      const SizedBox(width:7),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       WaffraText(sub.displayName,maxLines:2,
        style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
       if(total>0)WaffraText(cash(total),maxLines:1,
        style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
      ])),
      PopupMenuButton<String>(tooltip:waffraIsEnglish?'Subcategory actions':'خيارات القسم الفرعي',
       onSelected:WaffraHaptics.selection((action){
        if(action=='edit')updateCategory(sub);
        if(action=='delete')deleteCategory(sub);
       }),itemBuilder:(_)=>[
        PopupMenuItem(value:'edit',child:WaffraText(waffraIsEnglish?'Edit':'تعديل')),
        PopupMenuItem(value:'delete',child:WaffraText(waffraIsEnglish?'Delete':'حذف')),
       ],child:const Icon(Icons.more_vert,size:17)),
     ]))));
  }
  final groupRows=<Widget Function()>[];
  for(var i=0;i<sorted.length;i+=2){
   final left=sorted[i];
   final right=i+1<sorted.length?sorted[i+1]:null;
   groupRows.add(()=>Padding(padding:const EdgeInsets.only(bottom:10),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
     Expanded(child:rootCard(left)),const SizedBox(width:10),
     Expanded(child:right==null?const SizedBox.shrink():rootCard(right)),
    ])));
   for(final root in [left,if(right!=null)right]){
    if(!expandedCategoryIds.contains(root.id))continue;
    final items=children(root).where((c)=>!categoryMineOnly||c.isUserAdded).toList();
    groupRows.add(()=>Container(
     margin:const EdgeInsets.only(bottom:14),
     padding:const EdgeInsets.all(12),
     decoration:BoxDecoration(color:Theme.of(context).cardColor,
      borderRadius:BorderRadius.circular(19),
      border:Border.all(color:Color(root.color).withValues(alpha:.28))),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[
       Expanded(child:WaffraText(root.name,
        style:const TextStyle(fontSize:15,fontWeight:FontWeight.bold))),
       TextButton.icon(onPressed:WaffraHaptics.tap(()=>addCategory(income:root.income,parentId:root.id)),
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
       final wraps=<String,bool>{};
       bool cachedWrap(BudgetCategory item)=>
        wraps.putIfAbsent(item.id,()=>needsTwoLines(item));
       final ordered=[...items]..sort((a,b)=>
        (cachedWrap(a)?1:0).compareTo(cachedWrap(b)?1:0));
       return Wrap(spacing:9,runSpacing:9,children:[
        for(final sub in ordered)SizedBox(width:width,child:childCard(sub)),
       ]);
      }),
     ])));
   }
  }
  final pageRows=<Widget Function()>[
   ()=>WaffraPageHero(
    title:waffraIsEnglish?'Categories & budgets':'أقسامك وميزانياتك',
    subtitle:waffraIsEnglish?'All income and expense types with subcategories':
     'كل أنواع الدخل والمصروفات في أقسام رئيسية وفرعية منظمة.',
    icon:Icons.category_outlined,titleKey:_tourKeys[2]),
   ()=>Row(children:[
    Expanded(child:_compactCategoryStat(waffraIsEnglish?'Main categories':'الأقسام الرئيسية',
     roots.length.toString(),Icons.layers,emerald)),
    const SizedBox(width:10),
    Expanded(child:_compactCategoryStat(waffraIsEnglish?'Subcategories':'الأقسام الفرعية',
     categories.where((c)=>c.isSubcategory).length.toString(),Icons.account_tree,Colors.deepPurple)),
   ]),
   ()=>const SizedBox(height:10),
   ()=>Align(alignment:AlignmentDirectional.centerStart,
    child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:250),
     child:WaffraDeletedItemsButton(
      onPressed:WaffraHaptics.tapRequired(showCategoryTrash),
      label:waffraIsEnglish?'Deleted categories (${deletedCategories.length})':
       'الأقسام المحذوفة (${deletedCategories.length})'))),
   ()=>const SizedBox(height:10),
   ()=>_summaryBox(waffraIsEnglish?'Monthly expenses':'المصروف الشهري',
    cash(expenseTotal),Icons.trending_down,Colors.deepOrange),
   if(unassignedExpenseCount>0)...[
    ()=>const SizedBox(height:9),
    ()=>Card(
     key:const Key('waffra-retro-budget-review-banner'),
     margin:EdgeInsets.zero,
     child:ListTile(
      dense:true,contentPadding:const EdgeInsets.symmetric(horizontal:11),
      leading:const Icon(Icons.link_off_rounded,color:emerald),
      title:WaffraText(waffraIsEnglish?
       unassignedExpenseCount.toString()+' saved expenses without a budget':
       unassignedExpenseCount.toString()+' عملية محفوظة بدون ميزانية',
       maxLines:2,style:const TextStyle(fontSize:12,fontWeight:FontWeight.bold)),
      subtitle:WaffraText(waffraIsEnglish?
       'Optional review; old records remain unchanged':
       'راجع الربط باختيارك، من غير تعديل بياناتك القديمة',
       maxLines:2,style:const TextStyle(fontSize:11)),
      trailing:const Icon(Icons.chevron_right_rounded,size:19),
      onTap:WaffraHaptics.tap(()=>reviewUnlinkedHistoricalExpenses()),
     )),
   ],
   ()=>const SizedBox(height:13),
   ()=>this.budgetsDirectory(),
   ()=>const SizedBox(height:13),
   // Compact by default: the three large rows of chips previously pushed
   // the actual category cards below the fold on smaller phones.
   ()=>Container(
    key:const Key('waffra-category-filter-accordion'),
    decoration:BoxDecoration(
     color:Theme.of(context).cardColor,
     borderRadius:BorderRadius.circular(18),
     border:Border.all(color:emerald.withValues(alpha:.24))),
    child:ExpansionTile(
     key:const PageStorageKey<String>('waffra-category-filter-dropdown'),
     initiallyExpanded:categoryFiltersOpen,
     onExpansionChanged:(open)=>setState(()=>categoryFiltersOpen=open),
     leading:const Icon(Icons.tune_rounded,color:emerald,size:23),
     shape:const RoundedRectangleBorder(side:BorderSide.none),
     collapsedShape:const RoundedRectangleBorder(side:BorderSide.none),
     tilePadding:const EdgeInsets.symmetric(horizontal:12),
     childrenPadding:const EdgeInsets.fromLTRB(16,8,16,18),
     title:WaffraText(waffraIsEnglish?'Filter & sort':'الفلترة والترتيب',
      style:const TextStyle(fontWeight:FontWeight.bold)),
     subtitle:WaffraText(filterLabels.isEmpty?
       (waffraIsEnglish?'All categories • All budgets':
         'كل الأقسام • كل الميزانيات'):filterLabels.join(' • '),
      maxLines:2,style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
     children:[
      LayoutBuilder(builder:(ctx,layout){
       // Prevent Arabic/English dropdown labels from clipping on phones.
       // Only use two columns on tablets with sufficient room for both.
       final singleColumn=layout.maxWidth<560||
        MediaQuery.textScalerOf(ctx).scale(16)>21;
       final cell=singleColumn?layout.maxWidth:(layout.maxWidth-12)/2;
       InputDecoration decor(String label)=>InputDecoration(
        labelText:label,isDense:true,
        floatingLabelBehavior:FloatingLabelBehavior.auto,
        contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:15),
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)));
       return Wrap(spacing:12,runSpacing:16,children:[
        SizedBox(width:cell,child:DropdownButtonFormField<String>(
         key:ValueKey('waffra-category-type-'+categoryTypeFilter),
         initialValue:categoryTypeFilter,isExpanded:true,
         decoration:decor(waffraIsEnglish?'Transaction type':'نوع العملية'),
         items:[
          DropdownMenuItem(value:'all',child:WaffraText(waffraIsEnglish?'All':'الكل')),
          DropdownMenuItem(value:'expense',child:WaffraText(waffraIsEnglish?'Expenses':'المصروفات')),
          DropdownMenuItem(value:'income',child:WaffraText(waffraIsEnglish?'Income':'الدخل')),
         ],
         onChanged:WaffraHaptics.selection((v){
          if(v!=null)setState(()=>categoryTypeFilter=v);
         }))),
        SizedBox(width:cell,child:DropdownButtonFormField<String>(
         key:ValueKey('waffra-category-budget-'+categoryDisplay),
         initialValue:categoryDisplay,isExpanded:true,
         decoration:decor(waffraIsEnglish?'Budget status':'حالة الميزانية'),
         items:[
          DropdownMenuItem(value:'all',child:WaffraText(waffraIsEnglish?'All budgets':'كل الميزانيات')),
          DropdownMenuItem(value:'budget',child:WaffraText(waffraIsEnglish?'Budgeted':'بميزانية')),
          DropdownMenuItem(value:'none',child:WaffraText(waffraIsEnglish?'No budget':'بدون ميزانية')),
         ],
         onChanged:WaffraHaptics.selection((v){
          if(v!=null)setState(()=>categoryDisplay=v);
         }))),
        SizedBox(width:cell,child:DropdownButtonFormField<String>(
         key:ValueKey('waffra-category-sort-'+categorySort),
         initialValue:categorySort,isExpanded:true,
         decoration:decor(waffraIsEnglish?'Sort by':'الترتيب حسب'),
         items:[
          DropdownMenuItem(value:'default',child:WaffraText(waffraIsEnglish?'Default':'الافتراضي')),
          DropdownMenuItem(value:'income',child:WaffraText(waffraIsEnglish?'Highest income':'الأكثر دخلًا')),
          DropdownMenuItem(value:'spent',child:WaffraText(waffraIsEnglish?'Highest expenses':'الأكثر مصروفًا')),
          DropdownMenuItem(value:'alpha',child:WaffraText(waffraIsEnglish?'A–Z':'أبجديًا')),
         ],
         onChanged:WaffraHaptics.selection((v){
          if(v!=null)setState(()=>categorySort=v);
         }))),
        SizedBox(width:cell,child:SwitchListTile.adaptive(
         contentPadding:EdgeInsets.zero,dense:true,
         title:WaffraText(waffraIsEnglish?'Added by me':'مضاف بواسطتي',
          style:const TextStyle(fontSize:12)),
         value:categoryMineOnly,
         onChanged:WaffraHaptics.selection((v)=>setState(()=>categoryMineOnly=v)))),
       ]);
      }),
      Align(alignment:AlignmentDirectional.centerEnd,
       child:TextButton.icon(
        onPressed:WaffraHaptics.tap(()=>setState((){
         categoryTypeFilter='all';categoryDisplay='all';
         categorySort='default';categoryMineOnly=false;
        })),
        icon:const Icon(Icons.restart_alt_rounded,size:17),
        label:WaffraText(waffraIsEnglish?'Reset filters':'إعادة ضبط الفلاتر'))),
     ],
    )),
   ()=>const SizedBox(height:12),
   ()=>TextFormField(initialValue:categorySearch,
    onChanged:(text)=>setState(()=>categorySearch=text),
    decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
     hintText:waffraIsEnglish?'Search categories and subcategories':'البحث عن قسم أو قسم فرعي...',
     border:OutlineInputBorder(borderRadius:BorderRadius.circular(20)),isDense:true)),
   ()=>const SizedBox(height:15),
   ...groupRows,
   if(shown.isEmpty)()=>Padding(padding:const EdgeInsets.symmetric(vertical:46),
    child:Column(children:[
     const Icon(Icons.search_off_rounded,size:48,color:emerald),
     const SizedBox(height:11),
     WaffraText(waffraIsEnglish?'No matching categories':'لا توجد أقسام مطابقة'),
    ])),
   ()=>const SizedBox(height:75),
  ];
  return ListView.builder(
   controller:_categoryScrollController,
   physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
   padding:const EdgeInsets.fromLTRB(16,14,16,116),
   itemCount:pageRows.length,
   itemBuilder:(context,index)=>pageRows[index](),
  );
 }
}

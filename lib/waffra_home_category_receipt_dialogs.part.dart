part of 'main.dart';

/// M795 / Issue #633: original category picker and protected receipt dialogs.
/// Same-library Home State extension without changing finance or attachments.
extension _WaffraHomeCategoryReceiptDialogs on _HomeScreenState {
 Future<String?> chooseTransactionCategory(
  BuildContext ctx,List<BudgetCategory> options,String selected,{
  bool leafLabels=false,bool allowCreate=false,bool typeIncome=false,
  String? parentId,String? suggested,
 })async{
  var query='';
  const createMain='__waffra_category_picker_new_main__';
  const createSub='__waffra_category_picker_new_sub__';
  final picked=await showWaffraDialog<String>(
   context:ctx,builder:(dialogCtx)=>StatefulBuilder(
    builder:(dialogCtx,refresh){
     final filtered=options.where((item){
      final label=leafLabels?item.displayName:item.name;
      return waffraSearchAny([label,waffraTr(label),waffraTr(item.name)],query);
     }).toList();
     return AlertDialog(
      title:WaffraText(waffraIsEnglish?'Search categories':'بحث في الأقسام'),
      content:SizedBox(
       width:360,height:waffraKeyboardDialogListHeight(dialogCtx),
       child:Column(children:[
        TextField(onChanged:(v)=>refresh(()=>query=v),
         decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search),
          hintText:waffraIsEnglish?'Search…':'اكتب اسم القسم',
          border:const OutlineInputBorder())),
        if(allowCreate&&!leafLabels)...[
         const SizedBox(height:6),
         ListTile(
          key:const Key('waffra-inline-create-main-category'),
          dense:true,
          leading:const Icon(Icons.create_new_folder_outlined,color:emerald),
          title:WaffraText(waffraIsEnglish?
           'New main category':'إضافة قسم رئيسي جديد'),
          onTap:WaffraHaptics.tap(()=>
           Navigator.pop(dialogCtx,createMain))),
        ],
        if(allowCreate&&leafLabels)...[
         const SizedBox(height:6),
         ListTile(
          key:const Key('waffra-inline-create-subcategory'),
          dense:true,
          leading:const Icon(Icons.account_tree_outlined,color:emerald),
          title:WaffraText(waffraIsEnglish?
           'New subcategory':'إضافة قسم فرعي جديد'),
          onTap:WaffraHaptics.tap(()=>
           Navigator.pop(dialogCtx,createSub))),
         const Divider(height:8),
        ],
        Expanded(child:filtered.isEmpty?
         Center(child:WaffraText(waffraIsEnglish?
          'No matching categories':'لا توجد أقسام مطابقة')):
         ListView.builder(itemCount:filtered.length,itemBuilder:(ctx,i){
          final item=filtered[i];
          return ListTile(
           selected:selected==item.name,
           leading:Icon(categoryIcon(item.icon),color:Color(item.color)),
           title:WaffraText(waffraTr(leafLabels?
            item.displayName:item.name),maxLines:3),
           onTap:WaffraHaptics.tap(()=>
            Navigator.pop(dialogCtx,item.name)));
         })),
       ])),
      actions:[TextButton(
       onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogCtx)),
       child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))],
     );
    }));
  if(picked==null||!mounted||!ctx.mounted)return null;
  if(picked!=createMain&&picked!=createSub)return picked;
  var categoryParentId='';
  if(picked==createSub){
   final root=categories.where((c)=>c.id==parentId&&
    !c.isSubcategory&&c.income==typeIncome).toList();
   if(root.isNotEmpty){
    categoryParentId=root.single.id;
   }else{
    final parents=categories.where((c)=>
     !c.isSubcategory&&c.income==typeIncome).toList();
    if(parents.isEmpty){
     snack(ctx,waffraIsEnglish?
      'Create a main category first':'أضف قسمًا رئيسيًا أولًا');
     return null;
    }
    final selectedParent=await chooseTransactionCategory(ctx,parents,'');
    if(selectedParent==null||!mounted||!ctx.mounted)return null;
    final chosen=parents.where((c)=>c.name==selectedParent).toList();
    if(chosen.length!=1)return null;
    categoryParentId=chosen.single.id;
   }
  }
  // The exact same icon/color/name dialog used by Categories handles both
  // new main and new child categories. No parallel incomplete form exists.
  final created=await categoryDialog(
   income:typeIncome,parentId:categoryParentId,
   suggested:picked==createSub?suggested:null);
  if(created==null||!mounted||!ctx.mounted)return null;
  if(WaffraValidators.uniqueCategory(created.name,
    categories.where((c)=>c.income==created.income).map((c)=>c.name))
    !=null){
   snack(ctx,waffraIsEnglish?
    'Category name already exists':'اسم القسم موجود بالفعل');
   return null;
  }
  setState(()=>categories.add(created));
  if(!await _persistModuleOrReload(
   WaffraFinanceRoute.categoryCreateEditDeleteRestore,
   operation:'transaction-category-picker-create'))return null;
  return created.name;
 }
 Future<String?> _promptReceiptLabel(BuildContext context,String path)async {
  final name=TextEditingController(text:WaffraReceiptFilename.displayName(path));
  String? error;
  try{
   return await showWaffraDialog<String>(context:context,
    builder:(dialogContext)=>StatefulBuilder(builder:(dialogContext,setDialogState)=>
     AlertDialog(
      title:WaffraText(waffraIsEnglish?'Rename attachment':'تعديل اسم المرفق'),
      content:TextField(
       key:const Key('waffra-attachment-name-input'),
       controller:name,maxLength:WaffraReceiptFilename.maxLabelCharacters,
       autofocus:true,
       decoration:InputDecoration(
        labelText:waffraIsEnglish?'Attachment name *':'اسم المرفق *',
        errorText:error,border:const OutlineInputBorder()),
       onChanged:(_)=>setDialogState(()=>error=null)),
      actions:[
       TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext)),
        child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء')),
       FilledButton(onPressed:WaffraHaptics.tap((){
        final validation=WaffraReceiptFilename.validateLabel(name.text);
        if(validation!=null){
         setDialogState(()=>error=waffraIsEnglish?
          'Enter a valid name (1-80 characters, no slashes).':
          'اكتب اسمًا من 1 إلى 80 حرفًا بدون شرطات مسار.');
         return;
        }
        final normalized=WaffraReceiptFilename.normalizedLabel(name.text)!;
        Navigator.pop(dialogContext,
         normalized==WaffraReceiptFilename.displayName(path)?null:normalized);
       }),child:WaffraText(waffraIsEnglish?'Save name':'حفظ الاسم')),
      ],
     )));
  }finally{name.dispose();}
 }
 Future<String> saveReceipt(XFile picked)async {
  final directory=Directory('${(await getApplicationDocumentsDirectory()).path}/receipts');
  if(!await directory.exists())await directory.create(recursive:true);
  final original=picked.name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-.\u0600-\u06FF ]'),'_');
  final target='${directory.path}/${newId()}__$original';
  await File(picked.path).copy(target);
  return target;
 }
 Future<void> showReceipt(String encoded,{int initialIndex=0,String? entryId})async {
  final paths=waffraReceiptPaths(encoded);
  final encrypted=paths.isNotEmpty&&
   paths.every((p)=>p.startsWith('waffra-receipt://'));
  final available=<String>[];
  final encryptedBytes=<Uint8List>[];
  if(encrypted){
   // The tokens are opaque and owner-bound; never treat them as file paths.
   if(entryId==null||!List.generate(paths.length,
      (i)=>WaffraEncryptedReceiptReference.matches(
       paths[i],entryId,i)).every((matched)=>matched)){
    if(mounted)snack(context,waffraIsEnglish?
     'Encrypted receipt owner could not be verified.':
     'تعذر التحقق من ارتباط الصورة بالعملية.',isError:true);
    return;
   }
   try{
    encryptedBytes.addAll(await _financeAuthority.loadEncryptedReceiptImages(
     route:WaffraFinanceRoute.receiptView,entryId:entryId));
    if(encryptedBytes.length!=paths.length){
     throw StateError('Encrypted receipt count mismatch');
    }
    available.addAll(paths);
   }catch(error){
    if(mounted)snack(context,waffraIsEnglish?
     'Could not verify encrypted attachments.':
     'تعذر التحقق من المرفقات المشفرة.',isError:true);
    return;
   }
  }else{
   if(paths.any((p)=>p.startsWith('waffra-receipt://'))){
    if(mounted)snack(context,waffraIsEnglish?
     'Mixed receipt references were rejected.':
     'تم رفض مراجع مرفقات غير متطابقة.',isError:true);
    return;
   }
   for(final path in paths){if(await File(path).exists())available.add(path);}
  }
  if(available.isEmpty){if(mounted)snack(context,waffraIsEnglish?
   'Images not found on this device':'ما لقينا الصور على الجهاز');return;}
  if(!mounted)return;
  final controller=PageController(initialPage:initialIndex.clamp(0,available.length-1));
  int current=initialIndex.clamp(0,available.length-1);
  try{
   await showWaffraDialog<void>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update){
    final isDark=Theme.of(ctx).brightness==Brightness.dark;
    final accent=isDark?const Color(0xFF74D8A9):emerald;
    final surface=isDark?const Color(0xFF102A23):const Color(0xFF073F31);
    final count='${current+1} / ${available.length}';
    return Dialog(
     backgroundColor:Colors.transparent,elevation:0,
     insetPadding:const EdgeInsets.symmetric(horizontal:22,vertical:45),
     child:Container(
      constraints:BoxConstraints(maxHeight:MediaQuery.sizeOf(ctx).height*.74),
      decoration:BoxDecoration(color:surface,borderRadius:BorderRadius.circular(24),
       border:Border.all(color:accent.withValues(alpha:.85),width:1.2)),
      clipBehavior:Clip.antiAlias,
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       SizedBox(height:54,child:Stack(alignment:Alignment.center,children:[
        PositionedDirectional(end:7,child:IconButton(
         tooltip:waffraIsEnglish?'Close':'إغلاق',
         onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
         icon:const Icon(Icons.close_rounded,color:Colors.white))),
       ])),
       Flexible(child:Container(color:Colors.black,
        child:PageView.builder(controller:controller,itemCount:available.length,
         onPageChanged:(index)=>update(()=>current=index),
         itemBuilder:(ctx,index)=>InteractiveViewer(
          minScale:.8,maxScale:5,
          child:Center(child:encrypted?
           Image.memory(encryptedBytes[index],fit:BoxFit.contain):
           Image.file(File(available[index]),fit:BoxFit.contain)))))),
       Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        child:WaffraText(encrypted?
         (waffraIsEnglish?'Attachment ${current+1}':'مرفق ${current+1}'):
         WaffraReceiptFilename.displayName(available[current]),
         maxLines:2,textAlign:TextAlign.center,
         style:const TextStyle(color:Colors.white,fontSize:13,fontWeight:FontWeight.w700))),
       SizedBox(height:58,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        IconButton(
         tooltip:waffraIsEnglish?'Previous image':'الصورة السابقة',
         onPressed:WaffraHaptics.tap(current>0?()=>controller.previousPage(
          duration:waffraMotion(220),curve:Curves.easeInOut):null),
         icon:Icon(Icons.chevron_left_rounded,color:current>0?Colors.white:Colors.white38)),
        Text(count,textDirection:TextDirection.ltr,
         style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.bold)),
        IconButton(
         tooltip:waffraIsEnglish?'Next image':'الصورة التالية',
         onPressed:WaffraHaptics.tap(current<available.length-1?()=>controller.nextPage(
          duration:const Duration(milliseconds:220),curve:Curves.easeInOut):null),
         icon:Icon(Icons.chevron_right_rounded,
          color:current<available.length-1?Colors.white:Colors.white38)),
       ])),
      ])));
   }));
  }finally{controller.dispose();}
 }
}

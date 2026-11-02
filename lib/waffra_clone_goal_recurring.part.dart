part of 'main.dart';

/// Duplicate form templates only. Never reuse ledger IDs, paid occurrences,
/// goal savings, linked-goal due schedules, or old recurring postponements.
extension WaffraCloneGoalRecurring on _HomeScreenState {
 Future<void> copyGoalDialog() async {
  final sources=<SavingGoal>[...goals];
  for(final raw in deletedGoals){
   try{
    final value=raw['goal'];
    if(value is Map){
     sources.add(SavingGoal.fromJson(Map<String,dynamic>.from(value)));
    }
   }catch(_){/* Malformed history cannot change the ledger. */}
  }
  if(sources.isEmpty){
   if(mounted)snack(context,waffraIsEnglish?
    'There are no goals to copy.':'ما فيه أهداف للنسخ.');
   return;
  }
  String query='';
  final chosen=await showWaffraDialog<SavingGoal>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
    final visible=sources.where((g)=>
     waffraSearchAny([g.name,waffraTr(g.name)],query)).toList();
    return AlertDialog(
     title:WaffraText(waffraIsEnglish?'Copy an existing goal':'نسخ هدف ادخار'),
     content:SizedBox(width:410,
      height:min(410.0,MediaQuery.sizeOf(ctx).height*.55),
      child:Column(children:[
       TextField(autofocus:true,textInputAction:TextInputAction.search,
        onChanged:(v)=>refresh(()=>query=v),
        decoration:InputDecoration(
         prefixIcon:const Icon(Icons.search_rounded),
         hintText:waffraIsEnglish?'Search goals':'ابحث في الأهداف',
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
       const SizedBox(height:9),
       Expanded(child:visible.isEmpty?
        Center(child:WaffraText(waffraIsEnglish?'No matches':'لا توجد نتائج')):
        ListView.builder(itemCount:visible.length,itemBuilder:(_,index){
         final goal=visible[index];
         final isPrevious=!goals.any((g)=>g.id==goal.id);
         return Card(elevation:0,
          shape:RoundedRectangleBorder(
           borderRadius:BorderRadius.circular(12),
           side:BorderSide(color:emerald.withValues(alpha:.28))),
          child:ListTile(
           title:WaffraText(goal.name,maxLines:2),
           subtitle:WaffraText(isPrevious?
            (waffraIsEnglish?'Previous goal':'هدف سابق'):
            (waffraIsEnglish?'Current goal':'هدف حالي')),
           trailing:const Icon(Icons.copy_rounded,color:emerald),
           onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,goal))));
        })),
      ])),
     actions:[TextButton(
      onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
   }));
  if(chosen!=null&&mounted)await goalDialog(copyFrom:chosen);
 }

 Future<void> copyRecurringDialog() async {
  // Goal-linked one-off dues are deliberately excluded: the linked goal
  // itself should be copied; no auto-settlement or duplicate due is created.
  final sources=<RecurringBill>[
   ...recurring.where((r)=>r.linkedGoalId==null),
  ];
  for(final raw in deletedRecurring){
   try{
    final value=raw['recurring'];
    if(value is Map){
     final candidate=RecurringBill.fromJson(Map<String,dynamic>.from(value));
     if(candidate.linkedGoalId==null)sources.add(candidate);
    }
   }catch(_){/* Ignore invalid read-only archive snapshots. */}
  }
  if(sources.isEmpty){
   if(mounted)snack(context,waffraIsEnglish?
    'There are no recurring items to copy.':'ما فيه عمليات متكررة للنسخ.');
   return;
  }
  String query='';
  final chosen=await showWaffraDialog<RecurringBill>(
   context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh){
    final visible=sources.where((r)=>waffraSearchAny(
     [r.title,r.category,waffraTr(r.title)],query)).toList();
    return AlertDialog(
     title:WaffraText(waffraIsEnglish?
      'Copy recurring transaction':'نسخ عملية متكررة'),
     content:SizedBox(width:410,
      height:min(410.0,MediaQuery.sizeOf(ctx).height*.55),
      child:Column(children:[
       TextField(autofocus:true,textInputAction:TextInputAction.search,
        onChanged:(v)=>refresh(()=>query=v),
        decoration:InputDecoration(
         prefixIcon:const Icon(Icons.search_rounded),
         hintText:waffraIsEnglish?'Search recurring':'ابحث في المتكررة',
         border:OutlineInputBorder(borderRadius:BorderRadius.circular(13)))),
       const SizedBox(height:9),
       Expanded(child:visible.isEmpty?
        Center(child:WaffraText(waffraIsEnglish?'No matches':'لا توجد نتائج')):
        ListView.builder(itemCount:visible.length,itemBuilder:(_,index){
         final row=visible[index];
         final isPrevious=!recurring.any((r)=>r.id==row.id);
         return Card(elevation:0,
          shape:RoundedRectangleBorder(
           borderRadius:BorderRadius.circular(12),
           side:BorderSide(color:emerald.withValues(alpha:.28))),
          child:ListTile(
           title:WaffraText(row.title,maxLines:2),
           subtitle:WaffraText((isPrevious?
            (waffraIsEnglish?'Previous':'سابقة'):
            (waffraIsEnglish?'Current':'حالية'))+' • '+cash(row.amount)),
           trailing:const Icon(Icons.copy_rounded,color:emerald),
           onTap:WaffraHaptics.tap(()=>Navigator.pop(ctx,row))));
        })),
      ])),
     actions:[TextButton(
      onPressed:WaffraHaptics.tap(()=>Navigator.pop(ctx)),
      child:WaffraText(waffraIsEnglish?'Close':'إغلاق'))]);
   }));
  if(chosen!=null&&mounted)await recurringDialog(copyFrom:chosen);
 }
}

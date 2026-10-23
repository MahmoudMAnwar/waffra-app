import '../waffra_merchant_rules.dart';

/// Read-only plan for confirmed SMS batches. NO finance or category writes.
/// Caller must commit every generated category in the SAME guarded finance
/// transaction as its entries and deduplication fingerprints, or fail closed.
class WaffraM155Category {
 const WaffraM155Category({
  required this.id,required this.name,required this.income,this.parentId='',
 });
 final String id,name,parentId;
 final bool income;
 bool get isLeaf=>parentId.isNotEmpty;
}

class WaffraM155Assignment {
 const WaffraM155Assignment({
  required this.categoryName,required this.merchantKey,
  required this.newCategoryRequired,
 });
 final String categoryName,merchantKey;
 final bool newCategoryRequired;
}

/// Plan new merchant children without mutating in-memory database, preferences
/// or deleted category state. Write/persist is deliberately NOT in this class.
class WaffraM155CategoryPlan {
 const WaffraM155CategoryPlan._();

 static WaffraM155Assignment? propose({
  required String rawSms,
  required bool income,
  required List<WaffraM155Category> existing,
  required Map<String,String> learned,
 }) {
  final merchant=waffraMerchantName(rawSms,income:income);
  final key=merchant==null?'':waffraNormalizeMerchantName(merchant);
  final active=existing.where((c)=>c.income==income).toList();
  final known=merchant==null?null:waffraRecognizedMerchantLeaf(
   merchant,income:income);
  for(final candidate in [if(key.isNotEmpty)learned[key],known]){
   if(candidate==null)continue;
   for(final child in active.where((c)=>c.isLeaf&&c.name==candidate)){
    if(active.any((p)=>p.id==child.parentId&&!p.isLeaf)){
     return WaffraM155Assignment(
      categoryName:child.name,merchantKey:key,newCategoryRequired:false);
    }
   }
  }
  final isTransfer=RegExp(r'حوال[ةه]|تحويل|transfer',
   caseSensitive:false).hasMatch(rawSms);
  final parentName=waffraFallbackSmsParent(income:income,transfer:isTransfer);
  final parents=active.where((c)=>!c.isLeaf&&c.name==parentName).toList();
  if(merchant!=null&&parents.length==1){
   final parent=parents.single;
   final existingChild=active.where((c)=>c.parentId==parent.id&&
     waffraNormalizeMerchantName(c.name.split(' / ').last)==key).toList();
   if(existingChild.isNotEmpty){
    return WaffraM155Assignment(categoryName:existingChild.first.name,
     merchantKey:key,newCategoryRequired:false);
   }
   final candidate=parent.name+' / '+merchant;
   if(active.any((c)=>c.name==candidate)){
    throw StateError('Ambiguous merchant category already exists.');
   }
   return WaffraM155Assignment(categoryName:candidate,merchantKey:key,
    newCategoryRequired:true);
  }
  final fallback=income?'دخل آخر / دخل غير مصنف':'أخرى / مصروف غير مصنف';
  final matches=active.where((c)=>c.isLeaf&&c.name==fallback&&
   active.any((p)=>p.id==c.parentId&&!p.isLeaf)).toList();
  if(matches.length!=1)return null;
  return WaffraM155Assignment(categoryName:fallback,merchantKey:key,
   newCategoryRequired:false);
 }
}

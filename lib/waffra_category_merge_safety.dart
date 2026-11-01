/// Read-only proposal for a future immutable-ID category merge.
/// The legacy MoneyEntry stores category names; DO NOT apply this to actual
/// records until verified ID migration, backup and rollback are implemented.
class WaffraCategoryIdentity {
 const WaffraCategoryIdentity(this.id,this.name,this.parentId,this.income,
      {this.hasBudget=false});
 final String id,name,parentId;
 final bool income,hasBudget;
}
class WaffraCategoryAssignment {
 const WaffraCategoryAssignment(this.recordId,this.categoryId);
 final String recordId,categoryId;
}
class WaffraCategoryMergePreview {
 const WaffraCategoryMergePreview(this.sourceId,this.targetId,
   this.transactionIds,this.recurringIds,this.budgetReviewRequired);
 final String sourceId,targetId;
 final List<String> transactionIds,recurringIds;
 final bool budgetReviewRequired;
}
abstract final class WaffraCategoryMergeSafety {
 static WaffraCategoryMergePreview propose({
  required String sourceId,
  required String targetId,
  required Iterable<WaffraCategoryIdentity> categories,
  required Iterable<WaffraCategoryAssignment> transactions,
  required Iterable<WaffraCategoryAssignment> recurring,
 }) {
  if(sourceId.isEmpty||targetId.isEmpty||sourceId==targetId) {
    throw StateError('Invalid source/target category');
  }
  final all=<String,WaffraCategoryIdentity>{};
  for(final category in categories){
    if(category.id.isEmpty||category.name.trim().isEmpty||
       all.containsKey(category.id))throw StateError('Invalid category catalog');
    all[category.id]=category;
  }
  final source=all[sourceId],target=all[targetId];
  if(source==null||target==null||
     source.income!=target.income||source.parentId!=target.parentId) {
    throw StateError('Incompatible income/expense or category hierarchy');
  }
  // Reject merging a parent containing children; reparenting and child
  // budget handling must go through a distinct explicit workflow.
  if(all.values.any((entry)=>entry.parentId==sourceId)) {
    throw StateError('Parent merge with children requires review');
  }
  List<String> affected(Iterable<WaffraCategoryAssignment> rows) {
    final ids=<String>{};
    for(final row in rows) {
      if(row.recordId.isEmpty||!ids.add(row.recordId)||
         !all.containsKey(row.categoryId)) {
        throw StateError('Missing or duplicate financial reference');
      }
    }
    return List<String>.unmodifiable(
      rows.where((row)=>row.categoryId==sourceId)
          .map((row)=>row.recordId));
  }
  final transactionRows=transactions.toList(growable:false);
  final recurringRows=recurring.toList(growable:false);
  return WaffraCategoryMergePreview(sourceId,targetId,
    affected(transactionRows),affected(recurringRows),
    source.hasBudget||target.hasBudget);
 }
}

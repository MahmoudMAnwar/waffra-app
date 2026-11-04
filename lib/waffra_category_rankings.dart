/// Presentation-only category ranking. It never changes stored category order,
/// IDs, transaction links, income signs or encrypted finance history.
///
/// In mixed 'All' view, "highest income" ranks income parents before expense
/// parents; "highest expenses" ranks expense parents first. Each group's
/// current-calendar-month amount includes its children exactly once.
List<T> waffraRankCategoryRoots<T>(
  Iterable<T> roots, {
  required String mode,
  required String Function(T) label,
  required bool Function(T) isIncome,
  required double Function(T) monthlyTotal,
}) {
  final rows = roots.toList(growable:false);
  if(mode=='default')return List<T>.of(rows);
  if(!const {'alpha','income','spent'}.contains(mode)){
    throw ArgumentError.value(mode,'mode','Unsupported category ranking');
  }
  final decorated=<({T item,int original,String title,bool income,double total})>[];
  for(var i=0;i<rows.length;i++){
    final item=rows[i];
    final amount=monthlyTotal(item);
    if(!amount.isFinite||amount<0) {
      throw StateError('Invalid current-month category total');
    }
    decorated.add((item:item,original:i,title:label(item).trim().toLowerCase(),
      income:isIncome(item),total:amount));
  }
  decorated.sort((a,b){
    if(mode=='income'||mode=='spent'){
      final preferredIncome=mode=='income';
      if(a.income!=b.income)return a.income==preferredIncome?-1:1;
      if(a.income==preferredIncome){
        final compared=b.total.compareTo(a.total);
        if(compared!=0)return compared;
      }
    }
    final alphabetical=a.title.compareTo(b.title);
    return alphabetical!=0?alphabetical:a.original.compareTo(b.original);
  });
  return [for(final row in decorated)row.item];
}

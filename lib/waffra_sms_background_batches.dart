/// M1017 / Issue #734: work through every actionable bank-SMS candidate
/// without keeping an unbounded batch in memory or silently stopping after
/// the first 25. Processing and financial commits remain sequential.
Iterable<List<T>> waffraSmsBackgroundBatches<T>(
 List<T> candidates,{int batchSize=25}
)sync*{
 if(batchSize<1){
  throw ArgumentError.value(batchSize,'batchSize','Must be positive');
 }
 for(var offset=0;offset<candidates.length;offset+=batchSize){
  final end=offset+batchSize<candidates.length?
   offset+batchSize:candidates.length;
  yield candidates.sublist(offset,end);
 }
}

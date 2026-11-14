/// M940: presentation-only bounded visibility for an already verified,
/// sender-grouped SMS review queue. No native acknowledgement, deletion,
/// duplicate suppression, finance write or account-source change.
final class WaffraSmsReviewPageWindow {
 WaffraSmsReviewPageWindow({this.pageSize=100}):
  assert(pageSize>0),_exposed=pageSize;

 final int pageSize;
 int _exposed;

 int visibleCount(int total){
  if(total<0)throw RangeError.value(total,'total','Must be nonnegative');
  return total<_exposed?total:_exposed;
 }

 bool revealNext(int total){
  if(total<0)throw RangeError.value(total,'total','Must be nonnegative');
  if(_exposed>=total)return false;
  final next=_exposed+pageSize;
  _exposed=next<total?next:total;
  return true;
 }

 void reset(){_exposed=pageSize;}
}

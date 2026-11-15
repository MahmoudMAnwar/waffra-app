import 'dart:convert';

/// M1000: immutable financial differences between two *authenticated*
/// source snapshots. Review-only. Not a durable edit history or a writer.
class WaffraFinancialRowChange {
 const WaffraFinancialRowChange({
  required this.id,required this.beforeMinor,required this.afterMinor,
  required this.beforeTitle,required this.afterTitle,
  required this.beforeCategory,required this.afterCategory,
 });
 final String id;
 final int? beforeMinor,afterMinor;
 final String? beforeTitle,afterTitle,beforeCategory,afterCategory;
 bool get added=>beforeMinor==null;
 bool get removed=>afterMinor==null;
 bool get edited=>!added&&!removed;
}
class WaffraFinancialChangeReview {
 const WaffraFinancialChangeReview({
  required this.added,required this.removed,required this.changed,
  required this.unchanged,required this.beforeNetMinor,
  required this.afterNetMinor,required this.samples,
 });
 final int added,removed,changed,unchanged,beforeNetMinor,afterNetMinor;
 final List<WaffraFinancialRowChange> samples;
 int get netDifferenceMinor=>afterNetMinor-beforeNetMinor;
 String describe(bool english){
  if(english)return 'Snapshot impact (read-only): '+
    '$added new, $removed removed, $changed changed, '+
    '$unchanged unchanged transactions. Net difference: '+
    (netDifferenceMinor/100).toStringAsFixed(2)+' SAR.'+
    '\nThis is NOT a permanent edit-history log.';
  return 'أثر الاستعادة (معاينة فقط): '+
   '$added عملية جديدة، $removed غير موجودة بالنسخة، '+
   '$changed مختلفة، $unchanged بدون تغيير. فرق الصافي: '+
   (netDifferenceMinor/100).toStringAsFixed(2)+
   ' ريال.\nهذه مقارنة وليست سجل تعديلات دائم.';
 }
}
abstract final class WaffraFinancialDiff {
 static int signedMinor(Map<String,dynamic> r){
  final raw=r['amount'];
  if(raw is! num||!raw.isFinite||raw<0||raw>1000000000000) {
   throw const FormatException('Invalid SAR financial value.');
  }
  final cents=raw*100,rounded=cents.round();
  if((cents-rounded).abs()>0.000001) {
   throw const FormatException('Non-SAR amount precision.');
  }
  if(r['income'] is! bool)throw const FormatException('Missing income marker.');
  return r['income']==true?rounded:-rounded;
 }
 static Map<String,Map<String,dynamic>> index(List<dynamic> raw) {
  if(raw.length>100000)throw const FormatException('Too many finance records.');
  final found=<String,Map<String,dynamic>>{};
  for(final row in raw) {
   if(row is! Map)throw const FormatException('Invalid record.');
   final data=Map<String,dynamic>.from(row);
   final id=data['id'];
   if(id is! String||id.trim().isEmpty||found.containsKey(id)||
      data['title'] is! String||data['category'] is! String) {
    throw const FormatException('Missing/duplicate immutable record ID.');
   }
   signedMinor(data);
   found[id]=data;
  }
  return found;
 }
 static WaffraFinancialChangeReview compare({
  required List<dynamic> before,required List<dynamic> after,
 }) {
  final old=index(before),next=index(after);
  var added=0,removed=0,changed=0,unchanged=0;
  var oldNet=0,newNet=0;
  final samples=<WaffraFinancialRowChange>[];
  for(final a in old.values){oldNet+=signedMinor(a);}
  for(final b in next.values){newNet+=signedMinor(b);}
  for(final id in {...old.keys,...next.keys}) {
   final a=old[id],b=next[id];
   if(a==null){added++;}
   else if(b==null){removed++;}
   else if(jsonEncode(a)==jsonEncode(b)){unchanged++;continue;}
   else{changed++;}
   if(samples.length<25){
    samples.add(WaffraFinancialRowChange(
     id:id,beforeMinor:a==null?null:signedMinor(a),
     afterMinor:b==null?null:signedMinor(b),
     beforeTitle:a?['title'] as String?,
     afterTitle:b?['title'] as String?,
     beforeCategory:a?['category'] as String?,
     afterCategory:b?['category'] as String?,
    ));
   }
  }
  return WaffraFinancialChangeReview(
   added:added,removed:removed,changed:changed,unchanged:unchanged,
   beforeNetMinor:oldNet,afterNetMinor:newNet,
   samples:List<WaffraFinancialRowChange>.unmodifiable(samples));
 }
}

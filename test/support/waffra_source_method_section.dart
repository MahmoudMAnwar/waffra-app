/// Fail-closed source boundary extraction for static regression tests.
/// A comment is never a safe boundary: it can disappear during a refactor.
/// Only unique, explicit method declarations belong here.
String waffraSourceMethodSection(
 String source,{required String start,required String end}
){
 final first=source.indexOf(start);
 if(first<0||source.indexOf(start,first+start.length)>=0){
  throw FormatException('Missing or duplicated start method: $start');
 }
 final last=source.indexOf(end,first+start.length);
 if(last<0||source.indexOf(end,last+end.length)>=0){
  throw FormatException('Missing or duplicated next method: $end');
 }
 if(last<=first+start.length){
  throw FormatException('Methods out of order: $start, $end');
 }
 return source.substring(first+start.length,last);
}

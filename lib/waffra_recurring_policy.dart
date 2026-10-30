/// Pure due-date and money policies shared by Waffra UI and unit tests.
/// A schedule is not a ledger entry: only an explicit payment creates one.
class WaffraRecurringPolicy {
 const WaffraRecurringPolicy._();

 static DateTime dueDate(int year,int month,int day) {
  final lastDay=DateTime(year,month+1,0).day;
  return DateTime(year,month,day.clamp(1,lastDay));
 }

 /// First due date not earlier than either today or the schedule start.
 /// A newly scheduled future recurring item must never be presented as
 /// payable this month before its actual first eligible occurrence.
 static DateTime nextDueDate({
  required DateTime today, required DateTime startAt, required int day,
 }) {
  if(day<1||day>31)throw ArgumentError.value(day,'day','Day must be 1..31');
  final current=DateTime(today.year,today.month,today.day);
  final earliest=DateTime(startAt.year,startAt.month,startAt.day);
  final threshold=current.isAfter(earliest)?current:earliest;
  var due=dueDate(threshold.year,threshold.month,day);
  if(due.isBefore(threshold)) {
   due=dueDate(threshold.year,threshold.month+1,day);
  }
  return due;
 }

 static String entryId(String scheduleId,DateTime due)=>
  'rec_${scheduleId}_${due.year}_${due.month}';

 static bool isOutstanding({
  required DateTime due,
  required DateTime today,
  required DateTime startAt,
  required bool alreadyPaid,
  DateTime? postponedUntil,
 }) {
  if(alreadyPaid)return false;
  final todayOnly=DateTime(today.year,today.month,today.day);
  final first=DateTime(startAt.year,startAt.month,startAt.day);
  final dueOnly=DateTime(due.year,due.month,due.day);
  if(dueOnly.isBefore(first))return false;
  final effective=postponedUntil==null?dueOnly:
    DateTime(postponedUntil.year,postponedUntil.month,postponedUntil.day);
  return !effective.isAfter(todayOnly);
 }

 /// Values are rounded to halalas individually so summation is deterministic.
 static int toHalalas(num amount)=>(amount*100).round();
 static int netHalalas(Iterable<num> incomes,Iterable<num> expenses)=>
  incomes.fold<int>(0,(sum,value)=>sum+toHalalas(value))-
  expenses.fold<int>(0,(sum,value)=>sum+toHalalas(value));
}

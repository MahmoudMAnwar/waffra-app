import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_practical_ledger_engine.dart';

void main(){
 test('M350 20k same merchant and amount spaced >48h: no quadratic guesses',(){
  final start=DateTime.utc(2026,1,1);
  final rows=List<WaffraPracticalEntry>.generate(20000,(i)=>
   WaffraPracticalEntry(id:'tx-'+i.toString(),title:'Test merchant',
    category:'شراء',amount:75,income:false,
    date:start.add(Duration(days:i*3))));
  final result=WaffraDataHealth.inspect(rows);
  expect(result.where((issue)=>
    issue.kind==WaffraHealthIssueKind.possibleDuplicate),isEmpty);
  expect(rows.length,20000);
 });
 test('M350 unordered real-looking near duplicates remain reviewable',(){
  final rows=[
   WaffraPracticalEntry(id:'older',title:'Cafe',
    category:'مطاعم',amount:20,income:false,date:DateTime(2026,11,1)),
   WaffraPracticalEntry(id:'newer',title:'Cafe',
    category:'مطاعم',amount:20,income:false,date:DateTime(2026,11,2)),
   WaffraPracticalEntry(id:'far',title:'Cafe',
    category:'مطاعم',amount:20,income:false,date:DateTime(2026,10,20)),
  ];
  final result=WaffraDataHealth.inspect(rows);
  final candidates=result.where((issue)=>
    issue.kind==WaffraHealthIssueKind.possibleDuplicate).toList();
  expect(candidates.length,1);
  expect(rows[0].amount,20); // no changes
 });
}

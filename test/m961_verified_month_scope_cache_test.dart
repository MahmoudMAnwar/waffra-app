import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show
  MoneyEntry,WaffraFinancePeriodIndex,WaffraHomeLedgerReadCache;

/// M961: verified display filters must never leak between account witnesses.
/// Uses synthetic host data, never a user backup or a finance writer.
void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  MoneyEntry entry(int i)=>MoneyEntry(
    id:'tx-$i',title:'Transaction $i',category:'Test',
    amount:(i%27+1).toDouble(),income:i.isEven,
    date:DateTime(2026,1+i%12,1+i%27),sourceType:'manual');

  test('M961 12000 rows keep month order and account isolation across '
      'repeated Home and Budget builds',(){
    final rows=List<MoneyEntry>.generate(12000,entry);
    final cache=WaffraHomeLedgerReadCache();
    final index=cache.index(rows);
    final month=index.month(2026,11);
    expect(month.length,1000);
    expect(identical(month,index.month(2026,11)),isTrue);
    final idsA={for(var i=0;i<12000;i++)if(i%7==0)'tx-$i'};
    final idsB={for(var i=0;i<12000;i++)if(i%7==1)'tx-$i'};
    final expectedA=month.where((e)=>idsA.contains(e.id)).toList();
    final selectedA=cache.scopedMonth(month,idsA);
    expect(selectedA,expectedA);
    expect(identical(selectedA,
      cache.scopedMonth(index.month(2026,11),idsA)),isTrue);
    final selectedB=cache.scopedMonth(month,idsB);
    expect(selectedB,month.where((e)=>idsB.contains(e.id)).toList());
    expect(selectedB.map((e)=>e.id).toSet()
      .intersection(selectedA.map((e)=>e.id).toSet()),isEmpty);
    expect(identical(selectedA,selectedB),isFalse);
    final freshWitnessSet={...idsA};
    final refreshed=cache.scopedMonth(month,freshWitnessSet);
    expect(refreshed,expectedA);
    expect(identical(refreshed,selectedA),isFalse,
      reason:'A new SQLCipher account-link witness must recompute.');
    expect(()=>refreshed.clear(),throwsUnsupportedError);
    expect(cache.scopedMonth(index.month(2026,12),idsA),
      index.month(2026,12).where((e)=>idsA.contains(e.id)).toList());
    expect(cache.scopedMonth(index.month(2026,1),<String>{}),isEmpty);
    expect(index.month(2026,11),month);
  });

  test('M961 invalidation drops old month and owner account filter',(){
    final rows=<MoneyEntry>[entry(10),entry(22)];
    final cache=WaffraHomeLedgerReadCache();
    final index=cache.index(rows);
    final ids={'tx-10','tx-34'};
    final before=cache.scopedMonth(index.month(2026,11),ids);
    expect(before.map((e)=>e.id),['tx-10']);
    rows.add(entry(34));
    expect(identical(index,cache.index(rows)),isTrue);
    expect(index.month(2026,11),hasLength(2));
    cache.invalidate();
    final current=cache.index(rows);
    expect(identical(current,index),isFalse);
    expect(current.month(2026,11),hasLength(3));
    final after=cache.scopedMonth(current.month(2026,11),ids);
    expect(after.map((e)=>e.id),['tx-10','tx-34']);
    expect(identical(after,before),isFalse);
    expect(()=>after.add(entry(46)),throwsUnsupportedError);
  });
}

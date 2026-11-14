import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';
void main(){
 test('M905 registered verified transfer and savings history never posts finance',(){
  final m=File('lib/main.dart').readAsStringSync();
  final p=File('lib/waffra_home_unified_activity_reads.part.dart').readAsStringSync();
  expect(m.split("part 'waffra_home_unified_activity_reads.part.dart';").length,2);
  expect(p,startsWith("part of 'main.dart';"));
  expect(m,isNot(contains(' void _m648InvalidateTransfers(){')));
  for(final method in [
   ' void _m648InvalidateTransfers(){',
   ' Future<List<WaffraInternalTransferHistory>> _m648HomeTransfers(',
   ' Future<List<WaffraVerifiedGoalMovement>> _m649HomeSavings(',
   ' })> _m652UnifiedActivities(String account){',
  ]){expect(p.split(method).length,2,reason:method);}
  expect(p,contains('_m650DueSourceCache.clear();'));
  expect(p,contains("accountId:account=='all'?null:account"));
  expect(p,contains("StateError('Verified transfer history source unavailable')"));
  expect(p,contains("StateError('Verified goal source unavailable')"));
  expect(p,contains('return (transfers:transfers,savings:savings);'));
  expect(p,isNot(contains('saveCaptured(')));
  expect(p,isNot(contains('commitConfirmedSms(')));
 });
 test('M905 original four history methods reassemble byte for byte',(){
  final src=readWaffraMainSourceForContracts();
  final p=File('lib/waffra_home_unified_activity_reads.part.dart').readAsStringSync();
  final a=src.indexOf(' void _m648InvalidateTransfers(){');
  final b=src.indexOf(' WaffraAccountContextReadResult? _m467AccountContext;',a);
  expect(a,greaterThan(0));expect(b,greaterThan(a));
  expect(src.substring(a,b),p.substring(p.indexOf(' void _m648InvalidateTransfers(){'),p.lastIndexOf('\n}')+1));
 });
}

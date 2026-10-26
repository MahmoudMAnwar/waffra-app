import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_oil_market_data.dart';

void main(){
 test('EIA spot parser sorts by date and never invents missing benchmarks',(){
  final result=WaffraOilService.parse({
   'response':{'data':[
    {'series':'RWTC','period':'2026-10-21','value':'82.5'},
    {'series':'RBRTE','period':'2026-10-20','value':'81'},
    {'series':'RBRTE','period':'2026-10-21','value':'83.5'},
    {'series':'RBRTE','period':'2026-10-19','value':'79'},
    {'series':'RBRTE','period':'2026-10-21','value':'83.5'},
   ]}
  });
  expect(result['BRENT']!.usd,83.5);
  expect(result['BRENT']!.points.length,3);
  expect(result['BRENT']!.changePercent,isNotNull);
  expect(result['WTI']!.usd,82.5);
  expect(result.containsKey('OMAN'),isFalse);
  expect(result.containsKey('DUBAI'),isFalse);
  expect(result.containsKey('GAS'),isFalse);
 });
 test('invalid/negative and non-numeric values are never displayed',(){
  expect(WaffraOilService.parse({'response':{'data':[
   {'series':'RBRTE','period':'2026-10-20','value':'-1'},
   {'series':'RWTC','period':'2026-10-20','value':'oops'},
  ]}}),isEmpty);
  expect(()=>WaffraOilService.parse({'response':{'data':'not a list'}}),
   throwsFormatException);
 });
 test('unconfigured public market key fails explicitly and never returns demo quote',()async {
  await expectLater(const WaffraOilService(publicEiaKey:'').fetch(),
   throwsStateError);
 });
}

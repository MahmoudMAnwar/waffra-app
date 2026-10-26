import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
 test('FRED public CSV strictly validates named series, dates and missing values',(){
  final quote=WaffraOilService.parseFredCsv('DCOILBRENTEU','BRENT',
   'observation_date,DCOILBRENTEU\n'
   '2026-10-20,81.0\n2026-10-21,.\n2026-10-22,82.1\n');
  expect(quote!.points.length,2);
  expect(quote.usd,82.1);
  expect(quote.changePercent,closeTo((82.1/81.0-1)*100,0.00001));
  expect(()=>WaffraOilService.parseFredCsv('DCOILWTICO','WTI',
   'observation_date,DCOILBRENTEU\n2026-10-22,80\n'),
   throwsFormatException);
  expect(WaffraOilService.parseFredCsv('DHHNGSP','GAS',
   'observation_date,DHHNGSP\n2026-10-22,.\n'),isNull);
 });
 test('FRED HTTP failure never returns sample market prices',()async {
  final fake=MockClient((request)async=>http.Response('unavailable',503));
  await expectLater(const WaffraOilService(publicEiaKey:'').fetch(client:fake),
   throwsStateError);
  fake.close();
 });
}

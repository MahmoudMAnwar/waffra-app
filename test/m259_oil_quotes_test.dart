import 'dart:convert';
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
 test('EIA Henry Hub spot only accepts gas series and MMBtu units',(){
  final result=WaffraOilService.parseEiaGas({'response':{'data':[
   {'series':'RNGWHHD','period':'2026-10-20','value':'3.10',
    'units':'Dollars per Million Btu'},
   {'series':'RNGWHHD','period':'2026-10-21','value':'3.35',
    'units':'Dollars per Million Btu'},
   {'series':'RNGC1','period':'2026-10-22','value':'99.99',
    'units':'Dollars per Million Btu'},
   {'series':'RNGWHHD','period':'2026-10-23','value':'900.00',
    'units':'USD / barrel'},
  ]}});
  expect(result!.id,'GAS');
  expect(result.points.length,2);
  expect(result.usd,3.35);
  expect(result.changePercent,closeTo((3.35/3.10-1)*100,0.00001));
  expect(WaffraOilService.parseEiaGas({'response':{'data':[]}}),isNull);
 });

 test('registered EIA key requests independent crude and gas source routes',()async{
  final visited=<String>[];
  final mock=MockClient((request)async{
   visited.add(request.url.path);
   expect(request.url.queryParameters['api_key'],'public-readonly-test');
   if(request.url.path.contains('/natural-gas/')){
    expect(request.url.queryParameters['facets[series][]'],'RNGWHHD');
    return http.Response(jsonEncode({'response':{'data':[
     {'series':'RNGWHHD','period':'2026-10-21','value':'3.35',
      'units':'Dollars per Million Btu'},
    ]}}),200);
   }
   expect(request.url.path,'/v2/petroleum/pri/spt/data/');
   return http.Response(jsonEncode({'response':{'data':[
    {'series':'RBRTE','period':'2026-10-21','value':'81.50'},
    {'series':'RWTC','period':'2026-10-21','value':'77.20'},
   ]}}),200);
  });
  final quotes=await const WaffraOilService(
   publicEiaKey:'public-readonly-test').fetch(client:mock);
  expect(quotes.keys.toSet(),{'BRENT','WTI','GAS'});
  expect(quotes['GAS']!.usd,3.35);
  expect(quotes['BRENT']!.usd,81.50);
  expect(visited,contains('/v2/natural-gas/pri/fut/data/'));
  expect(visited,contains('/v2/petroleum/pri/spt/data/'));
  mock.close();
 });

 test('FRED HTTP failure never returns sample market prices',()async {
  final fake=MockClient((request)async=>http.Response('unavailable',503));
  await expectLater(const WaffraOilService(publicEiaKey:'').fetch(client:fake),
   throwsStateError);
  fake.close();
 });
}

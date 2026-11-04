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

 test('official keyless EIA daily HTML parses dates and rejects wrong units',(){
  final monday=DateTime.utc(2026,10,19);
  const fixture='<html><title>Europe Brent Spot Price FOB '
   '(Dollars per Barrel)</title><table><tr>'
   '<th>Week Of</th><th>Mon</th><th>Tue</th><th>Wed</th>'
   '<th>Thu</th><th>Fri</th></tr>'
   '<tr><td>2026 Oct-19 to Oct-23</td><td>118.82</td>'
   '<td>115.22</td><td></td><td>NA</td><td></td></tr>'
   '</table></html>';
  final quote=WaffraOilService.parseEiaDailyHtml('BRENT',fixture);
  expect(quote, isNotNull);
  expect(quote!.points.length,2);
  expect(quote.points.first.date,monday);
  expect(quote.usd,115.22);
  expect(quote.updatedAt,DateTime.utc(2026,10,20));
  expect(()=>WaffraOilService.parseEiaDailyHtml(
    'GAS',fixture),throwsFormatException);
  expect(()=>WaffraOilService.parseEiaDailyHtml(
    'OMAN',fixture),throwsFormatException);
  const falsePrices='<html><title>Europe Brent Spot Price FOB '
   '(Dollars per Barrel)</title>Week Of<table><tr>'
   '<td>2026 Oct-18 to Oct-22</td><td>999.0</td>'
   '<td>999.0</td><td>999.0</td><td>999.0</td><td>999.0</td>'
   '</tr></table></html>';
  expect(WaffraOilService.parseEiaDailyHtml('BRENT',falsePrices),isNull);
 });

 test('keyless source falls back to official EIA pages on FRED 403',()async{
  final now=DateTime.now().toUtc();
  final monday=DateTime.utc(now.year,now.month,now.day)
   .subtract(Duration(days:now.weekday-1));
  const months=['Jan','Feb','Mar','Apr','May','Jun','Jul',
   'Aug','Sep','Oct','Nov','Dec'];
  final friday=monday.add(const Duration(days:4));
  String d(DateTime date)=>'${months[date.month-1]}-${date.day}';
  String fixture(String name,String units,String value)=>'<html><title>'
   '$name ($units)</title><table>'
   '<tr><th>Week Of</th><th>Mon</th><th>Tue</th><th>Wed</th>'
   '<th>Thu</th><th>Fri</th></tr><tr>'
   '<td>${monday.year} ${d(monday)} to ${d(friday)}</td>'
   '<td>$value</td><td></td><td></td><td></td><td></td>'
   '</tr></table></html>';
  final visited=<Uri>[];
  final mock=MockClient((request)async{
   visited.add(request.url);
   if(request.url.host=='fred.stlouisfed.org'){
    return http.Response('Forbidden',403);
   }
   expect(request.url.host,'www.eia.gov');
   switch(request.url.path){
    case '/dnav/pet/hist/RBRTEd.htm':
     return http.Response(fixture('Europe Brent Spot Price FOB',
      'Dollars per Barrel','111.20'),200);
    case '/dnav/pet/hist/RWTCd.htm':
     return http.Response(fixture('Cushing, OK WTI Spot Price FOB',
      'Dollars per Barrel','108.10'),200);
    case '/dnav/ng/hist/RNGWHHDD.htm':
     return http.Response(fixture('Henry Hub Natural Gas Spot Price',
      'Dollars per Million Btu','3.20'),200);
    default: return http.Response('Not found',404);
   }
  });
  final quotes=await const WaffraOilService(publicEiaKey:'').fetch(client:mock);
  expect(quotes.keys.toSet(),{'BRENT','WTI','GAS'});
  expect(quotes['BRENT']!.usd,111.20);
  expect(quotes['WTI']!.usd,108.10);
  expect(quotes['GAS']!.usd,3.20);
  expect(quotes['GAS']!.updatedAt,monday);
  expect(visited.where((u)=>u.host=='fred.stlouisfed.org'),isEmpty);
  mock.close();
 });

 test('partial official EIA response cannot make up a missing oil type',()async{
  final now=DateTime.now().toUtc();
  final monday=DateTime.utc(now.year,now.month,now.day)
   .subtract(Duration(days:now.weekday-1));
  const months=['Jan','Feb','Mar','Apr','May','Jun','Jul',
   'Aug','Sep','Oct','Nov','Dec'];
  String label(DateTime d)=>'${months[d.month-1]}-${d.day}';
  final friday=monday.add(const Duration(days:4));
  final table='<html>Europe Brent Spot Price FOB '
   '(Dollars per Barrel) Week Of '
   '<table><tr><td>${monday.year} ${label(monday)} to '
   '${label(friday)}</td><td>110.0</td><td></td><td></td>'
   '<td></td><td></td></tr></table></html>';
  final fake=MockClient((request)async{
   if(request.url.path=='/dnav/pet/hist/RBRTEd.htm'){
    return http.Response(table,200);
   }
   return http.Response('Forbidden',403);
  });
  final quotes=await const WaffraOilService(publicEiaKey:'').fetch(client:fake);
  expect(quotes.keys.toSet(),{'BRENT'});
  fake.close();
 });

}

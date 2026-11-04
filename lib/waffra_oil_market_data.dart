import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public read-only commodity data. Does not touch Waffra finance records.
/// No default, cached, sample or guessed commodity prices may be displayed.
class WaffraOilPoint {
 const WaffraOilPoint(this.date,this.usd);
 final DateTime date;
 final double usd;
}
class WaffraOilQuote {
 const WaffraOilQuote(this.id,this.points);
 final String id;
 final List<WaffraOilPoint> points;
 double get usd=>points.last.usd;
 DateTime get updatedAt=>points.last.date;
 double? get changePercent=>points.length<2?null:
  (usd/points[points.length-2].usd-1)*100;
 bool isOld(DateTime now)=>now.toUtc().difference(updatedAt.toUtc())>
  const Duration(days:10);
}
const waffraOilNames=<String,List<String>>{
 'BRENT':['Brent crude','خام برنت','USD / barrel','دولار / برميل'],
 'WTI':['West Texas Intermediate','خام غرب تكساس','USD / barrel','دولار / برميل'],
 'OMAN':['Oman crude','خام عُمان','USD / barrel','دولار / برميل'],
 'DUBAI':['Dubai crude','خام دبي','USD / barrel','دولار / برميل'],
 'GAS':['Natural gas','الغاز الطبيعي','USD / MMBtu','دولار / مليون وحدة حرارية'],
};

/// Official EIA daily spot Brent/WTI series. The API key is an EIA public
/// commodity quota key, supplied through --dart-define (not a bank secret).
/// Oman/Dubai remain unavailable without independently verified feeds.
/// Henry Hub gas uses the distinct official EIA daily spot series RNGWHHD.
class WaffraOilService {
 const WaffraOilService({this.publicEiaKey=const String.fromEnvironment(
  'WAFFRA_PUBLIC_EIA_KEY')});
 final String publicEiaKey;
 static Map<String,WaffraOilQuote> parse(Map<String,dynamic> json){
  final response=json['response'];
  if(response is! Map||response['data'] is! List){
   throw const FormatException('Invalid EIA daily spot payload');
  }
  final collected=<String,List<WaffraOilPoint>>{'RBRTE':[],'RWTC':[]};
  for(final row in response['data'] as List){
   if(row is! Map)continue;
   final id=row['series']?.toString();
   if(!collected.containsKey(id))continue;
   final period=DateTime.tryParse(row['period']?.toString()??'');
   final price=double.tryParse(row['value']?.toString()??'');
   if(period==null||price==null||!price.isFinite||price<=0||price>=10000)continue;
   final day=DateTime.utc(period.year,period.month,period.day);
   if(day.isAfter(DateTime.now().toUtc().add(const Duration(days:1))))continue;
   collected[id]!.add(WaffraOilPoint(day,price));
  }
  final result=<String,WaffraOilQuote>{};
  for(final pair in <String,String>{'RBRTE':'BRENT','RWTC':'WTI'}.entries){
   final raw=collected[pair.key]!;
   if(raw.isEmpty)continue;
   final byDay=<String,WaffraOilPoint>{};
   for(final p in raw)byDay[p.date.toIso8601String()]=p;
   final ordered=byDay.values.toList()..sort((a,b)=>a.date.compareTo(b.date));
   result[pair.value]=WaffraOilQuote(pair.value,List.unmodifiable(
    ordered.length>14?ordered.sublist(ordered.length-14):ordered));
  }
  return result;
 }
 /// EIA Henry Hub gas spot is on the NATURAL GAS route, not petroleum.
 /// Units are USD per MMBtu, never USD per crude barrel.
 static WaffraOilQuote? parseEiaGas(Map<String,dynamic> json){
  final response=json['response'];
  if(response is! Map||response['data'] is! List){
   throw const FormatException('Invalid EIA Henry Hub payload');
  }
  final byDay=<String,WaffraOilPoint>{};
  for(final row in response['data'] as List){
   if(row is! Map||row['series']?.toString()!='RNGWHHD')continue;
   final units=row['units']?.toString().toLowerCase()??'';
   if(units.isNotEmpty &&
    !(units.contains('mmbtu')||(units.contains('million')&&units.contains('btu'))))continue;
   final period=DateTime.tryParse(row['period']?.toString()??'');
   final price=double.tryParse(row['value']?.toString()??'');
   if(period==null||price==null||!price.isFinite||
    price<=0||price>=10000)continue;
   final day=DateTime.utc(period.year,period.month,period.day);
   if(day.isAfter(DateTime.now().toUtc().add(const Duration(days:1))))continue;
   byDay[day.toIso8601String()]=WaffraOilPoint(day,price);
  }
  if(byDay.isEmpty)return null;
  final values=byDay.values.toList()..sort((a,b)=>a.date.compareTo(b.date));
  return WaffraOilQuote('GAS',List.unmodifiable(
   values.length>14?values.sublist(values.length-14):values));
 }


 /// EIA also publishes the same official DAILY spot series as public
 /// HTML tables without an API key. FRED CSV may return HTTP 403 on mobile.
 /// Do not substitute futures, estimates or rates from another commodity.
 static WaffraOilQuote? parseEiaDailyHtml(String benchmark,String html){
  const headings=<String,String>{
   'BRENT':'Europe Brent Spot Price FOB',
   'WTI':'Cushing, OK WTI Spot Price FOB',
   'GAS':'Henry Hub Natural Gas Spot Price',
  };
  final heading=headings[benchmark];
  final unit=benchmark=='GAS'?'Dollars per Million Btu':'Dollars per Barrel';
  if(heading==null||!html.contains(heading)||!html.contains(unit)||
   !html.contains('Week Of')){
   throw const FormatException('Unexpected official EIA daily table/units');
  }
  final months=<String,int>{
   'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,
   'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12,
  };
  final week=RegExp(
   r'(\d{4})\s+([A-Za-z]{3})\s*-\s*(\d{1,2})\s+to\s+'
   r'([A-Za-z]{3})\s*-\s*(\d{1,2})');
  final rowPattern=RegExp(r'<tr\b[^>]*>(.*?)</tr\s*>',
   caseSensitive:false,dotAll:true);
  final cellPattern=RegExp(r'<t[dh]\b[^>]*>(.*?)</t[dh]\s*>',
   caseSensitive:false,dotAll:true);
  final tags=RegExp(r'<[^>]*>');
  final nbsp=RegExp(r'&(?:nbsp|#160|#xA0);',caseSensitive:false);
  final points=<String,WaffraOilPoint>{};
  for(final row in rowPattern.allMatches(html)){
   final cells=cellPattern.allMatches(row.group(1)!).map((m)=>
    m.group(1)!.replaceAll(tags,' ').replaceAll(nbsp,' ')
      .replaceAll(RegExp(r'\s+'),' ').trim()).toList();
   if(cells.length!=6)continue;
   final match=week.firstMatch(cells[0]);
   if(match==null)continue;
   final year=int.parse(match.group(1)!);
   final month=months[match.group(2)];
   final day=int.parse(match.group(3)!);
   final endMonth=months[match.group(4)];
   final endDay=int.parse(match.group(5)!);
   if(month==null||endMonth==null)continue;
   final monday=DateTime.utc(year,month,day);
   final friday=DateTime.utc(year+(endMonth<month?1:0),endMonth,endDay);
   if(monday.year!=year||monday.month!=month||monday.day!=day||
    monday.weekday!=DateTime.monday||friday.difference(monday).inDays!=4){
    continue;
   }
   for(var i=1;i<=5;i++){
    final price=double.tryParse(cells[i]);
    if(price==null||!price.isFinite||price<=0||price>=10000)continue;
    final date=monday.add(Duration(days:i-1));
    if(date.isAfter(DateTime.now().toUtc().add(const Duration(days:1))))continue;
    points[date.toIso8601String()]=WaffraOilPoint(date,price);
   }
  }
  if(points.isEmpty)return null;
  final ordered=points.values.toList()..sort((a,b)=>a.date.compareTo(b.date));
  return WaffraOilQuote(benchmark,List.unmodifiable(
   ordered.length>14?ordered.sublist(ordered.length-14):ordered));
 }

 Future<Map<String,WaffraOilQuote>> _fetchEiaPublicPages(http.Client api)async{
  const paths=<String,String>{
   'BRENT':'/dnav/pet/hist/RBRTEd.htm',
   'WTI':'/dnav/pet/hist/RWTCd.htm',
   'GAS':'/dnav/ng/hist/RNGWHHDD.htm',
  };
  final results=<String,WaffraOilQuote>{};
  await Future.wait(paths.entries.map((entry)async{
   try{
    final response=await api.get(
     Uri.https('www.eia.gov',entry.value),
     headers:const {'Accept':'text/html',
      'User-Agent':'Waffra/3.4 (public EIA spot-price reader)'},
    ).timeout(const Duration(seconds:12));
    if(response.statusCode!=200||response.bodyBytes.length>4000000){
     return;
    }
    final quote=parseEiaDailyHtml(entry.key,response.body);
    if(quote!=null&&!quote.isOld(DateTime.now())){
     results[entry.key]=quote;
    }
   }catch(_){
    // Another independent spot source may still work; never invent a quote.
   }
  }));
  return results;
 }

 Future<Map<String,WaffraOilQuote>> _fetchPublicSources(http.Client api)async{
  // Prefer EIA's own daily pages: no key and no FRED CSV anti-bot 403.
  final prices=await _fetchEiaPublicPages(api);
  if(prices.length==3)return prices;
  try{
   final fred=await _fetchFred(api);
   for(final item in fred.entries){
    // Do not let a later mirror overwrite an authenticated EIA observation.
    if(!item.value.isOld(DateTime.now()))prices.putIfAbsent(item.key,()=>item.value);
   }
  }catch(_){
   // A failed FRED public CSV must not hide valid official EIA readings.
  }
  if(prices.isEmpty){
   throw StateError('Official EIA daily pages and FRED CSV unavailable');
  }
  return prices;
 }

 Future<Map<String,WaffraOilQuote>> _fetchFred(http.Client api)async {
  final start=DateTime.now().toUtc().subtract(const Duration(days:55));
  final date='${start.year.toString().padLeft(4,'0')}-'
   '${start.month.toString().padLeft(2,'0')}-'
   '${start.day.toString().padLeft(2,'0')}';
  final results=<String,WaffraOilQuote>{};
  final series=<String,String>{
   'DCOILBRENTEU':'BRENT',
   'DCOILWTICO':'WTI',
   'DHHNGSP':'GAS',
  };
  final failures=<String>[];
  await Future.wait(series.entries.map((entry)async{
   try{
    final uri=Uri.https('fred.stlouisfed.org','/graph/fredgraph.csv',{
     'id':entry.key,'cosd':date,
    });
    final response=await api.get(uri).timeout(const Duration(seconds:14));
    if(response.statusCode!=200||response.bodyBytes.length>512000) {
     throw StateError('Public FRED commodity download unavailable');
    }
    final quote=parseFredCsv(entry.key,entry.value,response.body);
    if(quote!=null)results[entry.value]=quote;
   }catch(error){
    // Preserve diagnostic categories; never log a key or full URL.
    failures.add('${entry.value}: ${error is StateError ? 'HTTP response unavailable' : error is TimeoutException ? 'request timed out' : error is FormatException ? 'unexpected source data' : 'network or source error'}');
   }
  }));
  if(results.isEmpty){
   throw StateError('FRED daily spot prices could not be verified: ${failures.join('; ')}');
  }
  return results;
 }

 /// Validate one source-named FRED CSV series, including missing days as ".".
 /// Only the latest 14 *actual* observations are kept for sparklines.
 static WaffraOilQuote? parseFredCsv(
  String seriesId,String benchmark,String csv){
  if(!const {'DCOILBRENTEU','DCOILWTICO','DHHNGSP'}.contains(seriesId)) {
   throw const FormatException('Unsupported source series');
  }
  final rows=const LineSplitter().convert(csv.trim());
  if(rows.isEmpty||rows.length>2000){
   throw const FormatException('Unexpected FRED CSV row count');
  }
  final headers=rows.first.trim().split(',');
  if(headers.length!=2||
   !const {'observation_date','DATE'}.contains(headers[0])||
   headers[1].trim()!=seriesId){
   throw const FormatException('Incorrect FRED source/units');
  }
  final values=<String,WaffraOilPoint>{};
  for(final line in rows.skip(1)){
   final fields=line.trim().split(',');
   if(fields.length!=2)continue;
   final day=DateTime.tryParse(fields[0]);
   final number=double.tryParse(fields[1]);
   if(day==null||number==null||!number.isFinite||
     number<=0||number>=10000)continue;
   final date=DateTime.utc(day.year,day.month,day.day);
   if(date.isAfter(DateTime.now().toUtc().add(const Duration(days:1))))continue;
   values[date.toIso8601String()]=WaffraOilPoint(date,number);
  }
  if(values.isEmpty)return null;
  final points=values.values.toList()..sort((a,b)=>a.date.compareTo(b.date));
  return WaffraOilQuote(benchmark,List.unmodifiable(
   points.length>14?points.sublist(points.length-14):points));
 }

 Future<Map<String,WaffraOilQuote>> fetch({http.Client? client})async{
  final owns=client==null,api=client??http.Client();
  try{
   // FRED republishes official EIA spot observations as public CSV files.
   // Unlike the registered EIA API, this download does not require a key.
   // Fetch each series independently; one unavailable feed cannot invent or
   // overwrite prices for the other benchmarks.
   if(publicEiaKey.trim().isEmpty)return await _fetchPublicSources(api);
   final uri=Uri.https('api.eia.gov','/v2/petroleum/pri/spt/data/',{
    'api_key':publicEiaKey,'frequency':'daily','data[0]':'value',
    'facets[series][]':['RBRTE','RWTC'],
    'sort[0][column]':'period','sort[0][direction]':'desc',
    'offset':'0','length':'45',
   });
   final response=await api.get(uri).timeout(const Duration(seconds:14));
   if(response.statusCode!=200){
    // Registered EIA service may be temporarily unavailable; use verified
    // public FRED observations instead, without substituting sample prices.
    return await _fetchPublicSources(api);
   }
   final decoded=jsonDecode(response.body);
   if(decoded is! Map<String,dynamic>)throw const FormatException('Invalid EIA JSON');
   final quotes=parse(decoded);
   if(quotes.isEmpty)throw const FormatException('No valid spot quotes');
   // Fetch independently: a missing Henry Hub quote must not suppress valid
   // Brent/WTI prices, and must never be filled using another benchmark.
   try{
    final gasUri=Uri.https('api.eia.gov','/v2/natural-gas/pri/fut/data/',{
     'api_key':publicEiaKey,'frequency':'daily','data[0]':'value',
     'facets[series][]':'RNGWHHD',
     'sort[0][column]':'period','sort[0][direction]':'desc',
     'offset':'0','length':'30',
    });
    final gasResponse=await api.get(gasUri).timeout(const Duration(seconds:8));
    if(gasResponse.statusCode==200&&gasResponse.bodyBytes.length<=512000){
     final gasData=jsonDecode(gasResponse.body);
     if(gasData is Map<String,dynamic>){
      final gas=parseEiaGas(gasData);
      if(gas!=null)quotes['GAS']=gas;
     }
    }
   }catch(_){
    // A failed optional gas feed must never block verified crude prices.
   }
   return quotes;
  }finally{if(owns)api.close();}
 }
}

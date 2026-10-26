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
/// Oman/Dubai/Gas remain explicitly unavailable without verified feeds.
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
   if(publicEiaKey.trim().isEmpty)return await _fetchFred(api);
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
    return await _fetchFred(api);
   }
   final decoded=jsonDecode(response.body);
   if(decoded is! Map<String,dynamic>)throw const FormatException('Invalid EIA JSON');
   final quotes=parse(decoded);
   if(quotes.isEmpty)throw const FormatException('No valid spot quotes');
   return quotes;
  }finally{if(owns)api.close();}
 }
}

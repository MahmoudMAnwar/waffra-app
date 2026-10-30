import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Country chooses a PRESENTATION UNIT ONLY. Numbers are unchanged (e.g.,
/// 1,000 SAR is shown as 1,000 EGP when EGP is selected). This is NOT FX.
/// The separate currency converter quotes genuine market exchange rates.
class WaffraCountryCurrency {
  const WaffraCountryCurrency(this.countryAr,this.countryEn,this.code,
      this.nameAr,this.nameEn,this.symbolAr);
  final String countryAr,countryEn,code,nameAr,nameEn,symbolAr;
  String label(bool english)=>english
      ?'$countryEn · $nameEn ($code)'
      :'$countryAr · $nameAr ($code)';
}

const waffraCountryCurrencies=<WaffraCountryCurrency>[
 WaffraCountryCurrency('السعودية','Saudi Arabia','SAR','ريال سعودي','Saudi riyal','ريال'),
 WaffraCountryCurrency('مصر','Egypt','EGP','جنيه مصري','Egyptian pound','ج.م'),
 WaffraCountryCurrency('الإمارات','United Arab Emirates','AED','درهم إماراتي','UAE dirham','د.إ'),
 WaffraCountryCurrency('الكويت','Kuwait','KWD','دينار كويتي','Kuwaiti dinar','د.ك'),
 WaffraCountryCurrency('البحرين','Bahrain','BHD','دينار بحريني','Bahraini dinar','د.ب'),
 WaffraCountryCurrency('قطر','Qatar','QAR','ريال قطري','Qatari riyal','ر.ق'),
 WaffraCountryCurrency('عمان','Oman','OMR','ريال عماني','Omani riyal','ر.ع'),
 WaffraCountryCurrency('الأردن','Jordan','JOD','دينار أردني','Jordanian dinar','د.أ'),
 WaffraCountryCurrency('العراق','Iraq','IQD','دينار عراقي','Iraqi dinar','د.ع'),
 WaffraCountryCurrency('لبنان','Lebanon','LBP','ليرة لبنانية','Lebanese pound','ل.ل'),
 WaffraCountryCurrency('المغرب','Morocco','MAD','درهم مغربي','Moroccan dirham','د.م'),
 WaffraCountryCurrency('الجزائر','Algeria','DZD','دينار جزائري','Algerian dinar','د.ج'),
 WaffraCountryCurrency('تونس','Tunisia','TND','دينار تونسي','Tunisian dinar','د.ت'),
 WaffraCountryCurrency('الولايات المتحدة','United States','USD','دولار أمريكي','US dollar','USD'),
 WaffraCountryCurrency('منطقة اليورو','Euro area','EUR','يورو','Euro','€'),
 WaffraCountryCurrency('المملكة المتحدة','United Kingdom','GBP','جنيه إسترليني','Pound sterling','£'),
 WaffraCountryCurrency('تركيا','Türkiye','TRY','ليرة تركية','Turkish lira','₺'),
 WaffraCountryCurrency('الهند','India','INR','روبية هندية','Indian rupee','₹'),
 WaffraCountryCurrency('باكستان','Pakistan','PKR','روبية باكستانية','Pakistani rupee','₨'),
 WaffraCountryCurrency('بنغلاديش','Bangladesh','BDT','تاكا بنغلاديشي','Bangladeshi taka','৳'),
 WaffraCountryCurrency('اليابان','Japan','JPY','ين ياباني','Japanese yen','¥'),
 WaffraCountryCurrency('الصين','China','CNY','يوان صيني','Chinese yuan','¥'),
 WaffraCountryCurrency('كندا','Canada','CAD','دولار كندي','Canadian dollar','CAD'),
 WaffraCountryCurrency('أستراليا','Australia','AUD','دولار أسترالي','Australian dollar','AUD'),
 WaffraCountryCurrency('سويسرا','Switzerland','CHF','فرنك سويسري','Swiss franc','CHF'),
 WaffraCountryCurrency('السويد','Sweden','SEK','كرونة سويدية','Swedish krona','SEK'),
 WaffraCountryCurrency('النرويج','Norway','NOK','كرونة نرويجية','Norwegian krone','NOK'),
 WaffraCountryCurrency('الدنمارك','Denmark','DKK','كرونة دنماركية','Danish krone','DKK'),
 WaffraCountryCurrency('جنوب أفريقيا','South Africa','ZAR','راند جنوب أفريقي','South African rand','R'),
 WaffraCountryCurrency('سنغافورة','Singapore','SGD','دولار سنغافوري','Singapore dollar','SGD'),
 WaffraCountryCurrency('هونغ كونغ','Hong Kong','HKD','دولار هونغ كونغ','Hong Kong dollar','HKD'),
 WaffraCountryCurrency('ماليزيا','Malaysia','MYR','رينغيت ماليزي','Malaysian ringgit','RM'),
 WaffraCountryCurrency('إندونيسيا','Indonesia','IDR','روبية إندونيسية','Indonesian rupiah','Rp'),
 WaffraCountryCurrency('كوريا الجنوبية','South Korea','KRW','وون كوري','South Korean won','₩'),
 WaffraCountryCurrency('تايلاند','Thailand','THB','بات تايلندي','Thai baht','฿'),
 WaffraCountryCurrency('الفلبين','Philippines','PHP','بيزو فلبيني','Philippine peso','₱'),
];

WaffraCountryCurrency waffraCountry(String code) =>
 waffraCountryCurrencies.firstWhere((c)=>c.code==code,
   orElse:()=>waffraCountryCurrencies.first);

class WaffraVerifiedDisplayQuote {
 const WaffraVerifiedDisplayQuote({
  required this.code,required this.sarToSelected,
  required this.updatedAtUtc,required this.provider,
 });
 final String code,provider;
 final double? sarToSelected;
 final DateTime? updatedAtUtc;
 // Display-only selection is a unit preference, not an exchange-rate quote.
 // No FX timestamp or connection is required to rename the presentation unit.
 bool get displayOnly => provider=='display-only';
 bool get verified => displayOnly || code=='SAR'||(sarToSelected!=null&&
   sarToSelected!.isFinite&&sarToSelected!>0&&updatedAtUtc!=null);
 double? fromSar(num amount){
  if(!amount.toDouble().isFinite)return null;
  if(code=='SAR'||displayOnly)return amount.toDouble();
  final rate=sarToSelected;
  return verified&&rate!=null?amount.toDouble()*rate:null;
 }
 double? toSar(num amount){
  if(!amount.toDouble().isFinite)return null;
  if(code=='SAR'||displayOnly)return amount.toDouble();
  final rate=sarToSelected;
  return verified&&rate!=null?amount.toDouble()/rate:null;
 }
}

class WaffraDisplayCurrency {
 static const _preferenceKey='waffra_display_country_currency_v1';
 // True only when a currency preference has actually been persisted.
 // GPS suggestions cannot displace a previously approved preference.
 static bool hasSavedPreference=false;
 static const _freshness=Duration(days:7);
 static final ValueNotifier<WaffraVerifiedDisplayQuote> active=
  ValueNotifier<WaffraVerifiedDisplayQuote>(
   const WaffraVerifiedDisplayQuote(code:'SAR',sarToSelected:1,
     updatedAtUtc:null,provider:'display-only'));
 static WaffraCountryCurrency get country=>waffraCountry(active.value.code);
 static String label(bool english)=>english?country.code:country.symbolAr;
 static double? convert(num sar)=>active.value.fromSar(sar);
 static double? toLedgerSar(num selected)=>active.value.toSar(selected);
 static String amount(num sar) {
  final converted=convert(sar);
  if(converted==null)return '—';
  final fixed=converted.toStringAsFixed(2).split('.');
  return '${fixed.first.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(_)=>',')}.${fixed.last}';
 }
 static String money(num sar,{required bool english}) =>
  '${amount(sar)} ${label(english)}';

 static DateTime _parseVerifiedTime(DateTime parsed,DateTime clock){
  final at=parsed.toUtc();
  if(at.isAfter(clock.add(const Duration(hours:1)))||
     clock.difference(at)>_freshness){
   throw const FormatException('Exchange-rate timestamp is not current.');
  }
  return at;
 }
 static WaffraVerifiedDisplayQuote primaryRate(
   Map<String,dynamic> data,String code,{DateTime? now}){
  if(data['result']!='success'||data['rates'] is! Map){
   throw const FormatException('FX source has no verified rates.');
  }
  final base=(data['rates'] as Map)['SAR'];
  final selected=(data['rates'] as Map)[code];
  if(base is! num||selected is! num||
     !base.toDouble().isFinite||!selected.toDouble().isFinite||
     base<=0||selected<=0||base.toDouble()>10000000||
     selected.toDouble()>10000000){
   throw const FormatException('Invalid SAR currency quote.');
  }
  final timestamp=data['time_last_update_unix'];
  if(timestamp is! num){
   throw const FormatException('Missing original FX source timestamp.');
  }
  final at=_parseVerifiedTime(DateTime.fromMillisecondsSinceEpoch(
    timestamp.toInt()*1000,isUtc:true),(now??DateTime.now()).toUtc());
  return WaffraVerifiedDisplayQuote(code:code,
   sarToSelected:selected.toDouble()/base.toDouble(),
   updatedAtUtc:at,provider:'ExchangeRate-API');
 }

 static WaffraVerifiedDisplayQuote backupRate(
   Map<String,dynamic> data,String code,{DateTime? now}){
  final rates=data['sar'];
  final date=data['date'];
  if(rates is! Map||date is! String||
     !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)){
   throw const FormatException('Independent FX response is invalid.');
  }
  final quote=rates[code.toLowerCase()];
  if(quote is! num||!quote.toDouble().isFinite||
     quote<=0||quote>10000000){
   throw const FormatException('No usable independent FX quote.');
  }
  final parsed=DateTime.tryParse('${date}T00:00:00Z');
  if(parsed==null)throw const FormatException('Invalid FX publication day.');
  return WaffraVerifiedDisplayQuote(code:code,
   sarToSelected:quote.toDouble(),
   updatedAtUtc:_parseVerifiedTime(parsed,(now??DateTime.now()).toUtc()),
   provider:'Independent FX');
 }

 static Future<WaffraVerifiedDisplayQuote> fetch(String code,
   {http.Client? client,DateTime? now})async{
  if(code=='SAR')return const WaffraVerifiedDisplayQuote(
   code:'SAR',sarToSelected:1,updatedAtUtc:null,provider:'base');
  if(!waffraCountryCurrencies.any((c)=>c.code==code)){
   throw const FormatException('Unsupported currency country.');
  }
  final api=client??http.Client();
  try{
   try{
    final response=await api.get(
     Uri.https('open.er-api.com','/v6/latest/USD'))
      .timeout(const Duration(seconds:12));
    if(response.statusCode!=200||response.bodyBytes.length>131072){
     throw const HttpException('Primary FX unavailable.');
    }
    final json=jsonDecode(utf8.decode(response.bodyBytes));
    if(json is! Map<String,dynamic>){
     throw const FormatException('Invalid primary FX payload.');
    }
    return primaryRate(json,code,now:now);
   }catch(_){
    final response=await api.get(Uri.https('cdn.jsdelivr.net',
     '/npm/@fawazahmed0/currency-api@latest/v1/currencies/sar.json'))
     .timeout(const Duration(seconds:12));
    if(response.statusCode!=200||response.bodyBytes.length>131072){
     throw const HttpException('Independent FX unavailable.');
    }
    final json=jsonDecode(utf8.decode(response.bodyBytes));
    if(json is! Map<String,dynamic>){
     throw const FormatException('Invalid independent FX payload.');
    }
    return backupRate(json,code,now:now);
   }
  }finally{if(client==null)api.close();}
 }
 // A country preference NEVER exchanges financial amounts. The separate
 // CurrencyConverterPage and gold calculator still use genuine market FX.
 // Keep this signature for existing settings callers; no HTTP request is made.
 static WaffraVerifiedDisplayQuote displaySelection(String code) {
  if (!waffraCountryCurrencies.any((item) => item.code == code)) {
   throw const FormatException('Unsupported currency country.');
  }
  return WaffraVerifiedDisplayQuote(
   code: code, sarToSelected: 1, updatedAtUtc: null,
   provider: 'display-only');
 }
 static Future<void> setCurrency(String code,{http.Client? client})async{
  final quote=displaySelection(code);
  final p=await SharedPreferences.getInstance();
  if(!await p.setString(_preferenceKey,code)){
   throw StateError('Currency preference was not stored.');
  }
  active.value=quote;
  hasSavedPreference=true;
 }
 static Future<void> initialize({http.Client? client})async{
  final p=await SharedPreferences.getInstance();
  final saved=p.getString(_preferenceKey)??'SAR';
  hasSavedPreference=p.containsKey(_preferenceKey)&&
    waffraCountryCurrencies.any((item)=>item.code==saved);
  active.value=displaySelection(
   waffraCountryCurrencies.any((item)=>item.code==saved)?saved:'SAR');
 }
 static Future<void> refresh({http.Client? client})async{
  // Presentation is independent of the network and never goes stale.
  // Real FX fetching is deliberately isolated in CurrencyConverterPage.
 }
}

import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'waffra_amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'waffra_i18n.dart';

class CurrencyConverterPage extends StatefulWidget {
 const CurrencyConverterPage({super.key,this.lastIncomeAmount});
 final double? lastIncomeAmount;
 @override State<CurrencyConverterPage> createState()=>_CurrencyConverterPageState();
}
class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
 late final TextEditingController amount;
 final currencyEnglish=const {'SAR':'Saudi riyal','EGP':'Egyptian pound','USD':'US dollar','AED':'UAE dirham','KWD':'Kuwaiti dinar','EUR':'Euro','GBP':'British pound','BHD':'Bahraini dinar','QAR':'Qatari riyal','OMR':'Omani riyal'};
 final currencies=const {'SAR':'ريال سعودي','EGP':'جنيه مصري','USD':'دولار أمريكي',
  'AED':'درهم إماراتي','KWD':'دينار كويتي','EUR':'يورو','GBP':'جنيه إسترليني',
  'BHD':'دينار بحريني','QAR':'ريال قطري','OMR':'ريال عُماني'};
 String from='SAR',status='';
 String? to;
 double? result,rate;
 bool busy=false;
 DateTime? updated;
 @override void initState(){super.initState();amount=TextEditingController(text:widget.lastIncomeAmount==null?'':formatWaffraMoney(widget.lastIncomeAmount!));}
 @override void dispose(){amount.dispose();super.dispose();}
 Future<void> convert()async {
  if(to==null){setState(()=>status='اختر العملة المراد التحويل إليها');return;}
  final input=double.tryParse(amount.text.trim().replaceAll(',',''));
  if(input==null||!input.isFinite||input<0){setState(()=>status='اكتب مبلغ صحيح عشان نحسبه');return;}
  setState((){busy=true;status='';result=null;rate=null;updated=null;});
  try{
   if(from==to){
    if(mounted)setState((){rate=1;result=input;updated=DateTime.now();});
    return;
   }
   late double fetchedRate;
   DateTime? fetchedAt;
   try{
    final response=await http.get(Uri.parse('https://open.er-api.com/v6/latest/$from'))
     .timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw HttpException('Primary service HTTP ${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    if(data['result']!='success'||data['rates'] is! Map)throw const FormatException('Primary rates missing');
    final r=(data['rates'] as Map)[to];
    if(r is! num||r.toDouble()<=0)throw const FormatException('Currency unavailable');
    fetchedRate=r.toDouble();
    fetchedAt=data['time_last_update_unix'] is num
     ?DateTime.fromMillisecondsSinceEpoch((data['time_last_update_unix'] as num).toInt()*1000).toLocal():null;
   }catch(primaryError){
    // A second independent rate provider keeps conversion usable during
    // a primary API outage. Never silently use a fabricated exchange rate.
    debugPrint('Primary exchange-rate provider failed: $primaryError');
    final response=await http.get(Uri.parse(
     'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${from.toLowerCase()}.json'))
     .timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw HttpException('Backup service HTTP ${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    final quotes=data[from.toLowerCase()];
    if(quotes is! Map)throw const FormatException('Backup rates missing');
    final r=quotes[to!.toLowerCase()];
    if(r is! num||r.toDouble()<=0)throw const FormatException('Currency unavailable');
    fetchedRate=r.toDouble();
    fetchedAt=DateTime.tryParse('${data['date']??''}');
   }
   if(!mounted)return;
   setState((){rate=fetchedRate;result=input*fetchedRate;updated=fetchedAt;});
  }on TimeoutException {
   if(mounted)setState(()=>status=waffraIsEnglish
    ?'Exchange-rate services timed out. Please retry.'
    :'انتهت مهلة الاتصال بخدمات أسعار الصرف. حاول مرة أخرى.');
  }on SocketException {
   if(mounted)setState(()=>status=waffraIsEnglish
    ?'Unable to reach exchange-rate services. Check your connection and retry.'
    :'تعذر الاتصال بخدمات أسعار الصرف. تحقق من الشبكة وحاول مرة أخرى.');
  }catch(e){
   debugPrint('Both exchange-rate sources failed: $e');
   if(mounted)setState(()=>status=waffraIsEnglish
    ?'Exchange-rate services are temporarily unavailable. Try again later.'
    :'خدمات أسعار الصرف غير متاحة حاليًا. حاول مرة أخرى لاحقًا.');
  }finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const WaffraText('تحويل العملات')),
  body:ListView(padding:const EdgeInsets.all(20),children:[
   const WaffraText('اعرف قيمة راتبك أو أي مبلغ بعملة ثانية، حسب أحدث سعر متاح.'),
   const SizedBox(height:18),
   TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    inputFormatters:[const WaffraAmountFormatter()],
    decoration:InputDecoration(labelText:waffraTr('المبلغ'),border:OutlineInputBorder())),
   const SizedBox(height:14),
   DropdownButtonFormField<String>(initialValue:from,
    decoration:InputDecoration(labelText:waffraTr('من عملة'),border:OutlineInputBorder()),
    items:currencies.entries.map((e)=>DropdownMenuItem(value:e.key,child:WaffraText('${waffraIsEnglish?currencyEnglish[e.key]:e.value} (${e.key})'))).toList(),
    onChanged:(v){if(v!=null)setState(()=>from=v);}),
   const SizedBox(height:14),
   DropdownButtonFormField<String>(initialValue:to,
    hint:const WaffraText('اختر العملة'),
    decoration:InputDecoration(labelText:waffraTr('إلى عملة'),border:OutlineInputBorder()),
    items:currencies.entries.map((e)=>DropdownMenuItem(value:e.key,child:WaffraText('${waffraIsEnglish?currencyEnglish[e.key]:e.value} (${e.key})'))).toList(),
    onChanged:(v){setState(()=>to=v);}),
   const SizedBox(height:20),
   FilledButton.icon(onPressed:busy?null:convert,
    icon:const Icon(Icons.currency_exchange),label:WaffraText(busy?'جاري جلب السعر...':'حوّل الحين')),
   if(busy)const Padding(padding:EdgeInsets.only(top:14),child:LinearProgressIndicator()),
   if(status.isNotEmpty)Padding(padding:const EdgeInsets.only(top:16),
    child:WaffraText(status,style:TextStyle(color:Theme.of(context).colorScheme.error))),
   if(result!=null)...[
    const SizedBox(height:24),
    Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
     const WaffraText('المبلغ بعد التحويل'),
     const SizedBox(height:8),
     WaffraText('${formatWaffraMoney(result!)} $to',
      style:Theme.of(context).textTheme.headlineMedium),
     const SizedBox(height:8),
     WaffraText('1 $from = ${rate!.toStringAsFixed(4)} $to'),
     if(updated!=null)WaffraText('آخر تحديث متاح: ${updated!.day}/${updated!.month}/${updated!.year}'),
    ]))),
   ],
   const SizedBox(height:20),
   const WaffraText('المصدر: ExchangeRate-API أو مزود احتياطي عند تعذّر الاتصال. الأسعار استرشادية وقد تختلف عن أسعار البنوك أو التحويل الفعلي.',
    style:TextStyle(fontSize:12)),
  ]));
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CurrencyConverterPage extends StatefulWidget {
 const CurrencyConverterPage({super.key});
 @override State<CurrencyConverterPage> createState()=>_CurrencyConverterPageState();
}
class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
 final amount=TextEditingController(text:'1000');
 final currencies=const {'SAR':'ريال سعودي','EGP':'جنيه مصري','USD':'دولار أمريكي',
  'AED':'درهم إماراتي','KWD':'دينار كويتي','EUR':'يورو','GBP':'جنيه إسترليني',
  'BHD':'دينار بحريني','QAR':'ريال قطري','OMR':'ريال عُماني'};
 String from='SAR',to='EGP',status='';
 double? result,rate;
 bool busy=false;
 DateTime? updated;
 @override void initState(){super.initState();convert();}
 @override void dispose(){amount.dispose();super.dispose();}
 Future<void> convert()async {
  final input=double.tryParse(amount.text.trim().replaceAll(',',''));
  if(input==null||!input.isFinite||input<0){setState(()=>status='اكتب مبلغ صحيح عشان نحسبه');return;}
  setState((){busy=true;status='';result=null;});
  try{
   if(from==to){if(mounted)setState((){rate=1;result=input;updated=DateTime.now();});return;}
   final response=await http.get(Uri.parse('https://open.er-api.com/v6/latest/$from'))
    .timeout(const Duration(seconds:12));
   if(response.statusCode!=200)throw Exception('HTTP ${response.statusCode}');
   final data=jsonDecode(response.body) as Map<String,dynamic>;
   if(data['result']!='success')throw Exception('Rate unavailable');
   final r=(data['rates'] as Map<String,dynamic>)[to];
   if(r is! num)throw Exception('Currency unavailable');
   if(!mounted)return;
   setState((){
    rate=r.toDouble();result=input*rate!;
    updated=data['time_last_update_unix'] is num
     ?DateTime.fromMillisecondsSinceEpoch((data['time_last_update_unix'] as num).toInt()*1000).toLocal()
     :null;
   });
  }catch(_){if(mounted)setState(()=>status='ما قدرنا نجيب سعر الصرف الحين. تأكد من الإنترنت وجرّب مرة ثانية.');}
  finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(
  appBar:AppBar(title:const Text('تحويل العملات')),
  body:ListView(padding:const EdgeInsets.all(20),children:[
   const Text('اعرف قيمة راتبك أو أي مبلغ بعملة ثانية، حسب أحدث سعر متاح.'),
   const SizedBox(height:18),
   TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    decoration:const InputDecoration(labelText:'المبلغ',border:OutlineInputBorder())),
   const SizedBox(height:14),
   DropdownButtonFormField<String>(initialValue:from,
    decoration:const InputDecoration(labelText:'من عملة',border:OutlineInputBorder()),
    items:currencies.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${e.value} (${e.key})'))).toList(),
    onChanged:(v){if(v!=null)setState(()=>from=v);}),
   const SizedBox(height:14),
   DropdownButtonFormField<String>(initialValue:to,
    decoration:const InputDecoration(labelText:'إلى عملة',border:OutlineInputBorder()),
    items:currencies.entries.map((e)=>DropdownMenuItem(value:e.key,child:Text('${e.value} (${e.key})'))).toList(),
    onChanged:(v){if(v!=null)setState(()=>to=v);}),
   const SizedBox(height:20),
   FilledButton.icon(onPressed:busy?null:convert,
    icon:const Icon(Icons.currency_exchange),label:Text(busy?'جاري جلب السعر...':'حوّل الحين')),
   if(busy)const Padding(padding:EdgeInsets.only(top:14),child:LinearProgressIndicator()),
   if(status.isNotEmpty)Padding(padding:const EdgeInsets.only(top:16),
    child:Text(status,style:TextStyle(color:Theme.of(context).colorScheme.error))),
   if(result!=null)...[
    const SizedBox(height:24),
    Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
     const Text('المبلغ بعد التحويل'),
     const SizedBox(height:8),
     Text('${result!.toStringAsFixed(2)} $to',
      style:Theme.of(context).textTheme.headlineMedium),
     const SizedBox(height:8),
     Text('1 $from = ${rate!.toStringAsFixed(4)} $to'),
     if(updated!=null)Text('آخر تحديث متاح: ${updated!.day}/${updated!.month}/${updated!.year}'),
    ]))),
   ],
   const SizedBox(height:20),
   const Text('المصدر: ExchangeRate-API (open.er-api.com). الأسعار استرشادية وقد تختلف عن أسعار البنوك أو التحويل الفعلي.',
    style:TextStyle(fontSize:12)),
  ]));
}

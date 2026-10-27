import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'waffra_amount_formatter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'waffra_i18n.dart';
import 'waffra_search.dart';
import 'waffra_gold_market_section.dart';
import 'waffra_gold_calculator.dart';
import 'waffra_market_accordion.dart';
import 'waffra_oil_market_section.dart';

import 'waffra_haptic_feedback.dart';
/// Cosmetic country markers only. The converter itself uses verified FX.
/// EUR is a multi-country currency, so use a currency symbol rather than
/// pretending that it belongs to one nation.
const Map<String,String> waffraCurrencyFlags = <String,String>{
 'SAR':'🇸🇦','EGP':'🇪🇬','USD':'🇺🇸','EUR':'💶','GBP':'🇬🇧',
 'AED':'🇦🇪','KWD':'🇰🇼','BHD':'🇧🇭','OMR':'🇴🇲','QAR':'🇶🇦',
 'JOD':'🇯🇴','TRY':'🇹🇷','INR':'🇮🇳','PKR':'🇵🇰','BDT':'🇧🇩',
 'JPY':'🇯🇵','CNY':'🇨🇳','CAD':'🇨🇦','AUD':'🇦🇺','CHF':'🇨🇭',
 'SEK':'🇸🇪','NOK':'🇳🇴','DKK':'🇩🇰','ZAR':'🇿🇦','SGD':'🇸🇬',
 'HKD':'🇭🇰','MYR':'🇲🇾','IDR':'🇮🇩','KRW':'🇰🇷','THB':'🇹🇭',
 'PHP':'🇵🇭','MAD':'🇲🇦','TND':'🇹🇳','DZD':'🇩🇿','IQD':'🇮🇶',
 'LBP':'🇱🇧',
};
String waffraCurrencyFlag(String code) => waffraCurrencyFlags[code] ?? '💱';

class CurrencyConverterPage extends StatefulWidget {
 const CurrencyConverterPage({super.key,this.lastIncomeAmount,this.embedded=false});
 final double? lastIncomeAmount;
 /// Render the same three market accordions directly inside Tools.
 final bool embedded;
 @override State<CurrencyConverterPage> createState()=>_CurrencyConverterPageState();
}
class _CurrencyConverterPageState extends State<CurrencyConverterPage> {
 late final TextEditingController amount;
 final Map<String,String> currencyEnglish=const {
  'SAR':'Saudi riyal',
  'EGP':'Egyptian pound',
  'USD':'US dollar',
  'EUR':'Euro',
  'GBP':'British pound',
  'AED':'UAE dirham',
  'KWD':'Kuwaiti dinar',
  'BHD':'Bahraini dinar',
  'OMR':'Omani riyal',
  'QAR':'Qatari riyal',
  'JOD':'Jordanian dinar',
  'TRY':'Turkish lira',
  'INR':'Indian rupee',
  'PKR':'Pakistani rupee',
  'BDT':'Bangladeshi taka',
  'JPY':'Japanese yen',
  'CNY':'Chinese yuan',
  'CAD':'Canadian dollar',
  'AUD':'Australian dollar',
  'CHF':'Swiss franc',
  'SEK':'Swedish krona',
  'NOK':'Norwegian krone',
  'DKK':'Danish krone',
  'ZAR':'South African rand',
  'SGD':'Singapore dollar',
  'HKD':'Hong Kong dollar',
  'MYR':'Malaysian ringgit',
  'IDR':'Indonesian rupiah',
  'KRW':'South Korean won',
  'THB':'Thai baht',
  'PHP':'Philippine peso',
  'MAD':'Moroccan dirham',
  'TND':'Tunisian dinar',
  'DZD':'Algerian dinar',
  'IQD':'Iraqi dinar',
  'LBP':'Lebanese pound',
 };
 final Map<String,String> currencies=const {
  'SAR':'ريال سعودي',
  'EGP':'جنيه مصري',
  'USD':'دولار أمريكي',
  'EUR':'يورو',
  'GBP':'جنيه إسترليني',
  'AED':'درهم إماراتي',
  'KWD':'دينار كويتي',
  'BHD':'دينار بحريني',
  'OMR':'ريال عُماني',
  'QAR':'ريال قطري',
  'JOD':'دينار أردني',
  'TRY':'ليرة تركية',
  'INR':'روبية هندية',
  'PKR':'روبية باكستانية',
  'BDT':'تاكا بنغلاديشي',
  'JPY':'ين ياباني',
  'CNY':'يوان صيني',
  'CAD':'دولار كندي',
  'AUD':'دولار أسترالي',
  'CHF':'فرنك سويسري',
  'SEK':'كرونة سويدية',
  'NOK':'كرونة نرويجية',
  'DKK':'كرونة دنماركية',
  'ZAR':'راند جنوب أفريقي',
  'SGD':'دولار سنغافوري',
  'HKD':'دولار هونغ كونغ',
  'MYR':'رينغيت ماليزي',
  'IDR':'روبية إندونيسية',
  'KRW':'وون كوري جنوبي',
  'THB':'بات تايلندي',
  'PHP':'بيزو فلبيني',
  'MAD':'درهم مغربي',
  'TND':'دينار تونسي',
  'DZD':'دينار جزائري',
  'IQD':'دينار عراقي',
  'LBP':'ليرة لبنانية',
 };
 String from='SAR',status='';
 String? to='EGP';
 int _quoteRevision=0;
 int _goldRefreshRevision=0;
 int _oilRefreshRevision=0;
 String? _openMarket='currency';
 final ScrollController _marketsScroll=ScrollController();
 void toggleMarket(String id)=>setState(()=>_openMarket=_openMarket==id?null:id);
 double? result,rate;
 bool busy=false;
 DateTime? updated;
 @override void initState(){super.initState();amount=TextEditingController(text:widget.lastIncomeAmount==null?'':formatWaffraMoney(widget.lastIncomeAmount!));}
 @override void dispose(){_marketsScroll.dispose();amount.dispose();super.dispose();}
 String currencyLabel(String code)=>'${waffraIsEnglish?currencyEnglish[code]:currencies[code]} ($code)';
 Widget _currencyChoice(String code){
  return Row(mainAxisSize:MainAxisSize.min,children:[
   Text(waffraCurrencyFlag(code),key:Key('waffra-currency-flag-$code'),
    style:const TextStyle(fontSize:25)),
   const SizedBox(width:7),
   Flexible(child:WaffraText(currencyLabel(code),
    textAlign:TextAlign.center,maxLines:2)),
  ]);
 }
 Future<void> selectCurrency(bool source)async {
  final filter=TextEditingController();
  String query='';
  try {
   final picked=await showDialog<String>(context:context,builder:(dialogContext)=>
    StatefulBuilder(builder:(dialogContext,refresh){
     final listed=currencies.keys.where((code){
      return waffraSearchAny([currencyEnglish[code]??'',currencies[code]??'',code],query);
     }).toList();
     return AlertDialog(
      title:WaffraText(source?(waffraIsEnglish?'From currency':'من عملة'):
       (waffraIsEnglish?'To currency':'إلى عملة')),
      content:SizedBox(width:420,height:420,child:Column(children:[
       TextField(controller:filter,autofocus:true,
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),
         hintText:waffraIsEnglish?'Search code or currency':'ابحث باسم العملة أو رمزها'),
        onChanged:(v)=>refresh(()=>query=v)),
       const SizedBox(height:8),
       Expanded(child:ListView.builder(itemCount:listed.length,itemBuilder:(ctx,index){
        final code=listed[index];
        return ListTile(
         leading:Text(waffraCurrencyFlag(code),
          style:const TextStyle(fontSize:28)),
         title:WaffraText(currencyLabel(code)),
         onTap:WaffraHaptics.tap(()=>Navigator.of(dialogContext).pop(code)),
        );
       })),
      ])),
      actions:[TextButton(onPressed:WaffraHaptics.tap(()=>Navigator.pop(dialogContext)),
       child:WaffraText(waffraIsEnglish?'Cancel':'إلغاء'))]);
    }));
   if(picked!=null&&mounted){
    ++_quoteRevision;
    setState((){
     if(source){from=picked;}else{to=picked;}
     rate=null;result=null;updated=null;status='';busy=false;
    });
   }
  }finally{filter.dispose();}
 }
 void swapCurrencies(){
  if(to==null)return;
  ++_quoteRevision;
  final previous=from;
  setState((){
   from=to!;
   to=previous;
   result=null;rate=null;updated=null;status='';busy=false;
  });
  // Keep the entered amount; fetch a NEW directional quote, never invert a
  // cached/stale rate or show a fabricated exchange rate.
  if(amount.text.trim().isNotEmpty)unawaited(convert());
 }
 Future<void> convert()async {
  final currentQuote=++_quoteRevision;
  final chosenFrom=from,chosenTo=to;
  if(chosenTo==null){setState(()=>status=waffraIsEnglish?'Choose the destination currency':'اختر العملة المراد التحويل إليها');return;}
  final input=double.tryParse(amount.text.trim().replaceAll(',',''));
  if(input==null||!input.isFinite||input<0){setState(()=>status='اكتب مبلغ صحيح عشان نحسبه');return;}
  setState((){busy=true;status='';result=null;rate=null;updated=null;});
  try{
   if(chosenFrom==chosenTo){
    if(mounted&&currentQuote==_quoteRevision)setState((){rate=1;result=input;updated=null;});
    return;
   }
   late double fetchedRate;
   DateTime? fetchedAt;
   try{
    final response=await http.get(Uri.parse('https://open.er-api.com/v6/latest/$chosenFrom'))
     .timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw HttpException('Primary service HTTP ${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    if(data['result']!='success'||data['rates'] is! Map)throw const FormatException('Primary rates missing');
    final r=(data['rates'] as Map)[chosenTo];
    if(r is! num||r.toDouble()<=0)throw const FormatException('Currency unavailable');
    fetchedRate=r.toDouble();
    fetchedAt=data['time_last_update_unix'] is num
     ?DateTime.fromMillisecondsSinceEpoch((data['time_last_update_unix'] as num).toInt()*1000).toLocal():null;
   }catch(primaryError){
    // A second independent rate provider keeps conversion usable during
    // a primary API outage. Never silently use a fabricated exchange rate.
    debugPrint('Primary exchange-rate provider failed: $primaryError');
    final response=await http.get(Uri.parse(
     'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/${chosenFrom.toLowerCase()}.json'))
     .timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw HttpException('Backup service HTTP ${response.statusCode}');
    final data=jsonDecode(response.body) as Map<String,dynamic>;
    final quotes=data[chosenFrom.toLowerCase()];
    if(quotes is! Map)throw const FormatException('Backup rates missing');
    final r=quotes[chosenTo.toLowerCase()];
    if(r is! num||r.toDouble()<=0)throw const FormatException('Currency unavailable');
    fetchedRate=r.toDouble();
    fetchedAt=DateTime.tryParse('${data['date']??''}');
   }
   if(!mounted||currentQuote!=_quoteRevision||from!=chosenFrom||to!=chosenTo)return;
   setState((){rate=fetchedRate;result=input*fetchedRate;updated=fetchedAt;});
  }on TimeoutException {
   if(mounted&&currentQuote==_quoteRevision)setState(()=>status=waffraIsEnglish
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
  }finally{if(mounted&&currentQuote==_quoteRevision)setState(()=>busy=false);}
 }
 Future<void> _pullRefresh()async {
  if(!mounted)return;
  ++_quoteRevision;
  setState((){
   ++_goldRefreshRevision;
   ++_oilRefreshRevision;
   result=null;rate=null;updated=null;status='';busy=false;
  });
  if(amount.text.trim().isNotEmpty)await convert();
 }
 List<Widget> _marketCards()=>[
   WaffraMarketAccordionCard(
    id:'currency',key:const Key('waffra-market-currency'),
    title:waffraIsEnglish?'Currency converter':'تحويل العملات',
    subtitle:waffraIsEnglish?'Quick conversion between global currencies':
     'تحويل العملات العالمية بسهولة',
    icon:Icons.currency_exchange_rounded,accent:const Color(0xFF147457),
    expanded:_openMarket=='currency',onPressed:WaffraHaptics.tapRequired(()=>toggleMarket('currency')),
    child:Card(
    margin:EdgeInsets.zero,
    color:Theme.of(context).cardColor,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),
     side:BorderSide(color:Theme.of(context).dividerColor.withValues(alpha:.6))),
    child:Padding(padding:const EdgeInsets.all(14),
     child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
   WaffraText(waffraIsEnglish?
    'Convert any amount using the latest available verified exchange rate.':
    'اعرف قيمة راتبك أو أي مبلغ بعملة ثانية، حسب أحدث سعر متاح.'),
   const SizedBox(height:18),
   TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),
    inputFormatters:[const WaffraAmountFormatter()],
    decoration:InputDecoration(labelText:waffraTr('المبلغ'),border:OutlineInputBorder())),
   const SizedBox(height:14),
   Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
    Expanded(child:OutlinedButton(
     onPressed:WaffraHaptics.tap(busy?null:()=>selectCurrency(true)),
     style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:15)),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      WaffraText(waffraIsEnglish?'From':'من عملة'),
      const SizedBox(height:4),
      _currencyChoice(from),
     ]))),
    const SizedBox(width:4),
    IconButton.filledTonal(
     key:const Key('waffra-currency-swap'),
     tooltip:waffraIsEnglish?'Swap currencies':'تبديل العملات',
     onPressed:WaffraHaptics.tap(busy?null:swapCurrencies),
     icon:const Icon(Icons.swap_horiz_rounded)),
    const SizedBox(width:4),
    Expanded(child:OutlinedButton(
     onPressed:WaffraHaptics.tap(busy?null:()=>selectCurrency(false)),
     style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:10,vertical:15)),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      WaffraText(waffraIsEnglish?'To':'إلى عملة'),
      const SizedBox(height:4),
      if(to==null) WaffraText(waffraIsEnglish?'Select currency':'اختر العملة')
      else _currencyChoice(to!),
     ]))),
   ]),
   const SizedBox(height:20),
   FilledButton.icon(onPressed:WaffraHaptics.tap(busy?null:convert),
    icon:const Icon(Icons.sync_rounded),label:WaffraText(busy?
     (waffraIsEnglish?'Fetching verified rate...':'جاري جلب السعر...'):
     (waffraIsEnglish?'Convert now':'حوّل الآن'))),
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
   ])))),
   const SizedBox(height:12),
   WaffraMarketAccordionCard(
    id:'gold',key:const Key('waffra-market-gold'),
    title:waffraIsEnglish?'Global gold prices':'أسعار الذهب العالمية',
    subtitle:waffraIsEnglish?'Gold karats, bars and weight calculator':
     'الذهب والسبائك وحاسبة الأوزان',
    icon:Icons.workspace_premium_rounded,accent:const Color(0xFFC19A36),
    expanded:_openMarket=='gold',onPressed:WaffraHaptics.tapRequired(()=>toggleMarket('gold')),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
     WaffraGoldMarketSection(
      key:ValueKey('gold-refresh-'+_goldRefreshRevision.toString()),
      english:waffraIsEnglish),
     const SizedBox(height:12),
     OutlinedButton.icon(
      style:OutlinedButton.styleFrom(
       padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),
       minimumSize:const Size.fromHeight(54),
       alignment:Alignment.center,
       shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)),
      ),
      key:const Key('waffra-open-gold-calculator'),
      onPressed:WaffraHaptics.tap(()=>Navigator.of(context).push(MaterialPageRoute(
       builder:(_)=>WaffraGoldCalculatorPage(
        arabicCurrencies:currencies,englishCurrencies:currencyEnglish)))),
      icon:const Icon(Icons.currency_exchange),
      label:WaffraText(waffraIsEnglish?
       'Convert gold value to SAR, EGP or any currency':
       'حوّل قيمة الذهب إلى ريال أو جنيه مصري أو أي عملة',
        maxLines:2,textAlign:TextAlign.center,softWrap:true)),
    ])),
   const SizedBox(height:12),
   WaffraMarketAccordionCard(
    id:'oil',key:const Key('waffra-market-oil'),
    title:waffraIsEnglish?'Global oil prices':'أسعار البترول العالمية',
    subtitle:waffraIsEnglish?'Brent, WTI, Oman, Dubai and natural gas':
     'برنت وغرب تكساس وعُمان ودبي والغاز الطبيعي',
    icon:Icons.oil_barrel_rounded,accent:const Color(0xFF17755E),
    expanded:_openMarket=='oil',onPressed:WaffraHaptics.tapRequired(()=>toggleMarket('oil')),
    child:WaffraOilMarketSection(
     key:ValueKey('waffra-oil-refresh-'+_oilRefreshRevision.toString()),
     english:waffraIsEnglish)),
   const SizedBox(height:22),
  ];
 @override Widget build(BuildContext context){
  if(widget.embedded){
   return Column(
    key:const Key('waffra-inline-world-markets'),
    crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[
     Align(alignment:AlignmentDirectional.centerEnd,
      child:OutlinedButton.icon(
       key:const Key('waffra-market-inline-refresh'),
       onPressed:WaffraHaptics.tap(()=>unawaited(_pullRefresh())),
       icon:const Icon(Icons.refresh_rounded),
       label:WaffraText(waffraIsEnglish?'Refresh market data':'تحديث بيانات الأسواق'))),
     const SizedBox(height:8),
     ..._marketCards(),
    ]);
  }
  return Scaffold(
   appBar:AppBar(title:WaffraText(waffraIsEnglish?
    'Currency, gold & global oil prices':
    'محوّل العملات وأسعار الذهب العالمية والبترول',
    style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800),maxLines:2)),
   body:RefreshIndicator(onRefresh:_pullRefresh,
    child:ListView(controller:_marketsScroll,
     physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
     padding:const EdgeInsets.all(14),
     children:_marketCards())));
 }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'waffra_amount_formatter.dart';
import 'waffra_display_currency.dart';
import 'waffra_oil_market_data.dart';

import 'waffra_haptic_feedback.dart';
/// Crude oil display is isolated from the transaction database.
class WaffraOilMarketSection extends StatefulWidget {
 const WaffraOilMarketSection({super.key,required this.english,
  this.loadQuotes});
 final bool english;
 final Future<Map<String,WaffraOilQuote>> Function()? loadQuotes;
 @override State<WaffraOilMarketSection> createState()=>_WaffraOilMarketSectionState();
}
class _WaffraOilMarketSectionState extends State<WaffraOilMarketSection>{
 static const forest=Color(0xFF073F31),oil=Color(0xFF16755D);
 final units=TextEditingController(text:'1');
 final _fxClient=http.Client();
 Map<String,WaffraOilQuote> quotes={};
 String? issue;
 String benchmark='BRENT',currency='USD';
 double? fx=1;
 bool loading=false,fxLoading=false;
 int generation=0,fxGeneration=0;
 DateTime? fxDate;
 String t(String english,String arabic)=>widget.english?english:arabic;
 @override void initState(){
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_){
   if(mounted)unawaited(load());
  });
 }
 @override void dispose(){generation++;fxGeneration++;units.dispose();_fxClient.close();super.dispose();}
 Future<void> load()async{
  if(loading)return;
  final request=++generation;
  setState((){loading=true;issue=null;});
  try{
   final latest=await (widget.loadQuotes??const WaffraOilService().fetch)();
   if(!mounted||request!=generation)return;
   setState((){
    quotes=latest;
    issue=latest.isEmpty?t('No verified commodity quote is available.',
      'لا تتوفر أسعار بترول موثّقة حاليًا.'):null;
   });
  }catch(_){
   if(!mounted||request!=generation)return;
   setState(()=>issue=quotes.isEmpty?
     t('Published oil prices are unavailable. No sample prices are shown.',
       'الأسعار المنشورة غير متاحة الآن. لن نعرض أسعارًا تجريبية.'):
     t('Unable to refresh; displaying last read data with its original date.',
       'تعذر التحديث؛ نعرض آخر قراءة بتاريخها الأصلي.'));
  }finally{if(mounted&&request==generation)setState(()=>loading=false);}
 }
 Future<void> setCurrency(String value)async{
  final request=++fxGeneration;
  setState((){currency=value;fx=value=='USD'?1:null;fxDate=null;fxLoading=value!='USD';});
  if(value=='USD')return;
  try{
   final response=await _fxClient.get(
    Uri.parse('https://open.er-api.com/v6/latest/USD')).timeout(const Duration(seconds:12));
   if(response.statusCode!=200)throw const FormatException('FX service HTTP');
   final data=jsonDecode(response.body);
   if(data is! Map||data['result']!='success'||data['rates'] is! Map)throw const FormatException('FX payload');
   final rate=(data['rates'] as Map)[value];
   if(rate is! num||!rate.toDouble().isFinite||rate<=0)throw const FormatException('FX rate');
   DateTime? date;
   if(data['time_last_update_unix'] is num){
    date=DateTime.fromMillisecondsSinceEpoch(
     (data['time_last_update_unix'] as num).toInt()*1000,isUtc:true);
    if(DateTime.now().toUtc().difference(date)>const Duration(days:7)||
      date.isAfter(DateTime.now().toUtc().add(const Duration(days:1)))){
     throw const FormatException('Stale FX quote');
    }
   }
   if(mounted&&request==fxGeneration)setState((){fx=rate.toDouble();fxDate=date;});
  }catch(_){
   if(mounted&&request==fxGeneration)setState(()=>fx=null);
  }finally{if(mounted&&request==fxGeneration)setState(()=>fxLoading=false);}
 }
 String stamp(DateTime date){
  final d=date.toLocal(),pad=(int n)=>n.toString().padLeft(2,'0');
  return pad(d.day)+'/'+pad(d.month)+'/'+d.year.toString()+
   '  '+pad(d.hour)+':'+pad(d.minute);
 }
 Widget quoteCard(String code,double width){
  final name=waffraOilNames[code]!,quote=quotes[code];
  final dark=Theme.of(context).brightness==Brightness.dark;
  final selected=benchmark==code;
  final change=quote?.changePercent;
  final tone=change==null?Theme.of(context).hintColor:
    change>=0?const Color(0xFF167C55):const Color(0xFFE34B45);
  return SizedBox(width:width,child:Material(
   color:selected?(dark?const Color(0xFF164F3F):const Color(0xFFF4F4DF)):
       Theme.of(context).cardColor,
   shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18),
    side:BorderSide(color:selected?const Color(0xFFBD9A4F):
     oil.withValues(alpha:.23),width:selected?1.5:1)),
   child:InkWell(
    key:Key('waffra-oil-select-'+code),
    onTap:WaffraHaptics.tap(()=>setState(()=>benchmark=code)),
    borderRadius:BorderRadius.circular(18),
    child:Padding(padding:const EdgeInsets.symmetric(horizontal:9,vertical:11),
     child:Column(children:[
      Text(widget.english?name[0]:name[1],maxLines:2,
       textAlign:TextAlign.center,
       style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),
      const SizedBox(height:5),
      SizedBox(height:53,width:73,child:CustomPaint(
       painter:_OilBarrelPainter(gas:code=='GAS',blue:code=='DUBAI'))),
      const SizedBox(height:5),
      FittedBox(fit:BoxFit.scaleDown,
       child:Text(quote==null?'—':quote.usd.toStringAsFixed(2),
        key:Key('waffra-oil-price-'+code),
        style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))),
      Text(widget.english?name[2]:name[3],textAlign:TextAlign.center,
       style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
      const SizedBox(height:6),
      if(quote!=null&&change!=null)
       Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        Text((change>=0?'+':'')+change.toStringAsFixed(2)+'%',
         style:TextStyle(fontWeight:FontWeight.w800,color:tone,fontSize:11)),
        const SizedBox(width:5),
        SizedBox(width:36,height:19,child:CustomPaint(
         painter:_OilSparkPainter(quote.points,color:tone))),
       ])
      else Text(t('Quote unavailable','السعر غير متاح'),
       style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
     ]))),
  ));
 }
 Widget calculator(){
  final q=quotes[benchmark];
  final volume=waffraStrictNumericInput(units.text,decimalPlaces:3,maxValue:1000000);
  final valid=volume!=null&&volume>0&&volume.isFinite&&volume<=1000000;
  final usd=valid&&q!=null&&!q.isOld(DateTime.now())?volume*q.usd:null;
  final total=usd==null||fx==null?null:usd*fx!;
  return Container(
   padding:const EdgeInsets.all(13),
   decoration:BoxDecoration(
    color:Theme.of(context).brightness==Brightness.dark?
      const Color(0xFF17483D):const Color(0xFFE9F5EF),
    borderRadius:BorderRadius.circular(18),
    border:Border.all(color:oil.withValues(alpha:.25))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(t('Calculate your oil value','احسب قيمة البترول'),
     style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
    const SizedBox(height:5),
    Text(t('Benchmark, quantity and independent currency conversion.',
      'اختَر نوع الخام والكمية وعملة التحويل بسعر صرف موثّق.'),
     style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
    const SizedBox(height:12),
    DropdownButtonFormField<String>(
     key:ValueKey('waffra-oil-benchmark-picker-'+benchmark),
     initialValue:benchmark,isExpanded:true,
     decoration:InputDecoration(labelText:t('Benchmark','نوع الخام'),
      border:const OutlineInputBorder()),
     items:waffraOilNames.entries.map((entry)=>DropdownMenuItem<String>(
      value:entry.key,child:Text(widget.english?entry.value[0]:entry.value[1]))).toList(),
     onChanged:WaffraHaptics.selection((v){if(v!=null)setState(()=>benchmark=v);})),
    const SizedBox(height:9),
    Row(children:[
     Expanded(child:TextField(
      key:const Key('waffra-oil-quantity'),
      controller:units,
      keyboardType:const TextInputType.numberWithOptions(decimal:true),
      inputFormatters:[const WaffraAmountFormatter(decimalPlaces:3,truncateExcess:false)],
      decoration:InputDecoration(labelText:t('Quantity','الكمية'),
       border:const OutlineInputBorder()),
      onChanged:(_)=>setState((){}))),
     const SizedBox(width:9),
     Expanded(child:DropdownButtonFormField<String>(
      key:ValueKey('waffra-oil-currency-'+currency),initialValue:currency,
      decoration:InputDecoration(labelText:t('Currency','العملة'),
       border:const OutlineInputBorder()),
      items:waffraCountryCurrencies
       .map((v)=>DropdownMenuItem(value:v.code,child:Text(v.code))).toList(),
      onChanged:WaffraHaptics.selection((v){if(v!=null)unawaited(setCurrency(v));}))),
    ]),
    const SizedBox(height:13),
    Row(children:[
     Icon(Icons.calculate_rounded,color:oil),
     const SizedBox(width:8),
     Expanded(child:Text(t('Estimated value','القيمة التقديرية'),
      style:const TextStyle(fontWeight:FontWeight.w700))),
     if(fxLoading)const SizedBox(width:19,height:19,
      child:CircularProgressIndicator(strokeWidth:2))
     else FittedBox(fit:BoxFit.scaleDown,
      child:Text(total==null?'—':formatWaffraMoney(total,decimalPlaces:waffraCurrencyMinorDigits(currency))+' '+currency,
       key:const Key('waffra-oil-total'),
       style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))),
    ]),
    if(total==null)Padding(padding:const EdgeInsets.only(top:7),
     child:Text(q==null?t('Verified benchmark price is required.',
      'تحتاج إلى سعر موثّق للخام المحدد.'):
      q.isOld(DateTime.now())?t('Quote is outdated; estimate is blocked.',
       'السعر قديم؛ لا يمكن حساب القيمة بسعر غير حديث.'):
      !valid?t('Enter a positive quantity.','أدخل كمية صحيحة أكبر من صفر.'):
      t('Verified FX quote is unavailable.','سعر الصرف الموثّق غير متاح.'),
      style:TextStyle(fontSize:11,color:Theme.of(context).hintColor))),
    if(usd!=null&&currency!='USD')Padding(padding:const EdgeInsets.only(top:6),
     child:Text('USD '+usd.toStringAsFixed(2),
      style:TextStyle(fontSize:11,color:Theme.of(context).hintColor))),
    if(total!=null&&currency!='USD'&&fxDate!=null)
     Text(t('FX quote: ','سعر الصرف بتاريخ: ')+stamp(fxDate!),
      style:TextStyle(fontSize:10,color:Theme.of(context).hintColor)),
   ]),
  );
 }
 @override Widget build(BuildContext context){
  return Container(
   key:const Key('waffra-world-oil-market-section'),
   padding:const EdgeInsets.all(13),
   decoration:BoxDecoration(
    color:Theme.of(context).cardColor,borderRadius:BorderRadius.circular(22),
    border:Border.all(color:oil.withValues(alpha:.35))),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Row(children:[
     const Icon(Icons.oil_barrel_rounded,size:26,color:oil),
     const SizedBox(width:9),
     Expanded(child:Text(t('Global oil prices','أسعار البترول العالمية'),
      style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900))),
     IconButton(tooltip:t('Refresh oil quotes','تحديث أسعار البترول'),
      icon:const Icon(Icons.refresh_rounded,color:oil),
      onPressed:WaffraHaptics.tap(loading?null:load)),
    ]),
    Text(t('Latest published spot price — not a live exchange tick',
     'أحدث سعر فوري منشور من المصدر، وليس تسعير بورصة لحظيًا'),
     style:TextStyle(color:Theme.of(context).hintColor,fontSize:11)),
    if(loading)const Padding(padding:EdgeInsets.symmetric(vertical:12),
     child:LinearProgressIndicator()),
    if(issue!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),
     child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(issue!,key:const Key('waffra-oil-price-status'),
       style:TextStyle(fontSize:12,color:Theme.of(context).colorScheme.error)),
      const SizedBox(height:8),
      OutlinedButton.icon(
       key:const Key('waffra-oil-retry'),
       onPressed:WaffraHaptics.tap(loading?null:load),
       icon:const Icon(Icons.refresh_rounded),
       label:Text(t('Retry verified prices','إعادة محاولة جلب الأسعار')),
      ),
     ])),
    const SizedBox(height:12),
    LayoutBuilder(builder:(ctx,box){
     final width=(box.maxWidth-9)/2;
     return Wrap(spacing:9,runSpacing:9,children:[
      for(final code in waffraOilNames.keys)quoteCard(code,width),
     ]);
    }),
    const SizedBox(height:14),
    if(quotes[benchmark]!=null)Text(
     t('EIA spot quote: ','سعر EIA المنشور: ')+
      stamp(quotes[benchmark]!.updatedAt)+
      (quotes[benchmark]!.isOld(DateTime.now())?
       t(' · old data',' · بيانات قديمة'):''),
     style:TextStyle(fontSize:11,color:Theme.of(context).hintColor)),
    const SizedBox(height:11),
    calculator(),
    const SizedBox(height:12),
    Text(t('Source: U.S. EIA official daily spot pages, EIA API (if configured), or FRED backup. Brent and WTI are USD/barrel; Henry Hub gas is USD/MMBtu. Oman and Dubai require independently verified feeds. Graphs use genuine historical observations; estimates exclude taxes and fees.',
      'المصدر: صفحات الأسعار اليومية الرسمية لهيئة الطاقة الأمريكية EIA، أو واجهة EIA عند إعدادها، مع FRED كمصدر احتياطي. برنت وغرب تكساس بالدولار للبرميل، وغاز هنري هب بالدولار لكل مليون وحدة حرارية. خاما عُمان ودبي يحتاجان مصادر موثوقة مستقلة. الرسوم من أسعار منشورة فعلية، والأسعار لا تشمل الرسوم والضرائب.'),
     style:TextStyle(fontSize:10.5,color:Theme.of(context).hintColor)),
   ]),
  );
 }
}

class _OilSparkPainter extends CustomPainter {
 const _OilSparkPainter(this.points,{required this.color});
 final List<WaffraOilPoint> points;
 final Color color;
 @override void paint(Canvas canvas,Size size){
  if(points.length<2)return;
  final values=points.map((p)=>p.usd).toList();
  final min=values.reduce((a,b)=>a<b?a:b),max=values.reduce((a,b)=>a>b?a:b);
  final range=max-min;
  final path=Path();
  for(var i=0;i<values.length;i++){
   final x=size.width*i/(values.length-1);
   final y=size.height/2-(range==0?0:(values[i]-(min+max)/2)/range*size.height*.8);
   if(i==0)path.moveTo(x,y);else path.lineTo(x,y);
  }
  canvas.drawPath(path,Paint()..color=color..strokeWidth=2.2
   ..strokeCap=StrokeCap.round..style=PaintingStyle.stroke);
 }
 @override bool shouldRepaint(covariant _OilSparkPainter old)=>
  old.points!=points||old.color!=color;
}

class _OilBarrelPainter extends CustomPainter {
 const _OilBarrelPainter({this.gas=false,this.blue=false});
 final bool gas,blue;
 @override void paint(Canvas canvas,Size size){
  final body=Rect.fromLTWH(size.width*.18,size.height*.19,
   size.width*.64,size.height*.70);
  final base=gas?const Color(0xFF959EA3):blue?
   const Color(0xFF216A96):const Color(0xFF222F2E);
  final paint=Paint()..shader=LinearGradient(colors:[
   base.withValues(alpha:.7),base,const Color(0xFF090E10)
  ]).createShader(body);
  canvas.drawOval(Rect.fromLTWH(size.width*.18,size.height*.78,
   size.width*.64,size.height*.17),Paint()..color=const Color(0x44000000));
  canvas.drawRect(body,paint);
  canvas.drawOval(Rect.fromLTWH(body.left,body.top-body.height*.09,
   body.width,body.height*.19),Paint()..color=base);
  canvas.drawOval(Rect.fromLTWH(body.left,body.bottom-body.height*.11,
   body.width,body.height*.19),Paint()..color=base.withValues(alpha:.9));
  final bands=Paint()..color=Colors.white.withValues(alpha:.19)
   ..strokeWidth=2..style=PaintingStyle.stroke;
  for(final d in [.28,.70])canvas.drawLine(
   Offset(body.left,body.top+body.height*d),
   Offset(body.right,body.top+body.height*d),bands);
  final ink=Paint()..color=gas?const Color(0xFFB0E5FF):const Color(0xFFE1B553);
  final cx=body.center.dx,cy=body.center.dy;
  final drop=Path()..moveTo(cx,cy-10)
   ..cubicTo(cx+13,cy+2,cx+8,cy+11,cx,cy+11)
   ..cubicTo(cx-9,cy+11,cx-11,cy+3,cx,cy-10);
  canvas.drawPath(drop,ink);
 }
 @override bool shouldRepaint(covariant _OilBarrelPainter old)=>
  old.gas!=gas||old.blue!=blue;
}

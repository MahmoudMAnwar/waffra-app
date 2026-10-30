import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'waffra_practical_tools_page.dart';
import 'waffra_practical_ledger_engine.dart';
import 'waffra_haptic_feedback.dart';
import 'waffra_ai_finance_coach.dart';
import 'waffra_ondevice_qwen.dart';
import 'waffra_ai_model_gate.dart';
import 'waffra_display_currency.dart';
import 'waffra_riyal_symbol.dart';
import 'currency_converter.dart';

/// M268. Read-only finance tools. Never reads SMS originals, keys, or bank data.
/// User-driven scenarios exist in widget state only and cannot write any ledger.
class WaffraSmartEntry {
  final String id, title, category;
  final double amount;
  final bool income;
  final DateTime date;
  /// The Home-verified projection only; never send bank details to the cloud.
  final String notes;
  final bool hasAttachment;
  const WaffraSmartEntry({required this.id,required this.title,
    required this.category,required this.amount,required this.income,
    required this.date,this.notes='',this.hasAttachment=false});
}

class WaffraSmartGoal {
  final String name;
  final double target,saved;
  const WaffraSmartGoal(this.name,this.target,this.saved);
}

class WaffraSmartRecurring {
  final String name;
  final double amount;
  final int day;
  final bool income;
  const WaffraSmartRecurring(this.name,this.amount,this.day,this.income);
}

class WaffraSmartSubscription {
  final String name;
  final double monthly;
  final int months;
  const WaffraSmartSubscription(this.name,this.monthly,this.months);
}

/// Month aware and intentionally separate from account balance (no bank access).
DateTime waffraNextPayday(DateTime today,int day) {
  final d=day.clamp(1,31).toInt();
  DateTime resolve(int year,int month) {
    final last=DateTime(year,month+1,0).day;
    return DateTime(year,month,math.min(last,d));
  }
  final thisMonth=resolve(today.year,today.month);
  final start=DateTime(today.year,today.month,today.day);
  return thisMonth.isAfter(start)?thisMonth:resolve(today.year,today.month+1);
}

double waffraSmartBalance(Iterable<WaffraSmartEntry> entries) =>
 entries.fold<double>(0,(v,e)=>v+(e.income?e.amount:-e.amount));

Map<String,double> waffraCategoryOutflows(Iterable<WaffraSmartEntry> entries,
 {DateTime? start,DateTime? end}) {
  final result=<String,double>{};
  for(final e in entries){
    if(e.income||(start!=null&&e.date.isBefore(start))||
       (end!=null&&!e.date.isBefore(end)))continue;
    result[e.category]=(result[e.category]??0)+e.amount;
  }
  return result;
}

List<WaffraSmartSubscription> waffraSmartSubscriptions(
 Iterable<WaffraSmartEntry> entries) {
  final grouped=<String,List<WaffraSmartEntry>>{};
  for(final e in entries){
    if(e.income||e.amount<=0||e.title.trim().isEmpty)continue;
    grouped.putIfAbsent(e.title.trim().toLowerCase(),()=>[]).add(e);
  }
  final output=<WaffraSmartSubscription>[];
  for(final group in grouped.values) {
    final monthly=group.map((e)=>e.date.year*12+e.date.month).toSet();
    if(monthly.length<2)continue;
    final avg=group.fold<double>(0,(v,e)=>v+e.amount)/group.length;
    if(group.any((e)=>(e.amount-avg).abs()>avg*.2))continue;
    output.add(WaffraSmartSubscription(group.first.title,avg,monthly.length));
  }
  return output..sort((a,b)=>b.months.compareTo(a.months));
}

List<WaffraSmartEntry> waffraPotentialDuplicates(
 Iterable<WaffraSmartEntry> entries) {
  final data=entries.where((e)=>!e.income).toList()
   ..sort((a,b)=>a.date.compareTo(b.date));
  final found=<WaffraSmartEntry>[];
  for(var i=1;i<data.length;i++){
    final current=data[i];
    final key=current.title.trim().toLowerCase();
    if(key.isEmpty)continue;
    for(var j=i-1;j>=0;j--){
      final previous=data[j];
      if(current.date.difference(previous.date).inDays>3)break;
      if(key==previous.title.trim().toLowerCase()&&
         (current.amount-previous.amount).abs()<0.01&&
         current.id!=previous.id){
        found.add(current);
        break;
      }
    }
  }
  return found;
}

double waffraProjectedRecurringOutflows(DateTime today,DateTime until,
 Iterable<WaffraSmartRecurring> recurring){
  var total=0.0;
  for(var month=DateTime(today.year,today.month);
      !month.isAfter(DateTime(until.year,until.month));
      month=DateTime(month.year,month.month+1)){
    for(final r in recurring){
      if(r.income||r.amount<=0)continue;
      final last=DateTime(month.year,month.month+1,0).day;
      final at=DateTime(month.year,month.month,math.min(last,r.day.clamp(1,31).toInt()));
      if(!at.isBefore(DateTime(today.year,today.month,today.day))&&
         at.isBefore(until))total+=r.amount;
    }
  }
  return total;
}

/// Illustrated category artwork, distinct from the functional system controls
/// (back, close, visibility, accessibility and camera remain recognizable).
class WaffraIllustration extends StatelessWidget {
  final String topic;
  final double size;
  const WaffraIllustration({super.key,required this.topic,this.size=56});

  static String picture(String source){
    final s=source.toLowerCase();
    const keys=<String,String>{
      'restaurant':'🍽️','coffee':'☕','shopping':'🛍️','car':'🚙',
      'receipt':'🧾','health':'🩺','transfer':'🏦','salary':'💰',
      'home':'🏡','education':'🎓','sport':'🏋️','gift':'🎁',
      'travel':'✈️','groceries':'🛒','family':'👨‍👩‍👧','baby':'🧸',
      'entertainment':'🎭','subscriptions':'📺','sadaqat':'❤️',
      'charity':'🤲','zakat':'🌙','pets':'🐈','insurance':'🛡️',
      'business':'💼','government':'🏛️','bank':'🏦',
      'wedding':'💍','tools':'🧰','device':'📱','freelance':'💻',
      'gaming':'🎮','tax':'🧮','investment':'📈','pension':'🪙',
      'agriculture':'🌾',
      'runway':'👛','subscription':'📺','simulation':'📱',
      'guardian':'🛡️','assistant':'🤖','season':'🌙',
      'wallet':'🧳','challenge':'🏆','flow':'🌿','emergency':'☂️',
      'calendar':'📅','income':'💰','expense':'🛍️',
    };
    for(final key in keys.keys){
      if(s.contains(key))return keys[key]!;
    }
    if(s.contains('مطعم')||s.contains('طعام'))return '🍽️';
    if(s.contains('كافيه')||s.contains('قهوة'))return '☕';
    if(s.contains('تسوق')||s.contains('تسوّق'))return '🛍️';
    if(s.contains('مواصل')||s.contains('سيار'))return '🚙';
    if(s.contains('فواتير')||s.contains('كهرب'))return '🧾';
    if(s.contains('سكن')||s.contains('منزل'))return '🏡';
    if(s.contains('صحة')||s.contains('علاج'))return '🩺';
    if(s.contains('راتب')||s.contains('دخل'))return '💰';
    if(s.contains('رياض')||s.contains('لياقة'))return '🏋️';
    if(s.contains('تعليم'))return '🎓';
    if(s.contains('سفر'))return '✈️';
    if(s.contains('صدقة')||s.contains('تبرع'))return '🤲';
    if(s.contains('تحويل'))return '🏦';
    return '🌱';
  }

  @override Widget build(BuildContext context){
    final dark=Theme.of(context).brightness==Brightness.dark;
    final bottom=dark?const Color(0xFF204D3D):const Color(0xFFE6F3E8);
    return Semantics(label:topic,image:true,child:Container(
      width:size,height:size,
      decoration:BoxDecoration(
        gradient:LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
          colors:dark?[const Color(0xFF326B54),const Color(0xFF103E30)]:
            [const Color(0xFFFFF7E7),bottom]),
        borderRadius:BorderRadius.circular(size*.28),
        border:Border.all(color:const Color(0xFF087A54).withValues(alpha:.13)),
        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:dark ? .18 : .08),
          blurRadius:12,offset:const Offset(0,5))]),
      child:Center(child:Text(picture(topic),
       style:TextStyle(fontSize:size*.53,height:1.14)))));
  }
}

class WaffraSmartFeaturesPage extends StatefulWidget{
 final List<WaffraSmartEntry> entries;
 final List<WaffraSmartGoal> goals;
 final List<WaffraSmartRecurring> recurring;
 final bool english;
 final bool embedded;
 /// Stable header focus used by the onboarding tour in the tools footer.
 final Key? tourHeadingKey;
 /// Existing full financial analysis entry, supplied by Home's verified state.
 final WidgetBuilder? analysisBuilder;
 /// Centralized Home footer notice presenter, optional for standalone previews.
 final ValueChanged<String>? onNotice;
 const WaffraSmartFeaturesPage({super.key,required this.entries,
  required this.goals,required this.recurring,required this.english,
  this.embedded=false,this.analysisBuilder,this.onNotice,this.tourHeadingKey});
 @override State<WaffraSmartFeaturesPage> createState()=>_WaffraSmartFeaturesPageState();
}

class _WaffraSmartFeaturesPageState extends State<WaffraSmartFeaturesPage>{
 static const green=Color(0xFF087A54);
 static const types=['runway','subscription','simulation','guardian','assistant',
  'season','wallet','challenge','flow','emergency'];
 static const titlesAr=['فلوسك تكفيك؟','صائد الاشتراكات','جرّب قبل ما تصرف',
  'الحارس المالي','اسأل وفرة','المواسم المالية','محافظ المشاريع',
  'تحديات التوفير','خريطة فلوسك','صندوق الأمان المالي'];
 static const titlesEn=['Will your money last?','Subscription detective',
  'Try before spending','Financial guardian','Ask Waffra','Saudi money seasons',
  'Project wallets','Savings challenges','Your money map','Emergency fund'];
 static const descAr=['مصروفك اليومي حتى الراتب','اشتراكات محتملة من معاملاتك',
  'تأثير شراء افتراضي','عمليات تحتاج مراجعتك','اسأل بياناتك المحفوظة',
  'استعد للمواسم المهمة','اجمع مصروفات مشروعك','قلل مصروفاتك بالتدريج',
  'شوف فين بتروح فلوسك','خطط لأمانك المالي'];
 static const descEn=['Daily allowance until payday','Likely repeated costs',
  'Preview a hypothetical purchase','Potential transactions to review',
  'Ask about saved transactions','Prepare for local seasons','Group a project budget',
  'Spend a little less','See how your money flows','Plan your safety buffer'];
 int? active;
 // Stable section anchors; the user-selected accordion is scrolled to top
 // only after expansion settles, respecting reduced-motion preferences.
 final Map<int,GlobalKey> _sectionKeys={for(var i=-2;i<10;i++) i:GlobalKey()};
 int _focusSerial=0;
 void _activateSection(int section){
  final next=active==section?null:section;
  setState(()=>active=next);
  // A deleted model leaves its AI features visible but disabled.
  if(section==4&&!WaffraOnDeviceQwen.shared.isReady)return;
  final token=++_focusSerial;
  if(next==null)return;
  final reduced=MediaQuery.disableAnimationsOf(context);
  final settle=reduced?Duration.zero:const Duration(milliseconds:345);
  WidgetsBinding.instance.addPostFrameCallback((_){
   unawaited(Future<void>.delayed(settle,()async{
    if(!mounted||active!=section||token!=_focusSerial)return;
    final target=_sectionKeys[section]?.currentContext;
    if(target==null)return;
    await Scrollable.ensureVisible(target,
     alignment:0.02,alignmentPolicy:ScrollPositionAlignmentPolicy.explicit,
     duration:reduced?Duration.zero:const Duration(milliseconds:275),
     curve:Curves.easeOutCubic);
   }));
  });
 }
 int payday=27;
 double purchase=3500,seasonTarget=5000,daysToSeason=90;
 double goalAmount=3000,challengePercent=20,existingEmergency=0;
 int emergencyMonths=3,projectIndex=0;
 String question='',answer='';
 bool aiBusy=false;
 String aiStatus='',aiAnalysis='',aiSavings='';
 final input=TextEditingController();
 final projectsAr=['رحلة','منزل','تعليم'];
 final projectsEn=['Trip','Home','Education'];
 String t(String ar,String en)=>widget.english?en:ar;
 // Honor the app-wide nominal denomination: never apply FX to ledger values.
 String cash(num v)=>WaffraDisplayCurrency.money(v,english:widget.english);
 String get currencyLabel=>WaffraDisplayCurrency.label(widget.english);
 double get balance=>waffraSmartBalance(widget.entries);
 List<WaffraSmartEntry> get expenses=>widget.entries.where((e)=>!e.income).toList();
 DateTime get today=>DateTime.now();
 @override void initState(){
  super.initState();
  WaffraOnDeviceQwen.shared.revision.addListener(_onAiRevision);
  unawaited(WaffraOnDeviceQwen.shared.loadToolVisibilityHistory()
   .catchError((Object _){}));
 }
 void _onAiRevision(){
  if(!mounted)return;
  setState((){
   if(!WaffraOnDeviceQwen.shared.isReady){
    // Clear private model output; collapse an open AI-only panel on delete.
    aiStatus='';aiAnalysis='';aiSavings='';answer='';
    if(active==4)active=null;
   }
  });
 }
 @override void dispose(){
  WaffraOnDeviceQwen.shared.revision.removeListener(_onAiRevision);
  input.dispose();super.dispose();
 }

 Widget _label(String value,{double size=14,bool bold=false,Color? color}){
  final effective=TextStyle(fontFamily:'Tajawal',fontSize:size,
      fontWeight:bold?FontWeight.w800:FontWeight.w500,color:color);
  final spans=waffraMoneyCurrencySpans(value,
      english:widget.english,style:effective);
  // Do not wrap a WaffraText inside another Text: Flutter's text finder
  // would double-count unchanged labels in the smart-tool screens.
  return spans==null?Text(value,style:effective):
   Text.rich(TextSpan(children:spans),style:effective);
 }
 Widget _paragraph(String v)=>_label(v,size:13,color:Theme.of(context).colorScheme.onSurface.withValues(alpha:.77));
 Widget _tile(String label,String value,{String? note,Color? tint}){
  final dark=Theme.of(context).brightness==Brightness.dark;
  return Container(
   padding:const EdgeInsets.all(14),margin:const EdgeInsets.only(bottom:9),
   decoration:BoxDecoration(color:tint??(dark?const Color(0xFF1C372B):
    const Color(0xFFEAF5EE)),borderRadius:BorderRadius.circular(18)),
   child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    _label(label,size:12),const SizedBox(height:4),
    _label(value,size:19,bold:true),
    if(note!=null)...[const SizedBox(height:4),_paragraph(note)],
   ]));
 }
 Widget _slider(String title,double current,double lower,double upper,
    ValueChanged<double> update,{int divisions=20}){
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   _label(title+' — '+current.toStringAsFixed(0),bold:true),
   Slider(value:current.clamp(lower,upper).toDouble(),min:lower,max:upper,
    divisions:divisions,activeColor:green,
    onChanged:update),
  ]);
 }
 Widget _head(String title,String topic,String subtitle){
  return Row(crossAxisAlignment:CrossAxisAlignment.center,children:[
   WaffraIllustration(topic:topic,size:72),const SizedBox(width:13),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    _label(title,size:21,bold:true),_paragraph(subtitle),
   ])),
  ]);
 }
 Widget _surface(Widget child)=>Container(
  width:double.infinity,padding:const EdgeInsets.all(15),
  decoration:BoxDecoration(color:Theme.of(context).cardColor,
   borderRadius:BorderRadius.circular(23),
   border:Border.all(color:green.withValues(alpha:.13))),
  child:child);
 Widget _column(List<Widget> items)=>_surface(Column(
  crossAxisAlignment:CrossAxisAlignment.stretch,children:items));
 Widget _warning()=>Padding(padding:const EdgeInsets.only(top:12),
  child:_paragraph(t('هذه النتائج تقديرية من العمليات المسجلة فقط، بدون ربط بنكي. '
   'التعديلات داخل الأدوات افتراضية ولا تُحفظ كمعاملات.',
   'Estimates use recorded transactions only, without bank access. '
   'Scenarios here do not save or change transactions.')));

 Widget _runway(){
  final until=waffraNextPayday(today,payday);
  final days=math.max(1,until.difference(DateTime(today.year,today.month,today.day)).inDays);
  final scheduled=waffraProjectedRecurringOutflows(today,until,widget.recurring);
  final available=math.max(0.0,balance-scheduled);
  final daily=available/days;
  return _column([
   _head(titlesAr[0],'runway',t('متاح تقديري حتى الراتب القادم','Estimated room until payday')),
   const SizedBox(height:20),
   _slider(t('يوم الراتب','Payday'),payday.toDouble(),1,31,
     (v)=>setState(()=>payday=v.round()),divisions:30),
   _tile(t('المتاح يوميًا','Daily spending room'),cash(daily),
    note:t('حتى '+until.day.toString()+'/'+until.month.toString()+
      '، بعد حجز المصروفات المتكررة المتوقعة.',
      'Until '+until.day.toString()+'/'+until.month.toString()+
      ', after projected recurring costs.')),
   _tile(t('الالتزامات المتوقعة','Projected bills'),cash(scheduled)),
   _tile(t('المتاح المسجل بعد الالتزامات','Balance less bills'),cash(available)),
   _warning(),
  ]);
 }
 Widget _subscriptions(){
  final found=waffraSmartSubscriptions(widget.entries);
  return _column([
   _head(titlesAr[1],'subscription',t('لا نضيف أي اشتراك دون موافقتك','No subscription is automatically added')),
   const SizedBox(height:15),
   _tile(t('اشتراكات محتملة','Potential subscriptions'),found.length.toString(),
     note:t('يحتاج كل اشتراك مراجعة للتأكد.','Verify each suggestion before recording it.')),
   if(found.isEmpty)_paragraph(t('لا توجد معاملات متشابهة في شهرين مختلفين حتى الآن.',
     'No similar payments across two different months yet.')),
   ...found.map((x)=>_tile(x.name,cash(x.monthly),
    note:t('ظهر في '+x.months.toString()+' أشهر','Seen in '+x.months.toString()+' months'))),
   _warning(),
  ]);
 }
 Widget _simulate(){
  final remaining=balance-purchase;
  final monthly=widget.entries.where((e)=>e.income&&
   e.date.isAfter(today.subtract(const Duration(days:90))))
   .fold<double>(0,(v,e)=>v+e.amount)/3;
  final needed=monthly>0?(purchase/monthly).ceil():0;
  return _column([
   _head(titlesAr[2],'simulation',t('قبل ما تأكد الشراء','Before committing to a purchase')),
   const SizedBox(height:15),
   _slider(t('مبلغ شراء افتراضي','Hypothetical purchase')+' ('+currencyLabel+')',
    purchase,0,15000,(v)=>setState(()=>purchase=v),divisions:60),
   _tile(t('المتبقي بعد الشراء','Balance after purchase'),cash(remaining)),
   _tile(t('الشراء من رصيدك المسجل','Purchase as share of recorded balance'),
    balance<=0?t('غير متاح','Unavailable'):(100*purchase/balance).toStringAsFixed(1)+'%'),
   if(needed>0)_tile(t('ما يعادله من متوسط الدخل الشهري','Equivalent average income months'),
    needed.toString()),
   _paragraph(t('دي تجربة فقط؛ لا تُنشأ معاملة أو يخصم أي مبلغ.',
    'Simulation only; no transaction is created or balance deducted.')),
  ]);
 }
 Widget _guardian(){
  final duplicates=waffraPotentialDuplicates(widget.entries);
  final refunds=widget.entries.where((e)=>e.income&&RegExp(
    r'استرداد|مرتجع|refund|reversal',caseSensitive:false).hasMatch(e.title)).toList();
  final ordered=expenses.map((e)=>e.amount).toList()..sort();
  final median=ordered.isEmpty?0.0:ordered[ordered.length~/2];
  final unusual=expenses.where((e)=>median>0&&e.amount>median*4&&e.amount>=100).toList();
  final watch=<WaffraSmartEntry>{...duplicates,...unusual,...refunds}.toList();
  return _column([
   _head(titlesAr[3],'guardian',t('تنبيهات للمراجعة، مش اتهامات احتيال','Review suggestions, not fraud accusations')),
   const SizedBox(height:15),
   _tile(t('عمليات تحتاج مراجعة','Items to review'),watch.length.toString()),
   _paragraph(t('المكرر المحتمل: '+duplicates.length.toString()+
    ' • المبلغ غير المعتاد: '+unusual.length.toString()+
    ' • استرداد محتمل: '+refunds.length.toString(),
    'Possible duplicates: '+duplicates.length.toString()+
    ' • Unusual amounts: '+unusual.length.toString()+
    ' • Possible refunds: '+refunds.length.toString())),
   const SizedBox(height:12),
   if(watch.isEmpty)_paragraph(t('ما لقيناش معاملات تحتاج تنبيه حاليًا.',
    'No transactions currently trigger these checks.')),
   ...watch.take(15).map((x)=>_tile(x.title,cash(x.amount),
    note:x.category+' • '+x.date.day.toString()+'/'+x.date.month.toString())),
   _warning(),
  ]);
 }

 WaffraAiSummary _verifiedAiSummary(){
  // _smartToolsTab already requires the current account's bound finance
  // source. Only category + exact minor unit totals reach the local model.
  final facts=<WaffraAiLedgerFact>[];
  for(final item in widget.entries){
   final minor=item.amount*100;
   if(!minor.isFinite||minor<=0||minor>100000000000||
      (minor-minor.round()).abs()>0.000001)continue;
   facts.add(WaffraAiLedgerFact(
    category:item.category,amountMinor:minor.round(),income:item.income));
  }
  return WaffraAiFinanceCoach.summarize(facts);
 }

 Future<void> _enableLocalAi()async{
  if(aiBusy||WaffraOnDeviceQwen.shared.isReady)return;
  setState(()=>aiBusy=true);
  try{
   final ready=await WaffraAiModelGate.ensureReady(context,english:widget.english);
   if(mounted)setState(()=>aiStatus=ready?
     t('النموذج جاهز للتحليل المحلي. يمكن حذفه من حسابي في أي وقت.',
       'The model is ready. You can remove it anytime in My Account.'):
     t('التحليل الذكي غير مفعّل؛ الأدوات العادية ما زالت متاحة.',
       'AI is not enabled; the usual tools remain available.'));
  }finally{
   if(mounted)setState(()=>aiBusy=false);
  }
 }

 Future<void> _generateAiSkill(String skill,{String questionText=''})async{
  if(aiBusy||!WaffraOnDeviceQwen.shared.isReady)return;
  final snapshot=_verifiedAiSummary();
  setState(()=>aiBusy=true);
  try{
   final generator=WaffraOnDeviceQwen.shared.textGenerator;
   final response=switch(skill){
    'ask'=>await WaffraAiFinanceCoach.askWaffra(
      questionText,snapshot,generate:generator,
      displayCurrency:WaffraDisplayCurrency.country.code,
      english:widget.english),
    'analysis'=>await WaffraAiFinanceCoach.analysis(
      snapshot,generate:generator,
      displayCurrency:WaffraDisplayCurrency.country.code,
      english:widget.english),
    _=>await WaffraAiFinanceCoach.savingSuggestions(
      snapshot,generate:generator,
      displayCurrency:WaffraDisplayCurrency.country.code,
      english:widget.english),
   };
   if(!mounted)return;
   setState((){
    final text=response??t(
     'البيانات غير كافية لإجابة موثوقة.',
     'Insufficient verified data for an AI answer.');
    if(skill=='ask')answer=text;
    else if(skill=='analysis')aiAnalysis=text;
    else aiSavings=text;
   });
  }catch(_){
   if(mounted)setState(()=>aiStatus=t(
    'لم يكتمل التحليل؛ لم تتغير أي بيانات مالية.',
    'AI analysis was interrupted; no finance data changed.'));
  }finally{
   if(mounted)setState(()=>aiBusy=false);
  }
 }

 // AI-only features are hidden until activation. Once previously used,
 // model removal leaves these UI elements visible but disabled.
 bool get _aiToolVisible=>WaffraOnDeviceQwen.shared.isReady||
  WaffraOnDeviceQwen.shared.hasEverEnabled;

 Widget _aiActivation()=>Column(
   key:const Key('waffra-ai-tools-install-section'),
   crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(!WaffraOnDeviceQwen.shared.isReady)...[
     _paragraph(_aiToolVisible?
      t('نموذج الذكاء الاصطناعي محذوف أو غير مفعّل. ميزات AI معطّلة حتى إعادة تفعيله.',
        'AI model removed or inactive. AI tools stay disabled until reactivated.'):
      t('حمّل نموذج الذكاء الاصطناعي على جهازك لتظهر أدوات AI الخاصة بوفرة.',
        'Download the private AI model to reveal AI-powered tools.')),
     const SizedBox(height:8),
     OutlinedButton.icon(
      key:const Key('waffra-local-ai-opt-in'),
      onPressed:aiBusy?null:()=>unawaited(_enableLocalAi()),
      icon:const Icon(Icons.smart_toy_outlined),
      label:Text(_aiToolVisible?
       t('إعادة تفعيل نموذج الذكاء الاصطناعي','Reactivate AI model'):
       t('تنزيل وتفعيل نموذج الذكاء الاصطناعي','Download and activate AI model'))),
    ],
    if(aiStatus.isNotEmpty)Padding(
     padding:const EdgeInsets.only(top:8),child:_paragraph(aiStatus)),
    if(aiBusy)const Padding(padding:EdgeInsets.only(top:8),
     child:LinearProgressIndicator()),
   ]);

 Widget _aiAnalysisPanel(){
  if(!_aiToolVisible)return const SizedBox.shrink();
  final ready=WaffraOnDeviceQwen.shared.isReady;
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   OutlinedButton(
    key:const Key('waffra-ai-financial-analysis'),
    onPressed:ready&&!aiBusy?()=>unawaited(_generateAiSkill('analysis')):null,
    child:Text(t('تحليل مالي بالذكاء الاصطناعي المحلي',
     'Generate on-device financial analysis'))),
   if(!ready)_paragraph(t('يتطلب إعادة تفعيل نموذج الذكاء الاصطناعي.',
     'Reactivate the AI model to use this feature.')),
   if(ready&&aiAnalysis.isNotEmpty)_tile(t('تحليل مقترح','Suggested analysis'),aiAnalysis),
  ]);
 }

 Widget _aiSavingPanel(){
  if(!_aiToolVisible)return const SizedBox.shrink();
  final ready=WaffraOnDeviceQwen.shared.isReady;
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   OutlinedButton(
    key:const Key('waffra-ai-saving-suggestions'),
    onPressed:ready&&!aiBusy?()=>unawaited(_generateAiSkill('savings')):null,
    child:Text(t('اقتراحات توفير بالذكاء الاصطناعي',
     'Generate AI savings suggestions'))),
   if(!ready)_paragraph(t('الميزة معطّلة لحين إعادة تفعيل الموديل.',
     'Disabled until the model is reactivated.')),
   if(ready&&aiSavings.isNotEmpty)_tile(t('اقتراحات قابلة للمراجعة',
     'Suggestions for review'),aiSavings),
  ]);
 }

 void _ask(){
  if(!WaffraOnDeviceQwen.shared.isReady)return;
  final q=question.toLowerCase().trim();
  if(q.isNotEmpty&&WaffraOnDeviceQwen.shared.isReady){
   unawaited(_generateAiSkill('ask',questionText:q));return;
  }
  if(q.isEmpty){setState(()=>answer=t('اكتب سؤال عن معاملاتك.','Ask about your transactions.'));return;}
  final now=today;
  final monthsBack=q.contains('3')||q.contains('٣')?3:q.contains('6')||q.contains('٦')?6:1;
  final rows=widget.entries.where((e)=>e.date.isAfter(
   DateTime(now.year,now.month-(monthsBack-1),1))).toList();
  final categories=widget.entries.map((e)=>e.category).toSet();
  String? matched;
  for(final category in categories){
   if(q.contains(category.toLowerCase().split(' / ').last.toLowerCase())){
    matched=category;break;
   }
  }
  final filtered=matched==null?rows:rows.where((e)=>e.category==matched).toList();
  final income=q.contains('دخل')||q.contains('income')||q.contains('راتب');
  final selected=filtered.where((e)=>income?e.income:!e.income).toList();
  final total=selected.fold<double>(0,(v,e)=>v+e.amount);
  setState(()=>answer=t('إجمالي '+(income?'الدخل':'المصروفات')+
   (matched==null?'':' في '+matched)+' خلال '+monthsBack.toString()+
   ' شهر: '+cash(total)+' ('+selected.length.toString()+' عملية).',
   'Recorded '+(income?'income':'expenses')+
   (matched==null?'':' in '+matched)+' over '+monthsBack.toString()+
   ' month(s): '+cash(total)+' ('+selected.length.toString()+' transactions).'));
 }
 Widget _assistant(){
  return _column([
   _head(titlesAr[4],'assistant',t('إجابات من سجلك المحلي فقط','Answers from verified local records')),
   const SizedBox(height:15),
   TextField(controller:input,maxLines:2,decoration:InputDecoration(
    hintText:t('مثال: صرفت كام على المطاعم آخر 3 شهور؟',
      'E.g. How much did I spend in 3 months?'),
    border:const OutlineInputBorder()),
    onChanged:(value)=>question=value),
   const SizedBox(height:10),
   Align(alignment:AlignmentDirectional.centerStart,child:FilledButton(onPressed:WaffraHaptics.tap(_ask),
    child:_label(t('اعرض الإجابة','Show answer'),color:Colors.white,bold:true))),
   if(answer.isNotEmpty)...[const SizedBox(height:12),_tile(t('نتيجة من المعاملات','From recorded transactions'),answer)],
   _paragraph(t('ده بحث حسابي محلي، مش ذكاء اصطناعي سحابي. لا نرسل بياناتك لأي خدمة.',
    'Local rule-based search, not cloud AI. No transaction data is sent out.')),
  ]);
 }
 Widget _seasons(){
  final perWeek=seasonTarget/math.max(1,daysToSeason/7);
  final seasonNames=t('رمضان • العيد • العودة للمدارس','Ramadan • Eid • Back to school');
  return _column([
   _head(titlesAr[5],'season',t('جهز ميزانية للمناسبات السعودية','Plan for local seasonal spending')),
   const SizedBox(height:15),_paragraph(seasonNames),
   const SizedBox(height:12),
   _slider(t('ميزانية المناسبة','Season target')+' ('+currencyLabel+')',
    seasonTarget,0,20000,(v)=>setState(()=>seasonTarget=v),divisions:80),
   _slider(t('الأيام المتبقية (تحددها أنت)','Days left (user-supplied)'),
    daysToSeason,7,365,(v)=>setState(()=>daysToSeason=v),divisions:51),
   _tile(t('ادخار أسبوعي مقترح','Suggested weekly saving'),cash(perWeek)),
   _paragraph(t('تاريخ المناسبة من اختيارك لتجنب افتراض مواعيد هجرية غير مؤكدة.',
    'You choose the occasion date; no assumed lunar calendar dates.')),
  ]);
 }
 Widget _projects(){
  final keywords=<List<String>>[
   ['travel','سفر','طيران','فندق','بنزين','مواصل'],
   ['home','سكن','منزل','اثاث','أثاث','كهرب','صيانة'],
   ['education','تعليم','مدرس','كتب','جامعة']];
  final matched=expenses.where((e)=>keywords[projectIndex].any((k)=>
    e.category.toLowerCase().contains(k)||e.title.toLowerCase().contains(k))).toList();
  final spent=matched.fold<double>(0,(v,e)=>v+e.amount);
  return _column([
   _head(titlesAr[6],'wallet',t('تجميع افتراضي دون تغيير أقسام المعاملات','Virtual groups, original categories unchanged')),
   const SizedBox(height:15),
   Wrap(spacing:6,runSpacing:6,children:List.generate(3,(i)=>ChoiceChip(
    label:_label(widget.english?projectsEn[i]:projectsAr[i]),
    selected:projectIndex==i,
    onSelected:WaffraHaptics.selection((_)=>setState(()=>projectIndex=i))))),
   const SizedBox(height:10),
   _tile(t('المصروفات المرتبطة بالمشروع','Matching project expenses'),cash(spent),
    note:t('من '+matched.length.toString()+' عملية محفوظة.',
       'From '+matched.length.toString()+' saved entries.')),
   ...matched.take(10).map((e)=>_tile(e.title,cash(e.amount))),
   _paragraph(t('التجميعات دي عرض تجريبي للقراءة فقط، مش محافظ مالية محفوظة.',
    'These are read-only example groupings, not persisted wallets.')),
  ]);
 }
 Widget _challenges(){
  final now=today;
  final current=waffraCategoryOutflows(widget.entries,
    start:DateTime(now.year,now.month));
  final previous=waffraCategoryOutflows(widget.entries,
    start:DateTime(now.year,now.month-1),end:DateTime(now.year,now.month));
  final currentTotal=current.values.fold<double>(0,(v,e)=>v+e);
  final previousTotal=previous.values.fold<double>(0,(v,e)=>v+e);
  final goal=previousTotal*(1-challengePercent/100);
  return _column([
   _head(titlesAr[7],'challenge',t('هدف لتقليل الصرف مقارنة بالشهر السابق','Compare spending with last month')),
   const SizedBox(height:15),
   _slider(t('خفض المصروفات بنسبة %','Reduce expenses by %'),
    challengePercent,0,50,(v)=>setState(()=>challengePercent=v),divisions:10),
   _tile(t('هدف المصروفات','Expense target'),cash(goal)),
   _tile(t('المصروفات هذا الشهر','Current month spending'),cash(currentTotal)),
   _tile(t('الأقل من الهدف أو المتجاوز له','Remaining until target'),
    cash(goal-currentTotal)),
   if(previousTotal==0)_paragraph(t('لا توجد بيانات للشهر السابق؛ أضف معاملات تجريبية للمقارنة.',
     'No previous month entries yet for a meaningful comparison.')),
   _aiSavingPanel(),
   _warning(),
  ]);
 }
 Widget _flow(){
  final by=waffraCategoryOutflows(widget.entries);
  final sorted=by.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
  final top=sorted.take(5).toList();
  final income=widget.entries.where((e)=>e.income)
    .fold<double>(0,(v,e)=>v+e.amount);
  return _column([
   _head(titlesAr[8],'flow',t('من دخلك إلى أبواب الصرف','From recorded income to category outflows')),
   const SizedBox(height:16),
   SizedBox(height:220,child:CustomPaint(
    painter:WaffraFlowArtwork(top.map((x)=>x.value).toList()),
    child:const SizedBox.expand())),
   const SizedBox(height:12),
   _tile(t('الدخل المسجل','Recorded income'),cash(income)),
   ...top.map((x)=>_tile(x.key,cash(x.value))),
   if(top.isEmpty)_paragraph(t('سجّل مصروفات لعرض خريطة التدفق.',
      'Record expenses to build your flow map.')),
   _warning(),
  ]);
 }
 Widget _emergency(){
  final essentials=expenses.where((e){
   final s=e.category.toLowerCase();
   return ['سكن','فاتورة','فواتير','صحة','مطعم','بقال','groceries','home',
     'rent','utilities','health'].any(s.contains);
  }).toList();
  final from=today.subtract(const Duration(days:90));
  final essential90=essentials.where((e)=>!e.date.isBefore(from))
   .fold<double>(0,(v,e)=>v+e.amount);
  final perMonth=essential90/3;
  final target=perMonth*emergencyMonths;
  final missing=math.max(0,target-existingEmergency);
  return _column([
   _head(titlesAr[9],'emergency',t('استعداد لثلاثة أو ستة أشهر من الضروريات',
     'Prepare for 3 or 6 months of necessities')),
   const SizedBox(height:16),
   SegmentedButton<int>(
    segments:[ButtonSegment(value:3,label:_label(t('3 أشهر','3 months'))),
      ButtonSegment(value:6,label:_label(t('6 أشهر','6 months')))],
    selected:{emergencyMonths},onSelectionChanged:WaffraHaptics.selectionRequired(
      (s)=>setState(()=>emergencyMonths=s.first))),
   const SizedBox(height:10),
   _slider(t('مدخرات الطوارئ الافتراضية','Assumed saved buffer')+' ('+currencyLabel+')',
    existingEmergency,0,50000,(v)=>setState(()=>existingEmergency=v),divisions:100),
   _tile(t('أساسيات الشهر (متوسط تقديري)','Monthly essentials estimate'),cash(perMonth)),
   _tile(t('حجم الصندوق المستهدف','Suggested fund'),cash(target)),
   _tile(t('المتبقي لتحقيق الهدف','Still to save'),cash(missing)),
   _paragraph(t('تقدير أولي من تصنيفات ضروريات آخر 90 يومًا؛ راجعه يدويًا.',
     'Estimate from essential categories over 90 days; review manually.')),
  ]);
 }
 Widget _body(int id){
  switch(id){
   case 0:return _runway();
   case 1:return _subscriptions();
   case 2:return _simulate();
   case 3:return _guardian();
   case 4:return _assistant();
   case 5:return _seasons();
   case 6:return _projects();
   case 7:return _challenges();
   case 8:return _flow();
   default:return _emergency();
  }
 }
 Widget _hub(){
  final names=widget.english?titlesEn:titlesAr;
  final details=widget.english?descEn:descAr;
  final dark=Theme.of(context).brightness==Brightness.dark;
  final reduced=MediaQuery.disableAnimationsOf(context);
  final duration=reduced?Duration.zero:const Duration(milliseconds:330);
  // Extra accordion sections reuse the existing analysis and live markets.
  // Negative indices avoid changing the ten tools' stable names and keys.
  final tiles=List<Widget?>.generate(types.length+2,(slot){
   final i=slot-2;
   if(i==4&&!_aiToolVisible)return null;
   final aiLocked=i==4&&!WaffraOnDeviceQwen.shared.isReady;
   final id=i==-2?'analysis':i==-1?'markets':types[i];
   final name=i==-2?t('التحليل المالي','Financial analysis'):
    i==-1?t('العملات والذهب والبترول','Currency, gold and oil markets'):names[i];
   final detail=i==-2?t('تحليلك وتوقعاتك المالية الفعلية','Insights and financial forecasts'):
    i==-1?t('أسعار الذهب والنفط وتحويل العملات','Gold, oil and exchange rates'):details[i];
   final illustration=i==-2?'investment':i==-1?'bank':types[i];
   final expanded=active==i;
   final sectionBody=expanded?Padding(
    key:Key('waffra-m268-expanded-'+id),
    padding:const EdgeInsets.fromLTRB(7,0,7,9),
    child:Column(children:[
     Divider(color:green.withValues(alpha:.23)),
     const SizedBox(height:7),
     if(i==-2)...[
       widget.analysisBuilder?.call(context)??
       _paragraph(t('التحليل متاح بعد فتح التطبيق ببيانات مالية مؤمنة.',
        'Financial insights require the verified app data source.')),
       const SizedBox(height:10),_aiAnalysisPanel(),
     ]
     else if(i==-1)const CurrencyConverterPage(embedded:true)
     else _body(i),
    ])):const SizedBox(width:double.infinity,height:0);
   return Padding(
    key:_sectionKeys[i],
    padding:const EdgeInsets.only(bottom:9),
    child:AnimatedContainer(
     key:Key('waffra-m268-accordion-'+id),
     duration:duration,curve:Curves.easeInOutCubic,
     decoration:BoxDecoration(
      color:aiLocked?Theme.of(context).disabledColor.withValues(alpha:.10):
       expanded?(dark?const Color(0xFF153C2D):const Color(0xFFE9F7ED)):
        Theme.of(context).cardColor,
      borderRadius:BorderRadius.circular(22),
      border:Border.all(color:green.withValues(alpha:expanded ? 0.48 : 0.15),
       width:expanded?1.6:1),
      boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:dark ? 0.09 : 0.055),
       blurRadius:expanded?17:8,offset:const Offset(0,3))]),
     child:Column(mainAxisSize:MainAxisSize.min,children:[
      Semantics(button:true,enabled:!aiLocked,
       label:name+' — '+detail+(aiLocked?' — disabled':expanded?' — open':' — closed'),
       child:InkWell(
        key:Key('waffra-m268-feature-'+id),
        borderRadius:BorderRadius.circular(22),
        onTap:aiLocked?null:WaffraHaptics.tap(()=>_activateSection(i)),
        child:Padding(
         padding:const EdgeInsets.symmetric(horizontal:10,vertical:8),
         child:Row(children:[
          Opacity(opacity:aiLocked?0.42:1,
            child:WaffraIllustration(topic:illustration,size:45)),
          const SizedBox(width:9),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
           children:[_label(name,bold:true,size:15,
              color:aiLocked?Theme.of(context).disabledColor:null),
            const SizedBox(height:2),_paragraph(aiLocked?
              t('الميزة معطّلة — أعد تفعيل الموديل',
                'Disabled — reactivate AI model'):detail)])), 
          const SizedBox(width:5),
          if(aiLocked)const Icon(Icons.lock_outline_rounded,
            color:Colors.grey,size:22)
          else AnimatedRotation(turns:expanded ? 0.5 : 0,duration:duration,
           child:Icon(Icons.keyboard_arrow_down_rounded,
             color:green,size:25)),
         ])))),
      // Reduced motion uses a direct layout swap, not a zero-duration
      // RenderAnimatedSize which can relayout itself during performLayout.
      ClipRect(child:reduced?sectionBody:AnimatedSize(
       duration:duration,curve:Curves.easeInOutCubic,
       alignment:Alignment.topCenter,child:sectionBody)),
     ])));
  }).whereType<Widget>().toList(growable:false);
  return ListView(
   key:const Key('waffra-m268-tools-scroll'),
   padding:const EdgeInsets.fromLTRB(14,16,14,30),
   physics:const ClampingScrollPhysics(parent:AlwaysScrollableScrollPhysics()),
   children:[
    Container(key:widget.tourHeadingKey,padding:const EdgeInsets.all(12),
     margin:const EdgeInsets.only(bottom:11),
     decoration:BoxDecoration(
      gradient:LinearGradient(colors:dark?
       [const Color(0xFF0A4838),const Color(0xFF145640)]:
       [const Color(0xFFE1F4E8),const Color(0xFFF8F6EF)]),
      borderRadius:BorderRadius.circular(23),
      border:Border.all(color:green.withValues(alpha:.20))),
     child:Row(children:[
      const WaffraIllustration(topic:'assistant',size:50),
      const SizedBox(width:10),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
       _label(t('أدوات وفرة الذكية','Waffra smart tools'),size:18,bold:true),
       const SizedBox(height:4),
       _paragraph(t('خطّط لميزانيتك، حلّل معاملاتك واستكشف أدواتك المالية.',
        'Plan your budget, analyze spending and explore financial tools.')),
      ]))])),
    if(!WaffraOnDeviceQwen.shared.isReady||aiBusy||aiStatus.isNotEmpty)...[
     _surface(_aiActivation()),
     const SizedBox(height:10),
    ],
    ...tiles,
    Card(
     key:const Key('m281-practical-tools-entry'),
     margin:const EdgeInsets.only(top:9,bottom:14),
     clipBehavior:Clip.antiAlias,
     child:ListTile(
      leading:const WaffraIllustration(topic:'tools',size:46),
      title:Text(t('أدوات مالية إضافية','Additional finance tools'),
        style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text(t('صحة البيانات • البحث • الفواتير • الإقفال • التشخيص',
        'Data health • Search • Receipts • Month close • Diagnostics')),
      trailing:const Icon(Icons.chevron_right),
      onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(
       builder:(_)=>WaffraPracticalToolsPage(
        english:widget.english,onNotice:widget.onNotice,
        entries:List<WaffraPracticalEntry>.unmodifiable(
         widget.entries.map((entry)=>WaffraPracticalEntry(
          id:entry.id,title:entry.title,category:entry.category,
          amount:entry.amount,income:entry.income,date:entry.date,
          notes:entry.notes,hasAttachment:entry.hasAttachment)))))),
     )),
   ]);
 }
 @override Widget build(BuildContext context){
  if(widget.embedded)return _hub();
  return Scaffold(
   appBar:AppBar(title:_label(t('أدوات وفرة الذكية','Waffra smart tools'),
      bold:true,size:18)),
   body:SafeArea(child:_hub()));
 }
}

/// Decorative five-branch money flow; text rows give precise accessible values.
class WaffraFlowArtwork extends CustomPainter{
 final List<double> amounts;
 const WaffraFlowArtwork(this.amounts);
 @override void paint(Canvas canvas,Size size){
  final total=amounts.fold<double>(0,(v,e)=>v+math.max(0,e));
  final background=Paint()..color=const Color(0xFFE4F4EB);
  canvas.drawRRect(RRect.fromRectAndRadius(
    Rect.fromLTWH(0,0,size.width,size.height),const Radius.circular(19)),background);
  final left=size.width*.12,right=size.width*.90;
  final initial=Offset(left,size.height*.5);
  final colors=[const Color(0xFF087A54),const Color(0xFF48A88B),
    const Color(0xFF81C4A8),const Color(0xFFB9DCC2),const Color(0xFFD8BA78)];
  canvas.drawRRect(RRect.fromRectAndRadius(
   Rect.fromLTWH(left-12,size.height*.33,24,size.height*.34),
    const Radius.circular(9)),Paint()..color=const Color(0xFF06543C));
  if(total<=0)return;
  for(var i=0;i<amounts.length;i++){
   final value=amounts[i];
   final y=size.height*(i+1)/(amounts.length+1);
   final width=math.max(4.0,math.min(22.0,40*value/total));
   final path=Path()..moveTo(initial.dx,initial.dy)
    ..cubicTo(size.width*.45,initial.dy,size.width*.47,y,right,y);
   canvas.drawPath(path,Paint()..color=colors[i%colors.length]
    ..style=PaintingStyle.stroke..strokeCap=StrokeCap.round..strokeWidth=width);
   canvas.drawCircle(Offset(right,y),9,Paint()..color=colors[i%colors.length]);
  }
 }
 @override bool shouldRepaint(covariant WaffraFlowArtwork old)=>
  old.amounts.length!=amounts.length||
  List.generate(amounts.length,(i)=>old.amounts[i]!=amounts[i]).contains(true);
}

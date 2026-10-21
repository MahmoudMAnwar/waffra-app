part of 'main.dart';

/// Standalone short-lived widget route: no full Waffra dashboard or navigation.
/// The user pastes text explicitly; analysis happens automatically (debounced).
class WaffraWidgetCaptureApp extends StatefulWidget {
 const WaffraWidgetCaptureApp({super.key});
 @override State<WaffraWidgetCaptureApp> createState()=>_WaffraWidgetCaptureState();
}

class _WidgetParsedSms {
 final String raw;
 final BankResult result;
 final bool duplicate;
 const _WidgetParsedSms(this.raw,this.result,this.duplicate);
 bool get valid=>result.amount!=null&&result.amount!>0;
}

class _WaffraWidgetCaptureState extends State<WaffraWidgetCaptureApp> {
 final _controller=TextEditingController();
 Timer? _debounce;
 bool _ready=false,_saving=false,_analyzing=false,_allowDuplicates=false,_success=false;
 bool _english=false,_dark=false;
 String? _error;
 int _savedIncome=0,_savedExpenses=0,_notSaved=0;
 List<_WidgetParsedSms> _results=[];
 Set<String> _knownHashes={};

 @override void initState(){
  super.initState();
  _loadSettings();
 }
 Future<void> _loadSettings()async{
  try{
   final prefs=await SharedPreferences.getInstance();
   await prefs.reload();
   if(!mounted)return;
   setState((){
    _english=prefs.getString('waffra_language')=='en';
    _dark=prefs.getBool('waffra_dark_mode')??false;
    _knownHashes=(prefs.getStringList('waffra_sms_hashes_v1')??[]).toSet();
    _ready=true;
   });
  }catch(e){
   if(mounted)setState((){_error='Cannot load local data / تعذر فتح البيانات المحلية';_ready=true;});
  }
 }

 void _onTextChanged(String value){
  _debounce?.cancel();
  setState((){
   _analyzing=value.trim().isNotEmpty;
   _error=null;_success=false;_results=[];
  });
  if(value.trim().isEmpty)return;
  _debounce=Timer(const Duration(milliseconds:420),(){
   if(!mounted||_controller.text.trim()!=value.trim())return;
   _analyze(value);
  });
 }

 void _analyze(String text){
  final pieces=splitBankMessages(text);
  if(pieces.length>100){
   setState((){
    _results=[];_analyzing=false;
    _error=_english?'Maximum 100 messages per paste.':'الحد الأقصى 100 رسالة في كل عملية لصق.';
   });
   return;
  }
  final inPaste=<String>{};
  final records=pieces.map((raw){
   final hash=bankSmsHash(raw);
   final duplicate=_knownHashes.contains(hash)||!inPaste.add(hash);
   return _WidgetParsedSms(raw,BankParser.parse(raw),duplicate);
  }).toList();
  if(!mounted)return;
  setState((){
   _results=records;
   _analyzing=false;
   if(records.isEmpty||records.every((r)=>!r.valid)){
    _error=_english?
      'No financial transactions detected. Edit the text and try again.':
      'لم يتم اكتشاف معاملات مالية. راجع النص وحاول مرة أخرى.';
   }
  });
 }

 List<_WidgetParsedSms> get _selected=>_results.where((r)=>r.valid&&
  (!r.duplicate||_allowDuplicates)).toList();

 int _sum(bool income)=>_selected.where((r)=>r.result.income==income)
  .fold<int>(0,(total,r)=>total+WaffraRecurringPolicy.toHalalas(r.result.amount!));

 Future<void> _pasteClipboard()async{
  final data=await Clipboard.getData(Clipboard.kTextPlain);
  final value=data?.text?.trim()??'';
  if(!mounted)return;
  if(value.isEmpty){
   setState(()=>_error=_english?'Clipboard is empty.':'الحافظة فارغة. انسخ الرسالة أولًا.');
   return;
  }
  _controller.text=value;
  _onTextChanged(value);
 }

 Future<void> _close()async {
  _debounce?.cancel();
  await closeWaffraWidgetWindow();
 }

 Future<void> _confirmAndSave()async{
  if(_saving||_analyzing||_selected.isEmpty)return;
  setState(()=>_saving=true);
  try{
   final prefs=await SharedPreferences.getInstance();
   await prefs.reload();
   final current=(jsonDecode(prefs.getString('entries')??'[]') as List)
    .map((x)=>MoneyEntry.fromJson(Map<String,dynamic>.from(x as Map))).toList();
   final oldHashes=(prefs.getStringList('waffra_sms_hashes_v1')??[]).toSet();
   final categoryRaw=prefs.getString('waffra_categories_v24');
   final categories=categoryRaw==null?defaultCategories():
    (jsonDecode(categoryRaw) as List)
     .map((x)=>BudgetCategory.fromJson(Map<String,dynamic>.from(x as Map))).toList();
   final newHashes=<String>{};
   final additions=<MoneyEntry>[];
   int savedInc=0,savedExp=0;
   for(final entry in _selected){
    final hash=bankSmsHash(entry.raw);
    if(!_allowDuplicates&&(oldHashes.contains(hash)||newHashes.contains(hash)))continue;
    final parsed=entry.result;
    final category=categories.any((c)=>c.income==parsed.income&&c.name==parsed.category)
      ?parsed.category
      :(categories.where((c)=>c.income==parsed.income).isNotEmpty
         ?categories.firstWhere((c)=>c.income==parsed.income).name:'أخرى');
    additions.add(MoneyEntry(
     id:'${newId()}_${additions.length}',
     title:'${parsed.title} — ${entry.raw.replaceAll(RegExp(r'\s+'),' ').trim()}',
     category:category,amount:parsed.amount!,income:parsed.income,
     date:bankSmsDate(entry.raw)??DateTime.now(),
    ));
    if(parsed.income){savedInc++;}else{savedExp++;}
    newHashes.add(hash);
   }
   if(additions.isEmpty){
    if(mounted)setState((){
     _saving=false;
     _error=_english?'These transactions have already been saved.':'هذه العمليات محفوظة بالفعل.';
    });
    return;
   }
   final merged=[...additions,...current];
   final saved=await prefs.setString('entries',jsonEncode(merged.map((e)=>e.toJson()).toList()));
   if(!saved)throw StateError('Local persistence did not confirm save');
   final hashesSaved=await prefs.setStringList('waffra_sms_hashes_v1',
    {...oldHashes,...newHashes}.toList());
   if(!hashesSaved)throw StateError('SMS hashes were not committed');
   await prefs.setString('waffra_widget_last_save_v1',DateTime.now().toIso8601String());

   // Refresh the circular balance immediately without opening the full app.
   final incomeHalalas=merged.where((e)=>e.income)
    .fold<int>(0,(sum,e)=>sum+WaffraRecurringPolicy.toHalalas(e.amount));
   final expenseHalalas=merged.where((e)=>!e.income)
    .fold<int>(0,(sum,e)=>sum+WaffraRecurringPolicy.toHalalas(e.amount));
   final net=incomeHalalas-expenseHalalas;
   final hidden=prefs.getBool('waffra_hide_amounts')??false;
   await refreshWaffraHomeWidget(
    balance:hidden?'***':formatWaffraMoney(net/100),
    negative:net<0,hidden:hidden,currency:_english?'SAR':'ريال');

   final ignored=_results.length-additions.length;
   if(!mounted)return;
   setState((){
    _knownHashes={...oldHashes,...newHashes};
    _savedIncome=savedInc;_savedExpenses=savedExp;_notSaved=ignored;
    _saving=false;_success=true;_error=null;
   });
   // If any message was not added, keep it open for review and retry.
   if(ignored==0){
    await Future<void>.delayed(const Duration(milliseconds:1200));
    if(mounted)await _close();
   }
  }catch(error){
   if(mounted)setState((){
    _saving=false;
    _error=_english?
     'Saving could not be fully confirmed. Review your transactions before retrying.':
     'تعذر تأكيد الحفظ بالكامل. راجع معاملاتك قبل إعادة المحاولة.';
   });
  }
 }

 @override void dispose(){
  _debounce?.cancel();
  _controller.dispose();
  super.dispose();
 }

 @override Widget build(BuildContext context){
  final theme=ThemeData(
   useMaterial3:true,
   brightness:_dark?Brightness.dark:Brightness.light,
   fontFamily:'Tajawal',
   colorScheme:ColorScheme.fromSeed(seedColor:emerald,
    brightness:_dark?Brightness.dark:Brightness.light),
  );
  return MaterialApp(
   debugShowCheckedModeBanner:false,
   theme:theme,
   locale:Locale(_english?'en':'ar'),
   home:Directionality(textDirection:_english?TextDirection.ltr:TextDirection.rtl,
    child:Scaffold(
     backgroundColor:Colors.transparent,
     resizeToAvoidBottomInset:true,
     body:SafeArea(child:Center(child:SingleChildScrollView(
      padding:const EdgeInsets.fromLTRB(16,20,16,20),
      child:TweenAnimationBuilder<double>(
       duration:const Duration(milliseconds:280),curve:Curves.easeOutBack,
       tween:Tween(begin:.88,end:1.0),
       builder:(ctx,scale,child)=>Transform.scale(scale:scale,child:child),
       child:Container(
        constraints:const BoxConstraints(maxWidth:420),
        decoration:BoxDecoration(
         color:_dark?const Color(0xFF171D1B):Colors.white,
         borderRadius:BorderRadius.circular(26),
         boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.20),blurRadius:25)],
         border:Border.all(color:emerald.withValues(alpha:.35))),
        child:Padding(padding:const EdgeInsets.all(18),
         child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[
           const Icon(Icons.auto_awesome,color:emerald,size:24),
           const SizedBox(width:7),
           Expanded(child:Text(_english?'Waffra • Bank SMS':'وفرة • إضافة رسالة بنكية',
            style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))),
           IconButton(icon:const Icon(Icons.close),onPressed:_saving?null:_close),
          ]),
          const SizedBox(height:8),
          Text(_english?'Paste a message for automatic analysis.':
            'الصق الرسالة البنكية وسيتم تحليلها تلقائيًا.',
           style:const TextStyle(fontSize:13)),
          const SizedBox(height:11),
          if(!_ready)const LinearProgressIndicator()
          else ...[
           TextField(
            key:const Key('waffra-widget-bank-message'),
            controller:_controller,onChanged:_onTextChanged,
            minLines:3,maxLines:6,
            decoration:InputDecoration(
             hintText:_english?'Paste your bank SMS here…':'الصق رسالتك البنكية هنا…',
             border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)),
             suffixIcon:_controller.text.isEmpty?null:IconButton(
              icon:const Icon(Icons.clear),onPressed:(){
               _controller.clear();_onTextChanged('');
              })),
           ),
           const SizedBox(height:9),
           OutlinedButton.icon(onPressed:_saving?null:_pasteClipboard,
            icon:const Icon(Icons.content_paste),
            label:Text(_english?'Paste from clipboard':'لصق الرسالة المنسوخة')),
           if(_analyzing)...[
            const SizedBox(height:11),
            const LinearProgressIndicator(),
            Text(_english?'Analyzing automatically…':'جارٍ التحليل تلقائيًا…'),
           ],
           if(_results.isNotEmpty&&!_analyzing&&!_success)...[
            const SizedBox(height:12),
            Text(_english?
             'Detected: ${_results.length} • Income: ${_selected.where((r)=>r.result.income).length} • Expenses: ${_selected.where((r)=>!r.result.income).length}':
             'المكتشفة: ${_results.length} • الدخل: ${_selected.where((r)=>r.result.income).length} • المصروفات: ${_selected.where((r)=>!r.result.income).length}',
             style:const TextStyle(fontWeight:FontWeight.bold)),
            const SizedBox(height:6),
            Text(_english?
             'Income: ${formatWaffraMoney(_sum(true)/100)} SAR • Expenses: ${formatWaffraMoney(_sum(false)/100)} SAR':
             'الدخل: ${formatWaffraMoney(_sum(true)/100)} ريال • المصروف: ${formatWaffraMoney(_sum(false)/100)} ريال',
             style:const TextStyle(fontSize:12)),
            if(_results.any((r)=>r.duplicate))CheckboxListTile(
             contentPadding:EdgeInsets.zero,
             value:_allowDuplicates,onChanged:_saving?null:(v)=>setState(()=>_allowDuplicates=v??false),
             title:Text(_english?'Allow duplicate SMS transactions':'السماح بإضافة الرسائل المكررة',
              style:const TextStyle(fontSize:12)),
            ),
            ConstrainedBox(constraints:const BoxConstraints(maxHeight:126),
             child:ListView(shrinkWrap:true,children:[
              for(final record in _results)
               ListTile(
                dense:true,contentPadding:EdgeInsets.zero,
                leading:Icon(record.valid?
                 (record.result.income?Icons.trending_up:Icons.trending_down):
                 Icons.error_outline,color:record.valid?emerald:Colors.orange),
                title:Text(record.result.title,maxLines:1,overflow:TextOverflow.ellipsis),
                subtitle:Text(record.valid?
                 '${record.result.category} • ${formatWaffraMoney(record.result.amount!)}':
                 (_english?'Unrecognized amount':'لم يتم التعرف على المبلغ'),
                 maxLines:1,overflow:TextOverflow.ellipsis),
                trailing:record.duplicate?const Icon(Icons.copy,color:Colors.orange,size:19):null,
               ),
             ])),
            const SizedBox(height:9),
            FilledButton.icon(
             onPressed:_selected.isEmpty||_saving?null:_confirmAndSave,
             icon:const Icon(Icons.check_circle_outline),
             label:Text(_english?'Confirm and save':'تأكيد إضافة العمليات')),
           ],
           if(_success)...[
            const SizedBox(height:10),
            const Icon(Icons.check_circle_rounded,color:emerald,size:43),
            Text(_english?'Transactions saved successfully':'تم حفظ العمليات بنجاح',
             textAlign:TextAlign.center,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
            Text(_english?
             'Income: $_savedIncome • Expenses: $_savedExpenses • Not added: $_notSaved':
             'الدخل: $_savedIncome • المصروف: $_savedExpenses • لم تُضف: $_notSaved',
             textAlign:TextAlign.center),
            if(_notSaved>0)Text(
             _english?'Review remaining messages before closing.':
             'راجع الرسائل غير المضافة قبل الإغلاق.',
             textAlign:TextAlign.center,style:const TextStyle(color:Colors.deepOrange)),
           ],
           if(_error!=null)Padding(padding:const EdgeInsets.only(top:9),
            child:Text(_error!,style:const TextStyle(color:Colors.red))),
          ],
         ]),
        ),
       ),
      ),
     ))),
    )),
  );
 }
}

part of 'main.dart';

// M687: exact original report method in the same library.
extension _WaffraHomeReportModule on _HomeScreenState {
 Future<void> exportEntriesPdf(List<MoneyEntry> items,String title,{
  bool analytics=false,String? activityFilter,
 })async {
  // M652: never fabricate transfers or savings by recoding income/expenses.
  // Read the *same* owner-scoped SQLCipher account journals as Home.
  var pdfTransfers=<WaffraInternalTransferHistory>[];
  var pdfSavings=<WaffraVerifiedGoalMovement>[];
  if(!analytics && _m468VerifiedAccountsLoaded){
   final wantsTransfers=activityFilter==null||
    activityFilter=='الكل'||activityFilter=='التحويلات';
   final wantsSavings=activityFilter==null||
    activityFilter=='الكل'||activityFilter=='الادخار';
   if(wantsTransfers||wantsSavings){
    try{
     final account=_m467SelectedAccount;
     if(wantsTransfers){
      pdfTransfers=await _m648HomeTransfers(account);
     }
     if(wantsSavings){
      pdfSavings=await _m649HomeSavings(account);
     }
     if(activityFilter!=null){
      bool keep(DateTime? date,int amountMinor,List<String> terms){
       final q=search.trim();
       return waffraSearchAny(terms,q)&&
        (transactionsDateRange==null||date==null||
         (!date.isBefore(transactionsDateRange!.start)&&
          date.isBefore(transactionsDateRange!.end.add(
           const Duration(days:1)))))&&
        (minTransactionAmount==null||
         amountMinor>=minTransactionAmount!*100)&&
        (maxTransactionAmount==null||
         amountMinor<=maxTransactionAmount!*100);
      }
      final names={for(final a in _m467Accounts)a.id:_m647VerifiedAccountLabel(a)};
      pdfTransfers=pdfTransfers.where((t)=>keep(
       DateTime.tryParse(t.occurredIso),t.amountMinor,[
        names[t.fromAccountId]??'',names[t.toAccountId]??'',
        t.note,waffraIsEnglish?'Transfer':'تحويل',
       ])).toList(growable:false);
      pdfSavings=pdfSavings.where((m)=>keep(
       DateTime.tryParse(m.occurredIso),m.amountMinor,[
        m.goalName,m.kind,waffraIsEnglish?'Savings':'ادخار',
       ])).toList(growable:false);
     }
    }catch(error){
     debugPrint('M652 verified activity PDF read rejected: ${error.runtimeType}');
     if(mounted)snack(context,waffraIsEnglish?
      'Could not verify transfers or savings for PDF export. Retry.':
      'تعذر التحقق من التحويلات أو الادخار قبل تصدير التقرير.',
      isError:true);
     return;
    }
   }
  }
  if(items.isEmpty&&pdfTransfers.isEmpty&&pdfSavings.isEmpty){
   if(mounted)snack(context,analytics
    ?(waffraIsEnglish?'Cannot export empty analytics.':
       'لا يمكن تصدير تحليلات بدون عمليات مالية.'):
     (waffraIsEnglish?'No verified transactions to export.':
       'لا توجد عمليات مالية موثقة لتصديرها.'));
   return;
  }
  bool exportDialogOpen=false;
  final exportNavigator=Navigator.of(context,rootNavigator:true);
  try{
   exportDialogOpen=true;
   unawaited(showWaffraDialog<void>(context:context,useRootNavigator:true,barrierDismissible:false,
    barrierColor:Colors.black.withValues(alpha:.22),
    builder:(dialogContext)=>PopScope(canPop:false,child:BackdropFilter(
     filter:ui.ImageFilter.blur(sigmaX:9,sigmaY:9),
     child:Center(child:Material(color:Colors.transparent,child:Container(
      width:MediaQuery.of(dialogContext).size.width*.82,
      padding:const EdgeInsets.all(28),
      decoration:BoxDecoration(color:Theme.of(dialogContext).cardColor,
       borderRadius:BorderRadius.circular(26),
       border:Border.fromBorderSide(waffraDialogOutline(Theme.of(dialogContext).brightness))),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
       const SizedBox(height:8),
       const Icon(Icons.picture_as_pdf_rounded,size:63,color:emerald),
       const SizedBox(height:18),
       const SizedBox(width:48,height:48,child:CircularProgressIndicator(strokeWidth:4.5,color:emerald)),
       const SizedBox(height:22),
       WaffraText(waffraIsEnglish?'Exporting PDF report...':'يتم الآن تصدير التقرير إلى PDF',
        textAlign:TextAlign.center,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
       const SizedBox(height:9),
       WaffraText(waffraIsEnglish?'Please wait while your report is prepared.':
        'يرجى الانتظار أثناء تجهيز التقرير.',textAlign:TextAlign.center),
      ]),
     )))),
    )));
   await Future<void>.delayed(const Duration(milliseconds:350));
   // Embed a full Arabic Unicode fallback; Tajawal stays the primary typeface.
   final font=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Regular.ttf'));
   final bold=pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
   final english=waffraIsEnglish;
   // Capture a single VERIFIED conversion for the entire PDF.
   // Never relabel stored SAR as EGP/USD when no exchange rate exists.
   final pdfQuote=WaffraDisplayCurrency.active.value;
   if(!pdfQuote.verified){
    throw StateError('Verified display FX rate required for PDF export.');
   }
   final pdfCurrency=pdfQuote.code;
   final pdfCurrencyAr=waffraCountry(pdfCurrency).symbolAr;
   // Embed the exact approved PNG, rather than using a PDF font glyph
   // that can become an unsupported square in generated reports.
   final pdfRiyalIcon=pw.MemoryImage(
    (await rootBundle.load(waffraRiyalAsset)).buffer.asUint8List());
   pw.Widget pdfCurrencyMark({double size=9,PdfColor color=PdfColors.teal900}) {
    if(pdfCurrency=='SAR')return pw.Image(pdfRiyalIcon,
     width:size,height:size,fit:pw.BoxFit.contain);
    return pw.Text(english?pdfCurrency:pdfCurrencyAr,
     style:pw.TextStyle(font:bold,fontSize:size*.8,color:color));
   }
   pw.Widget pdfMoney(String text,{double size=9,
      PdfColor color=PdfColors.teal900})=>pw.Directionality(
    textDirection:pw.TextDirection.ltr,
    child:pw.Row(
     mainAxisSize:pw.MainAxisSize.min,
     mainAxisAlignment:pw.MainAxisAlignment.center,children:[
      pdfCurrencyMark(size:size,color:color),
      pw.SizedBox(width:3),
      pw.Text(text,style:pw.TextStyle(font:bold,fontSize:size,color:color),
       textDirection:pw.TextDirection.ltr),
     ]));
   pw.Widget pdfMoneyHeader(String header,{double size=9,
      PdfColor color=PdfColors.white}){
    if(english||pdfCurrency!='SAR')return pw.Text(header,
     textAlign:pw.TextAlign.center,
     style:pw.TextStyle(font:bold,fontSize:size,color:color));
    final label=header.replaceAll('($pdfCurrencyAr)','').trim();
    if(label==header)return pw.Text(header,
     textAlign:pw.TextAlign.center,
     style:pw.TextStyle(font:bold,fontSize:size,color:color));
    return pw.Row(mainAxisSize:pw.MainAxisSize.min,
     mainAxisAlignment:pw.MainAxisAlignment.center,children:[
      pw.Text(label,style:pw.TextStyle(font:bold,fontSize:size,color:color)),
      pw.SizedBox(width:3),pw.Container(
       padding:const pw.EdgeInsets.all(1),color:PdfColors.white,
       child:pdfCurrencyMark(size:size)),
     ]);
   }
   double pdfAmount(num sar){
    final result=pdfQuote.fromSar(sar);
    if(result==null||!result.isFinite){
     throw StateError('Unverified PDF currency conversion refused.');
    }
    return result;
   }
   final exportedAt=DateTime.now();
   // Keep stored descriptions unchanged; sanitize only the exported PDF copy.
   String pdfClean(String input)=>sanitizeWaffraPdfText(input);
      String fmt(num number){
    final n=pdfAmount(number);
    if(n==n.roundToDouble())return n.toStringAsFixed(0);
    return n.toStringAsFixed(2);
   }
   // Keep the approved two-page PDF as the canonical, bundled design asset.
   // The generated export below still supplies live financial values.
   // Rasterize the branded PDF template once, then draw it as the
   // background of every exported report page. Financial data stays dynamic.
   final templateData=await rootBundle.load('assets/Waffra_Riyadh_Report_Template.pdf');
   if(templateData.lengthInBytes==0)throw StateError('Waffra PDF template is empty');
   pw.MemoryImage? reportBackground;
   await for(final raster in Printing.raster(
     templateData.buffer.asUint8List(),pages:[0],dpi:120)){
    reportBackground=pw.MemoryImage(await raster.toPng());
    break;
   }
   if(reportBackground==null)throw StateError('Unable to render Waffra PDF template');
   final brandedBackground=reportBackground;
   final doc=pw.Document();
   final totalIncome=sum(items,true),totalExpenses=sum(items,false);
   final categoryTotals=<String,double>{};
   for(final e in items.where((e)=>!e.income)){
    final label=waffraEntryReportCategory(e);
    categoryTotals[label]=(categoryTotals[label]??0)+e.amount;
   }
   pw.Widget summary(String label,double value,PdfColor bg)=>pw.Expanded(child:pw.Container(
    padding:const pw.EdgeInsets.all(10),decoration:pw.BoxDecoration(color:bg,borderRadius:pw.BorderRadius.circular(7)),
    child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
     pw.Text(waffraTr(label),style:pw.TextStyle(font:bold,fontSize:10,color:PdfColors.teal900)),
     pw.SizedBox(height:5),pdfMoney(fmt(value),size:15),
    ])));
   // Explicit script direction prevents mixed Arabic/Latin SMS text from
   // overlapping or reversing adjacent numbers in the PDF viewer.
   pw.Widget pdfCell(String raw,{bool rtl=false,bool center=false,
      bool monetary=false})=>
    pw.Padding(padding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:7),
     child:monetary?pdfMoney(pdfClean(raw),size:9,color:PdfColors.black):
     pw.Text(pdfClean(raw),
      textDirection:rtl?pw.TextDirection.rtl:pw.TextDirection.ltr,
      textAlign:center?pw.TextAlign.center:(rtl?pw.TextAlign.right:pw.TextAlign.left),
      style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.black)));
   // Split SMS into readable script-specific lines. Long mixed Arabic/Latin
   // descriptions must wrap inside the description column, never overflow.
   // Flutter/Skia shapes mixed Arabic, English and numbers reliably.
   // The pdf package can create unsupported-glyph boxes for these same runs.
   // Rasterize ONLY the transaction description text at 2x resolution with
   // the app's Tajawal font, leaving dates, categories and amounts as PDF text.
   Future<(pw.MemoryImage,double)> pdfDescriptionArtwork(String raw)async {
    const scale=2.0,logicalWidth=460.0;
    final description=pdfClean(raw);
    final painter=TextPainter(
     text:TextSpan(text:description.isEmpty?'—':description,
      style:const TextStyle(fontFamily:'Tajawal',fontSize:18,
       height:1.38,color:Colors.black)),
     textDirection:english?TextDirection.ltr:TextDirection.rtl,
     textAlign:english?TextAlign.left:TextAlign.right,
     maxLines:8,ellipsis:'...',
    );
    // TextPainter otherwise shrinks to its longest run, so TextAlign.right
    // has no spare horizontal space to align against. Force the whole
    // raster canvas width (including mixed Arabic/Latin bank SMS).
    painter.layout(minWidth:logicalWidth,maxWidth:logicalWidth);
    final recorder=ui.PictureRecorder();
    final canvas=Canvas(recorder);
    canvas.scale(scale,scale);
    painter.paint(canvas,Offset.zero);
    final picture=recorder.endRecording();
    final raster=await picture.toImage(
     (logicalWidth*scale).ceil(),max(1,(painter.height*scale).ceil()));
    final bytes=await raster.toByteData(format:ui.ImageByteFormat.png);
    final height=max(12.0,painter.height/scale);
    painter.dispose();
    raster.dispose();
    picture.dispose();
    if(bytes==null)throw StateError('Unable to rasterize bank SMS description');
    return (pw.MemoryImage(bytes.buffer.asUint8List()),height);
   }
   // The approved branded template remains unchanged; only its content layout is improved.
   final pageTheme=pw.PageTheme(
    pageFormat:const PdfPageFormat(900,600),
    margin:const pw.EdgeInsets.fromLTRB(36,115,36,90),
    buildBackground:(ctx)=>pw.FullPage(ignoreMargins:true,
     child:pw.Image(brandedBackground,fit:pw.BoxFit.fill)),
    theme:pw.ThemeData.withFont(base:font,bold:bold),
    textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
   );
   pw.Widget heading(String ar,String en)=>pw.Padding(
    padding:const pw.EdgeInsets.only(bottom:10),
    child:pw.Text(english?en:ar,style:pw.TextStyle(font:bold,fontSize:15,color:PdfColors.teal900)));
   // M662: collect all non-analytics sections in ONE flowing MultiPage.
   // Separate addPage calls forced goals/recurring onto new half-empty sheets.
   final reportSections=<pw.Widget>[];
   if(!analytics&&items.isNotEmpty){
    final ordered=items.toList()..sort((a,b)=>b.date.compareTo(a.date));
    final descriptions=<(pw.MemoryImage,double)>[];
    for(final e in ordered){
     // The 5,000 goal purchase includes a 2,000 earmark and only a 3,000
     // cash debit. Preserve that typed attribution in PDF without raw notes.
     final description=e.sourceType=='goal_due'?
      e.title+'\n'+(english?'Goal wallet: ':'محفظة الهدف: ')+
      fmt(e.goalWalletPaidMinor/100)+' | '+
      (english?'Money account: ':'الحساب المالي: ')+
      fmt(waffraGoalDueCashMinor(e)/100):e.title;
     descriptions.add(await pdfDescriptionArtwork(description));
    }
    reportSections.addAll([
      heading('تقرير الدخل والمصروفات','Income & Expenses Report'),
      pw.Row(children:[summary('إجمالي الدخل',totalIncome,PdfColors.green50),pw.SizedBox(width:8),
       summary('إجمالي المصروفات',totalExpenses,PdfColors.red50),pw.SizedBox(width:8),
       summary('الصافي',totalIncome-totalExpenses,PdfColors.amber50)]),
      pw.SizedBox(height:14),
      heading('تفاصيل العمليات','Transactions'),
      pw.Table(
       border:pw.TableBorder.all(color:PdfColors.grey400,width:0.4),
       columnWidths:english?
        {0:const pw.FixedColumnWidth(54),1:const pw.FixedColumnWidth(81),
         2:const pw.FixedColumnWidth(61),3:const pw.FixedColumnWidth(90),
         4:const pw.FlexColumnWidth(3),5:const pw.FixedColumnWidth(83)}:
        {0:const pw.FixedColumnWidth(83),1:const pw.FlexColumnWidth(3),
         2:const pw.FixedColumnWidth(90),3:const pw.FixedColumnWidth(61),
         4:const pw.FixedColumnWidth(81),5:const pw.FixedColumnWidth(54)},
       children:[
        pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
         children:(english?['No.','Date','Type','Category','Description','Amount ($pdfCurrency)']:
          ['المبلغ ($pdfCurrencyAr)','الوصف','القسم','النوع','التاريخ','رقم المعاملة'])
          .map((h)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
           child:pdfMoneyHeader(h,size:10))).toList()),
        ...ordered.asMap().entries.map((row){
         final e=row.value,art=descriptions[row.key];
         final orderedCells=<pw.Widget>[
          pdfCell('${row.key+1}',center:true),
          pdfCell(dayText(e.date),center:true),
          pdfCell(e.sourceType=='recurring'||e.sourceType=='goal_due'?
           (english?'Paid due':'استحقاق مدفوع'):
           (english?(e.income?'Income':'Expense'):(e.income?'دخل':'مصروف')),
           rtl:!english),
          pdfCell(e.sourceType=='goal_due'?
           (english?'Goal due':'استحقاق هدف'):
           waffraTr(e.category),rtl:!english),
          pw.Container(
           alignment:english?pw.Alignment.centerLeft:pw.Alignment.centerRight,
           padding:const pw.EdgeInsets.symmetric(horizontal:6,vertical:7),
           child:pw.Directionality(
            textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
            child:pw.Align(
             alignment:english?pw.Alignment.centerLeft:pw.Alignment.centerRight,
             child:pw.Image(art.$1,height:art.$2,fit:pw.BoxFit.scaleDown)))),
          pdfCell('${e.income?'+':'-'}${fmt(e.amount)}',center:true,monetary:true),
         ];
         return pw.TableRow(
          decoration:pw.BoxDecoration(color:
           (e.sourceType=='recurring'||e.sourceType=='goal_due')?
            PdfColor.fromInt(const Color(0xFFEFE9F8).toARGB32()):
            PdfColor.fromInt(e.income?waffraIncomeBackground.toARGB32():waffraExpenseBackground.toARGB32())),
          children:english?orderedCells:orderedCells.reversed.toList(),
         );
        }),
       ],
      ),
     ]);
   }else if(analytics){
    // "Financial Analytics" and "Smart Analysis" now render the very
    // same chart datasets shown by their respective Flutter screens.
    final smart=title.contains('آخر 90 يوم')||title.contains('Last 90 days');
    final yearly=title.contains('سنوي');
    final smartData=smart?waffraSmartChartData(items,exportedAt):null;
    final buckets=smart?smartData!.periods:List<(double,double)>.generate(
     yearly?12:5,(i){
      final slice=items.where((e)=>yearly?
       e.date.month==i+1:((e.date.day-1)~/7)==i);
      return (sum(slice,true),sum(slice,false));
     });
    final maximum=buckets.fold<double>(1,(n,p)=>max(n,max(p.$1,p.$2)));
    final top=(categoryTotals.entries.toList()
     ..sort((a,b)=>b.value.compareTo(a.value))).take(5).toList();
    final chartSlices=Map<String,double>.fromEntries(top);
    pw.Widget legend()=>pw.Row(mainAxisAlignment:pw.MainAxisAlignment.center,
     children:[
      pw.Container(width:10,height:10,color:PdfColors.teal800),
      pw.SizedBox(width:5),
      pw.Text(english?'Income':'دخل',
       style:pw.TextStyle(font:font,fontSize:10)),
      pw.SizedBox(width:18),
      pw.Container(width:10,height:10,color:PdfColors.deepOrange),
      pw.SizedBox(width:5),
      pw.Text(english?'Expenses':'مصروفات',
       style:pw.TextStyle(font:font,fontSize:10)),
     ]);
    pw.Widget progressBar(double value,PdfColor color)=>pw.Expanded(
     child:pw.Row(children:[
      pw.Expanded(flex:max(1,(value/maximum*100).round()),
       child:pw.Container(height:12,color:color)),
      pw.Expanded(flex:max(1,100-(value/maximum*100).round()),
       child:pw.SizedBox(height:12)),
     ]));
    pw.Widget panel(String ar,String en,List<pw.Widget> widgets)=>pw.Container(
     margin:const pw.EdgeInsets.only(bottom:10),
     padding:const pw.EdgeInsets.all(12),
     decoration:pw.BoxDecoration(
      border:pw.Border.all(color:PdfColors.grey400,width:.6),
      borderRadius:pw.BorderRadius.circular(8)),
     child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.stretch,
      children:[heading(ar,en),...widgets]));
    // Source-value tables are populated from the same buckets as the charts.
    pw.Widget miniTable(List<String> labels,List<List<String>> rows){
     bool isMoneyColumn(String label)=>[
      'Income','Expenses','Amount','الدخل','المصروفات','المبلغ',
     ].any(label.contains);
     pw.Widget cell(String v,{bool header=false,bool monetary=false})=>pw.Padding(
      padding:const pw.EdgeInsets.symmetric(horizontal:5,vertical:4),
      child:header?pdfMoneyHeader(v,size:8):
       monetary?pdfMoney(pdfClean(v),size:8):
       pw.Text(pdfClean(v),
        textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
        textAlign:pw.TextAlign.center,
        style:pw.TextStyle(font:font,fontSize:8,
         color:PdfColors.teal900)));
     return pw.Table(border:pw.TableBorder.all(color:PdfColors.grey300,width:.4),
      children:[
       pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
        children:(english?labels.asMap().entries:
           labels.asMap().entries.toList().reversed)
         .map((e)=>cell(e.value,header:true,
          monetary:isMoneyColumn(e.value))).toList()),
       ...rows.map((row)=>pw.TableRow(
        children:(english?row.asMap().entries:
           row.asMap().entries.toList().reversed).map((e)=>cell(e.value,
         monetary:isMoneyColumn(labels[e.key]))).toList())),
      ]);
    }
    pw.Widget dataTable(List<String> labels,List<List<String>> rows)=>
     rows.length<=6?miniTable(labels,rows):
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
       pw.Expanded(child:miniTable(labels,rows.take(6).toList())),
       pw.SizedBox(width:8),
       pw.Expanded(child:miniTable(labels,rows.skip(6).toList())),
      ]);
    final valueHeaders=english?
     ['Period','Income ($pdfCurrency)','Expenses ($pdfCurrency)']:
     ['الفترة','الدخل ($pdfCurrencyAr)','المصروفات ($pdfCurrencyAr)'];
    final periodValues=List<List<String>>.generate(buckets.length,(i)=>[
     (english?(yearly?'Month ':'Period '):(yearly?'شهر ':'فترة '))+(i+1).toString(),
     fmt(buckets[i].$1),fmt(buckets[i].$2),
    ]);
    final parts=<pw.Widget>[
     heading('تقرير الرسومات والتحليلات المالية','Financial Charts Report'),
     if(smart)...[
      panel('اتجاه الدخل والمصروفات - آخر 90 يوم',
       'Income vs Expenses - Last 90 Days',[
       ...List.generate(3,(i)=>pw.Padding(
        padding:const pw.EdgeInsets.symmetric(vertical:5),
        child:pw.Row(children:[
         pw.SizedBox(width:72,child:pw.Text(
          english?'Period ${i+1}':'فترة ${i+1}',
          style:pw.TextStyle(font:font,fontSize:10))),
         pw.Expanded(child:pw.Column(children:[
          pw.Row(children:[
           pw.SizedBox(width:40,child:pw.Text(english?'Income':'دخل',
            style:pw.TextStyle(font:font,fontSize:8))),
           progressBar(buckets[i].$1,PdfColors.teal800),
           pw.SizedBox(width:61,child:pdfMoney(fmt(buckets[i].$1),size:9))]),
          pw.SizedBox(height:4),
          pw.Row(children:[
           pw.SizedBox(width:40,child:pw.Text(english?'Expense':'مصروف',
            style:pw.TextStyle(font:font,fontSize:8))),
           progressBar(buckets[i].$2,PdfColors.deepOrange),
           pw.SizedBox(width:61,child:pdfMoney(fmt(buckets[i].$2),size:9))]),
         ])),
        ]))),
       pw.SizedBox(height:5),legend(),
       pw.SizedBox(height:8),dataTable(valueHeaders,periodValues),
      ]),
      panel('اتجاه المصروفات الأسبوعية','Weekly Spending Trend',[
       pw.Center(child:pw.SvgImage(
        svg:weeklySpendSvg(smartData!.weeklySpend.map(pdfAmount).toList()),width:620,height:130)),
       pw.Center(child:pw.Text(english?
        'Four weeks: oldest to newest':'أربعة أسابيع من الأقدم إلى الأحدث',
        style:pw.TextStyle(font:font,fontSize:10))),
       pw.SizedBox(height:8),
       dataTable(english?['Week','Expenses ($pdfCurrency)']:
        ['الأسبوع','المصروفات ($pdfCurrencyAr)'],
        List<List<String>>.generate(smartData.weeklySpend.length,(i)=>[
         (english?'Week ':'الأسبوع ')+(i+1).toString(),
         fmt(smartData.weeklySpend[i]),
        ])),
      ]),
     ]else...[
      panel(yearly?'الدخل والمصروفات حسب الشهر':'الدخل والمصروفات حسب الأسبوع',
       yearly?'Income vs Expenses by Month':'Income vs Expenses by Week',[
       pw.Center(child:pw.SvgImage(
        svg:pairedBarChartSvg(buckets.map((p)=>(pdfAmount(p.$1),pdfAmount(p.$2))).toList()),width:680,height:155)),
       pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceEvenly,
        children:List.generate(buckets.length,(i)=>pw.Expanded(
         child:pw.Text(
          english?(yearly?'M${i+1}':'W${i+1}'):
           (yearly?'ش${i+1}':'أ${i+1}'),
          textAlign:pw.TextAlign.center,
          style:pw.TextStyle(font:font,fontSize:9))))),
       pw.SizedBox(height:8),legend(),
       pw.SizedBox(height:8),dataTable(valueHeaders,periodValues),
      ]),
     ],
     if(top.isNotEmpty)panel(
      'توزيع المصروفات حسب الأقسام','Expenses by Category',[
      pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.center,children:[
       pw.SizedBox(width:190,height:160,
        child:pw.SvgImage(svg:expensePieSvg(chartSlices),width:160,height:160)),
       pw.SizedBox(width:20),
       pw.Expanded(child:pw.Column(
        crossAxisAlignment:pw.CrossAxisAlignment.stretch,
        children:top.map((entry){
         final color=PdfColor.fromInt(categoryFor(entry.key,false).color);
         return pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),
          child:pw.Row(children:[
           pw.Container(width:10,height:10,color:color),
           pw.SizedBox(width:6),
           pw.Expanded(child:pw.Text(pdfClean(waffraTr(entry.key)),
            maxLines:2,style:pw.TextStyle(font:font,fontSize:9))),
           pw.SizedBox(width:7),
           pw.Text('${(entry.value/totalExpenses*100).toStringAsFixed(1)}%',
            style:pw.TextStyle(font:bold,fontSize:9)),
          ]));
        }).toList())),
      ]),
       pw.SizedBox(height:8),
       dataTable(english?['Category','Amount ($pdfCurrency)','Share']:
        ['القسم','المبلغ ($pdfCurrencyAr)','النسبة'],
        top.map((e)=><String>[
         waffraTr(e.key),fmt(e.value),
         (e.value/totalExpenses*100).toStringAsFixed(1)+'%',
        ]).toList()),
     ]),
    ];
    // MultiPage split the chart header and artwork into separate pages,
    // displaying a framed but apparently empty chart on the previous page.
    // A chart, its caption and its populated source table are inseparable.
    final chartPanels=parts.skip(1).toList(growable:false);
    for(var i=0;i<chartPanels.length;i++){
     final index=i+1;
     doc.addPage(pw.Page(pageTheme:pageTheme,
      build:(ctx)=>pw.Column(
       crossAxisAlignment:pw.CrossAxisAlignment.stretch,
       children:[
        heading('تقرير الرسومات والتحليلات المالية','Financial Charts Report'),
        chartPanels[i],
        pw.Spacer(),
        pw.Align(alignment:pw.Alignment.centerRight,
         child:pw.Text(index.toString()+' / '+chartPanels.length.toString(),
          style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.teal900))),
       ],
      )));
    }
   }
   // M652: transfers and wallet movements form separate sections, never
   // become income, expenses or budget line items. All values are verified.
   if(!analytics&&pdfTransfers.isNotEmpty){
    final labels={for(final a in _m467Accounts)a.id:_m647VerifiedAccountLabel(a)};
    final ordered=pdfTransfers.toList()
     ..sort((a,b)=>b.occurredIso.compareTo(a.occurredIso));
    reportSections.addAll([
     pw.SizedBox(height:8),
     heading('التحويلات بين حساباتي','Transfers between my accounts'),
     pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),
      child:pw.Text(english?
       'Transfers do not increase income or expenses.':
       'أصل التحويل لا يُحسب دخلًا أو مصروفًا.',
       style:pw.TextStyle(font:font,fontSize:10,color:PdfColors.teal900))),
     pw.Table(border:pw.TableBorder.all(color:PdfColors.grey400,width:.4),
      children:[
       pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
        children:(english?['Date','From','To','Details','Amount']:
         ['المبلغ','تفاصيل','إلى الحساب','من الحساب','التاريخ'])
        .map((v)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
         child:pw.Text(v,textAlign:pw.TextAlign.center,
          textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
          style:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.white))))
         .toList()),
       ...ordered.map((t){
        final when=DateTime.tryParse(t.occurredIso);
        final cells=<pw.Widget>[
         pdfCell(when==null?t.occurredIso:dayText(when),center:true),
         pdfCell(labels[t.fromAccountId]??(english?'Unknown':'حساب غير متاح'),
          rtl:!english),
         pdfCell(labels[t.toAccountId]??(english?'Unknown':'حساب غير متاح'),
          rtl:!english),
         pdfCell(t.note,rtl:!english),
         pdfCell(fmt(t.amountMinor/100),center:true,monetary:true),
        ];
        return pw.TableRow(decoration:pw.BoxDecoration(
         color:PdfColor.fromInt(const Color(0xFFE7F0FA).toARGB32())),
         children:english?cells:cells.reversed.toList());
       }),
      ]),
    ]);
   }
   if(!analytics&&pdfSavings.isNotEmpty){
    final labels={for(final a in _m467Accounts)a.id:_m647VerifiedAccountLabel(a)};
    final ordered=pdfSavings.toList()
     ..sort((a,b)=>b.occurredIso.compareTo(a.occurredIso));
    reportSections.addAll([
     pw.SizedBox(height:8),
     heading('حركات الادخار','Savings goal movements'),
     pw.Padding(padding:const pw.EdgeInsets.only(bottom:10),
      child:pw.Text(english?
       'Savings movements are internal assets, not new revenue or expense.':
       'نقل مبالغ الادخار حركة أصول داخلية، وليس دخلًا أو مصروفًا جديدًا.',
       style:pw.TextStyle(font:font,fontSize:10,color:PdfColors.teal900))),
     pw.Table(border:pw.TableBorder.all(color:PdfColors.grey400,width:.4),
      children:[
       pw.TableRow(decoration:const pw.BoxDecoration(color:PdfColors.teal800),
        children:(english?['Date','Type','Savings goal','Source account','Amount']:
         ['المبلغ','الحساب الأصلي','الهدف','نوع الحركة','التاريخ'])
         .map((v)=>pw.Padding(padding:const pw.EdgeInsets.all(6),
         child:pw.Text(v,textAlign:pw.TextAlign.center,
          textDirection:english?pw.TextDirection.ltr:pw.TextDirection.rtl,
          style:pw.TextStyle(font:bold,fontSize:9,color:PdfColors.white))))
         .toList()),
       ...ordered.map((m){
        final when=DateTime.tryParse(m.occurredIso);
        final label=m.kind=='fund'?
         (english?'Saved':'إضافة ادخار'):
         (english?'Withdrawn':'سحب ادخار');
        final cells=<pw.Widget>[
         pdfCell(when==null?m.occurredIso:dayText(when),center:true),
         pdfCell(label,rtl:!english),
         pdfCell(m.goalName,rtl:!english),
         pdfCell(labels[m.accountId]??(english?'Unknown':'حساب غير متاح'),
          rtl:!english),
         pdfCell(fmt(m.amountMinor/100),center:true,monetary:true),
        ];
        return pw.TableRow(decoration:pw.BoxDecoration(
         color:PdfColor.fromInt(const Color(0xFFF8F0D9).toARGB32())),
         children:english?cells:cells.reversed.toList());
       }),
      ]),
    ]);
   }
   if(!analytics&&reportSections.isNotEmpty){
    doc.addPage(pw.MultiPage(
     pageTheme:pageTheme,
     footer:(ctx)=>pw.Align(alignment:pw.Alignment.centerRight,
      child:pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
       style:pw.TextStyle(font:font,fontSize:9,color:PdfColors.teal900))),
     build:(ctx)=>reportSections));
   }
   final bytes=await doc.save();
   if(exportDialogOpen&&exportNavigator.mounted){exportNavigator.pop();exportDialogOpen=false;}
   if(!mounted)return;
   final fileName=analytics?'waffra_analytics.pdf':'waffra_income_expenses.pdf';
   await showWaffraDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24),
     side:waffraDialogOutline(Theme.of(dialogContext).brightness)),
    title:Column(children:[
     const Icon(Icons.check_circle_rounded,color:emerald,size:58),
     const SizedBox(height:12),
     WaffraText(waffraIsEnglish?'Report ready':'تم تجهيز التقرير بنجاح',
      textAlign:TextAlign.center),
    ]),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
     const Icon(Icons.picture_as_pdf,color:Colors.red,size:38),
     const SizedBox(height:8),
     WaffraText(analytics?(waffraIsEnglish?'Analytics report':'تقرير التحليلات'):
      (waffraIsEnglish?'Income and expenses report':'تقرير الدخل والمصروفات'),
      textAlign:TextAlign.center),
     const SizedBox(height:4),
     WaffraText('${(bytes.length/1024).toStringAsFixed(1)} KB',
      textAlign:TextAlign.center,style:const TextStyle(fontSize:12)),
    ]),
    actionsPadding:const EdgeInsets.fromLTRB(16,0,16,16),
    actions:[
     LayoutBuilder(builder:(buttonsContext,limits){
      Widget openButton()=>FilledButton.icon(
       key:const Key('waffra-report-open'),
       onPressed:WaffraHaptics.tap((){
        Navigator.of(dialogContext).pop();
        Navigator.of(context).push(MaterialPageRoute(builder:(_)=>
         WaffraPdfReader(bytes:bytes,fileName:fileName,english:waffraIsEnglish)));
       }),
       icon:const Icon(Icons.visibility_outlined,size:18),
       style:FilledButton.styleFrom(
        minimumSize:const Size(0,48),
        padding:const EdgeInsets.symmetric(horizontal:10),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
       label:WaffraText(
        waffraIsEnglish?'Open report':'فتح التقرير',
        maxLines:2,textAlign:TextAlign.center));
      Widget shareButton()=>OutlinedButton.icon(
       key:const Key('waffra-report-share'),
       onPressed:WaffraHaptics.tap(()async{
        Navigator.of(dialogContext).pop();
        try{
         await Printing.sharePdf(bytes:bytes,filename:fileName);
        }catch(e){
         if(mounted)snack(context,waffraIsEnglish?
          'Could not share the report. Try again.':
          'تعذرت مشاركة التقرير. حاول مرة أخرى.');
        }
       }),
       icon:const Icon(Icons.share_outlined,size:18),
       style:OutlinedButton.styleFrom(
        minimumSize:const Size(0,48),
        padding:const EdgeInsets.symmetric(horizontal:10),
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
       label:WaffraText(
        waffraIsEnglish?'Share report':'مشاركة التقرير',
        maxLines:2,textAlign:TextAlign.center));
      // Buttons stay on one row when the dialog has room. Below 300dp
      // they stack without clipping a translated label or Android insets.
      if(limits.maxWidth<300)return Column(
       mainAxisSize:MainAxisSize.min,children:[
        SizedBox(width:double.infinity,child:openButton()),
        const SizedBox(height:8),
        SizedBox(width:double.infinity,child:shareButton()),
       ]);
      return Row(children:[
       Expanded(child:openButton()),const SizedBox(width:8),
       Expanded(child:shareButton()),
      ]);
     }),
    ],
   ));
  }catch(e,st){
   debugPrint('PDF export error: $e\n$st');
   if(exportDialogOpen&&exportNavigator.mounted){exportNavigator.pop();exportDialogOpen=false;}
   if(mounted)snack(context,waffraIsEnglish?'Could not export the PDF report. Please try again.':'تعذر تصدير تقرير PDF. حاول مرة أخرى.');
  }
 }
}

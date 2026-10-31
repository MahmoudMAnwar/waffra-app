/// Answers financial totals without asking the on-device LLM to do arithmetic.
class WaffraAiRecordedFact {
  const WaffraAiRecordedFact({
    required this.date,required this.category,
    required this.amountMinor,required this.income,
  });
  final DateTime date;
  final String category;
  final int amountMinor;
  final bool income;
}

abstract final class WaffraAiRecordedAnswers {
  static String _norm(String text)=>text.toLowerCase()
    .replaceAll(RegExp(r'[أإآٱ]'),'ا')
    .replaceAll('ى','ي').replaceAll('ة','ه')
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'),'')
    .replaceAll(RegExp(r'\s+'),' ').trim();
  static bool _has(String s,String pattern)=>
      RegExp(pattern,caseSensitive:false).hasMatch(s);

  /// Numeric questions use only verified account-scoped records.
  /// No implicit foreign-exchange conversion or bank-balance claim.
  static String? answer(String question,Iterable<WaffraAiRecordedFact> facts,{
    DateTime? now,bool english=false,String currency='SAR',
    String Function(int)? formatMoney,
  }){
    final q=_norm(question);
    if(q.isEmpty||q.length>500)return null;
    final incomeQuestion=_has(q,r'دخل|ايراد|راتب|income|earned|salary');
    final expenseQuestion=_has(q,r'صرف|مصروف|مصاريف|انفق|دفعت|spend|spent|expense|spending|paid');
    final netQuestion=_has(q,r'صافي|net\b|الفرق|رصيد|balance');
    final rows=facts.where((x)=>x.amountMinor>0&&
        x.amountMinor<=100000000000).toList(growable:false);
    String? category;
    for(final name in rows.map((x)=>x.category).toSet()){
      final norm=_norm(name);
      final matches=q.contains(norm)||
          norm.split(RegExp(r'[\s/]+'))
            .where((word)=>word.length>=5)
            .any(q.contains);
      if(matches&&(category==null||name.length>category.length))category=name;
    }
    if(!incomeQuestion&&!expenseQuestion&&!netQuestion&&category==null)return null;
    final today=now??DateTime.now();
    DateTime? from,to;
    var scope=english?'all recorded transactions':'كل المعاملات المسجلة';
    final monthMatch=RegExp(r'([0-9٠-٩]{1,3})\s*(?:شهر|شهور|اشهر|months?)')
        .firstMatch(q);
    int? months;
    if(monthMatch!=null){
      const digits='٠١٢٣٤٥٦٧٨٩';
      months=int.tryParse(monthMatch.group(1)!.split('').map((x){
        final i=digits.indexOf(x);
        return i<0?x:i.toString();
      }).join());
    }
    // A named period must never silently become "all transactions".
    if(months!=null&&(months<1||months>120)){
      return english?'Choose a period of 1 to 120 months.':
        'حدد فترة من شهر إلى 120 شهر.';
    }
    if(months!=null&&months>=1&&months<=120){
      from=DateTime(today.year,today.month-months+1,1);
      to=DateTime(today.year,today.month+1,1);
      scope=english?'last '+months.toString()+' months':
        'آخر '+months.toString()+' شهور';
    }else if(_has(q,r'الشهر اللي فات|الشهر السابق|last month')){
      from=DateTime(today.year,today.month-1,1);
      to=DateTime(today.year,today.month,1);
      scope=english?'last month':'الشهر الماضي';
    }else if(_has(q,r'امس|مبارح|yesterday')){
      from=DateTime(today.year,today.month,today.day-1);
      to=DateTime(today.year,today.month,today.day);
      scope=english?'yesterday':'أمس';
    }else if(_has(q,r'النهارده|اليوم|today\b')){
      from=DateTime(today.year,today.month,today.day);
      to=DateTime(today.year,today.month,today.day+1);
      scope=english?'today':'اليوم';
    }else if(_has(q,r'الاسبوع اللي فات|الاسبوع الماضي|last week')){
      final weekStart=DateTime(today.year,today.month,today.day)
          .subtract(Duration(days:today.weekday-1));
      from=weekStart.subtract(const Duration(days:7));
      to=weekStart;
      scope=english?'last calendar week':'الأسبوع الماضي';
    }else if(_has(q,r'الاسبوع|اسبوع|week\b')){
      from=DateTime(today.year,today.month,today.day-6);
      to=DateTime(today.year,today.month,today.day+1);
      scope=english?'last 7 days':'آخر 7 أيام';
    }else if(_has(q,r'الشهر|this month|current month')){
      from=DateTime(today.year,today.month,1);
      to=DateTime(today.year,today.month+1,1);
      scope=english?'this month':'الشهر الحالي';
    }else if(_has(q,r'السنه الماضيه|السنه اللي فاتت|last year')){
      from=DateTime(today.year-1,1,1);
      to=DateTime(today.year,1,1);
      scope=english?'last year':'السنة الماضية';
    }else if(_has(q,r'السنه|السنة|this year|current year')){
      from=DateTime(today.year,1,1);
      to=DateTime(today.year+1,1,1);
      scope=english?'this year':'السنة الحالية';
    }
    final selected=rows.where((x)=>
      (from==null||!x.date.isBefore(from))&&
      (to==null||x.date.isBefore(to))&&
      (category==null||x.category==category)).toList(growable:false);
    if(selected.isEmpty)return english?
      'No recorded transactions for this period.':
      'مافيش معاملات مسجلة للفترة دي.';
    final incoming=selected.where((x)=>x.income).toList();
    final outgoing=selected.where((x)=>!x.income).toList();
    final inc=incoming.fold<int>(0,(s,x)=>s+x.amountMinor);
    final exp=outgoing.fold<int>(0,(s,x)=>s+x.amountMinor);
    String money(int minor)=>formatMoney?.call(minor)??
        (minor/100).toStringAsFixed(2)+' '+currency;
    final cat=category==null?'':english?' in '+category:' في '+category;
    if(incomeQuestion&&expenseQuestion){
      return english?'For '+scope+cat+':\nIncome: '+money(inc)+
        ' ('+incoming.length.toString()+' transactions)\nExpenses: '+
        money(exp)+' ('+outgoing.length.toString()+' transactions).':
        'خلال '+scope+cat+':\nالدخل: '+money(inc)+
        ' ('+incoming.length.toString()+' معاملة)\nالمصروفات: '+
        money(exp)+' ('+outgoing.length.toString()+' معاملة).';
    }
    if(netQuestion){
      return english?'Net of recorded transactions for '+scope+': '+
        money(inc-exp)+'. This is not your bank balance.':
        'صافي المعاملات المسجلة خلال '+scope+': '+
        money(inc-exp)+'. ده مش رصيد حسابك البنكي.';
    }
    final useIncome=incomeQuestion&&!expenseQuestion;
    final total=useIncome?inc:exp;
    final count=useIncome?incoming.length:outgoing.length;
    final label=english?(useIncome?'income':'expenses'):
      (useIncome?'الدخل':'المصروفات');
    return english?'Recorded '+label+cat+' for '+scope+': '+money(total)+
      ' ('+count.toString()+' transactions).':
      'إجمالي '+label+cat+' خلال '+scope+': '+money(total)+
      ' ('+count.toString()+' معاملة).';
  }

  /// A local language model must not invent money totals in free-form
  /// advice. Deterministic numeric questions are answered from verified
  /// recorded finance facts before the model is invoked. Block any monetary
  /// value in generated narrative instead of pretending to verify it.
  /// Ratios or percentages alone are suggestions, not recorded amounts.
  static bool hasUnverifiedMoneyClaim(String answer) {
    final source=answer.trim();
    if(source.isEmpty)return false;
    final currencies=RegExp(
     r'(?i:(?:SAR|EGP|AED|USD|EUR|GBP|QAR|KWD|BHD|OMR|JOD|'
     r'IQD|JPY|CNY|TRY|INR|CAD|AUD|CHF|PKR|MAD|DZD|TND|'
     r'LBP|KRW|SGD|HKD|MYR|IDR|ZAR|SEK|NOK|DKK|THB|PHP|BDT))');
    // Match currency followed by a number or number followed by a
    // currency (e.g. "AED 136", "136 درهم", "١٠٠ ريال").
    final arabic=r'(?:ريال|درهم|جنيه|دولار|دينار|يورو|ليرة|روبية)';
    final numeric=r'[0-9٠-٩۰-۹][0-9٠-٩۰-۹,.\\u066B\\u066C]*';
    final money=RegExp(
      '(?:'+currencies.pattern+'|'+arabic+')'+r'\\s*[:：]?\\s*'+numeric+
      '|'+numeric+r'\\s*(?:'+currencies.pattern+'|'+arabic+')',
      caseSensitive:false);
    return money.hasMatch(source);
  }

    /// Remove raw Markdown/thinking and boilerplate from qualitative LLM output.
  static String? cleanModelAnswer(String raw){
    var output=raw.trim();
    if(output.isEmpty||output.length>8000)return null;
    final thinkEnd=output.lastIndexOf('</think>');
    if(thinkEnd>=0)output=output.substring(thinkEnd+8);
    if(output.contains('<think>')||output.startsWith('{')||
       output.contains('income_minor')||output.contains('VERIFIED SUMMARY'))return null;
    output=output
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*',multiLine:true),'')
      .replaceAll(RegExp(r'^\s*[-*]\s+',multiLine:true),'• ')
      .replaceAll(RegExp(r'\*\*|__'),'')
      .replaceAll(String.fromCharCode(96),'')
      .replaceAll(RegExp(r'^\s*[-_]{3,}\s*$',multiLine:true),'')
      .replaceAll(RegExp(
        r'all values derived directly from[\s\W]*the json data[\s\W]*',caseSensitive:false),'')
      .replaceAll(RegExp(r'\n{3,}'),'\n\n')
      .replaceAll('*','').trim();
    if(output.isEmpty)return null;
    if(output.length>850){
      final end=output.lastIndexOf(' ',850);
      output=output.substring(0,end>550?end:850).trim()+'…';
    }
    return output;
  }
}

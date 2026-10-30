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
    final expenseQuestion=_has(q,r'صرف|مصروف|مصاريف|انفق|دفعت|spent|expense|spending|paid');
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
    final monthMatch=RegExp(r'([0-9٠-٩]{1,2})\s*(?:شهر|شهور|اشهر|months?)')
        .firstMatch(q);
    int? months;
    if(monthMatch!=null){
      const digits='٠١٢٣٤٥٦٧٨٩';
      months=int.tryParse(monthMatch.group(1)!.split('').map((x){
        final i=digits.indexOf(x);
        return i<0?x:i.toString();
      }).join());
    }
    if(months!=null&&months>=1&&months<=12){
      from=DateTime(today.year,today.month-months+1,1);
      to=DateTime(today.year,today.month+1,1);
      scope=english?'last '+months.toString()+' months':
        'آخر '+months.toString()+' شهور';
    }else if(_has(q,r'الشهر اللي فات|الشهر السابق|last month')){
      from=DateTime(today.year,today.month-1,1);
      to=DateTime(today.year,today.month,1);
      scope=english?'last month':'الشهر الماضي';
    }else if(_has(q,r'النهارده|اليوم|today\b')){
      from=DateTime(today.year,today.month,today.day);
      to=DateTime(today.year,today.month,today.day+1);
      scope=english?'today':'اليوم';
    }else if(_has(q,r'الاسبوع|اسبوع|week\b')){
      from=DateTime(today.year,today.month,today.day-6);
      to=DateTime(today.year,today.month,today.day+1);
      scope=english?'last 7 days':'آخر 7 أيام';
    }else if(_has(q,r'الشهر|this month|current month')){
      from=DateTime(today.year,today.month,1);
      to=DateTime(today.year,today.month+1,1);
      scope=english?'this month':'الشهر الحالي';
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

  /// Remove raw Markdown/thinking and boilerplate from qualitative LLM output.
  static String? cleanModelAnswer(String raw){
    var output=raw.trim();
    if(output.isEmpty||output.length>8000)return null;
    final thinkEnd=output.lastIndexOf('</think>');
    if(thinkEnd>=0)output=output.substring(thinkEnd+8);
    if(output.contains('<think>')||output.startsWith('{')||
       output.contains('income_minor')||output.contains('VERIFIED SUMMARY'))return null;
    output=output
      .replaceAll(RegExp(r'(?m)^\s{0,3}#{1,6}\s*'),'')
      .replaceAll(RegExp(r'(?m)^\s*[-*]\s+'),'• ')
      .replaceAll(RegExp(r'\*\*|__'),'')
      .replaceAll(String.fromCharCode(96),'')
      .replaceAll(RegExp(r'(?m)^\s*[-_]{3,}\s*$'),'')
      .replaceAll(RegExp(
        r'(?i)all values derived directly from\s*\(?the json data\)?\.?'),'')
      .replaceAll(RegExp(r'\n{3,}'),'\n\n').trim();
    if(output.isEmpty)return null;
    if(output.length>850){
      final end=output.lastIndexOf(' ',850);
      output=output.substring(0,end>550?end:850).trim()+'…';
    }
    return output;
  }
}

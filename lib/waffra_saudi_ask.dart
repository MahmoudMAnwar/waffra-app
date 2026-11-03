/// Deterministic Saudi-release questions. Inputs must be projections of the
/// verified account finance source; no Qwen, network, free-text or writes.
class WaffraSaudiAskEntry {
 final DateTime date;
 final String category;
 final int amountMinor;
 final bool income;
 const WaffraSaudiAskEntry(this.date,this.category,this.amountMinor,this.income);
}
class WaffraSaudiAskBudget {
 final String id,name;
 final int limitMinor,spentMinor;
 final bool active;
 const WaffraSaudiAskBudget(this.id,this.name,this.limitMinor,
  this.spentMinor,this.active);
}
class WaffraSaudiQuestion {
 final String id,ar,en;
 const WaffraSaudiQuestion(this.id,this.ar,this.en);
 String label(bool english)=>english?en:ar;
}
abstract final class WaffraSaudiAsk {
 static bool inMonth(DateTime date,DateTime today)=>
  date.year==today.year&&date.month==today.month;
 static List<WaffraSaudiAskEntry> currentMonth(
  Iterable<WaffraSaudiAskEntry> entries,DateTime now)=>
  entries.where((r)=>r.amountMinor>0&&r.amountMinor<=100000000000&&
   inMonth(r.date,now)).toList(growable:false);
 static List<WaffraSaudiQuestion> questions(
  Iterable<WaffraSaudiAskEntry> entries,Iterable<WaffraSaudiAskBudget> budgets,{
  DateTime? now,
 }){
  final rows=currentMonth(entries,now??DateTime.now());
  final result=<WaffraSaudiQuestion>[
   const WaffraSaudiQuestion('income','كم دخلي هذا الشهر؟','What was my income this month?'),
   const WaffraSaudiQuestion('expenses','كم صرفت هذا الشهر؟','How much did I spend this month?'),
   const WaffraSaudiQuestion('net','ما صافي الدخل والمصروف هذا الشهر؟','What is my net recorded cashflow this month?'),
   const WaffraSaudiQuestion('top','إيش أكثر قسم صرفت عليه؟','Which category cost me the most?'),
   const WaffraSaudiQuestion('budget_summary','كيف وضع ميزانياتي؟','How are my budgets doing?'),
  ];
  final categories=rows.map((r)=>r.category).where((s)=>s.trim().isNotEmpty).toSet().toList()..sort();
  for(final name in categories.take(8)){
   result.add(WaffraSaudiQuestion('category:$name',
    'كم سجلت في قسم $name هذا الشهر؟','How much was recorded in $name this month?'));
  }
  for(final b in budgets.where((b)=>b.limitMinor>0).take(8)){
   result.add(WaffraSaudiQuestion('budget:${b.id}',
    'كم استخدمت من ميزانية ${b.name}؟','How much of ${b.name} budget is used?'));
  }
  return result;
 }
 static String answer(String key,Iterable<WaffraSaudiAskEntry> entries,
  Iterable<WaffraSaudiAskBudget> budgets,{
  DateTime? now,bool english=false,required String Function(int) money,
 }){
  final rows=currentMonth(entries,now??DateTime.now());
  int sum(Iterable<WaffraSaudiAskEntry> source)=>
   source.fold<int>(0,(v,r)=>v+r.amountMinor);
  final income=sum(rows.where((r)=>r.income));
  final expense=sum(rows.where((r)=>!r.income));
  if(key=='income')return english?
   'Recorded income this month: ${money(income)}.':
   'الدخل المسجل هذا الشهر: ${money(income)}.';
  if(key=='expenses')return english?
   'Recorded expenses this month: ${money(expense)}.':
   'المصروفات المسجلة هذا الشهر: ${money(expense)}.';
  if(key=='net')return english?
   'Net recorded income minus expenses: ${money(income-expense)}. This is not your bank balance.':
   'صافي الدخل ناقص المصروفات المسجلة: ${money(income-expense)}. هذا ليس رصيد حسابك البنكي.';
  final spent=<String,int>{};
  final earned=<String,int>{};
  for(final r in rows){
   final output=r.income?earned:spent;
   output[r.category]=(output[r.category]??0)+r.amountMinor;
  }
  if(key=='top'){
   final ranked=spent.entries.toList()..sort((a,b){
    final diff=b.value.compareTo(a.value);
    return diff!=0?diff:a.key.compareTo(b.key);
   });
   if(ranked.isEmpty)return english?
    'No expenses recorded this month.':'ما فيه مصروفات مسجلة هذا الشهر.';
   return english?
    'Largest expense category this month: ${ranked.first.key} — ${money(ranked.first.value)}.':
    'أكثر قسم مصروفات هذا الشهر: ${ranked.first.key} — ${money(ranked.first.value)}.';
  }
  if(key.startsWith('category:')){
   final name=key.substring('category:'.length);
   if(name.trim().isEmpty||!rows.any((r)=>r.category==name))return english?
    'This category has no records this month.':'ما فيه عمليات مسجلة لهذا القسم هذا الشهر.';
   return english?
    '$name this month: income ${money(earned[name]??0)}, expenses ${money(spent[name]??0)}.':
    'قسم $name هذا الشهر: دخل ${money(earned[name]??0)}، مصروفات ${money(spent[name]??0)}.';
  }
  if(key=='budget_summary'){
   final list=budgets.where((b)=>b.limitMinor>0).toList();
   if(list.isEmpty)return english?
    'No budgets have been created yet.':'ما أضفت أي ميزانية حتى الآن.';
   final total=sumBudget(list,(b)=>b.limitMinor);
   final used=sumBudget(list,(b)=>b.spentMinor);
   return english?
    '${list.length} budgets: limit ${money(total)}, recorded spending ${money(used)}, remaining ${money(total-used)}. Paused budgets are included in their saved totals.':
    '${list.length} ميزانية: إجمالي الحدود ${money(total)}، المصروف المسجل ${money(used)}، المتبقي ${money(total-used)}. الميزانيات المتوقفة محسوبة ضمن الإجمالي المحفوظ.';
  }
  if(key.startsWith('budget:')){
   final id=key.substring('budget:'.length);
   final match=budgets.where((b)=>b.id==id&&b.limitMinor>0).toList();
   if(match.length!=1)return english?'Budget not found.':'الميزانية غير موجودة.';
   final b=match.single;
   return english?
    '${b.name}: limit ${money(b.limitMinor)}, spent ${money(b.spentMinor)}, remaining ${money(b.limitMinor-b.spentMinor)}. ${b.active?'Active':'Paused'}.':
    '${b.name}: الحد ${money(b.limitMinor)}، المصروف ${money(b.spentMinor)}، المتبقي ${money(b.limitMinor-b.spentMinor)}. ${b.active?'مفعّلة':'متوقفة'}.';
  }
  return english?'Choose a question from the list.':'اختر سؤالًا من القائمة.';
 }
 static int sumBudget(Iterable<WaffraSaudiAskBudget> budgets,
  int Function(WaffraSaudiAskBudget) value)=>
  budgets.fold<int>(0,(sum,b)=>sum+value(b));
}
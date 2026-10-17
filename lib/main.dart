import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const Waffra());

class Entry {
  final String title;
  final double amount;
  final bool income;
  final String category;
  final DateTime date;
  Entry(this.title, this.amount, this.income, this.category, this.date);
  Map<String, dynamic> toJson() => {'title': title, 'amount': amount, 'income': income, 'category': category, 'date': date.toIso8601String()};
  factory Entry.fromJson(Map<String, dynamic> j) => Entry(j['title'] as String, (j['amount'] as num).toDouble(), j['income'] as bool, j['category'] as String, DateTime.parse(j['date'] as String));
}

class Waffra extends StatefulWidget {
  const Waffra({super.key});
  @override
  State<Waffra> createState() => _WaffraState();
}

class _WaffraState extends State<Waffra> {
  bool dark = false;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'وفرة', debugShowCheckedModeBanner: false,
    locale: const Locale('ar', 'SA'),
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF087A54), scaffoldBackgroundColor: const Color(0xFFF6F8F4)),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark, colorSchemeSeed: const Color(0xFF087A54)),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Directionality(textDirection: TextDirection.rtl, child: Home(dark: dark, toggleTheme: () => setState(() => dark = !dark))),
  );
}

class Home extends StatefulWidget {
  final bool dark;
  final VoidCallback toggleTheme;
  const Home({super.key, required this.dark, required this.toggleTheme});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<Entry> entries = [];
  int tab = 0;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('entries');
    if (data != null) {
      try { final loaded = (jsonDecode(data) as List).map((x) => Entry.fromJson(Map<String, dynamic>.from(x))).toList(); if (mounted) setState(() => entries.addAll(loaded)); } catch (_) {}
    }
  }
  Future<void> save() async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList())); }
  double get income => entries.where((e) => e.income).fold(0.0, (a, b) => a + b.amount);
  double get expense => entries.where((e) => !e.income).fold(0.0, (a, b) => a + b.amount);
  String money(double n) => '${n.toStringAsFixed(2)} ر.س';
  Future<void> addEntry() async {
    final title = TextEditingController(); final amount = TextEditingController();
    bool isIncome = false; String category = 'طعام';
    final result = await showModalBottomSheet<Entry>(context: context, isScrollControlled: true, builder: (sheetContext) => StatefulBuilder(builder: (context, update) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 22, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('إضافة عملية جديدة', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('مصروف')), ButtonSegment(value: true, label: Text('دخل'))], selected: {isIncome}, onSelectionChanged: (v) => update(() { isIncome = v.first; category = isIncome ? 'راتب' : 'طعام'; })),
        const SizedBox(height: 12), TextField(controller: title, decoration: const InputDecoration(labelText: 'وصف العملية', border: OutlineInputBorder())),
        const SizedBox(height: 12), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ بالريال', border: OutlineInputBorder())),
        const SizedBox(height: 12), DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'التصنيف', border: OutlineInputBorder()), items: (isIncome ? ['راتب', 'عمل إضافي', 'دخل آخر'] : ['طعام', 'تسوق', 'مواصلات', 'فواتير', 'صحة', 'أخرى']).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => update(() => category = v!)),
        const SizedBox(height: 18), FilledButton(onPressed: () { final value = double.tryParse(amount.text.trim().replaceAll(',', '.')); if (title.text.trim().isEmpty || value == null || value <= 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل وصفًا ومبلغًا صحيحًا'))); return; } Navigator.pop(sheetContext, Entry(title.text.trim(), value, isIncome, category, DateTime.now())); }, child: const Text('حفظ العملية')),
      ])),
    )));
    title.dispose(); amount.dispose();
    if (result != null) { setState(() => entries.insert(0, result)); await save(); }
  }
  Widget stat(String label, String value, IconData icon, Color color) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 8), Text(label), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]))));
  @override
  Widget build(BuildContext context) {
    final categories = <String, double>{};
    for (final e in entries.where((e) => !e.income)) { categories[e.category] = (categories[e.category] ?? 0) + e.amount; }
    return Scaffold(
      appBar: AppBar(title: const Text('وفرة  |  Waffra', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: widget.toggleTheme, tooltip: 'تغيير المظهر', icon: Icon(widget.dark ? Icons.light_mode : Icons.dark_mode))]),
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: tab == 0 ? [
        Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: const Color(0xFF087A54), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('رصيدك الحالي', style: TextStyle(color: Colors.white70, fontSize: 16)), const SizedBox(height: 8), Text(money(income - expense), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)), const SizedBox(height: 12), const Text('تابع مصروفاتك، خطوة بخطوة', style: TextStyle(color: Colors.white70))])),
        const SizedBox(height: 16), Row(children: [stat('الدخل', money(income), Icons.arrow_downward, Colors.green), stat('المصروفات', money(expense), Icons.arrow_upward, Colors.deepOrange)]),
        const SizedBox(height: 20), Text('آخر العمليات', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
        if (entries.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('ابدأ بإضافة أول عملية مالية'))),
        ...entries.take(20).map((e) => Card(child: ListTile(leading: CircleAvatar(child: Icon(e.income ? Icons.add : Icons.remove)), title: Text(e.title), subtitle: Text('${e.category} • ${e.date.day}/${e.date.month}/${e.date.year}'), trailing: Text('${e.income ? '+' : '-'}${money(e.amount)}', style: TextStyle(color: e.income ? Colors.green : null, fontWeight: FontWeight.bold)), onLongPress: () async { setState(() => entries.remove(e)); await save(); }))),
        const SizedBox(height: 60),
      ] : [
        Text('تحليل مصروفاتك', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 12),
        Text('إجمالي المصروفات: ${money(expense)}'), const SizedBox(height: 18),
        if (categories.isEmpty) const Text('لا توجد مصروفات لعرض التحليلات بعد'),
        ...categories.entries.map((e) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(e.key), Text(money(e.value))]), const SizedBox(height: 8), LinearProgressIndicator(value: expense == 0 ? 0 : e.value / expense, minHeight: 9, borderRadius: BorderRadius.circular(10))]))),
        const SizedBox(height: 20), const Text('البيانات محفوظة محليًا على جهازك. لا يوجد ربط بحسابات بنكية.'),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: addEntry, icon: const Icon(Icons.add), label: const Text('إضافة عملية')),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'), NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'التحليلات')]),
    );
  }
}

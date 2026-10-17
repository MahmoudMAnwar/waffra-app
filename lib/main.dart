
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Waffra());
}

class Entry {
  final String title;
  final double amount;
  final bool income;
  final String category;
  final DateTime date;

  Entry(this.title, this.amount, this.income, this.category, this.date);

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'income': income,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      json['title'] as String,
      (json['amount'] as num).toDouble(),
      json['income'] as bool,
      json['category'] as String,
      DateTime.parse(json['date'] as String),
    );
  }
}

class Waffra extends StatefulWidget {
  const Waffra({super.key});

  @override
  State<Waffra> createState() => _WaffraState();
}

class _WaffraState extends State<Waffra> {
  bool dark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وفرة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF087A54),
        scaffoldBackgroundColor: const Color(0xFFF6F8F4),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF087A54),
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Home(
          dark: dark,
          toggleTheme: () {
            setState(() {
              dark = !dark;
            });
          },
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  final bool dark;
  final VoidCallback toggleTheme;

  const Home({
    super.key,
    required this.dark,
    required this.toggleTheme,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final List<Entry> entries = [];
  int tab = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('entries');

    if (data == null) return;

    try {
      final decoded = jsonDecode(data) as List;
      final loaded = decoded
          .map((item) => Entry.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;

      setState(() {
        entries.addAll(loaded);
      });
    } catch (error) {
      debugPrint('Could not load saved entries: $error');
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(
      entries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString('entries', data);
  }

  double get income => entries
      .where((entry) => entry.income)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get expense => entries
      .where((entry) => !entry.income)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  String money(double value) => '${value.toStringAsFixed(2)} ر.س';

  Future<void> addEntry() async {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    bool isIncome = false;
    String category = 'طعام';

    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, update) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 22,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إضافة عملية جديدة',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('مصروف'),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('دخل'),
                        ),
                      ],
                      selected: {isIncome},
                      onSelectionChanged: (values) {
                        update(() {
                          isIncome = values.first;
                          category = isIncome ? 'راتب' : 'طعام';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'وصف العملية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ بالريال',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(
                        labelText: 'التصنيف',
                        border: OutlineInputBorder(),
                      ),
                      items: (isIncome
                              ? ['راتب', 'عمل إضافي', 'دخل آخر']
                              : [
                                  'طعام',
                                  'تسوق',
                                  'مواصلات',
                                  'فواتير',
                                  'صحة',
                                  'أخرى',
                                ])
                          .map(
                            (name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          update(() {
                            category = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        final amount = double.tryParse(
                          amountController.text
                              .trim()
                              .replaceAll(',', '.'),
                        );

                        if (titleController.text.trim().isEmpty ||
                            amount == null ||
                            !amount.isFinite ||
                            amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('أدخل وصفًا ومبلغًا صحيحًا'),
                            ),
                          );
                          return;
                        }

                        Navigator.pop(
                          sheetContext,
                          Entry(
                            titleController.text.trim(),
                            amount,
                            isIncome,
                            category,
                            DateTime.now(),
                          ),
                        );
                      },
                      child: const Text('حفظ العملية'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    amountController.dispose();

    if (result != null && mounted) {
      setState(() {
        entries.insert(0, result);
      });
      await save();
    }
  }

  Widget stat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(label),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String, double>{};

    for (final entry in entries.where((item) => !item.income)) {
      categories[entry.category] =
          (categories[entry.category] ?? 0) + entry.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'وفرة | Waffra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: widget.toggleTheme,
            tooltip: 'تغيير المظهر',
            icon: Icon(
              widget.dark ? Icons.light_mode : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: tab == 0
              ? [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF087A54),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رصيدك الحالي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          money(income - expense),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تابع مصروفاتك، خطوة بخطوة',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      stat(
                        'الدخل',
                        money(income),
                        Icons.arrow_downward,
                        Colors.green,
                      ),
                      stat(
                        'المصروفات',
                        money(expense),
                        Icons.arrow_upward,
                        Colors.deepOrange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'آخر العمليات',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('ابدأ بإضافة أول عملية مالية'),
                      ),
                    ),
                  ...entries.take(20).map(
                    (entry) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            entry.income ? Icons.add : Icons.remove,
                          ),
                        ),
                        title: Text(entry.title),
                        subtitle: Text(
                          '${entry.category} • '
                          '${entry.date.day}/${entry.date.month}/${entry.date.year}',
                        ),
                        trailing: Text(
                          '${entry.income ? '+' : '-'}${money(entry.amount)}',
                          style: TextStyle(
                            color: entry.income ? Colors.green : null,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onLongPress: () async {
                          setState(() {
                            entries.remove(entry);
                          });
                          await save();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ]
              : [
                  Text(
                    'تحليل مصروفاتك',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text('إجمالي المصروفات: ${money(expense)}'),
                  const SizedBox(height: 18),
                  if (categories.isEmpty)
                    const Text('لا توجد مصروفات لعرض التحليلات بعد'),
                  ...categories.entries.map(
                    (entry) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key),
                                Text(money(entry.value)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: expense == 0
                                  ? 0
                                  : entry.value / expense,
                              minHeight: 9,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'البيانات محفوظة محليًا على جهازك. '
                    'لا يوجد ربط بحسابات بنكية.',
                  ),
                ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addEntry,
        icon: const Icon(Icons.add),
        label: const Text('إضافة عملية'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() {
            tab = value;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'التحليلات',
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaffraApp());
}

const Color green = Color(0xFF087A54);
const Color darkGreen = Color(0xFF064D3B);
const Color cream = Color(0xFFF7F6F0);
const Color gold = Color(0xFFD7B675);

class Entry {
  final String title;
  final double amount;
  final bool income;
  final String category;
  final DateTime date;

  Entry(
    this.title,
    this.amount,
    this.income,
    this.category,
    this.date,
  );

  Map<String, dynamic> toJson() => {
        'title': title,
        'amount': amount,
        'income': income,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory Entry.fromJson(Map<String, dynamic> data) {
    return Entry(
      data['title'] as String,
      (data['amount'] as num).toDouble(),
      data['income'] as bool,
      data['category'] as String,
      DateTime.parse(data['date'] as String),
    );
  }
}

class WaffraApp extends StatefulWidget {
  const WaffraApp({super.key});

  @override
  State<WaffraApp> createState() => _WaffraAppState();
}

class _WaffraAppState extends State<WaffraApp> {
  bool dark = false;
  bool loading = true;
  bool seenIntro = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      seenIntro =
          prefs.getBool('waffra_onboarding_completed') ?? false;
      loading = false;
    });
  }

  Future<void> finishIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waffra_onboarding_completed', true);

    if (!mounted) return;

    setState(() {
      seenIntro = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وفرة | Waffra',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: green,
        scaffoldBackgroundColor: cream,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: green,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: loading
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : seenIntro
                ? HomePage(
                    dark: dark,
                    onTheme: () {
                      setState(() => dark = !dark);
                    },
                  )
                : IntroPage(onDone: finishIntro),
      ),
    );
  }
}

// ========================================
// ONBOARDING
// ========================================

class IntroPage extends StatefulWidget {
  final Future<void> Function() onDone;

  const IntroPage({
    super.key,
    required this.onDone,
  });

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final PageController controller = PageController();

  int page = 0;
  bool finishing = false;

  static const titles = [
    'أهلاً بك في وفرة',
    'تحكّم في مصروفاتك',
    'افهم عاداتك المالية',
    'خصوصيتك أولويتنا',
  ];

  static const descriptions = [
    'فلوسك أوضح، وقراراتك أذكى.\nابدأ رحلتك المالية بثقة.',
    'سجّل الدخل والمصروفات بسهولة،\nوخلي كل ريال في مكانه الصحيح.',
    'تابع تحليلاتك واكتشف\nأين تذهب أموالك.',
    'بياناتك محفوظة على جهازك.\nبدون ربط بنكي أو اشتراكات.',
  ];

  // صور حقيقية لمعالم سعودية بدون عرض أسمائها في الواجهة.
  // يتم تحميلها من الإنترنت.
  static const imageUrls = [
    'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=1200',
    'https://images.unsplash.com/photo-1494526585095-c41746248156?w=1200',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1200',
    'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?w=1200',
  ];

  static const icons = [
    Icons.account_balance_wallet_rounded,
    Icons.receipt_long_rounded,
    Icons.insights_rounded,
    Icons.shield_rounded,
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> done() async {
    if (finishing) return;

    setState(() => finishing = true);
    await widget.onDone();
  }

  Future<void> next() async {
    if (page == 3) {
      await done();
    } else {
      await controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Text(
                    'وفرة',
                    style: TextStyle(
                      color: darkGreen,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (page < 3)
                    TextButton(
                      onPressed: done,
                      child: const Text('تخطي'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: 4,
                onPageChanged: (value) {
                  setState(() => page = value);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: AspectRatio(
                            aspectRatio: 0.9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: darkGreen,
                                    child: const Icon(
                                      Icons.account_balance_rounded,
                                      color: gold,
                                      size: 120,
                                    ),
                                  ),
                                  Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stack) {
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0x00064D3B),
                                          Color(0xDD064D3B),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.20,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        icons[index],
                                        color: Colors.white,
                                        size: 58,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          titles[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: darkGreen,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          descriptions[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF56665E),
                            fontSize: 15,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: page == index ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: page == index
                        ? green
                        : const Color(0xFFC7D5CD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: finishing ? null : next,
                  style: FilledButton.styleFrom(
                    backgroundColor: green,
                  ),
                  child: Text(
                    page == 3 ? 'ابدأ رحلتك مع وفرة' : 'التالي',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// MESSAGE PARSER
// ========================================

class ParsedMessage {
  final double? amount;
  final String title;
  final bool income;
  final String category;

  const ParsedMessage(
    this.amount,
    this.title,
    this.income,
    this.category,
  );
}

class MessageParser {
  static String normalizeDigits(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';

    return input.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (match) {
        final ch = match.group(0)!;
        final a = arabic.indexOf(ch);
        return (a >= 0 ? a : persian.indexOf(ch)).toString();
      },
    );
  }

  static ParsedMessage parse(String source) {
    final text = normalizeDigits(source);
    final lower = text.toLowerCase();

    final income = RegExp(
          r'إيداع|ايداع|حوالة واردة|تحويل وارد|استلام|راتب|تم إضافة|تم اضافة|credited|deposit|received|salary',
        ).hasMatch(lower) &&
        !RegExp(
          r'شراء|سحب|خصم|دفع|مدفوع|purchase|withdrawal|debit',
        ).hasMatch(lower);

    const number = r'([0-9][0-9,\.\s]*[0-9]|[0-9])';

    final patterns = [
      RegExp(
        '(?:مبلغ|بقيمة|المبلغ|amount|amt)\\s*[:：-]?\\s*$number\\s*(?:ر\\.?س\\.?|ريال|sar|s\\.?a\\.?r\\.?)?',
        caseSensitive: false,
      ),
      RegExp(
        '$number\\s*(?:ر\\.?س\\.?|ريال(?:\\s+سعودي)?|sar|s\\.?a\\.?r\\.?)',
        caseSensitive: false,
      ),
      RegExp(
        '(?:sar|ر\\.?س\\.?|ريال)\\s*[:：-]?\\s*$number',
        caseSensitive: false,
      ),
    ];

    double? amount;

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;

      String clean =
          (match.group(1) ?? '').replaceAll(' ', '');

      if (clean.contains(',') && clean.contains('.')) {
        clean = clean.lastIndexOf('.') > clean.lastIndexOf(',')
            ? clean.replaceAll(',', '')
            : clean.replaceAll('.', '').replaceAll(',', '.');
      } else if (RegExp(
        r'^\d{1,3}(,\d{3})+(\.\d+)?$',
      ).hasMatch(clean)) {
        clean = clean.replaceAll(',', '');
      } else if (RegExp(
        r'^\d{1,3}(\.\d{3})+(,\d+)?$',
      ).hasMatch(clean)) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '.');
      }

      amount = double.tryParse(clean);

      if (amount != null && amount.isFinite && amount > 0) {
        break;
      }
    }

    String title = income ? 'دخل من رسالة' : 'مصروف من رسالة';

    final merchant = RegExp(
      r'(?:لدى|عند|من متجر|merchant|at)\s*[:：-]?\s*([^\n\r،,]{2,45})',
      caseSensitive: false,
    ).firstMatch(text);

    if (merchant != null) {
      String name = merchant.group(1)!.trim();

      name = name.replaceFirst(
        RegExp(
          r'\s+(?:باستخدام|بطاقة|بتاريخ|الرصيد|ending|card)\b.*$',
          caseSensitive: false,
        ),
        '',
      );

      if (name.trim().isNotEmpty) {
        title = name.trim();
      }
    }

    String category = income ? 'دخل آخر' : 'أخرى';

    if (income) {
      if (RegExp(r'راتب|salary').hasMatch(lower)) {
        category = 'راتب';
      }
    } else if (RegExp(
      r'مطعم|كافيه|قهوة|وجبة|طعام|restaurant|coffee|food',
    ).hasMatch(lower)) {
      category = 'طعام';
    } else if (RegExp(
      r'بنزين|وقود|محطة|uber|careem|أوبر|كريم|مواصلات',
    ).hasMatch(lower)) {
      category = 'مواصلات';
    } else if (RegExp(
      r'فاتورة|كهرباء|مياه|اتصالات|stc|mobily|زين',
    ).hasMatch(lower)) {
      category = 'فواتير';
    } else if (RegExp(
      r'صيدلية|مستشفى|عيادة|pharmacy',
    ).hasMatch(lower)) {
      category = 'صحة';
    } else if (RegExp(
      r'جرير|تسوق|متجر|shop|amazon|نون|شراء',
    ).hasMatch(lower)) {
      category = 'تسوق';
    }

    return ParsedMessage(amount, title, income, category);
  }
}

// ========================================
// ADD ENTRY SHEET
// ========================================

class EntrySheet extends StatefulWidget {
  final bool fromMessage;

  const EntrySheet({
    super.key,
    this.fromMessage = false,
  });

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  final title = TextEditingController();
  final amount = TextEditingController();
  final message = TextEditingController();

  bool income = false;
  String category = 'طعام';
  bool parsed = false;

  static const expenseCategories = [
    'طعام',
    'تسوق',
    'مواصلات',
    'فواتير',
    'صحة',
    'أخرى',
  ];

  static const incomeCategories = [
    'راتب',
    'عمل إضافي',
    'دخل آخر',
  ];

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    message.dispose();
    super.dispose();
  }

  void analyze() {
    if (message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الصق الرسالة أولاً')),
      );
      return;
    }

    final result = MessageParser.parse(message.text);

    setState(() {
      parsed = true;
      income = result.income;
      category = result.category;
      title.text = result.title;
      amount.text = result.amount?.toStringAsFixed(2) ?? '';
    });

    if (result.amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لم أتعرف على المبلغ. اكتبه يدوياً.',
          ),
        ),
      );
    }
  }

  void saveEntry() {
    final value = double.tryParse(
      MessageParser.normalizeDigits(
        amount.text.trim(),
      ).replaceAll(',', '.'),
    );

    if (title.text.trim().isEmpty ||
        value == null ||
        !value.isFinite ||
        value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل وصفاً ومبلغاً صحيحاً'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      Entry(
        title.text.trim(),
        value,
        income,
        category,
        DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        income ? incomeCategories : expenseCategories;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.fromMessage
                  ? 'إضافة من رسالة'
                  : 'إضافة عملية جديدة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (widget.fromMessage) ...[
              const Text(
                'انسخ رسالة العملية من أي تطبيق، ثم الصقها هنا. '
                'لن يتم حفظ نص الرسالة الأصلية.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة المنسوخة',
                  hintText: 'اضغط مطولاً هنا ثم اختر لصق',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: analyze,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('تحليل الرسالة'),
              ),
              if (parsed)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'راجع التفاصيل قبل الحفظ.',
                    style: TextStyle(color: green),
                  ),
                ),
              const SizedBox(height: 10),
            ],
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
              selected: {income},
              onSelectionChanged: (selection) {
                setState(() {
                  income = selection.first;
                  category = income ? 'راتب' : 'طعام';
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'الوصف',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالريال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(income),
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => category = value);
                }
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: saveEntry,
              icon: const Icon(Icons.check),
              label: const Text('حفظ العملية'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========================================
// HOME PAGE
// ========================================

class HomePage extends StatefulWidget {
  final bool dark;
  final VoidCallback onTheme;

  const HomePage({
    super.key,
    required this.dark,
    required this.onTheme,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
          .map(
            (item) => Entry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        entries
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      debugPrint('Error loading entries: $error');
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'entries',
      jsonEncode(
        entries.map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  double get income => entries
      .where((entry) => entry.income)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  double get expense => entries
      .where((entry) => !entry.income)
      .fold(0.0, (sum, entry) => sum + entry.amount);

  String money(double value) => '${value.toStringAsFixed(2)} ر.س';

  Future<void> addEntry({bool fromMessage = false}) async {
    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EntrySheet(
        fromMessage: fromMessage,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      entries.insert(0, result);
    });

    await save();
  }

  Widget stat(
    String title,
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
              Text(title),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [darkGreen, green],
            ),
            borderRadius: BorderRadius.circular(24),
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
              const SizedBox(height: 10),
              Text(
                money(income - expense),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'كل ريال تحسب له حساب',
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
              Icons.south_west,
              Colors.green,
            ),
            stat(
              'المصروفات',
              money(expense),
              Icons.north_east,
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: () => addEntry(fromMessage: true),
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('إضافة من رسالة منسوخة'),
        ),
        const SizedBox(height: 20),
        Text(
          'آخر العمليات',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'ابدأ بإضافة أول عملية مالية',
              ),
            ),
          ),
        ...entries.take(30).map(
          (entry) => Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  entry.income
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
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
                setState(() => entries.remove(entry));
                await save();
              },
            ),
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget analytics() {
    final categories = <String, double>{};

    for (final entry in entries.where((e) => !e.income)) {
      categories[entry.category] =
          (categories[entry.category] ?? 0) + entry.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          'تحليل مصروفاتك',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي المصروفات'),
                const SizedBox(height: 8),
                Text(
                  money(expense),
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: green,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text(
                'لا توجد مصروفات لعرض التحليلات بعد',
              ),
            ),
          ),
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
                  const SizedBox(height: 12),
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
        const SizedBox(height: 24),
        const Text(
          'بياناتك محفوظة محلياً على جهازك. '
          'لا يوجد ربط بحسابات بنكية.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'وفرة | Waffra',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: widget.onTheme,
            tooltip: 'تغيير المظهر',
            icon: Icon(
              widget.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: tab == 0 ? dashboard() : analytics(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addEntry(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة عملية'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
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
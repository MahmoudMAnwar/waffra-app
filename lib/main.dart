
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaffraApp());
}

const Color waffraGreen = Color(0xFF087A54);
const Color waffraDarkGreen = Color(0xFF064D3B);
const Color waffraGold = Color(0xFFD5B675);
const Color waffraCream = Color(0xFFF7F5EF);

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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'amount': amount,
      'income': income,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

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

class WaffraApp extends StatefulWidget {
  const WaffraApp({super.key});

  @override
  State<WaffraApp> createState() => _WaffraAppState();
}

class _WaffraAppState extends State<WaffraApp> {
  bool dark = false;
  bool loading = true;
  bool onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    checkOnboarding();
  }

  Future<void> checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      onboardingCompleted =
          prefs.getBool('waffra_onboarding_completed') ?? false;
      loading = false;
    });
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waffra_onboarding_completed', true);

    if (!mounted) return;

    setState(() {
      onboardingCompleted = true;
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
        colorSchemeSeed: waffraGreen,
        scaffoldBackgroundColor: waffraCream,
        appBarTheme: const AppBarTheme(
          backgroundColor: waffraCream,
          foregroundColor: waffraDarkGreen,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: waffraGreen,
      ),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: loading
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : onboardingCompleted
                ? HomePage(
                    dark: dark,
                    toggleTheme: () {
                      setState(() {
                        dark = !dark;
                      });
                    },
                  )
                : OnboardingPage(
                    onFinish: finishOnboarding,
                  ),
      ),
    );
  }
}

// ========================================
// ONBOARDING
// ========================================

class OnboardingData {
  final String title;
  final String subtitle;
  final String landmark;
  final IconData icon;
  final Color color;

  const OnboardingData({
    required this.title,
    required this.subtitle,
    required this.landmark,
    required this.icon,
    required this.color,
  });
}

class OnboardingPage extends StatefulWidget {
  final Future<void> Function() onFinish;

  const OnboardingPage({
    super.key,
    required this.onFinish,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController controller = PageController();

  int currentPage = 0;
  bool finishing = false;

  final List<OnboardingData> pages = const [
    OnboardingData(
      title: 'أهلاً بك في وفرة',
      subtitle:
          'فلوسك أوضح، وقراراتك أذكى.\nرحلتك نحو إدارة مالية أفضل تبدأ هنا.',
      landmark: 'برج المملكة • الرياض',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF064D3B),
    ),
    OnboardingData(
      title: 'تحكّم في مصروفاتك',
      subtitle:
          'سجّل دخلك ومصروفاتك بسهولة،\nوخلي كل ريال في مكانه الصحيح.',
      landmark: 'الدرعية • أصالة سعودية',
      icon: Icons.payments_rounded,
      color: Color(0xFF087A54),
    ),
    OnboardingData(
      title: 'افهم عاداتك المالية',
      subtitle:
          'تابع ملخص دخلك ومصروفاتك،\nواكتشف أين تذهب أموالك.',
      landmark: 'مركز الملك عبدالله المالي • الرياض',
      icon: Icons.insert_chart_rounded,
      color: Color(0xFF075B4C),
    ),
    OnboardingData(
      title: 'خصوصيتك أولويتنا',
      subtitle:
          'بياناتك محفوظة محلياً على جهازك.\nلا ربط بنكي ولا حاجة لبيانات بطاقتك.',
      landmark: 'وفرة • خصوصية واطمئنان',
      icon: Icons.shield_rounded,
      color: Color(0xFF064D3B),
    ),
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (currentPage < pages.length - 1) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await complete();
    }
  }

  Future<void> complete() async {
    if (finishing) return;

    setState(() {
      finishing = true;
    });

    await widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: waffraCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              child: Row(
                children: [
                  const Text(
                    'وفرة',
                    style: TextStyle(
                      color: waffraDarkGreen,
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (currentPage < pages.length - 1)
                    TextButton(
                      onPressed: complete,
                      child: const Text('تخطي'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: pages.length,
                onPageChanged: (value) {
                  setState(() {
                    currentPage = value;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingSlide(
                    data: pages[index],
                    index: index,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) {
                  final selected = index == currentPage;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: selected ? 28 : 8,
                    decoration: BoxDecoration(
                      color: selected
                          ? waffraGreen
                          : const Color(0xFFC7D5CD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
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
                    backgroundColor: waffraGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(
                    currentPage == pages.length - 1
                        ? 'ابدأ رحلتك مع وفرة'
                        : 'التالي',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
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

class OnboardingSlide extends StatelessWidget {
  final OnboardingData data;
  final int index;

  const OnboardingSlide({
    super.key,
    required this.data,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: AspectRatio(
              aspectRatio: 0.95,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      data.color,
                      waffraGreen,
                      const Color(0xFF0B9973),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -70,
                        left: -65,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12),
                              width: 35,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -100,
                        right: -75,
                        child: Container(
                          width: 260,
                          height: 260,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: waffraGold.withValues(alpha: 0.20),
                              width: 42,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LandmarkIllustration(index: index),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(17),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                data.icon,
                                size: 45,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: 22,
                        left: 16,
                        right: 16,
                        child: Text(
                          data.landmark,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: waffraDarkGreen,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: Color(0xFF56665E),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// رسومات معمارية مبسطة مستوحاة من المعالم السعودية.
// لا تستخدم صوراً أو شعارات رسمية.

class LandmarkIllustration extends StatelessWidget {
  final int index;

  const LandmarkIllustration({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    switch (index) {
      case 0:
        return const KingdomTowerIllustration();
      case 1:
        return const Icon(
          Icons.account_balance_rounded,
          color: waffraGold,
          size: 145,
        );
      case 2:
        return const Icon(
          Icons.apartment_rounded,
          color: waffraGold,
          size: 145,
        );
      default:
        return const Icon(
          Icons.lock_person_rounded,
          color: waffraGold,
          size: 145,
        );
    }
  }
}

class KingdomTowerIllustration extends StatelessWidget {
  const KingdomTowerIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 175,
      width: 145,
      child: CustomPaint(
        painter: KingdomTowerPainter(),
      ),
    );
  }
}

class KingdomTowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final towerPaint = Paint()
      ..color = waffraGold
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..moveTo(size.width * 0.25, size.height)
      ..lineTo(size.width * 0.36, size.height * 0.10)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.25,
        size.width * 0.64,
        size.height * 0.10,
      )
      ..lineTo(size.width * 0.75, size.height)
      ..close();

    canvas.drawPath(path, towerPaint);
    canvas.drawPath(path, outlinePaint);

    final opening = Path()
      ..moveTo(size.width * 0.40, size.height * 0.13)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.23,
        size.width * 0.60,
        size.height * 0.13,
      )
      ..lineTo(size.width * 0.57, size.height * 0.30)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.35,
        size.width * 0.43,
        size.height * 0.30,
      )
      ..close();

    canvas.drawPath(
      opening,
      Paint()..color = waffraDarkGreen,
    );

    final windowPaint = Paint()
      ..color = waffraDarkGreen.withValues(alpha: 0.30)
      ..strokeWidth = 1;

    for (int i = 0; i < 9; i++) {
      final y = size.height * (0.40 + i * 0.06);

      canvas.drawLine(
        Offset(size.width * 0.37, y),
        Offset(size.width * 0.63, y),
        windowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================================
// ADD ENTRY SHEET
// ========================================

class AddEntrySheet extends StatefulWidget {
  const AddEntrySheet({super.key});

  @override
  State<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends State<AddEntrySheet> {
  final titleController = TextEditingController();
  final amountController = TextEditingController();

  bool isIncome = false;
  String category = 'طعام';

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void saveEntry() {
    final title = titleController.text.trim();

    final amount = double.tryParse(
      amountController.text.trim().replaceAll(',', '.'),
    );

    if (title.isEmpty ||
        amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك أدخل وصفاً ومبلغاً صحيحاً'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      Entry(
        title,
        amount,
        isIncome,
        category,
        DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = isIncome
        ? ['راتب', 'عمل إضافي', 'دخل آخر']
        : [
            'طعام',
            'تسوق',
            'مواصلات',
            'فواتير',
            'صحة',
            'أخرى',
          ];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
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
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('مصروف'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('دخل'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {isIncome},
              onSelectionChanged: (selection) {
                setState(() {
                  isIncome = selection.first;
                  category = isIncome ? 'راتب' : 'طعام';
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'وصف العملية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالريال السعودي',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey(isIncome),
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    category = value;
                  });
                }
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: saveEntry,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('حفظ العملية'),
              style: FilledButton.styleFrom(
                backgroundColor: waffraGreen,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
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
  final VoidCallback toggleTheme;

  const HomePage({
    super.key,
    required this.dark,
    required this.toggleTheme,
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

  double get income {
    return entries
        .where((entry) => entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double get expense {
    return entries
        .where((entry) => !entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  String money(double amount) {
    return '${amount.toStringAsFixed(2)} ر.س';
  }

  Future<void> addEntry() async {
    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const AddEntrySheet(),
    );

    if (!mounted || result == null) return;

    setState(() {
      entries.insert(0, result);
    });

    await save();
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
              colors: [
                waffraDarkGreen,
                waffraGreen,
              ],
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
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            statCard(
              title: 'الدخل',
              value: money(income),
              icon: Icons.south_west,
              color: Colors.green,
            ),
            statCard(
              title: 'المصروفات',
              value: money(expense),
              icon: Icons.north_east,
              color: Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'آخر العمليات',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'لسه مفيش عمليات.\nابدأ بإضافة أول دخل أو مصروف.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ...entries.take(30).map(
          (entry) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: entry.income
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                child: Icon(
                  entry.income
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: entry.income
                      ? Colors.green
                      : Colors.deepOrange,
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
                  fontWeight: FontWeight.bold,
                  color: entry.income
                      ? Colors.green
                      : Theme.of(context).colorScheme.onSurface,
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
        const SizedBox(height: 90),
      ],
    );
  }

  Widget analytics() {
    final categories = <String, double>{};

    for (final entry in entries.where((item) => !item.income)) {
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
                    color: waffraGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(30),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          'وفرة لا يطلب بيانات حسابات أو بطاقات بنكية.',
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تغيير المظهر',
            onPressed: widget.toggleTheme,
            icon: Icon(
              widget.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: tab == 0 ? dashboard() : analytics(),
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
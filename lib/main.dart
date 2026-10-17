
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaffraApp());
}

const kGreen = Color(0xFF087A54);
const kDarkGreen = Color(0xFF064D3B);
const kCream = Color(0xFFF7F6F0);
const kGold = Color(0xFFD8BA78);

String formatMoney(double amount) {
  return '${amount.toStringAsFixed(2)} ر.س';
}

String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

String normalizeDigits(String value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';

  return value.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
    final char = match.group(0)!;
    final index = arabic.indexOf(char);
    return '${index >= 0 ? index : persian.indexOf(char)}';
  });
}

double? parseAmount(String text) {
  var value = normalizeDigits(text).replaceAll(' ', '').trim();

  if (value.contains(',') && value.contains('.')) {
    value = value.lastIndexOf('.') > value.lastIndexOf(',')
        ? value.replaceAll(',', '')
        : value.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$')
      .hasMatch(value)) {
    value = value.replaceAll(',', '');
  } else {
    value = value.replaceAll(',', '.');
  }

  return double.tryParse(value);
}

// ============================================
// MODELS
// ============================================

class MoneyEntry {
  final String id;
  final String title;
  final double amount;
  final bool income;
  final String category;
  final DateTime date;

  const MoneyEntry({
    required this.id,
    required this.title,
    required this.amount,
    required this.income,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'income': income,
        'category': category,
        'date': date.toIso8601String(),
      };

  factory MoneyEntry.fromJson(Map<String, dynamic> json) {
    return MoneyEntry(
      id: (json['id'] ??
              DateTime.now().microsecondsSinceEpoch.toString())
          .toString(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      income: json['income'] == true,
      category: (json['category'] ?? 'أخرى').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class WaffraProfile {
  final String name;
  final String email;
  final String provider;
  final String gender;
  final String avatar;
  final DateTime birthday;

  const WaffraProfile({
    required this.name,
    required this.email,
    required this.provider,
    required this.gender,
    required this.avatar,
    required this.birthday,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'provider': provider,
        'gender': gender,
        'avatar': avatar,
        'birthday': birthday.toIso8601String(),
      };

  factory WaffraProfile.fromJson(Map<String, dynamic> json) {
    return WaffraProfile(
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      provider: (json['provider'] ?? 'Google').toString(),
      gender: (json['gender'] ?? 'ذكر').toString(),
      avatar: (json['avatar'] ?? 'person').toString(),
      birthday:
          DateTime.tryParse((json['birthday'] ?? '').toString()) ??
              DateTime(2000),
    );
  }
}

IconData avatarIcon(String value) {
  switch (value) {
    case 'male':
      return Icons.face_rounded;
    case 'female':
      return Icons.face_3_rounded;
    case 'smile':
      return Icons.sentiment_very_satisfied_rounded;
    default:
      return Icons.person_rounded;
  }
}

// ============================================
// APPLICATION
// ============================================

class WaffraApp extends StatefulWidget {
  const WaffraApp({super.key});

  @override
  State<WaffraApp> createState() => _WaffraAppState();
}

class _WaffraAppState extends State<WaffraApp> {
  bool loading = true;
  bool onboardingDone = false;
  bool darkMode = false;
  WaffraProfile? profile;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfile = prefs.getString('waffra_profile');

    WaffraProfile? savedProfile;

    if (rawProfile != null) {
      try {
        savedProfile = WaffraProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawProfile)),
        );
      } catch (error) {
        debugPrint('Profile loading error: $error');
      }
    }

    if (!mounted) return;

    setState(() {
      onboardingDone =
          prefs.getBool('waffra_onboarding_completed') ?? false;
      darkMode = prefs.getBool('waffra_dark_mode') ?? false;
      profile = savedProfile;
      loading = false;
    });
  }

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waffra_onboarding_completed', true);

    if (mounted) {
      setState(() => onboardingDone = true);
    }
  }

  Future<void> saveProfile(WaffraProfile value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'waffra_profile',
      jsonEncode(value.toJson()),
    );

    if (mounted) {
      setState(() => profile = value);
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('waffra_profile');

    if (mounted) {
      setState(() => profile = null);
    }
  }

  Future<void> toggleTheme() async {
    final next = !darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waffra_dark_mode', next);

    if (mounted) {
      setState(() => darkMode = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وفرة | Waffra',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SA'),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: kGreen,
        scaffoldBackgroundColor: kCream,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: kGreen,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: loading
            ? const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              )
            : !onboardingDone
                ? OnboardingScreen(onFinish: finishOnboarding)
                : profile == null
                    ? DemoLoginScreen(onSave: saveProfile)
                    : HomeScreen(
                        profile: profile!,
                        darkMode: darkMode,
                        onToggleTheme: toggleTheme,
                        onSignOut: signOut,
                        onSaveProfile: saveProfile,
                      ),
      ),
    );
  }
}

// ============================================
// ONBOARDING - FULL SCREEN IMAGES
// ============================================

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onFinish;

  const OnboardingScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController controller = PageController();
  int current = 0;
  bool finishing = false;

  static const titles = [
    'أهلاً بك في وفرة',
    'تحكّم في مصروفاتك',
    'افهم عاداتك المالية',
    'خصوصيتك أولويتنا',
  ];

  static const subtitles = [
    'فلوسك أوضح، وقراراتك أذكى',
    'سجّل دخلك ومصروفاتك بكل سهولة',
    'اكتشف أين تذهب أموالك كل شهر',
    'بياناتك المالية محفوظة على جهازك',
  ];

  // صور خلفية بملء الشاشة.
  // يمكن استبدال الروابط بصور سعودية موثقة لاحقاً.
  static const images = [
    'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=1400',
    'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=1400',
    'https://images.unsplash.com/photo-1494526585095-c41746248156?w=1400',
    'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?w=1400',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> next() async {
    if (finishing) return;

    if (current == 3) {
      setState(() => finishing = true);
      await widget.onFinish();
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            itemCount: 4,
            onPageChanged: (index) {
              setState(() => current = index);
            },
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: kDarkGreen),
                  Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: kDarkGreen,
                        child: const Icon(
                          Icons.landscape_rounded,
                          color: kGold,
                          size: 140,
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x88000000),
                          Color(0x00000000),
                          Color(0xAA000000),
                          Color(0xEE032D24),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        25,
                        45,
                        25,
                        135,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'وفرة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            titles[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            subtitles[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              height: 1.7,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: current < 3
                        ? TextButton(
                            onPressed: widget.onFinish,
                            child: const Text(
                              'تخطي',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const SizedBox(height: 48),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: index == current ? 28 : 8,
                      decoration: BoxDecoration(
                        color: index == current
                            ? kGold
                            : Colors.white54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    22,
                    24,
                    25,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: finishing ? null : next,
                      style: FilledButton.styleFrom(
                        backgroundColor: kGreen,
                      ),
                      child: Text(
                        current == 3 ? 'ابدأ مع وفرة' : 'التالي',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// DEMO LOGIN
// ============================================

class DemoLoginScreen extends StatefulWidget {
  final Future<void> Function(WaffraProfile) onSave;

  const DemoLoginScreen({
    super.key,
    required this.onSave,
  });

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  String? provider;

  @override
  Widget build(BuildContext context) {
    if (provider != null) {
      return ProfileForm(
        provider: provider!,
        onSave: widget.onSave,
        onBack: () => setState(() => provider = null),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  height: 110,
                  width: 110,
                  decoration: const BoxDecoration(
                    color: kDarkGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'وفرة',
                  style: TextStyle(
                    color: kGreen,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'أهلاً بك في رحلتك المالية',
                  style: TextStyle(fontSize: 19),
                ),
                const SizedBox(height: 34),
                const Text(
                  'تسجيل دخول تجريبي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => provider = 'Google');
                    },
                    icon: const Icon(
                      Icons.g_mobiledata_rounded,
                      size: 32,
                    ),
                    label: const Text(
                      'المتابعة باستخدام Google',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() => provider = 'Apple');
                    },
                    icon: const Icon(Icons.apple),
                    label: const Text(
                      'المتابعة باستخدام Apple',
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                const Text(
                  'نسخة تجريبية مجانية: الأزرار لا تتصل '
                  'بـ Google أو Apple ولا تتحقق من ملكية الإيميل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// PROFILE FORM
// ============================================

class ProfileForm extends StatefulWidget {
  final String provider;
  final WaffraProfile? initial;
  final Future<void> Function(WaffraProfile) onSave;
  final VoidCallback? onBack;

  const ProfileForm({
    super.key,
    required this.provider,
    required this.onSave,
    this.initial,
    this.onBack,
  });

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final TextEditingController name;
  late final TextEditingController email;

  late String gender;
  late String avatar;
  late DateTime birthday;

  bool saving = false;

  @override
  void initState() {
    super.initState();

    name = TextEditingController(
      text: widget.initial?.name ?? '',
    );
    email = TextEditingController(
      text: widget.initial?.email ?? '',
    );
    gender = widget.initial?.gender ?? 'ذكر';
    avatar = widget.initial?.avatar ?? 'person';
    birthday = widget.initial?.birthday ?? DateTime(2000, 1, 1);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> pickBirthday() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: birthday,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() => birthday = selected);
    }
  }

  Future<void> submit() async {
    final userName = name.text.trim();
    final userEmail = email.text.trim();

    if (userName.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(userEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل الاسم وبريدًا إلكترونيًا صحيحًا'),
        ),
      );
      return;
    }

    setState(() => saving = true);

    await widget.onSave(
      WaffraProfile(
        name: userName,
        email: userEmail,
        provider: widget.provider,
        gender: gender,
        avatar: avatar,
        birthday: birthday,
      ),
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (widget.initial != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(
          editing ? 'تعديل الملف الشخصي' : 'استكمال الملف الشخصي',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              editing
                  ? 'بيانات حسابك'
                  : 'المتابعة عبر ${widget.provider} — تجريبي',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: kGreen,
                child: Icon(
                  avatarIcon(avatar),
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'اختر Avatar',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 9,
              children: ['person', 'male', 'female', 'smile']
                  .map(
                    (value) => ChoiceChip(
                      label: Icon(avatarIcon(value)),
                      selected: avatar == value,
                      onSelected: (_) {
                        setState(() => avatar = value);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 25),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'name@gmail.com أو name@icloud.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(
                labelText: 'الجنس',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'ذكر',
                  child: Text('Male - ذكر'),
                ),
                DropdownMenuItem(
                  value: 'أنثى',
                  child: Text('Female - أنثى'),
                ),
                DropdownMenuItem(
                  value: 'غير محدد',
                  child: Text('أفضل عدم التحديد'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => gender = value);
                }
              },
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: pickBirthday,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                'تاريخ الميلاد: ${formatDate(birthday)}',
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: saving ? null : submit,
                child: Text(
                  editing ? 'حفظ التعديلات' : 'إنشاء الحساب والدخول',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'هذا ملف شخصي محلي، وليس حساب Google أو Apple '
              'حقيقيًا. لا يتم تخزين كلمة مرور.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// MESSAGE PARSER
// ============================================

class MessageData {
  final double? amount;
  final String title;
  final bool income;
  final String category;

  const MessageData(
    this.amount,
    this.title,
    this.income,
    this.category,
  );
}

MessageData analyzeMessage(String source) {
  final text = normalizeDigits(source);
  final lower = text.toLowerCase();

  final isIncome = RegExp(
        r'راتب|إيداع|ايداع|حوالة واردة|تحويل وارد|استلام|salary|credited|deposit|received',
        caseSensitive: false,
      ).hasMatch(lower) &&
      !RegExp(
        r'شراء|خصم|دفع|سحب|purchase|debit|withdrawal',
        caseSensitive: false,
      ).hasMatch(lower);

  final patterns = [
    RegExp(
      r'(?:مبلغ|بقيمة|المبلغ|amount|amt)\s*[:\-]?\s*([0-9][0-9,\.]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'([0-9][0-9,\.]*)\s*(?:sar|ريال|ر\.?س\.?)',
      caseSensitive: false,
    ),
    RegExp(
      r'(?:sar|ريال|ر\.?س\.?)\s*([0-9][0-9,\.]*)',
      caseSensitive: false,
    ),
  ];

  double? amount;

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);

    if (match == null) continue;

    amount = parseAmount(match.group(1) ?? '');

    if (amount != null && amount > 0 && amount.isFinite) {
      break;
    }
  }

  String title = isIncome ? 'دخل من رسالة' : 'مصروف من رسالة';

  final merchant = RegExp(
    r'(?:لدى|عند|merchant|at)\s*[:\-]?\s*([^\n\r،,]{2,45})',
    caseSensitive: false,
  ).firstMatch(text);

  if (merchant != null) {
    final value = merchant.group(1)!
        .split(
          RegExp(
            r'باستخدام|بطاقة|الرصيد|بتاريخ|card',
            caseSensitive: false,
          ),
        )
        .first
        .trim();

    if (value.isNotEmpty) title = value;
  }

  String category = isIncome ? 'دخل آخر' : 'أخرى';

  if (isIncome) {
    if (RegExp(r'راتب|salary').hasMatch(lower)) {
      category = 'راتب';
    }
  } else if (RegExp(
    r'مطعم|كافيه|قهوة|طعام|food|coffee|restaurant',
  ).hasMatch(lower)) {
    category = 'طعام';
  } else if (RegExp(
    r'بنزين|وقود|محطة|أوبر|كريم|uber|careem',
  ).hasMatch(lower)) {
    category = 'مواصلات';
  } else if (RegExp(
    r'فاتورة|كهرباء|مياه|stc|mobily|زين',
  ).hasMatch(lower)) {
    category = 'فواتير';
  } else if (RegExp(
    r'صيدلية|مستشفى|عيادة|pharmacy',
  ).hasMatch(lower)) {
    category = 'صحة';
  } else if (RegExp(
    r'جرير|تسوق|شراء|amazon|noon|نون|shop',
  ).hasMatch(lower)) {
    category = 'تسوق';
  }

  return MessageData(
    amount,
    title,
    isIncome,
    category,
  );
}

// ============================================
// ADD / EDIT TRANSACTION
// ============================================

class EntrySheet extends StatefulWidget {
  final MoneyEntry? initial;
  final bool fromMessage;

  const EntrySheet({
    super.key,
    this.initial,
    this.fromMessage = false,
  });

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late final TextEditingController titleController;
  late final TextEditingController amountController;
  final messageController = TextEditingController();

  late bool income;
  late String category;
  late DateTime date;

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
  void initState() {
    super.initState();

    final entry = widget.initial;

    titleController = TextEditingController(
      text: entry?.title ?? '',
    );

    amountController = TextEditingController(
      text: entry?.amount.toStringAsFixed(2) ?? '',
    );

    income = entry?.income ?? false;
    category = entry?.category ?? 'طعام';
    date = entry?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void analyze() {
    if (messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الصق نص الرسالة أولاً'),
        ),
      );
      return;
    }

    final result = analyzeMessage(messageController.text);

    setState(() {
      income = result.income;
      category = result.category;
      titleController.text = result.title;
      amountController.text =
          result.amount?.toStringAsFixed(2) ?? '';
    });

    if (result.amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم أتعرف على المبلغ، اكتبه يدوياً'),
        ),
      );
    }
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => date = picked);
    }
  }

  void save() {
    final value = parseAmount(amountController.text);

    if (titleController.text.trim().isEmpty ||
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
      MoneyEntry(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: titleController.text.trim(),
        amount: value,
        income: income,
        category: category,
        date: date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        income ? incomeCategories : expenseCategories;

    final selectedCategory = categories.contains(category)
        ? category
        : categories.last;

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
              widget.initial != null
                  ? 'تعديل العملية'
                  : widget.fromMessage
                      ? 'إضافة من رسالة'
                      : 'إضافة عملية جديدة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (widget.fromMessage) ...[
              const Text(
                'انسخ رسالة العملية من الموبايل والصقها هنا. '
                'سيتم تحليلها محلياً بدون اشتراك.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة',
                  hintText: 'اضغط مطولاً واختر لصق',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: analyze,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('تحليل الرسالة'),
              ),
              const SizedBox(height: 12),
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
              onSelectionChanged: (selected) {
                setState(() {
                  income = selected.first;
                  category = income ? 'راتب' : 'طعام';
                });
              },
            ),
            const SizedBox(height: 15),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'وصف العملية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالريال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 13),
            DropdownButtonFormField<String>(
              key: ValueKey(income),
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                border: OutlineInputBorder(),
              ),
              items: categories.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => category = value);
                }
              },
            ),
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: pickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text('التاريخ: ${formatDate(date)}'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.check),
              label: Text(
                widget.initial == null
                    ? 'حفظ العملية'
                    : 'حفظ التعديلات',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// CHARTS - NO EXTRA PACKAGES
// ============================================

class ChartPoint {
  final String label;
  final double income;
  final double expense;

  const ChartPoint(
    this.label,
    this.income,
    this.expense,
  );
}

class FinanceBarChart extends StatelessWidget {
  final List<ChartPoint> points;

  const FinanceBarChart({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    double maximum = 1;

    for (final point in points) {
      if (point.income > maximum) maximum = point.income;
      if (point.expense > maximum) maximum = point.expense;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 12, height: 12, color: kGreen),
            const SizedBox(width: 6),
            const Text('الدخل'),
            const SizedBox(width: 20),
            Container(
              width: 12,
              height: 12,
              color: Colors.deepOrange,
            ),
            const SizedBox(width: 6),
            const Text('المصروفات'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: points.map((point) {
              return Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor:
                                  (point.income / maximum).clamp(
                                0.015,
                                1.0,
                              ),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: kGreen,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor:
                                  (point.expense / maximum).clamp(
                                0.015,
                                1.0,
                              ),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: const BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      point.label,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ============================================
// HOME
// ============================================

class HomeScreen extends StatefulWidget {
  final WaffraProfile profile;
  final bool darkMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onSignOut;
  final Future<void> Function(WaffraProfile) onSaveProfile;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.darkMode,
    required this.onToggleTheme,
    required this.onSignOut,
    required this.onSaveProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<MoneyEntry> entries = [];

  int tab = 0;
  String search = '';
  String typeFilter = 'الكل';
  String categoryFilter = 'الكل';
  String analyticsPeriod = 'شهري';
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('entries');

    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as List;

      final loaded = data.map((item) {
        return MoneyEntry.fromJson(
          Map<String, dynamic>.from(item),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        entries
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      debugPrint('Entries loading error: $error');
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'entries',
      jsonEncode(
        entries.map((entry) => entry.toJson()).toList(),
      ),
    );
  }

  double totalIncome(Iterable<MoneyEntry> items) {
    return items
        .where((entry) => entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double totalExpense(Iterable<MoneyEntry> items) {
    return items
        .where((entry) => !entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  Future<void> openEntry({
    MoneyEntry? initial,
    bool fromMessage = false,
  }) async {
    final result = await showModalBottomSheet<MoneyEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return EntrySheet(
          initial: initial,
          fromMessage: fromMessage,
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      if (initial == null) {
        entries.insert(0, result);
      } else {
        final index =
            entries.indexWhere((entry) => entry.id == initial.id);

        if (index >= 0) {
          entries[index] = result;
        }
      }

      entries.sort((a, b) => b.date.compareTo(a.date));
    });

    await persist();
  }

  Future<void> deleteEntry(MoneyEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف العملية'),
          content: Text(
            'هل تريد حذف "${entry.title}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      entries.removeWhere((item) => item.id == entry.id);
    });

    await persist();
  }

  List<MoneyEntry> get filteredEntries {
    final result = entries.where((entry) {
      final matchesSearch =
          entry.title.toLowerCase().contains(search.toLowerCase()) ||
              entry.category.toLowerCase().contains(
                    search.toLowerCase(),
                  );

      final matchesType = typeFilter == 'الكل' ||
          (typeFilter == 'الدخل' && entry.income) ||
          (typeFilter == 'المصروفات' && !entry.income);

      final matchesCategory = categoryFilter == 'الكل' ||
          entry.category == categoryFilter;

      return matchesSearch && matchesType && matchesCategory;
    }).toList();

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  List<String> get availableCategories {
    final categories = entries
        .where((entry) {
          if (typeFilter == 'الدخل') return entry.income;
          if (typeFilter == 'المصروفات') return !entry.income;
          return true;
        })
        .map((entry) => entry.category)
        .toSet()
        .toList()
      ..sort();

    return ['الكل', ...categories];
  }

  Widget balanceCard() {
    final income = totalIncome(entries);
    final expense = totalExpense(entries);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kDarkGreen, kGreen],
        ),
        borderRadius: BorderRadius.circular(25),
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
            formatMoney(income - expense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'كل ريال تحسب له حساب',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget miniStat(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(title),
              const SizedBox(height: 7),
              Text(
                formatMoney(amount),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget entryCard(MoneyEntry entry) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: entry.income
              ? kGreen.withValues(alpha: 0.12)
              : Colors.deepOrange.withValues(alpha: 0.12),
          child: Icon(
            entry.income
                ? Icons.south_west_rounded
                : Icons.north_east_rounded,
            color: entry.income ? kGreen : Colors.deepOrange,
          ),
        ),
        title: Text(entry.title),
        subtitle: Text(
          '${entry.category} • ${formatDate(entry.date)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${entry.income ? '+' : '-'}${formatMoney(entry.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.income ? kGreen : null,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  openEntry(initial: entry);
                } else if (value == 'delete') {
                  deleteEntry(entry);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 8),
                      Text('حذف'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget dashboard() {
    final filtered = filteredEntries;
    final categories = availableCategories;

    final selectedCategory = categories.contains(categoryFilter)
        ? categoryFilter
        : 'الكل';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'أهلاً، ${widget.profile.name} 👋',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 15),
        balanceCard(),
        const SizedBox(height: 15),
        Row(
          children: [
            miniStat(
              'إجمالي الدخل',
              totalIncome(entries),
              Icons.south_west,
              kGreen,
            ),
            miniStat(
              'المصروفات',
              totalExpense(entries),
              Icons.north_east,
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 15),
        OutlinedButton.icon(
          onPressed: () => openEntry(fromMessage: true),
          icon: const Icon(Icons.content_paste_rounded),
          label: const Text('إضافة من رسالة منسوخة'),
        ),
        const SizedBox(height: 22),
        Text(
          'عملياتك المالية',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 13),
        TextField(
          onChanged: (value) {
            setState(() => search = value);
          },
          decoration: const InputDecoration(
            labelText: 'بحث في الدخل أو المصروفات',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['الكل', 'الدخل', 'المصروفات'].map((type) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: typeFilter == type,
                  onSelected: (_) {
                    setState(() {
                      typeFilter = type;
                      categoryFilter = 'الكل';
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey('$typeFilter-$selectedCategory'),
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'فلتر التصنيف',
            border: OutlineInputBorder(),
          ),
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(category),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => categoryFilter = value ?? 'الكل');
          },
        ),
        const SizedBox(height: 12),
        Text(
          'عدد العمليات: ${filtered.length}',
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text('لا توجد عمليات مطابقة'),
            ),
          ),
        ...filtered.map(entryCard),
        const SizedBox(height: 100),
      ],
    );
  }

  List<MoneyEntry> get analyticsEntries {
    return entries.where((entry) {
      if (analyticsPeriod == 'شهري') {
        return entry.date.year == selectedYear &&
            entry.date.month == selectedMonth;
      }
      return entry.date.year == selectedYear;
    }).toList();
  }

  List<ChartPoint> chartPoints() {
    if (analyticsPeriod == 'شهري') {
      final days = DateTime(
        selectedYear,
        selectedMonth + 1,
        0,
      ).day;

      final weeks = (days / 7).ceil();

      return List.generate(weeks, (index) {
        final start = index * 7 + 1;
        final end = (start + 6).clamp(1, days);

        final items = analyticsEntries.where((entry) {
          return entry.date.day >= start &&
              entry.date.day <= end;
        });

        return ChartPoint(
          'أ${index + 1}',
          totalIncome(items),
          totalExpense(items),
        );
      });
    }

    return List.generate(12, (index) {
      final month = index + 1;

      final items = analyticsEntries.where((entry) {
        return entry.date.month == month;
      });

      return ChartPoint(
        '$month',
        totalIncome(items),
        totalExpense(items),
      );
    });
  }

  Widget analytics() {
    final items = analyticsEntries;
    final income = totalIncome(items);
    final expense = totalExpense(items);

    final categories = <String, double>{};

    for (final entry in items.where((e) => !e.income)) {
      categories[entry.category] =
          (categories[entry.category] ?? 0) + entry.amount;
    }

    final years = <int>{
      DateTime.now().year,
      selectedYear,
      ...entries.map((entry) => entry.date.year),
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(17),
      children: [
        Text(
          'التحليلات المالية',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 18),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'شهري',
              label: Text('شهري'),
            ),
            ButtonSegment(
              value: 'سنوي',
              label: Text('سنوي'),
            ),
          ],
          selected: {analyticsPeriod},
          onSelectionChanged: (value) {
            setState(() => analyticsPeriod = value.first);
          },
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  border: OutlineInputBorder(),
                ),
                items: years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text('$year'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedYear = value);
                  }
                },
              ),
            ),
            if (analyticsPeriod == 'شهري') ...[
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'الشهر',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (index) {
                    return DropdownMenuItem(
                      value: index + 1,
                      child: Text('شهر ${index + 1}'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedMonth = value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            miniStat(
              'الدخل',
              income,
              Icons.south_west,
              kGreen,
            ),
            miniStat(
              'المصروفات',
              expense,
              Icons.north_east,
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الدخل مقابل المصروفات',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 22),
                FinanceBarChart(points: chartPoints()),
                const SizedBox(height: 10),
                Text(
                  analyticsPeriod == 'شهري'
                      ? 'أ1، أ2... تمثل أسابيع الشهر'
                      : 'الأرقام تمثل أشهر السنة',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'توزيع المصروفات',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (categories.isEmpty)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(
              child: Text('لا توجد مصروفات في الفترة المحددة'),
            ),
          ),
        ...categories.entries.map((entry) {
          final ratio =
              expense <= 0 ? 0.0 : entry.value / expense;

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(formatMoney(entry.value)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 100),
      ],
    );
  }

  Future<void> editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileForm(
          provider: widget.profile.provider,
          initial: widget.profile,
          onSave: widget.onSaveProfile,
        ),
      ),
    );
  }

  Widget profilePage() {
    final profile = widget.profile;

    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 15),
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: kGreen,
            child: Icon(
              avatarIcon(profile.avatar),
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          profile.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          profile.email,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('طريقة الدخول التجريبية'),
                subtitle: Text(profile.provider),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('الجنس'),
                subtitle: Text(profile.gender),
              ),
              ListTile(
                leading: const Icon(Icons.cake_outlined),
                title: const Text('تاريخ الميلاد'),
                subtitle: Text(formatDate(profile.birthday)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: editProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('تعديل الملف الشخصي'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: widget.onToggleTheme,
          icon: Icon(
            widget.darkMode
                ? Icons.light_mode
                : Icons.dark_mode,
          ),
          label: const Text('تغيير المظهر'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('تسجيل الخروج التجريبي'),
        ),
        const SizedBox(height: 18),
        const Text(
          'ملاحظة: لا توجد مصادقة حقيقية أو مزامنة سحابية. '
          'البيانات المالية محفوظة محلياً على هذا الجهاز.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
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
            onPressed: widget.onToggleTheme,
            tooltip: 'تغيير المظهر',
            icon: Icon(
              widget.darkMode
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CircleAvatar(
              backgroundColor: kGreen,
              child: Icon(
                avatarIcon(widget.profile.avatar),
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: [
            dashboard(),
            analytics(),
            profilePage(),
          ],
        ),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => openEntry(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة عملية'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) {
          setState(() => tab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'التحليلات',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
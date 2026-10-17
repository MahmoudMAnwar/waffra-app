
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WaffraApp());
}

const Color green = Color(0xFF087A54);
const Color deepGreen = Color(0xFF064D3B);
const Color cream = Color(0xFFF8F6EF);
const Color gold = Color(0xFFD8BA78);

String money(num value) => '${value.toStringAsFixed(2)} ر.س';

String dateText(DateTime value) =>
    '${value.day}/${value.month}/${value.year}';

String normalizeDigits(String text) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';

  return text.replaceAllMapped(RegExp('[٠-٩۰-۹]'), (match) {
    final c = match.group(0)!;
    final a = ar.indexOf(c);
    return '${a >= 0 ? a : fa.indexOf(c)}';
  });
}

double? readAmount(String text) {
  var value = normalizeDigits(text).replaceAll(' ', '');

  if (value.contains(',') && value.contains('.')) {
    value = value.replaceAll(',', '');
  } else if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(value)) {
    value = value.replaceAll(',', '');
  } else {
    value = value.replaceAll(',', '.');
  }

  final number = double.tryParse(value);

  return number != null && number.isFinite && number > 0
      ? number
      : null;
}

// ==========================================
// MODELS
// ==========================================

class Entry {
  final String id;
  final String title;
  final double amount;
  final bool income;
  final String category;
  final DateTime date;

  const Entry({
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

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: (json['id'] ??
              DateTime.now().microsecondsSinceEpoch.toString())
          .toString(),
      title: (json['title'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      income: json['income'] == true,
      category: (json['category'] ?? 'أخرى').toString(),
      date: DateTime.tryParse('${json['date']}') ?? DateTime.now(),
    );
  }
}

class UserProfile {
  final String name;
  final String email;
  final String provider;
  final String gender;
  final String avatar;
  final DateTime birthday;

  const UserProfile({
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

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: '${json['name'] ?? ''}',
      email: '${json['email'] ?? ''}',
      provider: '${json['provider'] ?? 'Google'}',
      gender: '${json['gender'] ?? 'ذكر'}',
      avatar: '${json['avatar'] ?? 'person'}',
      birthday:
          DateTime.tryParse('${json['birthday']}') ?? DateTime(2000),
    );
  }
}

IconData avatarIcon(String value) {
  switch (value) {
    case 'male':
      return Icons.face;
    case 'female':
      return Icons.face_3;
    case 'smile':
      return Icons.sentiment_very_satisfied;
    default:
      return Icons.person;
  }
}

// ==========================================
// APPLICATION
// ==========================================

class WaffraApp extends StatefulWidget {
  const WaffraApp({super.key});

  @override
  State<WaffraApp> createState() => _WaffraAppState();
}

class _WaffraAppState extends State<WaffraApp> {
  bool loading = true;
  bool introDone = false;
  bool dark = false;
  UserProfile? profile;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    UserProfile? saved;

    final raw = prefs.getString('waffra_profile');

    if (raw != null) {
      try {
        saved = UserProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw)),
        );
      } catch (error) {
        debugPrint('Profile loading failed: $error');
      }
    }

    if (!mounted) return;

    setState(() {
      introDone =
          prefs.getBool('waffra_onboarding_completed') ?? false;
      dark = prefs.getBool('waffra_dark_mode') ?? false;
      profile = saved;
      loading = false;
    });
  }

  Future<void> finishIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('waffra_onboarding_completed', true);

    if (mounted) setState(() => introDone = true);
  }

  Future<void> saveProfile(UserProfile value) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'waffra_profile',
      jsonEncode(value.toJson()),
    );

    if (mounted) setState(() => profile = value);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('waffra_profile');

    if (mounted) setState(() => profile = null);
  }

  Future<void> toggleTheme() async {
    final value = !dark;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('waffra_dark_mode', value);

    if (mounted) setState(() => dark = value);
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
            : !introDone
                ? IntroScreen(onFinish: finishIntro)
                : profile == null
                    ? LoginScreen(onSave: saveProfile)
                    : HomeScreen(
                        profile: profile!,
                        dark: dark,
                        onTheme: toggleTheme,
                        onLogout: logout,
                        onProfile: saveProfile,
                      ),
      ),
    );
  }
}

// ==========================================
// FULL SCREEN ONBOARDING
// ==========================================

class IntroScreen extends StatefulWidget {
  final Future<void> Function() onFinish;

  const IntroScreen({
    super.key,
    required this.onFinish,
  });

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController controller = PageController();

  int page = 0;
  bool busy = false;

  static const List<String> images = [
    'assets/images.jpeg',
    'assets/kafd-slider-2-image-1200x750.jpg',
    'assets/pexels-photo-32918067.jpg',
  ];

  static const List<String> titles = [
    'أهلاً بك في وفرة',
    'مصروفاتك تحت السيطرة',
    'قرارات مالية أذكى',
  ];

  static const List<String> descriptions = [
    'ابدأ رحلتك نحو تنظيم أموالك بكل سهولة',
    'سجّل دخلك ومصروفاتك وتابع كل ريال',
    'حلّل عملياتك واكتشف فرص التوفير',
  ];

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (busy) return;

    setState(() => busy = true);
    await widget.onFinish();
  }

  Future<void> next() async {
    if (page == images.length - 1) {
      await finish();
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
            itemCount: images.length,
            onPageChanged: (value) {
              setState(() => page = value);
            },
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: deepGreen),
                  Image.asset(
                    images[index],
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: deepGreen,
                        child: const Icon(
                          Icons.landscape,
                          size: 110,
                          color: gold,
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
                          Colors.transparent,
                          Color(0x66000000),
                          Color(0xEE033C2C),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        40,
                        24,
                        135,
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'وفرة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 39,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            titles[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            descriptions[index],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
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
                    padding: const EdgeInsets.all(12),
                    child: page < images.length - 1
                        ? TextButton(
                            onPressed: finish,
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
                    images.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(
                        milliseconds: 200,
                      ),
                      width: page == index ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: page == index
                            ? gold
                            : Colors.white60,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    26,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      onPressed: busy ? null : next,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                      ),
                      child: Text(
                        page == images.length - 1
                            ? 'ابدأ مع وفرة'
                            : 'التالي',
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

// ==========================================
// DEMO LOGIN
// ==========================================

class LoginScreen extends StatefulWidget {
  final Future<void> Function(UserProfile) onSave;

  const LoginScreen({
    super.key,
    required this.onSave,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
                const CircleAvatar(
                  radius: 55,
                  backgroundColor: deepGreen,
                  child: Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'وفرة',
                  style: TextStyle(
                    fontSize: 42,
                    color: green,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'أهلاً بك في رحلتك المالية',
                  style: TextStyle(fontSize: 19),
                ),
                const SizedBox(height: 32),
                const Text(
                  'تسجيل دخول تجريبي',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() => provider = 'Google');
                    },
                    icon: const Icon(
                      Icons.g_mobiledata,
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
                  height: 55,
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
                const SizedBox(height: 22),
                const Text(
                  'الدخول تجريبي فقط. لا يتم الاتصال بخوادم '
                  'Google أو Apple أو التحقق من البريد الإلكتروني.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
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

// ==========================================
// USER PROFILE
// ==========================================

class ProfileForm extends StatefulWidget {
  final String provider;
  final UserProfile? initial;
  final Future<void> Function(UserProfile) onSave;
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
    birthday = widget.initial?.birthday ?? DateTime(2000);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> selectBirthday() async {
    final result = await showDatePicker(
      context: context,
      initialDate: birthday,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() => birthday = result);
    }
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
            .hasMatch(email.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل الاسم والبريد الإلكتروني بشكل صحيح',
          ),
        ),
      );
      return;
    }

    setState(() => saving = true);

    await widget.onSave(
      UserProfile(
        name: name.text.trim(),
        email: email.text.trim(),
        provider: widget.provider,
        gender: gender,
        avatar: avatar,
        birthday: birthday,
      ),
    );

    if (!mounted) return;

    setState(() => saving = false);

    if (widget.initial != null) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
        title: Text(
          widget.initial == null
              ? 'استكمال الملف الشخصي'
              : 'تعديل الملف الشخصي',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'المتابعة عبر ${widget.provider} — تجريبي',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 22),
            Center(
              child: CircleAvatar(
                radius: 52,
                backgroundColor: green,
                child: Icon(
                  avatarIcon(avatar),
                  color: Colors.white,
                  size: 60,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'اختر الصورة الرمزية',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                'person',
                'male',
                'female',
                'smile',
              ].map((value) {
                return ChoiceChip(
                  label: Icon(avatarIcon(value)),
                  selected: avatar == value,
                  onSelected: (_) {
                    setState(() => avatar = value);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'الاسم',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 13),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'name@gmail.com',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 13),
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
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: selectBirthday,
              icon: const Icon(Icons.calendar_month),
              label: Text(
                'تاريخ الميلاد: ${dateText(birthday)}',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : submit,
              child: Text(
                widget.initial == null
                    ? 'إنشاء الحساب والدخول'
                    : 'حفظ التعديلات',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// BANK MESSAGE ANALYZER
// ==========================================

class ParsedMessage {
  final double? amount;
  final String title;
  final bool income;
  final String category;

  const ParsedMessage({
    required this.amount,
    required this.title,
    required this.income,
    required this.category,
  });
}

class BankMessageAnalyzer {
  static ParsedMessage analyze(String original) {
    final text = normalizeDigits(original)
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('\u00a0', ' ')
        .trim();

    final lower = text.toLowerCase();

    final outgoing = RegExp(
      r'شراء|pos|مدى|mada|حوالة\s+(?:داخلية\s+)?صادرة|'
      r'تحويل\s+صادر|سحب|خصم|دفع|purchase|debit',
      caseSensitive: false,
    ).hasMatch(lower);

    final incoming = RegExp(
      r'راتب|إيداع|ايداع|حوالة\s+(?:داخلية\s+)?واردة|'
      r'تحويل\s+وارد|salary|credited|deposit|received',
      caseSensitive: false,
    ).hasMatch(lower);

    final income = incoming && !outgoing;

    double? amount;

    // Supported:
    // بـ2SR
    // بـ84.72SR
    // بـSR 60
    // SAR 120
    // 120 ريال

    const number = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';
    const currency = r'(?:SR|SAR|ر\.?\s?س\.?|ريال)';

    final patterns = <RegExp>[
      RegExp(
        '(?:بـ|ب|بقيمة|بمبلغ|مبلغ|المبلغ|amount|amt)'
        '\\s*[:：-]?\\s*$number\\s*$currency',
        caseSensitive: false,
      ),
      RegExp(
        '(?:بـ|ب|بقيمة|بمبلغ|مبلغ|المبلغ|amount|amt)'
        '\\s*[:：-]?\\s*$currency\\s*$number',
        caseSensitive: false,
      ),
      RegExp(
        '$number\\s*$currency',
        caseSensitive: false,
      ),
      RegExp(
        '$currency\\s*$number',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);

      if (match == null) continue;

      final value = readAmount(match.group(1) ?? '');

      if (value != null) {
        amount = value;
        break;
      }
    }

    String title;
    String category;

    if (RegExp(
      r'شراء|pos|مدى|mada',
      caseSensitive: false,
    ).hasMatch(lower)) {
      title = 'شراء نقاط بيع';
      category = 'تسوق';

      final merchants = RegExp(
        r'(?:^|\n)\s*من\s*([^\n\r]{2,45})',
        multiLine: true,
      ).allMatches(text).toList();

      for (final match in merchants.reversed) {
        final value = (match.group(1) ?? '').trim();

        if (RegExp(r'[a-zA-Z\u0600-\u06FF]')
            .hasMatch(value)) {
          title = 'شراء - $value';
          break;
        }
      }
    } else if (RegExp(
      r'حوالة|تحويل',
      caseSensitive: false,
    ).hasMatch(lower)) {
      title = income ? 'حوالة واردة' : 'حوالة صادرة';
      category = income ? 'دخل آخر' : 'تحويلات';

      final recipient = RegExp(
        r'(?:لـ|إلى|الى)\s*(?:[0-9]+[;؛:\-]?)?\s*'
        r'([^\n\r]+)',
      ).firstMatch(text);

      if (!income && recipient != null) {
        final value = recipient.group(1)?.trim() ?? '';

        if (value.isNotEmpty) {
          title = 'حوالة إلى $value';
        }
      }
    } else if (RegExp(
      r'راتب|salary',
      caseSensitive: false,
    ).hasMatch(lower)) {
      title = 'راتب';
      category = 'راتب';
    } else if (income) {
      title = 'إيداع أو دخل';
      category = 'دخل آخر';
    } else {
      title = 'مصروف من رسالة';
      category = 'أخرى';
    }

    if (!income) {
      if (RegExp(
        r'مطعم|كافيه|قهوة|coffee|restaurant',
        caseSensitive: false,
      ).hasMatch(lower)) {
        category = 'طعام';
      } else if (RegExp(
        r'بنزين|وقود|محطة|uber|careem|أوبر|كريم',
        caseSensitive: false,
      ).hasMatch(lower)) {
        category = 'مواصلات';
      } else if (RegExp(
        r'فاتورة|كهرباء|مياه|stc|mobily|زين',
        caseSensitive: false,
      ).hasMatch(lower)) {
        category = 'فواتير';
      } else if (RegExp(
        r'صيدلية|مستشفى|عيادة|pharmacy',
        caseSensitive: false,
      ).hasMatch(lower)) {
        category = 'صحة';
      }
    }

    return ParsedMessage(
      amount: amount,
      title: title,
      income: income,
      category: category,
    );
  }
}

// ==========================================
// ADD / EDIT ENTRY
// ==========================================

class EntrySheet extends StatefulWidget {
  final Entry? initial;
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
  late final TextEditingController title;
  late final TextEditingController amount;

  final TextEditingController message = TextEditingController();

  late bool income;
  late String category;
  late DateTime date;

  bool analyzing = false;
  bool analyzed = false;

  static const expenseCategories = [
    'طعام',
    'تسوق',
    'مواصلات',
    'فواتير',
    'صحة',
    'تحويلات',
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

    title = TextEditingController(
      text: widget.initial?.title ?? '',
    );

    amount = TextEditingController(
      text: widget.initial?.amount.toStringAsFixed(2) ?? '',
    );

    income = widget.initial?.income ?? false;
    category = widget.initial?.category ?? 'طعام';
    date = widget.initial?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> analyze() async {
    if (analyzing) return;

    if (message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الصق الرسالة البنكية أولاً'),
        ),
      );
      return;
    }

    setState(() => analyzing = true);

    final rootNavigator = Navigator.of(
      context,
      rootNavigator: true,
    );

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('تحليل الرسالة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'جارٍ تحليل الرسالة...',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'يتم استخراج المبلغ ونوع العملية',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    ParsedMessage? result;

    try {
      await Future<void>.delayed(
        const Duration(milliseconds: 850),
      );

      result = BankMessageAnalyzer.analyze(message.text);
    } catch (error) {
      debugPrint('Analysis error: $error');
    }

    if (!mounted) return;

    rootNavigator.pop();

    setState(() {
      analyzing = false;

      if (result != null) {
        analyzed = true;
        income = result.income;
        category = result.category;
        title.text = result.title;
        amount.text =
            result.amount?.toStringAsFixed(2) ?? '';
      }
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحليل الرسالة'),
        ),
      );
      return;
    }

    final parsed = result;

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('نتيجة تحليل الرسالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'نوع العملية: ${parsed.income ? 'دخل' : 'مصروف'}',
            ),
            const SizedBox(height: 12),
            Text(
              parsed.amount == null
                  ? 'لم يتم التعرف على المبلغ'
                  : 'المبلغ: ${money(parsed.amount!)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 12),
            Text('الوصف: ${parsed.title}'),
            const SizedBox(height: 12),
            Text('التصنيف: ${parsed.category}'),
            const SizedBox(height: 15),
            const Text(
              'راجع البيانات وعدّلها إذا لزم الأمر قبل الحفظ.',
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('مراجعة وحفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> selectDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() => date = result);
    }
  }

  void save() {
    final value = readAmount(amount.text);

    if (title.text.trim().isEmpty || value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'أدخل الوصف والمبلغ بشكل صحيح',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      Entry(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.text.trim(),
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
                      ? 'إضافة من رسالة بنكية'
                      : 'إضافة عملية جديدة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (widget.fromMessage) ...[
              const Text(
                'الصق الرسالة البنكية ثم اضغط تحليل الرسالة.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'نص الرسالة البنكية',
                  hintText: 'اضغط مطولاً ثم اختر لصق',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: analyzing ? null : analyze,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('تحليل الرسالة'),
              ),
              if (analyzed) ...[
                const SizedBox(height: 10),
                const Text(
                  'تم التحليل. راجع البيانات قبل الحفظ.',
                  style: TextStyle(color: green),
                ),
              ],
              const SizedBox(height: 16),
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
              onSelectionChanged: (values) {
                setState(() {
                  income = values.first;
                  category = income ? 'راتب' : 'طعام';
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              decoration: const InputDecoration(
                labelText: 'وصف العملية',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'المبلغ بالريال',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('$income-$selectedCategory'),
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
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: selectDate,
              icon: const Icon(Icons.calendar_month),
              label: Text('التاريخ: ${dateText(date)}'),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: analyzing ? null : save,
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

// ==========================================
// ANALYTICS CHART
// ==========================================

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

class FinanceChart extends StatelessWidget {
  final List<ChartPoint> points;

  const FinanceChart({
    super.key,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    double maximum = 1;

    for (final point in points) {
      if (point.income > maximum) {
        maximum = point.income;
      }

      if (point.expense > maximum) {
        maximum = point.expense;
      }
    }

    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.square, color: green, size: 15),
            Text(' الدخل'),
            SizedBox(width: 18),
            Icon(
              Icons.square,
              color: Colors.deepOrange,
              size: 15,
            ),
            Text(' المصروفات'),
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
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor:
                                  (point.income / maximum).clamp(
                                0.015,
                                1.0,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: green,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FractionallySizedBox(
                              alignment: Alignment.bottomCenter,
                              heightFactor:
                                  (point.expense / maximum).clamp(
                                0.015,
                                1.0,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
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
                    const SizedBox(height: 9),
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

// ==========================================
// HOME
// ==========================================

class HomeScreen extends StatefulWidget {
  final UserProfile profile;
  final bool dark;
  final VoidCallback onTheme;
  final Future<void> Function() onLogout;
  final Future<void> Function(UserProfile) onProfile;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.dark,
    required this.onTheme,
    required this.onLogout,
    required this.onProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Entry> entries = [];

  int tab = 0;

  String search = '';
  String typeFilter = 'الكل';
  String categoryFilter = 'الكل';
  String period = 'شهري';

  int year = DateTime.now().year;
  int month = DateTime.now().month;

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
      final decoded = jsonDecode(raw) as List;

      final loaded = decoded.map((value) {
        return Entry.fromJson(
          Map<String, dynamic>.from(value),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        entries
          ..clear()
          ..addAll(loaded);
      });
    } catch (error) {
      debugPrint('Entries loading failed: $error');
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

  double totalIncome(Iterable<Entry> data) {
    return data
        .where((entry) => entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  double totalExpense(Iterable<Entry> data) {
    return data
        .where((entry) => !entry.income)
        .fold(0.0, (sum, entry) => sum + entry.amount);
  }

  Future<void> editEntry({
    Entry? initial,
    bool fromMessage = false,
  }) async {
    final result = await showModalBottomSheet<Entry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EntrySheet(
        initial: initial,
        fromMessage: fromMessage,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      if (initial == null) {
        entries.insert(0, result);
      } else {
        final index = entries.indexWhere(
          (entry) => entry.id == initial.id,
        );

        if (index >= 0) {
          entries[index] = result;
        }
      }

      entries.sort(
        (a, b) => b.date.compareTo(a.date),
      );
    });

    await persist();
  }

  Future<void> deleteEntry(Entry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف العملية'),
        content: Text(
          'هل تريد حذف "${entry.title}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      entries.removeWhere(
        (value) => value.id == entry.id,
      );
    });

    await persist();
  }

  List<String> get categories {
    final values = entries.where((entry) {
      if (typeFilter == 'الدخل') return entry.income;
      if (typeFilter == 'المصروفات') return !entry.income;
      return true;
    }).map((entry) => entry.category).toSet().toList()
      ..sort();

    return ['الكل', ...values];
  }

  List<Entry> get filtered {
    final result = entries.where((entry) {
      final matchesSearch = entry.title
              .toLowerCase()
              .contains(search.toLowerCase()) ||
          entry.category
              .toLowerCase()
              .contains(search.toLowerCase());

      final matchesType = typeFilter == 'الكل' ||
          (typeFilter == 'الدخل' && entry.income) ||
          (typeFilter == 'المصروفات' && !entry.income);

      final matchesCategory =
          categoryFilter == 'الكل' ||
              entry.category == categoryFilter;

      return matchesSearch &&
          matchesType &&
          matchesCategory;
    }).toList();

    result.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return result;
  }

  Widget stat(
    String label,
    double value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 9),
              Text(label),
              const SizedBox(height: 7),
              Text(
                money(value),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget entryTile(Entry entry) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            entry.income
                ? Icons.south_west
                : Icons.north_east,
            color: entry.income
                ? green
                : Colors.deepOrange,
          ),
        ),
        title: Text(entry.title),
        subtitle: Text(
          '${entry.category} • ${dateText(entry.date)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${entry.income ? '+' : '-'}${money(entry.amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: entry.income ? green : null,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  editEntry(initial: entry);
                }

                if (value == 'delete') {
                  deleteEntry(entry);
                }
              },
              itemBuilder: (_) => const [
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
    final income = totalIncome(entries);
    final expense = totalExpense(entries);

    final selectedCategory =
        categories.contains(categoryFilter)
            ? categoryFilter
            : 'الكل';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'أهلاً، ${widget.profile.name} 👋',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [deepGreen, green],
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رصيدك الحالي',
                style: TextStyle(color: Colors.white70),
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
        const SizedBox(height: 14),
        Row(
          children: [
            stat(
              'الدخل',
              income,
              Icons.south_west,
              green,
            ),
            stat(
              'المصروفات',
              expense,
              Icons.north_east,
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () {
            editEntry(fromMessage: true);
          },
          icon: const Icon(Icons.content_paste),
          label: const Text(
            'إضافة من رسالة بنكية منسوخة',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'عملياتك المالية',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (value) {
            setState(() => search = value);
          },
          decoration: const InputDecoration(
            labelText: 'ابحث في الدخل والمصروفات',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              'الكل',
              'الدخل',
              'المصروفات',
            ].map((value) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text(value),
                  selected: typeFilter == value,
                  onSelected: (_) {
                    setState(() {
                      typeFilter = value;
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
          key: ValueKey(
            '$typeFilter-$selectedCategory',
          ),
          initialValue: selectedCategory,
          decoration: const InputDecoration(
            labelText: 'فلتر التصنيف',
            border: OutlineInputBorder(),
          ),
          items: categories.map((value) {
            return DropdownMenuItem(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              categoryFilter = value ?? 'الكل';
            });
          },
        ),
        const SizedBox(height: 12),
        Text('عدد العمليات: ${filtered.length}'),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: Text('لا توجد عمليات مطابقة'),
            ),
          ),
        ...filtered.map(entryTile),
        const SizedBox(height: 100),
      ],
    );
  }

  List<Entry> get analyticsData {
    return entries.where((entry) {
      if (period == 'شهري') {
        return entry.date.year == year &&
            entry.date.month == month;
      }

      return entry.date.year == year;
    }).toList();
  }

  List<ChartPoint> get chartPoints {
    if (period == 'شهري') {
      final days = DateTime(
        year,
        month + 1,
        0,
      ).day;

      return List.generate(
        (days / 7).ceil(),
        (index) {
          final start = index * 7 + 1;
          final end = (start + 6).clamp(1, days);

          final data = analyticsData.where(
            (entry) =>
                entry.date.day >= start &&
                entry.date.day <= end,
          );

          return ChartPoint(
            'أ${index + 1}',
            totalIncome(data),
            totalExpense(data),
          );
        },
      );
    }

    return List.generate(12, (index) {
      final data = analyticsData.where(
        (entry) => entry.date.month == index + 1,
      );

      return ChartPoint(
        '${index + 1}',
        totalIncome(data),
        totalExpense(data),
      );
    });
  }

  Widget analytics() {
    final data = analyticsData;
    final income = totalIncome(data);
    final expense = totalExpense(data);

    final categoryTotals = <String, double>{};

    for (final entry in data.where(
      (entry) => !entry.income,
    )) {
      categoryTotals[entry.category] =
          (categoryTotals[entry.category] ?? 0) +
              entry.amount;
    }

    final years = <int>{
      DateTime.now().year,
      year,
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
          selected: {period},
          onSelectionChanged: (value) {
            setState(() => period = value.first);
          },
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(
                  labelText: 'السنة',
                  border: OutlineInputBorder(),
                ),
                items: years.map((value) {
                  return DropdownMenuItem(
                    value: value,
                    child: Text('$value'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => year = value);
                  }
                },
              ),
            ),
            if (period == 'شهري') ...[
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: month,
                  decoration: const InputDecoration(
                    labelText: 'الشهر',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('شهر ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => month = value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            stat(
              'الدخل',
              income,
              Icons.south_west,
              green,
            ),
            stat(
              'المصروفات',
              expense,
              Icons.north_east,
              Colors.deepOrange,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
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
                const SizedBox(height: 20),
                FinanceChart(points: chartPoints),
                const SizedBox(height: 10),
                Text(
                  period == 'شهري'
                      ? 'أ1، أ2... تمثل أسابيع الشهر'
                      : 'الأرقام تمثل أشهر السنة',
                  style: const TextStyle(fontSize: 12),
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
        if (categoryTotals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(25),
            child: Center(
              child: Text(
                'لا توجد مصروفات في الفترة المحددة',
              ),
            ),
          ),
        ...categoryTotals.entries.map((item) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item.key),
                      Text(money(item.value)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: expense == 0
                        ? 0
                        : (item.value / expense).clamp(
                            0.0,
                            1.0,
                          ),
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileForm(
          provider: widget.profile.provider,
          initial: widget.profile,
          onSave: widget.onProfile,
        ),
      ),
    );
  }

  Widget profilePage() {
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 15),
        Center(
          child: CircleAvatar(
            radius: 52,
            backgroundColor: green,
            child: Icon(
              avatarIcon(widget.profile.avatar),
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          widget.profile.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.profile.email,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.account_circle_outlined,
                ),
                title: const Text(
                  'طريقة الدخول التجريبية',
                ),
                subtitle: Text(
                  widget.profile.provider,
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.people_outline,
                ),
                title: const Text('الجنس'),
                subtitle: Text(
                  widget.profile.gender,
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.cake_outlined,
                ),
                title: const Text('تاريخ الميلاد'),
                subtitle: Text(
                  dateText(widget.profile.birthday),
                ),
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
          onPressed: widget.onTheme,
          icon: Icon(
            widget.dark
                ? Icons.light_mode
                : Icons.dark_mode,
          ),
          label: const Text('تغيير المظهر'),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(Icons.logout),
          label: const Text(
            'تسجيل الخروج التجريبي',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'البيانات المالية محفوظة محلياً على جهازك. '
          'لا توجد مزامنة سحابية أو مصادقة حقيقية.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
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
            onPressed: widget.onTheme,
            icon: Icon(
              widget.dark
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: CircleAvatar(
              backgroundColor: green,
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
              onPressed: () => editEntry(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة عملية'),
            )
          : null,
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
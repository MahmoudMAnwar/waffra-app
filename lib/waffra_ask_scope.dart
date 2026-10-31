/// A conservative domain gate for Ask Waffra. No user question is sent to
/// the local model if it is clearly unrelated to the app's money features.
/// This is a UX scope boundary, not a security or financial-advice classifier.
abstract final class WaffraAskScope {
  static const outsideArabic =
      'اسأل وفرة مخصص يساعدك في أمورك المالية داخل التطبيق. '
      'اسألني عن دخلك، مصروفاتك، معاملاتك، ميزانيتك، أهدافك أو طرق التوفير.';
  static const outsideEnglish =
      'Ask Waffra helps with your finances inside the app. '
      'Ask about your income, spending, transactions, budget, goals or saving.';

  static String outsideResponse({bool english = false}) =>
      english ? outsideEnglish : outsideArabic;

  static String _normalized(String raw) => raw.toLowerCase()
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '');

  // Avoid substring checks on full sentences: e.g. the Arabic word 'جمال'
  // should not classify an unrelated question as money-related.
  static const _arabicRoots = <String>[
    'دخل', 'دخلي', 'ايراد', 'راتب', 'رواتب', 'صرف', 'مصروف',
    'مصاريف', 'انفق', 'انفاق', 'نفق', 'فلوس', 'اموال', 'ماليه',
    'مالي', 'ميزاني', 'رصيد', 'دين', 'ديون', 'دينار', 'ريال',
    'جنيه', 'درهم', 'دولار', 'عمله', 'عملات', 'تحويل',
    'حواله', 'بنك', 'بنكي', 'حسابي', 'معامل', 'عملي',
    'فاتور', 'ايصال', 'مشتري', 'شراء', 'تسوق', 'توفير',
    'وفر', 'ادخار', 'مدخر', 'استثمار', 'سعر', 'اسعار',
    'ذهب', 'نفط', 'بترول', 'اشتراك', 'التزام', 'قسط',
    'اقساط', 'هدف', 'اهداف', 'فئه', 'تصنيف', 'قسم',
    'محفظ', 'موسم', 'ضريب', 'رسوم', 'مدفوع', 'دفع',
    'تقرير', 'تحليل', 'ماليتي',
  ];
  static const _englishRoots = <String>[
    'income','salary','earn','expense','spend','spent','cost','money',
    'finance','financial','budget','balance','saving','save','debt',
    'bank','account','transaction','transfer','bill','receipt',
    'invoice','purchase','payment','currency','exchange','gold','oil',
    'subscription','goal','invest','fund','cash','wallet','category',
    'report','profit','tax','fee','loan','installment','merchant',
    'afford','forecast','asset','retirement',
  ];

  static bool isRelated(String question) {
    final normalized = _normalized(question).trim();
    if (normalized.isEmpty || normalized.length > 500) return false;
    final tokens = normalized.split(RegExp(r'[^a-z\u0600-\u06FF]+'))
        .where((part) => part.isNotEmpty);
    for (final token in tokens) {
      var word = token;
      // A few frequent Arabic prefixes before a financial noun.
      if (word.startsWith('وال') && word.length > 5) word = word.substring(3);
      else if (word.startsWith('بال') && word.length > 5) word = word.substring(3);
      else if (word.startsWith('ال') && word.length > 4) word = word.substring(2);
      if (_arabicRoots.any((root) => word.startsWith(root)) ||
          _englishRoots.any((root) => word.startsWith(root))) return true;
    }
    return false;
  }
}

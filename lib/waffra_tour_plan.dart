/// Single source of truth for Waffra's seven-step onboarding tour.
/// Index 0 introduces the app; subsequent indices visit live destinations
/// in the five-tab footer. Do not point steps at removed footer tabs.
abstract final class WaffraTourPlan {
  static const tabs = <int>[0, 0, 0, 1, 2, 3, 4];
  static const targetKeys = <int>[-1, 0, 1, 2, 3, 6, 4];
  static const titlesAr = <String>[
    'مرحبًا بك في وفرة',
    'الرئيسية والرصيد',
    'إضافة المعاملات',
    'الأقسام',
    'الأدوات المالية',
    'الأهداف الادخارية',
    'العمليات المتكررة',
  ];
  static const titlesEn = <String>[
    'Welcome to Waffra',
    'Home & balance',
    'Add transactions',
    'Categories',
    'Smart financial tools',
    'Savings goals',
    'Recurring items',
  ];
  static const helpAr = <String>[
    'ابدأ بدون تسجيل، واحتفظ ببياناتك على هاتفك.',
    'الرصيد والدخل والمصروفات في مكان واحد.',
    'أضف عملية أو الصق رسالة بنكية للتحليل.',
    'نظّم الأقسام الرئيسية والفرعية.',
    'افتح الأدوات لاستكشاف التحليل والتخطيط المالي والأدوات الإضافية.',
    'خطط لأهداف الادخار وتابع التقدم.',
    'نظّم الاستحقاقات الشهرية والمتكررة.',
  ];
  static const helpEn = <String>[
    'Start as a guest and keep data on your phone.',
    'See balance, income and expenses.',
    'Add a transaction or paste a bank message.',
    'Organize categories and budgets.',
    'Explore financial analysis, planning and additional tools.',
    'Create savings goals and follow progress.',
    'Plan recurring payments and due dates.',
  ];
}

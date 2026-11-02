/// Suggested budget names only, never financial records or assigned limits.
/// Budgets are independent of categories; templates choose NO category and
/// require a user-confirmed name, monthly cap and alert level.
class WaffraBudgetTemplate {
 final String nameAr,nameEn;
 const WaffraBudgetTemplate(this.nameAr,this.nameEn);
 String name(bool english)=>english?nameEn:nameAr;
}

const waffraBudgetStarterTemplates=<WaffraBudgetTemplate>[
 WaffraBudgetTemplate('إيجار البيت','Home rent'),
 WaffraBudgetTemplate('مشتريات السوبرماركت','Groceries'),
 WaffraBudgetTemplate('مطاعم الشهر','Restaurants'),
 WaffraBudgetTemplate('القهوة والمقاهي','Coffee & cafés'),
 WaffraBudgetTemplate('توصيل الطعام','Food delivery'),
 WaffraBudgetTemplate('بنزين السيارة','Car fuel'),
 WaffraBudgetTemplate('صيانة السيارة','Car maintenance'),
 WaffraBudgetTemplate('فاتورة الكهرباء','Electricity bill'),
 WaffraBudgetTemplate('فاتورة المياه','Water bill'),
 WaffraBudgetTemplate('الإنترنت المنزلي','Home internet'),
 WaffraBudgetTemplate('فاتورة الجوال','Mobile phone bill'),
 WaffraBudgetTemplate('الصيدلية والأدوية','Pharmacy & medicines'),
 WaffraBudgetTemplate('رسوم التعليم','School fees'),
 WaffraBudgetTemplate('مصروف البيت','Household spending'),
 WaffraBudgetTemplate('احتياجات الأطفال','Children’s essentials'),
 WaffraBudgetTemplate('السفر والعطلات','Travel & holidays'),
 WaffraBudgetTemplate('الاشتراكات الرقمية','Digital subscriptions'),
 WaffraBudgetTemplate('الصدقات','Charitable giving'),
 WaffraBudgetTemplate('الهدايا والمناسبات','Gifts & occasions'),
 WaffraBudgetTemplate('الملابس والتسوق','Clothes & shopping'),
 WaffraBudgetTemplate('الترفيه','Entertainment'),
 WaffraBudgetTemplate('المصاريف الطارئة','Unexpected expenses'),
 WaffraBudgetTemplate('الاشتراك الرياضي','Gym membership'),
 WaffraBudgetTemplate('تأمين السيارة','Car insurance'),
];

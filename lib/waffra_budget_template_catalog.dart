/// Suggested budget names only, never financial records or assigned limits.
/// Tapping a template requires a chosen main/child expense category and
/// a user-confirmed positive monthly spending cap before saving.
/// Templates never create transactions, goal savings or balances.
class WaffraBudgetTemplate {
 final String nameAr,nameEn,mainCategoryId,subcategoryAr;
 const WaffraBudgetTemplate(this.nameAr,this.nameEn,
  this.mainCategoryId,this.subcategoryAr);
 String name(bool english)=>english?nameEn:nameAr;
}

const waffraBudgetStarterTemplates=<WaffraBudgetTemplate>[
 WaffraBudgetTemplate('إيجار البيت','Home rent','housing','إيجار شهري'),
 WaffraBudgetTemplate('مشتريات السوبرماركت','Groceries','groceries','سوبرماركت'),
 WaffraBudgetTemplate('مطاعم الشهر','Restaurants','food','مطاعم شعبية'),
 WaffraBudgetTemplate('القهوة والمقاهي','Coffee & cafés','food','مقاهي'),
 WaffraBudgetTemplate('توصيل الطعام','Food delivery','food','توصيل الطعام'),
 WaffraBudgetTemplate('بنزين السيارة','Car fuel','vehicle','بنزين ووقود'),
 WaffraBudgetTemplate('صيانة السيارة','Car maintenance','vehicle','صيانة دورية'),
 WaffraBudgetTemplate('فاتورة الكهرباء','Electricity bill','bills','كهرباء'),
 WaffraBudgetTemplate('فاتورة المياه','Water bill','bills','مياه'),
 WaffraBudgetTemplate('الإنترنت المنزلي','Home internet','bills','إنترنت منزلي'),
 WaffraBudgetTemplate('فاتورة الجوال','Mobile phone bill','bills','جوال'),
 WaffraBudgetTemplate('الصيدلية والأدوية','Pharmacy & medicines','health','صيدلية وأدوية'),
 WaffraBudgetTemplate('رسوم التعليم','School fees','education','رسوم مدارس'),
 WaffraBudgetTemplate('مصروف البيت','Household spending','family','مصروف البيت'),
 WaffraBudgetTemplate('احتياجات الأطفال','Children’s essentials','children','حفاضات'),
 WaffraBudgetTemplate('السفر والعطلات','Travel & holidays','travel','تذاكر طيران'),
 WaffraBudgetTemplate('الاشتراكات الرقمية','Digital subscriptions','subscriptions','تطبيقات'),
 WaffraBudgetTemplate('الصدقات','Charitable giving','sadaqat','صدقة يومية'),
 WaffraBudgetTemplate('الهدايا والمناسبات','Gifts & occasions','gifts','هدايا المناسبات'),
 WaffraBudgetTemplate('الملابس والتسوق','Clothes & shopping','shopping','ملابس'),
 WaffraBudgetTemplate('الترفيه','Entertainment','entertainment','سينما'),
 WaffraBudgetTemplate('المصاريف الطارئة','Unexpected expenses','emergency-expense','مصاريف مفاجئة'),
 WaffraBudgetTemplate('الاشتراك الرياضي','Gym membership','sport','اشتراك نادي'),
 WaffraBudgetTemplate('تأمين السيارة','Car insurance','insurance','تأمين سيارة'),
];

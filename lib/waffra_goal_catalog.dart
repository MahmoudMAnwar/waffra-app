// Curated goal ideas used only as suggestions. Users can always create custom goals.
// Keep the original eight choices for backwards-compatible personal workflows.
class WaffraGoalIdea {
 final String ar,en;
 const WaffraGoalIdea(this.ar,this.en);
 String label(bool english)=>english?en:ar;
}
class WaffraGoalGroup {
 final String ar,en;
 final List<WaffraGoalIdea> ideas;
 const WaffraGoalGroup(this.ar,this.en,this.ideas);
 String label(bool english)=>english?en:ar;
}

const waffraGoalGroups=<WaffraGoalGroup>[
 WaffraGoalGroup('أهداف شائعة','Popular goals',[
  WaffraGoalIdea('سيارة','Car'),
  WaffraGoalIdea('منزل','Home'),
  WaffraGoalIdea('سفر','Travel'),
  WaffraGoalIdea('زواج','Marriage'),
  WaffraGoalIdea('صندوق الطوارئ','Emergency fund'),
  WaffraGoalIdea('تعليم','Education'),
  WaffraGoalIdea('حج أو عمرة','Hajj or Umrah'),
  WaffraGoalIdea('مشروع خاص','Personal business'),
 ]),
 WaffraGoalGroup('الادخار والأمان المالي','Savings and financial security',[
  WaffraGoalIdea('احتياطي مصاريف 3 أشهر','Three-month cash reserve'),
  WaffraGoalIdea('احتياطي مصاريف 6 أشهر','Six-month cash reserve'),
  WaffraGoalIdea('الادخار السنوي','Annual savings'),
  WaffraGoalIdea('سداد قرض شخصي','Pay off personal loan'),
  WaffraGoalIdea('سداد بطاقة ائتمان','Pay off credit card'),
  WaffraGoalIdea('إنهاء الأقساط','Clear installments'),
  WaffraGoalIdea('ادخار التقاعد','Retirement savings'),
  WaffraGoalIdea('استثمار طويل الأجل','Long-term investment'),
  WaffraGoalIdea('شراء الذهب للادخار','Buy gold for savings'),
  WaffraGoalIdea('إنشاء محفظة استثمارية','Build investment portfolio'),
  WaffraGoalIdea('احتياطي فقدان الوظيفة','Job-loss reserve'),
 ]),
 WaffraGoalGroup('السكن والعقارات','Home and property',[
  WaffraGoalIdea('دفعة أولى لمنزل','Home down payment'),
  WaffraGoalIdea('شراء أرض','Buy land'),
  WaffraGoalIdea('بناء منزل','Build a house'),
  WaffraGoalIdea('تجديد المنزل','Home renovation'),
  WaffraGoalIdea('تأثيث المنزل','Furnish home'),
  WaffraGoalIdea('صيانة المنزل','Home maintenance'),
  WaffraGoalIdea('إيجار سنة كاملة','Full-year rent'),
  WaffraGoalIdea('تجهيز منزل جديد','New home setup'),
  WaffraGoalIdea('شراء عقار استثماري','Investment property'),
  WaffraGoalIdea('سداد دفعة عقارية','Mortgage lump payment'),
 ]),
 WaffraGoalGroup('السيارات والمواصلات','Vehicles and transport',[
  WaffraGoalIdea('دفعة أولى لسيارة','Car down payment'),
  WaffraGoalIdea('سيارة عائلية','Family vehicle'),
  WaffraGoalIdea('سيارة كهربائية','Electric car'),
  WaffraGoalIdea('سيارة مستعملة','Used car'),
  WaffraGoalIdea('صيانة السيارة الكبرى','Major car repairs'),
  WaffraGoalIdea('تأمين السيارة السنوي','Annual car insurance'),
  WaffraGoalIdea('شراء دراجة هوائية','Buy bicycle'),
  WaffraGoalIdea('شراء دراجة نارية','Buy motorcycle'),
 ]),
 WaffraGoalGroup('الأسرة والمناسبات','Family and occasions',[
  WaffraGoalIdea('حفل زفاف','Wedding celebration'),
  WaffraGoalIdea('مهر الزواج','Marriage dowry'),
  WaffraGoalIdea('شهر العسل','Honeymoon'),
  WaffraGoalIdea('تجهيز مولود','New baby essentials'),
  WaffraGoalIdea('تكاليف الولادة','Childbirth costs'),
  WaffraGoalIdea('مستلزمات الأطفال','Children essentials'),
  WaffraGoalIdea('مصاريف الأسرة السنوية','Annual family expenses'),
  WaffraGoalIdea('هدية للوالدين','Gift for parents'),
  WaffraGoalIdea('مناسبة عائلية','Family occasion'),
  WaffraGoalIdea('عقيقة','Aqiqah celebration'),
  WaffraGoalIdea('حفلة تخرج','Graduation celebration'),
 ]),
 WaffraGoalGroup('التعليم وتطوير الذات','Learning and development',[
  WaffraGoalIdea('رسوم الجامعة','University tuition'),
  WaffraGoalIdea('رسوم المدرسة','School tuition'),
  WaffraGoalIdea('تعليم الأبناء','Children education'),
  WaffraGoalIdea('دراسة الماجستير','Master\'s degree'),
  WaffraGoalIdea('دراسة الدكتوراه','Doctoral degree'),
  WaffraGoalIdea('شهادة احترافية','Professional certification'),
  WaffraGoalIdea('دورة تدريبية','Training course'),
  WaffraGoalIdea('دراسة لغة جديدة','Learn a language'),
  WaffraGoalIdea('الدراسة بالخارج','Study abroad'),
  WaffraGoalIdea('شراء معدات للدراسة','Study equipment'),
 ]),
 WaffraGoalGroup('السفر والعبادات','Travel and pilgrimage',[
  WaffraGoalIdea('عطلة صيفية','Summer vacation'),
  WaffraGoalIdea('رحلة شتوية','Winter getaway'),
  WaffraGoalIdea('سياحة داخلية','Domestic trip'),
  WaffraGoalIdea('زيارة العائلة بالخارج','Visit family abroad'),
  WaffraGoalIdea('تذاكر طيران','Flight tickets'),
  WaffraGoalIdea('إقامة فندقية','Hotel stay'),
  WaffraGoalIdea('مصاريف العمرة','Umrah expenses'),
  WaffraGoalIdea('مصاريف الحج','Hajj expenses'),
  WaffraGoalIdea('رحلة نهاية الأسبوع','Weekend trip'),
 ]),
 WaffraGoalGroup('الإلكترونيات والتقنية','Electronics and tech',[
  WaffraGoalIdea('شراء هاتف جديد','New smartphone'),
  WaffraGoalIdea('شراء لابتوب','New laptop'),
  WaffraGoalIdea('شراء جهاز لوحي','New tablet'),
  WaffraGoalIdea('شراء كمبيوتر مكتبي','Desktop computer'),
  WaffraGoalIdea('شراء كاميرا','New camera'),
  WaffraGoalIdea('جهاز ألعاب','Gaming console'),
  WaffraGoalIdea('تجهيز مكتب منزلي','Home office setup'),
  WaffraGoalIdea('تجهيز استوديو','Studio setup'),
  WaffraGoalIdea('شراء جهاز منزلي','Home appliance'),
 ]),
 WaffraGoalGroup('المشاريع والعمل','Business and work',[
  WaffraGoalIdea('رأس مال مشروع','Business startup capital'),
  WaffraGoalIdea('متجر إلكتروني','Online store'),
  WaffraGoalIdea('معدات مشروع','Business equipment'),
  WaffraGoalIdea('ترخيص نشاط تجاري','Business licence'),
  WaffraGoalIdea('تطوير مشروع قائم','Expand existing business'),
  WaffraGoalIdea('إنشاء علامة تجارية','Launch a brand'),
  WaffraGoalIdea('تسويق مشروع','Business marketing'),
  WaffraGoalIdea('مشروع جانبي','Side project'),
  WaffraGoalIdea('تأسيس مكتب','Set up an office'),
 ]),
 WaffraGoalGroup('الصحة والعافية','Health and wellness',[
  WaffraGoalIdea('علاج طبي','Medical treatment'),
  WaffraGoalIdea('عملية جراحية','Surgery costs'),
  WaffraGoalIdea('تقويم الأسنان','Dental braces'),
  WaffraGoalIdea('علاج الأسنان','Dental treatment'),
  WaffraGoalIdea('فحوصات طبية شاملة','Comprehensive health check'),
  WaffraGoalIdea('نظارات طبية','Prescription glasses'),
  WaffraGoalIdea('جلسات علاج طبيعي','Physiotherapy sessions'),
  WaffraGoalIdea('تأمين صحي إضافي','Additional health insurance'),
  WaffraGoalIdea('اشتراك نادي رياضي','Gym membership'),
 ]),
 WaffraGoalGroup('الصدقات والعطاء','Charity and giving',[
  WaffraGoalIdea('صدقة جارية','Ongoing charity'),
  WaffraGoalIdea('زكاة المال','Zakat payment'),
  WaffraGoalIdea('كفالة يتيم','Sponsor an orphan'),
  WaffraGoalIdea('دعم جمعية خيرية','Support a charity'),
  WaffraGoalIdea('إفطار صائم','Ramadan iftar giving'),
  WaffraGoalIdea('أضحية العيد','Eid sacrifice'),
  WaffraGoalIdea('مساعدة أسرة محتاجة','Help a family in need'),
 ]),
 WaffraGoalGroup('الهوايات والاهتمامات','Hobbies and lifestyle',[
  WaffraGoalIdea('معدات تصوير','Photography equipment'),
  WaffraGoalIdea('أدوات الرسم','Art supplies'),
  WaffraGoalIdea('آلات موسيقية','Musical instrument'),
  WaffraGoalIdea('معدات تخييم','Camping gear'),
  WaffraGoalIdea('معدات رياضية','Sports equipment'),
  WaffraGoalIdea('حديقة منزلية','Home garden'),
  WaffraGoalIdea('تجديد الأثاث الشخصي','Refresh personal furniture'),
  WaffraGoalIdea('مكتبة منزلية','Home library'),
 ]),
];

/// Normalize Arabic spelling, case and whitespace to reject duplicate goal titles.
String waffraNormalizeGoal(String input)=>input.trim().toLowerCase()
 .replaceAll(RegExp(r'[\u064B-\u065F]'),'')
 .replaceAll(RegExp(r'[أإآ]'),'ا')
 .replaceAll(RegExp(r'\s+'),' ');

/// Returns a machine-readable validation issue or null for a valid goal name.
String? waffraGoalNameIssue(String? raw,Iterable<String> existing,{int maxLength=100}){
 final text=(raw??'').trim();
 if(text.isEmpty)return 'required';
 if(text.length>maxLength)return 'too_long';
 final normalized=waffraNormalizeGoal(text);
 return existing.any((x)=>waffraNormalizeGoal(x)==normalized)?'duplicate':null;
}

List<String> waffraDefaultGoalNames(bool english)=>[
 for(final group in waffraGoalGroups)
  for(final idea in group.ideas)idea.label(english),
];

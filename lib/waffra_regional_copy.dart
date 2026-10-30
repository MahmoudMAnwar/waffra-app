import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// UI-only country preference. NEVER use a selected display currency, SIM
/// phone prefix, device IP or bank-message currency to determine dialect.
/// A denied location permission simply retains neutral Modern Standard Arabic.
abstract final class WaffraRegionalCopy {
  static const preferenceKey='waffra_ui_country_iso_v1';
  static final ValueNotifier<String> countryIso=ValueNotifier<String>('');
  static const supportedRegions=<String,String>{
    '':'غير محدد / عربية عامة',
    'SA':'السعودية',
    'EG':'مصر',
    'AE':'الإمارات',
    'KW':'الكويت',
    'BH':'البحرين',
    'QA':'قطر',
    'OM':'عُمان',
    'JO':'الأردن',
    'IQ':'العراق',
    'LB':'لبنان',
    'MA':'المغرب',
    'DZ':'الجزائر',
    'TN':'تونس',
  };
  static const englishRegions=<String,String>{
    '':'Not selected / Neutral Arabic',
    'SA':'Saudi Arabia','EG':'Egypt','AE':'United Arab Emirates',
    'KW':'Kuwait','BH':'Bahrain','QA':'Qatar','OM':'Oman',
    'JO':'Jordan','IQ':'Iraq','LB':'Lebanon',
    'MA':'Morocco','DZ':'Algeria','TN':'Tunisia',
  };
  static String regionLabel(String code,{required bool english})=>
    english?(englishRegions[code]??code):(supportedRegions[code]??code);

  static String normalized(String? value){
    final code=value?.trim().toUpperCase()??'';
    return supportedRegions.containsKey(code)?code:'';
  }

  static Future<void> initialize(SharedPreferences preferences)async{
    countryIso.value=normalized(preferences.getString(preferenceKey));
  }

  static Future<void> setCountry(String? country)async{
    final value=normalized(country);
    final prefs=await SharedPreferences.getInstance();
    if(!await prefs.setString(preferenceKey,value)){
      throw StateError('country_preference_not_saved');
    }
    countryIso.value=value;
  }

  // Exact UI-message variants only. Never transform user-entered texts,
  // transaction descriptions, financial identifiers or stored categories.
  static const _saudiUi=<String,String>{
    'هل تريد تأكيد الإضافة؟':'ودّك تأكد إضافة العمليات؟',
    'حدث خطأ أثناء الحفظ':'ما قدرنا نحفظ العملية. جرّب مرة ثانية.',
    'فشلت العملية':'العملية ما تمت. جرّب مرة ثانية.',
    'هذه الرسالة محفوظة بالفعل، لن نكرر العملية.':
      'هذي الرسالة محفوظة من قبل، وما راح نكرر العملية.',
    'تعذر حفظ الإعدادات. حاول مجددًا.':
      'ما قدرنا نحفظ الإعدادات. جرّب مرة ثانية.',
    'هل أنت متأكد؟':'متأكد من هالخطوة؟',
  };
  static const _standardUi=<String,String>{
    'ودّك ننبهك عند كم ٪ من الميزانية؟':
      'عند أي نسبة من الميزانية تريد تلقّي تنبيه؟',
    'ما فيه مصروفات في هالفترة':'لا توجد مصروفات خلال هذه الفترة',
    'ما عندك عمليات متكررة':'لا توجد لديك معاملات متكررة',
    'ما عندك عمليات مطابقة':'لا توجد معاملات مطابقة',
    'دوّر على عملية':'ابحث عن معاملة',
    'هذي الرسالة سبق حفظها. ودّك تضيفها مرة ثانية؟':
      'هذه الرسالة محفوظة سابقًا. هل ترغب في إضافتها مرة أخرى؟',
    'هذي الرسالة البنكية أضفتها قبل كذا. ودّك تضيفها مرة ثانية؟':
      'لقد أضفت هذه الرسالة البنكية سابقًا. هل تريد إضافتها مرة أخرى؟',
  };
  static String adaptArabicUi(String source){
    final variants=isSaudi?_saudiUi:_standardUi;
    return variants[source]??source;
  }

  static bool get isSaudi=>countryIso.value=='SA';
  static bool get isEgyptian=>countryIso.value=='EG';

  /// English selection ALWAYS wins even if location is Saudi. For Arabic,
  /// location only selects a writing style, never currency or permissions.
  static String text({required bool english,required String standard,
    String? saudi,String? egyptian,required String en,String? country}){
    if(english)return en;
    switch(normalized(country??countryIso.value)){
      case 'SA':return saudi??standard;
      case 'EG':return egyptian??standard;
      default:return standard;
    }
  }

  static String get arabicCountrySubtag=>{
    'SA':'SA','EG':'EG',
  }[countryIso.value]??'';

  static String exitHint({required bool english,String? country})=>text(
    english:english,country:country,
    standard:'اضغط رجوع مرة ثانية للخروج من وفرة',
    saudi:'اضغط رجوع مرة ثانية عشان تطلع من وفرة',
    egyptian:'اضغط رجوع مرة كمان عشان تخرج من وفرة',
    en:'Press back again to exit Waffra');

  static String signOutTitle({required bool english,String? country})=>text(
    english:english,country:country,
    standard:'تسجيل الخروج من وفرة؟',
    saudi:'ودّك تسجّل خروج من وفرة؟',
    egyptian:'عايز تسجّل خروج من وفرة؟',
    en:'Sign out of Waffra?');

  static String signOutBody({required bool english,String? country})=>text(
    english:english,country:country,
    standard:'ستبقى بياناتك المالية محفوظة على هذا الجهاز.',
    saudi:'بياناتك المالية بتبقى محفوظة على جهازك.',
    egyptian:'بياناتك المالية هتفضل محفوظة على جهازك.',
    en:'Your financial data will remain on this device.');

  static String appError({required bool english,String? country})=>text(
    english:english,country:country,
    standard:'تعذر فتح وفرة. بياناتك لم تُحذف، ويمكنك إعادة المحاولة.',
    saudi:'ما قدرنا نفتح وفرة الحين. بياناتك ما انحذفت، جرّب مرة ثانية.',
    egyptian:'ما قدرناش نفتح وفرة دلوقتي. بياناتك ما اتمسحتش، جرّب تاني.',
    en:'Waffra could not start. Your data was not deleted. Please retry.');
}

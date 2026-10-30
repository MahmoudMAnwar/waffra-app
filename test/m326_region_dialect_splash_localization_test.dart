import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffra/waffra_regional_copy.dart';
import 'package:waffra/waffra_saudi_greetings.dart';

void main(){
  setUp((){
    SharedPreferences.setMockInitialValues(<String,Object>{});
    WaffraRegionalCopy.countryIso.value='';
  });

  test('M326 shared translation map has no duplicate literal keys',(){
    final source=File('lib/waffra_i18n.dart').readAsStringSync();
    final start=source.indexOf('const Map<String,String> _english = {');
    final end=source.indexOf('};',start);
    expect(start,greaterThanOrEqualTo(0));
    expect(end,greaterThan(start));
    final pairs=RegExp(r"^\s*'([^']+)'\s*:",multiLine:true)
      .allMatches(source.substring(start,end))
      .map((match)=>match.group(1)!)
      .toList();
    expect(pairs.length,greaterThan(100));
    expect(pairs.length,pairs.toSet().length,
      reason:'Duplicate translations fail Dart const map evaluation');
  });

  test('M326 slogan is universal Arabic and translated when English selected',(){
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('وفرة… فلوسك بوضوح'));
    expect(source,contains('Your money, made clear'));
    expect(source,isNot(contains('وفرة.. يعلّمك وين فلوسك تروح')));
    expect(source,isNot(contains('Waffra.. shows you where your money goes')));
  });

  test('M326 shared Arabic texts use selected regional voice',()async{
    await WaffraRegionalCopy.setCountry('SA');
    expect(WaffraRegionalCopy.adaptArabicUi('فشلت العملية'),
      'العملية ما تمت. جرّب مرة ثانية.');
    expect(WaffraRegionalCopy.adaptArabicUi('دوّر على عملية'),
      'دوّر على عملية');
    await WaffraRegionalCopy.setCountry('AE');
    expect(WaffraRegionalCopy.adaptArabicUi('دوّر على عملية'),
      'ابحث عن معاملة');
    expect(WaffraRegionalCopy.adaptArabicUi('فشلت العملية'),
      'فشلت العملية');
    final ui=File('lib/waffra_i18n.dart').readAsStringSync();
    expect(ui,contains('WaffraRegionalCopy.adaptArabicUi(source)'));
    expect(ui,contains("'إلغاء': 'Cancel'"));
    expect(ui,contains("'تأكيد': 'Confirm'"));
  });

  test('M326 country and currency preferences never share a storage key',()async{
    final prefs=await SharedPreferences.getInstance();
    await WaffraRegionalCopy.initialize(prefs);
    expect(WaffraRegionalCopy.countryIso.value,isEmpty);
    expect(WaffraRegionalCopy.text(english:false,
      standard:'لغة عربية عامة',saudi:'لهجة سعودية',egyptian:'لهجة مصرية',
      en:'English'),equals('لغة عربية عامة'));
    await WaffraRegionalCopy.setCountry('sa');
    expect(WaffraRegionalCopy.countryIso.value,'SA');
    expect(prefs.getString(WaffraRegionalCopy.preferenceKey),'SA');
    expect(prefs.getString('waffra_currency_v1'),isNull);
    final copy=File('lib/waffra_country_first_run_page.dart').readAsStringSync();
    expect(copy,contains('onCountryConfirmed'));
    expect(copy,contains('onComplete(currencyCode)'));
    expect(copy,contains('waffra-region-dialect-country'));
    expect(copy,contains('m290-currency-select'));
    expect(copy,contains('selectedRegionIso=WaffraRegionalCopy.normalized(iso)'));
  });

  test('M326 Saudi dialect wins only for Arabic with selected Saudi country',(){
    expect(WaffraRegionalCopy.exitHint(english:false,country:'SA'),
      'اضغط رجوع مرة ثانية عشان تطلع من وفرة');
    expect(WaffraRegionalCopy.exitHint(english:true,country:'SA'),
      'Press back again to exit Waffra');
    expect(WaffraRegionalCopy.signOutTitle(english:false,country:'SA'),
      'ودّك تسجّل خروج من وفرة؟');
    expect(WaffraRegionalCopy.appError(english:false,country:'SA'),
      contains('ما انحذفت'));
    expect(WaffraRegionalCopy.regionLabel('SA',english:true),'Saudi Arabia');
  });

  test('M326 Egypt uses Egyptian wording, other country uses neutral Arabic',(){
    expect(WaffraRegionalCopy.exitHint(english:false,country:'EG'),
      'اضغط رجوع مرة كمان عشان تخرج من وفرة');
    expect(WaffraRegionalCopy.exitHint(english:false,country:'AE'),
      'اضغط رجوع مرة ثانية للخروج من وفرة');
    expect(WaffraRegionalCopy.signOutTitle(english:false,country:'EG'),
      'عايز تسجّل خروج من وفرة؟');
    expect(WaffraRegionalCopy.normalized('xyz'),isEmpty);
  });

  test('M326 locale, greeting, exit and profile settings use same UI country',(){
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains('WaffraRegionalCopy.initialize(p)'));
    expect(source,contains('WaffraRegionalCopy.arabicCountrySubtag'));
    expect(source,contains('WaffraRegionalCopy.exitHint(english:waffraIsEnglish)'));
    expect(source,contains('WaffraRegionalCopy.signOutTitle(english:waffraIsEnglish)'));
    expect(source,contains('WaffraRegionalCopy.signOutBody(english:waffraIsEnglish)'));
    expect(source,contains('WaffraRegionalCopy.appError(english:waffraIsEnglish)'));
    expect(source,contains('waffra-regional-arabic-setting'));
    expect(source,contains('waffra-region-choice'));
    expect(source,contains('countryIso:WaffraRegionalCopy.countryIso.value'));
    expect(source,contains('onCountryConfirmed:setUiCountry'));
  });

  test('M326 greeting avoids Saudi-only colloquialisms outside Saudi Arabia',(){
    const name='علي';
    final saud=WaffraSaudiGreetings.compose(
      name:name,gender:'ذكر',english:false,greetingIndex:0,
      countryIso:'SA');
    final egypt=WaffraSaudiGreetings.compose(
      name:name,gender:'ذكر',english:false,greetingIndex:0,
      countryIso:'EG');
    final standard=WaffraSaudiGreetings.compose(
      name:name,gender:'ذكر',english:false,greetingIndex:0,
      countryIso:'');
    final english=WaffraSaudiGreetings.compose(
      name:'Ali',gender:'ذكر',english:true,greetingIndex:0,
      countryIso:'SA');
    expect(saud,contains('يا مرحبا'));
    expect(egypt,contains('يا أهلاً'));
    expect(standard,contains('مرحبًا بك'));
    expect(english,contains('Welcome'));
  });
}

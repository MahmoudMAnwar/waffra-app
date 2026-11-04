import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_ai_recorded_answers.dart';

void main(){
  final records=<WaffraAiRecordedFact>[
    WaffraAiRecordedFact(date:DateTime(2026,10,12),
      category:'راتب',amountMinor:120000,income:true),
    WaffraAiRecordedFact(date:DateTime(2026,8,20),
      category:'راتب',amountMinor:30000,income:true),
    WaffraAiRecordedFact(date:DateTime(2026,10,18),
      category:'مطاعم وكافيهات / وجبات سريعة',amountMinor:15000,income:false),
    WaffraAiRecordedFact(date:DateTime(2026,9,15),
      category:'مواصلات',amountMinor:4000,income:false),
  ];
  final clock=DateTime(2026,10,30,18,0);

  test('M333 spent how much: exact expenses across all recorded dates',(){
    final actual=WaffraAiRecordedAnswers.answer('صرفت كام',records,now:clock);
    expect(actual,contains('190.00 SAR'));
    expect(actual,contains('2 معاملة'));
    expect(actual,isNot(contains('الدخل:')));
    expect(actual,isNot(contains('**')));
  });

  test('M333 income, combined and net do not hallucinate bank balance',(){
    expect(WaffraAiRecordedAnswers.answer('دخل كام',records,now:clock),
      contains('1500.00 SAR'));
    final both=WaffraAiRecordedAnswers.answer(
      'الدخل والمصروفات كام؟',records,now:clock)!;
    expect(both,contains('1500.00 SAR'));
    expect(both,contains('190.00 SAR'));
    final net=WaffraAiRecordedAnswers.answer(
      'صافي رصيدي كام',records,now:clock)!;
    expect(net,contains('1310.00 SAR'));
    expect(net,contains('مش رصيد حسابك البنكي'));
  });

  test('M333 current month and last three Arabic digit months',(){
    final current=WaffraAiRecordedAnswers.answer(
      'صرفت كام الشهر ده',records,now:clock);
    expect(current,contains('150.00 SAR'));
    final three=WaffraAiRecordedAnswers.answer(
      'صرفت كام آخر ٣ شهور',records,now:clock);
    expect(three,contains('190.00 SAR'));
    expect(three,contains('آخر 3 شهور'));
  });

  test('M333 expense category answers use real category names',(){
    final actual=WaffraAiRecordedAnswers.answer(
      'صرفت كام على المطاعم؟',records,now:clock);
    expect(actual,contains('مطاعم وكافيهات'));
    expect(actual,contains('150.00 SAR'));
    expect(actual,isNot(contains('190.00 SAR')));
  });

  test('M333 nominal display currency has no FX conversion',(){
    final actual=WaffraAiRecordedAnswers.answer(
      'How much did I spend?',records,now:clock,
      english:true,currency:'EGP');
    expect(actual,contains('190.00 EGP'));
    expect(actual,contains('Recorded expenses'));
    final appCurrency=WaffraAiRecordedAnswers.answer(
      'صرفت كام',records,now:clock,
      formatMoney:(minor)=>((minor/100).toStringAsFixed(0))+' ج.م');
    expect(appCurrency,contains('190 ج.م'));
  });

  test('M333 insufficient data and advice are never invented',(){
    expect(WaffraAiRecordedAnswers.answer('صرفت كام',[],now:clock),
      'مافيش معاملات مسجلة للفترة دي.');
    expect(WaffraAiRecordedAnswers.answer(
      'اقترح عليا أوفر فلوس ازاي',records,now:clock),isNull);
  });

  test('M333 clean local model output removes Markdown and JSON boilerplate',(){
    const dirty='## Summary\n**Income**: 27,250\n'
      '**Expenses**: 80,024\n\n'
      '**Categories**:\n- **مطاعم وكافيهات**: 31,931\n'
      '*All values derived directly from the JSON data.*';
    final clean=WaffraAiRecordedAnswers.cleanModelAnswer(dirty)!;
    expect(clean,contains('Income: 27,250'));
    expect(clean,contains('مطاعم وكافيهات'));
    expect(clean,isNot(contains('**')));
    expect(clean,isNot(contains('##')));
    expect(clean,isNot(contains('All values derived directly')));
    final broken=WaffraAiRecordedAnswers.cleanModelAnswer(
      'مصروفاتك المسجلة: 120 ريال\n'
      '*All values derived directly from)*\n*(the JSON data.');
    expect(broken,contains('مصروفاتك المسجلة'));
    expect(broken,isNot(contains('All values derived')));
    expect(broken,isNot(contains('JSON data')));
    expect(WaffraAiRecordedAnswers.cleanModelAnswer(
      '<think>internal reasoning</think>النتيجة مختصرة'),'النتيجة مختصرة');
    expect(WaffraAiRecordedAnswers.cleanModelAnswer(
      '{"income_minor":120000}'),isNull);
  });

  test('M333 Ask Waffra checks verified records before calling local Qwen',(){
    final home=File('lib/waffra_smart_features.dart').readAsStringSync();
    final from=home.indexOf('void _ask(){');
    final until=home.indexOf('Widget _assistant(){',from);
    expect(from,greaterThan(0));
    expect(until,greaterThan(from));
    final method=home.substring(from,until);
    expect(method,contains('WaffraAiRecordedAnswers.answer('));
    expect(method.indexOf('if(direct!=null)'),lessThan(
      method.indexOf("_generateAiSkill('ask'")));
    expect(method.indexOf('if(!WaffraOnDeviceQwen.shared.isReady)'),
      greaterThan(method.indexOf('if(direct!=null)')));
    expect(method,contains('Download the AI library to enable advice.'));
    expect(home,contains('WaffraAiRecordedAnswers.cleanModelAnswer(response)'));
    expect(home,contains('size:value.length>140?14:19'));
    expect(home,contains('textDirection:direction'));
  });

  test('M333 calendar-periods never default to all recorded expenses',(){
    final periodRows=<WaffraAiRecordedFact>[
      WaffraAiRecordedFact(date:DateTime(2026,10,23),
        category:'مطاعم',amountMinor:5000,income:false),
      WaffraAiRecordedFact(date:DateTime(2026,10,29),
        category:'مطاعم',amountMinor:3000,income:false),
      WaffraAiRecordedFact(date:DateTime(2025,11,20),
        category:'مطاعم',amountMinor:7000,income:false),
      WaffraAiRecordedFact(date:DateTime(2024,10,20),
        category:'مطاعم',amountMinor:4000,income:false),
    ];
    final yesterday=WaffraAiRecordedAnswers.answer(
      'صرفت كام أمس',periodRows,now:clock)!;
    expect(yesterday,contains('30.00 SAR'));
    expect(yesterday,contains('أمس'));
    final lastWeek=WaffraAiRecordedAnswers.answer(
      'صرفت كام الأسبوع اللي فات',periodRows,now:clock)!;
    expect(lastWeek,contains('50.00 SAR'));
    expect(lastWeek,contains('الأسبوع الماضي'));
    final rollingWeek=WaffraAiRecordedAnswers.answer(
      'How much did I spend this week?',periodRows,
      now:clock,english:true)!;
    expect(rollingWeek,contains('30.00 SAR'));
    final lastYear=WaffraAiRecordedAnswers.answer(
      'صرفت كام السنة الماضية',periodRows,now:clock)!;
    expect(lastYear,contains('70.00 SAR'));
    final twoYears=WaffraAiRecordedAnswers.answer(
      'صرفت كام آخر 24 شهر',periodRows,now:clock)!;
    expect(twoYears,contains('150.00 SAR'));
    expect(twoYears,isNot(contains('190.00 SAR')));
    expect(WaffraAiRecordedAnswers.answer(
      'صرفت كام آخر 130 شهر',periodRows,now:clock),
      'حدد فترة من شهر إلى 120 شهر.');
  });
}

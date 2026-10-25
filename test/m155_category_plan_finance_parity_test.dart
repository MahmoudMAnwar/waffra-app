import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_m155_category_plan.dart';
import 'package:waffra/waffra_category_catalog.dart';
import 'package:waffra/waffra_category_english.dart';
import 'package:waffra/waffra_i18n.dart';
import 'package:waffra/main.dart';

void main(){
 const catalog=<WaffraM155Category>[
  WaffraM155Category(id:'other',name:'أخرى',income:false),
  WaffraM155Category(id:'transfers',name:'تحويلات',income:false),
  WaffraM155Category(id:'income-transfers',name:'حوالات واردة',income:true),
  WaffraM155Category(id:'other-income',name:'دخل آخر',income:true),
  WaffraM155Category(id:'food',name:'مطاعم وكافيهات',income:false),
  WaffraM155Category(id:'fast',parentId:'food',
    name:'مطاعم وكافيهات / وجبات سريعة',income:false),
  WaffraM155Category(id:'uncategorized',parentId:'other',
    name:'أخرى / مصروف غير مصنف',income:false),
  WaffraM155Category(id:'uncategorized-income',parentId:'other-income',
    name:'دخل آخر / دخل غير مصنف',income:true),
 ];
 test('M155: repeating SHA WARMA capitalization maps to one existing leaf',(){
  const sms1='شراء PoS\nبـSAR 72.01\nلـSHAWARMA H\n15/10/26 16:09';
  const sms2='شراء PoS\nبـSAR 83.90\nلـshawerma h\n11/10/26 11:25';
  final a=WaffraM155CategoryPlan.propose(
   rawSms:sms1,income:false,existing:catalog,learned:const {});
  final b=WaffraM155CategoryPlan.propose(
   rawSms:sms2,income:false,existing:catalog,learned:const {});
  expect(a!.categoryName,'مطاعم وكافيهات / وجبات سريعة');
  expect(a.newCategoryRequired,isFalse);
  expect(b!.categoryName,a.categoryName);
  expect(a.merchantKey,b.merchantKey);
 });

 test('M155: unknown POS creates proposal only and preserves original catalog',(){
  const sms='شراء PoS\nبـSAR 233.35\nلـALHUSSAIN\n20/10/26 22:26';
  final before=catalog.length;
  final item=WaffraM155CategoryPlan.propose(
   rawSms:sms,income:false,existing:catalog,learned:const {});
  expect(item!.categoryName,'أخرى / ALHUSSAIN');
  expect(item.newCategoryRequired,isTrue);
  expect(catalog.length,before);
 });

 test('M155: inbound and outbound counterparty names have separate parents',(){
  const incoming='حوالة داخلية واردة بـSR 15.50\nلـ9288\nمن4388;انس الشايب\n26/10/11 12:29';
  const outgoing='حوالة داخلية صادرة بـSR 14\nمن9288\nلـ4388;انس الشايب\n26/10/12 22:35';
  final debit=WaffraM155CategoryPlan.propose(
   rawSms:outgoing,income:false,existing:catalog,learned:const {});
  final credit=WaffraM155CategoryPlan.propose(
   rawSms:incoming,income:true,existing:catalog,learned:const {});
  expect(debit!.categoryName,'تحويلات / انس الشايب');
  expect(credit!.categoryName,'حوالات واردة / انس الشايب');
  expect(debit.newCategoryRequired,isTrue);
  expect(credit.newCategoryRequired,isTrue);
  expect(debit.merchantKey,credit.merchantKey);
 });

 test('M155: recognized user correction outranks a known catalog prediction',(){
  final withManual=<WaffraM155Category>[...catalog,
   const WaffraM155Category(id:'custom',parentId:'other',
    name:'أخرى / مخصص',income:false),
  ];
  final item=WaffraM155CategoryPlan.propose(
   rawSms:'شراء PoS\nبـSAR 10\nلـSHAWARMA H',
   income:false,existing:withManual,
   learned:const {'shawarma h':'أخرى / مخصص'});
  expect(item!.categoryName,'أخرى / مخصص');
  expect(item.newCategoryRequired,isFalse);
 });

 test('M155: deleted category parents never get automatically recreated',(){
  const absent=<WaffraM155Category>[
   WaffraM155Category(id:'other-income',name:'دخل آخر',income:true),
   WaffraM155Category(id:'uncategorized-income',name:'دخل آخر / دخل غير مصنف',
    parentId:'other-income',income:true),
  ];
  final item=WaffraM155CategoryPlan.propose(
   rawSms:'شراء PoS\nبـSAR 20\nلـUNKNOWN SHOP',
   income:false,existing:absent,learned:const {});
  expect(item,isNull);
 });

 test('Arabic storage category is stable with English or Arabic UI',(){
  final full=<WaffraM155Category>[];
  for(final g in waffraCategoryCatalog){
   full.add(WaffraM155Category(id:g.id,name:g.name,income:g.income));
   for(var i=0;i<g.subcategories.length;i++){
    full.add(WaffraM155Category(
     id:'${g.id}-${i+1}',
     name:'${g.name} / ${g.subcategories[i]}',
     income:g.income,parentId:g.id));
   }
  }
  final cases=<String,String>{
   'Purchase Card\nAmount: SAR 42\nAt: Keemart':
    'بقالة وتموين / سوبرماركت',
   'شراء نقاط بيع\nالمبلغ: 49 ريال\nلدى: كيتا':
    'مطاعم وكافيهات / توصيل الطعام',
   'Purchase Card\nAmount: 35 SAR\nAt: DR MOHAMMAD RASHID ALF':
    'صحة / أطباء',
   'شراء نقاط بيع\nالمبلغ: 40 ريال\nلدى: صيدلية النهدي':
    'صحة / صيدلية وأدوية',
   'Credit via local transfer\nAmount: SAR 1613.00\nFrom: SAMPLE NAME':
    'حوالات واردة / حوالة محلية',
   'Refund Received\nAmount: SAR 40.00':
    'مبالغ مستردة / استرجاع مشتريات',
  };
  try{
   for(final language in ['ar','en']){
    waffraLanguage.value=language;
    for(final entry in cases.entries){
     final parsed=BankParser.parse(entry.key);
     expect(parsed.amount,isNotNull,reason:entry.key);
     final assignment=WaffraM155CategoryPlan.propose(
      rawSms:entry.key,income:parsed.income,
      existing:full,learned:const {});
     expect(assignment,isNotNull,reason:entry.key);
     expect(assignment!.categoryName,entry.value,
      reason:'Persist same Arabic leaf with UI language $language');
     expect(assignment.newCategoryRequired,isFalse);
     if(language=='en'){
      expect(waffraEnglishCategoryLabel(assignment.categoryName),
       isNot(equals(assignment.categoryName)));
     }
    }
   }
  }finally{waffraLanguage.value='ar';}
 });

 test('user corrections outrank the classifier, deleted leaves not resurrected',(){
  final all=<WaffraM155Category>[];
  for(final g in waffraCategoryCatalog){
   all.add(WaffraM155Category(id:g.id,name:g.name,income:g.income));
   for(var i=0;i<g.subcategories.length;i++){
    all.add(WaffraM155Category(id:'${g.id}-$i',parentId:g.id,
     name:'${g.name} / ${g.subcategories[i]}',income:g.income));
   }
  }
  const sms='Purchase Card\nAmount: 20 SAR\nAt: Keemart';
  const override='أخرى / مصروف غير مصنف';
  final learned=WaffraM155CategoryPlan.propose(
   rawSms:sms,income:false,existing:all,
   learned:const {'keemart':override});
  expect(learned?.categoryName,override);
  final deleted=all.where((c)=>c.name!='بقالة وتموين / سوبرماركت')
   .toList();
  final next=WaffraM155CategoryPlan.propose(
   rawSms:sms,income:false,existing:deleted,learned:const {});
  expect(next?.categoryName,isNot('بقالة وتموين / سوبرماركت'));
 });

}

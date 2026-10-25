import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_merchant_rules.dart';

void main() {
  test('extracts a Latin merchant from Saudi POS SMS', () {
    expect(waffraMerchantKey('شراء PoS من مدى SAR 65.90 Shawerma HJ 8/10/26'),
        'shawarma hj');
    expect(waffraMerchantKey('شراء PoS من مدى PANDA RETJ SAR 25.69'),
        'panda retj');
  });

  test('M158: POS inline merchant never includes amount, date or bank identifier', () {
    const sms='شراء PoS من مدى SAR 65.90 Shawerma HJ 8/10/26';
    expect(waffraSafeSmsTransactionTitle('شراء نقاط بيع',sms,income:false),
        'شراء نقاط بيع — Shawerma HJ');
    expect(waffraMerchantKey(sms),'shawarma hj');
    expect(waffraMerchantName('شراء PoS من مدى SAR 65.90 8/10/26'),isNull);
    expect(waffraMerchantName(
        'شراء PoS من مدى SAR 65.90 SHOP 4321123412349999'),isNull);
  });

  test('no merchant rules are invented for generic transfers', () {
    expect(waffraMerchantKey('حوالة واردة من 9288 مبلغ 15.50 ريال'), isNull);
  });

  test('rule keys are case-insensitive', () {
    expect(waffraMerchantKey('شراء SR 80.00 PETRO 288'),
        waffraMerchantKey('شراء sr 80.00 petro 288'));
  });
  test('M158: Widget SMS title contains only a generic operation and safe merchant', () {
    const sms='شراء نقاط بيع\nلدى: ALHUSSAIN SHOP\n'
      'البطاقة: ****9876\nالمبلغ: 84.72 SAR';
    final title=waffraSafeSmsTransactionTitle('شراء نقاط بيع',sms,income:false);
    expect(title,'شراء نقاط بيع — ALHUSSAIN SHOP');
    expect(title.contains('9876'),false);
    expect(title.contains('84.72'),false);
    expect(title.contains('البطاقة'),false);
  });

  test('M158: mixed merchant and card/account number is omitted entirely', () {
    const sms='شراء نقاط بيع\nلدى: SHOP 4321123412349999\n'
      'بمبلغ 10 SAR';
    expect(waffraSafeSmsTransactionTitle('شراء نقاط بيع',sms,income:false),
      'شراء نقاط بيع');
    expect(waffraMerchantKey(sms,income:false),isNull);
  });

  test('M158: unknown parser labels cannot echo raw account data', () {
    expect(waffraSafeSmsTransactionTitle(
      'Credit card 5432123454329999','عملية مجهولة',income:true),
      'مبلغ وارد');
  });
  test('M158: historical merchant fallback rejects bank and card IDs', () {
    expect(waffraMerchantKey('شراء — SHOP CARD 5432123454329999'),isNull);
    expect(waffraMerchantKey('حوالة — حساب 123456789012'),isNull);
    expect(waffraMerchantKey('شراء — ALHUSSAIN SHOP'),'alhussain shop');
  });

  test('Saudi English and Arabic merchants map to the same Arabic leaf', () {
    final cases=<String,String>{
      'Keemart':'بقالة وتموين / سوبرماركت',
      'كيمارت':'بقالة وتموين / سوبرماركت',
      'LULU HYPER KHURAIS RD':'بقالة وتموين / سوبرماركت',
      'العثيم - حي الخليج':'بقالة وتموين / سوبرماركت',
      'TAMIMI MARKETS':'بقالة وتموين / سوبرماركت',
      'NANA EXPRESS':'بقالة وتموين / سوبرماركت',
      'PANDA RETAIL':'بقالة وتموين / سوبرماركت',
      'Keeta':'مطاعم وكافيهات / توصيل الطعام',
      'كيتا':'مطاعم وكافيهات / توصيل الطعام',
      'HungerStation':'مطاعم وكافيهات / توصيل الطعام',
      'جاهز':'مطاعم وكافيهات / توصيل الطعام',
      'ALNAHDI PHARMACY':'صحة / صيدلية وأدوية',
      'صيدلية النهدي':'صحة / صيدلية وأدوية',
      'ALDAWAA PHARMACY':'صحة / صيدلية وأدوية',
      'DR MOHAMMAD RASHID ALF':'صحة / أطباء',
      'Dr. Ahmed':'صحة / أطباء',
      'دكتور خالد':'صحة / أطباء',
      'Medical Center Riyadh':'صحة / عيادات',
      'MAR AKEZ MEDICAL COMPAN':'صحة / عيادات',
      'CLINIC CENTER':'صحة / عيادات',
      'Dental Clinic':'صحة / عيادات',
      'Jeeny':'مواصلات / تاكسي',
      'جيني':'مواصلات / تاكسي',
      'Uber Trip':'مواصلات / أوبر وكريم',
      'كارفور':'بقالة وتموين / سوبرماركت',
      'SHEIN.COM':'تسوّق / ملابس',
      'Noon':'تسوّق / تسوق إلكتروني',
      'AMAZON SA':'تسوّق / تسوق إلكتروني',
      'STARBUCKS Riyadh':'مطاعم وكافيهات / مقاهي',
      'SHAWARMA HJ':'مطاعم وكافيهات / وجبات سريعة',
      'ALBAIK':'مطاعم وكافيهات / وجبات سريعة',
      'McDonalds':'مطاعم وكافيهات / وجبات سريعة',
      'STC MOBILE':'فواتير / جوال',
      'MOBILY':'فواتير / جوال',
      'NETFLIX':'اشتراكات رقمية / بث أفلام',
      'SPOTIFY':'اشتراكات رقمية / بث موسيقى',
      'OPENAI':'اشتراكات رقمية / اشتراكات ذكاء اصطناعي',
      'FITNESS TIME':'رياضة ولياقة / اشتراك نادي',
      'الخطوط السعودية':'سفر وسياحة / تذاكر طيران',
    };
    for(final entry in cases.entries){
      expect(waffraRecognizedMerchantLeaf(entry.key,income:false),
       entry.value,reason:entry.key);
      expect(waffraRecognizedMerchantLeaf(entry.key,income:true),
       isNull,reason:'Merchant brand cannot turn bank credit into an expense');
    }
  });

  test('name collision protections: bank rails and DR inside words never classify', () {
    for(final merchant in [
      'AlinmaPay','MADA','DRIVE PARK','ADDRESS SHOP','STC PAY',
      'PAYMENT GATEWAY','TAMARA','TABBY','PERSONAL TRANSFER',
    ]){
      expect(waffraRecognizedMerchantLeaf(merchant,income:false),isNull,
       reason:'A rail or substring is not enough evidence: $merchant');
    }
  });

  test('financial direction and category intent remain separate', () {
    expect(waffraRecognizedSmsLeaf(
      'Credit via local transfer\nAmount: SAR 1613.00',income:true),
      'حوالات واردة / حوالة محلية');
    expect(waffraRecognizedSmsLeaf(
      'Refund Received\nAmount: SAR 20.00',income:true),
      'مبالغ مستردة / استرجاع مشتريات');
    expect(waffraRecognizedSmsLeaf(
      'Salary Credit\nAmount: SAR 5000',income:true),
      'راتب / راتب أساسي');
    expect(waffraRecognizedSmsLeaf(
      'Purchase Card\nAmount: SAR 42\nAt: Keemart',
      income:false,merchant:'Keemart'),
      'بقالة وتموين / سوبرماركت');
    expect(waffraRecognizedSmsLeaf(
      'شراء نقاط بيع\nمبلغ: 23 ريال\nلدى: كيتا',
      income:false,merchant:'كيتا'),
      'مطاعم وكافيهات / توصيل الطعام');
  });

}

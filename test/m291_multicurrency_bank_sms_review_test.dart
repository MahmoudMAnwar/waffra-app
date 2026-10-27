import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  test('M291 currency scan distinguishes SAR, EGP, USD and EUR', () {
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'شراء PoS\nبـ84.72SR\nالرصيد المتبقي 50 ريال'), {'SAR'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'تم خصم مبلغ ١٥٠ جنيه مصري\nالرصيد ١٠٠٠ ريال'), {'EGP'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'Debit card purchase\nAmount: 50 USD\nAvailable Balance: 300 SAR'),
      {'USD'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'Paiement par carte effectué\nAmount: EUR 19,50'), {'EUR'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'Pago realizado\nAmount: MXN 200'), {'UNKNOWN'});
  });

  test('M291 POS and ATM abbreviations are not fake currencies', () {
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'POS 84.72 SAR'), {'SAR'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
      'ATM 300 SAR'), {'SAR'});
    expect(BankParser.parse('POS 84.72 SAR').requiresCurrencyReview, isFalse);
  });

  test('M291 same-line balance does not hide the actual foreign amount', () {
    final message='Card Purchase: USD 25.00; Available Balance: SAR 500';
    expect(WaffraSmsCurrencies.currenciesForMessage(message), {'USD'});
    expect(BankParser.parse(message).amount, isNull);
    expect(BankParser.parse(message).requiresCurrencyReview, isTrue);
  });

  test('M291 mixed currencies are grouped, never summed', () {
    final result = WaffraSmsCurrencies.summarize([
      'شراء PoS\nAmount 90 SAR',
      'Incoming Transfer\nAmount: 10 USD',
      'Compra con tarjeta\nEUR 70.00',
      'Salary Credit\nAmount: 200 USD',
    ]);
    expect(result.counts, {'SAR': 1, 'USD': 2, 'EUR': 1});
    expect(result.hasMixedCurrencies, isTrue);
    expect(result.needsCurrencyReview, isTrue);
    expect(result.summary, contains('USD: 2'));
  });

  test('M291 no foreign posted as SAR, including mixed balance notices', () {
    final foreign = BankParser.parse(
      'Outgoing Transfer\nAmount: 50 USD\nAvailable balance: 200 SAR');
    expect(foreign.amount, isNull);
    expect(foreign.currencyCode, 'USD');
    expect(foreign.requiresCurrencyReview, isTrue);

    final local = BankParser.parse(
      'Incoming Transfer\nAmount: 200 SAR\nAvailable balance 300 USD');
    expect(local.amount, 200);
    expect(local.income, isTrue);
    expect(local.requiresCurrencyReview, isFalse);
  });

  test('M291 foreign currency imports need manual review even if displayed currency is EGP', () {
    final egyptian = BankParser.parse(
      'تم خصم مبلغ ١٥٠ EGP من حسابك');
    expect(egyptian.amount, isNull);
    expect(egyptian.requiresCurrencyReview, isTrue);
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(
      'Incoming Transfer\nAmount: 100 SAR'), isFalse);
  });

  test('M291 undefined $ and multiple currencies do not create debit', () {
    const ambiguous = 'Outgoing Transfer\nAmount: $100.00';
    expect(WaffraSmsCurrencies.currenciesForMessage(ambiguous),
        {'UNKNOWN'});
    expect(BankParser.parse(ambiguous).amount, isNull);
    expect(BankParser.parse(ambiguous).requiresCurrencyReview, isTrue);
    final mixed = BankParser.parse(
      'Card Purchase\nAmount 100 USD\nFee 2 EUR');
    expect(mixed.amount, isNull);
    expect(mixed.requiresCurrencyReview, isTrue);
  });
}

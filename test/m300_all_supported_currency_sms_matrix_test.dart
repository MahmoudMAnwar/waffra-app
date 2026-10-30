import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_display_currency.dart';
import 'package:waffra/waffra_sms_fx_review.dart';
import 'package:waffra/waffra_sms_intelligence.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  test('M300 all 36 display currencies have matching SMS coverage', () {
    final display=waffraCountryCurrencies.map((item)=>item.code).toSet();
    expect(display.length, 36);
    expect(WaffraSmsCurrencies.supported, display);
  });

  test('M300 each currency recognized before and after amount, regardless of balance', () {
    for (final currency in WaffraSmsCurrencies.supported) {
      final precision=WaffraCurrencyMinor.digits(currency);
      final amount=precision==0?'198':precision==3?'198.125':'198.75';
      final expected=amount+' '+currency;
      final prefix=currency+amount+
          ' has been credited to account from sender. Balance 201.632'+currency;
      final suffix='Incoming Transfer received\nAmount: '+amount+' '+currency+
          '\nAvailable balance: 999 '+currency;
      expect(WaffraSmsCurrencies.currenciesForMessage(prefix), {currency},
          reason:'prefix '+currency);
      expect(WaffraSmsCurrencies.currenciesForMessage(suffix), {currency},
          reason:'suffix '+currency);
      expect(WaffraSmsCurrencies.originalAmountPreview(prefix), expected,
          reason:'prefix amount '+currency);
      expect(WaffraSmsCurrencies.originalAmountPreview(suffix), expected,
          reason:'suffix amount '+currency);
      final parsed=BankParser.parse(prefix);
      expect(parsed.income, isTrue, reason:'income '+currency);
      if (currency!='SAR') {
        expect(parsed.currencyCode, currency, reason:currency);
        expect(parsed.amount, isNull,reason:'must not invent SAR for '+currency);
        expect(parsed.requiresCurrencyReview, isTrue,reason:currency);
      }
      expect(WaffraCurrencyMinor.exact(double.parse(amount),currency),isNotNull,
          reason:'minor units '+currency);
    }
  });

  test('M300 international decimals parse without silently changing precision',(){
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received USD 1,234.50 Balance 999.00 USD'),
        '1234.50 USD');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received EUR 1.234,50 Balance 999.00 EUR'),
        '1234.50 EUR');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received EUR 19,50 Balance 999.00 EUR'),
        '19.50 EUR');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JOD198.125 Balance 201.632JOD'),
        '198.125 JOD');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JOD 1,234 Balance 201.632JOD'),
        isNull, reason:'single 3-digit comma is ambiguous');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JPY 1,234 Balance 50,000 JPY'),
        '1234 JPY',reason:'JPY has no fractional units');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received KRW1,234 Balance 50,000KRW'),
        '1234 KRW',reason:'KRW grouped thousands are unambiguous');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JOD 1,234 Balance 500 JOD'),isNull,
        reason:'3-decimal currency comma remains ambiguous');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received USD 1,234 Balance 500 USD'),isNull,
        reason:'2-decimal currency comma stays conservative');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JPY 198.50 Balance 200 JPY'),isNull);
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received EUR 19.500 Balance 200 EUR'),isNull);
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received JOD 10.1234 Balance 200 JOD'),isNull);
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received USD 0 Balance 999 USD'),isNull);
  });

  test('M300 aliases preserve names and Arabic/Persian digits',(){
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'تم إيداع ١٥٠٫٢٥ ريال\nالرصيد 300 ريال'), '150.25 SAR');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'Transfer received EUR ۱۹٫۵۰ Balance EUR 20'), '19.50 EUR');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'تم خصم ١٩٫٥٠ جنيه مصري\nالرصيد ٢٠٠ جنيه'), '19.50 EGP');
    expect(WaffraSmsCurrencies.originalAmountPreview(
        'تم خصم ١٩٫٥٠ درهم إماراتي\nالرصيد ٢٠٠ درهم'), '19.50 AED');
  });

  test('M300 ambiguous/mixed lines require manual correction, never an incorrect debit',(){
    const mixed='Money received USD 10.25 and EUR 20.50 Balance 800 USD';
    expect(WaffraSmsCurrencies.currenciesForMessage(mixed),{'USD','EUR'});
    expect(WaffraSmsCurrencies.originalAmountPreview(mixed),isNull);
    final blocked=BankParser.parse(mixed);
    expect(blocked.amount,isNull);
    expect(blocked.requiresCurrencyReview,isTrue);
    expect(blocked.currencyCode,isNull);
    const unknown='Money credited MXN 200 Balance 300 MXN';
    expect(WaffraSmsCurrencies.currenciesForMessage(unknown),{'UNKNOWN'});
    expect(WaffraSmsCurrencies.originalAmountPreview(unknown),isNull);
    expect(BankParser.parse(unknown).requiresCurrencyReview,isTrue);
    expect(WaffraSmsCurrencies.currenciesForMessage(
        'Balance JOD 201.632'),isEmpty);
    expect(WaffraSmsCurrencies.currenciesForMessage(
        'OTP 445566 and balance SAR 999'),isEmpty);
  });

  test('M300 manual bank SMS editor blocks foreign currency before hashing',(){
    final app=File('lib/main.dart').readAsStringSync();
    final editor=app.indexOf('Future<void> entrySheet(');
    final save=app.indexOf('if(message.text.trim().isEmpty)return;',editor);
    final hash=app.indexOf('final h=sha256.convert',save);
    expect(editor,greaterThan(0));
    expect(save,greaterThan(editor));
    expect(hash,greaterThan(save));
    final boundary=app.substring(save,hash);
    expect(boundary,contains(
      'WaffraSmsCurrencies.requiresReviewForSarLedger(message.text)'));
    expect(boundary,contains('return;'));
    for(final code in WaffraSmsCurrencies.supported) {
      final text='Transfer received '+code+' 123.50 Balance 900 '+code;
      expect(WaffraSmsCurrencies.requiresReviewForSarLedger(text),
        code!='SAR',reason:code);
    }
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(
       'Money received MXN 18.25 Balance 999 MXN'),isTrue);
    expect(WaffraSmsCurrencies.currenciesForMessage(
       'Money received mxn 18.25 Balance 999 mxn'),{'UNKNOWN'});
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(
       'Money received mxn 18.25 Balance 999 mxn'),isTrue);
    expect(WaffraSmsCurrencies.currenciesForMessage(
       'Money received brl 18.25 Balance 999 brl'),{'UNKNOWN'});
    expect(WaffraSmsCurrencies.currenciesForMessage(
       'Money has 18 seconds and is ready'),isEmpty);
    expect(WaffraSmsCurrencies.requiresReviewForSarLedger(
       'Money received USD 18.25 and SAR 19.25'),isTrue);
  });

  test('M300 original currency and FX minor units are consistent',(){
    for(final currency in WaffraSmsCurrencies.supported) {
      expect(WaffraCurrencyMinor.digits(currency),
          WaffraSmsCurrencies.minorDigits(currency));
    }
    final hint=WaffraSmsIntelligence.classify(
      'Incoming transfer received JOD198.125 Balance 201.632JOD');
    expect(hint.currency,'JOD');
    expect(hint.amount,198.125);
    expect(hint.requiresCurrencyReview,isTrue);
    expect(hint.canAutoSuggestSar,isFalse);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_sms_intelligence.dart';

void main() {
  group('M289 free offline multilingual intent classification', () {
    final known = <({String sms, WaffraSmsIntent expected})>[
      (sms:'Your account has been credited with USD 500.00',
       expected:WaffraSmsIntent.incoming),
      (sms:'You spent USD 100.00 on groceries',
       expected:WaffraSmsIntent.outgoing),
      (sms:'Incoming ACH deposit SAR 100.55',
       expected:WaffraSmsIntent.incoming),
      (sms:'UPI payment sent INR 700.00',
       expected:WaffraSmsIntent.outgoing),
      (sms:'Transferencia recibida EUR 250,50 a tu cuenta',
       expected:WaffraSmsIntent.incoming),
      (sms:'Transferencia enviada USD 80.00',
       expected:WaffraSmsIntent.outgoing),
      (sms:'Paiement par carte effectué 50.00 EUR',
       expected:WaffraSmsIntent.outgoing),
      (sms:'تم ايداع مبلغ قدره ٢٠٠ ريال',
       expected:WaffraSmsIntent.incoming),
      (sms:'تم سحب ١٠٠ درهم من حسابك',
       expected:WaffraSmsIntent.outgoing),
    ];

    for(final item in known){
      test('trained classification: ${item.sms}', (){
        final result=WaffraSmsIntelligence.classify(item.sms);
        expect(result.intent,item.expected);
        expect(result.confidence,greaterThanOrEqualTo(.84));
      });
    }

    test('does not invent transactions from OTP, balance, holds or failures', (){
      for(final sms in <String>[
        'OTP 123456 for your payment SAR 200',
        'Authorization Hold USD 30.00',
        'Transaction Declined USD 100.00',
        'Payment pending EUR 120.00',
        'Your available balance USD 3000',
        'Account balance SAR 50.00',
        'تم رفض العملية بقيمة ٤٠ ريال',
        'Text message without any money information',
      ]){
        final result=WaffraSmsIntelligence.classify(sms);
        expect(result.intent,WaffraSmsIntent.uncertain,
          reason:'No completed finance event may be guessed: $sms');
      }
    });

    test('foreign currency cannot be automatically interpreted as SAR', (){
      for(final sms in <String>[
        'Transferencia recibida EUR 250,50 a tu cuenta',
        'Transferencia enviada USD 80.00',
        'UPI payment sent INR 700.00',
        'Paiement par carte effectué 50.00 EUR',
      ]){
        final model=WaffraSmsIntelligence.classify(sms);
        expect(model.currency,isNot('SAR'));
        expect(model.requiresCurrencyReview,isTrue);
        expect(model.canAutoSuggestSar,isFalse);
        final parsed=BankParser.parse(sms);
        expect(parsed.amount,isNull);
        expect(parsed.requiresCurrencyReview,isTrue);
      }
    });

    test('new international wording with explicit SAR can suggest, not auto-commit', (){
      const raw='You received a refund\nAmount SAR 90.20';
      final model=WaffraSmsIntelligence.classify(raw);
      expect(model.intent,WaffraSmsIntent.incoming);
      expect(model.currency,'SAR');
      expect(model.amount,90.20);
      final parsed=BankParser.parse(raw);
      expect(parsed.income,isTrue);
      expect(parsed.amount,90.20);
    });

    test('existing Saudi parser and English headers unchanged', (){
      expect(BankParser.parse('شراء PoS\nبـ84.72SR').amount,84.72);
      expect(BankParser.parse('شراء PoS\nبـ84.72SR').income,isFalse);
      expect(BankParser.parse('Incoming Transfer\nAmount: 300.25 SAR').income,isTrue);
      expect(BankParser.parse('Outgoing Transfer\nAmount: 90.10 SAR').income,isFalse);
      expect(BankParser.parse('Amount: 1234.56 SAR\nAvailable balance: 4000 SAR').amount,isNull);
    });

    test('model has no network/PII code and never writes to finance DB', (){
      final source=File('lib/waffra_sms_intelligence.dart').readAsStringSync();
      expect(source,contains('_TinySmsIntentBayes'));
      expect(source,contains('_incomeSamples'));
      expect(source,contains('_expenseSamples'));
      expect(source,isNot(contains('package:http/')));
      expect(source,isNot(contains('Firebase')));
      expect(source,isNot(contains('SharedPreferences')));
      expect(source,isNot(contains('persist(')));
      expect(source,isNot(contains('commitConfirmedSms(')));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_bank_screenshot_parser.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  group('M341 multilingual English bank SMS financial accuracy', () {
    test('an English Alinma credit with a grouped SAR amount is income', () {
      const sms = 'Credit Transfer via Alinma Bank\n'
          'Amount: 1,900 SAR\n'
          'From: TEST SENDER\n'
          'IBAN: **0000\n'
          'Date: 2026-11-01 08:46';
      final posted = WaffraSmsCurrencies.originalAmount(sms);
      expect(posted?.currency, 'SAR');
      expect(posted?.amount, 1900);
      final parsed = BankParser.parse(sms);
      expect(parsed.amount, 1900);
      expect(parsed.income, isTrue);
    });

    test('glued credit and card purchase remain two different records', () {
      const glued = 'Credit Transfer via Alinma Bank\n'
          'Amount: 100 SAR\n'
          'Date: 2026-10-24 14:58'
          'Purchase Card\n'
          'Card: **0001 MADA\n'
          'Amount: 42 SAR\n'
          'At: TEST PHARMACY\n'
          'Remaining Balance: 13.38 SAR';
      final messages = splitBankMessages(glued);
      expect(messages, hasLength(2));
      expect(BankParser.parse(messages.first).income, isTrue);
      expect(BankParser.parse(messages.last).income, isFalse);
      expect(BankParser.parse(messages.last).amount, 42);
      expect(WaffraSmsCurrencies.originalAmount(messages.last)?.amount, 42);
    });

    test('AED debit and concatenated JOD CliQ credits/debits split correctly', () {
      const pasted =
          '136.00 AED debited from account ending with 1001 at '
          'TEST RESTAURANT. Balance: 4857.96 AED.'
          'JOD198.000 has been credited to 0119*500 from TEST PAYER '
          'as CliQ transfer. Balance 201.632JOD'
          'JOD10.000 has been debited from 0119*500 to TEST BENEFICIARY '
          'as CliQ transfer. Balance 3.632JOD';
      final chunks = splitBankMessages(pasted);
      expect(chunks, hasLength(3));
      final source = chunks.map(WaffraSmsCurrencies.originalAmount).toList();
      expect(source[0]?.currency, 'AED');
      expect(source[0]?.amount, 136);
      expect(source[1]?.currency, 'JOD');
      expect(source[1]?.amount, 198);
      expect(source[2]?.currency, 'JOD');
      expect(source[2]?.amount, 10);
      expect(BankParser.parse(chunks[1]).income, isTrue);
      expect(BankParser.parse(chunks[2]).income, isFalse);
      expect(chunks.every((c) => BankParser.parse(c).amount == null), isTrue,
          reason: 'Never write foreign original amounts into the SAR ledger');
    });

    test('internal transfers and credit-card settlements require review', () {
      const internal = 'Internal Transfer\nAmount:SR 500\n'
          'To:0001\nFrom:TEST PAYER\n26/10/25 00:36';
      const settlement = 'JOD 610.000 has been debited from 0119*500 '
          'on 29/09/2026 as Credit Card Payment Balance 13.632 JOD';
      for (final sms in [internal, settlement]) {
        final parsed = BankParser.parse(sms);
        expect(parsed.amount, isNull);
        expect(parsed.category, 'تحويلات');
      }
    });

    test('OTP, preauthorization and declined SMS are not posted totals', () {
      const completed = 'Purchase Card\nCard: **0001 MADA\n'
          'Amount: 42 SAR\nAt: TEST MERCHANT\nRemaining Balance: 50 SAR';
      const pending = 'Online Pre-Auth\nCard: MADA 0001\n'
          'Amount: 8.57 SAR\nAt: TEST RIDE';
      const otp = 'Please use the code: 0000\nFor card:*0001\n'
          'Amount:1 SAR\nMerchant: TEST RIDE';
      const declined = 'Declined Transaction\n'
          'Reason: Disabling Online purchases\n'
          'Amount: 99 SAR\nCard: *****0001';
      expect(WaffraSmsCurrencies.isUnpostedNotice(pending), isTrue);
      expect(WaffraSmsCurrencies.isUnpostedNotice(otp), isTrue);
      expect(WaffraSmsCurrencies.isUnpostedNotice(declined), isTrue);
      for (final sms in [pending, otp, declined]) {
        expect(BankParser.parse(sms).amount, isNull);
      }
      final totals = WaffraSmsCurrencies.sourceTotals(
          [completed, pending, otp, declined]);
      expect(totals.totals['SAR'], 42);
      expect(totals.unresolved, 0);
    });

    test('unlabelled 3-decimal comma is still ambiguous', () {
      expect(WaffraSmsCurrencies.originalAmount(
          'Transfer received JOD 1,234 Balance 201.632JOD'), isNull);
      expect(WaffraSmsCurrencies.originalAmount(
          'Transfer received USD 1,234 Balance 201 USD'), isNull);
    });
  });

  group('M341 English OCR screenshot review', () {
    test('purchase card headlines produce exactly three expense drafts', () {
      const text = 'Purchase Card\nAmount: 42 SAR\nAt: TEST MERCHANT\n'
          'On: 2026-10-24 18:53\n'
          'Online Purchase Card\nAmount: 80.55 SAR\nAt: Keeta\n'
          'On: 2026-10-21 23:40\n'
          'Purchase Card\nAmount: 37.76 SAR\nAt: LULU HYPER\n'
          'On: 2026-10-24 16:34';
      final rows = WaffraBankScreenshotParser.reviewItems(text);
      expect(rows, hasLength(3), reason: 'Do not duplicate purchase/card anchors');
      expect(rows.map((r) => r.amount).toList(), [42, 80.55, 37.76]);
      expect(rows.every((r) => !r.income), isTrue);
    });

    test('OCR retains foreign currency leading credit as review-only', () {
      const text = 'Purchase Card\nAmount: 10 SAR\nAt: TEST STORE\n'
          'JOD198.000 has been credited to TEST ACCOUNT. Balance 201.632JOD';
      final rows = WaffraBankScreenshotParser.reviewItems(text);
      expect(rows, hasLength(2));
      expect(rows.first.amount, 10);
      expect(rows.last.income, isTrue);
      expect(rows.last.amount, isNull,
          reason: 'Foreign OCR cannot prefill a SAR-only ledger amount');
    });
  });
}

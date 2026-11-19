import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/storage/waffra_account_context_policy.dart';

/// M1039/#767: the actual Saudi POS body, not just a guessed last-four from
/// the manual editor. Only unique verified bank identifiers can bind money.
void main() {
  const pos = 'شراء عبر نقاط البيع\n'
      'بطاقة: **6314 MADA\n'
      'مبلغ: 33.81 SAR\n'
      'لدى: Marakez Medical Compan\n'
      'في: 2026-11-18 18:51\n'
      'الرصيد المتبقي: ريال 93.95';

  test('M1039 Saudi POS card label supplies verified expense source', () {
    final facts = WaffraBankSmsFactsParser.parse(pos);
    expect(facts.kind, WaffraBankOperationKind.expense);
    expect(facts.sourceSuffix, '6314');
    expect(facts.destinationSuffix, isNull);
    expect(facts.pending, isFalse);
    final decision = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: facts.sourceSuffix,
      destinationSuffix: facts.destinationSuffix,
      incoming: false,
      classifiedIncomeOrExpense: facts.canAutoPostAsIncomeExpense,
      verifiedSuffixByAccount: const {'confirmed-bank': '6314', 'other-bank': '7856'},
    );
    expect(decision.confident, isTrue);
    expect(decision.accountId, 'confirmed-bank');
    expect(WaffraBankSmsFactsParser.suggestedAccountLastFour(
      pos, income: false, preParsed: facts), '6314');
  });

  test('M1039 Arabic variants and Persian masked digits are normalized', () {
    for (final label in <String>['بطاقة:', 'البطاقة:', 'بطاقتك:']) {
      final facts = WaffraBankSmsFactsParser.parse(
        'شراء عبر نقاط البيع\n$label ****٦٣١٤\nمبلغ: 33.81 SAR');
      expect(facts.sourceSuffix, '6314', reason: label);
    }
    expect(WaffraBankSmsFactsParser.parse(
      'شراء عبر نقاط البيع بطاقة: xx۶۳۱۴\nمبلغ: 33.81 SAR'
    ).sourceSuffix, '6314');
  });

  test('M1039 ambiguous or unmasked POS identities cannot be assigned', () {
    for (final sms in <String>[
      'شراء عبر نقاط البيع\nبطاقة: 6314\nمبلغ: 33.81 SAR',
      'شراء عبر نقاط البيع\nبطاقة: **63145\nمبلغ: 33.81 SAR',
      'شراء عبر نقاط البيع\nبطاقة: **6314\nبطاقة: **7856\nمبلغ: 33.81 SAR',
    ]) {
      final facts = WaffraBankSmsFactsParser.parse(sms);
      expect(facts.sourceSuffix, isNull, reason: sms);
      final decision = WaffraAccountContextPolicy.matchBankSms(
        sourceSuffix: facts.sourceSuffix,
        destinationSuffix: facts.destinationSuffix,
        incoming: false,
        classifiedIncomeOrExpense: facts.canAutoPostAsIncomeExpense,
        verifiedSuffixByAccount: const {'confirmed-bank': '6314'},
      );
      expect(decision.confident, isFalse, reason: sms);
      expect(decision.accountId, isNull, reason: sms);
    }
    final unknown = WaffraAccountContextPolicy.matchBankSms(
      sourceSuffix: '6314', destinationSuffix: null,
      incoming: false, classifiedIncomeOrExpense: true,
      verifiedSuffixByAccount: const {'bank-a': '6314', 'bank-b': '6314'},
    );
    expect(unknown.confident, isFalse);
  });

  test('M1039 OTP and existing external transfer cannot authorize posting', () {
    final otp = WaffraBankSmsFactsParser.parse(
      'رمز التحقق 123456 لبطاقة: **6314');
    expect(otp.securityChallenge, isTrue);
    expect(otp.canAutoPostAsIncomeExpense, isFalse);
    final transfer = WaffraBankSmsFactsParser.parse(
      'حوالة داخلية صادرة من حساب: **7856\n'
      'إلى حساب: **1234\nمبلغ: 50 SAR');
    expect(transfer.sourceSuffix, '7856');
    expect(transfer.destinationSuffix, '1234');
    expect(transfer.requiresBeneficiaryReview, isTrue);
    expect(transfer.canAutoPostAsIncomeExpense, isFalse);
  });
}

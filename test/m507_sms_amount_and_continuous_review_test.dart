import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_sms_local_rules.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';

void main() {
  // Exact screenshot sample. The product plan (240) and the masked card
  // suffix (8308) must NEVER be interpreted as transaction money.
  const sample='شحن الجوال\n'
    'مبلغ:276 ريال\n'
    'إلى:**8308\n'
    'المنتج:سوا فليكس 240\n'
    'في:05-11-2026 19:07';

  test('M507-01 parses screenshot as confirmed 276 SAR mobile expense', () {
    final facts=WaffraBankSmsFactsParser.parse(sample);
    expect(facts.kind,WaffraBankOperationKind.expense);
    expect(facts.pending,isFalse);
    expect(facts.destinationSuffix,'8308');
    final src=WaffraSmsCurrencies.originalAmount(sample);
    expect(src?.currency,'SAR');
    expect(src?.amount,276);
    final parsed=BankParser.parse(sample);
    expect(parsed.amount,276);
    expect(parsed.income,isFalse);
    expect(parsed.title,'شحن الجوال');
    expect(parsed.category,'فواتير / جوال');
    expect(parsed.requiresCurrencyReview,isFalse);
  });

  test('M507-01 handles Arabic-Indic numerals without taking product price', () {
    const arabic='شحن الجوال\nمبلغ:٢٧٦ ريال\n'
      'إلى:**٨٣٠٨\nالمنتج:سوا فليكس 240\nفي:05-11-2026 19:07';
    expect(WaffraSmsCurrencies.originalAmount(arabic)?.amount,276);
    expect(BankParser.parse(arabic).amount,276);
  });

  test('M507-01 source amount is required despite other numeric tokens', () {
    const masked='شحن الجوال\nإلى:**8308\n'
      'المنتج:سوا فليكس 240\nفي:05-11-2026 19:07';
    expect(WaffraSmsCurrencies.originalAmount(masked),isNull);
    expect(BankParser.parse(masked).amount,isNull);
  });

  test('M507-02 a second reviewed top-up gets category suggestion only', () {
    const next='شحن الجوال\nمبلغ:315 ريال\n'
      'إلى:**8308\nالمنتج:سوا فليكس 240\nفي:06-11-2026 09:00';
    final approved=WaffraSmsLocalRules.manualCategoryPattern(
      description:'شحن الجوال',category:'فواتير / جوال',income:false);
    expect(approved,isNotNull);
    expect(approved!.autoPost,isFalse);
    // The account ID is a non-null String: empty means no inferred account.
    expect(approved.accountId,isEmpty);
    expect(approved.accountSuffix,isEmpty);
    final rules=WaffraSmsLocalRules.upsertLearned(
      existing:const <WaffraSmsLocalRule>[],candidate:approved);
    final suggestion=WaffraSmsLocalRules.resolve(
      body:next,sender:'Alinma',
      bankKind:WaffraBankSmsFactsParser.parse(next).kind,custom:rules);
    expect(suggestion?.category,'فواتير / جوال');
    expect(suggestion?.income,isFalse);
    expect(suggestion?.autoPost,isFalse);
    expect(BankParser.parse(next).amount,315);
  });

  test('M636 automatic SMS review and editor still use latest learned rules',(){
    final src=readWaffraMainSourceForContracts();
    final review=src.substring(src.indexOf(' Future<void> _reviewAutoSmsCandidates('),
     src.indexOf(' void _receiveSharedSms('));
    final editor=src.substring(src.indexOf(' Future<void> entrySheet('),
     src.indexOf(' Future<void> showReceipt('));
    expect(review,contains('await _learnSafeSmsRule('));
    expect(review,contains('bankSmsHash(body)'));
    expect(editor,contains('WaffraSmsLocalRules.resolve(body:initialSms,'));
    expect(editor,contains('userConfirmed:true'));
    expect(review,isNot(contains('_refreshAutoSmsInbox(importMonth:true)')));
    expect(src,isNot(contains('Future<void> bulkSmsSheet(')));
  });
}

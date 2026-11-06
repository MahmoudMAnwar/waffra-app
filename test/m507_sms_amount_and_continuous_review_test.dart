import 'dart:io';

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
    expect(approved.accountId,isNull);
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

  test('M507-02 source editor reloads rules for each next SMS', () {
    final src=File('lib/main.dart').readAsStringSync();
    final start=src.indexOf(' Future<void> bulkSmsSheet(');
    final end=src.indexOf(' Future<void> _previewForeignBankCurrency(');
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final sheet=src.substring(start,end);
    expect(sheet,contains('final inferred=WaffraSmsLocalRules.resolve('));
    expect(sheet,contains('.read(_smsRuleOwnerKey)'));
    expect(sheet,contains('category=suggested??learned??'));
    expect(sheet,contains('_refreshAutoSmsInbox(importMonth:true)'));
    // Do not auto-post inferred SMS: every next item still uses the
    // explicitly reviewed, verified source commit path.
    expect(sheet,contains('userConfirmed:true'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_bank_sms_facts.dart';
import 'package:waffra/waffra_category_catalog.dart';
import 'package:waffra/waffra_sms_local_rules.dart';

void main() {
  final all=WaffraSmsLocalRules.allDefaultRules;
  final sa=all.where((rule)=>rule.id.startsWith('sa_')).toList();

  test('M508 has bilingual built-in defaults for four distinct buckets', () {
    expect(sa.length,177);
    expect(sa.where((r)=>r.resolvedKind=='income'),hasLength(53));
    expect(sa.where((r)=>r.resolvedKind=='expense'),hasLength(102));
    expect(sa.where((r)=>r.resolvedKind=='transfer'),hasLength(8));
    expect(sa.where((r)=>r.resolvedKind=='excluded'),hasLength(14));
    expect(sa.fold<int>(0,(n,r)=>n+r.keywords.length),793);
    expect(sa.expand((r)=>r.keywords).any(
      (w)=>RegExp(r'[\u0621-\u064a]').hasMatch(w)),isTrue);
    expect(sa.expand((r)=>r.keywords).any(
      (w)=>RegExp(r'[a-zA-Z]').hasMatch(w)),isTrue);
    expect(sa.map((r)=>r.id).toSet(),hasLength(sa.length));
    expect(sa.every((r)=>r.builtIn&&!r.autoPost&&r.sender.isEmpty&&
      r.accountId.isEmpty&&r.accountSuffix.isEmpty&&
      r.keywords.isNotEmpty&&!r.matchAll),isTrue);
  });

  test('M508 financial seeds map to real child catalog categories', () {
    final allowed={
      for(final group in waffraCategoryCatalog)
        for(final sub in group.subcategories)
          '${group.income}|${group.name} / $sub',
    };
    for(final rule in sa.where((r)=>r.financial)) {
      expect(allowed,contains('${rule.income}|${rule.category}'),
        reason:rule.id);
    }
    expect(sa.where((r)=>!r.financial).every(
      (r)=>r.category.isEmpty),isTrue);
  });

  test('M508 no seed contains secret values or payment digits', () {
    for(final rule in sa) {
      for(final term in rule.keywords) {
        expect(RegExp(r'[0-9٠-٩۰-۹]|@|\\*|#').hasMatch(term),isFalse,
          reason:'${rule.id}: $term');
      }
    }
  });

  test('M508 salary and expense direction are independent bank evidence', () {
    const salary='إيداع راتب\nالمبلغ: 8500 ريال\nإلى: **4281';
    const groceries='شراء\nالمبلغ: 236 ريال\nمن: أسواق العثيم';
    const netflix='Card Purchase SAR 65.00 Netflix Subscription';
    expect(WaffraSmsLocalRules.resolve(
      body:salary,sender:'Bank',
      bankKind:WaffraBankSmsFactsParser.parse(salary).kind)?.category,
      'راتب / راتب أساسي');
    expect(WaffraSmsLocalRules.resolve(
      body:groceries,sender:'Bank',
      bankKind:WaffraBankSmsFactsParser.parse(groceries).kind)?.category,
      'بقالة وتموين / سوبرماركت');
    expect(WaffraSmsLocalRules.resolve(
      body:netflix,sender:'Bank',
      bankKind:WaffraBankSmsFactsParser.parse(netflix).kind)?.category,
      'اشتراكات رقمية / بث أفلام');
    expect(WaffraSmsLocalRules.resolve(
      body:groceries,sender:'Bank',
      bankKind:WaffraBankOperationKind.income),isNull);
  });

  test('M508 supports Arabic and English transfer review only', () {
    for(final text in <String>[
      'حوالة دولية صادرة بقيمة 300 ريال',
      'Internal Transfer SAR 500 from ***1234 to ***5678',
      'Outgoing Transfer SAR 140 to beneficiary',
    ]) {
      final rule=WaffraSmsLocalRules.resolveSpecial(
        body:text,sender:'Bank',
        bankKind:WaffraBankOperationKind.transfer);
      expect(rule?.resolvedKind,'transfer',reason:text);
      expect(rule?.financial,isFalse);
      expect(rule?.autoPost,isFalse);
      expect(WaffraSmsLocalRules.resolve(
        body:text,sender:'Bank',
        bankKind:WaffraBankOperationKind.transfer),isNull);
    }
  });

  test('M508 exclusions are hints only and never target an expense', () {
    for(final text in <String>[
      'رمز التحقق الخاص بك لإتمام العملية',
      'Your verification code for the app',
      'New login detected on your account',
      'Promotional offer for loyal clients',
    ]) {
      final rule=WaffraSmsLocalRules.resolveSpecial(
        body:text,sender:'Bank',
        bankKind:WaffraBankOperationKind.uncertain);
      expect(rule?.resolvedKind,'excluded',reason:text);
      expect(rule?.autoPost,isFalse);
    }
    expect(WaffraSmsLocalRules.resolveSpecial(
      body:'Card Purchase SAR 75.00 OTP verification code',
      sender:'Bank',bankKind:WaffraBankOperationKind.expense),isNull);
    expect(WaffraSmsLocalRules.resolve(
      body:'Card Purchase declined SAR 42.50 at Netflix',
      sender:'Bank',bankKind:WaffraBankOperationKind.expense),isNull);
    final source=File('lib/main.dart').readAsStringSync();
    expect(source,contains("local['defaultSeed']!=true"));
    expect(source,contains("'defaultSeed':special.builtIn"));
  });

  test('M508 encrypted user learning remains independent from seed rules', () {
    const custom=WaffraSmsLocalRule(
      id:'manual_user_custom',name:'My regular shop',
      keywords:['my shop'],income:false,
      category:'تسوّق / تسوق إلكتروني',
      kind:'expense',matchAll:false);
    final picked=WaffraSmsLocalRules.resolve(
      body:'Card Purchase SAR 10 at my shop and Netflix',
      sender:'Bank',bankKind:WaffraBankOperationKind.expense,
      custom:const [custom]);
    expect(picked?.id,custom.id);
    expect(picked?.autoPost,isFalse);
  });
}

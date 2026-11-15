import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_multicurrency_review.dart';
import 'package:waffra/waffra_sms_structured_bank_context.dart';
import 'package:waffra/waffra_sms_lifecycle_evidence.dart';

void main() {
  test('M989 standalone reference ABC12345 does not become unknown ISO', () {
    const sms = 'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345';
    expect(WaffraSmsCurrencies.currenciesForMessage(sms), {'SAR'});
    final parsed = WaffraSmsStructuredBankContext.parse(
      sms, sender: 'AlRajhi');
    expect(parsed.principalSar, 100);
    expect(WaffraSmsLifecycleEvidence.inspect(
      sms, sender: 'AlRajhi').stage, WaffraSmsLifecycleStage.posted);
  });

  test('M989 unknown ISO currency on financial clause still fails closed', () {
    const sms = 'Purchase Card 100 SAR; Purchase 50 MXN\n'
        'Ref: ABC12345';
    expect(WaffraSmsCurrencies.currenciesForMessage(sms), {'SAR', 'UNKNOWN'});
    expect(WaffraSmsCurrencies.originalAmount(sms), isNull);
    expect(WaffraSmsStructuredBankContext.parse(
      sms, sender:'AlRajhi').principalSar, isNull);
  });

  test('M989 account ID and payment on SAME clause cannot hide currency', () {
    const sms = 'Ref: ABC12345 Purchase 50 MXN';
    expect(WaffraSmsCurrencies.currenciesForMessage(sms), {'UNKNOWN'});
  });

  test('M989 labelled Arabic reference does not add fake currency', () {
    const sms = 'شراء 30 SAR\nرقم المرجع: ABC12345';
    expect(WaffraSmsCurrencies.currenciesForMessage(sms), {'SAR'});
  });

  test('M989 pending then posted strict same bank key stays advisory only', () {
    final index = WaffraSmsRelatedEventIndex();
    final pending = WaffraSmsLifecycleEvidence.inspect(
      'Pending Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
      sender: 'AlRajhi');
    final posted = WaffraSmsLifecycleEvidence.inspect(
      'Purchase Card 100 SAR\nAccount: **1234\nRef: ABC12345',
      sender: 'AlRajhi');
    expect(pending.relationKey, isNotNull);
    expect(posted.relationKey, pending.relationKey);
    expect(index.inspectAndRemember(pending), WaffraSmsRelatedEvent.none);
    expect(index.inspectAndRemember(posted),
      WaffraSmsRelatedEvent.possibleSettlement);
  });
}

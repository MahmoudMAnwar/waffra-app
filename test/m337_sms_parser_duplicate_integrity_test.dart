import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_intelligence.dart';

void main() {
  test('M337 SMS ML parser has one well-formed classifier and no dangling code', () {
    final source = File('lib/waffra_sms_intelligence.dart').readAsStringSync();
    expect(RegExp(r'class _TinySmsIntentBayes\b').allMatches(source).length, 1);
    expect(RegExp(r'abstract final class WaffraSmsIntelligence\b')
        .allMatches(source).length, 1);
    expect(source, isNot(contains('\n,\n      multiLine:true')));
    expect(source.trimRight().endsWith('}'), isTrue);
  });

  test('M337 non-financial or pending SMS must never authorize a ledger write', () {
    for (final sample in <String>[
      'Your OTP is 123456. Do not share it.',
      'Balance: SAR 1,500.00. No debit.',
      'Your credit card was approved for a limit of SAR 30,000.',
      'Payment of SAR 20.00 is pending confirmation',
    ]) {
      final result = WaffraSmsIntelligence.classify(sample);
      expect(result.canAutoSuggestSar, isFalse, reason: sample);
    }
  });

  test('M337 same action across currencies is not a SAR finance approval', () {
    for (final sample in <String>[
      'AED debited from account 136.00 ending with 1001. Balance: 4857.96 AED',
      'Purchase EUR 42.50. Balance: EUR 900.00',
      'Received USD 10.00. Balance: USD 100.00',
    ]) {
      final result = WaffraSmsIntelligence.classify(sample);
      expect(result.canAutoSuggestSar, isFalse, reason: sample);
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_auto_sms.dart';

void main() {
  test('M520 native SMS bridge methods appear exactly once', () {
    final source = File('lib/waffra_auto_sms.dart').readAsStringSync();
    const names = <String>[
      'excludedSenders',
      'excludedMessages',
      'restoreExcludedMessage',
      'excludeMessages',
      'transferIdForMessage',
      'acknowledgeCompletedTransfer',
      'acknowledgeCommitted',
      'acknowledge',
      'notifyCommitted',
      'notifyReview',
    ];
    for (final name in names) {
      final methods = RegExp('\\bstatic (?:Future|String)[^\\n]*? '
          '$name\\(').allMatches(source);
      expect(methods.length, 1, reason: 'Missing or duplicated $name');
    }
    for (final nativeMethod in <String>[
      'excludedAutoSmsMessages',
      'restoreExcludedAutoSmsMessage',
      'excludeAutoBankSms',
      'ackCompletedTransferAutoBankSms',
      'ackCommittedAutoBankSms',
    ]) {
      expect(source.contains("'$nativeMethod'"), isTrue,
          reason: 'Native channel action is missing: $nativeMethod');
    }
    // A previous string substitution expanded a trailing Dart regex
    // dollar-sign into repeated copies of the rest of this entire file.
    expect(source.contains("r'^[a-f0-9]{64}\n"), isFalse);
    expect(RegExp(r'^abstract final class WaffraAutoSms \\{', multiLine: true)
        .allMatches(source).length, 1);
    expect(source.trimRight().endsWith('}'), isTrue);
  });

  test('M520 SMS transfer ID uses the full validated native fingerprint', () {
    final a = List<String>.filled(64, 'a').join();
    final b = List<String>.filled(64, 'b').join();
    expect(WaffraAutoSms.transferIdForMessage(a), 'sms-transfer-$a');
    expect(WaffraAutoSms.transferIdForMessage(b), 'sms-transfer-$b');
    expect(WaffraAutoSms.transferIdForMessage(a),
        isNot(WaffraAutoSms.transferIdForMessage(b)));
    expect(() => WaffraAutoSms.transferIdForMessage('not-an-id'),
        throwsArgumentError);
    expect(() => WaffraAutoSms.transferIdForMessage(a.toUpperCase()),
        throwsArgumentError);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_review_groups.dart';

/// M973 / #671: review-window ownership only; no native SMS or finance posts.
void main() {
  Map<String, Object?> sms(String id, String sender, int at) =>
      <String, Object?>{'id': id, 'sender': sender, 'receivedAt': at};

  test('M973 duplicate legacy ID is removed from every owning sender group', () {
    final original = <Map<String, Object?>>[
      sms('same', 'Alpha', 10),
      sms('same', 'beta', 11),
      sms('keep', ' ALPHA ', 9),
      sms('other', 'beta', 8),
    ];
    final grouped = WaffraSmsReviewGroups.from(
      original, unknownSender: 'Unknown');
    expect(grouped.senders, <String>['Alpha', 'beta']);
    expect(grouped.bySender['Alpha']!.length, 2);
    expect(grouped.removeReviewedId('same'), isTrue);
    expect(grouped.bySender['Alpha']!.map((r) => r['id']), ['keep']);
    expect(grouped.bySender['beta']!.map((r) => r['id']), ['other']);
    expect(grouped.senders, <String>['Alpha', 'beta']);
    // Group changes never mutate the input/native pending queue.
    expect(original.length, 4);
    expect(original.where((r) => r['id'] == 'same').length, 2);
  });

  test('M973 removing last ID drops the empty sender but not adjacent groups',
      () {
    final grouped = WaffraSmsReviewGroups.from(<Map<String, Object?>>[
      sms('a', 'A', 1),
      sms('b', 'B', 2),
      sms('c', ' B ', 3),
    ], unknownSender: 'Unknown');
    expect(grouped.removeReviewedId('a'), isTrue);
    expect(grouped.bySender.containsKey('A'), isFalse);
    expect(grouped.senders, <String>['B']);
    expect(grouped.bySender['B']!.length, 2);
    expect(grouped.removeReviewedId('a'), isFalse);
    expect(grouped.removeReviewedId('not-present'), isFalse);
  });

  test('M973 2000 pending SMS retain all other groups and chronological order',
      () {
    final source = List<Map<String, Object?>>.generate(2000, (i) =>
        sms('sms-$i', 'Sender ${i ~/ 20}', i), growable: false);
    final grouped = WaffraSmsReviewGroups.from(
      source, unknownSender: 'Unknown');
    expect(grouped.senders.length, 100);
    final untouched = grouped.bySender['Sender 51']!;
    final previousOrder = untouched.map((e) => e['id']).toList();
    expect(grouped.removeReviewedId('sms-1000'), isTrue);
    expect(grouped.bySender['Sender 50']!.length, 19);
    expect(grouped.bySender['Sender 51'], same(untouched));
    expect(grouped.bySender['Sender 51']!.map((r) => r['id']),
        previousOrder);
    expect(grouped.bySender.values.fold<int>(0, (n, rows) => n + rows.length),
        1999);
    expect(source.length, 2000);
  });

  test('M973 verified UI single review uses indexed cleanup, bulk stays intact',
      () {
    final source = File('lib/waffra_home_sms_inbox.part.dart')
        .readAsStringSync();
    final from = source.indexOf(
        "if(!_autoSmsPending.any((row)=>row['id']==id)){");
    final to = source.indexOf('selectedIds.remove(id);', from);
    expect(from, greaterThanOrEqualTo(0));
    expect(to, greaterThan(from));
    final single = source.substring(from, to);
    expect(single, contains('grouped.removeReviewedId(id);'));
    expect(single, isNot(contains('for(final group in bySender.values)')));
    // Bulk native exclusion retains existing encrypted batch workflow.
    expect(source, contains('WaffraAutoSms.excludeMessages(batch)'));
    expect(source, contains('WaffraAutoSms.excludeSenders('));
    expect(source, contains('refreshReviewIds();'));
  });
}

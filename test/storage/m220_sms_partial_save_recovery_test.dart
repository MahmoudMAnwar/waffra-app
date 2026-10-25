import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_sms_partial_save_recovery.dart';

void main() {
  test('M220 56 saved and 13 not saved remain exactly reviewable', () {
    final messages = List<String>.generate(69, (i) => 'synthetic SMS $i');
    final result = WaffraSmsPartialSaveRecovery.reconcile(
      discovered: messages,
      rejectedBeforeCommit: {
        for (var i = 56; i < 65; i++)
          i: WaffraSmsNotSavedReason.amountUnrecognized,
        for (var i = 65; i < 69; i++)
          i: WaffraSmsNotSavedReason.categoryUnresolved,
      },
      proposedSourceIndexes: List<int>.generate(56, (i) => i),
      proposedIds: List<String>.generate(56, (i) => 'id-$i'),
      persistedIds: {
        for (var i = 0; i < 56; i++) 'id-$i',
      },
    );
    expect(result.saved, 56);
    expect(result.unsaved.length, 13);
    expect(result.unsaved.first.sourceIndex, 56);
    expect(result.unsaved.last.sourceIndex, 68);
    expect(result.unsaved.every((item) => item.message.startsWith('synthetic')), isTrue);
  });

  test('M220 writer-skipped duplicate has original source and reason', () {
    final result = WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['synthetic A', 'synthetic B', 'synthetic C'],
      rejectedBeforeCommit: const {
        1: WaffraSmsNotSavedReason.amountUnrecognized,
      },
      proposedSourceIndexes: const [0, 2],
      proposedIds: const ['id-A', 'id-C'],
      persistedIds: const {'id-A'},
    );
    expect(result.saved, 1);
    expect(result.unsaved.map((e) => e.sourceIndex), [1, 2]);
    expect(result.unsaved.last.reason, WaffraSmsNotSavedReason.alreadySaved);
    expect(result.unsaved.last.message, 'synthetic C');
  });

  test('M220 user-skipped duplicate remains a review option', () {
    final result = WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['first', 'second'],
      rejectedBeforeCommit: const {
        1: WaffraSmsNotSavedReason.alreadySaved,
      },
      proposedSourceIndexes: const [0],
      proposedIds: const ['id-1'],
      persistedIds: const {'id-1'},
    );
    expect(result.saved, 1);
    expect(result.unsaved.single.message, 'second');
  });

  test('M220 refuses to hide unaccounted bank messages', () {
    expect(() => WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['one', 'two'],
      rejectedBeforeCommit: const {},
      proposedSourceIndexes: const [0],
      proposedIds: const ['id-1'],
      persistedIds: const {'id-1'},
    ), throwsStateError);
  });

  test('M220 refuses overlapping rejected and proposed source', () {
    expect(() => WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['one'],
      rejectedBeforeCommit: const {
        0: WaffraSmsNotSavedReason.alreadySaved,
      },
      proposedSourceIndexes: const [0],
      proposedIds: const ['id-1'],
      persistedIds: const {},
    ), throwsStateError);
  });

  test('M220 refuses duplicate candidate IDs', () {
    expect(() => WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['one', 'two'],
      rejectedBeforeCommit: const {},
      proposedSourceIndexes: const [0, 1],
      proposedIds: const ['same', 'same'],
      persistedIds: const {'same'},
    ), throwsStateError);
  });

  test('M220 rejects over 100 messages rather than silently truncating', () {
    expect(() => WaffraSmsPartialSaveRecovery.reconcile(
      discovered: List<String>.filled(101, 'synthetic'),
      rejectedBeforeCommit: const {},
      proposedSourceIndexes: const [],
      proposedIds: const [],
      persistedIds: const {},
    ), throwsStateError);
  });

  test('M220 complete durable commit produces no retry list', () {
    final result = WaffraSmsPartialSaveRecovery.reconcile(
      discovered: const ['one', 'two'],
      rejectedBeforeCommit: const {},
      proposedSourceIndexes: const [0, 1],
      proposedIds: const ['a', 'b'],
      persistedIds: const {'a', 'b'},
    );
    expect(result.saved, 2);
    expect(result.unsaved, isEmpty);
  });
}

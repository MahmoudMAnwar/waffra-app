import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_recurring_policy.dart';

/// M86 independent pure scheduler QA. A schedule never posts money by itself.
void main() {
  test('M86 day 31 correctly clamps for 30-day months and leap February',
      () {
    expect(WaffraRecurringPolicy.dueDate(2026, 4, 31),
        DateTime(2026, 4, 30));
    expect(WaffraRecurringPolicy.dueDate(2027, 2, 31),
        DateTime(2027, 2, 28));
    expect(WaffraRecurringPolicy.dueDate(2028, 2, 31),
        DateTime(2028, 2, 29));
    expect(WaffraRecurringPolicy.dueDate(2026, 12, 31),
        DateTime(2026, 12, 31));
  });

  test('M86 future recurring charges remain pending until due date', () {
    final due = DateTime(2026, 11, 15);
    final start = DateTime(2026, 11, 1);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: DateTime(2026, 11, 14),
      startAt: start, alreadyPaid: false,
    ), isFalse);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: due,
      startAt: start, alreadyPaid: false,
    ), isTrue);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: due,
      startAt: start, alreadyPaid: true,
    ), isFalse);
  });

  test('M86 postponement and prior-start dates cannot double charge', () {
    final due = DateTime(2026, 11, 15);
    final postpone = DateTime(2026, 11, 21);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: due, startAt: DateTime(2026, 11, 1),
      alreadyPaid: false, postponedUntil: postpone,
    ), isFalse);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: postpone, startAt: DateTime(2026, 11, 1),
      alreadyPaid: false, postponedUntil: postpone,
    ), isTrue);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: due, today: postpone, startAt: DateTime(2026, 11, 1),
      alreadyPaid: true, postponedUntil: postpone,
    ), isFalse);
    expect(WaffraRecurringPolicy.isOutstanding(
      due: DateTime(2026, 10, 20), today: postpone,
      startAt: DateTime(2026, 11, 1), alreadyPaid: false,
    ), isFalse);
  });

  test('M86 stable recurring identities differ across months', () {
    expect(WaffraRecurringPolicy.entryId('rent', DateTime(2026, 11, 1)),
        WaffraRecurringPolicy.entryId('rent', DateTime(2026, 11, 30)));
    expect(WaffraRecurringPolicy.entryId('rent', DateTime(2026, 11, 1)),
        isNot(WaffraRecurringPolicy.entryId('rent', DateTime(2026, 12, 1))));
  });

  test('M86 Riyal halala rounding is deterministic for recurring net', () {
    expect(WaffraRecurringPolicy.toHalalas(84.72), 8472);
    expect(WaffraRecurringPolicy.toHalalas(0.1), 10);
    expect(WaffraRecurringPolicy.toHalalas(0.2), 20);
    expect(WaffraRecurringPolicy.netHalalas(
      [1000.25, 0.1, 0.2], [84.72, 15.28],
    ), 90055);
  });
}

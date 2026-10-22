import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_receipt_screen_contract.dart';
import 'package:waffra/waffra_verified_receipt_panel.dart';

class _FakeVerifiedPort implements WaffraReceiptScreenPort {
  _FakeVerifiedPort()
      : active = WaffraReceiptScreenState(
          entryId: 'synthetic-entry', generation: 1,
          images: [Uint8List.fromList([10, 20, 30])],
        );

  late WaffraReceiptScreenState active;
  int loads = 0, removals = 0, restores = 0;
  bool failNext = false;

  @override
  Future<WaffraReceiptScreenState> load(String entryId) async {
    loads++;
    if (failNext) {
      failNext = false;
      throw StateError('source unavailable');
    }
    if (entryId != active.entryId) throw StateError('wrong owner');
    return active;
  }

  @override
  Future<WaffraReceiptScreenState> moveToRecycle({
    required WaffraReceiptScreenState baseline,
    required bool userConfirmed,
    required DateTime now,
  }) async {
    if (!userConfirmed || baseline.generation != active.generation) {
      throw StateError('Unconfirmed or stale');
    }
    removals++;
    active = WaffraReceiptScreenState(
      entryId: baseline.entryId,
      generation: baseline.generation + 1,
      images: const [],
      recoverUntilMs: now.add(const Duration(days: 30))
          .millisecondsSinceEpoch,
    );
    return active;
  }

  @override
  Future<WaffraReceiptScreenState> restore({
    required WaffraReceiptScreenState baseline,
    required DateTime now,
  }) async {
    if (baseline.generation != active.generation ||
        !baseline.isInRecycleBin) {
      throw StateError('Not a recoverable archive');
    }
    restores++;
    active = WaffraReceiptScreenState(
      entryId: baseline.entryId,
      generation: baseline.generation + 1,
      images: [Uint8List.fromList([10, 20, 30])],
    );
    return active;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 23);

  Future<void> showPanel(
    WidgetTester tester, _FakeVerifiedPort port,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WaffraVerifiedReceiptPanel(
            port: port,
            entryId: 'synthetic-entry',
            english: true,
            clock: () => now,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('M119 cancel never deletes confirmed image', (tester) async {
    final port = _FakeVerifiedPort();
    await showPanel(tester, port);
    expect(find.byKey(const Key('verified-encrypted-receipt-pages')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const Key('move-encrypted-receipts-to-trash')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(port.removals, 0);
    expect(port.active.hasActiveImages, true);
  });

  testWidgets('M119 confirmation commits before showing encrypted trash',
      (tester) async {
    final port = _FakeVerifiedPort();
    await showPanel(tester, port);
    await tester.tap(find.byKey(
        const Key('move-encrypted-receipts-to-trash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(
        const Key('confirm-encrypted-receipt-recycle')));
    await tester.pumpAndSettle();
    expect(port.removals, 1);
    expect(port.active.isInRecycleBin, true);
    expect(find.byKey(const Key('restore-encrypted-receipts')),
        findsOneWidget);
    expect(find.byKey(const Key('verified-encrypted-receipt-pages')),
        findsNothing);
    await tester.tap(find.byKey(const Key('restore-encrypted-receipts')));
    await tester.pumpAndSettle();
    expect(port.restores, 1);
    expect(find.byKey(const Key('verified-encrypted-receipt-pages')),
        findsOneWidget);
  });

  testWidgets('M119 unavailable source never shows fake success',
      (tester) async {
    final port = _FakeVerifiedPort()..failNext = true;
    await showPanel(tester, port);
    expect(find.byKey(const Key('verified-receipt-error')), findsOneWidget);
    expect(find.byKey(const Key('verified-encrypted-receipt-pages')),
        findsNothing);
    await tester.tap(find.byKey(const Key('refresh-encrypted-receipts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('verified-encrypted-receipt-pages')),
        findsOneWidget);
    expect(port.loads, 2);
  });

  test('M119 captured image buffers cannot be changed by original caller', () {
    final source = Uint8List.fromList([1, 2, 3]);
    final screen = WaffraReceiptScreenState(
      entryId: 'e', generation: 0, images: [source],
    );
    source[0] = 255;
    expect(screen.images.single, [1, 2, 3]);
    expect(screen.imageSha256.single, hasLength(64));
    expect(() => WaffraReceiptScreenState(
      entryId: 'e', generation: 0,
      images: [Uint8List.fromList([1])], recoverUntilMs: 1,
    ), throwsStateError);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_new_account_dialog.dart';

/// M1042 / #773 — the real Create account button must not be blocked by
/// a bank-only SMS suggestion that is invisible on a digital-wallet form.
void main() {
  const save = Key('m470-new-account-save');
  const kind = Key('m470-new-account-kind');
  const suffix = Key('m470-new-account-last-four');
  const provider = Key('m470-new-account-provider');
  const opening = Key('m470-new-account-opening');

  Future<void> openWallet(WidgetTester tester,
      ValueChanged<WaffraNewAccountDraft?> onResult) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: Builder(builder: (context) => FilledButton(
        onPressed: () async {
          final draft = await showDialog<WaffraNewAccountDraft>(
            context: context,
            builder: (_) => const WaffraNewAccountDialog(
              english: true,
              suggestedProviderId: 'alinmapay',
              suggestedSenderName: 'AlinmaPay',
              // Source bank account/card identity can be inferred from SMS,
              // but is not an editable field on a wallet.
              suggestedLastFour: '6314',
            ),
          );
          onResult(draft);
        },
        child: const Text('Create wallet'),
      )),
    )));
    await tester.tap(find.text('Create wallet'));
    await tester.pumpAndSettle();
  }

  testWidgets('M1042 AlinmaPay SMS wallet with hidden digits saves zero opening',
      (tester) async {
    WaffraNewAccountDraft? result;
    await openWallet(tester, (value) => result = value);
    expect(find.byKey(suffix), findsNothing);
    expect(tester.widget<TextField>(
      find.byKey(const Key('m470-new-account-label'))).controller!.text,
      'AlinmaPay');
    expect(tester.widget<TextField>(find.byKey(opening)).controller!.text, '0');
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNotNull,
      reason: 'A hidden bank suffix must not disable a complete wallet form.');
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.kind, 'wallet');
    expect(result!.providerId, 'alinmapay');
    expect(result!.subtype, 'digital');
    expect(result!.openingMinor, 0);
    expect(result!.lastFour, isNull);
  });

  testWidgets('M1042 AlinmaPay wallet positive opening saves no bank suffix',
      (tester) async {
    WaffraNewAccountDraft? result;
    await openWallet(tester, (value) => result = value);
    await tester.ensureVisible(find.byKey(opening));
    await tester.enterText(find.byKey(opening), '41.25');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNotNull);
    await tester.tap(find.byKey(save));
    await tester.pumpAndSettle();
    expect(result!.openingMinor, 4125);
    expect(result!.lastFour, isNull);
    expect(result!.providerId, 'alinmapay');
  });

  testWidgets('M1042 bank suffix is discarded when switching to wallet',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      WaffraNewAccountDialog(english: true, suggestedProviderId: 'inma',
        suggestedSenderName: 'AlinmaPay', suggestedLastFour: '6314'))));
    expect(tester.widget<TextField>(find.byKey(suffix)).controller!.text, '6314');
    await tester.tap(find.byKey(kind));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digital wallet').last);
    await tester.pumpAndSettle();
    expect(find.byKey(suffix), findsNothing);
    await tester.tap(find.byKey(provider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإنماء باي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('m470-new-account-subtype')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digital wallet').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNotNull);
    await tester.tap(find.byKey(kind));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank account').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(suffix)).controller!.text, isEmpty,
      reason: 'Returning to a bank must not resurrect the previous card.');
  });

  testWidgets('M1042 bank still enforces exactly four typed suffix digits',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      WaffraNewAccountDialog(english: true, suggestedProviderId: 'inma',
        suggestedSenderName: 'AlinmaPay', suggestedLastFour: '6314'))));
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNotNull);
    await tester.ensureVisible(find.byKey(suffix));
    await tester.enterText(find.byKey(suffix), '12');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
    await tester.enterText(find.byKey(suffix), '1234');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNotNull);
    await tester.enterText(find.byKey(opening), '-1');
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(save)).onPressed, isNull);
  });
}

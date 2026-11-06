import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_new_account_dialog.dart';

void main() {
  testWidgets('M483 bank SMS suggested suffix is visible but editable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraNewAccountDialog(
        english: true,
        suggestedProviderId: 'inma',
        suggestedSenderName: 'AlinmaPay',
        suggestedLastFour: '8308',
      )),
    ));
    final suffix = tester.widget<TextField>(
      find.byKey(const Key('m470-new-account-last-four')));
    expect(suffix.controller!.text, '8308');
    expect(find.text('AlinmaPay'), findsWidgets);
    await tester.enterText(
      find.byKey(const Key('m470-new-account-last-four')), '4702');
    await tester.pump();
    expect(suffix.controller!.text, '4702');
  });

  testWidgets('M483 ambiguous/non-four-digit SMS suffix is not prefilled',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: WaffraNewAccountDialog(
        english: true,
        suggestedProviderId: 'inma',
        suggestedSenderName: 'AlinmaPay',
        suggestedLastFour: '123456',
      )),
    ));
    expect(tester.widget<TextField>(
      find.byKey(const Key('m470-new-account-last-four')))
      .controller!.text, isEmpty);
  });
}

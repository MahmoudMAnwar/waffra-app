import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_account_transaction_form.dart';
import 'package:waffra/waffra_home_accounts_sheet.dart';

void main() {
  const accounts = [
    WaffraAccountBalance('bank-1', 'الراجحي الجاري', 'bank', 200000, false),
    WaffraAccountBalance('cash-1', 'نقدي', 'cash', 5000, false),
  ];

  testWidgets('M470 account selector never offers unassigned as a choice', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: WaffraHomeAccountsSheet(accounts: accounts, selected: 'all', english: false),
    )));
    expect(find.byKey(const Key('m467-account-choice-all')), findsOneWidget);
    expect(find.byKey(const Key('m467-account-choice-bank-1')), findsOneWidget);
    expect(find.byKey(const Key('m467-account-choice-cash-1')), findsOneWidget);
    expect(find.byKey(const Key('m467-account-choice-none')), findsNothing);
    expect(find.textContaining('بدون حساب'), findsNothing);
  });

  testWidgets('M470 SMS transfer retains its dated money instruction and stable request ID',
      (tester) async {
    WaffraInternalTransferDraft? sent;
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: WaffraAccountTransactionForm(
        accounts: accounts,
        initialOperation: WaffraAccountOperation.transfer,
        initialSmsTransfer: const WaffraInternalTransferDraft(
          requestId: 'sms-stable-123',
          fromId: 'bank-1',
          toId: 'cash-1',
          occurredIso: '2026-11-02T10:30:00',
          amountMinor: 12500,
          memo: 'reviewed transfer',
        ),
        onConfirmTransfer: (draft) async { sent = draft; },
      ),
    )));
    expect(find.byKey(const Key('m470-transfer-date')), findsOneWidget);
    expect(find.textContaining('02/11/2026'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('m440-confirm')));
    await tester.tap(find.byKey(const Key('m440-confirm')));
    await tester.pumpAndSettle();
    expect(sent, isNotNull);
    expect(sent!.requestId, 'sms-stable-123');
    expect(sent!.occurredIso, '2026-11-02T10:30:00.000');
    expect(sent!.fromId, 'bank-1');
    expect(sent!.toId, 'cash-1');
  });

  test('M470 home account preferences never re-activate legacy unassigned filter', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains("chosen!='none'")));
    expect(source, isNot(contains("next!='none'")));
    expect(source, isNot(contains("selected=='none'")));
    expect(source, contains("if(chosen!='all'&&"));
    expect(source, contains("chosen=p.getString(_m467ChoiceKey)??'all'"));
    expect(source, contains("item.accountId==selected"));
  });
}

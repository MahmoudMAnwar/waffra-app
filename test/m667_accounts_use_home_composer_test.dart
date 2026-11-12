import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_accounts_manager_page.dart';
import 'package:waffra/waffra_account_transaction_form.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';

/// M667: Home owns the one canonical transaction editor. My Accounts must
/// dispatch to the supplied Home callback rather than pushing a cloned form.
class _AccountsForComposerTest implements WaffraAccountOperations {
  int balanceReads = 0;

  @override
  Future<List<WaffraAccountBalance>> balances() async {
    balanceReads++;
    return const <WaffraAccountBalance>[
      WaffraAccountBalance('m667-a', 'Test current', 'bank', 250000, false),
      WaffraAccountBalance('m667-b', 'Test savings', 'bank', 100000, false),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final english in <bool>[false, true]) {
    testWidgets('M667 My Accounts opens injected Home sheet, not its duplicate '
        '${english ? "English" : "Arabic"}', (tester) async {
      final fake = _AccountsForComposerTest();
      var launches = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (homeContext) => WaffraAccountsManagerPage(
          repository: fake,
          english: english,
          onCreateHomeTransaction: () async {
            launches++;
            await showModalBottomSheet<void>(
              context: homeContext,
              builder: (_) => const SizedBox(
                key: Key('m667-canonical-home-entry-sheet'),
                height: 200,
                child: Text('Same Home sheet'),
              ),
            );
          },
        )),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text(english ? 'New transaction' : 'معاملة جديدة'));
      await tester.pumpAndSettle();

      expect(launches, 1);
      expect(find.byKey(const Key('m667-canonical-home-entry-sheet')),
          findsOneWidget);
      expect(find.byType(WaffraAccountTransactionForm), findsNothing,
          reason: 'My Accounts must not open the older duplicate form');
      expect(fake.balanceReads, 1,
          reason: 'No extra financial reads before Home editor closes');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text(english ? 'My accounts' : 'حساباتي'), findsOneWidget);
      expect(fake.balanceReads, greaterThanOrEqualTo(2),
          reason: 'Verified account balances are reloaded after returning');
      expect(tester.takeException(), isNull);
    });
  }

  test('M667 production Accounts screen delegates to exact Home entrySheet', () {
    final home = File('lib/main.dart').readAsStringSync();
    final accounts =
        File('lib/waffra_accounts_manager_page.dart').readAsStringSync();
    final start = home.indexOf('Future<void> openVerifiedAccounts()async{');
    final end = home.indexOf('Future<void> openVerifiedTransfer()async{', start);
    expect(start, greaterThan(0));
    expect(end, greaterThan(start));
    final route = home.substring(start, end);
    expect(route, contains('WaffraAccountsManagerPage('));
    expect(route, contains('onCreateHomeTransaction:()=>entrySheet()'));
    expect(home, contains('Future<void> entrySheet({MoneyEntry? initial'));
    expect(home, contains('bool transferSelected=false'));
    final compose = accounts.indexOf('Future<void> compose(');
    final build = accounts.indexOf('@override Widget build(', compose);
    expect(compose, greaterThan(0));
    expect(build, greaterThan(compose));
    final body = accounts.substring(compose, build);
    expect(body, contains('await homeComposer();'));
    expect(body, contains('if(mounted)reload();'));
    expect(body.indexOf('return;'),
      lessThan(body.indexOf('WaffraAccountTransactionForm(')),
      reason: 'Home callback path returns before legacy account form opens');
  });
}

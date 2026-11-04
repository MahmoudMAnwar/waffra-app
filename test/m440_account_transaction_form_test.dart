import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_account_transaction_form.dart';

void main() {
 const accounts=<WaffraAccountBalance>[
  WaffraAccountBalance('bank','الراجحي','bank',500000,false),
  WaffraAccountBalance('cash','كاش','cash',200000,false),
 ];

 test('M440 SAR parser requires positive integer halalas, no FX relabel',(){
  expect(waffraSarAmountMinor('1000'),100000);
  expect(waffraSarAmountMinor('12.50'),1250);
  expect(waffraSarAmountMinor('1.2'),120);
  expect(waffraSarAmountMinor('0.01'),1);
  expect(waffraSarAmountMinor('١٠٠٠٫٥٠'),100050);
  expect(waffraSarAmountMinor('۱۲.۵۰'),1250);
  for(final bad in ['','0','0.00','-1','1.234','12SAR','1e3','1,000']){
   expect(waffraSarAmountMinor(bad),isNull,reason:bad);
  }
 });

 test('M440 new account opening balances accept Saudi zero in Arabic and English',(){
  for(final zero in ['0','0.00','٠','٠٫٠٠','۰','۰.۰۰']){
   expect(waffraSarAmountMinor(zero,allowZero:true),0,reason:zero);
   expect(waffraSarAmountMinor(zero),isNull,reason:'transaction rejects zero');
  }
  expect(waffraSarAmountMinor('١٢٫٥٠',allowZero:true),1250);
  expect(waffraSarAmountMinor('-1',allowZero:true),isNull);
 });

 testWidgets('M440 manual form offers three operation types, transfer has both accounts',
  (tester)async{
   await tester.pumpWidget(const MaterialApp(home:Scaffold(body:
    WaffraAccountTransactionForm(accounts:accounts))));
   expect(find.text('دخل'),findsOneWidget);
   expect(find.text('مصروف'),findsOneWidget);
   expect(find.text('تحويل'),findsOneWidget);
   expect(find.text('إلى حساب'),findsNothing);
   await tester.tap(find.text('تحويل'));
   await tester.pumpAndSettle();
   expect(find.text('من حساب'),findsOneWidget);
   expect(find.text('إلى حساب'),findsOneWidget);
   expect(find.textContaining('لا يُحسب دخلًا أو مصروفًا'),findsOneWidget);
 });

 testWidgets('M440 bad/empty transfer must not call the finance writer',
  (tester)async{
   var commits=0;
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:
    WaffraAccountTransactionForm(accounts:accounts,
     onConfirmTransfer:(_ )async{commits++;}))));
   await tester.tap(find.text('تحويل'));
   await tester.pumpAndSettle();
   await tester.tap(find.byKey(const Key('m440-confirm')));
   await tester.pumpAndSettle();
   expect(find.text('أدخل مبلغًا صحيحًا بالريال'),findsOneWidget);
   expect(commits,0);
 });
}

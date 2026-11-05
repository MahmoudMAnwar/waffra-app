import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/waffra_recurring_account_groups.dart';

void main() {
 const accounts=<WaffraAccountBalance>[
  WaffraAccountBalance('r1','الراجحي الجاري','bank',120000,false),
  WaffraAccountBalance('r2','Al Rajhi Savings','bank',20000,false),
  WaffraAccountBalance('s1','الأهلي الجاري','bank',7000,false),
  WaffraAccountBalance('u1','Unrecognized institution','bank',100,false),
  WaffraAccountBalance('u2','Different unknown bank','bank',200,false),
  WaffraAccountBalance('c1','كاش','cash',5000,false),
  WaffraAccountBalance('c2','نقدي المنزل','cash',1000,false),
  WaffraAccountBalance('archived','الراجحي القديم','bank',0,true),
 ];

 test('M470 known bank groups show their separate linked active accounts',(){
  final grouped=WaffraRecurringAccountGroups.fromAccounts(accounts);
  final rajhi=grouped.singleWhere((group)=>group.id=='bank:institution:rajhi');
  expect(rajhi.labelAr,'مصرف الراجحي');
  expect(rajhi.accounts.map((account)=>account.id).toList(),['r1','r2']);
  expect(grouped.singleWhere((g)=>g.id=='bank:institution:snb')
   .accounts.single.id,'s1');
  expect(grouped.expand((g)=>g.accounts).any((a)=>a.id=='archived'),isFalse);
 });

 test('M470 unknown banks must not be guessed into one provider',(){
  final grouped=WaffraRecurringAccountGroups.fromAccounts(accounts);
  expect(grouped.singleWhere((g)=>g.id=='bank:account:u1').accounts.single.id,'u1');
  expect(grouped.singleWhere((g)=>g.id=='bank:account:u2').accounts.single.id,'u2');
  expect(grouped.singleWhere((g)=>g.id=='cash').accounts.length,2);
 });

 test('M470 recurring default chooser requires provider then explicit account',(){
  final source=File('lib/waffra_account_context_settings.dart')
   .readAsStringSync();
  expect(source,contains("labelText:t('الجهة أو البنك','Provider or bank')"));
  expect(source,contains("labelText:t('الحساب المرتبط بالجهة','Linked money account')"));
  expect(source,contains('chosen=null; // Never imply the account from a provider alone.'));
  expect(source,contains('onPressed:chosen!=null&&linked.any((a)=>a.id==chosen)'));
  expect(source,contains('accountId:selection,userConfirmed:true'));
  expect(source,isNot(contains("DropdownMenuItem(value:'none'")));
 });
 test('M470 money form requires an explicit provider before a linked source or destination',(){
  final source=File('lib/waffra_account_transaction_form.dart').readAsStringSync();
  expect(source,contains('WaffraRecurringAccountGroups.fromAccounts(accounts)'));
  expect(source,contains("labelText:tr('الجهة أو البنك','Bank or provider')"));
  expect(source,contains("Key('m470-'+(isDestination?'target':'source')+'-provider-'"));
  expect(source,contains("Key('m470-'+(isDestination?'target':'source')+'-account-'"));
  expect(source,contains('onChanged:saving||saved||group==null?null:onChanged'));
  expect(source,contains('sourceProvider=v;source=null;'));
  expect(source,contains('destinationProvider=v;destination=null;'));
  expect(source,contains('exclude:source,isDestination:true'));
  expect(source,isNot(contains('sourceProvider=_m467SelectedAccount')));
 });
}

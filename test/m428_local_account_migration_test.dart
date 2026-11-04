import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_local_account_migration.dart';

void main(){
 testWidgets('M428 local Google-to-phone migration needs matching password',
  (tester)async{
  var migrated=0;
  await tester.pumpWidget(MaterialApp(home:WaffraLocalAccountMigration(
   english:true,onConfirm:(phone,password)async{migrated++;})));
  await tester.tap(find.byKey(const Key('waffra-migrate-to-local-phone')));
  await tester.pump();
  expect(migrated,0);
  expect(find.textContaining('matching'),findsOneWidget);
 });
 test('M428 preserves legacy profile fields and does not touch ledger',(){
  final s=File('lib/main.dart').readAsStringSync();
  final part=s.substring(s.indexOf(" Widget profilePage(){"),
   s.indexOf("   _accountSection(waffraIsEnglish?'App settings'"));
  expect(part,contains("provider=='google'||provider=='apple'"));
  expect(part,contains('WaffraLocalAccountMigration('));
  expect(part,contains('WaffraLocalPhoneCredentials.register('));
  expect(part,contains('widget.onProfile(Person('));
  expect(part,contains("name:p.name,email:p.email,phone:number"));
  expect(part,contains('gender:p.gender,avatar:p.avatar,birthday:p.birthday'));
  expect(part,isNot(contains('deleteFinance')));
  expect(part,isNot(contains('removeAll')));
 });
}

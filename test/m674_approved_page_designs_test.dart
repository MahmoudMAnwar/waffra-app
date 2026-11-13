import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart' show SavingGoal, RecurringBill;
import 'package:waffra/waffra_approved_page_designs.dart';
import 'package:waffra/storage/waffra_accounts_repository.dart';
import 'package:waffra/storage/waffra_accounts_schema.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M674 encrypted SQLCipher: all approved goal and recurring fields '
     'survive save, edit, cold reopen; invalid account rolls back',()async{
  final directory=await Directory.systemTemp.createTemp('m674-disposable-');
  final path=File(directory.path+'/finance.sqlite');
  const key='m674-synthetic-disposable-sqlcipher-fixture';
  WaffraEncryptedStore? db;
  try{
   db=WaffraEncryptedStore.openAt(path,key:key);
   await WaffraFreshEncryptedVaultBootstrap(
    store:db,experimentalEnabled:true,
   ).initialize(decision:WaffraFirstRunDecision.freshCandidate);
   await WaffraAtomicFinanceSnapshot(
    store:db,experimentalEnabled:true,
   ).initializeEmpty();
   await WaffraAccountsSchema.install(db);
   final accounts=WaffraAccountsRepository(db:db,experimentalEnabled:true);
   await accounts.createAccount(
    id:'m674-bank',name:'Synthetic Account',kind:'bank',
    openingMinor:153900,createdIso:'2026-11-13T10:00:00Z',
    userConfirmed:true);
   final balance=(await accounts.balances())
    .singleWhere((a)=>a.id=='m674-bank').balanceMinor;
   final goal=SavingGoal(
    id:'m674-goal',name:'Synthetic Goal',target:5000,saved:1250,
    active:true,accountId:'m674-bank',
    dueDate:DateTime.parse('2027-05-15T00:00:00.000'),
    progressAlertsEnabled:true,progressAlertPercent:90);
   final schedule=RecurringBill(
    id:'m674-due',title:'Goal Due',category:'أخرى',
    amount:5000,income:false,day:15,active:true,
    startAt:DateTime.parse('2027-05-15T00:00:00.000'),
    linkedGoalId:goal.id,accountId:'m674-bank');
   final modules=WaffraFreshModulesRepository(
    store:db,experimentalEnabled:true);
   await modules.save(WaffraFinanceModule.goals,goal.toJson());
   await modules.save(WaffraFinanceModule.recurring,schedule.toJson());
   expect((await modules.list(WaffraFinanceModule.goals)).single,goal.toJson());
   expect((await modules.list(WaffraFinanceModule.recurring)).single,
    schedule.toJson());
   await modules.save(WaffraFinanceModule.goals,
    {...goal.toJson(),'name':'Edited Goal'},replaceExisting:true);
   await modules.save(WaffraFinanceModule.recurring,
    {...schedule.toJson(),'day':20},replaceExisting:true);
   await expectLater(modules.save(WaffraFinanceModule.recurring,
    {...schedule.toJson(),'accountId':'unknown-account'},replaceExisting:true),
    throwsA(isA<StateError>()));
   expect((await accounts.balances())
    .singleWhere((a)=>a.id=='m674-bank').balanceMinor,balance);
   await db.close();
   db=null;
   db=WaffraEncryptedStore.openAt(path,key:key);
   final cold=WaffraFreshModulesRepository(store:db,experimentalEnabled:true);
   final g=(await cold.list(WaffraFinanceModule.goals)).single;
   final due=(await cold.list(WaffraFinanceModule.recurring)).single;
   expect(g['id'],goal.id);
   expect(g['name'],'Edited Goal');
   expect(g['accountId'],'m674-bank');
   expect(g['target'],goal.target);
   expect(g['saved'],goal.saved);
   expect(g['active'],true);
   expect(g['dueDate'],goal.toJson()['dueDate']);
   expect(g['progressAlertsEnabled'],true);
   expect(g['progressAlertPercent'],90);
   expect(due['id'],schedule.id);
   expect(due['title'],schedule.title);
   expect(due['category'],schedule.category);
   expect(due['amount'],schedule.amount);
   expect(due['income'],false);
   expect(due['day'],20);
   expect(due['active'],true);
   expect(due['startAt'],schedule.toJson()['startAt']);
   expect(due['linkedGoalId'],goal.id);
   expect(due['accountId'],'m674-bank');
   expect((await WaffraAccountsRepository(
    db:db,experimentalEnabled:true).balances())
    .singleWhere((a)=>a.id=='m674-bank').balanceMinor,balance);
   expect((await db.customSelect('PRAGMA foreign_key_check').get()),isEmpty);
  }finally{
   await db?.close();
   if(await directory.exists())await directory.delete(recursive:true);
  }
 });

 test('M674 JSON models retain all IDs and fields; no account invented',(){
  final goal=SavingGoal(id:'g',name:'هدف',target:1200,saved:300,
   accountId:'bank-a',dueDate:DateTime.parse('2027-02-01'),
   progressAlertsEnabled:true,progressAlertPercent:95);
  expect(SavingGoal.fromJson(goal.toJson()).toJson(),goal.toJson());
  expect(SavingGoal.fromJson({...goal.toJson(),'accountId':null}).accountId,isNull);
  final due=RecurringBill(id:'r',title:'ادخار شهري',category:'أخرى',
   amount:500,income:false,day:28,accountId:'bank-a',
   linkedGoalId:'g',startAt:DateTime.parse('2027-01-01'));
  expect(RecurringBill.fromJson(due.toJson()).toJson(),due.toJson());
  expect(RecurringBill.fromJson({...due.toJson(),'accountId':null}).accountId,isNull);
 });

 testWidgets('M674 approved cards render actual metrics in narrow RTL dark mode',
  (tester)async{
  tester.view.physicalSize=const Size(320,720);
  tester.view.devicePixelRatio=1;
  addTearDown((){
   tester.view.resetPhysicalSize();
   tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(MaterialApp(theme:ThemeData.dark(),
   home:Directionality(textDirection:TextDirection.rtl,
    child:Scaffold(body:SingleChildScrollView(child:Column(children:[
     const WaffraApprovedPageHero(title:'الأهداف',
      subtitle:'خطط وادخر',icon:Icons.flag_outlined),
     const WaffraApprovedMetrics(metrics:[
      WaffraApprovedMetric('المدخرات','1,250 ر.س',Icons.account_balance_wallet_outlined),
      WaffraApprovedMetric('نشطة','2',Icons.flag_outlined),
      WaffraApprovedMetric('الإنجاز','25%',Icons.donut_large),
     ]),
     const WaffraApprovedGoalProgressBars(
      title:'تقدم الأهداف الحالي',
      labels:['هدف أ','هدف ب'],progress:[.25,.75]),
    ]))))));
  expect(find.text('1,250 ر.س'),findsOneWidget);
  expect(find.text('25%'),findsOneWidget);
  expect(find.byKey(const Key('m674-real-goal-progress-chart')),
   findsOneWidget);
  expect(tester.takeException(),isNull);
 });

 Widget scene(String message,{bool english=false}){
  final link=LayerLink();
  return MaterialApp(home:Directionality(
   textDirection:english?TextDirection.ltr:TextDirection.rtl,
   child:Scaffold(body:Stack(children:[
    Positioned(left:english?null:16,right:english?16:null,bottom:82,
     child:CompositedTransformTarget(link:link,
      child:const SizedBox(key:Key('m675-fixed-plus'),width:58,height:58))),
    WaffraApprovedFixedFabNoticePosition(
     link:link,english:english,
     child:Material(child:Container(
      key:const Key('m675-snackbar'),padding:const EdgeInsets.all(8),
      child:Text(message,style:const TextStyle(fontSize:13))))),
   ]))));
 }

 testWidgets('M675 Arabic snackbar wraps upward beside stationary left +',
  (tester)async{
  tester.view.physicalSize=const Size(360,700);
  tester.view.devicePixelRatio=1;
  addTearDown((){
   tester.view.resetPhysicalSize();
   tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(scene('تم الحفظ'));
  await tester.pumpAndSettle();
  final plus=tester.getRect(find.byKey(const Key('m675-fixed-plus')));
  final short=tester.getRect(find.byKey(const Key('m675-snackbar')));
  expect(short.left,greaterThanOrEqualTo(plus.right+7));
  expect((short.bottom-plus.bottom).abs(),lessThan(1.0));
  await tester.pumpWidget(scene(
   'رسالة تأكيد طويلة من سطرين أو أكثر ولا تغير موقع زر الإضافة على الإطلاق'));
  await tester.pumpAndSettle();
  final fixed=tester.getRect(find.byKey(const Key('m675-fixed-plus')));
  final long=tester.getRect(find.byKey(const Key('m675-snackbar')));
  expect(fixed,plus);
  expect(long.left,greaterThanOrEqualTo(fixed.right+7));
  expect((long.bottom-fixed.bottom).abs(),lessThan(1.0));
  expect(long.height,greaterThan(short.height));
  expect(tester.takeException(),isNull);
 });

 testWidgets('M675 English snackbar remains left of stationary right +',
  (tester)async{
  tester.view.physicalSize=const Size(360,700);
  tester.view.devicePixelRatio=1;
  addTearDown((){
   tester.view.resetPhysicalSize();
   tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(scene(
   'This long message wraps without moving the add icon',english:true));
  await tester.pumpAndSettle();
  final plus=tester.getRect(find.byKey(const Key('m675-fixed-plus')));
  final snackbar=tester.getRect(find.byKey(const Key('m675-snackbar')));
  expect(snackbar.right,lessThanOrEqualTo(plus.left-7));
  expect((snackbar.bottom-plus.bottom).abs(),lessThan(1.0));
  expect(tester.takeException(),isNull);
 });

 test('M675 immutable + source contract and existing finance write routing',(){
  final code=File('lib/main.dart').readAsStringSync();
  final a=code.indexOf(
   '  // A fixed 58x58 FAB: pop-up menu is an independent body overlay.');
  final b=code.indexOf('  // M675: footer height stays invariant.',a);
  expect(a,greaterThan(0));
  expect(b,greaterThan(a));
  final fab=code.substring(a,b);
  expect(fab,contains('floatingActionButtonLocation:WaffraDirectionalFabLocation'));
  expect(fab,contains('CompositedTransformTarget('));
  expect(fab,contains('width:58,height:58'));
  expect(fab,contains('addFabExpanded=!addFabExpanded'));
  expect(code,contains('WaffraApprovedFixedFabNoticePosition('));
  expect(code,contains(
   'bottomNavigationBar:accountOpened?null:WaffraFooterNavigation('));
  expect(code,isNot(contains(
   'bottomNavigationBar:accountOpened?null:Column(mainAxisSize:MainAxisSize.min')));
  expect(code,contains('fundVerifiedGoal('));
  expect(code,contains('_m665ExplainLinkedGoalEdit()'));
  expect(code,contains('accountId:selectedRecurringAccount'));
 });
}

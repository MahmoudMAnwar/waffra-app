import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';

/// M632: actual pure-worker outputs plus UI/security source regression.
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 final source=File('lib/main.dart').readAsStringSync();
 final review=source.split(
  ' Future<void> _reviewAutoSmsCandidates({String? targetId})async {')[1]
  .split(' void _receiveSharedSms(){')[0];
 final loader=source.split(' Future<void> _loadFinanceSafely()async{')[1]
  .split(' Widget _financialRecoveryScreen()')[0];
 final refresher=source.split(' Future<void> _runAutoSmsRefresh(')[1]
  .split(' Future<void> _scanPreviousBankSmsFromSettings()async{')[0];

 testWidgets('splash is readable until genuine completion, once only',(tester)async{
  var completions=0;
  await tester.pumpWidget(MaterialApp(
   home:WaffraLaunchIntro(onFinished:()=>completions++)));
  await tester.pump(const Duration(milliseconds:300));
  expect(completions,0);
  expect(find.text('Waffra'),findsOneWidget);
  expect(find.text('وفرة'),findsOneWidget);
  await tester.pumpAndSettle(const Duration(milliseconds:100));
  expect(completions,1);
  expect(tester.takeException(),isNull);
 });

 test('root never dismisses animated intro after one frame',(){
  final launch=source.split(' Future<void> launchIntro()async{')[1]
   .split(' @override void didChangeAppLifecycleState(')[0];
  expect(launch,contains('await WidgetsBinding.instance.endOfFrame;'));
  expect(launch,contains('void _m632SplashCompleted(){'));
  expect(launch,contains('setState(()=>introDone=true);'));
  expect(launch.indexOf('setState(()=>introDone=true);'),
   greaterThan(launch.indexOf('void _m632SplashCompleted(){')));
  expect(source,contains('WaffraLaunchIntro(onFinished:_m632SplashCompleted)'));
  expect(source,contains('status==AnimationStatus.completed&&!_completionSent'));
 });

 test('missing first account offers direct creation, independent of categories',(){
  expect(review,contains('final hasActiveMoneyAccount=_m467Accounts.any((a)=>!a.archived);'));
  expect(review,contains("waffraIsEnglish?'Add account':'إضافة حساب'"));
  expect(review,contains('if(choosingAccount)return;'));
  expect(review,isNot(contains('if(!canConfirm||choosingAccount)return;')));
  expect(review,contains('WaffraNewAccountDialog('));
  expect(review,contains('createTypedAccountWithIdentity('));
  expect(review,contains('userConfirmed:true'));
  expect(review,contains('final fresh=await bridge.readVerifiedAccounts();'));
  expect(review,contains('reviewedAccount=(ids:<String?>[pickedId]'));
  expect(review,contains('onPressed:!choosingAccount?'));
  expect(review,contains('onPressed:canConfirm&&reviewedAccount?.ids?.single!=null&&'));
  expect(review,contains('await _m565ConfirmSms('));
  // Placeholder date/amount are only for a never-posted account picker trial.
  expect(review,contains('await reviewSmsAccountLinks([trial],smsSender:sender)'));
 });

 test('real SMS writer still requires original verified fields and anti-replay',(){
  final writer=source.split(' Future<void> _m565ConfirmSms({')[1]
   .split(' Widget _m615ReviewDetail(')[0];
  expect(writer,contains('selectedAccount.generation==null'));
  expect(writer,contains('original.currency!=\'SAR\''));
  expect(writer,contains('bankSmsHasUnverifiedTimestamp(body)'));
  expect(writer,contains('if(smsHashes.contains(hash))'));
  expect(writer,contains('allowDuplicateHashes:false'));
  expect(writer,contains('userConfirmed:true'));
 });

 test('isolate classifier preserves original pending SMS and committed ACK',()async{
  const duplicate='Purchase Card SAR 12.00 at Grocer. Account ending 1234';
  final input=<String,Object?>{
   'results':<Map<String,Object?>>[
    {'id':'dupe','body':duplicate,'sender':'BANK'},
    {'id':'fresh','body':'Your OTP code is 123456.','sender':'BANK'},
    {'id':'new','body':'Purchase SAR 7.00','sender':'BANK'},
   ],
   'rules':<Map<String,Object?>>[],
   'categories':<String>[],
   'hashes':<String>[bankSmsHash(duplicate)],
  };
  final result=await compute(waffraM632ClassifySmsQueue,input);
  final committed=(result['committed'] as List).cast<String>();
  final waiting=(result['waiting'] as List).cast<Map<String,Object?>>();
  final restore=(result['retainOnAckFailure'] as List).cast<Map<String,Object?>>();
  expect(committed,['dupe']);
  // Ready-made verification rules now exclude pending native OTP IDs while
  // never treating a committed hash as a newly excluded SMS.
  expect((result['excluded'] as List).cast<String>(),['fresh']);
  expect(waiting.map((m)=>m['id']),contains('new'));
  expect(waiting.any((m)=>m['id']=='fresh'),isFalse);
  expect(restore.map((m)=>m['id']),containsAll(['dupe','fresh']));
  // Background classification cannot authorize or post an account debit.
  expect(result.keys.toSet(),{'waiting','excluded','committed','retainOnAckFailure'});
 });

 test('large input uses worker without main-isolate message parser loop',()async{
  final sourceQueue=<Map<String,Object?>>[
   for(var i=0;i<120;i++)
    <String,Object?>{'id':'sms-$i','body':'Purchase SAR 6.00 at merchant $i',
      'sender':'BANK'},
  ];
  final result=await compute(waffraM632ClassifySmsQueue,<String,Object?>{
   'results':sourceQueue,
   'rules':<Map<String,Object?>>[],
   'categories':<String>[],
   'hashes':<String>[],
  });
  expect((result['waiting'] as List).length,120);
  expect(refresher,contains('await compute(waffraM632ClassifySmsQueue,'));
  expect(refresher,contains('if(!mounted||!ready||_m627ClosingSession||_financeLoadFailure!=null)return;'));
  expect(refresher,contains('if(!_m630SmsSessionCurrent(smsEpoch))return;'));
  expect(source,contains('epoch==_m630HomeStartupEpoch;'));
  expect(refresher,contains('WaffraAutoSms.pendingChecked()'));
  expect(refresher,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(refresher,contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
  expect(loader.indexOf('await load();'),
   lessThan(loader.indexOf('const Duration(milliseconds:900)')));
  expect(loader,contains('const Duration(milliseconds:1200)'));
  expect(source,contains('_m632SmsNoticeTimer?.cancel();'));
 });

 test('M665.6 ready excluded notices ACK natively, posted finance remains pending',()async{
  final messages=<Map<String,Object?>>[
   {'id':'otp','body':'Your verification code is 123456','sender':'TestBank'},
   {'id':'promo','body':'Promotional offer for loyal customers','sender':'TestBank'},
   {'id':'reminder','body':'payment reminder','sender':'TestBank'},
   {'id':'marketing-discount','body':'خصم حصري اليوم','sender':'TestBank'},
   {'id':'salary-plus-promo','body':'Salary deposit SAR 5000. promo code','sender':'TestBank'},
   {'id':'salary-plus-otp','body':'Salary deposit SAR 5000. OTP code 123456','sender':'TestBank'},
   {'id':'expense-plus-otp','body':'Card Purchase SAR 75.00 OTP verification code 123456','sender':'TestBank'},
   {'id':'credit-plus-promo','body':'تم إيداع 400 ريال. عرض خاص','sender':'TestBank'},
  ];
  final result=await compute(waffraM632ClassifySmsQueue,<String,Object?>{
   'results':messages,'rules':<Map<String,Object?>>[],
   'categories':<String>[], 'hashes':<String>[],
  });
  final excluded=(result['excluded'] as List).cast<String>();
  final waiting=(result['waiting'] as List).cast<Map<String,Object?>>();
  expect(excluded,containsAll(<String>['otp','promo','reminder','marketing-discount']));
  expect(excluded,isNot(contains('salary-plus-promo')));
  expect(excluded,isNot(contains('salary-plus-otp')));
  expect(excluded,isNot(contains('expense-plus-otp')));
  expect(excluded,isNot(contains('credit-plus-promo')));
  expect(waiting.map((row)=>row['id']),
    containsAll(<String>['expense-plus-otp','credit-plus-promo','salary-plus-promo','salary-plus-otp']));
  // An immutable seed doesn't create a money entry or sender-wide block.
  expect(result.keys.toSet(),{'waiting','excluded','committed','retainOnAckFailure'});
  expect((result['committed'] as List),isEmpty);
 });


}

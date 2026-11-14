import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/waffra_sms_review_groups.dart';

/// M548 source and pure-logic tests. These are not release/profile device
/// frame traces; the issue requires an Android signed-APK performance check.
void main() {
 test('1000 unique sender groups are complete without quadratic key search',(){
  final source=List<Map<String,Object?>>.generate(1000,(i)=><String,Object?>{
   'id':'sms-$i','sender':'Bank-$i','receivedAt':i,
  });
  final grouped=WaffraSmsReviewGroups.from(source,
   unknownSender:'مرسل غير محدد');
  expect(grouped.senders.length,1000);
  expect(grouped.bySender.length,1000);
  expect(grouped.bySender.values.expand((items)=>items).length,1000);
  expect(grouped.senders.first,'Bank-0');
  expect(grouped.senders.last,'Bank-999');
  expect(source.first['id'],'sms-0'); // original review queue not mutated
 });

 test('case-insensitive aliases, blank senders and dates retain semantics',(){
  final source=<Map<String,Object?>>[
   {'id':'1','sender':'AlRajhi','receivedAt':100},
   {'id':'2','sender':'alrajhi','receivedAt':300},
   {'id':'3','sender':' ALRAJHI ','receivedAt':200},
   {'id':'4','sender':'','receivedAt':500},
   {'id':'5','sender':'  ','receivedAt':100},
  ];
  final grouped=WaffraSmsReviewGroups.from(source,
   unknownSender:'Unknown sender');
  expect(grouped.senders,['AlRajhi','Unknown sender']);
  expect(grouped.bySender['AlRajhi']!.map((r)=>r['id']).toList(),
   ['2','3','1']);
  expect(grouped.bySender['Unknown sender']!.length,2);
  expect(source.map((r)=>r['id']).toList(),['1','2','3','4','5']);
 });

 test('Home verified review snapshot bypasses unnecessary 1000-SMS reread',(){
  final main=readWaffraMainSourceForContracts();
  final open=main.split(' Future<void> _openAutoSmsInbox()async{')[1]
   .split(' Widget _autoSmsReviewCard(){')[0];
  expect(open,contains('if(!_autoSmsStatusChecked||_autoSmsStatusProblem!=null||'));
  expect(open,contains('await _refreshAutoSmsInbox();'));
  expect(open,contains('if(!mounted||!ready||_autoSmsStatusProblem!=null||'));
  expect(open,contains('WaffraSmsReviewGroups.from(_autoSmsPending'));
  expect(open,isNot(contains('bySender.keys.firstWhere(')));
  // Never turn opening review into a historical reimport/financial posting.
  expect(open,isNot(contains('WaffraAutoSms.importConsentMonth(')));
  expect(open,isNot(contains('acknowledgeCommitted(')));
 });

 test('SMS classification runs outside UI isolate; native ACK stays checked',(){
  final main=readWaffraMainSourceForContracts();
  final refresh=main.split(' Future<void> _runAutoSmsRefresh(')[1]
   .split(' Future<void> _scanPreviousBankSmsFromSettings()async{')[0];
  final worker=main.split('Map<String,Object?> waffraM632ClassifySmsQueue(')[1]
   .split('List<String> splitBankMessages(')[0];
  expect(refresh,contains('await compute(waffraM632ClassifySmsQueue,'));
  expect(refresh,contains('if(!mounted||!ready||_m627ClosingSession||_financeLoadFailure!=null)return;'));
  expect(refresh,contains('if(!_m630SmsSessionCurrent(smsEpoch))return;'));
  expect(main,contains('epoch==_m630HomeStartupEpoch;'));
  expect(refresh,contains('WaffraAutoSms.pendingChecked()'));
  expect(refresh,contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
  expect(refresh,contains('WaffraAutoSms.excludeMessages(batch)'));
  expect(worker,contains('WaffraBankSmsFactsParser.parse(body)'));
  expect(worker,contains('WaffraSmsLocalRules.resolve('));
  expect(worker,contains('waiting.add(annotated);'));
  expect(worker,isNot(contains('WaffraAutoSms.')));
  expect(worker,isNot(contains('setState(')));
 });

 test('fresh registration proves exact read-back without duplicate KDF',(){
  final credentials=File('lib/waffra_local_phone_credentials.dart')
   .readAsStringSync();
  final registration=credentials.split(' static Future<void> registerOrResume({')[1]
   .split(' /// Decode and challenge a pre-existing verifier')[0];
  expect(credentials,contains('static const _iterations=600000;'));
  expect(registration,contains('final saved=await _readVerifier();'));
  expect(registration,contains('final record=await deriveRecord('));
  expect(registration,contains('final encoded=jsonEncode(record);'));
  expect(registration,contains('await _store.write(key:_key,value:encoded);'));
  expect(registration,contains('final persisted=await _store.read(key:_key);'));
  expect(registration,contains('_equal(utf8.encode(persisted),utf8.encode(encoded))'));
  expect(registration,contains('if(await canResumeRecord(saved,phone:phone,password:password))return;'));
  expect(registration,isNot(contains('!await canResumeRecord(persisted')));
  expect(registration,isNot(contains('_store.delete(')));
  final main=readWaffraMainSourceForContracts();
  final submit=main.split(' Future<void> save()async {')[1]
   .split(' Widget _phoneRegistrationForm(){')[0];
  expect(submit,contains('if(busy)return;'));
  expect(submit,contains('await WidgetsBinding.instance.endOfFrame;'));
  expect(submit,contains('await WaffraLocalPhoneCredentials.registerOrResume('));
  final form=main.split(' Widget _phoneRegistrationForm(){')[1]
   .split(' @override Widget build(BuildContext context){')[0];
  expect(form,contains("Key('waffra-register-submit')"));
  expect(form,contains('child:busy?Row('));
  expect(form,contains('CircularProgressIndicator('));
 });
}

import 'dart:io';
import 'support/waffra_main_source.dart';

import 'package:flutter_test/flutter_test.dart';

/// M630 / #542: cross-session regression for latest merged M632/M633 Home.
/// These source ordering tests are not a substitute for real-device profiling.
void main() {
  final source = readWaffraMainSourceForContracts();
  final home = source.split(
    'class _HomeScreenState extends State<HomeScreen>')[1];
  final close = home.split(' Future<void> _m627CloseForLogout()async{')[1]
    .split(' void _m627AbortFailedLogout()')[0];
  final startup = home.split(' Future<void> _loadFinanceSafely()async{')[1]
    .split(' Widget _financialRecoveryScreen()')[0];
  final load = home.split(' Future<void> load()async {')[1]
    .split(' Future<void> _refreshWidget()async{')[0];
  final sms = home.split(' Future<void> _runAutoSmsRefresh(')[1]
    .split(' Future<void> _scanPreviousBankSmsFromSettings()async{')[0];

  test('only verified encrypted source and real account balances reveal Home', () {
    expect(load, contains('await _ensureFinanceBound();'));
    expect(load, contains('WaffraFreshHomeCatalogRecovery.load('));
    expect(load, contains('financeView.requireIntegrity();'));
    expect(load, contains('await (accountsLoading??_m467RefreshHomeAccounts())'));
    expect(load.indexOf('await (accountsLoading??_m467RefreshHomeAccounts())'),
      lessThan(load.indexOf('setState(()=>ready=true);')));
    expect(startup.indexOf('await load();'),
      lessThan(startup.indexOf('widget.onVerifiedReady?.call();')));
    expect(load, contains('WaffraPublicStartupPrewarm.categoriesJson()'));
    expect(load, contains('parseStartupFields('));
  });

  test('post-frame finance work is epoch guarded and awaits before vault close', () {
    expect(home, contains('int _m630HomeStartupEpoch=0;'));
    expect(home, contains('Future<void>? _m630PostFrameFinanceWork;'));
    expect(startup, contains('final startupEpoch=++_m630HomeStartupEpoch;'));
    expect(load, contains('final startupEpoch=_m630HomeStartupEpoch;'));
    expect(load, contains('Duration(milliseconds:400)'));
    expect(load.indexOf('Duration(milliseconds:400)'),
      lessThan(load.indexOf('final postFrameFinance=()async{')));
    expect(load, contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
    expect(load, contains('_m630PostFrameFinanceWork=postFrameFinance;'));
    expect(load, contains('await _refreshWidget();'));
    expect(load, contains('await syncRecurringReminders();'));
    expect(close, contains('_m630HomeStartupEpoch++;'));
    expect(close, contains('await postFrameFinance.timeout(const Duration(seconds:20));'));
    expect(close.indexOf('await postFrameFinance.timeout('),
      lessThan(close.indexOf('await binding.close();')));
    expect(close, contains('await _financialWriteQueue.drain()'));
    expect(startup, isNot(contains('unawaited(_refreshWidget());')));
  });

  test('native SMS resume and import never inherit a stale Home session', () {
    expect(startup, contains('if(!_m630SmsSessionCurrent(startupEpoch))return;'));
    expect(startup.indexOf('widget.onVerifiedReady?.call();'),
      lessThan(startup.indexOf('Duration(milliseconds:900)')));
    expect(startup, contains('if(!activeOwner||!_m630SmsSessionCurrent(startupEpoch))return;'));
    expect(startup, contains('await _refreshAutoSmsInbox('));
  });

  test('M632 whole-queue isolate survives; stale results never ACK new owner', () {
    expect(sms, contains('final smsEpoch=_m630HomeStartupEpoch;'));
    expect(sms, contains('compute(waffraM632ClassifySmsQueue,'));
    expect(sms, contains('if(!_m630SmsSessionCurrent(smsEpoch))return;'));
    expect(sms, contains('WaffraAutoSms.excludeMessages(batch)'));
    expect(sms, contains('WaffraAutoSms.acknowledgeCommitted(batch)'));
    expect(sms, contains("final waiting=(classified['waiting'] as List)"));
    expect(sms, contains('smsHashes.toList(growable:false)'));
    final exclusion = sms.indexOf('await WaffraAutoSms.excludeMessages(batch)');
    final commitAck = sms.indexOf('await WaffraAutoSms.acknowledgeCommitted(batch)');
    expect(sms.lastIndexOf('if(!_m630SmsSessionCurrent(smsEpoch))return;', exclusion),
      greaterThan(sms.indexOf('final classified=await compute(')));
    expect(sms.lastIndexOf('if(!_m630SmsSessionCurrent(smsEpoch))return;', commitAck),
      greaterThan(exclusion));
    expect(sms, isNot(contains('waffraParseBankSmsBatchInIsolate,bodies')));
  });
}

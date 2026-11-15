import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// M965 / #666: the last Home State helper extraction retains exact
/// invalidation and permission-memoization semantics, not new finance writes.
void main(){
 test('M965 Home core helpers preserve full ledger cache invalidation '
      'and one future per permission session',(){
  final main=File('lib/main.dart').readAsStringSync();
  final helpers=File('lib/waffra_home_state_core_helpers.part.dart')
    .readAsStringSync();
  expect(main,contains("part 'waffra_home_state_core_helpers.part.dart';"));
  expect(main,contains('final WaffraHomeLedgerReadCache _m940LedgerReads='));
  expect(main,contains('Future<bool>? _m528SmsEnabledFuture;'));
  expect(main,isNot(contains('void _m684InvalidatePeriodRead(){')));
  expect(main,isNot(contains('Future<bool> _m528SmsEnabled()=>')));
  final invalidate=helpers.indexOf('void _m684InvalidatePeriodRead(){');
  final permission=helpers.indexOf('Future<bool> _m528SmsEnabled()=>');
  expect(invalidate,greaterThan(0));
  expect(permission,greaterThan(invalidate));
  final invalidateSource=helpers.substring(invalidate,permission);
  expect(invalidateSource,contains('_m940LedgerReads.invalidate();'));
  expect(invalidateSource,contains('_m945UnifiedHistoryScope=null;'));
  expect(invalidateSource,contains('_m945UnifiedHistoryCount=null;'));
  expect(helpers,contains('_m528SmsEnabledFuture??=WaffraAutoSms.enabled()'));
  // Caller and lifecycle ownership did not move with helpers.
  expect(main,contains('void _receiveSharedSms(){'));
  expect(main,isNot(contains('void _m684InvalidatePeriodRead();')));
  expect(main,contains('@override void initState(){'));
  expect(main,contains('@override void dispose(){'));
  final recovery=File('lib/waffra_home_finance_recovery.part.dart')
    .readAsStringSync();
  expect(recovery,contains('_m684InvalidatePeriodRead();'));
 });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'support/waffra_main_source.dart';

void main(){
 test('M930 verified Home session/nav methods are real same-library parts, unchanged',(){
  final main=File('lib/main.dart').readAsStringSync();
  final joined=readWaffraMainSourceForContracts();
  final checks=<String,List<String>>{
   'lib/waffra_home_auth_visibility.part.dart':[
    ' Future<bool> _m663AwaitVisible(int epoch)async{',
    '_m663FirstInteractiveFrame.future',
    'epoch==_m630HomeStartupEpoch&&!_m627ClosingSession',
   ],
   'lib/waffra_home_finance_binding.part.dart':[
    ' Future<void> _ensureFinanceBound()async{',
    'final pending=_financeBindingFuture??=_bindFinanceSource();',
    ' Future<void> _bindFinanceSource()async{',
    'deferInitialDashboardRead:true',
    'if(!mounted){await binding.close();',
    '_financeAuthority=binding.authority;',
   ],
   'lib/waffra_home_fab_actions.part.dart':[
    ' Future<void> _launchAddAction(',
    'if(_addActionOpening)return;',
    'if(mounted)await action();',
    ' bool _acceptFabTap(){',
    'const Duration(milliseconds:380)',
   ],
   'lib/waffra_home_resume_handler.part.dart':[
    ' void _m468OnResume(){',
    'WidgetsBinding.instance.addPostFrameCallback((_){',
    'WaffraExternalMediaSession.shouldSkipResumeBackgroundWork',
    'unawaited(_syncWidgetTransactions());',
    'unawaited(_refreshAutoSmsInbox());',
   ],
   'lib/waffra_home_widget_action_routes.part.dart':[
    ' void _returnToHome(){',
    ' void _receiveWidgetAction(){',
    "waffraWidgetAction.value!='add'",
    'WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)unawaited(entrySheet());});',
   ],
  };
  for(final entry in checks.entries){
   final source=File(entry.key).readAsStringSync();
   expect(source,startsWith("part of 'main.dart';"));
   expect(main,contains("part '${entry.key.split('/').last}';"));
   for(final value in entry.value){
    expect(source,contains(value),reason:'${entry.key}: $value');
    expect(joined,contains(value),reason:'real source: ${entry.key}: $value');
   }
  }
  expect(main,contains('floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
  expect(main,contains('width:58,height:58'));
  expect(main,contains('waffraWidgetAction.addListener(_receiveWidgetAction)'));
 });
}

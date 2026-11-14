import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_approved_page_designs.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();

 test('M938 backup dialog uses one opening biometric, never second challenge '
      'and no Advanced Options or clipboard path',(){
  final source=File('lib/waffra_home_account_tools.part.dart').readAsStringSync();
  final start=source.indexOf(' Future<void> backupDialog()async {');
  final end=source.indexOf(' // System credentials are never saved',start);
  expect(start,greaterThanOrEqualTo(0));
  expect(end,greaterThan(start));
  final dialog=source.substring(start,end);
  expect(RegExp(r'_authorizeSensitiveAction\(').allMatches(dialog).length,1);
  expect(dialog,contains('WaffraVerifiedActiveRestorePreflight('));
  expect(dialog,contains('preflightChecksum:result.archiveChecksum'));
  expect(dialog,contains('baseline:source.encryptedWitness!'));
  expect(dialog,contains('waffra-open-backup-file'));
  expect(dialog,isNot(contains('waffra-import-legacy-text')));
  expect(dialog,isNot(contains('Advanced options')));
  expect(dialog,isNot(contains('Clipboard.getData(')));
 });

 test('M938 goal filter menu owns counts, More is 3 dots and due filters '
      'also have status/date windows',(){
  final page=File('lib/waffra_home_goals_recurring_pages.part.dart')
   .readAsStringSync();
  expect(page,contains("const filterValues=<String>['all','active','inactive','done','incomplete','week','month']"));
  expect(page,contains("key:const Key('m938-goals-filter-menu')"));
  expect(page,contains("key:const Key('m938-goals-more')"));
  expect(page,contains('Icons.more_vert_rounded'));
  expect(page,contains('WaffraOutlinedItemsCount('));
  expect(page,contains("key:const Key('m938-dues-filter-menu')"));
  expect(page,contains("'all','today','week','month','overdue','active','paused'"));
  expect(page,contains('goalCounts[filter]'));
  expect(page,contains('dueCounts[filter]'));
  expect(page,isNot(contains("key:const Key('m689-goals-archive')")));
 });

 test('M938 home restore notice retains FAB anchor during Settings handoff',(){
  final home=File('lib/main.dart').readAsStringSync();
  expect(home,contains('if(inHome||(_waffraFooterHostCount>0&&'));
  expect(home,isNot(contains('if(_waffraFooterHostCount==0)waffraDismissFooterNotice();')));
  expect(home,contains('WaffraApprovedFixedFabNoticePosition('));
  expect(home,contains('floatingActionButtonAnimator:const WaffraStationaryFabAnimator()'));
 });

 for(final english in [false,true]){
  testWidgets('M938 ${english?'LTR':'RTL'} two-line notice stays '
    'adjacent to original FAB without moving it',(tester)async{
   final link=LayerLink();
   final notice=ValueNotifier<WaffraNoticeData?>(WaffraNoticeData(
    text:'Message confirming restored 19 transactions after verification '
      'with encrypted archive and all saved goal balances',
    kind:WaffraSnackKind.success));
   addTearDown(notice.dispose);
   await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[
    Positioned(left:english?300:18,bottom:80,
     child:CompositedTransformTarget(link:link,
      child:const SizedBox(key:Key('m938-fab-anchor'),width:58,height:58,
       child:ColoredBox(color:Colors.green)))),
    WaffraApprovedFixedFabNoticePosition(
     link:link,english:english,
     child:WaffraFooterNoticeHost(listenable:notice)),
   ]))));
   await tester.pump();
   final fab=tester.getRect(find.byKey(const Key('m938-fab-anchor')));
   final toast=tester.getRect(find.byType(WaffraNoticeEdgeBody));
   if(english){
    expect(toast.right,lessThanOrEqualTo(fab.left));
   }else{
    expect(toast.left,greaterThanOrEqualTo(fab.right));
   }
   expect(toast.height,greaterThanOrEqualTo(48));
   expect(tester.getRect(find.byKey(const Key('m938-fab-anchor'))),fab);
  });
 }
}

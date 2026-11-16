import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M1006 post-restore Home verification is required before success',(){
  final restore=File('lib/waffra_home_account_tools.part.dart')
   .readAsStringSync();
  final start=restore.indexOf("       sqlcipherRestoreCommitted=true;");
  final end=restore.indexOf("       if(authenticatedLegacyRows!=null&&mounted){",start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final postCommit=restore.substring(start,end);
  expect(postCommit,contains("restoreStage='HOME_REFRESH';"));
  expect(postCommit,contains('await _loadFinanceSafely();'));
  expect(postCommit,contains("restoreStage='HOME_VERIFICATION';"));
  expect(postCommit,contains('if(!mounted)return;'));
  expect(postCommit,contains('if(!ready||_financeLoadFailure!=null){'));
  expect(postCommit,contains("restoreStage='HOME_RELOAD_FAILED';"));
  expect(postCommit,contains("throw StateError('M1006_RESTORED_HOME_UNVERIFIED');"));
  expect(postCommit.indexOf('await _loadFinanceSafely();'),
   lessThan(postCommit.indexOf('if(!ready||_financeLoadFailure!=null){')));
  final success=restore.indexOf('if(ctx.mounted)Navigator.pop(ctx);',end);
  final alert=restore.indexOf('if(mounted)snackSuccess(context,',end);
  expect(success,greaterThan(end));
  expect(alert,greaterThan(success));
  expect(restore,contains('restoreError=sqlcipherRestoreCommitted?'));
  expect(restore,contains('لا تحذف أي عملية، واحتفظ بنسخة الأمان'));
 });

 test('M1006 loaded source can fail closed without throwing',(){
  final source=File('lib/waffra_home_finance_recovery.part.dart')
   .readAsStringSync();
  final loader=source.substring(
   source.indexOf(' Future<void> _loadFinanceSafely()async{'),
   source.indexOf(' Widget _financialRecoveryScreen()=>'));
  expect(loader,contains('setState((){ready=false;_financeLoadFailure=null;});'));
  expect(loader,contains('await load();'));
  expect(loader,contains('}catch(e){'));
  expect(loader,contains('_financeLoadFailure=waffraIsEnglish?'));
  final readySource=File('lib/waffra_home_finance_startup.part.dart')
   .readAsStringSync();
  expect(readySource,contains('setState(()=>ready=true);'));
 });

 test('M1006 unready finance paints full light nonfinancial background',(){
  final source=File('lib/waffra_home_root_shell.part.dart')
   .readAsStringSync();
  final start=source.indexOf(' Widget _m1003FinanceHandoffSurface()=>Scaffold(');
  final end=source.indexOf(' Widget _m944BuildHome()=>PopScope(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final scene=source.substring(start,end);
  expect(scene,contains("Key('m1006-protected-finance-reload-surface')"));
  expect(scene,contains('backgroundColor:const Color(0xFFF8F6EF)'));
  expect(scene,contains('CircularProgressIndicator('));
  expect(scene,contains('جارٍ التحقق من البيانات المالية المشفرة'));
  expect(scene,isNot(contains('backgroundColor:forest')));
  expect(scene,isNot(contains('Colors.black')));
  expect(scene,isNot(contains('entries.')));
  expect(scene,isNot(contains('_m467ShownBalance()')));
  expect(source,contains('child:!ready&&_financeLoadFailure==null?'));
  expect(source,contains('widget.postAuthVisible?'));
  expect(source,contains('WaffraFinanceReloadingView(english:waffraIsEnglish)'));
  expect(source,contains('_m1003FinanceHandoffSurface()):Stack(children:[Scaffold('));
  expect(source,contains('body:_financeLoadFailure!=null?_financialRecoveryScreen():'));
  // The branded transition does not modify the original floating + button.
  expect(source,contains(' // A fixed 58x58 FAB:'));
 });
}

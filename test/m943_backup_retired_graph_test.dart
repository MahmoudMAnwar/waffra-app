import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M943 V3 optional custom institution extension preserves old archives',(){
  final source=File('lib/storage/waffra_accounts_portable_backup_v3.dart')
   .readAsStringSync();
  expect(source,contains("'customInstitutionLinksV1'"));
  expect(source,contains("raw.containsKey('customInstitutionLinksV1')?1:0"));
  expect(source,contains('WaffraCustomInstitutionLinks.validateBackup('));
  expect(source,contains('WaffraCustomInstitutionLinks.restore('));
  expect(source,contains("if(institutionLinks.isNotEmpty)"));
  // The historical V24/V3 restoration still uses the existing authenticated
  // source and disposable SQLCipher transaction, never an app-owned snapshot.
  expect(source,contains('return disposableStore.transaction(()async{'));
 });

 test('M943 retired model is unreachable from live Home without deleting currency guards',(){
  final main=File('lib/main.dart').readAsStringSync();
  final worker=File('lib/waffra_cloudflare_sms_gateway.dart').readAsStringSync();
  expect(main,isNot(contains("import 'waffra_ai_finance_brain.dart'")));
  expect(main,isNot(contains("import 'waffra_cloudflare_sms_gateway.dart'")));
  expect(worker,contains('static bool get configured => false;'));
  expect(worker,contains("static const String configuredUrl = '';"));
  expect(File('test/qa/m927_retired_model_runtime_graph_guard_test.py')
   .existsSync(),isTrue);
 });
}

import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M636 retire model source without deleting finance records',(){
  expect(File('lib/waffra_ondevice_qwen.dart').existsSync(),false);
  expect(File('lib/waffra_ai_model_gate.dart').existsSync(),false);
  expect(File('scripts/qa/prefetch_verified_llamadart.sh').existsSync(),false);
  final home=readWaffraMainSourceForContracts();
  expect(home,contains('Future<void> eraseFinancialData()async'));
  expect(home,isNot(contains('Future<void> deleteAiModel()async')));
  expect(home,contains('await _accountWriteAuthority.signOut();'));
 });
 test('M636 old AI removal never clears user finance data or recovery',(){
  final home=readWaffraMainSourceForContracts();
  expect(home,contains('Future<void> _loadFinanceSafely()async'));
  expect(home,contains('financeView.requireIntegrity();'));
  expect(home,contains('Future<void> entrySheet('));
  expect(home,isNot(contains('deleteDownloadedModel()')));
 });
 test('M636 remove Qwen dependency and native asset fetch',(){
  final pubspec=File('pubspec.yaml').readAsStringSync();
  final action=File('.github/actions/prefetch-sqlite3mc/action.yml').readAsStringSync();
  expect(pubspec,isNot(contains('llamadart:')));
  expect(pubspec,isNot(contains('llama_cpp')));
  expect(action,isNot(contains('prefetch_verified_llamadart')));
  expect(action,contains('prefetch_verified_sqlite3mc.sh'));
 });
}

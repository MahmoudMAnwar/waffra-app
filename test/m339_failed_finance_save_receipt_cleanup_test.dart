import 'dart:io';
import 'support/waffra_main_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M339 manual receipt attachment stages roll back when ledger commit fails',(){
  final main=readWaffraMainSourceForContracts();
  final start=main.indexOf('Future<void> entrySheet(');
  final end=main.indexOf('Future<String?> chooseTransactionCategory(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final editor=main.substring(start,end);
  expect(editor,contains('stagedReceiptCopies.add(renamed)'));
  expect(editor,contains('stagedReceiptCopies.add(path)'));
  expect(editor,contains('stagedReceiptCopies.add(copied)'));
  // M953: after uncertain encrypted commits, source is reloaded before
  // the user is told to retry. The old "data unchanged" text was unsafe.
  final catchPoint=editor.indexOf(
   'Save was not confirmed; verified finance was reloaded before retry.');
  expect(editor.substring(catchPoint),contains(
   'await _refreshFromVerifiedFinance();'));
  final cleanup=editor.indexOf('for(final copy in stagedReceiptCopies)',catchPoint);
  expect(catchPoint,greaterThan(0));
  expect(cleanup,greaterThan(catchPoint));
  expect(editor.substring(cleanup),contains('if(await staged.exists())await staged.delete()'));
  expect(editor.substring(cleanup),contains('Could not clean staged receipt'));
 });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M339 manual and OCR staged receipts roll back when ledger commit fails',(){
  final main=File('lib/main.dart').readAsStringSync();
  final start=main.indexOf('Future<void> entrySheet(');
  final end=main.indexOf('Future<String?> chooseTransactionCategory(',start);
  expect(start,greaterThan(0));
  expect(end,greaterThan(start));
  final editor=main.substring(start,end);
  expect(editor,contains('stagedReceiptCopies.add(copy)'));
  expect(editor,contains('stagedReceiptCopies.add(path)'));
  expect(editor,contains('stagedReceiptCopies.add(copied)'));
  final catchPoint=editor.indexOf('Could not save the transaction.');
  final cleanup=editor.indexOf('for(final copy in stagedReceiptCopies)',catchPoint);
  expect(catchPoint,greaterThan(0));
  expect(cleanup,greaterThan(catchPoint));
  expect(editor.substring(cleanup),contains('if(await staged.exists())await staged.delete()'));
  expect(editor.substring(cleanup),contains('Could not clean staged receipt'));
 });
}

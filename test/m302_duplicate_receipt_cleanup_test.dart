import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M302 refuse duplicate means no new finance write and staged receipt removed',(){
  final main=File('lib/main.dart').readAsStringSync();
  final entry=main.indexOf('Future<void> entrySheet(');
  final duplicate=main.indexOf('if(initial==null&&entries.any((e)=>',entry);
  final commit=main.indexOf('final previousSpent=sum(',duplicate);
  expect(entry,greaterThan(0));
  expect(duplicate,greaterThan(entry));
  expect(commit,greaterThan(duplicate));
  final review=main.substring(duplicate,commit);
  expect(review,contains('if(proceed!=true||!mounted){'));
  expect(review,contains('for(final copy in stagedReceiptCopies)'));
  expect(review,contains('if(await file.exists())await file.delete()'));
  expect(review,contains('return;'));
  expect(main,contains('if(result==null||!mounted)'));
  expect(main,contains('await persist(route:initial==null'));
 });
}

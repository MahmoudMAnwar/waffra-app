import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/main.dart';
import 'package:waffra/waffra_validators.dart';

void main() {
  test('M302 category rename preserves bank SMS origin, notes and attachment', () {
    final original=MoneyEntry(
      id:'tx-123',title:'تحويل وارد',category:'دخل آخر',
      amount:198.75,income:true,date:DateTime.utc(2026,10,30,11,34),
      receiptPath:'/data/receipts/sample__invoice.jpg',
      notes:'Original long bank SMS and user notes — synthetic test only',
      sourceType:'sms',merchantKey:'merchant-1',
    );
    final renamed=original.withCategory('دخل / حوالات');
    final json=renamed.toJson();
    final cold=MoneyEntry.fromJson(json);
    expect(renamed.category,'دخل / حوالات');
    expect(original.category,'دخل آخر');
    for(final key in <String>['id','title','amount','income','date',
      'receiptPath','notes','sourceType','merchantKey']) {
      expect(json[key],original.toJson()[key],reason:'preserve '+key);
      expect(cold.toJson()[key],original.toJson()[key],reason:'cold restore '+key);
    }
  });

  test('M302 category rename never resets recurring start date/day/status', () {
    final original=RecurringBill(
      id:'due-123',title:'اشتراك',category:'اشتراكات رقمية',
      amount:29.95,income:false,day:31,active:false,
      startAt:DateTime.utc(2024,2,14,14,15),
    );
    final renamed=original.withCategory('اشتراكات / انترنت');
    final json=renamed.toJson();
    final cold=RecurringBill.fromJson(json);
    expect(renamed.category,'اشتراكات / انترنت');
    expect(original.category,'اشتراكات رقمية');
    for(final key in <String>['id','title','amount','income','day','active','startAt']){
      expect(json[key],original.toJson()[key],reason:key);
      expect(cold.toJson()[key],original.toJson()[key],reason:'restored '+key);
    }
  });

  test('M302 category name guard prevents Arabic look-alike labels',(){
    final existing=['إدخار','متجر آخر','صَدَقة'];
    for(final label in ['ادخار','متجر اخر','صدقة']){
      expect(WaffraValidators.uniqueCategory(label,existing),'duplicate',
        reason:label);
    }
    expect(WaffraValidators.uniqueCategory('سكن',existing),isNull);
  });

  test('M302 rejected category mutation reloads authority, never leaves phantom UI',(){
    final main=File('lib/main.dart').readAsStringSync();
    final start=main.indexOf('Future<void> addCategory(');
    final finish=main.indexOf('WaffraFinanceRoute _moduleMutationRoute',start);
    expect(start,greaterThan(0));
    expect(finish,greaterThan(start));
    final calls=main.substring(start,finish);
    expect(calls,contains('_persistModuleOrReload('),
      reason:'Category creation must use the shared authority recovery guard');
    expect(calls,contains("operation:'category-create'"));
    expect(calls,contains('Category edit not committed by verified finance source'));
    expect(RegExp(r'if\(mounted\)await _loadFinanceSafely\(\);')
      .allMatches(calls).length,1,
      reason:'Category edit must also recover authoritative state on failure');
  });

  test('M302 live update path must use field-preserving clones',(){
    final source=File('lib/main.dart').readAsStringSync();
    final start=source.indexOf('Future<void> updateCategory(');
    final end=source.indexOf('WaffraFinanceRoute _moduleMutationRoute',start);
    expect(start,greaterThan(0));
    expect(end,greaterThan(start));
    final method=source.substring(start,end);
    expect(method,contains('entries[j]=old.withCategory(renamed)'));
    expect(method,contains('recurring[j]=old.withCategory(renamed)'));
    expect(method,isNot(contains('entries[j]=MoneyEntry(')));
    expect(method,isNot(contains('recurring[j]=RecurringBill(')));
  });
}

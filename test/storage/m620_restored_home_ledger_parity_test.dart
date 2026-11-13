import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_restored_ledger_identity_guard.dart';

void main() {
  Map<String, Object?> row(int n, {bool income = false}) =>
    <String, Object?>{
      'id': 'synthetic-620-$n',
      'title': 'Same-looking synthetic record',
      'amount': income ? 250.0 : 19.25,
      'income': income,
      'date': '2026-11-01T10:00:00.000',
    };

  final source = <Map<String, Object?>>[
    for (var i=0; i<19; i++) row(i,income:i>=17),
  ];

  test('M620 original 19 distinct IDs, including same-looking records, '
      'are accepted exactly once', () {
    final result=WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,
      verifiedSnapshot:source.map((r)=>Map<String,Object?>.from(r)).toList(),
    );
    expect(result.sourceCount,19);
    expect(result.verifiedCount,19);
    expect(source.where((r)=>r['income']==false),hasLength(17));
    expect(source.where((r)=>r['income']==true),hasLength(2));
  });

  test('M620 19 records doubled to 38 in Home can NEVER pass parity', () {
    final doubled=<Map<String,Object?>>[
      ...source.map((r)=>Map<String,Object?>.from(r)),
      ...source.map((r)=>Map<String,Object?>.from(r)),
    ];
    expect(() => WaffraRestoredLedgerIdentityGuard.verify(
        authenticatedSource:source,verifiedSnapshot:doubled),
      throwsA(isA<StateError>()));
  });

  test('M620 additional rows with different IDs are not silently deduped '
      'by same amount, title or date', () {
    final extra=[...source,row(20,income:true)];
    expect(() => WaffraRestoredLedgerIdentityGuard.verify(
        authenticatedSource:source,verifiedSnapshot:extra),
      throwsA(isA<StateError>()));
    final legitimate=[row(1),row(2)];
    expect(WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:legitimate,
      verifiedSnapshot:legitimate,
    ).verifiedCount,2);
  });

  test('M620 changing amounts, dates, income flag or removing an ID '
      'must fail closed', () {
    for (final changed in <Map<String,Object?>>[
      {...source.first,'amount':20.25},
      {...source.first,'date':'2026-11-02T10:00:00.000'},
      {...source.first,'income':true},
    ]) {
      final altered=[changed,...source.skip(1)];
      expect(() => WaffraRestoredLedgerIdentityGuard.verify(
        authenticatedSource:source,verifiedSnapshot:altered),
        throwsA(isA<StateError>()));
    }
    expect(() => WaffraRestoredLedgerIdentityGuard.verify(
      authenticatedSource:source,verifiedSnapshot:source.take(18).toList()),
      throwsA(isA<StateError>()));
  });

  test('M620 restored V24 checks canonical SQLCipher before repainting '
      'Home; SQL rollback and source-witness guards are still active', () {
    final code=File('lib/main.dart').readAsStringSync();
    expect(code,contains("restoreStage='CANONICAL_PARITY'"));
    expect(code,contains("restoreStage='HOME_PARITY'"));
    expect(code,contains('WaffraRestoredLedgerIdentityGuard.verify('));
    expect(code,contains("route:WaffraFinanceRoute.dashboardRead"));
    expect(code,contains('verified.finance.requireIntegrity();'));
    expect(code,contains('entries..clear()..addAll(exact)'));
    expect(code,isNot(contains('externallySavedRescueConfirmed:true')));
    expect(code,isNot(contains('Waffra_Rescue_Before_Restore_')));
    expect(code,contains('preflightChecksum:result.archiveChecksum'));
    expect(code,contains("key:const Key('m620-accountless-legacy-net-explanation')"));
    expect(code,contains("cash(sum(entries,true)-sum(entries,false))"));
    expect(code,contains('هذا ليس رصيدًا بنكيًا متاحًا'));
    // M623 owner-approved restore no longer prompts for a rescue archive.
    expect(code,isNot(contains('نسخة الأمان ملف مشفر منفصل')));
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_verified_transaction_ui_guard.dart';

void main() {
  Map<String, dynamic> record(String id) => <String, dynamic>{
    'id': id,
    'title': 'Synthetic financial row',
    'category': 'Other',
    'amount': 45.75,
    'income': false,
    'date': '2026-10-24T10:00:00.000Z',
    'receiptPath': null,
    'notes': '',
    'sourceType': 'manual',
    'merchantKey': '',
  };

  test('M183 Home UI validates exact immutable selected row', () {
    final selected = record('synthetic-001');
    WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([selected]), selected: selected,
    );
    final rows = WaffraVerifiedTransactionUiGuard.decodeLedger(
      jsonEncode([selected]),
    );
    expect(rows.single['amount'], 45.75);
    expect(() => rows.single['amount'] = 2, throwsUnsupportedError);
    expect(() => rows.clear(), throwsUnsupportedError);
  });

  test('M183 stale tile cannot delete a transaction edited by Widget', () {
    final selected = record('synthetic-002');
    final changed = record('synthetic-002')..['amount'] = 54.75;
    expect(() => WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([changed]), selected: selected,
    ), throwsStateError);
  });

  test('M183 changing only attached receipt reference blocks deletion', () {
    final selected = record('synthetic-003')
      ..['receiptPath'] = 'waffra-receipt://original/0';
    final changed = record('synthetic-003')
      ..['receiptPath'] = 'waffra-receipt://different/0';
    expect(() => WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([changed]), selected: selected,
    ), throwsStateError);
  });

  test('M183 missing transaction cannot silently delete a different ID', () {
    expect(() => WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([record('other-id')]),
      selected: record('selected-id'),
    ), throwsStateError);
  });

  test('M183 duplicate IDs and malformed finance fail closed', () {
    final duplicated = jsonEncode([record('dup'), record('dup')]);
    expect(() => WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: duplicated, selected: record('dup'),
    ), throwsStateError);
    for (final bad in [null, '{}', '"bad"', '[5]', '[null]',
        '[{"id":""}]', '[{"title":"missing ID"}]']) {
      expect(() => WaffraVerifiedTransactionUiGuard.decodeLedger(bad),
          throwsStateError);
    }
  });

  test('M183 unrelated new Widget row survives selected row matching', () {
    final selected = record('existing');
    WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([record('widget-added'), selected]),
      selected: selected,
    );
    expect(WaffraVerifiedTransactionUiGuard.decodeLedger(jsonEncode([
      record('widget-added'), selected,
    ])).length, 2);
  });

  test('M183 old record must not be replaced with default values', () {
    final rendered = record('legacy-with-missing-fields');
    final previous = <String, dynamic>{
      'id': rendered['id'], 'title': rendered['title'],
      'category': rendered['category'], 'amount': rendered['amount'],
      'income': rendered['income'], 'date': rendered['date'],
      'receiptPath': null,
    };
    expect(() => WaffraVerifiedTransactionUiGuard.requireUnchangedSelected(
      ledgerRaw: jsonEncode([previous]),
      selected: rendered,
    ), throwsStateError);
  });
}

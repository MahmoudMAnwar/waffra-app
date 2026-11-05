import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

void main() {
  final payload = <String, Object>{
    'entries': '[{"id":"synthetic-1","amount":12.5}]',
    'waffra_categories_v24': '[]',
    'waffra_named_budgets_v1': '[]',
    'waffra_goals_v24': '[]',
    'waffra_recurring_v24': '[]',
    'waffra_monthly_budget_v1': 0.0,
  };

  test('M455 fresh verified SQLCipher manual save submits only ledger', () {
    final snapshot = Map<String, Object>.of(payload);
    WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
      route: WaffraFinanceRoute.manualTransactionSave,
      source: WaffraRuntimeFinanceBackend.verifiedEncrypted,
      snapshot: snapshot,
    );
    expect(snapshot, <String, Object>{'entries': payload['entries']!});
  });

  test('M455 guarded legacy manual save preserves full snapshot', () {
    final snapshot = Map<String, Object>.of(payload);
    WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
      route: WaffraFinanceRoute.manualTransactionSave,
      source: WaffraRuntimeFinanceBackend.guardedLegacy,
      snapshot: snapshot,
    );
    expect(snapshot, payload);
  });

  test('M455 no source witness cannot authorize narrowing', () {
    final snapshot = Map<String, Object>.of(payload);
    WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
      route: WaffraFinanceRoute.manualTransactionSave,
      source: null,
      snapshot: snapshot,
    );
    expect(snapshot, payload);
  });

  test('M455 verified edits and other finance routes retain all fields', () {
    for (final route in [
      WaffraFinanceRoute.transactionEdit,
      WaffraFinanceRoute.categoryCreateEditDeleteRestore,
      WaffraFinanceRoute.goalCreateEditDeleteRestore,
      WaffraFinanceRoute.recurringPostingAndPostponement,
    ]) {
      final snapshot = Map<String, Object>.of(payload);
      WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
        route: route,
        source: WaffraRuntimeFinanceBackend.verifiedEncrypted,
        snapshot: snapshot,
      );
      expect(snapshot, payload, reason: route.name);
    }
  });

  test('M455 missing manual ledger rejects without touching other data', () {
    final snapshot = <String, Object>{'waffra_goals_v24': '[]'};
    expect(() => WaffraHomeTransactionCapture.narrowVerifiedManualAppend(
      route: WaffraFinanceRoute.manualTransactionSave,
      source: WaffraRuntimeFinanceBackend.verifiedEncrypted,
      snapshot: snapshot,
    ), throwsStateError);
    expect(snapshot, <String, Object>{'waffra_goals_v24': '[]'});
  });

  test('M455 Home applies narrowing before source-authorized queued write', () {
    final app = File('lib/main.dart').readAsStringSync();
    final begin = app.indexOf('Future<void> persist({');
    final end = app.indexOf('Future<bool> _persistModuleOrReload(', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(end, greaterThan(begin));
    final persist = app.substring(begin, end);
    final scope = persist.indexOf(
      'WaffraHomeTransactionCapture.narrowVerifiedManualAppend(');
    final queued = persist.indexOf('_financialWriteQueue.submit(snapshot,');
    expect(scope, greaterThan(0));
    expect(queued, greaterThan(scope));
    expect(persist, contains('source:baseline?.source'));
    expect(persist, contains('baseline:baseline'));
    expect(persist, contains('_financeAuthority.saveCaptured('));
  });

  test('M455 authority still refuses mixed edits and duplicate posting', () {
    final source = File('lib/storage/waffra_verified_finance_authority.dart')
        .readAsStringSync();
    expect(source, contains('Manual save includes unrelated finance edits.'));
    expect(source, contains(
        'Manual save may only append one unchanged transaction.'));
    expect(source, contains('baseline.encryptedWitness'));
    expect(source, contains('expectedAccountGeneration:'));
  });
}

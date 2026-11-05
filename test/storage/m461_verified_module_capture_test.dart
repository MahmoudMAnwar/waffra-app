import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';

void main() {
  const encrypted = WaffraRuntimeFinanceBackend.verifiedEncrypted;
  const legacy = WaffraRuntimeFinanceBackend.guardedLegacy;
  const catalogue = '[{"id":"main"}]';
  const goal = '[{"id":"goal-1"}]';
  const due = '[{"id":"due-1","linkedGoalId":"goal-1"}]';

  Map<String, Object> displayed() => <String, Object>{
    'entries': '[]',
    'waffra_categories_v24': catalogue,
    'waffra_named_budgets_v1': '[]',
    'waffra_goals_v24': goal,
    'waffra_recurring_v24': due,
    'waffra_challenges_v1': '[]',
    'waffra_deleted_categories_v1': '[]',
    'waffra_deleted_goals_v1': '[]',
    'waffra_deleted_recurring_v1': '[]',
    'waffra_recurring_postponed_v1': '{}',
    'waffra_monthly_budget_v1': 0.0,
    'waffra_monthly_budget_enabled_v1': false,
    'waffra_learned_merchants_v1': '{}',
  };
  final fresh = <String, Object?>{
    'entries': '[]',
    'waffra_categories_v24': catalogue,
  };

  test('fresh SQLCipher goal and due submit only atomic projection fields', () {
    final capture = displayed();
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
      source: encrypted, snapshot: capture, witnessedValues: fresh);
    expect(capture.keys.toSet(), {
      'waffra_goals_v24', 'waffra_recurring_v24',
    });
    expect(capture['waffra_goals_v24'], goal);
    expect(capture['waffra_recurring_v24'], due);
  });

  test('fresh SQLCipher recurring edit does not manufacture optional fields', () {
    final capture = displayed();
    // A goal already exists on disk but is not changed by recurring creation.
    final prior = <String, Object?>{...fresh, 'waffra_goals_v24': goal};
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.recurringCreateEditDeleteRestore,
      source: encrypted, snapshot: capture, witnessedValues: prior);
    expect(capture.keys.toList(), ['waffra_recurring_v24']);
  });

  test('entry editing submits only entry projection after verified read', () {
    final capture = displayed()..['entries']='[{"id":"txn-1"}]';
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.transactionEdit,
      source: encrypted, snapshot: capture, witnessedValues: fresh);
    expect(capture.keys.toList(), ['entries']);
  });

  test('unrelated persisted category change fails closed', () {
    final capture = displayed()
      ..['waffra_categories_v24']='[{"id":"unexpected"}]';
    expect(() => WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
      source: encrypted, snapshot: capture, witnessedValues: fresh),
      throwsStateError);
  });

  test('unpersisted nonempty budget is not silently dropped', () {
    final capture = displayed()
      ..['waffra_named_budgets_v1']='[{"id":"unconfirmed"}]';
    expect(() => WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.recurringCreateEditDeleteRestore,
      source: encrypted, snapshot: capture, witnessedValues: fresh),
      throwsStateError);
  });

  test('unchanged legacy captures retain original full snapshot', () {
    final capture = displayed();
    WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
      route: WaffraFinanceRoute.goalCreateEditDeleteRestore,
      source: legacy, snapshot: capture, witnessedValues: null);
    expect(capture.keys.length, displayed().keys.length);
  });
}

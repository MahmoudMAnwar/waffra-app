import 'package:flutter_test/flutter_test.dart';
import 'package:waffra/storage/waffra_home_transaction_capture.dart';
import 'package:waffra/storage/waffra_runtime_finance_route_contract.dart';
import 'package:waffra/storage/waffra_production_finance_routing_gate.dart';

void main() {
 test('M468 unchanged large confirmed ledger remains allowed in goal edit',(){
  final ledger='['+List.filled(4000,'{"id":"confirmed","amount":5.5}').join(',')+']';
  final snapshot=<String,Object>{
   'entries':ledger,
   'waffra_goals_v24':'[{"id":"new-goal"}]',
   'waffra_recurring_v24':'[]',
  };
  WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.goalCreateEditDeleteRestore,
   source:WaffraRuntimeFinanceBackend.verifiedEncrypted,
   snapshot:snapshot,
   witnessedValues:<String,Object?>{
    'entries':ledger,'waffra_goals_v24':'[]','waffra_recurring_v24':'[]',
   },
  );
  expect(snapshot.keys,containsAll(['waffra_goals_v24','waffra_recurring_v24']));
  expect(snapshot.containsKey('entries'),isFalse);
 });
 test('M468 fast string check still rejects unrelated ledger mutation',(){
  final snapshot=<String,Object>{
   'entries':'[{"amount":999}]','waffra_recurring_v24':'[{"id":"rent"}]',
  };
  expect(()=>WaffraHomeTransactionCapture.narrowVerifiedModuleEdit(
   route:WaffraFinanceRoute.recurringCreateEditDeleteRestore,
   source:WaffraRuntimeFinanceBackend.verifiedEncrypted,
   snapshot:snapshot,
   witnessedValues:<String,Object?>{
    'entries':'[{"amount":100}]','waffra_recurring_v24':'[]',
   },
  ),throwsStateError);
 });
}

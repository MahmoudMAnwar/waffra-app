import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main(){
 test('M636 Home alone owns verified bank SMS finance writers; widget never debits',(){
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  final journal=File('lib/storage/waffra_home_finance_persistence.dart').readAsStringSync();
  final router=File('lib/storage/waffra_verified_finance_authority.dart').readAsStringSync();
  expect(File('lib/waffra_widget_capture.part.dart').existsSync(),isFalse);
  expect(native,contains('Intent(context, MainActivity::class.java)'));
  expect(native,contains('action = "waffra.ADD_TRANSACTION"'));
  expect(native,isNot(contains('commitConfirmedSms(')));
  expect(home,contains('await _ensureFinanceBound();'));
  expect(home,contains('_financeAuthority.commitConfirmedSms('));
  expect(home,contains('WaffraFinanceRoute.bulkSmsConfirmedSave'));
  expect(home,isNot(contains('_homeFinancePersistence.commitConfirmedLegacySms(')));
  expect(router,contains('legacy.commitConfirmedLegacySms('));
  expect(router,contains('sourceGuard.inspect()'));
  expect(router,contains('encryptedSession!.appendConfirmed('));
  expect(journal,contains('coordinator.withCurrentPreferences((prefs) async {'));
  expect(journal,contains('final existingHashes ='));
  expect(journal,contains('await journal.prepare('));
  expect(journal,contains('await journal.recover(prefs);'));
 });
 test('M636 native widget cannot switch finance source or start a second writer',(){
  final native=File('native/WaffraWidget.kt').readAsStringSync();
  final home=File('lib/main.dart').readAsStringSync();
  final binding=File('lib/storage/waffra_production_finance_authority_binding.dart').readAsStringSync();
  expect(native,isNot(contains('FirebaseFirestore.instance')));
  expect(native,isNot(contains('WaffraProductionFinanceAuthorityBinding.bind(')));
  expect(native,isNot(contains('journal.prepare(')));
  expect(native,contains('PendingIntent.FLAG_IMMUTABLE'));
  expect(home,contains('if(!mounted||!ready||waffraWidgetAction.value!=\'add\')return;'));
  expect(home,contains('unawaited(entrySheet())'));
  expect(home,contains('if(!startup.encrypted)await const WaffraLiveLegacyFinanceGuard().requireLegacySource(p)'));
  expect(binding,contains('sourceGuard.inspect()'));
  expect(binding,contains('WaffraProductionFinanceSource.manualRecoveryRequired'));
  expect(binding,contains('if (evidence == null)'));
  expect(binding,isNot(contains('WaffraEncryptedStore.openShadow(')));
 });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:waffra/storage/waffra_atomic_finance_snapshot.dart';
import 'package:waffra/storage/waffra_encrypted_goal_recycle.dart';
import 'package:waffra/storage/waffra_encrypted_receipt_vault.dart';
import 'package:waffra/storage/waffra_encrypted_store.dart';
import 'package:waffra/storage/waffra_finance_source_cutover_policy.dart';
import 'package:waffra/storage/waffra_fresh_encrypted_vault_bootstrap.dart';
import 'package:waffra/storage/waffra_fresh_finance_modules_repository.dart';
import 'package:waffra/storage/waffra_fresh_ledger_repository.dart';
import 'package:waffra/storage/waffra_unified_finance_writer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline encrypted finance survives Android cold restart',
      (tester) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    final root = await (await getTemporaryDirectory())
        .createTemp('waffra-finance-e2e-');
    final db = File('${root.path}/financial.sqlite');
    const key = 'device-only-encrypted-finance-secret-32';
    final current = DateTime.utc(2026,10,21,12);
    WaffraEncryptedStore? vault;
    try {
      const selector = WaffraFinanceSourceCutoverPolicy();
      expect(selector.resolve(const WaffraFinanceSourceEvidence(
        preferences:{},
        encryptedFileExists:false,
        encryptedKeyReadable:false,
        encryptedSqlActivationVerified:false,
        cooperatingWritersFrozen:true,
        encryptedFeatureAvailable:true,
      )),WaffraFinanceSourceStatus.freshCandidate);

      vault = WaffraEncryptedStore.openAt(db,key:key);
      final bootstrap = WaffraFreshEncryptedVaultBootstrap(
        store:vault,experimentalEnabled:true,
      );
      expect((await bootstrap.initialize(
        decision:WaffraFirstRunDecision.freshCandidate,
      )).isNew,true);

      final ledger = WaffraFreshLedgerRepository(
        store:vault,experimentalEnabled:true,
      );
      await ledger.add(const WaffraFreshLedgerEntry(
        id:'offline-expense',title:'تجربة',categorySnapshot:'مصروفات',
        amountMinor:1235,isIncome:false,
        occurredIso:'2026-10-21T14:00:00',
      ));
      await ledger.add(const WaffraFreshLedgerEntry(
        id:'offline-income',title:'Salary',categorySnapshot:'Salary',
        amountMinor:120000,isIncome:true,
        occurredIso:'2026-10-20T13:00:00',
      ));
      final goalRepo = WaffraFreshModulesRepository(
        store:vault,experimentalEnabled:true,
      );
      await goalRepo.save(WaffraFinanceModule.goals,{
        'id':'holiday-goal','name':'هدف جديد',
        'target':5000,'saved':100,
      });
      final trash = WaffraEncryptedGoalRecycle(
        store:vault,experimentalEnabled:true,
      );
      await trash.deleteGoal('holiday-goal',now:current);
      await trash.restore('holiday-goal',
          now:current.add(const Duration(days:2)));
      expect((await goalRepo.list(WaffraFinanceModule.goals))
          .single['saved'],0);

      final receipts = WaffraEncryptedReceiptVault(
        store:vault,experimentalEnabled:true,
      );
      await receipts.attachNewBatch(
        entryId:'offline-expense',
        images:[
          Uint8List.fromList([1,2,3,4]),
          Uint8List.fromList([10,11,12]),
        ],
      );
      expect((await receipts.readAll('offline-expense')).length,2);

      // The transition snapshot is deliberately separate from the
      // normalized-relational finance repository. This is NOT live UI cutover.
      final fullSnapshot=WaffraAtomicFinanceSnapshot(
        store:vault,experimentalEnabled:true,
      );
      await fullSnapshot.initializeEmpty();
      final writer=WaffraUnifiedFinanceWriter(
        writerDirectory:root,
        snapshot:fullSnapshot,
        experimentalEnabled:true,
      );
      final result=await writer.appendTransactions(
        records:[{
          'id':'synthetic-widget','title':'شراء عبر الودجت',
          'category':'تسوق','amount':4.25,'income':false,
          'date':'2026-10-21T14:00:00','receiptPath':null,
        }],
        messageHashes:[List.filled(64,'a').join()],
        userConfirmed:true,
      );
      expect(result.saved,1);
      expect((await fullSnapshot.read()).generation,1);
      expect((await ledger.totals()).count,2);

      // Even with a real encrypted file, active-source routing remains
      // unavailable until TWO activation witnesses are durably committed.
      expect(selector.resolve(const WaffraFinanceSourceEvidence(
        preferences:{},
        encryptedFileExists:true,
        encryptedKeyReadable:true,
        encryptedSqlActivationVerified:false,
        cooperatingWritersFrozen:true,
        encryptedFeatureAvailable:true,
      )),WaffraFinanceSourceStatus.recoveryRequired);

      await vault.close();
      vault = null;
      final prefix = await db.openRead(0,16).toList();
      expect(prefix.expand((part)=>part).toList(),
          isNot([83,81,76,105,116,101,32,102,111,114,109,97,116,32,51,0]));
      vault = WaffraEncryptedStore.openAt(db,key:key);
      final reopenedLedger=WaffraFreshLedgerRepository(
        store:vault,experimentalEnabled:true,
      );
      final totals=await reopenedLedger.totals();
      expect(totals.count,2);
      expect(totals.incomeMinor,120000);
      expect(totals.expenseMinor,1235);
      expect((await WaffraEncryptedReceiptVault(
        store:vault,experimentalEnabled:true,
      ).readAll('offline-expense')).map((r)=>r.bytes.join(',')).toSet(),
          {'1,2,3,4','10,11,12'});
      expect((await WaffraFreshModulesRepository(
        store:vault,experimentalEnabled:true,
      ).list(WaffraFinanceModule.goals)).single['saved'],0);
      expect((await WaffraAtomicFinanceSnapshot(
        store:vault,experimentalEnabled:true,
      ).read()).generation,1);
    } finally {
      await vault?.close();
      if(await root.exists())await root.delete(recursive:true);
    }
  });
}

"""M923: original secure goal/due writer regression must read registered Dart parts."""
from pathlib import Path
import unittest
from waffra_home_source import read_waffra_home_source

ROOT=Path(__file__).resolve().parents[2]
class M923RegisteredGoalDueWriterTest(unittest.TestCase):
    def test_original_m362_preserves_qa_and_fails_closed_on_part_wiring(self):
        t=(ROOT / 'test/m362_goal_wallet_due_settlement_test.dart').read_text(encoding='utf-8')
        part=(ROOT / 'lib/waffra_home_finance_persistence_due.part.dart').read_text(encoding='utf-8')
        main=(ROOT / 'lib/main.dart').read_text(encoding='utf-8')
        self.assertIn("import 'support/waffra_main_source.dart';",t)
        self.assertIn('final main=readWaffraMainSourceForContracts();',t)
        self.assertNotIn("final main=File('lib/main.dart').readAsStringSync();",t)
        self.assertIn("part 'waffra_home_finance_persistence_due.part.dart';",main)
        self.assertIn("part of 'main.dart';",part)
        for witness in (
            "WaffraGoalDueAllocation.allocate(",
            "sourceType:'goal_due'",
            "recurring[scheduleIndex]=currentSchedule.single.copy(active:false)",
            "await persist(route:WaffraFinanceRoute.transactionEdit,",
            "userConfirmed:true",
            "if(entries.any((e)=>e.id==id))continue;",
        ):
            self.assertIn(witness,t)
            self.assertIn(witness,part)
            self.assertIn(witness,read_waffra_home_source(ROOT))
        self.assertIn("if(r.linkedGoalId!=null)continue;",t)
if __name__=='__main__':
    unittest.main()

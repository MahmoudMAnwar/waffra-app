"""M951 functionality audit cannot count missing, duplicate or disabled tests."""
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'/'qa'))
import m951_last_functional_gap_audit as gate

class M951FunctionalGapAuditTest(unittest.TestCase):
 def test_synthetic_app_code_is_exercised_by_26_unique_cases(self):
  result=gate.audit()
  self.assertEqual(result['new_M951_functional_case_count'],26)
  self.assertEqual(result['new_PR_functional_case_total'],115)
  self.assertEqual(len(set(result['test_ids'])),26)
  self.assertFalse(result['physical_android_verified'])

 def test_missing_case_and_disabled_case_are_not_silently_counted(self):
  with tempfile.TemporaryDirectory() as d:
   dst=Path(d)/gate.SUITE
   dst.parent.mkdir(parents=True,exist_ok=True)
   shutil.copy2(ROOT/gate.SUITE,dst)
   original=dst.read_text()
   dst.write_text(original.replace("test('M951-A02","test('missing-A02"),encoding='utf-8')
   with self.assertRaises(ValueError):
    gate.audit(Path(d))
   dst.write_text(original+"\n// skip: true\n",encoding='utf-8')
   with self.assertRaises(ValueError):
    gate.audit(Path(d))

if __name__=='__main__':
 unittest.main()

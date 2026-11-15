"""Mutation checks: M950 ID count, no duplicates, no missing or skipped cases."""
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'/'qa'))
import m950_extended_functional_audit as gate

class M950CaseAuditTest(unittest.TestCase):
 def test_46_new_usable_functional_cases(self):
  report=gate.audit()
  self.assertEqual(report['new_functional_case_count'],46)
  self.assertEqual(report['new_functional_total_with_M949'],89)
  self.assertEqual(len(set(report['all_unique_ids'])),46)
  self.assertFalse(report['device_android_verified'])

 def test_missing_user_scenario_blocks_release_gate(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)
   for file in gate.SUITES:
    target=path/file
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/file,target)
   f=path/next(iter(gate.SUITES))
   f.write_text(f.read_text().replace("test('M950-P01","test('NO_CASE"),
    encoding='utf-8')
   with self.assertRaises(ValueError):
    gate.audit(path)

 def test_second_copy_of_one_case_fails_by_distinct_id(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)
   for file in gate.SUITES:
    target=path/file
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/file,target)
   f=path/next(iter(gate.SUITES))
   f.write_text(f.read_text().replace("test('M950-P02","test('M950-P01"),
    encoding='utf-8')
   with self.assertRaises(ValueError):
    gate.audit(path)

 def test_skipped_scenario_never_counts_as_new(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)
   for file in gate.SUITES:
    target=path/file
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/file,target)
   f=path/next(iter(gate.SUITES))
   f.write_text(f.read_text()+"\n// skip: true\n",encoding='utf-8')
   with self.assertRaises(ValueError):
    gate.audit(path)

if __name__=='__main__':
 unittest.main()

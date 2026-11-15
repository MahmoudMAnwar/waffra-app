"""Mutation tests for M949 exact 43-case non-duplicate functional registry."""
from __future__ import annotations
import shutil
import sys
import tempfile
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'scripts'/'qa'))
import m949_unique_functional_case_audit as audit

class M949UniqueFunctionalAuditTest(unittest.TestCase):
 def test_every_new_case_is_real_unique_and_ordered(self):
  report=audit.audit()
  self.assertEqual(report['unique_case_count'],43)
  self.assertEqual(report['by_area'],{
   'accounts_and_transfers':14,
   'goals_recurring_categories':17,
   'home_filter_intersections':12,
  })
  self.assertEqual(len(set(report['ids'])),43)
  self.assertFalse(report['physical_android_uat_verified'])

 def test_deleting_one_new_case_cannot_pass(self):
  with tempfile.TemporaryDirectory() as d:
   dest=Path(d)
   for path in audit.SUITES:
    f=dest/path
    f.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/path,f)
   path=next(iter(audit.SUITES))
   f=dest/path
   f.write_text(f.read_text().replace("test('M949-A01","test('REMOVED-A01"),
    encoding='utf-8')
   with self.assertRaisesRegex(ValueError,'must contain'):
    audit.audit(dest)

 def test_duplicate_case_id_cannot_inflate_count(self):
  with tempfile.TemporaryDirectory() as d:
   dest=Path(d)
   for path in audit.SUITES:
    f=dest/path
    f.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/path,f)
   path=next(iter(audit.SUITES))
   f=dest/path
   s=f.read_text()
   s=s.replace("test('M949-A02","test('M949-A01")
   f.write_text(s,encoding='utf-8')
   with self.assertRaisesRegex(ValueError,'blocked'):
    audit.audit(dest)

 def test_skip_cannot_be_disguised_as_new_functional_coverage(self):
  with tempfile.TemporaryDirectory() as d:
   dest=Path(d)
   for path in audit.SUITES:
    f=dest/path
    f.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/path,f)
   f=dest/next(iter(audit.SUITES))
   f.write_text(f.read_text()+'\n// skip: true\n',encoding='utf-8')
   with self.assertRaisesRegex(ValueError,'skipped'):
    audit.audit(dest)

if __name__=='__main__':
 unittest.main()

import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from m172_accessibility_review import contrast, inspect

ROOT = Path(__file__).resolve().parents[2]

class M172AccessibilityTests(unittest.TestCase):
    def test_wcff_contrast(self):
        self.assertAlmostEqual(contrast("#FFFFFF","#000000"),21.0,places=2)
        self.assertLess(contrast("#777777","#777777"),1.01)
        self.assertGreaterEqual(contrast("#FFFFFF","#191D1B"),4.5)

    def test_source_rtl_system_dark_tajawal_and_motion_regression(self):
        result = inspect(ROOT)
        self.assertTrue(result["sourceConsistencyPassed"],result["checks"])
        self.assertFalse(result["physicalAccessibilityValidated"])
        self.assertIn("talkback_semantics_and_keyboard_navigation_unverified",
                      result["knownReviewItems"])

if __name__ == "__main__":
    unittest.main()

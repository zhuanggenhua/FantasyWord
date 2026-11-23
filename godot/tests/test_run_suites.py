"""Regression tests for the source-free classifier, independent of Godot."""
import unittest
from run_suites import classify, EXPECTED_SOURCE_FREE, INDICATOR, INDICATOR_MISSING


class TestSuiteResults(unittest.TestCase):
    def test_skip_is_a_specific_suite_and_marker(self):
        suite = "test_clickmovetest_control_panel.gd"
        reason, = EXPECTED_SOURCE_FREE[suite]
        self.assertEqual(classify(suite, 0, reason, True), "SKIP")
        self.assertEqual(classify(suite, 0, reason, False), "FAIL")
        self.assertEqual(classify("other.gd", 0, reason, True), "FAIL")
        self.assertEqual(classify(suite, 0, reason + "\nSKIP unknown", True), "FAIL")
        self.assertEqual(classify(suite, 0, reason + "\nPASS 8/8", True), "PARTIAL")

    def test_real_failures_do_not_turn_into_skips(self):
        self.assertEqual(classify("other.gd", 1, "PASS 8/8", True), "FAIL")
        self.assertEqual(classify("other.gd", 0, "PASS 8/8\nSCRIPT ERROR: test", True), "FAIL")
        self.assertEqual(classify("other.gd", 0, "no result", True), "FAIL")
        self.assertEqual(classify("other.gd", 0, "PASS 0/0", True), "FAIL")

    def test_indicator_exit_two_only_means_expected_missing_art(self):
        self.assertEqual(classify(INDICATOR, 2, INDICATOR_MISSING, True), "SKIP")
        self.assertEqual(classify(INDICATOR, 2, INDICATOR_MISSING, False), "FAIL")
        self.assertEqual(classify(INDICATOR, 2, INDICATOR_MISSING + "\nERROR: invalid data", True), "FAIL")
        self.assertEqual(classify("other.gd", 2, INDICATOR_MISSING, True), "FAIL")

    def test_custom_completion_marker_validates_counts(self):
        suite = "test_flamethrower_timeline.gd"
        self.assertEqual(classify(suite, 0, "喷火时间轴：15/15", True), "PASS")
        self.assertEqual(classify(suite, 0, "喷火时间轴：14/15", True), "FAIL")


if __name__ == "__main__":
    unittest.main()

import unittest

from finalize_compact64 import verify_case_metrics


class Compact64GateTests(unittest.TestCase):
    def setUp(self):
        self.valid = {
            "pass_fail": "PASS", "injected_flits": "55000", "delivered_flits": "55000",
            "missing_expected_flits": "0", "unexpected_flits": "0", "timeout_hit": "0",
            "warmup_original_events": "1000", "measurement_original_events": "10000",
            "measurement_offered_flits": "50000", "measurement_delivered_flits": "49999",
            "measurement_backlog_flits": "1",
        }

    def test_full_drain_accepts_measurement_backlog(self):
        verify_case_metrics(self.valid, "synthetic")

    def test_rejects_incomplete_final_delivery(self):
        bad = dict(self.valid, delivered_flits="54999")
        with self.assertRaises(ValueError):
            verify_case_metrics(bad, "synthetic")

    def test_rejects_errors(self):
        bad = dict(self.valid, unexpected_flits="1")
        with self.assertRaises(ValueError):
            verify_case_metrics(bad, "synthetic")

    def test_rejects_zero_or_inconsistent_denominator(self):
        bad = dict(self.valid, measurement_offered_flits="0")
        with self.assertRaises(ValueError):
            verify_case_metrics(bad, "synthetic")
        bad = dict(self.valid, measurement_delivered_flits="50001")
        with self.assertRaises(ValueError):
            verify_case_metrics(bad, "synthetic")


if __name__ == "__main__":
    unittest.main()

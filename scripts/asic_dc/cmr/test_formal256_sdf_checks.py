import importlib.util
from pathlib import Path
import tempfile
import unittest

s = importlib.util.spec_from_file_location("pairing", Path(__file__).with_name("formal256_sdf_checks.py"))
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)


class PairingTest(unittest.TestCase):
    def test_exact_pairing_preserves_negative_triplets(self):
        text = """(TIMINGCHECK
(RECOVERY (posedge CDN) (COND D_SDFCHK (posedge CP)) (0.01:0.02:0.03))
(HOLD (posedge CDN) (COND D_SDFCHK (posedge CP)) (-0.03:-0.02:-0.01))
(SETUP (posedge D) (posedge CP) (0.1:0.2:0.3))
(HOLD (posedge D) (posedge CP) (-0.1:-0.1:-0.1))
(WIDTH (posedge CP) (0.2:0.2:0.2)))"""
        out, counts = m.pair_block(text)
        self.assertEqual(counts["RECREM"], 1)
        self.assertEqual(counts["SETUPHOLD"], 1)
        self.assertIn("(-0.03:-0.02:-0.01)", out)
        self.assertIn("(WIDTH (posedge CP) (0.2:0.2:0.2))", out)

    def test_edges_and_conditions_are_not_guessed(self):
        for second in ("(negedge D) (posedge CP)", "(posedge D) (COND X (posedge CP))"):
            with self.assertRaises(ValueError):
                m.pair_block(f"(TIMINGCHECK (SETUP (posedge D) (posedge CP) (1)) (HOLD {second} (2)))")

    def test_no_overwrite_and_delay_bytes_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            src, dst = Path(d) / "a.sdf", Path(d) / "b.sdf"
            original = '(DELAYFILE\n(SDFVERSION "OVI 2.1")\n(DELAY (IOPATH D Q (0.123:0.234:0.345)))\n(TIMINGCHECK (SETUP (posedge D) (posedge CP) (1)) (HOLD (posedge D) (posedge CP) (-1)))\n)\n'
            src.write_text(original)
            m.convert(src, dst)
            self.assertEqual(src.read_text(), original)
            self.assertIn('(DELAY (IOPATH D Q (0.123:0.234:0.345)))\n', dst.read_text())
            with self.assertRaises(ValueError):
                m.convert(src, src)


if __name__ == "__main__":
    unittest.main()

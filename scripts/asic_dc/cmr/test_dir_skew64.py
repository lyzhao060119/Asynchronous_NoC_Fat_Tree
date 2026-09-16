#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))

from date_v3.canonical_trace import dir_skew1_sources, generate_trace, pe_xy  # noqa: E402


class DirectionSkewTraceTest(unittest.TestCase):
    def test_source_mapping_destination_and_metadata(self):
        trace = generate_trace("DIR-SKEW1", seed=202701, nodes=64, load_point=100)
        expected = {(2*a+1) + 8*(2*b+1) for a in range(4) for b in range(4)}
        self.assertEqual(set(dir_skew1_sources()), expected)
        self.assertEqual(set(e["source"] for e in trace["events"]), expected)
        for event in trace["events"]:
            src, dst = event["source"], event["destinations"][0]
            sx, sy = pe_xy(src, 8)
            dx, dy = pe_xy(dst, 8)
            self.assertNotEqual((sx // 2, sy // 2), (dx // 2, dy // 2))
        header = trace["header"]
        self.assertEqual(header["active_sources"], 16)
        self.assertEqual(header["source_child_direction"], 0)
        self.assertEqual(header["source_rate_multiplier"], 4)
        self.assertEqual(header["load_normalization"], "all_64_ports")

    def test_four_x_rate_and_determinism(self):
        a = generate_trace("DIR-SKEW1", seed=202701, nodes=64, load_point=100)
        b = generate_trace("DIR-SKEW1", seed=202701, nodes=64, load_point=100)
        self.assertEqual(a, b)
        # Same pairs and scheduling RNG seed; 4x exponential rate yields
        # approximately quarter-cycle readiness, modulo integer rounding.
        from date_v3.canonical_trace import draw_pairs, schedule_pairs, seed_mix
        from random import Random
        pairs = draw_pairs("dir_skew1_64", 64, 11000, Random(seed_mix(202701, 64, 0, 1)))
        ready_100 = schedule_pairs(pairs, nodes=64, packet_flits=5, load_point=100,
                                   rng=Random(seed_mix(202701, 64, 0, 100)))
        self.assertEqual(a["events"][5000]["ready_cycle"],
                         schedule_pairs(pairs, nodes=64, packet_flits=5, load_point=400,
                                        rng=Random(seed_mix(202701, 64, 0, 100)))[5000])
        self.assertGreater(ready_100[5000], a["events"][5000]["ready_cycle"])


if __name__ == "__main__":
    unittest.main()

"""Focused regression for physical packet identity and paired multicast cases."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
import csv

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "DATE_paper/experiments/scripts"))
from date_v3 import canonical_trace as ct

spec = importlib.util.spec_from_file_location("campaign", Path(__file__).with_name("formal256_campaign.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class CampaignTest(unittest.TestCase):
    def test_metrics_reject_duplicates_and_unchecked_timing(self):
        old = m.modules
        m.modules = lambda root: ct
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                trace = m.trace_for(tmp, "ALL-MULTICAST-AABB", 202701, 5, True)
                trace["events"] = [trace["events"][0]]
                e = trace["events"][0]
                e.update(phase="measurement", ready_cycle=0, destinations=[1, 2])
                trace["header"].update(warmup_original_events=0, measurement_original_events=1)
                stem = "test"
                ct.dump_jsonl(trace, root / "traces" / f"{stem}.jsonl")
                m.save(root / "sidecars/test_native.json", dict(
                    input_flits=5, expected_copy_flits=10,
                    packets=[dict(pkt_seq=0, event_index=0, destinations=[1, 2])]))
                log = root / "logs/Mesh256/test"
                log.mkdir(parents=True)
                (log / "run.log").write_text("TB_RESULT PASS\n")
                latency = "pkt_seq,port,tail_egress_req_ps\n0,1,200\n0,2,300\n"
                (log / "latency.csv").write_text(latency)
                annotation = dict(errors=0, warnings=0, missing_timing_checks=0,
                                  negative_separate_checks_limited=False)
                m.save(root / "work/Mesh256/annotation_status.json", annotation)
                raw = dict(pass_fail="PASS", measurement_start_ps=100, measurement_end_ps=1100,
                           missing_expected_flits=0, unexpected_flits=0, timeout_hit=0,
                           delivered_mflit_port_s=1, measurement_delivered_flits=10,
                           injected_flits=5, delivered_flits=10)
                result = root / "results/Mesh256/test.csv"
                result.parent.mkdir(parents=True)
                with result.open("w", newline="") as f:
                    writer = csv.DictWriter(f, fieldnames=list(raw))
                    writer.writeheader()
                    writer.writerow(raw)
                row = m.collect_case(root, "Mesh256", stem)
                self.assertTrue(row["valid"])
                self.assertAlmostEqual(row["mean_last_destination_ns"], .2)
                self.assertAlmostEqual(row["mean_first_destination_ns"], .1)
                raw["delivered_flits"] = 11
                with result.open("w", newline="") as f:
                    writer = csv.DictWriter(f, fieldnames=list(raw))
                    writer.writeheader()
                    writer.writerow(raw)
                self.assertFalse(m.collect_case(root, "Mesh256", stem)["valid"])
                raw["delivered_flits"] = 10
                with result.open("w", newline="") as f:
                    writer = csv.DictWriter(f, fieldnames=list(raw))
                    writer.writeheader()
                    writer.writerow(raw)
                (log / "latency.csv").write_text(latency + "0,2,300\n")
                with self.assertRaises(ValueError):
                    m.collect_case(root, "Mesh256", stem)
                (log / "latency.csv").write_text(latency)
                annotation["negative_separate_checks_limited"] = True
                m.save(root / "work/Mesh256/annotation_status.json", annotation)
                self.assertFalse(m.collect_case(root, "Mesh256", stem)["valid"])
                annotation["negative_separate_checks_limited"] = False
                m.save(root / "work/Mesh256/annotation_status.json", annotation)
                (log / "run.log").write_text("TB_RESULT PASS\nTiming violation\n")
                self.assertFalse(m.collect_case(root, "Mesh256", stem)["valid"])
        finally:
            m.modules = old

    def test_identity_wrap_and_payload_type(self):
        for seq in (0, 16383, 16384, 65535, 65536, 131071):
            for index in range(1, 5):
                flit = m.encode(seq, 255, [0, 0, 1, 1], index)
                decoded = ((flit >> 2 & 15) << 14) | (flit >> 12 & 16383)
                self.assertEqual(decoded, seq)
                self.assertEqual(flit >> 9 & 7, index)
                self.assertEqual(flit >> 6 & 7, 5)
                self.assertEqual(flit >> 26 & 3, int(index == 4))
        with self.assertRaises(ValueError):
            m.encode(m.MAX_PACKETS, 0, [0, 0, 1, 1], 1)

    def test_trace_and_native_repeated_equivalence(self):
        old = m.modules
        m.modules = lambda root: ct
        try:
            with tempfile.TemporaryDirectory() as tmp:
                m.ROOT = tmp
                for bench in m.BENCHMARKS:
                    trace = m.trace_for(tmp, bench, 202701, 5, True)
                    self.assertEqual(trace, m.trace_for(tmp, bench, 202701, 5, True))
                    m.audit(trace)
                    for repeated in (False, True):
                        paths = m.materialize(tmp, trace, bench, repeated)
                        a = Path(paths["Mesh256"]["path"]).read_text().splitlines()[1:]
                        b = Path(paths["M16_256"]["path"]).read_text().splitlines()[1:]
                        self.assertEqual(a, b)
                        mode = "repeated" if repeated else "native"
                        side = json.loads((Path(tmp) / "sidecars" / f"{bench}_{mode}.json").read_text())
                        unions = {}
                        seen = set()
                        for packet in side["packets"]:
                            self.assertNotIn(packet["pkt_seq"], seen)
                            seen.add(packet["pkt_seq"])
                            ei = packet["event_index"]
                            self.assertEqual(packet["ready_cycle"], trace["events"][ei]["ready_cycle"])
                            unions.setdefault(ei, set()).update(packet["destinations"])
                        for event in trace["events"]:
                            self.assertEqual(unions[event["event_index"]], set(event["destinations"]))
        finally:
            m.modules = old


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Unit checks for DATE V3 traffic, Tmax, saturation, and H-REP split."""
from __future__ import annotations

import sys
import tempfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

import json

from date_v3.canonical_trace import (  # noqa: E402
    PACKET_FLITS,
    generate_trace,
    load_seeds,
    same_l2_subtree,
    width_of,
)
from date_v3.hrep_policy import cluster_of_pe, prop_packet, split_dest_set  # noqa: E402
from date_v3.materialize_case import materialize, write_case  # noqa: E402
from date_v3.saturation import next_fine_loads, saturation_point  # noqa: E402
from date_v3.schema import validate_required  # noqa: E402
from date_v3.tmax import summarize_tmax, tmax_by_original_event, tmax_ns  # noqa: E402


def assert_true(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def test_seeds() -> None:
    assert_true(load_seeds() == [202701, 202702, 202703], "frozen seeds")


def test_bf_stress() -> None:
    trace = generate_trace("BF-STRESS64", seed=202701, smoke=True, load_point=0.10)
    header = trace["header"]
    validate_required(header, label="bf header")
    assert_true(header["packet_flits"] == PACKET_FLITS, "5-flit")
    assert_true(header["warmup_original_events"] == 4, "smoke warmup")
    assert_true(header["measurement_original_events"] == 8, "smoke measurement")
    width = width_of(header["nodes"])
    for event in trace["events"]:
        validate_required(event, label=event["original_event_id"])
        src = event["source"]
        dest = event["destinations"][0]
        assert_true(src != dest, "src != dst")
        assert_true(not same_l2_subtree(src, dest, width), "not same L2")
        assert_true(event["packet_flits"] == 5, "event 5-flit")


def test_paired_thin_prop() -> None:
    a = generate_trace("BF-STRESS64", seed=202701, smoke=True, load_point=0.10)
    b = generate_trace("BF-STRESS64", seed=202701, smoke=True, load_point=0.10)
    dests_a = [(e["source"], tuple(e["destinations"])) for e in a["events"]]
    dests_b = [(e["source"], tuple(e["destinations"])) for e in b["events"]]
    assert_true(dests_a == dests_b, "paired traces share src/dst")


def test_topo_ur_scales() -> None:
    for nodes in (64, 256, 1024):
        trace = generate_trace("TOPO-UR", seed=202702, nodes=nodes, smoke=True, load_point=0.05)
        assert_true(trace["header"]["nodes"] == nodes, "nodes")
        for event in trace["events"]:
            assert_true(event["source"] != event["destinations"][0], "ur src!=dst")
            assert_true(len(event["destinations"]) == 1, "unicast")


def test_xmc_spread() -> None:
    for spread in (1, 4, 16):
        trace = generate_trace(
            "XMC-F16", seed=202701, nodes=1024, spread=spread, smoke=True
        )
        width = 32
        for event in trace["events"]:
            dests = event["destinations"]
            clusters = {cluster_of_pe(d, width) for d in dests}
            assert_true(event["source"] not in dests, "no self dest")
            if spread == 1:
                assert_true(len(clusters) == 1, "S=1 one cluster")
                assert_true(len(dests) == 16, "S=1 F=16")
            elif spread == 4:
                assert_true(len(clusters) == 4, "S=4 four clusters")
                assert_true(len(dests) == 16, "S=4 F=16")
            else:
                assert_true(len(clusters) == 16, "S=16 sixteen clusters")
                assert_true(len(dests) == 16, "S=16 F=16")


def test_xmc10_fraction() -> None:
    trace = generate_trace("XMC10-G", seed=202703, nodes=1024, smoke=False, load_point=0.10)
    n = len(trace["events"])
    mc = sum(1 for event in trace["events"] if event["multicast"])
    frac = mc / n
    assert_true(n == 11000, "warmup+meas")
    assert_true(0.05 < frac < 0.15, "about 10%% multicast, got %s" % frac)


def test_hrep_split() -> None:
    dests = [0, 8, 256, 264]
    prop = prop_packet("e0", 1, dests, 32)
    hrep = split_dest_set("e0", 1, dests, cluster_grid=4)
    assert_true(len(prop["destinations"]) == 4, "prop one packet dests")
    assert_true(len(hrep) > 1, "hrep splits clusters")
    assert_true(all(p["original_event_id"] == "e0" for p in hrep), "keep original id")
    recovered = sorted(d for p in hrep for d in p["destinations"])
    assert_true(recovered == sorted(dests), "hrep covers intended dests")


def test_materialize_64() -> None:
    trace = generate_trace("BF-STRESS64", seed=202701, smoke=True, load_point=0.10)
    case = materialize(trace, top_lanes=1, hrep=False)
    assert_true(len(case["event_map"]) == 12, "12 original events -> 12 packets")
    flits = [row for row in case["inputs"] if row[0] >= 0]
    assert_true(len(flits) == 12 * 5, "5 flits each")
    assert_true(all("flit" in row[4] for row in case["inputs"]), "flit comments")
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "bf.case"
        write_case(case, path)
        text = path.read_text(encoding="utf-8")
        assert_true("event_map" in text, "event_map")
        assert_true("meta top_lanes 1" in text, "thin top lanes")
        assert_true(path.with_suffix(".packets.json").is_file(), "packets sidecar")


def test_tmax() -> None:
    assert_true(tmax_ns(12.5, 2.0) == 10.5, "tmax formula")
    rows = [
        {"original_event_id": "e1", "phase": "warmup", "t_head_inject": 0.0, "t_last_tail": 9.0},
        {"original_event_id": "e2", "phase": "measurement", "t_head_inject": 1.0, "t_last_tail": 4.0, "port": 1},
        {"original_event_id": "e2", "phase": "measurement", "t_head_inject": 1.0, "t_last_tail": 7.0, "port": 2},
        {"original_event_id": "e3", "phase": "measurement", "t_head_inject": 2.0, "t_last_tail": 5.0, "port": 3},
    ]
    rec = tmax_by_original_event(rows)
    assert_true(len(rec) == 2, "drop warmup")
    by_id = {row["original_event_id"]: row["tmax_ns"] for row in rec}
    assert_true(by_id["e2"] == 6.0, "last dest tail")
    summary = summarize_tmax(rec)
    assert_true(summary["count"] == 2, "two measurement events")


def test_saturation() -> None:
    rows = []
    for seed in (202701, 202702, 202703):
        for load, err in ((0.10, 0), (0.20, 0), (0.30, 1)):
            rows.append(
                {
                    "seed": seed,
                    "offered_load": load,
                    "errors": err,
                    "drainable": True,
                    "backlog_growth": False,
                    "delivered_throughput": load * 0.8,
                    "mean_latency": 10.0 + load,
                }
            )
    sat = saturation_point(rows, seeds=(202701, 202702, 202703))
    assert_true(sat is not None and sat["offered_load"] == 0.20, "sat at 0.20")
    fine = next_fine_loads(rows, seeds=(202701, 202702, 202703))
    assert_true(fine[0] == 0.18, "fine below knee")
    assert_true(0.21 in fine and fine[-1] == 0.29, "fine between 0.20 and 0.30")


def test_mesh_intercluster() -> None:
    trace = generate_trace("MESH-INTERCLUSTER-UR", seed=202701, smoke=True)
    width = 32
    for event in trace["events"]:
        src_c = cluster_of_pe(event["source"], width)
        dst_c = cluster_of_pe(event["destinations"][0], width)
        assert_true(src_c != dst_c, "inter-cluster")


def test_paper_warmup_measurement() -> None:
    trace = generate_trace("BF-STRESS64", seed=202701, smoke=False, load_point=0.10)
    header = trace["header"]
    assert_true(header["warmup_original_events"] == 1000, "warmup 1000")
    assert_true(header["measurement_original_events"] == 10000, "measurement 10000")
    assert_true(len(trace["events"]) == 11000, "11000 original events")
    assert_true(all(e["phase"] == "warmup" for e in trace["events"][:1000]), "warmup phase")
    assert_true(all(e["phase"] == "measurement" for e in trace["events"][1000:]), "meas phase")
    assert_true(all(e["packet_flits"] == 5 for e in trace["events"]), "5-flit locked")


def test_three_seeds_distinct() -> None:
    traces = [
        generate_trace("TOPO-UR", seed=seed, smoke=True, load_point=0.10)
        for seed in load_seeds()
    ]
    dests = [tuple((e["source"], tuple(e["destinations"])) for e in t["events"]) for t in traces]
    assert_true(len(set(dests)) == 3, "three frozen seeds are not identical")


def test_xmc_f16_samples() -> None:
    trace = generate_trace("XMC-F16", seed=202701, nodes=1024, spread=4, smoke=False)
    assert_true(trace["header"]["measurement_original_events"] >= 32, ">=32 samples")
    assert_true(trace["header"]["warmup_original_events"] == 0, "XMC-F16 no warmup")
    assert_true(len(trace["events"]) >= 32, "32 original events")
    width = 32
    for event in trace["events"]:
        clusters = {cluster_of_pe(d, width) for d in event["destinations"]}
        assert_true(len(clusters) == 4, "S=4 four clusters")
        assert_true(len(event["destinations"]) == 16, "F=16")


def test_route_oracle_64() -> None:
    from date_v3.route_oracle import deliver_flat_mesh, deliver_unicast

    for sy in range(8):
        for sx in range(8):
            for dy in range(8):
                for dx in range(8):
                    if sx == dx and sy == dy:
                        continue
                    result = deliver_unicast(sx, sy, dx, dy, 1)
                    assert_true(not result["loss"], "64 loss %s->%s" % ((sx, sy), (dx, dy)))
                    assert_true(not result["duplicate"], "64 dup")
                    assert_true(not result["cycle"], "64 cycle")
                    assert_true(len(result["router_traversal"]) > 0, "traversal recorded")
    fm = deliver_flat_mesh(0, 0, 7, 7, 8)
    assert_true(not fm["loss"] and fm["mesh_hops"] >= 1, "FM8 corner")
    from date_v3.route_oracle import deliver_unicast as du

    far = du(0, 0, 15, 15, 2)
    assert_true(not far["loss"], "256 corner")
    assert_true(far["top_mesh_injection"] >= 1, "cross-tier inject")


def test_materialize_256_keycase() -> None:
    from date_v3.canonical_trace import generate_directed_keycase

    trace = generate_directed_keycase(nodes=256, seed=202701, random_unicasts=8)
    case = materialize(trace, top_lanes=0, hrep=False, routing="quadtree")
    assert_true(case["case_format"] == "keycase", "256 is keycase")
    assert_true(len(case["expects"]) == 0, "no 256-bit masks")
    assert_true(len(case["expect_ports"]) == len(case["packets"]) * 5, "dest-list expects")
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "k256.case"
        write_case(case, path)
        text = path.read_text(encoding="utf-8")
        assert_true("expect_port" in text, "expect_port")
        assert_true("meta format keycase" in text, "format")
        assert_true(path.with_suffix(".model.json").is_file(), "model input")


def test_event_record_tmax() -> None:
    from date_v3.event_record import assemble_event_records, run_metrics, validate_event_record

    with tempfile.TemporaryDirectory() as tmp:
        packets = Path(tmp) / "p.json"
        packets.write_text(
            json.dumps(
                {
                    "packets": [
                        {
                            "pkt_seq": 0,
                            "original_event_id": "e000000",
                            "packet_id": "e000000#0",
                            "phase": "warmup",
                            "source": 0,
                            "intended_destinations": [1],
                            "traversal": {"router_traversal": ["L1(0,0)"], "top_mesh_injection": 0},
                        },
                        {
                            "pkt_seq": 1,
                            "original_event_id": "e000001",
                            "packet_id": "e000001#0",
                            "phase": "measurement",
                            "source": 0,
                            "intended_destinations": [1, 2],
                            "traversal": {
                                "router_traversal": ["L1(0,0)", "L2(0,0)"],
                                "link_traversal": ["L1->L2"],
                                "top_mesh_injection": 0,
                                "top_mesh_link_traversal": 0,
                            },
                        },
                    ]
                }
            ),
            encoding="utf-8",
        )
        recs = assemble_event_records(
            packets_json=packets,
            deliveries=[
                {"pkt_seq": 0, "port": 1, "t_head_inject": 1.0, "t_last_tail": 4.0},
                {"pkt_seq": 1, "port": 1, "t_head_inject": 10.0, "t_last_tail": 13.0},
                {"pkt_seq": 1, "port": 2, "t_head_inject": 10.0, "t_last_tail": 16.5},
                {"pkt_seq": 1, "port": 99, "t_head_inject": 10.0, "t_last_tail": 40.0},
            ],
        )
        assert_true(len(recs) == 1, "drop warmup")
        validate_event_record(recs[0])
        assert_true(recs[0]["tmax_ns"] == 6.5, "last dest tail - head inject")
        assert_true(99 in recs[0]["delivered_destinations"], "rect extras recorded")
        assert_true(recs[0]["t_last_tail"] == 16.5, "Tmax ignores extra rect dest")
        metrics = run_metrics(recs, v3_summary={"drainable": True, "timeout": False, "errors": 0})
        assert_true(metrics["drainable"], "drainable")
        assert_true(not metrics["backlog_growth"], "no backlog")


def test_stats_and_fine_loads() -> None:
    from date_v3.stats import bootstrap_ci, seed_summary
    from date_v3.saturation import coarse_loads, hrep_common_tmax_load, next_coarse_load, throughput_plateau

    rows = [
        {"seed": 202701, "delivered_throughput": 0.20},
        {"seed": 202702, "delivered_throughput": 0.22},
        {"seed": 202703, "delivered_throughput": 0.24},
    ]
    summary = seed_summary(rows, value_key="delivered_throughput", seeds=(202701, 202702, 202703))
    assert_true(abs(summary["mean"] - 0.22) < 1e-12, "mean")
    assert_true(summary["sd"] is not None and summary["sd"] > 0, "sd")
    ci = bootstrap_ci([float(i) for i in range(32)], seed=1)
    assert_true(ci["low"] is not None and ci["high"] >= ci["low"], "bootstrap")
    assert_true(coarse_loads()[0] == 0.0, "zero load first")
    assert_true(hrep_common_tmax_load(0.40) == 0.10, "0.25 x H-REP sat")
    assert_true(next_coarse_load([], last_ok=True, plateau=False) == 0.0, "start at zero")
    assert_true(next_coarse_load([0.0], last_ok=True, plateau=False) == 0.02, "next coarse")
    assert_true(next_coarse_load([0.50], last_ok=True, plateau=False) is None, "end of coarse")
    assert_true(next_coarse_load([0.10], last_ok=False, plateau=False) is None, "stop on fail")
    plateau_rows = []
    for seed in (202701, 202702, 202703):
        plateau_rows.append(
            {
                "seed": seed,
                "offered_load": 0.20,
                "errors": 0,
                "drainable": True,
                "backlog_growth": False,
                "delivered_throughput": 0.160,
                "mean_latency": 10.0,
            }
        )
        plateau_rows.append(
            {
                "seed": seed,
                "offered_load": 0.30,
                "errors": 0,
                "drainable": True,
                "backlog_growth": False,
                "delivered_throughput": 0.161,
                "mean_latency": 11.0,
            }
        )
    assert_true(throughput_plateau(plateau_rows, seeds=(202701, 202702, 202703)), "plateau")


def test_design_map() -> None:
    from date_v3.designs import materialize_opts

    thin = materialize_opts("THIN64")
    assert_true(thin["top_lanes"] == 1 and thin["nodes"] == 64, "thin")
    assert_true(thin["async"], "thin is async")
    prop256 = materialize_opts("PROP256")
    assert_true(prop256["top_lanes"] == 0 and prop256["nodes"] == 256, "256 cores only")
    fm = materialize_opts("FM64")
    assert_true(fm["routing"] == "mesh" and fm["top_lanes"] == 0, "fm64")
    sync_thin = materialize_opts("SYNC_THIN64")
    assert_true(sync_thin["top_lanes"] == 1 and not sync_thin["async"], "sync thin64")
    assert_true(sync_thin["clock_ns"] == 1.0, "sync thin clock")
    sync_prop = materialize_opts("SYNC_PROP64")
    assert_true(sync_prop["top_lanes"] == 2 and not sync_prop["async"], "sync prop64")
    try:
        materialize_opts("SYNC_THIN_1X1")
        raise AssertionError("router primitives must be rejected")
    except ValueError as exc:
        assert_true("network DUT" in str(exc), "reject primitive")


def test_paper_nodes() -> None:
    from date_v3.canonical_trace import paper_nodes_for

    assert_true(paper_nodes_for("BF-STRESS64") == [64], "bf 64")
    assert_true(paper_nodes_for("TOPO-UR") == [64, 256, 1024], "topo scales")
    assert_true(paper_nodes_for("XMC-F16") == [1024], "xmc 1024")
    assert_true(paper_nodes_for("MESH-INTERCLUSTER-UR") == [1024], "mesh 1024")


def test_hrep_xmc_packets_and_tmax() -> None:
    from date_v3.event_record import assemble_event_records

    trace = generate_trace("XMC-F16", seed=202701, nodes=1024, spread=16, smoke=True)
    event = trace["events"][0]
    assert_true(len(event["destinations"]) == 16, "F=16")
    prop = materialize(trace, top_lanes=0, hrep=False)
    hrep = materialize(trace, top_lanes=0, hrep=True)
    assert_true(len(hrep["packets"]) > len(prop["packets"]), "H-REP splits")
    intended = list(prop["packets"][0]["intended_destinations"])
    delivered = list(prop["packets"][0]["delivered_destinations"])
    extras = [d for d in delivered if d not in intended]
    assert_true(set(intended).issubset(set(delivered)), "rect superset")
    assert_true(len(extras) > 0, "S=16 bounding rect fills extra PEs")
    deliveries = [
        {"pkt_seq": 0, "port": dest, "t_head_inject": 1.0, "t_last_tail": 5.0 + dest * 0.01}
        for dest in intended
    ]
    deliveries.append({"pkt_seq": 0, "port": extras[0], "t_head_inject": 1.0, "t_last_tail": 99.0})
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "p.json"
        path.write_text(json.dumps({"packets": prop["packets"][:1]}), encoding="utf-8")
        recs = assemble_event_records(packets_json=path, deliveries=deliveries, include_warmup=True)
    rec = recs[0]
    expected = max(5.0 + d * 0.01 for d in intended) - 1.0
    assert_true(abs(rec["tmax_ns"] - expected) < 1e-9, "Tmax on F=16 dests")
    assert_true(rec["t_last_tail"] != 99.0, "ignore extra rect dest")


def test_hrep_traversal_sum() -> None:
    from date_v3.event_record import assemble_event_records

    with tempfile.TemporaryDirectory() as tmp:
        packets = Path(tmp) / "p.json"
        packets.write_text(
            json.dumps(
                {
                    "packets": [
                        {
                            "pkt_seq": 0,
                            "original_event_id": "e000001",
                            "packet_id": "e000001#0",
                            "phase": "measurement",
                            "source": 1,
                            "intended_destinations": [8, 256],
                            "traversal": {
                                "router_traversal": ["L3(0,0)", "MESH(0,0)"],
                                "link_traversal": ["L3->MESH"],
                                "top_mesh_injection": 1,
                                "top_mesh_link_traversal": 0,
                            },
                        },
                        {
                            "pkt_seq": 1,
                            "original_event_id": "e000001",
                            "packet_id": "e000001#1",
                            "phase": "measurement",
                            "source": 1,
                            "intended_destinations": [8, 256],
                            "traversal": {
                                "router_traversal": ["L3(0,0)", "MESH(1,0)"],
                                "link_traversal": ["MESH->MESH"],
                                "top_mesh_injection": 1,
                                "top_mesh_link_traversal": 2,
                            },
                        },
                    ]
                }
            ),
            encoding="utf-8",
        )
        recs = assemble_event_records(
            packets_json=packets,
            deliveries=[
                {"pkt_seq": 0, "port": 8, "t_head_inject": 1.0, "t_last_tail": 4.0},
                {"pkt_seq": 1, "port": 256, "t_head_inject": 1.2, "t_last_tail": 6.0},
            ],
        )
        rec = recs[0]
        assert_true(rec["tmax_ns"] == 5.0, "min head, max intended tail")
        assert_true(rec["top_mesh_injection"] == 2, "sum split injections")
        assert_true(rec["top_mesh_link_traversal"] == 2, "sum split mesh links")
        assert_true(len(rec["packet_id"]) == 2, "two H-REP packets")
        assert_true("MESH(0,0)" in rec["router_traversal"] and "MESH(1,0)" in rec["router_traversal"], "union")


def test_paired_sync_async_case() -> None:
    trace = generate_trace("BF-STRESS64", seed=202701, smoke=True, load_point=0.10)
    from date_v3.designs import materialize_opts

    keys = ("top_lanes", "hrep", "routing")
    thin_opts = {k: materialize_opts("THIN64")[k] for k in keys}
    sync_opts = {k: materialize_opts("SYNC_THIN64")[k] for k in keys}
    assert_true(thin_opts == sync_opts, "thin/sync share case geometry")
    thin = materialize(trace, **thin_opts)
    sync = materialize(trace, **sync_opts)
    assert_true(thin["inputs"] == sync["inputs"], "paired thin/sync inputs")
    assert_true(thin["expects"] == sync["expects"], "paired thin/sync expects")
    assert_true(thin["event_map"] == sync["event_map"], "paired event_map")
    prop_opts = {k: materialize_opts("PROP64")[k] for k in keys}
    sync_prop_opts = {k: materialize_opts("SYNC_PROP64")[k] for k in keys}
    assert_true(prop_opts == sync_prop_opts, "prop/sync share case geometry")
    prop = materialize(trace, **prop_opts)
    sync_prop = materialize(trace, **sync_prop_opts)
    assert_true(prop["inputs"] == sync_prop["inputs"], "paired prop/sync inputs")
    assert_true(prop["expects"] == sync_prop["expects"], "paired prop/sync expects")


def main() -> int:
    tests = [
        test_seeds,
        test_bf_stress,
        test_paired_thin_prop,
        test_topo_ur_scales,
        test_xmc_spread,
        test_xmc10_fraction,
        test_hrep_split,
        test_materialize_64,
        test_tmax,
        test_saturation,
        test_mesh_intercluster,
        test_paper_warmup_measurement,
        test_three_seeds_distinct,
        test_xmc_f16_samples,
        test_route_oracle_64,
        test_materialize_256_keycase,
        test_event_record_tmax,
        test_stats_and_fine_loads,
        test_design_map,
        test_paper_nodes,
        test_hrep_xmc_packets_and_tmax,
        test_hrep_traversal_sum,
        test_paired_sync_async_case,
    ]
    for test in tests:
        test()
        print("PASS", test.__name__)
    print("TRAFFIC_V3_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

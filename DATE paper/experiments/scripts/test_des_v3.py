#!/usr/bin/env python3
"""Unit checks for the post-synthesis calibrated DES."""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.canonical_trace import generate_trace  # noqa: E402
from date_v3.designs import load_design  # noqa: E402
from date_v3.hrep_policy import split_dest_set  # noqa: E402
from date_v3.materialize_case import materialize  # noqa: E402
from des import CALIBRATION_SEED, MODEL_VERSION, PAPER_SEEDS, PHYSICAL_CLASS  # noqa: E402
from des.hop import run_all_hops, run_isolated_hop  # noqa: E402
from des.lock import build_lock, verify_lock, write_lock  # noqa: E402
from des.run import oracle_errors, simulate, zero_load_analytic_errors  # noqa: E402
from des.sim import packets_from_unicast  # noqa: E402
from des.timing import TimingTable  # noqa: E402
from des.topology import build_network, inventory_delta  # noqa: E402


def assert_true(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def test_calibration_seed() -> None:
    assert_true(CALIBRATION_SEED not in PAPER_SEEDS, "cal seed is not a paper seed")
    assert_true(MODEL_VERSION.startswith("date-des-"), "model version")
    assert_true(PHYSICAL_CLASS == "post-synthesis", "post-synthesis only")


def test_timing_table() -> None:
    table = TimingTable()
    assert_true(table.physical_class == "post-synthesis", "cal class")
    assert_true(len(table.file_hash) == 64, "sha256")
    thin = table.require("async_thin_1x1")
    assert_true(thin.head_ns > thin.body_ns > 0, "thin head>body")
    sync = table.require("sync_thin_1x1")
    assert_true(abs(sync.head_ns - 1.0) < 1e-9, "sync 1 ns")
    table.require("sync_fat_1x2")


def test_inventory() -> None:
    table = TimingTable()
    for design_id in (
        "THIN64",
        "PROP64",
        "PFAT64",
        "FM64",
        "PROP256",
        "FM256",
        "PROP1024",
        "HREP1024",
        "PROP1024_MESH1",
        "SYNC_THIN64",
        "SYNC_PROP64",
    ):
        net = build_network(load_design(design_id), timing=table)
        errors = inventory_delta(net)
        assert_true(not errors, "%s %s" % (design_id, errors))
    hrep = build_network(load_design("HREP1024"), timing=table)
    prop = build_network(load_design("PROP1024"), timing=table)
    assert_true(len(hrep.routers) == len(prop.routers), "H-REP shares netlist")
    try:
        build_network(load_design("PROP1024_MESH4"), timing=table)
        raise AssertionError("MESH4 must not elaborate")
    except ValueError as exc:
        assert_true("not elaborated" in str(exc).lower() or "Mesh4" in str(exc), str(exc))


def test_hops() -> None:
    table = TimingTable()
    result = run_all_hops(table)
    assert_true(result["pass"], "hops %s" % result["failed"])
    row = run_isolated_hop("async_thin_1x1", table)
    assert_true(row["pass"], row["errors"])


def test_unicast_thin64() -> None:
    table = TimingTable()
    packets = []
    pairs = ((0, 1), (0, 15), (0, 63), (3, 40))
    for idx, (src, dst) in enumerate(pairs):
        packets.extend(packets_from_unicast(src, dst, 8, pkt_seq=idx, ready_cycle=idx * 64))
    sim, result = simulate("THIN64", packets, timing=table, arb_seed=CALIBRATION_SEED)
    assert_true(not result["errors"], result["errors"])
    oerr = oracle_errors("THIN64", packets, result["records"])
    assert_true(not oerr, oerr)
    assert_true(not sim.grants_leaked(), sim.grants_leaked())
    assert_true(result["energy_hop_j"] > 0, "energy")
    assert_true(result["n_departs"] > 0, "departs")


def test_unicast_fm64() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 63, 8)
    _sim, result = simulate("FM64", packets, timing=table, arb_seed=2)
    oerr = oracle_errors("FM64", packets, result["records"])
    assert_true(not oerr, oerr)
    assert_true(not result["errors"], result["errors"])


def test_prop256_corner() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 255, 16)
    _sim, result = simulate("PROP256", packets, timing=table, arb_seed=3)
    oerr = oracle_errors("PROP256", packets, result["records"])
    assert_true(not oerr, oerr)
    rec = result["records"][0]
    assert_true(int(rec["top_mesh_injection"] or 0) >= 1, "cross-tier")


def test_scheduled_analytic() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 63, 8)
    _sim, result = simulate("THIN64", packets, timing=table, arb_seed=CALIBRATION_SEED)
    aerr = zero_load_analytic_errors("THIN64", packets, result["records"], timing=table)
    assert_true(not aerr, aerr)
    assert_true(not result["errors"], result["errors"])
    fm = packets_from_unicast(0, 63, 8)
    _sim, result = simulate("FM64", fm, timing=table, arb_seed=CALIBRATION_SEED)
    aerr = zero_load_analytic_errors("FM64", fm, result["records"], timing=table)
    assert_true(not aerr, aerr)


def test_wait_rx_analytic() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 63, 8)
    _sim, result = simulate(
        "THIN64", packets, timing=table, arb_seed=CALIBRATION_SEED, wait_rx=True, case_tick_ns=0.0
    )
    aerr = zero_load_analytic_errors(
        "THIN64", packets, result["records"], timing=table, case_tick_ns=0.0
    )
    assert_true(not aerr, aerr)
    assert_true(not result["errors"], result["errors"])
    fm = packets_from_unicast(0, 63, 8)
    _sim, result = simulate(
        "FM64", fm, timing=table, arb_seed=CALIBRATION_SEED, wait_rx=True, case_tick_ns=0.0
    )
    aerr = zero_load_analytic_errors(
        "FM64", fm, result["records"], timing=table, case_tick_ns=0.0
    )
    assert_true(not aerr, aerr)


def test_multicast_thin64() -> None:
    table = TimingTable()
    packets = [
        {
            "pkt_seq": 0,
            "original_event_id": "e000000",
            "packet_id": "e000000#0",
            "phase": "measurement",
            "source": 0,
            "destinations": [3],
            "rect": [0, 0, 1, 1],
            "ready_cycle": 0,
            "flits": ["0"] * 5,
        }
    ]
    _sim, result = simulate("THIN64", packets, timing=table, arb_seed=CALIBRATION_SEED)
    oerr = oracle_errors("THIN64", packets, result["records"])
    assert_true(not oerr, oerr)
    assert_true(not result["errors"], result["errors"])


def test_energy_conservation() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 7, 8)
    sim, result = simulate("THIN64", packets, timing=table)
    prim = table.require("async_thin_1x1")
    lo = result["n_departs"] * min(prim.energy_head_j, prim.energy_body_j, prim.energy_tail_j)
    hi = result["n_departs"] * max(prim.energy_head_j, prim.energy_body_j, prim.energy_tail_j)
    assert_true(lo - 1e-18 <= result["energy_hop_j"] <= hi + 1e-18, "energy bounds")
    assert_true(result["energy_total_j"] >= result["energy_hop_j"], "idle included")
    del sim


def test_hrep_keeps_event_id() -> None:
    table = TimingTable()
    dests = [0, 8, 256, 264]
    split = split_dest_set("e000000", 1, dests, cluster_grid=4)
    packets = []
    for idx, packet in enumerate(split):
        packets.append(
            {
                "pkt_seq": idx,
                "original_event_id": packet["original_event_id"],
                "packet_id": packet["packet_id"],
                "phase": "measurement",
                "source": packet["source"],
                "destinations": packet["destinations"],
                "rect": packet["rect"],
                "ready_cycle": 0,
                "flits": ["0"] * 5,
            }
        )
    _sim, result = simulate("HREP1024", packets, timing=table)
    assert_true(len(result["records"]) == 1, "one original event")
    rec = result["records"][0]
    assert_true(rec["original_event_id"] == "e000000", "keep id")
    assert_true(set(rec["delivered_destinations"]) >= set(dests) - {1}, rec["delivered_destinations"])


def test_arb_seed_independent() -> None:
    table = TimingTable()
    packets = packets_from_unicast(0, 63, 8)
    _a, ra = simulate("PROP64", packets, timing=table, arb_seed=11)
    _b, rb = simulate("PROP64", packets, timing=table, arb_seed=11)
    assert_true(ra["records"][0]["tmax_ns"] == rb["records"][0]["tmax_ns"], "deterministic arb")
    dests_a = ra["records"][0]["delivered_destinations"]
    dests_b = rb["records"][0]["delivered_destinations"]
    assert_true(dests_a == dests_b, "same dests")


def test_loaded_smoke_no_deadlock() -> None:
    table = TimingTable()
    trace = generate_trace("TOPO-UR", seed=CALIBRATION_SEED, nodes=64, smoke=True, load_point=0.10)
    case = materialize(trace, top_lanes=1, hrep=False, routing="quadtree")
    sim, result = simulate("THIN64", case["packets"], timing=table, arb_seed=CALIBRATION_SEED)
    assert_true(not sim.grants_leaked(), sim.grants_leaked())
    assert_true(len(result["records"]) == 12, "smoke events")
    assert_true(all(rec.get("tmax_ns") is not None for rec in result["records"]), "all tmax")


def test_lock_roundtrip() -> None:
    import des.lock as lockmod

    table = TimingTable()
    orig = lockmod.LOCKED_PATH
    with tempfile.TemporaryDirectory() as tmp:
        lockmod.LOCKED_PATH = Path(tmp) / "locked.json"
        try:
            lock = build_lock(table, hop_self_check="pass", network_rtl_64="pending", network_rtl_256="pending")
            assert_true(lock["physical_class"] == "post-synthesis", "lock class")
            assert_true(lock["calibration_hash"] == table.file_hash, "hash")
            assert_true(lock["paper_matrix_allowed"] is False, "RTL cal pending")
            write_lock(table, hop_self_check="pass", network_rtl_64="pending", network_rtl_256="pending")
            errors = verify_lock(table)
            assert_true(not errors, errors)
        finally:
            lockmod.LOCKED_PATH = orig


def test_256_rtl_keycase_skips_zero_load_tmax() -> None:
    from calibrate_des import _maybe_rtl

    des = [
        {
            "original_event_id": "e000000",
            "delivered_destinations": [37],
            "phase": "measurement",
            "tmax_ns": 88.336,
        }
    ]
    rtl = [
        {
            "original_event_id": "e000000",
            "delivered_destinations": [37],
            "phase": "measurement",
            "tmax_ns": 80.0,
        }
    ]
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        out = root / "FM256" / "directed"
        out.mkdir(parents=True)
        path = out / "events.jsonl"
        path.write_text(json.dumps(rtl[0]) + "\n", encoding="utf-8")
        cmp = _maybe_rtl(root, "FM256", des, zero_load=True, tag="directed")
        assert_true(cmp["pass"], "delivery match is enough for 256 directed")
        assert_true(cmp.get("tmax_enforced") is False, "do not enforce post-synth 5%")
        cmp64 = _maybe_rtl(root, "FM64", des, zero_load=True, tag="directed")
        assert_true(cmp64["status"] == "pending", "missing FM64 jsonl stays pending")
        out64 = root / "FM64" / "directed"
        out64.mkdir(parents=True)
        (out64 / "events.jsonl").write_text(json.dumps(rtl[0]) + "\n", encoding="utf-8")
        cmp64 = _maybe_rtl(root, "FM64", des, zero_load=True, tag="directed")
        assert_true(not cmp64["pass"], "64 still enforces 5% Tmax")


def test_compare_delivery() -> None:
    from des.compare import compare_delivery

    a = [
        {
            "original_event_id": "e000000",
            "delivered_destinations": [63],
            "phase": "measurement",
        }
    ]
    b = [
        {
            "original_event_id": "e000000",
            "delivered_destinations": [63],
            "phase": "measurement",
        }
    ]
    assert_true(compare_delivery(a, b)["pass"], "same dests")
    c = [
        {
            "original_event_id": "e000000",
            "delivered_destinations": [0],
            "phase": "measurement",
        }
    ]
    assert_true(not compare_delivery(a, c)["pass"], "dest mismatch")


def test_descal_pack_helpers() -> None:
    from prepare_descal import DUT_STATUS, directed_corners

    assert_true(DUT_STATUS["PFAT64"]["network_sdf"] == "need_dc", "pfat need_dc")
    assert_true(DUT_STATUS["PROP64"]["network_sdf"] == "have_del050_netlist_need_v3_gls", "prop candidate")
    assert_true(DUT_STATUS["THIN64"]["network_sdf"] == "need_dc", "thin need_dc")
    assert_true(DUT_STATUS["PROP256"]["network_sdf"] == "pending_whole_network", "256 waits for whole-network delay simulation")
    trace = directed_corners(nodes=64, seed=CALIBRATION_SEED, corners=[0, 63], random_unicasts=0)
    assert_true(trace["header"]["seed"] == CALIBRATION_SEED, "cal seed")
    assert_true(len(trace["events"]) == 2, "two corners")
    assert_true(trace["header"]["seed"] not in PAPER_SEEDS, "not paper")


def test_descal_refuse_ackin250() -> None:
    import subprocess
    import tempfile

    from date_v3.paths import REPO

    with tempfile.TemporaryDirectory() as tmp:
        case = Path(tmp) / "dummy.case"
        case.write_text("meta dummy\n", encoding="utf-8")
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "run_descal_gls.py"),
                "--submit",
                "--design",
                "PROP64",
                "--case",
                str(case),
                "--netlist-run-id",
                "20260830_095259_cmr_noc64_p50_1222",
            ],
            cwd=str(REPO),
            capture_output=True,
            text=True,
            check=False,
        )
    assert_true(completed.returncode == 2, completed.stdout + completed.stderr)
    assert_true("Ackin-250" in completed.stdout or "Ackin-250" in completed.stderr, completed.stdout)


def test_hier_unique_refs() -> None:
    from date_v3.paths import REPO

    sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
    from hier_noc import unique_router_jobs

    sample = """
module CMRRouter(
  input clock
);
  IPM InputPortModules_0 (
  );
  LanePhaseAdapter #(
    .LANES(2)
  ) adapter (
  );
endmodule
module CMRRouter_1(
);
  IPM InputPortModules_0 (
  );
  IPM_1 InputPortModules_1 (
  );
endmodule
module NoC_64nodes(
);
  CMRRouter routersL1_0 (
  );
  CMRRouter_1 routersL2_0 (
  );
endmodule
"""
    jobs = unique_router_jobs(sample)
    assert_true(len(jobs) == 2, "two unique refs")
    by_ref = {job["ref"]: job for job in jobs}
    assert_true(by_ref["CMRRouter"]["expected_ports"] == 1, "l1 ports")
    assert_true(by_ref["CMRRouter"]["expected_adapters"] == 1, "l1 adapters")
    assert_true(by_ref["CMRRouter_1"]["expected_ports"] == 2, "l2 ports")
    assert_true(by_ref["CMRRouter"]["expected_path_latches"] == 4, "path latches")


def test_descal_allows_pfat_plan() -> None:
    import subprocess
    import tempfile

    from date_v3.paths import REPO

    with tempfile.TemporaryDirectory() as tmp:
        case = Path(tmp) / "dummy.case"
        case.write_text("meta dummy\n", encoding="utf-8")
        completed = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "run_descal_gls.py"),
                "--submit",
                "--design",
                "PFAT64",
                "--case",
                str(case),
                "--dc-mode",
                "full",
            ],
            cwd=str(REPO),
            capture_output=True,
            text=True,
            check=False,
        )
    assert_true(completed.returncode == 0, completed.stdout + completed.stderr)
    assert_true("SUBMIT_PLAN" in completed.stdout, completed.stdout)
    assert_true("emit-only" not in completed.stdout, completed.stdout)


def main() -> int:
    tests = [
        test_calibration_seed,
        test_timing_table,
        test_inventory,
        test_hops,
        test_unicast_thin64,
        test_scheduled_analytic,
        test_multicast_thin64,
        test_unicast_fm64,
        test_prop256_corner,
        test_energy_conservation,
        test_hrep_keeps_event_id,
        test_arb_seed_independent,
        test_loaded_smoke_no_deadlock,
        test_lock_roundtrip,
        test_compare_delivery,
        test_256_rtl_keycase_skips_zero_load_tmax,
        test_descal_pack_helpers,
        test_descal_refuse_ackin250,
        test_hier_unique_refs,
        test_descal_allows_pfat_plan,
    ]
    for test in tests:
        test()
        print("PASS", test.__name__)
    print("DES_V3_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

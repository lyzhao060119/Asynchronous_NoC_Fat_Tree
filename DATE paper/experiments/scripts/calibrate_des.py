#!/usr/bin/env python3
"""DATE V3 Phase 5 DES calibration gate.

Uses calibration seed 900001, never the paper seeds.  Hop H/B/T must match
post-synthesis MAXIMUM-SDF primitives.  64/256 delivery/traversal must match
the route oracle.  Zero-load Tmax must match hop-composed analytic within 5%.
If RTL CSVs are present under --rtl-dir, apply §21 latency/throughput limits.
Does not submit LSF onto hosts already running Phase 5 DC/GLS.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
EXPERIMENTS = SCRIPTS.parent
MODEL = EXPERIMENTS / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.designs import NETWORK_IDS, load_design  # noqa: E402
from date_v3.event_record import run_metrics  # noqa: E402
from date_v3.hashutil import load_json, write_json  # noqa: E402
from date_v3.paths import INTERMEDIATE  # noqa: E402
from des import CALIBRATION_SEED, MODEL_VERSION, PAPER_SEEDS, PHYSICAL_CLASS  # noqa: E402
from des.compare import (  # noqa: E402
    ZERO_LOAD_MEDIAN,
    compare_delivery,
    compare_throughput,
    compare_tmax,
)
from des.hop import run_all_hops  # noqa: E402
from des.lock import verify_lock, write_lock  # noqa: E402
from des.run import oracle_errors, simulate, zero_load_analytic_errors  # noqa: E402
from des.sim import packets_from_unicast  # noqa: E402
from des.timing import DEFAULT_CASE_TICK_NS, TimingTable  # noqa: E402
from des.topology import build_network, inventory_delta  # noqa: E402

CAL64 = ("THIN64", "PROP64", "PFAT64", "FM64")
CAL256 = ("PROP256", "FM256")
OUT = INTERMEDIATE / "des_calibration"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quick", action="store_true", help="small traces for the Phase 5 gate")
    parser.add_argument("--write-lock", action="store_true")
    parser.add_argument("--rtl-dir", type=Path, help="optional RTL event JSONL / latency.csv tree")
    parser.add_argument(
        "--pack",
        type=Path,
        help="des_calibration pack from prepare_descal.py (uses pack/rtl if --rtl-dir omitted)",
    )
    parser.add_argument("--out", type=Path, default=OUT)
    return parser.parse_args()


def _unicast(design_id: str, src: int, dst: int, width: int) -> list[dict]:
    return packets_from_unicast(src, dst, width)


def _run_case(
    design_id: str,
    packets: list[dict],
    timing: TimingTable,
    *,
    wait_rx: bool = False,
    case_tick_ns: float | None = None,
    analytic: bool = False,
) -> dict:
    kwargs = {"timing": timing, "arb_seed": CALIBRATION_SEED, "wait_rx": wait_rx}
    if case_tick_ns is not None:
        kwargs["case_tick_ns"] = case_tick_ns
    sim, result = simulate(design_id, packets, **kwargs)
    oerr = oracle_errors(design_id, packets, result["records"])
    aerr = []
    if analytic:
        tick = kwargs["case_tick_ns"] if kwargs.get("case_tick_ns") is not None else DEFAULT_CASE_TICK_NS
        aerr = zero_load_analytic_errors(
            design_id, packets, result["records"], timing=timing, case_tick_ns=tick
        )
    leaked = sim.grants_leaked()
    return {
        "design_id": design_id,
        "events": len(result["records"]),
        "sim_errors": result["errors"],
        "oracle_errors": oerr,
        "analytic_errors": aerr,
        "inventory_errors": result.get("inventory_errors") or [],
        "grant_leaks": leaked,
        "energy_hop_j": result["energy_hop_j"],
        "n_departs": result["n_departs"],
        "physical_class": result["physical_class"],
        "pass": not (result["errors"] or oerr or aerr or leaked or result.get("inventory_errors")),
        "records": result["records"],
    }


def _load_jsonl(path: Path) -> list[dict]:
    records = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.strip():
            records.append(json.loads(line))
    return records


def _rtl_path(rtl_dir: Path, design_id: str, tag: str | None) -> Path | None:
    candidates = []
    if tag:
        candidates.append(rtl_dir / design_id / tag / "events.jsonl")
    candidates.append(rtl_dir / design_id / "events.jsonl")
    for path in candidates:
        if path.is_file():
            return path
    return None


def _maybe_rtl(
    rtl_dir: Path | None,
    design_id: str,
    des_records: list[dict],
    *,
    zero_load: bool,
    tag: str | None = None,
) -> dict:
    if rtl_dir is None or not rtl_dir.is_dir():
        return {"status": "pending", "pass": True, "notes": "no RTL dir; network MAXIMUM-SDF is pending"}
    path = _rtl_path(rtl_dir, design_id, tag)
    if path is None:
        return {
            "status": "pending",
            "pass": True,
            "notes": "missing rtl/%s/%s/events.jsonl" % (design_id, tag or ""),
        }
    records = _load_jsonl(path)
    cmp_t = compare_tmax(des_records, records, zero_load=zero_load)
    cmp_d = compare_delivery(des_records, records)
    skip_tmax = design_id in ("PROP256", "FM256") and zero_load
    ok = bool(cmp_d["pass"] and (True if skip_tmax else cmp_t["pass"]))
    out = {
        "status": "compared",
        "path": str(path),
        "tmax": cmp_t,
        "delivery": cmp_d,
        "tmax_enforced": not skip_tmax,
        "pass": ok,
    }
    if skip_tmax:
        out["notes"] = (
            "256 rtl_keycase skips post-synth zero-load 5% Tmax; "
            "delivery still required. Do not cook DelayElement_sim."
        )
    if not zero_load:
        cmp_tp = compare_throughput(run_metrics(des_records), run_metrics(records))
        out["throughput"] = cmp_tp
        out["pass"] = bool(ok and cmp_tp["pass"])
    return out


REQUIRED_64 = tuple((d, t) for d in CAL64 for t in ("directed", "zero", "loaded"))
REQUIRED_256 = tuple((d, t) for d in CAL256 for t in ("directed", "low", "mid"))


def _pack_rtl_status(pack_dir: Path, rtl_dir: Path | None) -> tuple[list[dict], str, str]:
    matrix_path = pack_dir / "matrix.json"
    if not matrix_path.is_file():
        return ([{"pass": False, "notes": "missing %s" % matrix_path}], "pending", "pending")
    matrix = load_json(matrix_path)
    root = rtl_dir if rtl_dir is not None else Path(matrix.get("rtl_dir") or (pack_dir / "rtl"))
    rows = []
    compared: dict[tuple[str, str], bool] = {}
    for job in matrix.get("jobs") or []:
        design_id = job["design_id"]
        tag = job["tag"]
        des_path = Path(job["des_events"])
        if not des_path.is_file():
            rows.append({"design_id": design_id, "tag": tag, "pass": False, "notes": "missing DES jsonl"})
            continue
        des_records = _load_jsonl(des_path)
        cmp = _maybe_rtl(
            root,
            design_id,
            des_records,
            zero_load=bool(job.get("zero_load")),
            tag=tag,
        )
        cmp["design_id"] = design_id
        cmp["tag"] = tag
        rows.append(cmp)
        if cmp["status"] == "compared":
            compared[(design_id, tag)] = bool(cmp["pass"])

    def _gate(required: tuple[tuple[str, str], ...]) -> str:
        if not all(key in compared for key in required):
            return "pending"
        if all(compared[key] for key in required):
            return "pass"
        return "fail"

    return rows, _gate(REQUIRED_64), _gate(REQUIRED_256)


def main() -> int:
    args = parse_args()
    if CALIBRATION_SEED in PAPER_SEEDS:
        print("FAIL calibration seed collides with paper seeds", flush=True)
        return 2
    timing = TimingTable()
    if timing.physical_class == "post-layout":
        print("FAIL post-layout calibration", flush=True)
        return 2
    hops = run_all_hops(timing)
    inventory = {}
    for design_id in NETWORK_IDS:
        if design_id == "PROP1024_MESH4":
            continue
        net = build_network(load_design(design_id), timing=timing)
        inventory[design_id] = inventory_delta(net)

    cases: list[tuple[str, str, list[dict], dict]] = []
    for design_id in CAL64:
        dst = 63
        width = 8
        cases.append(
            (
                "64_oracle",
                design_id,
                _unicast(design_id, 0, dst, width),
                {"analytic": design_id in ("THIN64", "FM64", "PROP64", "PFAT64")},
            )
        )
    cases.append(("256_oracle", "PROP256", _unicast("PROP256", 0, 255, 16), {"analytic": True}))
    cases.append(("256_oracle", "FM256", _unicast("FM256", 0, 255, 16), {"analytic": True}))
    if not args.quick:
        from date_v3.canonical_trace import generate_trace
        from date_v3.designs import materialize_opts
        from date_v3.materialize_case import materialize

        loaded = generate_trace(
            "TOPO-UR", seed=CALIBRATION_SEED, nodes=64, smoke=True, load_point=0.10
        )
        for design_id in CAL64:
            opts = materialize_opts(design_id)
            case = materialize(
                loaded,
                top_lanes=opts["top_lanes"],
                hrep=opts["hrep"],
                routing=opts["routing"],
            )
            cases.append(("64_loaded", design_id, case["packets"], {"analytic": False}))

    reports = []
    failed = []
    rtl_64 = "pending"
    rtl_256 = "pending"
    pack_rows: list[dict] = []
    for tag, design_id, packets, opts in cases:
        row = _run_case(design_id, packets, timing, **opts)
        row["tag"] = tag
        zero = bool(opts.get("analytic") or opts.get("wait_rx"))
        if args.pack:
            row["rtl"] = {"status": "deferred_to_pack", "pass": True}
        else:
            row["rtl"] = _maybe_rtl(args.rtl_dir, design_id, row["records"], zero_load=zero, tag=tag)
            if row["rtl"]["status"] == "compared":
                if design_id in CAL64:
                    rtl_64 = "pass" if row["rtl"]["pass"] else "fail"
                if design_id in CAL256:
                    rtl_256 = "pass" if row["rtl"]["pass"] else "fail"
        if not row["pass"] or not row["rtl"]["pass"]:
            failed.append("%s/%s" % (tag, design_id))
        slim = {k: v for k, v in row.items() if k != "records"}
        reports.append(slim)
        print("CASE", tag, design_id, "PASS" if row["pass"] else "FAIL", flush=True)

    if args.pack:
        pack_rows, rtl_64, rtl_256 = _pack_rtl_status(args.pack, args.rtl_dir)
        for prow in pack_rows:
            if prow.get("status") == "compared" and not prow.get("pass"):
                failed.append("pack/%s/%s" % (prow.get("design_id"), prow.get("tag")))

    pending_hw = [
        "%s/%s" % (prow.get("design_id"), prow.get("tag"))
        for prow in pack_rows
        if prow.get("status") == "pending"
    ]
    blocker_bits = []
    if failed:
        blocker_bits.append("compared_fail=" + ",".join(failed))
    if pending_hw:
        blocker_bits.append("missing_hw=" + ",".join(pending_hw))
    hop_ok = hops["pass"]
    inv_fail = [k for k, v in inventory.items() if v]
    paper_ok = hop_ok and not failed and not inv_fail and rtl_64 == "pass" and rtl_256 == "pass"
    lock = None
    if args.write_lock or (hop_ok and not failed and not inv_fail):
        lock = write_lock(
            timing,
            hop_self_check="pass" if hop_ok else "fail",
            network_rtl_64=rtl_64,
            network_rtl_256=rtl_256,
            paper_matrix_allowed=paper_ok,
        )
    lock_errors = verify_lock(timing) if lock is not None else []
    log = {
        "schema": "date-v3-des-calibration-log-v1",
        "model_version": MODEL_VERSION,
        "physical_class": PHYSICAL_CLASS,
        "calibration_hash": timing.file_hash,
        "calibration_seed": CALIBRATION_SEED,
        "paper_seeds_excluded": list(PAPER_SEEDS),
        "hop": {k: hops[k] for k in ("pass", "failed", "calibration_hash")},
        "hop_rows": hops["rows"],
        "inventory": inventory,
        "cases": reports,
        "pack_rtl": pack_rows,
        "failed": failed,
        "pending_hw": pending_hw,
        "zero_load_median_limit": ZERO_LOAD_MEDIAN,
        "network_rtl_64": rtl_64,
        "network_rtl_256": rtl_256,
        "paper_matrix_allowed": paper_ok,
        "lock": lock,
        "lock_errors": lock_errors,
        "lsf": "not submitted; use CMR_DES_BSUB_EXTRA for a free host if GLS is required",
        "notes": (
            "V3 5-flit 64 network MAXIMUM-SDF traces are required for "
            "network_rtl_64. 256 rtl_keycase gates on delivery and loaded "
            "10% mean/throughput, not post-synth zero-load 5% Tmax. "
            "Do not calibrate against 3-flit archive GLS. "
            "Ackin-250 NoC64 is not a timing-cal netlist. "
            "Do not cook DelayElement_sim."
            + ((" Blockers: " + "; ".join(blocker_bits) + ".") if blocker_bits else "")
        ),
    }
    args.out.mkdir(parents=True, exist_ok=True)
    write_json(args.out / "calibration_log.json", log)
    print(
        json.dumps(
            {
                "hop_pass": hops["pass"],
                "inventory_fail": inv_fail,
                "case_fail": failed,
                "lock_errors": lock_errors,
                "paper_matrix_allowed": paper_ok,
                "network_rtl_64": rtl_64,
                "network_rtl_256": rtl_256,
            }
        ),
        flush=True,
    )
    if (not hop_ok) or inv_fail or failed or lock_errors:
        return 1
    if paper_ok:
        print("PHASE5_DES_CAL_PASS", flush=True)
    else:
        print("PHASE5_DES_INFRA_PASS", flush=True)
        print("PHASE5_NETWORK_RTL_CAL pending", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

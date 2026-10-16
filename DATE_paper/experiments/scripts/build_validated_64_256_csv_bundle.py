#!/usr/bin/env python3
"""Build a claim-safe, hash-indexed CSV bundle from accepted 64/256-node runs.

This copies/filters curated data only; it never edits or deletes source artifacts.
"""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
EXP = ROOT / "DATE paper" / "experiments"
OUT = EXP / "curated" / "validated_64_256_csv_20260918"
P64 = EXP / "raw" / "paper64"
P256 = EXP / "raw" / "paper256"
P64_FINAL = P64 / "compact64_20260916_193802"
P64_COHORT = P64 / "cohort64_20260916_083441"
P256_REPAIR = P256 / "compact256_repair_20260918_123846"
P256_CURRENT = P256 / "compact256_20260918_111300"
P256_CURATED_REPAIR = EXP / "curated" / "paper256" / "compact256_repair_20260918_123846"

INDEX_FIELDS = [
    "nodes", "experiment", "classification", "row_count", "source_path",
    "bundle_path", "source_sha256", "bundle_sha256", "acceptance_rule",
]
EXCLUSION_FIELDS = ["nodes", "experiment", "case", "design", "load", "reason", "source_path"]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"Missing/empty source CSV: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if not reader.fieldnames:
            raise RuntimeError(f"CSV has no header: {path}")
        return list(reader.fieldnames), list(reader)


def truth(value: str | None) -> bool:
    return (value or "").strip().lower() in {"true", "1", "yes", "pass"}


def write_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def unique(rows: list[dict[str, str]], keys: tuple[str, ...], label: str) -> None:
    seen: set[tuple[str, ...]] = set()
    for row in rows:
        key = tuple(row.get(k, "") for k in keys)
        if key in seen:
            raise RuntimeError(f"Duplicate {label} key {keys}={key}")
        seen.add(key)


def copy_artifact(src: Path, rel: str, nodes: str, exp: str, classification: str,
                  rows: int, rule: str) -> None:
    if not src.is_file() or src.stat().st_size == 0:
        raise RuntimeError(f"Required artifact missing/empty: {src}")
    dst = OUT / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    index.append({
        "nodes": nodes, "experiment": exp, "classification": classification,
        "row_count": str(rows), "source_path": str(src.relative_to(ROOT)),
        "bundle_path": rel.replace("\\", "/"), "source_sha256": sha256(src),
        "bundle_sha256": sha256(dst), "acceptance_rule": rule,
    })


def export_filtered(src: Path, rel: str, nodes: str, exp: str, classification: str,
                    predicate, rule: str) -> list[dict[str, str]]:
    fields, rows = read_csv(src)
    chosen = [r for r in rows if predicate(r)]
    if not chosen:
        raise RuntimeError(f"Filter produced no accepted rows: {src} -> {rel}")
    tmp = OUT / rel
    write_csv(tmp, fields, chosen)
    index.append({
        "nodes": nodes, "experiment": exp, "classification": classification,
        "row_count": str(len(chosen)), "source_path": str(src.relative_to(ROOT)),
        "bundle_path": rel.replace("\\", "/"), "source_sha256": sha256(src),
        "bundle_sha256": sha256(tmp), "acceptance_rule": rule,
    })
    return chosen


def exclude(nodes: str, exp: str, case: str, design: str, load: str,
            reason: str, source: Path) -> None:
    exclusions.append({
        "nodes": nodes, "experiment": exp, "case": case, "design": design,
        "load": load, "reason": reason, "source_path": str(source.relative_to(ROOT)),
    })


def verify_bundle() -> None:
    manifest_path = OUT / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    problems: list[str] = []
    for rel, expected in manifest["sha256"].items():
        path = OUT / rel
        if not path.is_file() or sha256(path) != expected:
            problems.append(f"manifest hash mismatch: {rel}")
    fields, rows = read_csv(OUT / "included_files.csv")
    for row in rows:
        path = OUT / row["bundle_path"]
        if not path.is_file() or sha256(path) != row["bundle_sha256"]:
            problems.append(f"index hash mismatch: {row['bundle_path']}")
    _, r64 = read_csv(OUT / "64/01_ur/pre_saturation_latency_accepted.csv")
    if any(not truth(r.get("paper_latency_eligible")) or not truth(r.get("near_lossless")) for r in r64):
        problems.append("64 UR latency table contains an ineligible/saturated row")
    _, r256 = read_csv(OUT / "256/01_global_ur/common_near_lossless_latency.csv")
    if any(not truth(r.get("near_lossless")) or truth(r.get("censored")) for r in r256):
        problems.append("256 UR latency table contains an ineligible/censored row")
    _, loc = read_csv(OUT / "256/02_locality/locality_m120_paired_eligible.csv")
    if any(not truth(r.get("paper_eligible")) or not truth(r.get("near_lossless"))
           or r.get("locality_p") == "0.9" for r in loc):
        problems.append("256 locality table includes ineligible p=0.9 or non-near-lossless data")
    _, f16 = read_csv(OUT / "256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv")
    if any(r.get("load") not in {"5", "20"} or truth(r.get("censored")) for r in f16):
        problems.append("256 F16 table includes censored/out-of-scope load")
    _, mc = read_csv(OUT / "64/04_multicast/clean_fanout_400tx.csv")
    if any(truth(r.get("censored")) or r.get("completed_count") != "400"
           or r.get("backlog") != "0" for r in mc):
        problems.append("64 multicast table contains censored/incomplete data")
    if problems:
        raise RuntimeError("Bundle verification failed:\n- " + "\n- ".join(problems))
    print(json.dumps({"verified_manifest_files": len(manifest["sha256"]),
                      "verified_indexed_files": len(rows), "integrity": "PASS",
                      "eligible_filter_checks": "PASS", "bundle": str(OUT)}, indent=2))


def is_64_ur_pass(r: dict[str, str]) -> bool:
    return (r.get("pass_fail") == "PASS" and r.get("missing") == "0"
            and r.get("unexpected") == "0" and r.get("timeout") == "0"
            and r.get("injected_flits") == r.get("delivered_flits"))


def is_64_ur_cohort(r: dict[str, str]) -> bool:
    return (is_64_ur_pass(r) and r.get("cohort_latency_status") == "PASS"
            and r.get("latency_contract") == "full_drain_measurement_offer_cohort_v1"
            and r.get("cohort_measurement_packets") == "10000"
            and r.get("cohort_measurement_flits") == "50000")


def is_64_bench_pass(r: dict[str, str]) -> bool:
    return (r.get("pass_fail") == "PASS" and truth(r.get("full_drain_pass"))
            and truth(r.get("sdf_pass")) and truth(r.get("trace_pair_pass"))
            and r.get("latency_contract") == "full_drain_measurement_offer_cohort_v1"
            and r.get("cohort_measurement_packets") == "10000"
            and r.get("cohort_measurement_flits") == "50000")


index: list[dict[str, str]] = []
exclusions: list[dict[str, str]] = []


def main() -> None:
    if "--verify" in sys.argv:
        verify_bundle()
        return
    if OUT.exists() and (OUT / "manifest.json").exists() and "--refresh" not in sys.argv:
        raise RuntimeError(f"Output already finalized; refusing to overwrite: {OUT}")
    # A prior acceptance-gate failure may leave this script's partial output only.
    # Deterministic generated files below may be rewritten when resuming that build.
    OUT.mkdir(parents=True, exist_ok=True)

    # 64-node UR: throughput-valid points and positive-latency points are separate.
    ur_src = P64_COHORT / "ur_acceptance.csv"
    ur_all = export_filtered(ur_src, "64/01_ur/throughput_all_accepted.csv", "64", "global_ur",
                             "accepted_throughput", is_64_ur_pass,
                             "PASS, zero missing/unexpected/timeout, injected equals delivered; saturation remains throughput-only")
    ur_latency = export_filtered(ur_src, "64/01_ur/pre_saturation_latency_accepted.csv", "64", "global_ur",
                                 "paper_latency_eligible", lambda r: is_64_ur_cohort(r)
                                 and truth(r.get("near_lossless"))
                                 and truth(r.get("paper_latency_eligible")),
                                 "accepted cohort + near_lossless + paper_latency_eligible")
    unique(ur_all, ("design", "load_setpoint_mflit_per_port_s"), "64 UR throughput")
    unique(ur_latency, ("design", "load_setpoint_mflit_per_port_s"), "64 UR latency")
    if len(ur_all) != 90 or len(ur_latency) != 44:
        raise RuntimeError(f"Unexpected 64 UR counts: throughput={len(ur_all)}, latency={len(ur_latency)}")
    for r in ur_all:
        if not (truth(r.get("near_lossless")) and truth(r.get("paper_latency_eligible"))):
            exclude("64", "global_ur_latency", r.get("case", ""), r.get("design", ""),
                    r.get("load_setpoint_mflit_per_port_s", ""),
                    "valid throughput point, but saturated/censored or not eligible for positive latency claim", ur_src)

    # 64-node BC and Hotspot: require SDF, pairing and full-drain markers for every row.
    bench_src = P64_COHORT / "bc_hotspot_acceptance.csv"
    bench_all = export_filtered(bench_src, "64/02_benchmarks/bc_hotspot_all_accepted.csv", "64",
                                "bc_hotspot", "accepted_full_drain", is_64_bench_pass,
                                "PASS + SDF + trace pairing + full drain + complete cohort")
    bench_latency = export_filtered(bench_src, "64/02_benchmarks/bc_hotspot_latency_eligible.csv", "64",
                                    "bc_hotspot", "paper_latency_eligible", lambda r: is_64_bench_pass(r)
                                    and truth(r.get("near_lossless"))
                                    and truth(r.get("latency_claim_eligible"))
                                    and truth(r.get("paper_latency_eligible")),
                                    "accepted full-drain row + near_lossless + latency claim eligible")
    unique(bench_all, ("benchmark", "design", "load_setpoint_mflit_per_port_s"), "64 BC/Hotspot")
    if len(bench_all) != 120:
        raise RuntimeError(f"Expected 120 accepted BC/Hotspot rows, got {len(bench_all)}")
    for b in {r["benchmark"] for r in bench_all}:
        for l in {r["load_setpoint_mflit_per_port_s"] for r in bench_all if r["benchmark"] == b}:
            pair = [r for r in bench_all if r["benchmark"] == b and r["load_setpoint_mflit_per_port_s"] == l]
            if len(pair) != 2 or len({r["trace_sha256"] for r in pair}) != 1:
                raise RuntimeError(f"64 BC/Hotspot paired trace mismatch: {b} M{l}")

    # 64-node Static4: only the three predeclared paper points; selection probes stay excluded.
    static_src = P64_FINAL / "static_acceptance.csv"
    static_fields, static_rows = read_csv(static_src)
    static_ok = [r for r in static_rows if truth(r.get("pass")) and r.get("claim_role") == "paper_point"
                 and truth(r.get("trace_case_paired")) and r.get("sdf_annotation_errors") == "0"
                 and r.get("measurement_packets") == "10000" and r.get("measurement_flits") == "50000"
                 and r.get("injected_flits") == "55000" and r.get("delivered_flits") == "55000"
                 and r.get("measurement_backlog_flits") == "4" and not truth(r.get("censored"))]
    if {r.get("load") for r in static_ok} != {"5", "100", "420"} or len(static_ok) != 3:
        raise RuntimeError("Static4 paper points did not match M5/M100/M420 acceptance contract")
    write_csv(OUT / "64/03_static4/static4_paper_points.csv", static_fields, static_ok)
    index.append({"nodes": "64", "experiment": "static4", "classification": "paper_points",
                  "row_count": "3", "source_path": str(static_src.relative_to(ROOT)),
                  "bundle_path": "64/03_static4/static4_paper_points.csv", "source_sha256": sha256(static_src),
                  "bundle_sha256": sha256(OUT / "64/03_static4/static4_paper_points.csv"),
                  "acceptance_rule": "M5/M100/M420 only; PASS, paired trace, zero SDF errors, 55k/55k, full cohort, backlog=4"})
    for r in static_rows:
        if r not in static_ok:
            exclude("64", "static4", r.get("case", ""), r.get("design", ""), r.get("load", ""),
                    "selection probe or not a predeclared paper point; not included in main evidence CSV", static_src)

    # 64-node multicast: clean F2/F16/F32 rows; the M60 F16 pair is censored stress, not a claim point.
    mc_src = P64_FINAL / "multicast_acceptance.csv"
    mc_fields, mc_rows = read_csv(mc_src)
    mc_ok = [r for r in mc_rows if r.get("fanout") in {"2", "16", "32"}
             and r.get("acceptance") == "PASS" and truth(r.get("sdf_pass"))
             and truth(r.get("full_drain_pass")) and not truth(r.get("censored"))
             and r.get("completed_count") == "400" and r.get("measurement_transactions") == "400"
             and r.get("backlog") == "0"]
    unique(mc_ok, ("fanout", "load", "scheme"), "64 multicast")
    if len(mc_ok) != 8:
        raise RuntimeError(f"Expected 8 clean 64 multicast rows (F2/F16/F32), got {len(mc_ok)}")
    for fanout in {r["fanout"] for r in mc_ok}:
        for load in {r["load"] for r in mc_ok if r["fanout"] == fanout}:
            pair = [r for r in mc_ok if r["fanout"] == fanout and r["load"] == load]
            if len(pair) != 2 or len({r["trace_sha256"] for r in pair}) != 1:
                raise RuntimeError(f"64 multicast pairing failed: F{fanout} M{load}")
    write_csv(OUT / "64/04_multicast/clean_fanout_400tx.csv", mc_fields, mc_ok)
    index.append({"nodes": "64", "experiment": "multicast", "classification": "clean_full_drain",
                  "row_count": str(len(mc_ok)), "source_path": str(mc_src.relative_to(ROOT)),
                  "bundle_path": "64/04_multicast/clean_fanout_400tx.csv", "source_sha256": sha256(mc_src),
                  "bundle_sha256": sha256(OUT / "64/04_multicast/clean_fanout_400tx.csv"),
                  "acceptance_rule": "F2/F16/F32; Native/Repeated paired; 400/400, backlog=0, SDF and full-drain PASS; censored excluded"})
    for r in mc_rows:
        if r not in mc_ok:
            exclude("64", "multicast", r.get("case", ""), r.get("scheme", ""),
                    f"M{r.get('load','')}/F{r.get('fanout','')}",
                    "censored stress or outside the accepted F2/F16/F32 paired clean matrix", mc_src)

    # 64-node network and router PPA / power tables.
    table_i = P64_FINAL / "table64-i-network.csv"
    copy_artifact(table_i, "64/05_ppa_power/table64_i_network.csv", "64", "network_ppa_power",
                  "paper_table", 5, "Latest final compact64 table; Sync row carries pre-CTS clock caveat")
    table_ii_src = P64_FINAL / "table64-ii-router.csv"
    t2_fields, t2_rows = read_csv(table_ii_src)
    t2_ok = [r for r in t2_rows if r.get("design") in {"async_c1p1", "async_c1p2", "async_c1p4"}]
    if len(t2_ok) != 3:
        raise RuntimeError("Router lane scaling must contain accepted Async c1p1/c1p2/c1p4 only")
    write_csv(OUT / "64/06_router/router_lane_scaling.csv", t2_fields, t2_ok)
    index.append({"nodes": "64", "experiment": "router_lane_scaling", "classification": "accepted_async_only",
                  "row_count": "3", "source_path": str(table_ii_src.relative_to(ROOT)),
                  "bundle_path": "64/06_router/router_lane_scaling.csv", "source_sha256": sha256(table_ii_src),
                  "bundle_sha256": sha256(OUT / "64/06_router/router_lane_scaling.csv"),
                  "acceptance_rule": "Async c1p1/c1p2/c1p4 MAXIMUM-SDF aggregates; failed Sync aggregate row excluded"})
    area_src = P64_FINAL / "area_acceptance.csv"
    copy_artifact(area_src, "64/05_ppa_power/area_acceptance.csv", "64", "area", "frozen_dc_qor_hashes",
                  len(read_csv(area_src)[1]), "Non-empty archived QoR reports with SHA-256; table64-I maps eligible designs")

    power_src = P64_FINAL / "network_power_acceptance.csv"
    power_fields, power_rows = read_csv(power_src)
    power_ok = [r for r in power_rows if truth(r.get("pass")) and float(r.get("total_power_w") or 0) > 0
                and (int(r.get("delivered_flits") or 0) > 0
                     or (int(r.get("original_transactions") or 0) > 0
                         and int(r.get("useful_destination_deliveries") or 0) > 0))]
    if len(power_ok) != 8:
        raise RuntimeError(f"Expected 8 accepted Async network PT-PX points, got {len(power_ok)}")
    rel = "64/05_ppa_power/network_power_async_accepted.csv"
    write_csv(OUT / rel, power_fields, power_ok)
    index.append({"nodes": "64", "experiment": "network_power", "classification": "async_ptpx_accepted",
                  "row_count": str(len(power_ok)), "source_path": str(power_src.relative_to(ROOT)),
                  "bundle_path": rel, "source_sha256": sha256(power_src), "bundle_sha256": sha256(OUT / rel),
                  "acceptance_rule": "pass=true, nonzero total power, and nonzero flit or multicast-delivery denominator"})

    # 64-node Sync B8: kept separate from async and gated on the full 30-point scan.
    sync_src = P64_FINAL / "sync64_ur_acceptance.csv"
    sync_fields, sync_rows = read_csv(sync_src)
    sync_ok = [r for r in sync_rows if truth(r.get("full_drain_pass"))
               and r.get("measurement_packets") == "10000" and r.get("measurement_flits") == "50000"
               and r.get("injected_flits") == "55000" and r.get("delivered_flits") == "55000"]
    if len(sync_ok) != 30:
        raise RuntimeError(f"Expected 30 Sync full-drain points, got {len(sync_ok)}")
    sync_latency = [r for r in sync_ok if truth(r.get("paper_latency_eligible")) and truth(r.get("near_lossless"))]
    write_csv(OUT / "64/07_sync_b8/ur_all_full_drain.csv", sync_fields, sync_ok)
    write_csv(OUT / "64/07_sync_b8/ur_pre_saturation_latency.csv", sync_fields, sync_latency)
    for rel, rows, cls, rule in (
        ("64/07_sync_b8/ur_all_full_drain.csv", sync_ok, "full_drain", "30/30 full drain; 10k packets/50k cohort flits; 55k/55k"),
        ("64/07_sync_b8/ur_pre_saturation_latency.csv", sync_latency, "latency_eligible", "full-drain points + near_lossless + paper_latency_eligible"),
    ):
        index.append({"nodes": "64", "experiment": "sync_b8_ur", "classification": cls,
                      "row_count": str(len(rows)), "source_path": str(sync_src.relative_to(ROOT)),
                      "bundle_path": rel, "source_sha256": sha256(sync_src), "bundle_sha256": sha256(OUT / rel),
                      "acceptance_rule": rule})
    syncp_src = P64_FINAL / "sync64_power_acceptance.csv"
    syncp = export_filtered(syncp_src, "64/07_sync_b8/power_accepted.csv", "64", "sync_b8_power",
                             "post_synthesis_pre_cts_ptpx", lambda r: truth(r.get("pass"))
                             and float(r.get("total_power_w") or 0) > 0
                             and int(r.get("delivered_flits") or 0) > 0,
                             "PT-PX pass with nonzero report/denominator; pre-CTS explicitly caveated")
    if len(syncp) != 2:
        raise RuntimeError(f"Expected Sync M100/M420 power, got {len(syncp)}")

    # 256-node E1 M16 vs FlatMesh: only full-drain PASS rows; latency requires common near-lossless pairing.
    e1_src = P256_CURRENT / "summary_e1.csv"
    e1_fields, e1_rows = read_csv(e1_src)
    e1_all = [r for r in e1_rows if truth(r.get("full_drain_pass"))
              and r.get("full_drain_injected_flits") == "55000"
              and r.get("full_drain_delivered_flits") == "55000"]
    unique(e1_all, ("design", "load"), "256 E1 all-pass")
    if len(e1_all) != 40:
        raise RuntimeError(f"Expected 40 accepted 256 E1 full-drain rows, got {len(e1_all)}")
    e1_pairs: list[dict[str, str]] = []
    by_load: dict[str, list[dict[str, str]]] = {}
    for r in e1_all:
        by_load.setdefault(r["load"], []).append(r)
    for load, pair in by_load.items():
        if len(pair) != 2 or len({r["trace_sha256"] for r in pair}) != 1:
            raise RuntimeError(f"256 E1 trace pairing failed at M{load}")
        if all(truth(r.get("near_lossless")) and not truth(r.get("censored")) for r in pair):
            e1_pairs.extend(pair)
        else:
            for r in pair:
                exclude("256", "global_ur_latency", r.get("case", ""), r.get("design", ""), load,
                        "full-drain PASS but point is censored or outside shared near-lossless set", e1_src)
    write_csv(OUT / "256/01_global_ur/throughput_all_full_drain.csv", e1_fields, e1_all)
    write_csv(OUT / "256/01_global_ur/common_near_lossless_latency.csv", e1_fields, e1_pairs)
    for rel, rows, cls, rule in (
        ("256/01_global_ur/throughput_all_full_drain.csv", e1_all, "accepted_throughput", "20 loads x 2 DUTs; full-drain 55k/55k and paired trace"),
        ("256/01_global_ur/common_near_lossless_latency.csv", e1_pairs, "paired_latency_eligible", "only loads where both DUTs are near_lossless, uncensored, full-drain and share trace hash"),
    ):
        index.append({"nodes": "256", "experiment": "global_ur_m16_vs_fm256", "classification": cls,
                      "row_count": str(len(rows)), "source_path": str(e1_src.relative_to(ROOT)),
                      "bundle_path": rel, "source_sha256": sha256(e1_src), "bundle_sha256": sha256(OUT / rel),
                      "acceptance_rule": rule})

    # 256-node repaired locality: only paired p values for which both designs are eligible.
    loc_src = P256_REPAIR / "acceptance_e3_m120.csv"
    loc_fields, loc_rows = read_csv(loc_src)
    loc_by_p: dict[str, list[dict[str, str]]] = {}
    for r in loc_rows:
        loc_by_p.setdefault(r["locality_p"], []).append(r)
    loc_ok: list[dict[str, str]] = []
    good_ps: set[str] = set()
    for p, pair in loc_by_p.items():
        eligible = len(pair) == 2 and all(truth(r.get("pass")) and truth(r.get("near_lossless"))
                                          and truth(r.get("paper_eligible")) for r in pair)
        if eligible and len({r["trace_sha256"] for r in pair}) == 1:
            good_ps.add(p)
            loc_ok.extend(pair)
        else:
            for r in pair:
                exclude("256", "locality_m120", r.get("case", ""), r.get("design", ""),
                        f"M120 p={p}", "not part of a fully paired near-lossless/ paper-eligible point", loc_src)
    if len(loc_ok) != 6 or len(good_ps) != 3:
        raise RuntimeError(f"Expected 3 paired locality settings / 6 rows, got {len(good_ps)} / {len(loc_ok)}")
    write_csv(OUT / "256/02_locality/locality_m120_paired_eligible.csv", loc_fields, loc_ok)
    index.append({"nodes": "256", "experiment": "locality_m120", "classification": "paired_latency_eligible",
                  "row_count": str(len(loc_ok)), "source_path": str(loc_src.relative_to(ROOT)),
                  "bundle_path": "256/02_locality/locality_m120_paired_eligible.csv",
                  "source_sha256": sha256(loc_src), "bundle_sha256": sha256(OUT / "256/02_locality/locality_m120_paired_eligible.csv"),
                  "acceptance_rule": "M120; both DUTs pass, near_lossless and paper_eligible; paired canonical trace"})
    loc_summary_src = P256_REPAIR / "summary_e3_m120.csv"
    loc_summary_fields, loc_summary_rows = read_csv(loc_summary_src)
    loc_cases = {r["case"] for r in loc_ok}
    loc_summary_ok = [r for r in loc_summary_rows if r.get("case") in loc_cases]
    if len(loc_summary_ok) != 6:
        raise RuntimeError(f"Expected six accepted locality summary rows, got {len(loc_summary_ok)}")
    loc_sum_rel = "256/02_locality/locality_m120_paired_summary.csv"
    write_csv(OUT / loc_sum_rel, loc_summary_fields, loc_summary_ok)
    index.append({"nodes": "256", "experiment": "locality_m120", "classification": "paired_metrics_summary",
                  "row_count": str(len(loc_summary_ok)), "source_path": str(loc_summary_src.relative_to(ROOT)),
                  "bundle_path": loc_sum_rel, "source_sha256": sha256(loc_summary_src),
                  "bundle_sha256": sha256(OUT / loc_sum_rel),
                  "acceptance_rule": "summary rows restricted to the six cases passing paired locality acceptance"})

    # 256-node repaired F16: M5/M20 accepted only; M40 censored stress stays out of the data tables.
    f16_src = P256_REPAIR / "acceptance_e2_f16_2tile.csv"
    f16_fields, f16_rows = read_csv(f16_src)
    f16_accept = [r for r in f16_rows if truth(r.get("pass")) and truth(r.get("paper_eligible"))
                  and not truth(r.get("censored")) and r.get("load") in {"5", "20"}]
    f16_cases = {r["case"] for r in f16_accept}
    f16_summary_src = P256_REPAIR / "summary_e2_f16_2tile.csv"
    f16_summary_fields, f16_summary_rows = read_csv(f16_summary_src)
    f16_ok = [r for r in f16_summary_rows if r.get("case") in f16_cases
              and r.get("completed_originals") == "400" and r.get("original_transactions") == "400"
              and r.get("useful_destination_deliveries") == "6400" and truth(r.get("full_drain_pass"))
              and not truth(r.get("censored"))]
    unique(f16_ok, ("load", "scheme"), "256 F16 accepted")
    if len(f16_ok) != 4 or {r["load"] for r in f16_ok} != {"5", "20"} or len(f16_accept) != 4:
        raise RuntimeError(f"Expected F16 M5/M20 Native/Repeated (4 rows), got acceptance={len(f16_accept)} summary={len(f16_ok)}")
    acc_rel = "256/03_f16_cross_tier/f16_2tile_m5_m20_acceptance.csv"
    sum_rel = "256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv"
    write_csv(OUT / acc_rel, f16_fields, f16_accept)
    write_csv(OUT / sum_rel, f16_summary_fields, f16_ok)
    for rel, src, rows, cls, rule in (
        (acc_rel, f16_src, f16_accept, "acceptance", "PASS, paper_eligible, not censored; M5/M20 only"),
        (sum_rel, f16_summary_src, f16_ok, "summary", "400/400 originals, 6400 useful destinations, full drain, not censored"),
    ):
        index.append({"nodes": "256", "experiment": "f16_cross_tier_2tile", "classification": cls,
                      "row_count": str(len(rows)), "source_path": str(src.relative_to(ROOT)),
                      "bundle_path": rel, "source_sha256": sha256(src), "bundle_sha256": sha256(OUT / rel),
                      "acceptance_rule": rule})
    for r in f16_rows:
        if r not in f16_accept:
            exclude("256", "f16_cross_tier_2tile", r.get("case", ""), r.get("scheme", ""), r.get("load", ""),
                    "censored stress or not paper eligible; excluded from positive comparison", f16_src)

    # Include selected raw case CSVs only for the accepted M120 locality and M5/M20 F16 cases.
    case_map: list[tuple[str, Path]] = []
    for r in loc_ok:
        case = r["case"]
        sources = [
            ("case_results", P256_CURATED_REPAIR / "case_results" / f"sdf_{case}.csv"),
            ("case_logs", P256_CURATED_REPAIR / "case_logs" / f"{case}.v3_metrics.csv"),
            ("latency", P256_CURATED_REPAIR / "latency" / f"{case}.latency.csv"),
            ("flit_latency", P256_CURATED_REPAIR / "flit_latency" / f"{case}.flit_latency.csv"),
            ("events", P256_CURATED_REPAIR / "events" / f"{case}.events.csv"),
        ]
        if r.get("design") == "PROP_temp256_m16":
            sources.append(("upper_mesh_counters", P256_CURATED_REPAIR / "upper_mesh_counters" / f"{case}.csv"))
        for kind, src in sources:
            case_map.append((f"256/02_locality/raw/{kind}/{src.name}", src))
    for r in f16_ok:
        case = r["case"]
        for kind, src in [
            ("case_results", P256_CURATED_REPAIR / "case_results" / f"sdf_{case}.csv"),
            ("case_logs", P256_CURATED_REPAIR / "case_logs" / f"{case}.v3_metrics.csv"),
            ("latency", P256_CURATED_REPAIR / "latency" / f"{case}.latency.csv"),
            ("flit_latency", P256_CURATED_REPAIR / "flit_latency" / f"{case}.flit_latency.csv"),
            ("events", P256_CURATED_REPAIR / "events" / f"{case}.events.csv"),
        ]:
            case_map.append((f"256/03_f16_cross_tier/raw/{kind}/{src.name}", src))
    for rel, src in case_map:
        _, case_rows = read_csv(src)
        copy_artifact(src, rel, "256", "accepted_raw_case_data", "selected_full_drain_case_csv",
                      len(case_rows), "Copied only when the parent case is present in a paper_eligible acceptance CSV")

    # Traceability / exclusions. No rejected measurement rows are copied into the accepted data directories.
    write_csv(OUT / "included_files.csv", INDEX_FIELDS, index)
    write_csv(OUT / "excluded_cases.csv", EXCLUSION_FIELDS, exclusions)
    readme = f"""# Validated 64/256-node experiment CSV bundle

This folder is an additive, filtered view. Source archives remain unchanged. A CSV appears under the accepted data
folders only after the acceptance gates listed in `included_files.csv`; SHA-256 is recorded for each source and copy.

## Classification

- `64/01_ur`: all accepted throughput points are separate from the pre-saturation, near-lossless latency subset.
- `64/02_benchmarks`: BC/Hotspot10 requires SDF PASS, paired trace, full drain, complete 10k/50k cohort; latency view
  further requires near-lossless and latency eligibility.
- `64/03_static4`: only M5/M100/M420 paper points; selection probes are listed in `excluded_cases.csv`.
- `64/04_multicast`: clean F2/F16/F32 paired Native/Repeated cases, 400/400, full drain, zero backlog. F16 M60 is
  censored stress and is excluded from the positive-comparison CSV.
- `64/05_ppa_power`: final Table 64-I, accepted QoR hashes, and passed network PT-PX estimates. These remain
  post-synthesis estimates, not post-layout or silicon measurements.
- `64/06_router`: only accepted Async c1p1/c1p2/c1p4 aggregate MAXIMUM-SDF rows; failed Sync aggregate is excluded.
- `64/07_sync_b8`: kept separate from Async. Includes the 30/30 full-drain Sync B8 UR scan and passed M100/M420
  PT-PX points; clock power is pre-CTS.
- `256/01_global_ur`: 20 paired loads, two DUTs, full-drain PASS; latency is a second table containing only the common
  uncensored near-lossless subset.
- `256/02_locality`: repaired M120 results only at paired eligible p={','.join(sorted(good_ps, key=float))}; p=0.90 is
  excluded because PROP-M16 is not near-lossless. Selected raw CSVs and upper-Mesh accepted-handshake counters are
  included only for accepted cases.
- `256/03_f16_cross_tier`: repaired adjacent-tile 8+8 F16 M5/M20 Native/Repeated; M40 censored cases are excluded.

## Explicit exclusions

`excluded_cases.csv` records valid throughput points not eligible for positive latency claims, selection probes,
censored stress points, and unpaired/ineligible 256 locality points. It contains identifiers and reasons, not rejected
measurement payloads. The malformed first-batch 256 F16 Native cases, old tick=20 results, failed PROP-M16 high-load
diagnostic cases, stale/right-censored 64 summaries, failed `core64_power` results, and dependency-invalid PEND jobs are
not copied into this bundle.

## Counts

- 64 UR: {len(ur_all)} accepted throughput rows; {len(ur_latency)} positive-latency rows.
- 64 BC/Hotspot10: {len(bench_all)} accepted rows; {len(bench_latency)} latency-eligible rows.
- 64 Static4 paper points: {len(static_ok)}; clean multicast: {len(mc_ok)}; Sync UR: {len(sync_ok)}.
- 256 E1: {len(e1_all)} full-drain rows; {len(e1_pairs)} rows in common near-lossless latency pairs.
- 256 repaired locality: {len(loc_ok)} paired eligible rows; 256 repaired F16: {len(f16_ok)} accepted rows.

See `included_files.csv` for file-level provenance and hashes. `excluded_cases.csv` is an audit list, not publication data.
"""
    (OUT / "README.md").write_text(readme, encoding="utf-8", newline="\n")

    # Hash manifest is intentionally JSON as well as the machine-readable CSV index.
    manifest = {
        "bundle": OUT.name,
        "sources": {
            "64_cohort": str(P64_COHORT.relative_to(ROOT)),
            "64_final": str(P64_FINAL.relative_to(ROOT)),
            "256_current": str(P256_CURRENT.relative_to(ROOT)),
            "256_repair": str(P256_REPAIR.relative_to(ROOT)),
        },
        "included_file_count": len(index),
        "excluded_case_count": len(exclusions),
        "policy": "Never merge failed, censored, right-censored, ineligible, stale or malformed runs into accepted data tables.",
        "sha256": {},
    }
    for f in sorted(OUT.rglob("*")):
        if f.is_file() and f.name != "manifest.json":
            manifest["sha256"][f.relative_to(OUT).as_posix()] = sha256(f)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"output": str(OUT), "indexed_files": len(index), "excluded_cases": len(exclusions),
                      "64_ur_rows": len(ur_all), "64_ur_latency_rows": len(ur_latency),
                      "64_benchmark_rows": len(bench_all), "64_benchmark_latency_rows": len(bench_latency),
                      "64_multicast_rows": len(mc_ok), "64_sync_rows": len(sync_ok),
                      "256_e1_rows": len(e1_all), "256_e1_common_latency_rows": len(e1_pairs),
                      "256_locality_rows": len(loc_ok), "256_f16_rows": len(f16_ok)}, indent=2))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build the final, paper-facing 64/256-node result tables.

The frozen validated bundle remains the baseline.  Two locally verified,
full-drain supplemental scans repair Mesh64 UR M100--M300 and add the missing
PFAT64 BC/Hotspot10 series; the builder reads only their compact audit tables,
never loose simulator logs.
"""

from __future__ import annotations

import csv
import hashlib
import json
import shutil
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[3]
PAPER_DIR = ROOT / ("DATE_paper" if (ROOT / "DATE_paper").is_dir() else "DATE paper")
SRC = PAPER_DIR / "experiments" / "curated" / "validated_64_256_csv_20260918"
OUT = PAPER_DIR / "experiments" / "final" / "20260918_64_256_final"
DATA = OUT / "data"
MESH64_REPAIR = PAPER_DIR / "experiments/raw/paper64/mesh64_tbfix_ur_m100_300_20260918_223859/mesh64_tbfix_summary.csv"
PFAT64_BENCH = PAPER_DIR / "experiments/raw/paper64/pfat64_bc_hotspot64_20260918_224453/pfat64_bc_hotspot_summary.csv"
PFAT64_EXCLUDED = PAPER_DIR / "experiments/raw/paper64/pfat64_bc_hotspot64_20260918_224453/pfat64_bc_hotspot_excluded.csv"

EXPECTED_COUNTS = {
    "64/01_ur/throughput_all_accepted.csv": 90,
    "64/01_ur/pre_saturation_latency_accepted.csv": 44,
    "64/02_benchmarks/bc_hotspot_all_accepted.csv": 120,
    "64/02_benchmarks/bc_hotspot_latency_eligible.csv": 62,
    "64/04_multicast/clean_fanout_400tx.csv": 8,
    "64/06_router/router_lane_scaling.csv": 3,
    "64/07_sync_b8/ur_all_full_drain.csv": 30,
    "64/07_sync_b8/ur_pre_saturation_latency.csv": 19,
    "256/01_global_ur/throughput_all_full_drain.csv": 40,
    "256/01_global_ur/common_near_lossless_latency.csv": 18,
    "256/02_locality/locality_m120_paired_summary.csv": 6,
    "256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv": 4,
}

LABELS = {
    "FM64": "Mesh",
    "FM256": "Mesh",
    "PROP_temp64": "PROP",
    "PROP_temp256_m16": "PROP",
    "PFAT64": "FAT",
    "SYNC_PROP_temp64_B8": "Sync",
    "Full PROP": "PROP",
    "FlatMesh64": "Mesh",
    "Sync B8": "Sync",
    "native": "Native",
    "source_repeated_unicast": "Repeated",
    "Native": "Native",
    "Repeated": "Repeated",
}

# Node-level (isolated router primitive) PPA source.  This lives outside the
# validated CSV bundle: it is the frozen paper hop-PPA campaign
# (MAXIMUM-SDF GLS + PT-PX, DC cell area, no P&R).
NODE_PPA_REL = "scripts/asic_dc/cmr/results/bundles/20260913_093043_rpsdel050_paper/hop_ppa"
NODE_PPA_METRICS = ROOT / NODE_PPA_REL / "metrics.csv"
NODE_PPA_CALIBRATION = ROOT / NODE_PPA_REL / "calibration.json"

# Paper topology family for each router primitive geometry (child x parent).
NODE_TOPOLOGIES = {
    "async_thin_1x1": "Thin",
    "async_flatmesh_1x1": "Mesh",
    "async_fat_1x2": "FAT",
    "async_prop_2x2": "PROP",
    "async_topmesh_2x2": "TopMesh",
    "async_pfat_2x4": "PFAT",
    "async_pfat_4x8": "PFAT",
}

# c1p4 (fat_1x4: one child x four parent) router primitive PPA, async plus its
# synchronous counterpart. Separate 2026-09-14 bundle; not part of the
# 2026-09-13 paper hop-PPA campaign above.
C1P4_PPA_REL = "scripts/asic_dc/cmr/results/20260914_cmr_c1p4_async_sync_hop_ppa"
C1P4_PPA_METRICS = ROOT / C1P4_PPA_REL / "metrics.csv"
C1P4_PPA_CALIBRATION = ROOT / C1P4_PPA_REL / "calibration.json"

C1P4_TOPOLOGIES = {
    "async_fat_1x4": "FAT",
    "sync_fat_1x4": "Sync",
}
C1P4_CAVEATS = {
    "sync_fat_1x4": "per-hop latency quantized to the 1.0 ns clock period "
                    "(1 cycle/hop at 1 GHz); clocked, not a measured propagation delay",
}


def read_csv(rel: str) -> list[dict[str, str]]:
    path = SRC / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"missing or empty validated input: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def read_path(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(f"missing or empty supplemental input: {path}")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def root_rel(path: Path) -> str:
    return str(path.relative_to(ROOT)).replace("\\", "/")


def write_csv(path: Path, fields: list[str], rows: Iterable[dict[str, object]]) -> None:
    rows = list(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def f(value: str) -> float:
    return float(value)


def truth(value: str) -> bool:
    return value.strip().lower() in {"true", "1", "yes", "pass"}


def label(design: str) -> str:
    if design not in LABELS:
        raise RuntimeError(f"missing paper label mapping for {design!r}")
    return LABELS[design]


def keyed(rows: list[dict[str, str]], keys: tuple[str, ...]) -> dict[tuple[str, ...], dict[str, str]]:
    result: dict[tuple[str, ...], dict[str, str]] = {}
    for row in rows:
        key = tuple(row[k] for k in keys)
        if key in result:
            raise RuntimeError(f"duplicate key {keys}={key}")
        result[key] = row
    return result


def source_row(rel: str, row: dict[str, str], *, case_field: str = "case", run_field: str = "") -> dict[str, object]:
    return {
        "source_file": rel,
        "source_design": row.get("design", row.get("scheme", "")),
        "source_case": row.get(case_field, ""),
        "source_run_id": row.get(run_field, "") if run_field else "",
    }


def build_unicast64() -> list[dict[str, object]]:
    ur_all_rel = "64/01_ur/throughput_all_accepted.csv"
    ur_lat_rel = "64/01_ur/pre_saturation_latency_accepted.csv"
    bm_all_rel = "64/02_benchmarks/bc_hotspot_all_accepted.csv"
    bm_lat_rel = "64/02_benchmarks/bc_hotspot_latency_eligible.csv"
    ur_all, ur_lat = read_csv(ur_all_rel), read_csv(ur_lat_rel)
    bm_all, bm_lat = read_csv(bm_all_rel), read_csv(bm_lat_rel)
    ur_lut = keyed(ur_lat, ("design", "load_setpoint_mflit_per_port_s"))
    bm_lut = keyed(bm_lat, ("design", "benchmark", "load_setpoint_mflit_per_port_s"))
    out: list[dict[str, object]] = []
    for row in ur_all:
        key = (row["design"], row["load_setpoint_mflit_per_port_s"])
        lat = ur_lut.get(key)
        lat_source = source_row(ur_lat_rel, lat, run_field="netlist_run_id") if lat else {}
        item = {
            "nodes": 64, "traffic": "UR", "paper_label": label(row["design"]),
            "load_m": int(row["load_setpoint_mflit_per_port_s"]),
            "offered_mflit_s_per_port": f(row["offered_mflit_per_port_s"]),
            "delivered_mflit_s_per_port": f(row["delivered_mflit_per_port_s"]),
            "mean_latency_ns": f(lat["cohort_mean_ns"]) if lat else "",
            "latency_eligible": bool(lat),
            **source_row(ur_all_rel, row, run_field="netlist_run_id"),
            "latency_source_file": lat_source.get("source_file", ""),
            "latency_source_design": lat_source.get("source_design", ""),
            "latency_source_case": lat_source.get("source_case", ""),
            "latency_source_run_id": lat_source.get("source_run_id", ""),
        }
        out.append(item)
    traffic_names = {"TOPO-BC": "BC", "HOTSPOT10": "Hotspot10"}
    for row in bm_all:
        key = (row["design"], row["benchmark"], row["load_setpoint_mflit_per_port_s"])
        lat = bm_lut.get(key)
        lat_source = source_row(bm_lat_rel, lat, case_field="result_case",
                                run_field="netlist_run_id") if lat else {}
        item = {
            "nodes": 64, "traffic": traffic_names[row["benchmark"]],
            "paper_label": label(row["design"]),
            "load_m": int(row["load_setpoint_mflit_per_port_s"]),
            "offered_mflit_s_per_port": f(row["offered_mflit_per_port_s"]),
            "delivered_mflit_s_per_port": f(row["delivered_mflit_per_port_s"]),
            "mean_latency_ns": f(lat["cohort_mean_ns"]) if lat else "",
            "latency_eligible": bool(lat),
            **source_row(bm_all_rel, row, case_field="result_case", run_field="netlist_run_id"),
            "latency_source_file": lat_source.get("source_file", ""),
            "latency_source_design": lat_source.get("source_design", ""),
            "latency_source_case": lat_source.get("source_case", ""),
            "latency_source_run_id": lat_source.get("source_run_id", ""),
        }
        out.append(item)

    # Replace the Mesh64 UR M100--M300 baseline rows with the repaired-TB
    # rerun.  Setpoint keys are stable while plot x values remain measured rates.
    mesh_repairs = read_path(MESH64_REPAIR)
    if len(mesh_repairs) != 11 or any(row["pass_fail"] != "PASS" for row in mesh_repairs):
        raise RuntimeError("Mesh64 repaired scan must contain 11 PASS rows")
    repair_by_load = {int(row["load_m"]): row for row in mesh_repairs}
    for item in out:
        if item["paper_label"] != "Mesh" or item["traffic"] != "UR" or int(item["load_m"]) not in repair_by_load:
            continue
        row = repair_by_load[int(item["load_m"])]
        eligible = truth(row["latency_eligible"])
        item.update({
            "offered_mflit_s_per_port": f(row["offered_mflit_s_per_port"]),
            "delivered_mflit_s_per_port": f(row["delivered_mflit_s_per_port"]),
            "mean_latency_ns": f(row["mean_flit_latency_ns"]) if eligible else "",
            "latency_eligible": eligible,
            "source_file": root_rel(MESH64_REPAIR), "source_design": "FM64",
            "source_case": row["case_name"],
            "source_run_id": "20260918_223859_mesh64_tbfix_ur_m100_300",
            "latency_source_file": root_rel(MESH64_REPAIR) if eligible else "",
            "latency_source_design": "FM64" if eligible else "",
            "latency_source_case": row["case_name"] if eligible else "",
            "latency_source_run_id": "20260918_223859_mesh64_tbfix_ur_m100_300" if eligible else "",
        })

    # Add the previously missing PFAT64 benchmark scans.  Hotspot10 stops at
    # M400 because M420 failed correctness; later cases are recorded as skipped.
    pfat_rows = read_path(PFAT64_BENCH)
    if len(pfat_rows) != 52 or any(row["pass_fail"] != "PASS" for row in pfat_rows):
        raise RuntimeError("PFAT64 benchmark scan must contain 52 PASS rows")
    for row in pfat_rows:
        eligible = truth(row["latency_eligible"])
        source = root_rel(PFAT64_BENCH)
        out.append({
            "nodes": 64, "traffic": row["traffic"], "paper_label": "FAT",
            "load_m": int(row["load_m"]),
            "offered_mflit_s_per_port": f(row["offered_mflit_s_per_port"]),
            "delivered_mflit_s_per_port": f(row["delivered_mflit_s_per_port"]),
            "mean_latency_ns": f(row["mean_flit_latency_ns"]) if eligible else "",
            "latency_eligible": eligible,
            "source_file": source, "source_design": "PFAT64",
            "source_case": row["case_name"],
            "source_run_id": "20260918_224453_pfat64_bc_hotspot64",
            "latency_source_file": source if eligible else "",
            "latency_source_design": "PFAT64" if eligible else "",
            "latency_source_case": row["case_name"] if eligible else "",
            "latency_source_run_id": "20260918_224453_pfat64_bc_hotspot64" if eligible else "",
        })
    order = {"UR": 0, "BC": 1, "Hotspot10": 2, "Mesh": 0, "PROP": 1, "FAT": 2}
    return sorted(out, key=lambda r: (order[str(r["traffic"])], order[str(r["paper_label"])], int(r["load_m"])))


def build_shared_scan64(unicast: list[dict[str, object]], metric: str) -> list[dict[str, object]]:
    """Combine comparable 64-node traffic and implementation scans on one rate axis."""
    if metric not in {"delivered_throughput", "mean_flit_latency"}:
        raise ValueError(f"unsupported shared-scan metric: {metric}")
    latency = metric == "mean_flit_latency"
    output: list[dict[str, object]] = []

    def append(topology: str, mode: str, traffic: str, offered: float, value: float,
               source: dict[str, object], eligibility: str) -> None:
        output.append({
            "nodes": 64, "topology": topology, "mode": mode, "traffic": traffic,
            "offered_mflit_s_per_port": offered, "metric": metric, "value": value,
            "value_unit": "ns" if latency else "Mflit/s/port",
            "eligibility": eligibility, **source,
        })

    mode_for_traffic = {"UR": "UR (Async)", "BC": "BC", "Hotspot10": "Hotspot10"}
    for row in unicast:
        traffic = str(row["traffic"])
        if latency and not row["latency_eligible"]:
            continue
        value = row["mean_latency_ns"] if latency else row["delivered_mflit_s_per_port"]
        if value == "":
            continue
        if latency:
            source = {
                "source_file": row["latency_source_file"],
                "source_design": row["latency_source_design"],
                "source_case": row["latency_source_case"],
                "source_run_id": row["latency_source_run_id"],
            }
        else:
            source = {key: row[key] for key in ("source_file", "source_design", "source_case", "source_run_id")}
        append(
            str(row["paper_label"]), mode_for_traffic[traffic], traffic,
            f(str(row["offered_mflit_s_per_port"])), f(str(value)),
            source,
            "paired near-lossless latency" if latency else "correctness/full-drain throughput",
        )

    sync_all_rel = "64/07_sync_b8/ur_all_full_drain.csv"
    sync_lat_rel = "64/07_sync_b8/ur_pre_saturation_latency.csv"
    sync_rows = read_csv(sync_lat_rel if latency else sync_all_rel)
    if latency:
        sync_rows = [row for row in sync_rows if truth(row["paper_latency_eligible"])]
    else:
        sync_rows = [row for row in sync_rows if truth(row["full_drain_pass"])]
    for row in sync_rows:
        value = f(row["cohort_mean_ns"]) if latency else f(row["delivered_mflit_per_port_s"])
        append("PROP", "UR (Sync)", "UR", f(row["offered_mflit_per_port_s"]), value,
               source_row(sync_lat_rel if latency else sync_all_rel, row, run_field="netlist_run_id"),
               "paired near-lossless latency" if latency else "correctness/full-drain throughput")

    topology_order = {"Mesh": 0, "PROP": 1, "FAT": 2}
    mode_order = {"UR (Async)": 0, "UR (Sync)": 1, "BC": 2, "Hotspot10": 3}
    output.sort(key=lambda row: (topology_order[str(row["topology"])],
                                 mode_order[str(row["mode"])],
                                 f(str(row["offered_mflit_s_per_port"]))))
    return output


def build_mesh64_latency_audit() -> list[dict[str, object]]:
    """Retain measured Mesh UR latency/censoring context without treating it as plot data."""
    rel = "64/01_ur/throughput_all_accepted.csv"
    source = [row for row in read_csv(rel) if row["design"] == "FM64"]
    result = [{
        "load_setpoint_mflit_per_port_s": int(row["load_setpoint_mflit_per_port_s"]),
        "offered_mflit_per_port_s": f(row["offered_mflit_per_port_s"]),
        "delivered_mflit_per_port_s": f(row["delivered_mflit_per_port_s"]),
        "backlog_flits": int(float(row["backlog"])),
        "observed_flit_mean_latency_ns": row["flit_latency_mean_ns"],
        "cohort_mean_latency_ns": row["cohort_mean_ns"],
        "cohort_latency_status": row["cohort_latency_status"],
        "near_lossless": row["near_lossless"],
        "paper_latency_eligible": row["paper_latency_eligible"],
        **source_row(rel, row, run_field="netlist_run_id"),
    } for row in source]
    repairs = {int(row["load_m"]): row for row in read_path(MESH64_REPAIR)}
    for item in result:
        load = int(item["load_setpoint_mflit_per_port_s"])
        if load not in repairs:
            continue
        row = repairs[load]
        eligible = truth(row["latency_eligible"])
        item.update({
            "offered_mflit_per_port_s": f(row["offered_mflit_s_per_port"]),
            "delivered_mflit_per_port_s": f(row["delivered_mflit_s_per_port"]),
            "backlog_flits": int(row["measurement_backlog_flits"]),
            "observed_flit_mean_latency_ns": row["mean_flit_latency_ns"],
            "cohort_mean_latency_ns": row["mean_flit_latency_ns"] if eligible else "",
            "cohort_latency_status": "PASS" if eligible else "THROUGHPUT_ONLY",
            "near_lossless": str(eligible), "paper_latency_eligible": str(eligible),
            "source_file": root_rel(MESH64_REPAIR), "source_design": "FM64",
            "source_case": row["case_name"],
            "source_run_id": "20260918_223859_mesh64_tbfix_ur_m100_300",
        })
    result.sort(key=lambda row: int(row["load_setpoint_mflit_per_port_s"]))
    if len(result) != 30:
        raise RuntimeError(f"expected 30 Mesh UR latency-audit rows, found {len(result)}")
    return result


def offered_256(row: dict[str, str]) -> float:
    # delivered / ratio recovers offered flits.  ps -> Mflit/s contributes 1e6,
    # and E1 has 256 injection ports.
    duration_ps = f(row["measurement_end_ps"]) - f(row["measurement_start_ps"])
    offered_flits = f(row["measurement_delivered_flits"]) / f(row["measurement_delivery_ratio"])
    return offered_flits * 1e6 / duration_ps / 256.0


def build_unicast256() -> list[dict[str, object]]:
    all_rel = "256/01_global_ur/throughput_all_full_drain.csv"
    lat_rel = "256/01_global_ur/common_near_lossless_latency.csv"
    loc_rel = "256/02_locality/locality_m120_paired_summary.csv"
    all_rows, lat_rows, loc_rows = read_csv(all_rel), read_csv(lat_rel), read_csv(loc_rel)
    lat_lut = keyed(lat_rows, ("design", "load"))
    out: list[dict[str, object]] = []
    for row in all_rows:
        lat = lat_lut.get((row["design"], row["load"]))
        out.append({
            "nodes": 256, "section": "global_ur", "paper_label": label(row["design"]),
            "x_name": "offered_mflit_s_per_port", "x_value": offered_256(row),
            "load_m": int(row["load"]),
            "delivered_mflit_s_per_port": f(row["delivered_mflit_s_per_port"]),
            "mean_latency_ns": f(lat["mean_flit_latency_ns"]) if lat else "",
            "latency_eligible": bool(lat),
            "derivation": "offered=(measurement_delivered_flits/delivery_ratio)*1e6/(window_ps*256)",
            **source_row(all_rel, row),
        })
    for row in loc_rows:
        out.append({
            "nodes": 256, "section": "locality", "paper_label": label(row["design"]),
            "x_name": "locality_probability", "x_value": f(row["locality_p"]),
            "load_m": int(row["load"]), "delivered_mflit_s_per_port": "",
            "mean_latency_ns": f(row["mean_flit_latency_ns"]), "latency_eligible": True,
            "derivation": "direct accepted paired mean flit latency",
            **source_row(loc_rel, row),
        })
    section_order = {"global_ur": 0, "locality": 1, "Mesh": 0, "PROP": 1}
    return sorted(out, key=lambda r: (section_order[str(r["section"])], section_order[str(r["paper_label"])], f(str(r["x_value"]))))


def build_multicast() -> list[dict[str, object]]:
    mc64_rel = "64/04_multicast/clean_fanout_400tx.csv"
    mc256_rel = "256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv"
    out: list[dict[str, object]] = []
    for row in read_csv(mc64_rel):
        fanout, load = int(row["fanout"]), int(row["load"])
        section = "fanout64_m5" if load == 5 else "f16_64"
        if fanout == 16:
            section = "f16_64" if load in {5, 20} else section
        out.append({
            "nodes": 64, "section": section, "paper_label": label(row["scheme"]),
            "fanout": fanout, "load_m": load,
            "mean_completion_latency_ns": f(row["mean_completion_latency"]),
            "useful_delivery_rate_mdelivery_s": f(row["useful_delivery_rate"]),
            **source_row(mc64_rel, row, run_field="source_run_id"),
        })
    for row in read_csv(mc256_rel):
        out.append({
            "nodes": 256, "section": "f16_256_cross_tier", "paper_label": label(row["scheme"]),
            "fanout": 16, "load_m": int(row["load"]),
            "mean_completion_latency_ns": f(row["completion_mean_ns"]),
            "useful_delivery_rate_mdelivery_s": "",
            **source_row(mc256_rel, row),
        })
    order = {"fanout64_m5": 0, "f16_64": 1, "f16_256_cross_tier": 2, "Native": 0, "Repeated": 1}
    return sorted(out, key=lambda r: (order[str(r["section"])], int(r["load_m"]), int(r["fanout"]), order[str(r["paper_label"])]))


def build_implementation64() -> list[dict[str, object]]:
    ur_all_rel = "64/01_ur/throughput_all_accepted.csv"
    ur_lat_rel = "64/01_ur/pre_saturation_latency_accepted.csv"
    sync_all_rel = "64/07_sync_b8/ur_all_full_drain.csv"
    sync_lat_rel = "64/07_sync_b8/ur_pre_saturation_latency.csv"
    router_rel = "64/06_router/router_lane_scaling.csv"
    power_rel = "64/05_ppa_power/network_power_async_accepted.csv"
    ur_all, ur_lat = read_csv(ur_all_rel), read_csv(ur_lat_rel)
    ur_lat_lut = keyed(ur_lat, ("design", "load_setpoint_mflit_per_port_s"))
    out: list[dict[str, object]] = []
    paper_loads = {5, 100, 420}
    for row in ur_all:
        load = int(row["load_setpoint_mflit_per_port_s"])
        if row["design"] == "PROP_temp64" and load in paper_loads:
            lat = ur_lat_lut[(row["design"], row["load_setpoint_mflit_per_port_s"])]
            out.append({
                "section": "dynamic_latency", "paper_label": "Dynamic", "x_value": load,
                "x_unit": "M", "metric": "mean_latency_ns", "value": f(lat["cohort_mean_ns"]),
                "physical_class": "post-synthesis MAXIMUM-SDF",
                **source_row(ur_lat_rel, lat, run_field="netlist_run_id"),
            })
    for row in ur_all:
        if row["design"] != "PROP_temp64":
            continue
        out.append({
            "section": "async_sync_throughput", "paper_label": "Async",
            "x_value": f(row["offered_mflit_per_port_s"]), "x_unit": "Mflit/s/port",
            "metric": "delivered_mflit_s_per_port", "value": f(row["delivered_mflit_per_port_s"]),
            "physical_class": "post-synthesis MAXIMUM-SDF",
            **source_row(ur_all_rel, row, run_field="netlist_run_id"),
        })
    for row in read_csv(sync_all_rel):
        out.append({
            "section": "async_sync_throughput", "paper_label": "Sync",
            "x_value": f(row["offered_mflit_per_port_s"]), "x_unit": "Mflit/s/port",
            "metric": "delivered_mflit_s_per_port", "value": f(row["delivered_mflit_per_port_s"]),
            "physical_class": "post-synthesis MAXIMUM-SDF",
            **source_row(sync_all_rel, row),
        })
    for row in ur_lat:
        if row["design"] != "PROP_temp64":
            continue
        out.append({
            "section": "async_sync_latency", "paper_label": "Async",
            "x_value": f(row["offered_mflit_per_port_s"]), "x_unit": "Mflit/s/port",
            "metric": "mean_latency_ns", "value": f(row["cohort_mean_ns"]),
            "physical_class": "post-synthesis MAXIMUM-SDF",
            **source_row(ur_lat_rel, row, run_field="netlist_run_id"),
        })
    for row in read_csv(sync_lat_rel):
        out.append({
            "section": "async_sync_latency", "paper_label": "Sync",
            "x_value": f(row["offered_mflit_per_port_s"]), "x_unit": "Mflit/s/port",
            "metric": "mean_latency_ns", "value": f(row["cohort_mean_ns"]),
            "physical_class": "post-synthesis MAXIMUM-SDF",
            **source_row(sync_lat_rel, row),
        })
    for row in read_csv(router_rel):
        out.append({
            "section": "router_lane_scaling", "paper_label": "Async",
            "x_value": int(row["physical_parent_lanes"]), "x_unit": "parent lanes",
            "metric": "aggregate_throughput_gflit_s", "value": f(row["aggregate_throughput_gflit_s"]),
            "physical_class": row["evidence_scope"],
            **source_row(router_rel, row),
        })
    power_ids = {"prop_m100": "PROP", "pfat_m100": "FAT", "flatmesh_m100": "Mesh"}
    for row in read_csv(power_rel):
        if row["id"] not in power_ids:
            continue
        for metric in ("total_power_w", "total_pj_per_delivered_flit"):
            out.append({
                "section": "topology_power_m100", "paper_label": power_ids[row["id"]],
                "x_value": 100, "x_unit": "M", "metric": metric, "value": f(row[metric]),
                "physical_class": row["physical_class"],
                **source_row(power_rel, row, run_field="netlist_run_id"),
            })
    section_order = {"dynamic_latency": 0, "async_sync_throughput": 1, "async_sync_latency": 2,
                     "router_lane_scaling": 3, "topology_power_m100": 4}
    label_order = {"Mesh": 0, "PROP": 1, "FAT": 2, "Dynamic": 0, "Async": 0, "Sync": 1}
    return sorted(out, key=lambda r: (section_order[str(r["section"])], str(r["metric"]),
                                      label_order[str(r["paper_label"])], f(str(r["x_value"]))))


def build_power64() -> list[dict[str, object]]:
    async_rel = "64/05_ppa_power/network_power_async_accepted.csv"
    sync_rel = "64/07_sync_b8/power_accepted.csv"
    out: list[dict[str, object]] = []
    for row in read_csv(async_rel):
        if row["design"] == "PROP_temp64_static4":
            continue
        paper_label = label(row["design"])
        role = row["id"]
        out.append({
            "paper_label": paper_label, "result_id": role,
            "total_power_w": f(row["total_power_w"]),
            "energy_pj_per_delivered_flit": row["total_pj_per_delivered_flit"],
            "energy_pj_per_useful_delivery": row["total_pj_per_useful_destination_delivery"],
            "physical_class": row["physical_class"],
            **source_row(async_rel, row, run_field="netlist_run_id"),
        })
    for row in read_csv(sync_rel):
        out.append({
            "paper_label": "Sync", "result_id": row["id"],
            "total_power_w": f(row["total_power_w"]),
            "energy_pj_per_delivered_flit": row["total_pj_per_delivered_flit"],
            "energy_pj_per_useful_delivery": "",
            "physical_class": row["physical_class"],
            **source_row(sync_rel, row),
        })
    return sorted(out, key=lambda r: (str(r["result_id"]), str(r["paper_label"])))


def build_area() -> list[dict[str, object]]:
    rel = "64/05_ppa_power/table64_i_network.csv"
    rows = []
    for row in read_csv(rel):
        if row["design"] == "Static4":
            continue
        rows.append({
            "paper_label": label(row["design"]), "source_design": row["design"],
            "area_um2": f(row["area_um2"]), "netlist_run_id": row["area_power_netlist_run_id"],
            "evidence_scope": row["evidence_scope"], "caveat": row["caveat"], "source_file": rel,
        })
    order = {"Mesh": 0, "PROP": 1, "FAT": 2, "Sync": 3}
    return sorted(rows, key=lambda r: order[str(r["paper_label"])])


def _node_ppa_bundle(metrics_path: Path, calibration_path: Path, topology_map: dict[str, str],
                     caveats: dict[str, str], source_rel: str) -> list[dict[str, object]]:
    """Read one hop-PPA bundle (metrics.csv + calibration.json) into node rows."""
    if not metrics_path.is_file() or not calibration_path.is_file():
        raise RuntimeError(f"missing node PPA source under {source_rel}")
    with calibration_path.open("r", encoding="utf-8") as handle:
        calibration = json.load(handle)
    netlist_by_kind = {item["kind"]: item["netlist_run_id"] for item in calibration["primitives"]}
    with metrics_path.open("r", encoding="utf-8-sig", newline="") as handle:
        metrics = list(csv.DictReader(handle))
    out: list[dict[str, object]] = []
    for row in metrics:
        geometry = row["geometry"]
        if geometry not in topology_map:
            raise RuntimeError(f"missing node topology mapping for {geometry!r}")
        left, parent = geometry.rsplit("x", 1)
        child = left.rsplit("_", 1)[-1]
        out.append({
            "topology": topology_map[geometry], "geometry": geometry,
            "child_ports": int(child), "parent_ports": int(parent),
            "max_opm_fanin": int(row["max_opm_fanin"]),
            "area_um2": f(row["area_um2"]),
            "head_ns": f(row["head_ns"]), "body_ns": f(row["body_ns"]), "tail_ns": f(row["tail_ns"]),
            "head_power_w": f(row["head_power_w"]), "body_power_w": f(row["body_power_w"]),
            "tail_power_w": f(row["tail_power_w"]), "packet_power_w": f(row["packet_power_w"]),
            "head_energy_j": f(row["head_energy_j"]), "body_energy_j": f(row["body_energy_j"]),
            "tail_energy_j": f(row["tail_energy_j"]), "packet_energy_j": f(row["packet_energy_j"]),
            "idle_power_w": f(row["idle_power_w"]), "active_power_w": f(row["active_power_w"]),
            "physical_class": "post-synthesis MAXIMUM-SDF + time-based PT-PX (DC cell area, no P&R)",
            "caveat": caveats.get(geometry, ""),
            "netlist_run_id": netlist_by_kind[geometry],
            "source_file": f"{source_rel}/metrics.csv",
        })
    return out


def build_node_ppa() -> list[dict[str, object]]:
    """Node-level (isolated router primitive) PPA: hop delay, DC cell area, power."""
    rows = _node_ppa_bundle(NODE_PPA_METRICS, NODE_PPA_CALIBRATION, NODE_TOPOLOGIES, {}, NODE_PPA_REL)
    rows += _node_ppa_bundle(C1P4_PPA_METRICS, C1P4_PPA_CALIBRATION, C1P4_TOPOLOGIES, C1P4_CAVEATS, C1P4_PPA_REL)
    order = {"Thin": 0, "Mesh": 1, "FAT": 2, "PROP": 3, "TopMesh": 4, "PFAT": 5, "Sync": 6}
    rows.sort(key=lambda r: (order[str(r["topology"])], int(r["child_ports"]), int(r["parent_ports"])))
    return rows


def long_rows(scan_throughput: list[dict[str, object]], scan_latency: list[dict[str, object]],
              fig2: list[dict[str, object]],
              fig3: list[dict[str, object]], fig4: list[dict[str, object]],
              power: list[dict[str, object]], area: list[dict[str, object]],
              node_ppa: list[dict[str, object]]) -> list[dict[str, object]]:
    out: list[dict[str, object]] = []

    def add(nodes: int, experiment: str, series: str, x_name: str, x_value: object,
            metric: str, value: object, unit: str, source: dict[str, object],
            eligibility: str = "accepted", mode: str = "") -> None:
        out.append({
            "nodes": nodes, "experiment": experiment, "paper_label": series, "mode": mode,
            "x_name": x_name, "x_value": x_value, "metric": metric, "value": value,
            "unit": unit, "eligibility": eligibility,
            "source_file": source.get("source_file", ""), "source_design": source.get("source_design", ""),
            "source_case": source.get("source_case", ""), "source_run_id": source.get("source_run_id", ""),
        })

    for rows in (scan_throughput, scan_latency):
        for row in rows:
            metric = "delivered_throughput" if row["metric"] == "delivered_throughput" else "mean_flit_latency"
            add(64, "unicast64_shared_scan", str(row["topology"]),
                "offered_mflit_s_per_port", row["offered_mflit_s_per_port"],
                metric, row["value"], str(row["value_unit"]), row, str(row["eligibility"]),
                mode=str(row["mode"]))
    for row in fig2:
        exp = "unicast256_global_ur" if row["section"] == "global_ur" else "unicast256_locality"
        if row["section"] == "global_ur":
            add(256, exp, str(row["paper_label"]), str(row["x_name"]), row["x_value"],
                "delivered_throughput", row["delivered_mflit_s_per_port"], "Mflit/s/port", row)
        if row["latency_eligible"]:
            add(256, exp, str(row["paper_label"]), str(row["x_name"]), row["x_value"],
                "mean_flit_latency", row["mean_latency_ns"], "ns", row, "paired near-lossless")
    for row in fig3:
        x_name = "fanout" if row["section"] == "fanout64_m5" else "load_m"
        x_value = row["fanout"] if x_name == "fanout" else row["load_m"]
        add(int(row["nodes"]), f"multicast_{row['section']}", str(row["paper_label"]), x_name, x_value,
            "mean_completion_latency", row["mean_completion_latency_ns"], "ns", row)
        if row["useful_delivery_rate_mdelivery_s"] != "":
            add(int(row["nodes"]), f"multicast_{row['section']}", str(row["paper_label"]), x_name, x_value,
                "useful_delivery_throughput", row["useful_delivery_rate_mdelivery_s"], "Mdelivery/s", row)
    for row in fig4:
        if row["section"] in {"dynamic_latency", "async_sync_throughput", "async_sync_latency"}:
            # These scan points are represented once in the shared 64-node tables above.
            continue
        unit = {"mean_latency_ns": "ns", "delivered_mflit_s_per_port": "Mflit/s/port",
                "aggregate_throughput_gflit_s": "Gflit/s", "total_power_w": "W",
                "total_pj_per_delivered_flit": "pJ/flit"}[str(row["metric"])]
        add(64, str(row["section"]), str(row["paper_label"]), str(row["x_unit"]), row["x_value"],
            str(row["metric"]), row["value"], unit, row)
    for row in power:
        add(64, "network_power", str(row["paper_label"]), "result_id", row["result_id"],
            "total_power", row["total_power_w"], "W", row)
        if row["energy_pj_per_delivered_flit"] != "":
            add(64, "network_power", str(row["paper_label"]), "result_id", row["result_id"],
                "energy_per_delivered_flit", row["energy_pj_per_delivered_flit"], "pJ/flit", row)
        if row["energy_pj_per_useful_delivery"] != "":
            add(64, "network_power", str(row["paper_label"]), "result_id", row["result_id"],
                "energy_per_useful_delivery", row["energy_pj_per_useful_delivery"], "pJ/delivery", row)
    for row in area:
        add(64, "network_area", str(row["paper_label"]), "configuration", row["paper_label"],
            "area", row["area_um2"], "um^2", {"source_file": row["source_file"],
                                                "source_design": row["source_design"],
                                                "source_case": "", "source_run_id": row["netlist_run_id"]})
    for row in node_ppa:
        source = {"source_file": row["source_file"], "source_design": row["geometry"],
                  "source_case": "", "source_run_id": row["netlist_run_id"]}
        for metric, key, unit in (("area", "area_um2", "um^2"),
                                  ("head_hop_delay", "head_ns", "ns"),
                                  ("body_hop_delay", "body_ns", "ns"),
                                  ("tail_hop_delay", "tail_ns", "ns"),
                                  ("idle_power", "idle_power_w", "W"),
                                  ("active_power", "active_power_w", "W"),
                                  ("packet_energy", "packet_energy_j", "J")):
            add(1, "node_ppa", str(row["topology"]), "geometry", row["geometry"],
                metric, row[key], unit, source)
    return sorted(out, key=lambda r: (int(r["nodes"]), str(r["experiment"]), str(r["metric"]),
                                      str(r["paper_label"]), str(r["x_value"])))


def build_source_manifest(used: set[str]) -> list[dict[str, object]]:
    index = {row["bundle_path"]: row for row in read_csv("included_files.csv")}
    rows = []
    for rel in sorted(used):
        if rel.startswith("DATE_paper/") or rel.startswith("DATE paper/"):
            path = ROOT / rel
            is_exclusion = path == PFAT64_EXCLUDED
            rows.append({
                "source_file": rel, "row_count": len(read_path(path)), "sha256": sha256(path),
                "final_path": "", "final_sha256": "",
                "classification": ("supplemental failure/exclusion register" if is_exclusion
                                   else "locally verified supplemental MAXIMUM-SDF scan"),
                "acceptance_rule": ("excluded from publication curves" if is_exclusion else
                                    "TB_RESULT PASS; 55000/55000 full drain; no missing/unexpected/timeout; SDF Total errors: 0"),
                "upstream_source_path": rel,
            })
            continue
        path = SRC / rel
        source = index.get(rel, {})
        final_path = OUT / "data" / rel if rel.startswith("256/") else None
        rows.append({
            "source_file": rel, "row_count": len(read_csv(rel)), "sha256": sha256(path),
            "final_path": str(final_path.relative_to(OUT)).replace("\\", "/") if final_path else "",
            "final_sha256": sha256(final_path) if final_path and final_path.is_file() else "",
            "classification": source.get("classification", "validated audit input"),
            "acceptance_rule": source.get("acceptance_rule", "copied from validated bundle"),
            "upstream_source_path": source.get("source_path", ""),
        })
    return rows


def validate_publication_csvs(paths: list[Path]) -> None:
    forbidden_headers = ("p50", "p90", "p95", "p99", "max_latency", "cohort_max")
    for path in paths:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            bad = [name for name in (reader.fieldnames or []) if any(token in name.lower() for token in forbidden_headers)]
            if bad:
                raise RuntimeError(f"percentile/max latency leaked into publication CSV {path}: {bad}")
            for row in reader:
                if any("static" in str(value).lower() for value in row.values()):
                    raise RuntimeError(f"disallowed implementation series leaked into publication CSV {path}")


def write_readme(counts: dict[str, int], fig2: list[dict[str, object]],
                 fig3: list[dict[str, object]],
                 scan_throughput: list[dict[str, object]],
                 scan_latency: list[dict[str, object]],
                 mesh_latency_audit: list[dict[str, object]],
                 node_ppa: list[dict[str, object]]) -> None:
    mesh_ur_raw = [row for row in read_csv("64/01_ur/throughput_all_accepted.csv")
                   if row["design"] == "FM64"]
    node_table_lines = [
        "| Topology | Geometry | Area (µm²) | Head (ns) | Body (ns) | Tail (ns) | Idle (mW) | Active (mW) | Packet energy (pJ) |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in node_ppa:
        node_table_lines.append(
            f"| {row['topology']} | {row['geometry']} | {f(row['area_um2']):.0f} | "
            f"{f(row['head_ns']):.3f} | {f(row['body_ns']):.3f} | {f(row['tail_ns']):.3f} | "
            f"{f(row['idle_power_w']) * 1e3:.3f} | {f(row['active_power_w']) * 1e3:.3f} | "
            f"{f(row['packet_energy_j']) * 1e12:.2f} |"
        )
    node_table = "\n".join(node_table_lines)
    mesh_ur_throughput = [row for row in scan_throughput
                          if row["topology"] == "Mesh" and row["mode"] == "UR (Async)"]
    mesh_ur_latency = [row for row in scan_latency
                       if row["topology"] == "Mesh" and row["mode"] == "UR (Async)"]
    mesh_ur_highest_setpoint = max(mesh_ur_raw, key=lambda row: int(row["load_setpoint_mflit_per_port_s"]))
    mesh_latency_peak = max(mesh_ur_latency, key=lambda row: f(str(row["offered_mflit_s_per_port"])))
    text = f"""# Final 64/256-node results

This folder is the paper-facing result set derived from the frozen
`experiments/curated/validated_64_256_csv_20260918` baseline plus two compact,
locally verified supplemental tables: the repaired Mesh64 UR M100--M300 scan
and the missing PFAT64 BC/Hotspot10 scan. Loose raw logs and older figure
directories are not parsed by the final builder.

## Metric policy

- Unicast and locality latency: mean flit latency in ns.
- Multicast latency: mean transaction completion latency in ns.
- No percentile or maximum latency is exported to the publication tables.
- Throughput uses measured offered/delivered rates. For 256-node E1, offered
  rate is reconstructed as `(delivered_flits / delivery_ratio) * 1e6 /
  (measurement_window_ps * 256)`.
- Throughput includes all correctness/full-drain passes. Latency includes only
  paired, near-lossless, uncensored, paper-eligible points.

## Figures

- `fig01_64_throughput`: all eligible 64-node throughput scans on one measured-rate axis.
- `fig02_64_latency`: all paired, near-lossless 64-node mean-latency scans on one axis.
- `fig03_256_global_locality`: 256-node global UR throughput/latency and locality latency.
- `fig04_multicast`: 64-node fanout and F16 plus 256-node cross-tier F16.
- `fig05_network_power64`: grouped bars for accepted 64-node network power and energy.
- The two 64-node scans use color for topology (Mesh, PROP, FAT) and marker shape
  for mode (UR Async, UR Sync, BC, Hotspot10). The asynchronous UR series uses
  Dynamic lane selection.
- Router lane scaling has parent-lane count on its x-axis, while power/energy are
  single-load implementation measurements. They are shown in the power figure and
  retained with provenance in `data/power64_all_accepted.csv`.
- The multicast figure also includes M5 F16 energy per useful destination; it uses
  pJ/useful destination, separate from the unicast pJ/flit comparison.
- In the 256-node global UR latency panel, the M60 setpoint is omitted; its
  throughput observations remain in the throughput panel and source tables.
- `data/256/`: all 59 CSVs from the validated 256 evidence bundle, including accepted
  case results and audit data. The `data/fig*.csv` files are the compact plotting views.

Paper legends use only Mesh, PROP and FAT for topology comparisons. Internal
configuration names and run identifiers remain in CSV provenance columns.

## 64-node Mesh high-load coverage

- The Mesh UR throughput sweep contains {len(mesh_ur_throughput)} accepted points.
  At setpoint M{mesh_ur_highest_setpoint['load_setpoint_mflit_per_port_s']}, it measured
  {f(mesh_ur_highest_setpoint['offered_mflit_per_port_s']):.2f} Mflit/s/port offered,
  {f(mesh_ur_highest_setpoint['delivered_mflit_per_port_s']):.2f} delivered, and a backlog
  of {int(float(mesh_ur_highest_setpoint['backlog']))} flits.
- The Mesh UR latency curve contains {len(mesh_ur_latency)} paired near-lossless
  points and reaches {f(str(mesh_latency_peak['offered_mflit_s_per_port'])):.2f}
  Mflit/s/port offered. Higher-load runs remain represented in throughput data;
  saturated/censored points are excluded from the positive mean-latency curve.
- `data/mesh64_ur_latency_eligibility_audit.csv` retains all {len(mesh_latency_audit)}
  measured Mesh UR sweep rows, including observed per-flit means and censor flags.
  For example, M800 has an observed per-flit mean of
  {f(str(next(row['observed_flit_mean_latency_ns'] for row in mesh_latency_audit if row['load_setpoint_mflit_per_port_s'] == 800))):.2f} ns,
  but no complete cohort mean; it is marked right-censored and is not plotted as a
  positive latency comparison point.
- Mesh BC and Hotspot10 eligible latency scans reach {max(f(str(row['offered_mflit_s_per_port'])) for row in scan_latency if row['topology'] == 'Mesh' and row['mode'] == 'BC'):.2f}
  and {max(f(str(row['offered_mflit_s_per_port'])) for row in scan_latency if row['topology'] == 'Mesh' and row['mode'] == 'Hotspot10'):.2f}
  Mflit/s/port, respectively.

## Exclusions and limitations

- 64-node multicast M60 and 256-node cross-tier F16 M40 are censored stress points.
- PFAT64 Hotspot10 M420 failed correctness; M440--M800 were skipped after the
  fail-fast stop. These points are not connected to the accepted FAT curve.
- 256-node locality p=0.90 is excluded from the paired positive comparison because
  PROP is not near-lossless there.
- 256-node power is outside the experiment plan.
- Sync power is a post-synthesis, pre-CTS estimate and is not used for an
  unconditional Async/Sync implementation-efficiency claim.
- Area is retained in `data/area_summary.csv` but is not plotted.
- Existing frozen figures are superseded for presentation purposes, but are not deleted.

## 256-node result snapshot

- Global UR has 20 paired offered-load settings and 40 full-drain DUT results. The
  common near-lossless latency subset has 18 results. At setting M160, both designs
  measure {next(f(r['x_value']) for r in fig2 if r['section'] == 'global_ur' and r['paper_label'] == 'PROP' and r['load_m'] == 160):.2f}
  Mflit/s/port offered and {next(f(r['delivered_mflit_s_per_port']) for r in fig2 if r['section'] == 'global_ur' and r['paper_label'] == 'PROP' and r['load_m'] == 160):.2f} delivered; mean latency is
  {next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'global_ur' and r['paper_label'] == 'PROP' and r['load_m'] == 160):.2f} ns for PROP and {next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'global_ur' and r['paper_label'] == 'Mesh' and r['load_m'] == 160):.2f} ns for Mesh.
- Locality uses three paired eligible points at p=0.247, 0.50 and 0.75. By p=0.75,
  mean latency falls {((1-next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'locality' and r['paper_label'] == 'PROP' and abs(f(str(r['x_value']))-0.75)<1e-9)/next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'locality' and r['paper_label'] == 'PROP' and abs(f(str(r['x_value']))-(63/255))<1e-9))*100):.1f}% from the uniform-equivalent point for PROP and
  {((1-next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'locality' and r['paper_label'] == 'Mesh' and abs(f(str(r['x_value']))-0.75)<1e-9)/next(f(r['mean_latency_ns']) for r in fig2 if r['section'] == 'locality' and r['paper_label'] == 'Mesh' and abs(f(str(r['x_value']))-(63/255))<1e-9))*100):.1f}% for Mesh. The p=0.90 PROP point is excluded because its backlog is above the near-lossless limit.
- Cross-tier F16 uses adjacent 8+8 destinations. All four M5/M20 Native/Repeated cases
  pass the paper gate. Mean completion latency is {next(f(r['mean_completion_latency_ns']) for r in fig3 if r['section'] == 'f16_256_cross_tier' and r['paper_label'] == 'Native' and r['load_m'] == 5):.2f}/{next(f(r['mean_completion_latency_ns']) for r in fig3 if r['section'] == 'f16_256_cross_tier' and r['paper_label'] == 'Repeated' and r['load_m'] == 5):.2f} ns at M5 and
  {next(f(r['mean_completion_latency_ns']) for r in fig3 if r['section'] == 'f16_256_cross_tier' and r['paper_label'] == 'Native' and r['load_m'] == 20):.2f}/{next(f(r['mean_completion_latency_ns']) for r in fig3 if r['section'] == 'f16_256_cross_tier' and r['paper_label'] == 'Repeated' and r['load_m'] == 20):.2f} ns at M20 (Native/Repeated). M40 is retained only in the exclusion register.
- The detailed accepted-data copy contains {len(list((DATA / '256').rglob('*.csv')))} CSV files ({sum(p.stat().st_size for p in (DATA / '256').rglob('*.csv')) / (1024 * 1024):.1f} MiB) across global UR, locality, and cross-tier F16. It includes per-case simulator tables and counters; raw DC netlists and full simulator logs remain referenced by the upstream source paths in `source_manifest.csv`.

## Node-level (isolated router primitive) PPA

Per-router hop delay, DC cell area and power for the seven frozen async router
primitives from the paper hop-PPA campaign `20260912_205700_cmr_primitive_hop_ppa_rpsdel050`,
plus the c1p4 (fat_1x4, one child x four parent) primitive and its synchronous
counterpart from the separate `20260914_cmr_c1p4_async_sync_hop_ppa` bundle
(post-synthesis, MAXIMUM-SDF + time-based PT-PX, no place-and-route). The full
per-flit power/energy breakdown is retained in `data/node_ppa.csv`; the network-level
64-node area/power lives separately in `data/area_summary.csv` and
`data/power64_all_accepted.csv`.

{node_table}

- Geometry is child x parent tier ports; `max_opm_fanin` and per-flit head/body/tail
  power/energy are carried in `data/node_ppa.csv`.
- These are isolated-primitive measurements: they are not the 64/256-node
  network totals and should not be summed into network area/power directly.
- `sync_fat_1x4` is the synchronous counterpart of the c1p4 FAT primitive (1.0 ns
  clock); its head/body/tail latency is quantized to the clock period (1 cycle per
  hop), so it is not directly comparable to the async measured propagation delay.

## Accepted input counts

| Dataset | Rows |
| --- | ---: |
"""
    for name, value in counts.items():
        text += f"| `{name}` | {value} |\n"
    (OUT / "README.md").write_text(text, encoding="utf-8")


def main() -> int:
    if not SRC.is_dir():
        raise RuntimeError(f"validated input bundle is missing: {SRC}")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "FINAL_RESULTS_PASS").unlink(missing_ok=True)
    (OUT / "figure_manifest.json").unlink(missing_ok=True)
    counts = {rel: len(read_csv(rel)) for rel in EXPECTED_COUNTS}
    mismatches = {rel: (counts[rel], expected) for rel, expected in EXPECTED_COUNTS.items()
                  if counts[rel] != expected}
    if mismatches:
        raise RuntimeError(f"validated input count mismatch: {mismatches}")

    # Carry the complete validated 256 CSV evidence subtree into the final
    # folder. This is the same accepted-data view used to curate the 64-node
    # results; raw source archives remain the upstream provenance.
    archive_src = SRC / "256"
    archive_dst = DATA / "256"
    archived_256_files: list[Path] = []
    for source_path in sorted(archive_src.rglob("*.csv")):
        relative = source_path.relative_to(SRC)
        destination = DATA / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, destination)
        if sha256(source_path) != sha256(destination):
            raise RuntimeError(f"256 archive copy hash mismatch: {relative}")
        archived_256_files.append(destination)
    if len(archived_256_files) != 59:
        raise RuntimeError(f"expected 59 validated 256 CSV files, found {len(archived_256_files)}")

    fig1 = build_unicast64()
    fig2 = build_unicast256()
    fig3 = build_multicast()
    fig4 = build_implementation64()
    power = build_power64()
    area = build_area()
    node_ppa = build_node_ppa()
    fields1 = ["nodes", "traffic", "paper_label", "load_m", "offered_mflit_s_per_port",
               "delivered_mflit_s_per_port", "mean_latency_ns", "latency_eligible",
               "source_file", "source_design", "source_case", "source_run_id",
               "latency_source_file", "latency_source_design", "latency_source_case",
               "latency_source_run_id"]
    fields2 = ["nodes", "section", "paper_label", "x_name", "x_value", "load_m",
               "delivered_mflit_s_per_port", "mean_latency_ns", "latency_eligible", "derivation",
               "source_file", "source_design", "source_case", "source_run_id"]
    fields3 = ["nodes", "section", "paper_label", "fanout", "load_m",
               "mean_completion_latency_ns", "useful_delivery_rate_mdelivery_s",
               "source_file", "source_design", "source_case", "source_run_id"]
    fields4 = ["section", "paper_label", "x_value", "x_unit", "metric", "value",
               "physical_class", "source_file", "source_design", "source_case", "source_run_id"]
    power_fields = ["paper_label", "result_id", "total_power_w", "energy_pj_per_delivered_flit",
                    "energy_pj_per_useful_delivery", "physical_class", "source_file", "source_design",
                    "source_case", "source_run_id"]
    area_fields = ["paper_label", "source_design", "area_um2", "netlist_run_id", "evidence_scope",
                   "caveat", "source_file"]
    node_fields = ["topology", "geometry", "child_ports", "parent_ports", "max_opm_fanin",
                   "area_um2", "head_ns", "body_ns", "tail_ns",
                   "head_power_w", "body_power_w", "tail_power_w", "packet_power_w",
                   "head_energy_j", "body_energy_j", "tail_energy_j", "packet_energy_j",
                   "idle_power_w", "active_power_w", "physical_class", "caveat",
                   "netlist_run_id", "source_file"]
    long_fields = ["nodes", "experiment", "paper_label", "mode", "x_name", "x_value", "metric", "value",
                   "unit", "eligibility", "source_file", "source_design", "source_case", "source_run_id"]

    scan_throughput = build_shared_scan64(fig1, "delivered_throughput")
    scan_latency = build_shared_scan64(fig1, "mean_flit_latency")
    mesh_latency_audit = build_mesh64_latency_audit()
    expected_scan_counts = {"delivered_throughput": 292, "mean_flit_latency": 143}
    actual_scan_counts = {"delivered_throughput": len(scan_throughput), "mean_flit_latency": len(scan_latency)}
    if actual_scan_counts != expected_scan_counts:
        raise RuntimeError(f"shared 64-node scan count mismatch: {actual_scan_counts}")
    final_long = long_rows(scan_throughput, scan_latency, fig2, fig3, fig4, power, area, node_ppa)

    shared_fields = ["nodes", "topology", "mode", "traffic", "offered_mflit_s_per_port",
                     "metric", "value", "value_unit", "eligibility", "source_file",
                     "source_design", "source_case", "source_run_id"]
    outputs = [
        (DATA / "fig01_unicast64.csv", fields1, fig1),
        (DATA / "fig01_64_throughput.csv", shared_fields, scan_throughput),
        (DATA / "fig02_64_latency.csv", shared_fields, scan_latency),
        (DATA / "mesh64_ur_latency_eligibility_audit.csv",
         ["load_setpoint_mflit_per_port_s", "offered_mflit_per_port_s",
          "delivered_mflit_per_port_s", "backlog_flits", "observed_flit_mean_latency_ns",
          "cohort_mean_latency_ns", "cohort_latency_status", "near_lossless",
          "paper_latency_eligible", "source_file", "source_design", "source_case", "source_run_id"],
         mesh_latency_audit),
        (DATA / "fig02_unicast256.csv", fields2, fig2),
        (DATA / "fig03_multicast.csv", fields3, fig3),
        (DATA / "fig04_implementation64.csv", fields4, fig4),
        (DATA / "power64_all_accepted.csv", power_fields, power),
        (DATA / "area_summary.csv", area_fields, area),
        (DATA / "node_ppa.csv", node_fields, node_ppa),
        (DATA / "final_results_long.csv", long_fields, final_long),
    ]
    for path, fields, rows in outputs:
        write_csv(path, fields, rows)

    excluded = [row for row in read_csv("excluded_cases.csv")
                if row["design"] != "PROP_temp64_static4" and row["experiment"] != "static4"]
    for row in read_path(PFAT64_EXCLUDED):
        excluded.append({
            "nodes": 64, "experiment": "Hotspot10", "case": row["case_name"],
            "design": "PFAT64", "load": row["load_m"], "reason": row["reason"],
            "source_path": root_rel(PFAT64_EXCLUDED),
        })
    write_csv(OUT / "excluded_results.csv",
              ["nodes", "experiment", "case", "design", "load", "reason", "source_path"], excluded)

    used = {str(row["source_file"]) for row in final_long}
    used.update(str(path.relative_to(SRC)).replace("\\", "/") for path in sorted(archive_src.rglob("*.csv")))
    used.add("excluded_cases.csv")
    used.add(root_rel(PFAT64_EXCLUDED))
    used.discard(f"{NODE_PPA_REL}/metrics.csv")  # node PPA provenance handled separately below
    used.discard(f"{C1P4_PPA_REL}/metrics.csv")
    source_manifest = build_source_manifest(used)
    paper_node_count = sum(1 for r in node_ppa if r["source_file"] == f"{NODE_PPA_REL}/metrics.csv")
    c1p4_node_count = sum(1 for r in node_ppa if r["source_file"] == f"{C1P4_PPA_REL}/metrics.csv")
    source_manifest.append({
        "source_file": f"{NODE_PPA_REL}/metrics.csv",
        "row_count": paper_node_count,
        "sha256": sha256(NODE_PPA_METRICS),
        "final_path": "data/node_ppa.csv",
        "final_sha256": sha256(DATA / "node_ppa.csv"),
        "classification": "node-level hop PPA (isolated router primitive)",
        "acceptance_rule": "MAXIMUM-SDF GLS + time-based PT-PX; DC cell area; no P&R",
        "upstream_source_path": f"{NODE_PPA_REL}/metrics.csv",
    })
    source_manifest.append({
        "source_file": f"{C1P4_PPA_REL}/metrics.csv",
        "row_count": c1p4_node_count,
        "sha256": sha256(C1P4_PPA_METRICS),
        "final_path": "data/node_ppa.csv",
        "final_sha256": sha256(DATA / "node_ppa.csv"),
        "classification": "node-level hop PPA (c1p4 isolated router primitive, async + sync)",
        "acceptance_rule": "MAXIMUM-SDF GLS + time-based PT-PX; DC cell area; no P&R; sync latency quantized to 1.0 ns clock",
        "upstream_source_path": f"{C1P4_PPA_REL}/metrics.csv",
    })
    write_csv(OUT / "source_manifest.csv",
              ["source_file", "row_count", "sha256", "final_path", "final_sha256",
               "classification", "acceptance_rule", "upstream_source_path"], source_manifest)
    write_readme(counts, fig2, fig3, scan_throughput, scan_latency, mesh_latency_audit, node_ppa)
    validate_publication_csvs([path for path, _, _ in outputs])

    # Explicit claim-boundary checks.
    if any(r["section"] == "locality" and abs(f(str(r["x_value"])) - 0.9) < 1e-12 for r in fig2):
        raise RuntimeError("ineligible locality p=0.90 leaked into final data")
    if any((r["nodes"] == 64 and r["load_m"] == 60) or (r["nodes"] == 256 and r["load_m"] == 40)
           for r in fig3):
        raise RuntimeError("censored multicast stress point leaked into final data")

    manifest_files = [path for path, _, _ in outputs] + archived_256_files + [OUT / "README.md",
                                                                              OUT / "excluded_results.csv",
                                                                              OUT / "source_manifest.csv"]
    manifest = {
        "input_bundle": str(SRC.relative_to(ROOT)).replace("\\", "/"),
        "input_counts": counts,
        "archived_256_csv_count": len(archived_256_files),
        "archived_256_bytes": sum(path.stat().st_size for path in archived_256_files),
        "shared_64_scan_counts": actual_scan_counts,
        "output_sha256": {str(path.relative_to(OUT)).replace("\\", "/"): sha256(path)
                          for path in sorted(manifest_files)},
        "status": "FINAL_RESULTS_DATA_PASS",
    }
    (OUT / "data_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "output": str(OUT),
                      "long_rows": len(final_long), "source_files": len(source_manifest)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

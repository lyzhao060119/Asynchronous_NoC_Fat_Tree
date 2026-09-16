#!/usr/bin/env python3
"""Strictly collect and plot a completed DATE 2027 E2 frozen-netlist run.

The collector is fail-closed: it writes no paper-facing output until all 120
canonical points pass full-drain, MAXIMUM-SDF, trace-pairing, and CSV gates.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from run_e2_bc_hotspot64 import (  # noqa: E402
    BENCHMARKS,
    FROZEN,
    LOADS,
    case_name,
    remote_root,
)
import run_remote_prop_temp64 as prop_remote  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import connect  # noqa: E402

DESIGNS = ("PROP_temp64", "FM64")
EXPECTED_FLITS = 55_000
EXPECTED_MEASUREMENT_FLITS = 50_000
FORBIDDEN = re.compile(
    r"TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|"
    r"TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation",
    re.IGNORECASE,
)
STYLE = {
    "PROP_temp64": {"label": "PROP_temp64", "color": "#d62728", "marker": "s"},
    "FM64": {"label": "FlatMesh64", "color": "#1f77b4", "marker": "o"},
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_remote(sftp, path: str) -> bytes:
    with sftp.file(path, "rb") as stream:
        data = stream.read()
    if not data:
        raise RuntimeError(f"empty remote artifact: {path}")
    return data


def one_csv_row(data: bytes, path: str) -> dict[str, str]:
    rows = list(csv.DictReader(io.StringIO(data.decode("utf-8"))))
    if len(rows) != 1:
        raise RuntimeError(f"{path}: expected one CSV row, got {len(rows)}")
    return rows[0]


def accepted_case_names(state: dict) -> dict[tuple[str, str], str]:
    result = {}
    for row in state.get("run_jobs", []):
        result[(row["benchmark"], row["design"])] = row["case"]
    if len(result) != 4:
        raise RuntimeError("state.json does not identify four accepted M5 smoke cases")
    return result


def git_evidence() -> tuple[str, list[str]]:
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=REPO, text=True
    ).strip()
    dirty = subprocess.check_output(
        ["git", "status", "--short"], cwd=REPO, text=True, errors="replace"
    ).splitlines()
    return commit, dirty


def collect(client, run_id: str) -> tuple[list[dict], dict, dict[str, bytes]]:
    root = remote_root(run_id)
    state_path = HERE / "results" / run_id / "state.json"
    state = json.loads(state_path.read_text(encoding="utf-8"))
    accepted_m5 = accepted_case_names(state)
    sftp = client.open_sftp()
    artifacts: dict[str, bytes] = {}
    shared_sdf_hashes = {}
    try:
        input_manifest_data = read_remote(sftp, f"{root}/e2_input_manifest.json")
        input_manifest = json.loads(input_manifest_data)
        artifacts["e2_input_manifest.json"] = input_manifest_data
        if len(input_manifest) != 120:
            raise RuntimeError(f"input manifest cardinality {len(input_manifest)} != 120")
        by_key = {
            (row["benchmark"], int(row["load"]), row["design"]): row
            for row in input_manifest
        }
        if len(by_key) != 120:
            raise RuntimeError("input manifest has duplicate/missing benchmark-load-design keys")

        for design in DESIGNS:
            sdf_path = f"{root}/work/{design}/sdf_annotate.log"
            sdf = read_remote(sftp, sdf_path)
            if not re.search(rb"Total errors:\s*0", sdf):
                raise RuntimeError(f"{design}: shared MAXIMUM-SDF report is not clean")
            shared_sdf_hashes[design] = sha256_bytes(sdf)
            artifacts[f"shared_sdf/{design}_sdf_annotate.log"] = sdf
            artifacts[f"compile/{design}_input_hashes.log"] = read_remote(
                sftp, f"{root}/work/{design}/input_hashes.log"
            )

        rows_out = []
        for benchmark in BENCHMARKS:
            for load in LOADS:
                pair_hashes = set()
                for design in DESIGNS:
                    key = (benchmark, load, design)
                    source = by_key.get(key)
                    if source is None:
                        raise RuntimeError(f"missing input manifest point {key}")
                    pair_hashes.add(source["trace_sha256"])
                    result_case = (
                        accepted_m5[(benchmark, design)]
                        if load == 5
                        else case_name(benchmark, design, load)
                    )
                    base = f"{root}/logs/{design}/{result_case}"
                    csv_path = f"{root}/results/{design}/{result_case}.csv"
                    csv_data = read_remote(sftp, csv_path)
                    run_data = read_remote(sftp, f"{base}/run.log")
                    stage_data = read_remote(sftp, f"{base}/stage.log")
                    hashes_data = read_remote(sftp, f"{base}/input_hashes.log")
                    sdf_ref = read_remote(sftp, f"{base}/sdf_reference.sha256")
                    if not sdf_ref.decode("utf-8", errors="replace").strip().startswith(shared_sdf_hashes[design]):
                        raise RuntimeError(f"{result_case}: shared SDF report SHA-256 reference mismatch")
                    row = one_csv_row(csv_data, csv_path)
                    run_text = run_data.decode("utf-8", errors="replace")
                    stage_text = stage_data.decode("utf-8", errors="replace")
                    required = {
                        "pass_fail": "PASS",
                        "injected_flits": str(EXPECTED_FLITS),
                        "delivered_flits": str(EXPECTED_FLITS),
                        "missing_expected_flits": "0",
                        "unexpected_flits": "0",
                        "timeout_hit": "0",
                        "warmup_original_events": "1000",
                        "measurement_original_events": "10000",
                    }
                    bad = {name: row.get(name) for name, value in required.items() if row.get(name) != value}
                    if bad:
                        raise RuntimeError(f"{result_case}: CSV acceptance failed {bad}")
                    if "Doing SDF annotation ...... Done" not in run_text:
                        raise RuntimeError(f"{result_case}: per-run SDF annotation marker missing")
                    if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in run_text:
                        raise RuntimeError(f"{result_case}: exact full-drain marker missing")
                    if f"E2_CASE_PASS design={design}" not in stage_text or FORBIDDEN.search(run_text):
                        raise RuntimeError(f"{result_case}: stage/error gate failed")

                    offered_measurement = int(row["measurement_offered_flits"])
                    delivered_measurement = int(row["measurement_delivered_flits"])
                    backlog = int(float(row["measurement_backlog_flits"]))
                    if offered_measurement != EXPECTED_MEASUREMENT_FLITS or offered_measurement <= 0:
                        raise RuntimeError(f"{result_case}: invalid measurement denominator")
                    delivery_ratio = delivered_measurement / offered_measurement
                    near_lossless = delivery_ratio >= 0.99 and backlog <= 5
                    out = {
                        "design": design,
                        "benchmark": benchmark,
                        "load_setpoint_mflit_per_port_s": load,
                        "result_case": result_case,
                        "canonical_case": source["case"],
                        "netlist_run_id": FROZEN[design][0],
                        "trace_sha256": source["trace_sha256"],
                        "trace_header_hash": source["trace_header_hash"],
                        "case_sha256": source["case_sha256"],
                        "result_csv_sha256": sha256_bytes(csv_data),
                        "run_log_sha256": sha256_bytes(run_data),
                        "sdf_reference": sdf_ref.decode("utf-8", errors="replace").strip(),
                        "measurement_start_ps": int(row["measurement_start_ps"]),
                        "measurement_end_ps": int(row["measurement_end_ps"]),
                        "measurement_offered_flits": offered_measurement,
                        "measurement_delivered_flits": delivered_measurement,
                        "measurement_delivery_ratio": f"{delivery_ratio:.9f}",
                        "measurement_backlog_flits": backlog,
                        "offered_mflit_per_port_s": row["offered_mflit_port_s"],
                        "delivered_mflit_per_port_s": row["delivered_mflit_port_s"],
                        "flit_latency_mean_ns": row["flit_lat_mean_ns"],
                        "flit_latency_p95_ns": row["flit_lat_p95_ns"],
                        "flit_latency_p99_ns": row["flit_lat_p99_ns"],
                        "full_drain_pass": True,
                        "sdf_pass": True,
                        "trace_pair_pass": True,
                        "near_lossless": near_lossless,
                        "latency_claim_eligible": near_lossless,
                        "pass_fail": "PASS",
                    }
                    rows_out.append(out)
                    prefix = f"cases/{benchmark}/m{load}/{design}"
                    artifacts[f"{prefix}/result.csv"] = csv_data
                    artifacts[f"{prefix}/run.log"] = run_data
                    artifacts[f"{prefix}/stage.log"] = stage_data
                    artifacts[f"{prefix}/input_hashes.log"] = hashes_data
                    artifacts[f"{prefix}/sdf_reference.sha256"] = sdf_ref
                if len(pair_hashes) != 1:
                    raise RuntimeError(f"trace pairing failed for {benchmark} M{load}")
        return rows_out, state, artifacts
    finally:
        sftp.close()


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def saturation_rows(rows: list[dict]) -> list[dict]:
    output = []
    for benchmark in BENCHMARKS:
        for design in DESIGNS:
            selected = [r for r in rows if r["benchmark"] == benchmark and r["design"] == design]
            peak = max(selected, key=lambda r: float(r["delivered_mflit_per_port_s"]))
            eligible = [r for r in selected if r["near_lossless"]]
            near = max(eligible, key=lambda r: int(r["load_setpoint_mflit_per_port_s"])) if eligible else None
            output.append({
                "benchmark": benchmark,
                "design": design,
                "peak_load_setpoint": peak["load_setpoint_mflit_per_port_s"],
                "peak_delivered_mflit_per_port_s": peak["delivered_mflit_per_port_s"],
                "near_lossless_load_setpoint": near["load_setpoint_mflit_per_port_s"] if near else "",
                "near_lossless_delivered_mflit_per_port_s": near["delivered_mflit_per_port_s"] if near else "",
                "near_lossless_criterion": "delivery_ratio>=0.99 and backlog<=5",
            })
    return output


def download_raw(client, run_id: str, rows: list[dict], stage: Path) -> dict[str, str]:
    """Copy accepted raw evidence only, with independent remote/local SHA-256."""
    root = remote_root(run_id)
    wanted: dict[str, str] = {}
    for row in rows:
        design, name = row["design"], row["result_case"]
        base = f"logs/{design}/{name}"
        for suffix in ("events.csv", "latency.csv", "flit_latency.csv", "v3_metrics.csv"):
            wanted[f"{base}/{suffix}"] = f"raw/{base}/{suffix}"
        canonical = row["canonical_case"]
        if not re.fullmatch(r"[A-Za-z0-9_.-]+\.case", canonical):
            raise RuntimeError(f"unsafe canonical case name: {canonical}")
        wanted[f"cases/{canonical}"] = f"raw/inputs/cases/{canonical}"
        trace = f"{row['benchmark']}_n64_s202701_m{row['load_setpoint_mflit_per_port_s']}.jsonl"
        wanted[f"traces/{trace}"] = f"raw/inputs/traces/{trace}"
    expected = {}
    paths = sorted(wanted)
    for start in range(0, len(paths), 24):
        batch = paths[start:start + 24]
        command = "sha256sum " + " ".join(shlex.quote(f"{root}/{p}") for p in batch)
        _, stdout, stderr = client.exec_command(command, timeout=180)
        output = stdout.read().decode("utf-8", errors="replace")
        error = stderr.read().decode("utf-8", errors="replace")
        rc = stdout.channel.recv_exit_status()
        if rc:
            raise RuntimeError(f"remote SHA-256 failed rc={rc}: {error}")
        for line in output.splitlines():
            digest, absolute = line.split(None, 1)
            rel = absolute.lstrip(" *")[len(root) + 1:]
            if rel not in wanted or not re.fullmatch(r"[0-9a-f]{64}", digest):
                raise RuntimeError(f"unexpected remote SHA-256 record: {line}")
            expected[rel] = digest
    if set(expected) != set(wanted):
        raise RuntimeError("remote SHA-256 inventory is incomplete")
    sftp = client.open_sftp()
    try:
        for index, rel in enumerate(paths, 1):
            local = stage / wanted[rel]
            local.parent.mkdir(parents=True, exist_ok=True)
            sftp.get(f"{root}/{rel}", str(local))
            if local.stat().st_size == 0:
                raise RuntimeError(f"empty downloaded raw artifact: {rel}")
            digest = hashlib.sha256()
            with local.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            actual = digest.hexdigest()
            if actual != expected[rel]:
                raise RuntimeError(f"remote/local SHA-256 mismatch: {rel}")
            if index % 100 == 0 or index == len(paths):
                print(f"E3_RAW_SHA_PASS {index}/{len(paths)}", flush=True)
    finally:
        sftp.close()
    for row in rows:
        canonical = f"cases/{row['canonical_case']}"
        trace = f"traces/{row['benchmark']}_n64_s202701_m{row['load_setpoint_mflit_per_port_s']}.jsonl"
        if expected[canonical] != row["case_sha256"] or expected[trace] != row["trace_sha256"]:
            raise RuntimeError(f"canonical input manifest SHA-256 mismatch: {canonical}")
    return {wanted[rel]: expected[rel] for rel in paths}


def write_compact_index(stage: Path, rows: list[dict]) -> None:
    """Keep legacy evidence immutable; classify each supported claim here."""
    index = []
    for row in rows:
        source = stage / "cases" / row["benchmark"] / f"m{row['load_setpoint_mflit_per_port_s']}" / row["design"] / "result.csv"
        index.append({
            "experiment": "E3", "claim": "paired BC/Hotspot throughput and pre-saturation latency",
            "run_id": "20260914_231005_date2027_e2_bc_hotspot64",
            "source": str(source.relative_to(stage)).replace("\\", "/"),
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "evidence_level": "post-synthesis MAXIMUM-SDF GLS",
            "status": "accepted_two_dut" if row["latency_claim_eligible"] else "throughput_only_saturated",
            "reason": "PFAT64 remains missing; latency gated by delivery ratio and backlog",
        })
    local_sources = (
        ("E1", "PROP_temp64 vs FlatMesh64 UR, 30-point partial three-DUT comparison", "DATE paper/experiments/figures/paper64/20260914_092324_asap_uc_m5_800_mesh64_prop_temp64/aggregated_metrics.csv", "partial", "PFAT64 full grid and common trace audit missing"),
        ("E1", "PFAT64 vs FlatMesh64 UR, 12-point historical", "DATE paper/experiments/figures/paper64/20260913_asap_uc_m5_200_mesh64_pfat64/aggregated_metrics.csv", "exploratory", "not yet unified with 30-point trace/window audit"),
        ("E4", "F16 M5 native full-drain completion latency", "DATE paper/experiments/raw/prop_temp64/20260914_prop_temp64_mc_emergency/multicast_main_native.csv", "accepted_completion_only", "400/400; no clean energy measurement"),
        ("E4", "F16 M5 repeated-unicast full-drain completion latency", "DATE paper/experiments/raw/prop_temp64/20260914_prop_temp64_mc_emergency/multicast_main_source_repeated_unicast.csv", "accepted_completion_only", "400/400; no clean energy measurement"),
        ("E5", "fanout F2/4/8/16/32 exploratory sweep", "DATE paper/experiments/raw/prop_temp64/20260914_prop_temp64_mc_emergency/multicast_fanout_evidence.csv", "exploratory", "399/400 and backlog=1; fails full-drain gate"),
        ("E6", "Router Async/Sync c1p4 power", "DATE paper/experiments/raw/prop_temp64/20260914_prop_temp64_mc_emergency/router_summary.csv", "blocked_power", "PT-063; no clean PT-PX acceptance"),
        ("E6", "Router aggregate MAXIMUM-SDF lane scaling", "scripts/asic_dc/cmr/results/20260914_cmr_multi_lane_agg_r1/summary.json", "accepted_aggregate_only", "separate from single-lane body service rate"),
    )
    for experiment, claim, relative, status, reason in local_sources:
        source = REPO / relative
        if not source.is_file() or source.stat().st_size == 0:
            raise RuntimeError(f"missing local evidence: {source}")
        copy = stage / "references" / experiment / source.name
        copy.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, copy)
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        if hashlib.sha256(copy.read_bytes()).hexdigest() != digest:
            raise RuntimeError(f"local reference copy SHA-256 mismatch: {relative}")
        index.append({
            "experiment": experiment, "claim": claim, "run_id": source.parent.name,
            "source": relative, "sha256": digest,
            "evidence_level": "mixed historical evidence; see claim", "status": status,
            "reason": reason,
        })
    write_csv(stage / "evidence_index.csv", index)


def plot_benchmark(rows: list[dict], benchmark: str, out_dir: Path, *, separate_only: bool = False) -> list[str]:
    fig, (ax_tp, ax_lat) = plt.subplots(1, 2, figsize=(8.6, 3.4), constrained_layout=True)
    xmax = max(float(r["offered_mflit_per_port_s"]) for r in rows if r["benchmark"] == benchmark)
    ax_tp.plot([0, xmax * 1.04], [0, xmax * 1.04], "--", color="#888888", lw=1, label="Ideal")
    for design in DESIGNS:
        st = STYLE[design]
        selected = sorted(
            (r for r in rows if r["benchmark"] == benchmark and r["design"] == design),
            key=lambda r: float(r["offered_mflit_per_port_s"]),
        )
        ax_tp.plot(
            [float(r["offered_mflit_per_port_s"]) for r in selected],
            [float(r["delivered_mflit_per_port_s"]) for r in selected],
            color=st["color"], marker=st["marker"], ms=4, lw=1.3, label=st["label"],
        )
        eligible = [r for r in selected if r["latency_claim_eligible"]]
        x = [float(r["offered_mflit_per_port_s"]) for r in eligible]
        ax_lat.plot(x, [float(r["flit_latency_mean_ns"]) for r in eligible], color=st["color"], marker=st["marker"], ms=4, lw=1.4, label=st["label"] + " mean")
        ax_lat.plot(x, [float(r["flit_latency_p95_ns"]) for r in eligible], color=st["color"], ls="--", lw=1.0, alpha=.8, label=st["label"] + " p95")
        ax_lat.plot(x, [float(r["flit_latency_p99_ns"]) for r in eligible], color=st["color"], ls=":", lw=1.0, alpha=.8, label=st["label"] + " p99")
    ax_tp.set(xlabel="Offered load (Mflit/s/port)", ylabel="Delivered throughput (Mflit/s/port)", title=benchmark)
    ax_lat.set(xlabel="Offered load (Mflit/s/port)", ylabel="Flit latency (ns)", title="Pre-saturation only")
    ax_tp.grid(True, ls=":", alpha=.6); ax_lat.grid(True, ls=":", alpha=.6)
    ax_tp.legend(fontsize=8); ax_lat.legend(fontsize=7, ncol=2)
    stem = "bc" if benchmark == "TOPO-BC" else "hotspot10"
    names = []
    if not separate_only:
        names = [f"{stem}-throughput-pre-saturation-latency.png", f"{stem}-throughput-pre-saturation-latency.pdf"]
        fig.savefig(out_dir / names[0], dpi=300, bbox_inches="tight")
        fig.savefig(out_dir / names[1], bbox_inches="tight")
    for source_ax, suffix, title in (
        (ax_tp, "throughput-load", benchmark),
        (ax_lat, "pre-saturation-latency-load", "Pre-saturation only"),
    ):
        single_fig, single_ax = plt.subplots(figsize=(4.6, 3.4), constrained_layout=True)
        for line in source_ax.get_lines():
            single_ax.plot(
                line.get_xdata(), line.get_ydata(),
                color=line.get_color(), marker=line.get_marker(),
                markersize=line.get_markersize(), linewidth=line.get_linewidth(),
                linestyle=line.get_linestyle(), alpha=line.get_alpha(),
                label=line.get_label(),
            )
        single_ax.set(xlabel=source_ax.get_xlabel(), ylabel=source_ax.get_ylabel(), title=title)
        single_ax.grid(True, ls=":", alpha=.6)
        single_ax.legend(fontsize=7, ncol=2 if source_ax is ax_lat else 1)
        for extension in ("png", "pdf"):
            filename = f"{stem}-{suffix}.{extension}"
            single_fig.savefig(out_dir / filename, dpi=300, bbox_inches="tight")
            names.append(filename)
        plt.close(single_fig)
    plt.close(fig)
    return names


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--host", default=os.environ.get("E2_LOGIN_HOST", "192.168.2.9"))
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--compact64", action="store_true", help="publish a unified compact64 archive with full raw evidence")
    args = parser.parse_args()
    os.environ["C1_HOST"] = args.host
    prop_remote.LOGIN_HOSTS = (args.host,)
    client = connect(attempts=2)
    try:
        rows, state, artifacts = collect(client, args.run_id)
        print(f"E2_ACCEPTANCE_PASS rows={len(rows)} paired_points={len(rows)//2}", flush=True)
        if args.check_only:
            return 0
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        label = f"compact64_{stamp}" if args.compact64 else f"e2_bc_hotspot64_{stamp}"
        parent = REPO / "DATE paper" / "experiments" / "raw" / "paper64"
        raw_root = parent / label
        stage = parent / (label + ".staging")
        if raw_root.exists() or stage.exists():
            raise RuntimeError(f"refusing to overwrite {raw_root} or {stage}")
        stage.mkdir(parents=True)
        raw_hashes = download_raw(client, args.run_id, rows, stage) if args.compact64 else {}
    finally:
        client.close()
    for rel, data in artifacts.items():
        path = stage / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    if args.compact64:
        write_compact_index(stage, rows)
    write_csv(stage / "summary.csv", rows)
    write_csv(stage / "acceptance.csv", rows)
    sat = saturation_rows(rows)
    write_csv(stage / "saturation_summary.csv", sat)
    commit, dirty_lines = git_evidence()
    (stage / "git_status_short.txt").write_text("\n".join(dirty_lines) + "\n", encoding="utf-8")
    figure_outputs = {}
    for benchmark, dirname in (("TOPO-BC", f"benchmark_bc_{stamp}"), ("HOTSPOT10", f"benchmark_hotspot10_{stamp}")):
        figure_dir = stage / "figures" / dirname
        figure_dir.mkdir(parents=True, exist_ok=False)
        subset = [r for r in rows if r["benchmark"] == benchmark]
        write_csv(figure_dir / "summary.csv", subset)
        figure_outputs[benchmark] = plot_benchmark(rows, benchmark, figure_dir)
    manifest = {
        "schema": "date2027-e2-bc-hotspot64-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "run_id": args.run_id,
        "remote_root": remote_root(args.run_id),
        "commit": commit,
        "dirty": bool(dirty_lines),
        "dirty_status_file": "git_status_short.txt",
        "frozen_netlists": FROZEN,
        "loads": list(LOADS),
        "benchmarks": list(BENCHMARKS),
        "rows": len(rows),
        "paired_points": len(rows) // 2,
        "all_acceptance_pass": True,
        "figure_outputs": figure_outputs,
        "state": state,
        "raw_file_sha256": raw_hashes,
        "raw_files": len(raw_hashes),
        "command": "python scripts/asic_dc/cmr/collect_e2_bc_hotspot64.py --run-id " + args.run_id + (" --compact64" if args.compact64 else ""),
    }
    (stage / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    result_lines = [
        "# DATE 2027 E2 results",
        "",
        f"Run: `{args.run_id}`",
        "",
        "Evidence status: post-synthesis MAXIMUM-SDF GLS estimates; not post-layout or silicon measurements.",
        "",
        "All 120 cases passed exact full-drain, SDF annotation, nonzero artifact, and paired-trace gates.",
        "Latency plots include only points with delivery ratio >=99% and measurement backlog <=5 flits.",
        "",
        "## Saturation summary",
        "",
        "| Benchmark | Design | Peak delivered | Highest near-lossless point |",
        "|---|---|---:|---:|",
    ]
    for row in sat:
        result_lines.append(f"| {row['benchmark']} | {row['design']} | {row['peak_delivered_mflit_per_port_s']} | M{row['near_lossless_load_setpoint']} ({row['near_lossless_delivered_mflit_per_port_s']}) |")
    (stage / "RESULTS.md").write_text("\n".join(result_lines) + "\n", encoding="utf-8")
    hash_lines = []
    for path in sorted(stage.rglob("*")):
        if not path.is_file():
            continue
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        hash_lines.append(f"{digest.hexdigest()}  {path.relative_to(stage).as_posix()}")
    (stage / "hashes.sha256").write_text("\n".join(hash_lines) + "\n", encoding="utf-8")
    stage.rename(raw_root)
    for dirname in (f"benchmark_bc_{stamp}", f"benchmark_hotspot10_{stamp}"):
        target = REPO / "DATE paper" / "experiments" / "figures" / "paper64" / dirname
        shutil.copytree(raw_root / "figures" / dirname, target)
    print(f"E2_ARCHIVE_PASS {raw_root}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

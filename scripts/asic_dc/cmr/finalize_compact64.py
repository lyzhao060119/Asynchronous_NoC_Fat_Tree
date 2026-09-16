#!/usr/bin/env python3
"""Audit a newly published compact64 archive and add the Fig. B data source.

This is read-only with respect to historical and remote runs. It writes only
derived files inside the explicitly named compact64 archive.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_rows(path: Path, data: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(data[0]))
        writer.writeheader()
        writer.writerows(data)


def verify_case_metrics(raw: dict[str, str], name: str) -> None:
    required = {
        "pass_fail": "PASS", "injected_flits": "55000", "delivered_flits": "55000",
        "missing_expected_flits": "0", "unexpected_flits": "0", "timeout_hit": "0",
        "warmup_original_events": "1000", "measurement_original_events": "10000",
        "measurement_offered_flits": "50000",
    }
    bad = {key: raw.get(key) for key, value in required.items() if raw.get(key) != value}
    if bad:
        raise ValueError(f"{name}: full-drain/denominator gate failed: {bad}")
    offered = int(raw["measurement_offered_flits"])
    delivered = int(raw["measurement_delivered_flits"])
    backlog = int(float(raw["measurement_backlog_flits"]))
    if delivered < 0 or delivered > offered or backlog < 0 or offered <= 0:
        raise ValueError(f"{name}: invalid measurement counters")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    parent = REPO / "DATE paper" / "experiments" / "raw" / "paper64"
    if archive.parent != parent.resolve() or not archive.name.startswith("compact64_"):
        raise SystemExit("archive must be an explicit compact64 directory inside paper64")
    manifest = json.loads((archive / "manifest.json").read_text(encoding="utf-8"))
    summary = rows(archive / "summary.csv")
    if len(summary) != 120 or manifest.get("rows") != 120 or manifest.get("paired_points") != 60:
        raise SystemExit("E3 120-case/60-pair cardinality gate failed")
    by_point = {}
    for row in summary:
        key = (row["benchmark"], int(row["load_setpoint_mflit_per_port_s"]))
        by_point.setdefault(key, []).append(row)
        if row["pass_fail"] != "PASS" or row["full_drain_pass"] != "True" or row["sdf_pass"] != "True":
            raise SystemExit(f"acceptance gate failed: {key} {row['design']}")
        if "retry_csv_gate" not in row["result_case"] and key[1] == 5:
            raise SystemExit(f"initial failed M5 case leaked into archive: {key}")
        result = archive / "cases" / row["benchmark"] / f"m{key[1]}" / row["design"] / "result.csv"
        result_rows = rows(result)
        if len(result_rows) != 1 or sha256(result) != row["result_csv_sha256"]:
            raise SystemExit(f"result CSV source hash gate failed: {result}")
        verify_case_metrics(result_rows[0], str(result))
        sdf = archive / "shared_sdf" / f"{row['design']}_sdf_annotate.log"
        sdf_ref = archive / "cases" / row["benchmark"] / f"m{key[1]}" / row["design"] / "sdf_reference.sha256"
        if not sdf.is_file() or not sdf_ref.is_file() or not sdf_ref.read_text(encoding="utf-8").strip().startswith(sha256(sdf)):
            raise SystemExit(f"SDF reference SHA-256 gate failed: {key} {row['design']}")
    if len(by_point) != 60 or any(len(pair) != 2 or len({r["trace_sha256"] for r in pair}) != 1 for pair in by_point.values()):
        raise SystemExit("paired trace gate failed")
    raw_hashes = manifest.get("raw_file_sha256", {})
    if len(raw_hashes) != 660:
        raise SystemExit(f"raw file inventory expected 660, got {len(raw_hashes)}")
    for relative, expected in raw_hashes.items():
        path = archive / relative
        if not path.is_file() or sha256(path) != expected:
            raise SystemExit(f"raw file SHA-256 gate failed: {relative}")

    frozen_inputs = []
    frozen_by_design = {}
    for design in ("PROP_temp64", "FM64"):
        log = archive / "compile" / f"{design}_input_hashes.log"
        for line in log.read_text(encoding="utf-8").splitlines():
            parts = line.split(maxsplit=1)
            if len(parts) != 2 or len(parts[0]) != 64:
                raise SystemExit(f"malformed frozen input hash: {log}")
            remote_path = parts[1].strip()
            frozen_inputs.append({"design": design, "remote_input": remote_path, "sha256": parts[0]})
            frozen_by_design.setdefault(design, {})[remote_path] = parts[0]
        if not any(r["design"] == design and r["remote_input"].endswith("_post.v") for r in frozen_inputs):
            raise SystemExit(f"frozen post-synthesis netlist hash absent: {design}")
        if not any(r["design"] == design and r["remote_input"].endswith(".sdf") for r in frozen_inputs):
            raise SystemExit(f"frozen SDF hash absent: {design}")
    write_rows(archive / "frozen_input_hashes.csv", frozen_inputs)

    for row in summary:
        design = row["design"]
        load = int(row["load_setpoint_mflit_per_port_s"])
        log = archive / "cases" / row["benchmark"] / f"m{load}" / design / "input_hashes.log"
        recorded = {}
        for line in log.read_text(encoding="utf-8").splitlines():
            parts = line.split(maxsplit=1)
            if len(parts) != 2:
                raise SystemExit(f"malformed per-case input SHA-256: {log}")
            recorded[parts[1].strip()] = parts[0]
        for remote_path, digest in frozen_by_design[design].items():
            if remote_path.endswith("_post.v") or remote_path.endswith(".sdf"):
                if recorded.get(remote_path) != digest:
                    raise SystemExit(f"frozen netlist/SDF mismatch in {log}: {remote_path}")
        case_path = next((p for p in recorded if p.endswith("/" + row["canonical_case"])), None)
        if case_path is None:
            raise SystemExit(f"recorded input case absent in {log}")
        if load == 5:
            local_case = REPO / "DATE paper" / "experiments" / "intermediate" / "e2_smoke_cases" / row["canonical_case"]
            if not local_case.is_file() or sha256(local_case) != recorded[case_path]:
                raise SystemExit(f"accepted M5 original input hash mismatch: {local_case}")
            copy = archive / "m5_original_cases" / row["canonical_case"]
            copy.parent.mkdir(parents=True, exist_ok=True)
            if not copy.exists():
                shutil.copy2(local_case, copy)
            if sha256(copy) != recorded[case_path]:
                raise SystemExit(f"M5 input copy hash mismatch: {copy}")
        elif recorded[case_path] != row["case_sha256"]:
            raise SystemExit(f"per-case input SHA-256 mismatch: {log}")

    output = []
    for source_path, status in (
        (REPO / "DATE paper/experiments/figures/paper64/20260914_092324_asap_uc_m5_800_mesh64_prop_temp64/aggregated_metrics.csv", "provisional_three_dut_audit_pending"),
        (REPO / "DATE paper/experiments/figures/paper64/20260913_asap_uc_m5_200_mesh64_pfat64/aggregated_metrics.csv", "historical_12_point_only"),
    ):
        for row in rows(source_path):
            output.append({
                "benchmark": "TOPO-UR", "design": row["design"],
                "load": row["load_setpoint_mflit_per_port_s"],
                "delivered_mflit_per_port_s": row["delivered_mflit_per_port_s"],
                "near_lossless": "", "status": status,
                "source": str(source_path.relative_to(REPO)).replace("\\", "/"),
                "source_sha256": sha256(source_path),
            })
    for row in summary:
        output.append({
            "benchmark": row["benchmark"], "design": row["design"],
            "load": row["load_setpoint_mflit_per_port_s"],
            "delivered_mflit_per_port_s": row["delivered_mflit_per_port_s"],
            "near_lossless": row["near_lossless"],
            "status": "accepted_two_dut" if row["near_lossless"] == "True" else "throughput_only_saturated",
            "source": f"cases/{row['benchmark']}/m{row['load_setpoint_mflit_per_port_s']}/{row['design']}/result.csv",
            "source_sha256": row["result_csv_sha256"],
        })
    write_rows(archive / "fig_b_source.csv", output)
    stamp = archive.name.removeprefix("compact64_")
    for benchmark, dirname in (("TOPO-BC", f"benchmark_bc_{stamp}"), ("HOTSPOT10", f"benchmark_hotspot10_{stamp}")):
        manifest.setdefault("figure_outputs", {})[benchmark] = sorted(
            p.name for p in (archive / "figures" / dirname).iterdir() if p.suffix in (".png", ".pdf")
        )
    (archive / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    result_path = archive / "RESULTS.md"
    if "## Compact64 evidence view" not in result_path.read_text(encoding="utf-8"):
      with result_path.open("a", encoding="utf-8") as result:
        result.write("\n## Compact64 evidence view\n\n")
        result.write("- E1: PROP_temp64–FlatMesh64 UR 30-point historical evidence and PFAT64–FlatMesh64 12-point historical evidence are indexed, but the three-DUT common-trace audit and PFAT64补点 remain open.\n")
        result.write("- E2: matched Sync PROP_temp64 B8 does not yet have an authorized new synthesis run; old Sync1222 is not a strict counterpart.\n")
        result.write("- E3: this archive accepts 120 MAXIMUM-SDF full-drain cases, 60 paired traces, for PROP_temp64 and FlatMesh64 only. PFAT64 BC/Hotspot10 remains open.\n")
        result.write("- E4: F16 M5 Native and repeated-unicast full-drain completion results are indexed; other load points and clean energy remain open.\n")
        result.write("- E5: ten existing fanout points are 399/400 with final backlog 1; exploratory only.\n")
        result.write("- E6: Router aggregate GLS is distinct from the single-lane 919 Mflit/s body-service micro-benchmark. PT-PX remains blocked by PT-063.\n")
        result.write("- Fig. B input: `fig_b_source.csv` preserves historical UR rows as provisional; no three-DUT comparison claim is asserted.\n")
        result.write("- Power: no accepted paper64 network power points; all future PT-PX quantities are post-synthesis estimates.\n")
    lines = []
    for path in sorted(archive.rglob("*")):
        if path.is_file() and path.name != "hashes.sha256":
            lines.append(f"{sha256(path)}  {path.relative_to(archive).as_posix()}")
    (archive / "hashes.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"COMPACT64_FINAL_AUDIT_PASS rows=120 raw_files={len(raw_hashes)} fig_b_rows={len(output)} archive={archive}", flush=True)


if __name__ == "__main__":
    main()

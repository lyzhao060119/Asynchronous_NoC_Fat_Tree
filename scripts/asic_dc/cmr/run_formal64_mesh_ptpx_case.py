#!/usr/bin/env python3
"""Validate one remote activity point and run PT-PX in its measured window."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import re
import subprocess
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--activity", type=Path, required=True)
    ap.add_argument("--report", type=Path, required=True)
    ap.add_argument("--tcl", type=Path, required=True)
    ap.add_argument("--netlist-root", type=Path, required=True)
    ap.add_argument("--ddc-name", default="CMRMeshNoC.ddc")
    ap.add_argument("--netlist-name", default="CMRMeshNoC_post.v")
    ap.add_argument("--sdf-name", default="CMRMeshNoC.sdf")
    ap.add_argument("--top", default="CMRMeshNoC")
    ap.add_argument("--strip-path", default=(
        "tb_cmr_noc64_async_boundary_failfast/core/"
        "g_behavioral_noc_mesh.noc/dut"))
    args = ap.parse_args()
    with (args.activity / "result.csv").open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 1:
        raise RuntimeError("activity result must contain exactly one row")
    row = rows[0]
    if (row["pass_fail"] != "PASS" or int(row["missing_expected_flits"]) != 0 or
            int(row["unexpected_flits"]) != 0 or int(row["timeout_hit"]) != 0):
        raise RuntimeError("activity scoreboard failed")
    start = int(row["measurement_start_ps"])
    end = int(row["measurement_end_ps"])
    if not 0 < start < end:
        raise RuntimeError("invalid activity window")
    log = (args.activity / "sdf_annotate.log").read_text(errors="replace")
    if not re.search(r"Total errors:\s*0\b", log):
        raise RuntimeError("SDF annotation is not clean")
    vcd = args.activity / "measurement.vcd"
    if vcd.stat().st_size < 1000:
        raise RuntimeError("VCD missing or empty")
    # Match literal VCD scope tokens, not a dot-to-slash transformation of
    # the HDL name. VCS may emit generate-block.instance as one token.
    scopes = []
    matched_scope = False
    with vcd.open(errors="replace") as stream:
        for line in stream:
            words = line.split()
            if words[:1] == ["$scope"]:
                scopes.append(words[2])
                matched_scope |= "/".join(scopes) == args.strip_path
            elif words[:1] == ["$upscope"]:
                scopes.pop()
            elif words[:1] == ["$enddefinitions"]:
                break
    if not matched_scope:
        raise RuntimeError(f"DUT strip-path not present in VCD: {args.strip_path}")
    args.report.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update({
        "CMR_POWER_DDC": str(args.netlist_root / args.ddc_name),
        "CMR_POWER_NETLIST": str(args.netlist_root / args.netlist_name),
        "CMR_POWER_SDF": str(args.netlist_root / args.sdf_name),
        "CMR_POWER_VCD": str(vcd),
        "CMR_POWER_TOP": args.top,
        "CMR_POWER_STRIP_PATH": args.strip_path,
        "CMR_POWER_START_NS": f"{start / 1000:.3f}",
        "CMR_POWER_END_NS": f"{end / 1000:.3f}",
        "CMR_POWER_REPORT_DIR": str(args.report),
    })
    print(f"FORMAL64_PTPX_CASE_START case={row['case_name']} window_ps={start}:{end} vcd_sha256={digest(vcd)}", flush=True)
    proc = subprocess.run(["/soft/synopsys/prime/V-2023.12/bin/pt_shell", "-f", str(args.tcl)],
                          env=env, cwd=args.report)
    if proc.returncode:
        for temporary in args.report.glob("primetime_px*.fsdb"):
            temporary.unlink(missing_ok=True)
        raise RuntimeError(f"pt_shell exited {proc.returncode}")
    for name in ("check_power.rpt", "activity.rpt", "power.rpt", "power_hierarchy.rpt", "power_cells.rpt"):
        if (args.report / name).stat().st_size == 0:
            raise RuntimeError(f"empty PT report: {name}")
    activity = (args.report / "activity.rpt").read_text(errors="replace")
    if not re.search(r"Nets\s+\d+\(100\.00%\).*?\b0\(0\.00%\)", activity):
        raise RuntimeError("activity report does not show complete net annotation")
    for temporary in args.report.glob("primetime_px*.fsdb"):
        temporary.unlink(missing_ok=True)
    print(f"FORMAL64_PTPX_CASE_PASS case={row['case_name']} report={args.report}", flush=True)


if __name__ == "__main__":
    main()

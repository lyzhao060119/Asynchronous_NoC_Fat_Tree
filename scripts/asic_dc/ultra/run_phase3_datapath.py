#!/usr/bin/env python3
"""Launch/collect the two frozen-entry Phase-3 Router datapath runs."""
from __future__ import annotations
import json, os, subprocess, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
BASELINE = "20260812_timing_role_split_r4"
PROFILE = "ULTRA_P250_PRS_ACG_OPM75"

def invoke(run_id: str, seed_run: str) -> None:
    target = REPO / "scripts/asic_dc/ultra" / (run_id + "_targets.tcl")
    rtc = REPO / "docs/timing_baselines/20260812_rtc_all_edges_baseline_r2_rtc.csv"
    # Remote collection preserves the original archive hierarchy below
    # ``archive/``.  Keeping that hierarchy makes the frozen measurement
    # immutable and avoids copying a GLS log into a generated-input folder.
    dp_log = REPO / "scripts/asic_dc/ultra/results/20260812_phase3_datapath_measure/archive/logs/gls/20260812_phase3_datapath_measure/sdf/unicast3/gap0/run.log"
    subprocess.run([sys.executable, str(REPO / "scripts/asic_dc/ultra/create_ultra_datapath_targets.py"),
                    "--rtc-csv", str(rtc), "--datapath-log", str(dp_log), "--out", str(target), "--scale", "0.95"], check=True)
    env = os.environ.copy()
    env.update({
        "ULTRA_RUN_ID": run_id,
        "ULTRA_DELAY_PROFILE": PROFILE,
        "ULTRA_STAGES": "dc,sdf,sta",
        "ULTRA_SDF_CASES": "unicast3,mc_single3,mc_disjoint_parallel3,uc_overlap_release3,mc_overlap_tailjoin3",
        "ULTRA_DATAPATH_SEED_DDC": f"{ROOT}/outputs/{seed_run}/UltraRouter.ddc",
        "ULTRA_DATAPATH_OVERLAY": f"{ROOT}/rtl/async_ultra_router_datapath.sdc",
        "ULTRA_DATAPATH_TARGET_FILE": f"{ROOT}/rtl/{target.name}",
        "ULTRA_DATAPATH_REPORT_DIR": f"{ROOT}/reports/dc/{run_id}",
        "ULTRA_TRACE_DATAPATH": "1",
    })
    # Make the generated target part of the immutable upload manifest.
    env["ULTRA_DATAPATH_LOCAL_TARGET"] = str(target)
    subprocess.run([sys.executable, str(REPO / "scripts/asic_dc/ultra/run_remote_ultra_flow.py")], cwd=REPO, env=env, check=True)

def main() -> None:
    if len(sys.argv) == 2 and sys.argv[1] == "measure":
        env = os.environ.copy(); env.update({"ULTRA_RUN_ID": "20260812_phase3_datapath_measure", "ULTRA_NETLIST_RUN_ID": BASELINE, "ULTRA_DELAY_PROFILE": PROFILE, "ULTRA_STAGES": "sdf", "ULTRA_SDF_CASES": "unicast3", "ULTRA_TRACE_DATAPATH": "1"})
        subprocess.run([sys.executable, str(REPO / "scripts/asic_dc/ultra/run_remote_ultra_flow.py")], cwd=REPO, env=env, check=True)
    elif len(sys.argv) == 2 and sys.argv[1] == "r1": invoke("20260812_phase3_datapath_r1", BASELINE)
    elif len(sys.argv) == 2 and sys.argv[1] == "r2": invoke("20260812_phase3_datapath_r2", "20260812_phase3_datapath_r1")
    else: raise SystemExit("usage: run_phase3_datapath.py r1|r2")
if __name__ == "__main__": main()

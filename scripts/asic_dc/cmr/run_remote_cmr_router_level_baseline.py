#!/usr/bin/env python3
"""Baseline DC + hop PPA: RCU 1xDEL050, no matched buffer, Ackin 1xDEL050.

Thin L1/L2/L3 are (1,1).  Fat is L1 (1,2) plus 1222 L2/L3 (2,2).
The six *_hop_del050_ackin050 netlists and 20260830_cmr_router_level_baseline_del050
are frozen: this script reuses them and skips hop PPA unless you pass a new
CMR_HOP_PPA_RUN_ID.  Do not overwrite them.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


from cmr_frozen_run_ids import (
    FROZEN_HOP_NETLIST_RUN_IDS,
    FROZEN_HOP_PPA_RUN_ID,
    refuse_overwrite,
)


HERE = Path(__file__).resolve().parent
GEOMS = (
    {
        "kind": "thin_l1_1to1",
        "level": 1,
        "child": 1,
        "parent": 1,
        "reuse": True,
        "dc_id": "20260830_cmr_thin_l1_hop_del050_ackin050",
        "env": ("CMR_THIN_L1_1TO1_NETLIST_RUN_ID", "CMR_THIN_NETLIST_RUN_ID"),
    },
    {
        "kind": "thin_l2_1to1",
        "level": 2,
        "child": 1,
        "parent": 1,
        "reuse": True,
        "dc_id": "20260830_cmr_thin_l2_hop_del050_ackin050",
        "env": ("CMR_THIN_L2_1TO1_NETLIST_RUN_ID",),
    },
    {
        "kind": "thin_l3_1to1",
        "level": 3,
        "child": 1,
        "parent": 1,
        "reuse": True,
        "dc_id": "20260830_cmr_thin_l3_hop_del050_ackin050",
        "env": ("CMR_THIN_L3_1TO1_NETLIST_RUN_ID",),
    },
    {
        "kind": "fat_l1_1to2",
        "level": 1,
        "child": 1,
        "parent": 2,
        "reuse": True,
        "dc_id": "20260830_cmr_fat_l1_hop_del050_ackin050",
        "env": ("CMR_FAT_L1_1TO2_NETLIST_RUN_ID", "CMR_FAT_NETLIST_RUN_ID"),
    },
    {
        "kind": "fat_l2_2to2",
        "level": 2,
        "child": 2,
        "parent": 2,
        "reuse": False,
        "dc_id": "20260830_cmr_fat_l2_hop_del050_ackin050",
        "env": ("CMR_FAT_L2_2TO2_NETLIST_RUN_ID",),
    },
    {
        "kind": "fat_l3_2to2",
        "level": 3,
        "child": 2,
        "parent": 2,
        "reuse": False,
        "dc_id": "20260830_cmr_fat_l3_hop_del050_ackin050",
        "env": ("CMR_FAT_L3_2TO2_NETLIST_RUN_ID",),
    },
)


def delay_env(base: dict[str, str]) -> dict[str, str]:
    env = base.copy()
    env["PYTHONUNBUFFERED"] = "1"
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_SKIP_LOCAL_SMOKE"] = "1"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = "1"
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = "50"
    env["CMR_RCU_MATCHED_BUF_STAGES"] = "0"
    env["CMR_OPM_ACKIN_DELAY_STEPS"] = "1"
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = "50"
    env["CMR_LANE01_BUF_STAGES"] = "0"
    env.pop("CMR_DC_SEED_RUN_ID", None)
    env.pop("CMR_OPM_ACKIN_USE_BUF", None)
    return env


def run_dc(geom: dict) -> None:
    refuse_overwrite(geom["dc_id"], action="dc")
    env = delay_env(os.environ)
    env["CMR_DC_ONLY"] = "1"
    env["CMR_ROUTER_LEVEL"] = str(geom["level"])
    env["CMR_CHILD_LANES"] = str(geom["child"])
    env["CMR_PARENT_LANES"] = str(geom["parent"])
    env["CMR_RUN_ID"] = geom["dc_id"]
    print(
        "BASELINE_DC kind=%s level=%s c%sp%s run=%s"
        % (geom["kind"], geom["level"], geom["child"], geom["parent"], geom["dc_id"]),
        flush=True,
    )
    subprocess.check_call(
        [sys.executable, "-u", str(HERE / "run_remote_cmr_flow.py")],
        cwd=HERE,
        env=env,
    )


def main() -> None:
    reuse_l1 = os.environ.get("CMR_REUSE_L1_BASELINE", "1") == "1"
    skip_dc = os.environ.get("CMR_BASELINE_SKIP_DC", "0") == "1"
    skip_hop = os.environ.get("CMR_BASELINE_SKIP_HOP", "0") == "1"
    for geom in GEOMS:
        if skip_dc:
            print("BASELINE_SKIP_DC", geom["kind"], geom["dc_id"], flush=True)
            continue
        if geom["dc_id"] in FROZEN_HOP_NETLIST_RUN_IDS:
            print("BASELINE_FROZEN_REUSE", geom["kind"], geom["dc_id"], flush=True)
            continue
        if geom["reuse"] and reuse_l1:
            print("BASELINE_REUSE", geom["kind"], geom["dc_id"], flush=True)
            continue
        run_dc(geom)
    if skip_hop:
        return
    env = delay_env(os.environ)
    env.pop("CMR_DC_ONLY", None)
    hop_run = os.environ.get("CMR_HOP_PPA_RUN_ID", FROZEN_HOP_PPA_RUN_ID)
    env["CMR_HOP_PPA_RUN_ID"] = hop_run
    if hop_run == FROZEN_HOP_PPA_RUN_ID and os.environ.get("CMR_FORCE_OVERWRITE_FROZEN", "0") != "1":
        print("BASELINE_HOP_FROZEN_SKIP", hop_run, flush=True)
        return
    refuse_overwrite(hop_run, action="hop-ppa-results")
    env["CMR_HOP_KINDS"] = ",".join(geom["kind"] for geom in GEOMS)
    for geom in GEOMS:
        for name in geom["env"]:
            env[name] = geom["dc_id"]
    print("BASELINE_HOP", env["CMR_HOP_PPA_RUN_ID"], env["CMR_HOP_KINDS"], flush=True)
    subprocess.check_call(
        [sys.executable, "-u", str(HERE / "run_remote_cmr_router_hop_ppa.py")],
        cwd=HERE,
        env=env,
    )


if __name__ == "__main__":
    main()

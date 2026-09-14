#!/usr/bin/env python3
"""Submit the next descal GLS/RTL jobs after the isolation split.

Modes:
  func           FM64 func GLS of the read-only 20260831 netlist (iso + directed)
  prop256        PROP256 full KEY-256 directed RTL (needs emitted NoC_256nodes.v)
  prop256-probe  KEY-256 hop-chain + pkt13/pkt15 isolation on node26/24/18
  fm64-dc        New cmr_descal_ mesh DC + V3 SDF (does not overwrite 20260831)
  fm64-hold      8x8 mesh DC after TailPassed GrantHoldBuf; SDF + hop-probe
  fm64-reopen    8x8 mesh DC after L5 LatchReopenDelay 1xDEL050; SDF + hop-probe
  fm16-dc        4x4 mesh baseline DC + MAXIMUM-SDF hop-probe (no OPM hold buf)
  fm16-fix       4x4 mesh DC after TailPassed GrantHoldBuf; same isolation

Does not cook DelayElement_sim.  New run IDs stay cmr_descal_*.
"""
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
CMR = Path(__file__).resolve().parent
EXPERIMENTS = REPO / "DATE paper" / "experiments"
CASE_DIR = EXPERIMENTS / "intermediate" / "des_calibration" / "cases"
MESH64 = "20260831_115856_cmr_mesh64_p50"
STAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
PROP256_DIRECTED = "KEY-256_n256_s900001_zero_PROP256_top0"
FM64_SDF = (
    "DBG-64_fm64_6to44",
    "KEY-64_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_zero_FM64_top0",
    "TOPO-UR_n64_s900001_r0p10_FM64_top0",
)


def _base_env() -> dict[str, str]:
    env = os.environ.copy()
    extra = env.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
    env.update(
        {
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_DES_BSUB_EXTRA": extra,
            "CMR_REMOTE_ROOT": env.get(
                "CMR_DES_REMOTE_ROOT",
                env.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR"),
            ),
            "CMR_NOC64_ALLOW_V3": "1",
            "CMR_MESH64_ALLOW_V3": "1",
            "CMR_NOC256_ALLOW_V3": "1",
            "CMR_NOC64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_MESH64_V3_CASE_DIR": str(CASE_DIR),
            "CMR_NOC256_V3_CASE_DIR": str(CASE_DIR),
        }
    )
    return env


def launch(script: Path, env: dict[str, str], label: str) -> int:
    print("LAUNCH", label, script.name, flush=True)
    completed = subprocess.run(
        [sys.executable, str(script)],
        cwd=str(REPO),
        env=env,
        check=False,
    )
    print("LAUNCH_DONE", label, "rc", completed.returncode, flush=True)
    return completed.returncode


def launch_func() -> int:
    env = _base_env()
    cases = "DBG-64_fm64_6to44,KEY-64_n64_s900001_zero_FM64_top0"
    env.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_func" % STAMP,
            "CMR_MESH64_NETLIST_RUN_ID": MESH64,
            "CMR_MESH64_SKIP_FUNC": "0",
            "CMR_MESH64_SKIP_SDF": "1",
            "CMR_MESH64_CASES": cases,
            "CMR_MESH64_FUNC_CASES": cases,
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE",
        }
    )
    return launch(CMR / "run_remote_cmr_mesh64_sdf.py", env, "fm64-func")


def launch_prop256() -> int:
    rtl = REPO / "generated_cmr" / "clustered_noc_g2_m2" / "NoC_256nodes.v"
    if not rtl.is_file():
        print("MISSING_EMIT", rtl, flush=True)
        return 2
    text = rtl.read_text(encoding="utf-8", errors="replace")
    if "WormholeLaneLock" not in text:
        print("EMIT_STALE no WormholeLaneLock in", rtl, flush=True)
        return 2
    env = _base_env()
    env.update(
        {
            "CMR_NOC256_KIND": "prop",
            "CMR_NOC256_RUN_ID": "%s_cmr_descal_prop256" % STAMP,
            "CMR_NOC256_CASES": PROP256_DIRECTED,
            "CMR_FORCE_EMIT": "0",
        }
    )
    return launch(CMR / "run_remote_cmr_noc256_rtl.py", env, "prop256-directed")


def launch_prop256_probe() -> int:
    rtl = REPO / "generated_cmr" / "clustered_noc_g2_m2" / "NoC_256nodes.v"
    if not rtl.is_file():
        print("MISSING_EMIT", rtl, flush=True)
        return 2
    text = rtl.read_text(encoding="utf-8", errors="replace")
    if "WormholeLaneLock" not in text:
        print("EMIT_STALE no WormholeLaneLock in", rtl, flush=True)
        return 2
    two = CASE_DIR / "DBG-256_prop_13and15.case"
    if not two.is_file():
        print("MISSING_CASE", two, flush=True)
        return 2
    env = _base_env()
    env["CMR_DES_BSUB_EXTRA"] = '-m "node26 node24 node18"'
    hop = dict(env)
    hop.update(
        {
            "CMR_NOC256_KIND": "prop",
            "CMR_NOC256_RUN_ID": "%s_cmr_descal_prop256_hop" % STAMP,
            "CMR_NOC256_CASES": PROP256_DIRECTED,
            "CMR_NOC256_SIM_ARGS": "+HOP_PROBE",
            "CMR_FORCE_EMIT": "0",
        }
    )
    rc = launch(CMR / "run_remote_cmr_noc256_rtl.py", hop, "prop256-hop")
    two_env = dict(env)
    two_env.update(
        {
            "CMR_NOC256_KIND": "prop",
            "CMR_NOC256_RUN_ID": "%s_cmr_descal_prop256_2pkt" % STAMP,
            "CMR_NOC256_CASES": "DBG-256_prop_13and15",
            "CMR_NOC256_SIM_ARGS": "+HOP_PROBE +DUMP_SCOPED_VCD",
            "CMR_FORCE_EMIT": "0",
        }
    )
    rc2 = launch(CMR / "run_remote_cmr_noc256_rtl.py", two_env, "prop256-2pkt")
    return rc or rc2


def launch_fm64_probe() -> int:
    env = _base_env()
    env["CMR_DES_BSUB_EXTRA"] = '-m "node26 node24 node18"'
    env.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_hop" % STAMP,
            "CMR_MESH64_NETLIST_RUN_ID": "20260901_172539_cmr_descal_fm64",
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_MESH64_CASES": "DBG-64_fm64_6to44",
            "CMR_MESH64_FUNC_CASES": "DBG-64_fm64_6to44",
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE +MESH_HOP_PROBE",
            "CMR_FORCE_EMIT": "0",
        }
    )
    return launch(CMR / "run_remote_cmr_mesh64_sdf.py", env, "fm64-hop")


def launch_fm64_dc() -> int:
    rtl = REPO / "generated_cmr" / "mesh_noc64_11" / "CMRMeshNoC.v"
    if not rtl.is_file():
        print("MISSING_EMIT", rtl, flush=True)
        return 2
    env = _base_env()
    cases = ",".join(FM64_SDF)
    env.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64" % STAMP,
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_MESH64_CASES": cases,
            "CMR_MESH64_FUNC_CASES": cases,
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE",
            "CMR_FORCE_EMIT": "0",
        }
    )
    env.pop("CMR_MESH64_NETLIST_RUN_ID", None)
    selector = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR" / "OPMSelector.v"
    if "BlockSet" not in selector.read_text(encoding="utf-8"):
        print("MISSING_HOLD_OFF", selector, flush=True)
        return 2
    return launch(CMR / "run_remote_cmr_mesh64_sdf.py", env, "fm64-dc")


def launch_fm64_hold() -> int:
    rtl = REPO / "generated_cmr" / "mesh_noc64_11" / "CMRMeshNoC.v"
    scala = REPO / "src" / "main" / "scala" / "Router_Architecture" / "CMR" / "OPM.scala"
    if "GrantHold" not in scala.read_text(encoding="utf-8"):
        print("MISSING_GRANT_HOLD", scala, flush=True)
        return 2
    if not rtl.is_file() or "GrantHoldBuf" not in rtl.read_text(encoding="utf-8", errors="replace"):
        print("MISSING_EMIT_GRANT_HOLD", rtl, flush=True)
        return 2
    env = _base_env()
    env["CMR_DES_BSUB_EXTRA"] = '-m "node26 node24 node18"'
    cases = ",".join(FM64_SDF)
    env.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_hold" % STAMP,
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_MESH64_CASES": cases,
            "CMR_MESH64_FUNC_CASES": cases,
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE +MESH_HOP_PROBE",
            "CMR_EXPECTED_GRANT_HOLD_BUF": "1280",
            "CMR_FORCE_EMIT": "0",
        }
    )
    env.pop("CMR_MESH64_NETLIST_RUN_ID", None)
    return launch(CMR / "run_remote_cmr_mesh64_sdf.py", env, "fm64-hold")


def launch_fm64_reopen() -> int:
    scala = REPO / "src" / "main" / "scala" / "Router_Architecture" / "CMR" / "OPM.scala"
    text = scala.read_text(encoding="utf-8")
    if "LatchReopenDelay" not in text:
        print("MISSING_LATCH_REOPEN", scala, flush=True)
        return 2
    if "GrantHold" in text:
        print("STALE_GRANT_HOLD", scala, flush=True)
        return 2
    env = _base_env()
    env["CMR_DES_BSUB_EXTRA"] = '-m "node26 node24 node18"'
    cases = ",".join(FM64_SDF)
    env.update(
        {
            "CMR_MESH64_RUN_ID": "%s_cmr_descal_fm64_reopen" % STAMP,
            "CMR_MESH64_SKIP_FUNC": "1",
            "CMR_MESH64_SKIP_SDF": "0",
            "CMR_MESH64_CASES": cases,
            "CMR_MESH64_FUNC_CASES": cases,
            "CMR_MESH64_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE +MESH_HOP_PROBE",
            "CMR_EXPECTED_LATCH_REOPEN_DEL": "320",
            "CMR_EXPECTED_GRANT_HOLD_BUF": "0",
            "CMR_FORCE_EMIT": "1",
        }
    )
    env.pop("CMR_MESH64_NETLIST_RUN_ID", None)
    return launch(CMR / "run_remote_cmr_mesh64_sdf.py", env, "fm64-reopen")


def _fm16_env() -> dict[str, str]:
    env = _base_env()
    env["CMR_DES_BSUB_EXTRA"] = '-m "node26 node24 node18"'
    env.update(
        {
            "CMR_MESH16_ALLOW_V3": "1",
            "CMR_MESH16_V3_CASE_DIR": str(CASE_DIR),
            "CMR_MESH16_CASES": "DBG-16_fm16_3to13",
            "CMR_MESH16_SKIP_GLS": "0",
            "CMR_MESH16_SKIP_SDF": "0",
            "CMR_MESH16_SIM_ARGS": "+DUMP_ON_FAIL +MESH_LOCAL_PROBE +MESH_HOP_PROBE",
        }
    )
    env.pop("CMR_MESH16_NETLIST_RUN_ID", None)
    return env


def launch_fm16_dc() -> int:
    rtl = REPO / "generated_cmr" / "mesh_noc16_11" / "CMRMeshNoC.v"
    if not rtl.is_file():
        print("MISSING_EMIT", rtl, flush=True)
        return 2
    if "GrantHoldBuf" in rtl.read_text(encoding="utf-8", errors="replace"):
        print("BASELINE_HAS_HOLD_BUF refuse fm16-dc until emit without GrantHoldBuf", flush=True)
        return 2
    env = _fm16_env()
    env["CMR_MESH16_RUN_ID"] = "%s_cmr_descal_fm16" % STAMP
    env["CMR_FORCE_EMIT"] = "0"
    env.pop("CMR_EXPECTED_GRANT_HOLD_BUF", None)
    return launch(CMR / "run_remote_cmr_mesh16_sdf.py", env, "fm16-dc")


def launch_fm16_fix() -> int:
    rtl = REPO / "generated_cmr" / "mesh_noc16_11" / "CMRMeshNoC.v"
    scala = REPO / "src" / "main" / "scala" / "Router_Architecture" / "CMR" / "OPM.scala"
    if "GrantHold" not in scala.read_text(encoding="utf-8"):
        print("MISSING_GRANT_HOLD", scala, flush=True)
        return 2
    env = _fm16_env()
    env["CMR_MESH16_RUN_ID"] = "%s_cmr_descal_fm16_hold" % STAMP
    env["CMR_FORCE_EMIT"] = "1"
    env["CMR_EXPECTED_GRANT_HOLD_BUF"] = "320"
    if rtl.is_file() and "GrantHoldBuf" not in rtl.read_text(encoding="utf-8", errors="replace"):
        print("FORCE_EMIT mesh16 GrantHoldBuf missing in current Verilog", flush=True)
    return launch(CMR / "run_remote_cmr_mesh16_sdf.py", env, "fm16-fix")


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode not in (
        "func",
        "prop256",
        "prop256-probe",
        "fm64-dc",
        "fm64-probe",
        "fm64-hold",
        "fm64-reopen",
        "fm16-dc",
        "fm16-fix",
    ):
        print(
            "usage: launch_descal_fix.py "
            "func|prop256|prop256-probe|fm64-dc|fm64-probe|fm64-hold|"
            "fm64-reopen|fm16-dc|fm16-fix",
            flush=True,
        )
        return 2
    if not CASE_DIR.is_dir():
        raise SystemExit("missing V3 case dir " + str(CASE_DIR))
    rc = {
        "func": launch_func,
        "prop256": launch_prop256,
        "prop256-probe": launch_prop256_probe,
        "fm64-dc": launch_fm64_dc,
        "fm64-probe": launch_fm64_probe,
        "fm64-hold": launch_fm64_hold,
        "fm64-reopen": launch_fm64_reopen,
        "fm16-dc": launch_fm16_dc,
        "fm16-fix": launch_fm16_fix,
    }[mode]()
    if rc:
        print("LAUNCH_FAIL", mode, "rc", rc, "stamp", STAMP, flush=True)
        return rc
    print("LAUNCH_OK mode=%s stamp=%s" % (mode, STAMP), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Dispatch table that wraps existing remote DC/GLS entry points.

The orchestrator never copies DC or GLS Tcl.  It only sets environment
variables and runs the existing Python drivers.

`pnr_pilot` / `pnr_probe` remain in the table for the closed Phase 1 record.
DATE V3 does not run P&R; do not schedule those adapters on the paper path.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from .paths import CMR_SCRIPTS, PNR_SCRIPTS, REPO

ADAPTERS = {
    "import_readonly": None,
    "dc_cmr_router": CMR_SCRIPTS / "run_remote_cmr_flow.py",
    "dc_sync_router": CMR_SCRIPTS / "run_remote_cmr_sync_router.py",
    "hop_ppa": CMR_SCRIPTS / "run_remote_cmr_router_hop_ppa.py",
    "primitive_matrix": CMR_SCRIPTS / "run_remote_cmr_primitive_matrix.py",
    "noc64_async": CMR_SCRIPTS / "run_remote_cmr_noc64_sdf.py",
    "noc64_sync": CMR_SCRIPTS / "run_remote_cmr_sync_noc64_sdf.py",
    "mesh64": CMR_SCRIPTS / "run_remote_cmr_mesh64_sdf.py",
    "pnr_pilot": PNR_SCRIPTS / "run_remote_cmr_pnr_pilot.py",
    "pnr_probe": PNR_SCRIPTS / "probe_remote_pnr.py",
}


def resolve(adapter: str) -> Path | None:
    if adapter not in ADAPTERS:
        raise KeyError("unknown adapter %s" % adapter)
    return ADAPTERS[adapter]


def run_adapter(run: dict[str, Any], *, dry_run: bool = False) -> int:
    adapter = run["adapter"]
    script = resolve(adapter)
    env = os.environ.copy()
    for key, value in (run.get("env") or {}).items():
        env[str(key)] = "" if value is None else str(value)
    argv = [sys.executable, str(script), *(run.get("argv") or [])] if script else None
    if dry_run or script is None:
        return 0
    completed = subprocess.run(argv, cwd=REPO, env=env, check=False)
    return completed.returncode

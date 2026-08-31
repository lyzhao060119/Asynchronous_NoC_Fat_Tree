#!/usr/bin/env python3
"""Generate, upload, and run RouterL1 per-domain delay profile sweeps.

Credentials for remote steps are inherited by the existing scripts:
  C1_HOST / C1_USER / C1_PASS

Examples:
  python scripts/asic_dc/run_routerl1_delay_profile_sweep.py P150_BASELINE
  python scripts/asic_dc/run_routerl1_delay_profile_sweep.py P100_FIFO_ONLY P100_SHORT_ONLY
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ASIC_DC = REPO / "scripts" / "asic_dc"
RESULT_DIR = ASIC_DC / "timing" / "results"


def run(cmd: list[str], env: dict[str, str]) -> None:
    print("RUN", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=REPO, env=env, check=True)


def read_text(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(errors="replace")


def extract(pattern: str, text: str) -> str:
    m = re.search(pattern, text)
    return m.group(1) if m else "NA"


def summarize(profile: str) -> None:
    summary = read_text(RESULT_DIR / "combo_budget_bypass_summary.txt")
    csv = read_text(RESULT_DIR / "combo_budget_bypass.csv")
    print("\n=== PROFILE_SUMMARY %s ===" % profile)
    for line in summary.splitlines():
        if line.startswith("DEL") or "reqgen_launchPulse" in line or "covered_roles" in line:
            print(line)
    if csv:
        print("--- delay refs ---")
        for line in csv.splitlines()[1:]:
            cols = line.split(",")
            if len(cols) >= 12:
                print(
                    "%s/%s ref=%s unit_ns=%s combo=%s vs_current=%s needs=%s"
                    % (cols[0], cols[1], cols[3], cols[4], cols[5], cols[8], cols[11])
                )


def main() -> int:
    profiles = sys.argv[1:] or ["P150_BASELINE"]
    for profile in profiles:
        env = os.environ.copy()
        env["ASYNC_PRIMITIVES"] = "asic"
        env["ASYNC_DELAY_PROFILE"] = profile
        print("\n========== RouterL1 profile %s ==========" % profile, flush=True)
        run(["sbt", "runMain Router_Architecture.instantiation.RouterL1"], env)
        run(["python", str(ASIC_DC / "remote_upload_and_run.py"), "upload"], env)
        run(["python", str(ASIC_DC / "run_dc_r1_only.py")], env)
        run(
            ["python", str(ASIC_DC / "run_dc_r1_combo_budget.py")],
            env,
        )
        env["GLS_SMOKE_STAGE"] = "sdf_routerl1_probe"
        run(["python", str(ASIC_DC / "upload_and_run_gls_smoke.py")], env)
        summarize(profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run or dry-run V3.1.0 staged whole-network gates.

Default is check-only.  --submit launches remote synthesis only if the
previous gate is green.  A failure writes evidence and exits; it does not
fall back to the software event model.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.display_names import display_name  # noqa: E402
from date_v3.paths import CMR_SCRIPTS, REPO  # noqa: E402

from check_v31_gates import check_gate_a, check_gate_b, check_scale_pair  # noqa: E402


def _run_checker(gate: str, extra: list[str]) -> int:
    cmd = [sys.executable, str(SCRIPTS / "check_v31_gates.py"), "--gate", gate, *extra]
    return subprocess.run(cmd, cwd=REPO, check=False).returncode


def _submit(design_id: str, run_id: str, skip_gls: bool) -> int:
    env = os.environ.copy()
    env["CMR_NETWORK_DESIGN_ID"] = design_id
    env["CMR_NETWORK_RUN_ID"] = run_id
    env["CMR_HIER_STITCH_RUN_ID"] = run_id
    env["CMR_DESCAL_SUBMIT_ONLY"] = "1"
    if skip_gls:
        env["CMR_HIER_SKIP_GLS"] = "1"
    print("SUBMIT", display_name(design_id), run_id, flush=True)
    return subprocess.run(
        [sys.executable, str(CMR_SCRIPTS / "run_remote_cmr_network_sdf.py"), "--design", design_id],
        cwd=REPO,
        env=env,
        check=False,
    ).returncode


def main() -> int:
    parser = argparse.ArgumentParser(description="V3.1.0 network gate runner")
    parser.add_argument("--gate", default=os.environ.get("CMR_V31_GATE", "A"))
    parser.add_argument("--submit", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--skip-scala", action="store_true")
    parser.add_argument("--skip-traffic", action="store_true")
    parser.add_argument("--design", action="append", default=[])
    args = parser.parse_args()
    extra = []
    if args.skip_scala:
        extra.append("--skip-scala")
    if args.skip_traffic:
        extra.append("--skip-traffic")

    if args.gate == "A" or args.dry_run:
        try:
            check_gate_a(skip_scala=args.skip_scala, skip_traffic=True if args.dry_run else args.skip_traffic)
        except AssertionError as exc:
            print("GATE_FAIL A", exc, flush=True)
            return 1
        if args.gate == "A":
            return 0

    if args.gate in ("B", "C", "D", "E", "F"):
        b = check_gate_b()
        if not b["pass"]:
            print("GATE_FAIL B: 64-node template is not green. Not submitting 256/1024.")
            return 1

    if args.gate in ("C", "D") and args.submit:
        for design_id in args.design or ["PROP256", "FM256"]:
            run_id = "20260901_cmr_v31_%s_dc" % design_id.lower()
            code = _submit(design_id, run_id, skip_gls=True)
            if code != 0:
                print("GATE_FAIL C submit", display_name(design_id))
                return code
        return 0

    if args.gate in ("E", "F"):
        c = check_scale_pair(256, label="gate_C")
        if not c["pass"]:
            print("GATE_FAIL E blocked: 256-node gate is not green.")
            return 1
        if args.submit:
            for design_id in args.design or ["PROP1024", "FM1024"]:
                run_id = "20260901_cmr_v31_%s_dc" % design_id.lower()
                code = _submit(design_id, run_id, skip_gls=True)
                if code != 0:
                    print("GATE_FAIL E submit", display_name(design_id))
                    return code
            return 0

    return _run_checker(args.gate, extra)


if __name__ == "__main__":
    raise SystemExit(main())

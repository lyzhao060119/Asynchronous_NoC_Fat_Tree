#!/usr/bin/env python3
"""DATE V3 Phase 5 DES infrastructure gate.

Local unit tests + isolated hop MAXIMUM-SDF match + lock file.
Does not submit LSF.  prepare_descal.py builds the seed-900001 DES pack;
64/256 network MAXIMUM-SDF comparison stays pending until those traces exist.
Do not treat a hop lock as permission to write Fig. A/B/C DES numbers.
"""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))


def main() -> int:
    from test_des_v3 import main as des_tests

    rc = des_tests()
    if rc != 0:
        return rc
    sys.argv = ["calibrate_des.py", "--quick", "--write-lock"]
    from calibrate_des import main as calibrate

    rc = calibrate()
    if rc != 0:
        return rc
    from date_v3.hashutil import load_json
    from des.timing import LOCKED_PATH

    if not LOCKED_PATH.is_file():
        print("FAIL missing lock", LOCKED_PATH, flush=True)
        return 1
    lock = load_json(LOCKED_PATH)
    if lock.get("physical_class") == "post-layout":
        print("FAIL lock claims post-layout", flush=True)
        return 1
    if lock.get("paper_matrix_allowed"):
        print("PHASE5_GATE_PASS", flush=True)
    else:
        print("PHASE5_INFRA_GATE_PASS", flush=True)
        print("PHASE5_NETWORK_RTL_CAL pending; paper_matrix_allowed=false", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

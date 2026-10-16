#!/usr/bin/env python3
"""Run DATE V3 DES on a model-input JSON (local; no LSF)."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
EXPERIMENTS = SCRIPTS.parent
MODEL = EXPERIMENTS / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from date_v3.hashutil import write_json  # noqa: E402
from des.lock import verify_lock  # noqa: E402
from des.run import simulate_model_json  # noqa: E402
from des.timing import TimingTable  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design", required=True)
    parser.add_argument("--input", type=Path, required=True, help="*.model.json")
    parser.add_argument("--out", type=Path)
    parser.add_argument("--arb-seed", type=int, default=1)
    parser.add_argument("--case-tick-ns", type=float, default=20.0)
    parser.add_argument("--skip-lock", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    timing = TimingTable()
    if not args.skip_lock:
        lock_errors = verify_lock(timing)
        if lock_errors:
            print("LOCK", "; ".join(lock_errors), flush=True)
            return 2
        from des.timing import load_locked

        lock = load_locked() or {}
        if not lock.get("paper_matrix_allowed"):
            print("WARN paper_matrix_allowed=false; local DES only", flush=True)
    result = simulate_model_json(
        args.design,
        args.input,
        timing=timing,
        arb_seed=args.arb_seed,
        case_tick_ns=args.case_tick_ns,
    )
    if args.out:
        write_json(args.out, result)
    n_err = len(result.get("errors") or []) + len(result.get("oracle_errors") or [])
    print(
        json.dumps(
            {
                "design_id": result["design_id"],
                "model_version": result["model_version"],
                "calibration_hash": result["calibration_hash"],
                "physical_class": result["physical_class"],
                "events": len(result["records"]),
                "errors": n_err,
                "energy_hop_j": result["energy_hop_j"],
            }
        ),
        flush=True,
    )
    return 0 if n_err == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())

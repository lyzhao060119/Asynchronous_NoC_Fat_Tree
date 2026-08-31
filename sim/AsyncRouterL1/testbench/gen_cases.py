#!/usr/bin/env python3
"""Delegate AsyncRouterL1 case generation to the SyncRouterL1 generator."""

from __future__ import annotations

import runpy
import sys
from pathlib import Path


def main() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    sync_gen = repo_root / "sim" / "SyncRouterL1" / "testbench" / "gen_cases.py"
    if not sync_gen.exists():
        raise FileNotFoundError(f"missing SyncRouterL1 generator: {sync_gen}")

    if "--out-dir" not in sys.argv:
        sys.argv.extend(["--out-dir", str(Path(__file__).resolve().with_name("cases"))])

    sys.argv[0] = str(sync_gen)
    runpy.run_path(str(sync_gen), run_name="__main__")


if __name__ == "__main__":
    main()

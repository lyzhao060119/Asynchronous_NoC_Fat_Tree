#!/usr/bin/env python3
"""Add separate throughput and latency figures to an accepted compact64 archive."""
from __future__ import annotations

import argparse
import csv
import shutil
from pathlib import Path

from collect_e2_bc_hotspot64 import REPO, plot_benchmark


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    archive = args.archive.resolve()
    parent = (REPO / "DATE paper/experiments/raw/paper64").resolve()
    if archive.parent != parent or not archive.name.startswith("compact64_"):
        raise SystemExit("expected explicit compact64 archive under raw/paper64")
    with (archive / "summary.csv").open("r", encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    if len(rows) != 120:
        raise SystemExit("120-row acceptance summary required")
    stamp = archive.name.removeprefix("compact64_")
    for benchmark, dirname in (("TOPO-BC", f"benchmark_bc_{stamp}"), ("HOTSPOT10", f"benchmark_hotspot10_{stamp}")):
        inside = archive / "figures" / dirname
        outside = REPO / "DATE paper/experiments/figures/paper64" / dirname
        if not inside.is_dir() or not outside.is_dir():
            raise SystemExit(f"existing figure directory missing: {dirname}")
        names = ("bc" if benchmark == "TOPO-BC" else "hotspot10")
        for suffix in ("throughput-load", "pre-saturation-latency-load"):
            for extension in ("png", "pdf"):
                filename = f"{names}-{suffix}.{extension}"
                if (inside / filename).exists() or (outside / filename).exists():
                    raise SystemExit(f"refusing to overwrite {filename}")
        created = plot_benchmark(rows, benchmark, inside, separate_only=True)
        for filename in created:
            shutil.copy2(inside / filename, outside / filename)
    print(f"COMPACT64_SEPARATE_FIGURES_PASS archive={archive}", flush=True)


if __name__ == "__main__":
    main()

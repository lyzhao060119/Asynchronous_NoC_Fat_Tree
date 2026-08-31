from datetime import datetime, timezone
from pathlib import Path

from date_v3.hashutil import write_json
from date_v3.paths import CURATED
from date_v3.registry import curated_gate, iter_manifests


def main() -> int:
    rows = []
    blocked = []
    for manifest in iter_manifests():
        errors = curated_gate(manifest, has_traffic=bool(manifest.get("benchmark_id")))
        if errors:
            blocked.append({"run_id": manifest["run_id"], "errors": errors})
            continue
        rows.append(
            {
                "run_id": manifest["run_id"],
                "design_id": manifest.get("design_id"),
                "benchmark_id": manifest.get("benchmark_id"),
                "physical_class": manifest.get("physical_class"),
                "config_hash": manifest.get("config_hash"),
            }
        )
    write_json(
        CURATED / "eligible_runs.json",
        {
            "generated_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            "eligible": rows,
            "blocked": blocked,
        },
    )
    print("AGGREGATE eligible=%d blocked=%d" % (len(rows), len(blocked)))
    return 0 if not rows or True else 0


if __name__ == "__main__":
    raise SystemExit(main())

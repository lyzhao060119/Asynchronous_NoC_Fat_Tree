from __future__ import annotations

from typing import Any

from .hashutil import load_json, write_json
from .manifest import utc_now
from .paths import PNR_SCRIPTS, REGISTRY, REGISTRY_RUNS
from .schema import validate_file, validate_required

INDEX = REGISTRY / "index.json"


def load_index() -> dict[str, Any]:
    if not INDEX.is_file():
        return {"schema": "date-v3-registry-v1", "updated_utc": utc_now(), "notes": "", "runs": []}
    obj = load_json(INDEX)
    validate_required(obj, label=str(INDEX))
    return obj


def save_index(index: dict[str, Any]) -> None:
    index["updated_utc"] = utc_now()
    validate_required(index, label=str(INDEX))
    write_json(INDEX, index)


def upsert_run(manifest: dict[str, Any]) -> None:
    index = load_index()
    entry = {
        "run_id": manifest["run_id"],
        "design_id": manifest.get("design_id"),
        "benchmark_id": manifest.get("benchmark_id"),
        "status": manifest["status"],
        "paper_eligible": manifest["paper_eligible"],
        "physical_class": manifest["physical_class"],
        "config_hash": manifest.get("config_hash"),
        "manifest": str(REGISTRY_RUNS / ("%s.json" % manifest["run_id"])).replace("\\", "/"),
        "notes": manifest.get("notes", ""),
    }
    runs = [row for row in index["runs"] if row["run_id"] != manifest["run_id"]]
    runs.append(entry)
    runs.sort(key=lambda row: row["run_id"])
    index["runs"] = runs
    save_index(index)


def get_run(run_id: str) -> dict[str, Any] | None:
    path = REGISTRY_RUNS / ("%s.json" % run_id)
    if not path.is_file():
        return None
    return validate_file(path)


def iter_manifests() -> list[dict[str, Any]]:
    if not REGISTRY_RUNS.is_dir():
        return []
    rows = []
    for path in sorted(REGISTRY_RUNS.glob("*.json")):
        rows.append(validate_file(path))
    return rows


def curated_gate(manifest: dict[str, Any], *, has_traffic: bool) -> list[str]:
    errors = []
    if manifest.get("schema") != "date-experiment-run-v1":
        errors.append("missing date-experiment-run-v1 schema")
    if not manifest.get("config_hash"):
        errors.append("missing config_hash")
    if has_traffic and not (manifest.get("case_hash") or manifest.get("trace_hash")):
        errors.append("missing case_hash/trace_hash")
    if not manifest.get("frozen_structure_ok"):
        errors.append("frozen_structure_ok is not true")
    if manifest.get("physical_class") == "archive-only":
        errors.append("archive-only run")
    lock_path = PNR_SCRIPTS / "locked_tool.json"
    if lock_path.is_file():
        lock = load_json(lock_path)
        if (
            lock.get("physical_class") == "post-synthesis"
            and manifest.get("physical_class") == "post-layout"
        ):
            errors.append("post-layout forbidden while P&R lock is post-synthesis")
    if not manifest.get("paper_eligible"):
        errors.append("paper_eligible is false")
    if manifest.get("status") != "pass":
        errors.append("status is not pass")
    return errors

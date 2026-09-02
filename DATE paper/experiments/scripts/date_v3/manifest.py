from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from . import gitmeta
from .hashutil import sha256_json, write_json
from .paths import REGISTRY_RUNS
from .schema import validate_required


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def new_manifest(**fields: Any) -> dict[str, Any]:
    manifest = {
        "schema": "date-experiment-run-v1",
        "run_id": fields.get("run_id"),
        "status": fields.get("status", "planned"),
        "design_id": fields.get("design_id"),
        "benchmark_id": fields.get("benchmark_id"),
        "seed": fields.get("seed"),
        "adapter": fields.get("adapter"),
        "git": fields.get("git") or gitmeta.snapshot(),
        "config_hash": fields.get("config_hash"),
        "case_hash": fields.get("case_hash"),
        "trace_hash": fields.get("trace_hash"),
        "netlist_hash": fields.get("netlist_hash"),
        "sdf_hash": fields.get("sdf_hash"),
        "spef_hash": fields.get("spef_hash"),
        "model_version": fields.get("model_version"),
        "calibration_hash": fields.get("calibration_hash"),
        "tool_versions": fields.get("tool_versions") or {},
        "pvt": fields.get("pvt") or {
            "library": "tcbn28hpcplusbwp12t30p140",
            "corner": "ssg0p81v125c",
            "wireload": "zero" if fields.get("physical_class") == "post-synthesis" else None,
        },
        "command": fields.get("command") or [],
        "env": fields.get("env") or {},
        "lsf_jobs": fields.get("lsf_jobs") or [],
        "frozen_structure_ok": fields.get("frozen_structure_ok"),
        "paper_eligible": bool(fields.get("paper_eligible", False)),
        "physical_class": fields.get("physical_class", "unknown"),
        "archive_only_reason": fields.get("archive_only_reason"),
        "remote_root": fields.get("remote_root", "/home/ghy19/Asynchronous_Router_CMR"),
        "artifacts": fields.get("artifacts") or {},
        "cases": fields.get("cases") or [],
        "created_utc": fields.get("created_utc") or utc_now(),
        "updated_utc": fields.get("updated_utc") or utc_now(),
        "notes": fields.get("notes", ""),
    }
    validate_required(manifest, label=manifest["run_id"] or "manifest")
    return manifest


def manifest_path(run_id: str):
    return REGISTRY_RUNS / ("%s.json" % run_id)


def save_manifest(manifest: dict[str, Any]):
    validate_required(manifest, label=manifest["run_id"])
    write_json(manifest_path(manifest["run_id"]), manifest)
    return manifest_path(manifest["run_id"])


def hashes_match(existing: dict[str, Any], incoming: dict[str, Any]) -> bool:
    keys = ("config_hash", "case_hash", "trace_hash", "netlist_hash")
    for key in keys:
        left = existing.get(key)
        right = incoming.get(key)
        if left and right and left != right:
            return False
    return True


DISPLAY_HASH_EXCLUDES = ("display_name", "display_description")


def config_hash_of(design: dict[str, Any]) -> str:
    payload = {key: value for key, value in design.items() if key not in DISPLAY_HASH_EXCLUDES}
    return sha256_json(payload)

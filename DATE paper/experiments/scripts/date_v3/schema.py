from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .hashutil import load_json
from .paths import SCHEMA

REQUIRED = {
    "date-v3-design-v1": (
        "schema",
        "design_id",
        "kind",
        "family",
        "async",
        "routing",
        "lane_profile",
        "flit_width_bits",
        "buffer_slots",
        "delay_recipe",
        "paper_eligible_default",
    ),
    "date-v3-benchmark-v1": (
        "schema",
        "benchmark_id",
        "packet_flits",
        "warmup_original_events",
        "measurement_original_events",
        "seed_set_id",
        "paired_trace",
        "metrics",
        "paper_figures",
    ),
    "date-v3-seeds-v1": ("schema", "seed_set_id", "frozen", "seeds"),
    "date-experiment-run-v1": (
        "schema",
        "run_id",
        "status",
        "git",
        "config_hash",
        "frozen_structure_ok",
        "paper_eligible",
        "physical_class",
        "created_utc",
    ),
    "date-v3-registry-v1": ("schema", "updated_utc", "runs"),
    "date-v3-plan-v1": ("schema", "plan_id", "runs"),
    "date-v3-canonical-trace-v1": (
        "schema",
        "benchmark_id",
        "nodes",
        "seed",
        "packet_flits",
        "warmup_original_events",
        "measurement_original_events",
        "offered_load",
        "paired_trace",
    ),
    "date-v3-canonical-event-v1": (
        "schema",
        "original_event_id",
        "phase",
        "source",
        "destinations",
        "rect",
        "ready_cycle",
        "packet_flits",
    ),
    "date-v3-snn-trace-v1": (
        "schema",
        "trace_id",
        "source_sha256",
        "provenance",
        "license",
        "network_nodes",
        "endpoint_mapping",
        "preserves_original_multicast",
        "events",
    ),
    "date-v3-des-lock-v1": (
        "schema",
        "model_version",
        "physical_class",
        "calibration_file",
        "calibration_hash",
    ),
}

LOCKED_DELAY = {
    "rcu_steps": 1,
    "rcu_unit_ps": 50,
    "buf_stages": 0,
    "ackin_steps": 1,
    "ackin_unit_ps": 50,
    "ackin_use_buf": False,
}


def validate_required(obj: dict[str, Any], *, label: str) -> None:
    schema = obj.get("schema")
    keys = REQUIRED.get(schema)
    if not keys:
        raise ValueError("%s unknown schema %r" % (label, schema))
    missing = [key for key in keys if key not in obj]
    if missing:
        raise ValueError("%s missing %s" % (label, ", ".join(missing)))


def validate_file(path: Path) -> dict[str, Any]:
    obj = load_json(path)
    if not isinstance(obj, dict):
        raise ValueError("%s is not a JSON object" % path)
    validate_required(obj, label=str(path))
    return obj


def assert_locked_delay(recipe: dict[str, Any], *, label: str) -> None:
    for key, expected in LOCKED_DELAY.items():
        if recipe.get(key) != expected:
            raise ValueError(
                "%s delay recipe %s=%r, locked is %s"
                % (label, key, recipe.get(key), expected)
            )


def schema_path(name: str) -> Path:
    return SCHEMA / name


def load_schema_doc(name: str) -> dict[str, Any]:
    return json.loads(schema_path(name).read_text(encoding="utf-8"))

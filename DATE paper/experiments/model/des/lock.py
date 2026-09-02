"""Lock model_version + calibration_hash.  DC/SDF/DEL drift marks formal DES stale."""

from __future__ import annotations

from typing import Any

from date_v3.hashutil import sha256_file, write_json
from date_v3.manifest import utc_now

from . import CALIBRATION_SEED, MODEL_VERSION, PHYSICAL_CLASS
from .timing import DEFAULT_CALIBRATION, LOCKED_PATH, TimingTable


def build_lock(
    timing: TimingTable | None = None,
    *,
    hop_self_check: str = "pass",
    network_rtl_64: str = "pending",
    network_rtl_256: str = "pending",
    paper_matrix_allowed: bool | None = None,
) -> dict[str, Any]:
    table = timing or TimingTable()
    if paper_matrix_allowed is None:
        paper_matrix_allowed = hop_self_check == "pass" and network_rtl_64 == "pass" and network_rtl_256 == "pass"
    return {
        "schema": "date-v3-des-lock-v1",
        "model_version": MODEL_VERSION,
        "physical_class": PHYSICAL_CLASS,
        "calibration_file": table.path.name,
        "calibration_run_id": table.run_id,
        "calibration_hash": table.file_hash,
        "calibration_seed": CALIBRATION_SEED,
        "hop_self_check": hop_self_check,
        "network_rtl_64": network_rtl_64,
        "network_rtl_256": network_rtl_256,
        "paper_matrix_allowed": bool(paper_matrix_allowed),
        "locked_utc": utc_now(),
        "stale_if": [
            "dc_netlist_change",
            "maximum_sdf_change",
            "locked_delay_recipe_change",
        ],
        "notes": (
            "Hop H/B/T is locked to post-synthesis MAXIMUM-SDF primitives.  "
            "Formal 64/256/1024 DES paper matrix requires paper_matrix_allowed.  "
            "256 rtl_keycase does not use DelayElement_sim Tmax vs post-synth 5%.  "
            "Do not write post-layout.  Do not overwrite frozen hop netlists.  "
            "Do not tune on paper seeds 202701/202702/202703."
            + (
                " network_rtl_64=%s network_rtl_256=%s."
                % (network_rtl_64, network_rtl_256)
            )
        ),
    }


def write_lock(timing: TimingTable | None = None, **kwargs: Any) -> dict[str, Any]:
    lock = build_lock(timing, **kwargs)
    write_json(LOCKED_PATH, lock)
    return lock


def verify_lock(timing: TimingTable | None = None) -> list[str]:
    table = timing or TimingTable()
    errors = []
    if not LOCKED_PATH.is_file():
        return ["missing %s" % LOCKED_PATH]
    from date_v3.hashutil import load_json

    lock = load_json(LOCKED_PATH)
    if lock.get("model_version") != MODEL_VERSION:
        errors.append("model_version %s != %s" % (lock.get("model_version"), MODEL_VERSION))
    if lock.get("physical_class") == "post-layout":
        errors.append("lock claims post-layout")
    if lock.get("physical_class") != PHYSICAL_CLASS:
        errors.append("physical_class %s" % lock.get("physical_class"))
    if lock.get("paper_matrix_allowed") and (
        lock.get("network_rtl_64") != "pass" or lock.get("network_rtl_256") != "pass"
    ):
        errors.append("paper_matrix_allowed without 64/256 network RTL pass")
    if lock.get("calibration_hash") != table.file_hash:
        errors.append(
            "calibration_hash stale: lock=%s file=%s"
            % (lock.get("calibration_hash"), table.file_hash)
        )
    if sha256_file(DEFAULT_CALIBRATION) != table.file_hash and table.path == DEFAULT_CALIBRATION:
        errors.append("hash mismatch on default calibration file")
    return errors

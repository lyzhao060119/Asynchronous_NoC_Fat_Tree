"""Load post-synthesis primitive Head/Body/Tail and energy coefficients."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from . import MODEL_VERSION, PHYSICAL_CLASS
from ._path import MODEL
from date_v3.hashutil import load_json, sha256_file
from date_v3.schema import LOCKED_DELAY, assert_locked_delay

DEFAULT_CALIBRATION = MODEL / "calibration" / "20260901_primitive_ru5_post_synthesis.json"
LOCKED_PATH = MODEL / "calibration" / "locked.json"

# ZeroWireload network stitch: no extra wire delay.  Inter-level FIFO is bypass.
DEFAULT_LINK_NS = 0.0
DEFAULT_CASE_TICK_NS = 20.0
DEFAULT_ACK_GUARD_NS = 0.20
DEFAULT_TX_SETUP_NS = 0.05

# Sync Fat L1 (1,2) was not isolated in Phase 2.5; network clock is 1.0 ns.
SYNC_FALLBACK_NS = 1.0

KIND_GEOM = {
    "async_thin_1x1": (1, 1, False),
    "async_flatmesh_1x1": (1, 1, True),
    "async_fat_1x2": (1, 2, False),
    "async_prop_2x2": (2, 2, False),
    "async_topmesh_2x2": (2, 2, True),
    "async_pfat_2x4": (2, 4, False),
    "async_pfat_4x8": (4, 8, False),
    "sync_thin_1x1": (1, 1, False),
    "sync_prop_2x2": (2, 2, False),
    "sync_fat_1x2": (1, 2, False),
}


def _f(value: Any) -> float:
    return float(value)


class PrimitiveTiming:
    __slots__ = (
        "kind",
        "netlist_run_id",
        "area_um2",
        "head_ns",
        "body_ns",
        "tail_ns",
        "idle_power_w",
        "active_power_w",
        "packet_energy_j",
        "energy_head_j",
        "energy_body_j",
        "energy_tail_j",
        "physical_class",
        "link_ns",
    )

    def __init__(self, row: dict[str, Any], *, link_ns: float = DEFAULT_LINK_NS):
        if row.get("physical_class") == "post-layout":
            raise ValueError("post-layout primitive %s is forbidden" % row.get("kind"))
        self.kind = str(row["kind"])
        self.netlist_run_id = row.get("netlist_run_id")
        self.area_um2 = _f(row.get("total_cell_area_um2") or 0.0)
        self.head_ns = _f(row["head_ns"])
        self.body_ns = _f(row["body_ns"])
        self.tail_ns = _f(row["tail_ns"])
        self.idle_power_w = _f(row.get("idle_power_w") or 0.0)
        self.active_power_w = _f(row.get("active_power_w") or 0.0)
        self.packet_energy_j = _f(row.get("packet_energy_j") or 0.0)
        total_t = self.head_ns + 3.0 * self.body_ns + self.tail_ns
        if total_t <= 0:
            total_t = 5.0
        self.energy_head_j = self.packet_energy_j * (self.head_ns / total_t)
        self.energy_body_j = self.packet_energy_j * (self.body_ns / total_t)
        self.energy_tail_j = self.packet_energy_j * (self.tail_ns / total_t)
        self.physical_class = row.get("physical_class") or PHYSICAL_CLASS
        self.link_ns = link_ns

    def service_ns(self, is_head: bool, is_tail: bool) -> float:
        if is_head:
            return self.head_ns
        if is_tail:
            return self.tail_ns
        return self.body_ns

    def energy_j(self, is_head: bool, is_tail: bool) -> float:
        if is_head:
            return self.energy_head_j
        if is_tail:
            return self.energy_tail_j
        return self.energy_body_j


def _sync_fat_alias(table: dict[str, PrimitiveTiming]) -> PrimitiveTiming:
    """Phase 2.5 did not isolate Sync (1,2).  Clock is 1.0 ns for every hop."""
    thin = table["sync_thin_1x1"]
    prop = table["sync_prop_2x2"]
    row = {
        "kind": "sync_fat_1x2",
        "netlist_run_id": None,
        "total_cell_area_um2": 0.5 * (thin.area_um2 + prop.area_um2),
        "head_ns": SYNC_FALLBACK_NS,
        "body_ns": SYNC_FALLBACK_NS,
        "tail_ns": SYNC_FALLBACK_NS,
        "idle_power_w": 0.5 * (thin.idle_power_w + prop.idle_power_w),
        "active_power_w": 0.5 * (thin.active_power_w + prop.active_power_w),
        "packet_energy_j": 0.5 * (thin.packet_energy_j + prop.packet_energy_j),
        "physical_class": PHYSICAL_CLASS,
    }
    return PrimitiveTiming(row)


class TimingTable:
    def __init__(self, path: Path | None = None, *, link_ns: float = DEFAULT_LINK_NS):
        self.path = Path(path or DEFAULT_CALIBRATION)
        raw = load_json(self.path)
        if raw.get("physical_class") == "post-layout":
            raise ValueError("calibration %s claims post-layout" % self.path)
        self.run_id = raw.get("run_id")
        self.physical_class = raw.get("physical_class") or PHYSICAL_CLASS
        self.file_hash = sha256_file(self.path)
        self.by_kind: dict[str, PrimitiveTiming] = {}
        for row in raw.get("primitives") or []:
            prim = PrimitiveTiming(row, link_ns=link_ns)
            self.by_kind[prim.kind] = prim
        if "sync_thin_1x1" in self.by_kind and "sync_prop_2x2" in self.by_kind:
            self.by_kind.setdefault("sync_fat_1x2", _sync_fat_alias(self.by_kind))
        self.link_ns = link_ns
        self.case_tick_ns = DEFAULT_CASE_TICK_NS
        self.ack_guard_ns = DEFAULT_ACK_GUARD_NS
        self.model_version = MODEL_VERSION

    def require(self, kind: str) -> PrimitiveTiming:
        if kind in self.by_kind:
            return self.by_kind[kind]
        # Mesh1 TopMesh (1,2) has no isolated hop; Phase 10 backup aliases Fat L1.
        if kind == "async_topmesh_1x2" and "async_fat_1x2" in self.by_kind:
            return self.by_kind["async_fat_1x2"]
        raise KeyError("no primitive timing for %s in %s" % (kind, self.path.name))

    def for_geometry(self, child: int, parent: int, mesh: bool, *, async_design: bool) -> PrimitiveTiming:
        for kind, (c, p, m) in KIND_GEOM.items():
            if (c, p, m) != (child, parent, mesh):
                continue
            if async_design and kind.startswith("sync_"):
                continue
            if (not async_design) and kind.startswith("async_"):
                continue
            if kind in self.by_kind:
                return self.by_kind[kind]
        if mesh and (child, parent) == (1, 2) and async_design and "async_fat_1x2" in self.by_kind:
            # No isolated TopMesh1 hop; Mesh1 is Phase 10 backup. Same (1,2) datapath delay.
            return self.by_kind["async_fat_1x2"]
        if not async_design:
            return self.require("sync_prop_2x2" if (child, parent) != (1, 1) else "sync_thin_1x1")
        raise KeyError("no timing for geometry (%s,%s) mesh=%s" % (child, parent, mesh))


def assert_locked_recipe(design: dict[str, Any]) -> None:
    recipe = design.get("delay_recipe") or {}
    assert_locked_delay(recipe, label=design.get("design_id") or "design")
    for key, expected in LOCKED_DELAY.items():
        if recipe.get(key) != expected:
            raise ValueError("delay recipe drift")


def load_locked() -> dict[str, Any] | None:
    if not LOCKED_PATH.is_file():
        return None
    return load_json(LOCKED_PATH)

"""Saturation point for DATE V3 load sweeps.

Not 2x zero-load.  Highest offered load with zero errors on every seed,
drainable after measurement, and no sustained backlog growth.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Any, Iterable

COARSE_LOADS = (0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)
FINE_STEP = 0.01
PLATEAU_REL_EPS = 0.02


def coarse_loads(*, include_zero: bool = True) -> list[float]:
    loads = [0.0] if include_zero else []
    loads.extend(COARSE_LOADS)
    return loads


def hrep_common_tmax_load(hrep_saturation_offered: float) -> float:
    """Fig. C Tmax is read at 0.25 x H-REP saturation offered load for both designs."""
    return 0.25 * float(hrep_saturation_offered)


def _ok(row: dict[str, Any]) -> bool:
    return (
        int(row.get("errors") or 0) == 0
        and bool(row.get("drainable", True))
        and not bool(row.get("backlog_growth", False))
    )


def saturation_point(
    rows: Iterable[dict[str, Any]],
    *,
    seeds: Iterable[int] | None = None,
) -> dict[str, Any] | None:
    by_load: dict[float, list[dict[str, Any]]] = defaultdict(list)
    seed_set = set(seeds) if seeds is not None else None
    for row in rows:
        if seed_set is not None and int(row["seed"]) not in seed_set:
            continue
        by_load[float(row["offered_load"])].append(row)
    if seed_set is None:
        seed_set = {int(row["seed"]) for row in rows}
    passing = []
    for load, group in sorted(by_load.items()):
        present = {int(row["seed"]) for row in group}
        if present != seed_set:
            continue
        if all(_ok(row) for row in group):
            mean_tp = sum(float(row["delivered_throughput"]) for row in group) / len(group)
            mean_lat = sum(float(row["mean_latency"]) for row in group) / len(group)
            passing.append(
                {
                    "offered_load": load,
                    "delivered_throughput": mean_tp,
                    "mean_latency": mean_lat,
                    "seeds": sorted(seed_set),
                }
            )
    if not passing:
        return None
    return passing[-1]


def _group_by_load(
    rows: Iterable[dict[str, Any]],
    seed_set: set[int],
) -> dict[float, list[dict[str, Any]]]:
    by_load: dict[float, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if int(row["seed"]) in seed_set:
            by_load[float(row["offered_load"])].append(row)
    return by_load


def throughput_plateau(
    rows: Iterable[dict[str, Any]],
    *,
    seeds: Iterable[int] | None = None,
    rel_eps: float = PLATEAU_REL_EPS,
) -> bool:
    """True when delivered throughput flattened on the last two passing loads."""
    row_list = list(rows)
    seed_set = set(seeds) if seeds is not None else {int(row["seed"]) for row in row_list}
    by_load = _group_by_load(row_list, seed_set)
    passing_tp: list[float] = []
    for _load, group in sorted(by_load.items()):
        if {int(row["seed"]) for row in group} != seed_set:
            continue
        if not all(_ok(row) for row in group):
            break
        passing_tp.append(sum(float(row["delivered_throughput"]) for row in group) / len(group))
    if len(passing_tp) < 2:
        return False
    prev, last = passing_tp[-2], passing_tp[-1]
    if prev <= 0.0:
        return last <= 0.0
    return (last - prev) / prev < rel_eps


def next_coarse_load(
    measured_loads: Iterable[float],
    *,
    last_ok: bool,
    plateau: bool,
) -> float | None:
    """Next coarse offered load, or None when the sweep should stop for a fine scan."""
    if not last_ok or plateau:
        return None
    measured = [float(load) for load in measured_loads]
    ceiling = max(measured) if measured else -1.0
    for load in coarse_loads(include_zero=True):
        if load > ceiling + 1e-12:
            return load
    return None


def next_fine_loads(
    rows: Iterable[dict[str, Any]],
    *,
    seeds: Iterable[int] | None = None,
    step: float = FINE_STEP,
) -> list[float]:
    """Fine loads on both sides of the saturation knee (not 2x zero-load)."""
    row_list = list(rows)
    sat = saturation_point(row_list, seeds=seeds)
    if sat is None:
        return []
    seed_set = set(seeds) if seeds is not None else {int(row["seed"]) for row in row_list}
    by_load = _group_by_load(row_list, seed_set)
    failing = [
        load
        for load, group in sorted(by_load.items())
        if {int(row["seed"]) for row in group} == seed_set and not all(_ok(row) for row in group)
    ]
    lo = float(sat["offered_load"])
    fail_at = failing[0] if failing else None
    start = round(max(0.0, lo - 2 * step), 6)
    stop = fail_at if fail_at is not None else round(lo + 2 * step, 6)
    measured = {round(load, 6) for load in by_load}
    loads: list[float] = []
    value = start
    while value <= stop + 1e-12:
        rounded = round(value, 6)
        include = rounded > 0.0 and rounded not in measured
        if fail_at is not None and rounded >= fail_at - 1e-12:
            include = False
        if include:
            loads.append(rounded)
        value = round(value + step, 6)
    return loads

"""Paired-design statistics for DATE V3.

Three frozen seeds report mean+/-SD and the per-seed points.  XMC samples
may add a bootstrap 95% CI.  p50/p95/p99 are retained; paper tables pick
the planned metric only.
"""
from __future__ import annotations

from math import sqrt
from random import Random
from typing import Any, Iterable, Sequence


def mean(values: Sequence[float]) -> float | None:
    if not values:
        return None
    return sum(values) / len(values)


def sample_sd(values: Sequence[float]) -> float | None:
    if len(values) < 2:
        return 0.0 if values else None
    avg = mean(values)
    assert avg is not None
    return sqrt(sum((value - avg) ** 2 for value in values) / (len(values) - 1))


def percentile(values: Sequence[float], p: float) -> float | None:
    ordered = sorted(values)
    if not ordered:
        return None
    idx = min(len(ordered) - 1, max(0, int(round(p * (len(ordered) - 1)))))
    return ordered[idx]


def seed_summary(
    rows: Iterable[dict[str, Any]],
    *,
    value_key: str,
    seeds: Sequence[int],
) -> dict[str, Any]:
    by_seed: dict[int, float] = {}
    for row in rows:
        by_seed[int(row["seed"])] = float(row[value_key])
    missing = [seed for seed in seeds if seed not in by_seed]
    if missing:
        raise ValueError("missing seeds %s for %s" % (missing, value_key))
    values = [by_seed[seed] for seed in seeds]
    return {
        "seeds": list(seeds),
        "per_seed": {str(seed): by_seed[seed] for seed in seeds},
        "mean": mean(values),
        "sd": sample_sd(values),
        "p50": percentile(values, 0.50),
        "p95": percentile(values, 0.95),
        "p99": percentile(values, 0.99),
        "count": len(values),
    }


def bootstrap_ci(
    values: Sequence[float],
    *,
    n_boot: int = 2000,
    alpha: float = 0.05,
    seed: int = 0,
) -> dict[str, float | None]:
    if not values:
        return {"mean": None, "low": None, "high": None, "n": 0, "n_boot": n_boot}
    rng = Random(seed)
    samples = []
    n = len(values)
    for _ in range(n_boot):
        draw = [values[rng.randrange(n)] for _ in range(n)]
        samples.append(sum(draw) / n)
    samples.sort()
    lo = samples[min(n_boot - 1, max(0, int(round((alpha / 2) * (n_boot - 1)))))]
    hi = samples[min(n_boot - 1, max(0, int(round((1.0 - alpha / 2) * (n_boot - 1)))))]
    return {
        "mean": sum(values) / n,
        "low": lo,
        "high": hi,
        "n": n,
        "n_boot": n_boot,
        "alpha": alpha,
    }

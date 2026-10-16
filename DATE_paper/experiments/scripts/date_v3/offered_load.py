"""DATE V3 offered load: MFlit per injection port per second.

Paper coarse points are 100, 300, 500, 700, 900 MFlit/Port/s (plus zero).
CMR/TaBuLA continuous-time injection: packet-header inter-arrivals are
exponential with

    lambda_pkt = offered_MFlit_per_port_s / packet_flits / 1e3   (packets/ns)

so 100 MFlit/Port/s at 5 flits is 0.02 packets/ns (mean 50 ns).  Body/tail
flits share the header's offer cycle (ASAP); DUT backpressure paces wire
service.  A later packet on that source may be scheduled on the next tick.
packet_start_probability() is the discrete Bernoulli counterpart
(0.02 at 100 MFlit) and is not the scheduler.

With CASE_TICK_NS = 1.0 the 1-flit/tick ceiling is 1000 MFlit/Port/s.
Historical dimensionless offered_load (0.10 at a 20 ns tick) was 5
MFlit/Port/s and must not be relabeled as 100.
"""
from __future__ import annotations

from typing import Any

CASE_TICK_NS = 1.0
LOAD_UNIT = "MFlit_per_port_s"
COARSE_LOADS = (100.0, 300.0, 500.0, 700.0, 900.0)
DEFAULT_LOAD = 100.0
SMOKE_LOAD = 100.0
FINE_STEP = 25.0

GATE_B_MEDIUM_LOAD = 100.0
GATE_B_NEAR_SAT_LOAD = 300.0
GATE_B_RETRY_LOAD = 200.0
GATE_CD_LOW_LOAD = 100.0
GATE_CD_MEDIUM_LOAD = 200.0
GATE_CD_NEAR_SAT_LOAD = 400.0
GATE_CD_MC_LOAD = 200.0

# Keep zero-load / XMC wall-clock gaps (~5.12 µs / ~1.28 µs) after the tick shrinks.
HISTORIC_CASE_TICK_NS = 20.0
HISTORIC_ZERO_LOAD_GAP_TICKS = 256
HISTORIC_XMC_GAP_TICKS = 64
ZERO_LOAD_GAP = int(round(HISTORIC_ZERO_LOAD_GAP_TICKS * HISTORIC_CASE_TICK_NS / CASE_TICK_NS))
XMC_GAP = int(round(HISTORIC_XMC_GAP_TICKS * HISTORIC_CASE_TICK_NS / CASE_TICK_NS))

LINE_RATE_MFLIT = 1000.0 / CASE_TICK_NS


def load_tag(load_point: float) -> str:
    if load_point <= 0.0:
        return "zero"
    return "m%d" % int(round(load_point))


def load_tag_int(load_point: float) -> int:
    return int(round(load_point))


def parse_load_tag(tag: str) -> float:
    if tag == "zero":
        return 0.0
    if tag.startswith("m") and tag[1:].isdigit():
        return float(int(tag[1:]))
    if tag.startswith("r") and "p" in tag:
        whole, _, frac = tag[1:].partition("p")
        if whole.isdigit() and frac.isdigit():
            return float(int(whole)) + int(frac) / 100.0
    raise ValueError("bad load tag %s" % tag)


def assert_offered_mflit(load_point: float) -> float:
    value = float(load_point)
    if value < 0.0:
        raise ValueError("offered_load must be >= 0 MFlit/Port/s, got %s" % value)
    if 0.0 < value < 1.0:
        raise ValueError(
            "offered_load is MFlit/Port/s (100, 200, 300, ...); got %s "
            "(legacy flit/cycle/node values are not accepted)" % value
        )
    if value > LINE_RATE_MFLIT + 1e-12:
        raise ValueError(
            "offered_load %s MFlit/Port/s exceeds the 1-flit/tick ceiling %s"
            % (value, LINE_RATE_MFLIT)
        )
    return value


def flits_per_case_tick(offered_mflit_per_port_s: float) -> float:
    return float(offered_mflit_per_port_s) * CASE_TICK_NS * 1e-3


def packet_start_probability(offered_mflit_per_port_s: float, packet_flits: int) -> float:
    """Discrete Bernoulli analog of header_rate_per_ns; not used by schedule_pairs."""
    offered = assert_offered_mflit(offered_mflit_per_port_s)
    start_prob = flits_per_case_tick(offered) / float(packet_flits)
    if not (0.0 < start_prob <= 1.0):
        raise ValueError(
            "bad packet-start probability %s (offered %s MFlit/Port/s, tick %s ns)"
            % (start_prob, offered, CASE_TICK_NS)
        )
    return start_prob


def header_rate_per_ns(offered_mflit_per_port_s: float, packet_flits: int) -> float:
    """Poisson packet-header rate in packets/ns (CMR continuous-time injection)."""
    offered = assert_offered_mflit(offered_mflit_per_port_s)
    if packet_flits < 1:
        raise ValueError("packet_flits must be positive")
    rate = offered / float(packet_flits) / 1e3
    if rate <= 0.0:
        raise ValueError("header rate must be positive, got %s" % rate)
    return rate


def trace_load_fields(load_point: float) -> dict[str, Any]:
    offered = 0.0 if load_point <= 0.0 else assert_offered_mflit(load_point)
    return {
        "offered_load": offered,
        "load_tag": load_tag(offered),
        "load_unit": LOAD_UNIT,
        "case_tick_ns": CASE_TICK_NS,
    }

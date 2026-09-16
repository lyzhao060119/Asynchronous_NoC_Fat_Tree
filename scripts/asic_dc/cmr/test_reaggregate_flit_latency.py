from __future__ import annotations

import csv
from pathlib import Path

import pytest

from reaggregate_flit_latency import reaggregate


def write_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def test_drain_after_window_remains_in_measurement_cohort(tmp_path: Path) -> None:
    latency = tmp_path / "latency.csv"
    flits = tmp_path / "flit_latency.csv"
    write_csv(latency, ["pkt_seq", "original_event_id"], [
        {"pkt_seq": 10, "original_event_id": 0},
        {"pkt_seq": 11, "original_event_id": 1},
        {"pkt_seq": 12, "original_event_id": 2},
    ])
    # Packet 11 is deliberately the slow, post-window completion.  Selection
    # is by original event, so its 100 ns latency must not be censored.
    write_csv(flits, ["pkt_seq", "lat_ns"], [
        {"pkt_seq": 10, "lat_ns": 1.0},
        {"pkt_seq": 11, "lat_ns": 100.0},
        {"pkt_seq": 12, "lat_ns": 2.0},
    ])
    result = reaggregate(latency, flits, warmup_events=1,
                         measurement_events=1, packet_flits=1)
    assert result["measurement_flits"] == 1
    assert result["flit_latency_mean_ns"] == 100.0
    assert result["flit_latency_p99_ns"] == 100.0


def test_rejects_incomplete_measurement_cohort(tmp_path: Path) -> None:
    latency = tmp_path / "latency.csv"
    flits = tmp_path / "flit_latency.csv"
    write_csv(latency, ["pkt_seq", "original_event_id"], [
        {"pkt_seq": 1, "original_event_id": 0},
    ])
    write_csv(flits, ["pkt_seq", "lat_ns"], [])
    with pytest.raises(ValueError, match="expected 1"):
        reaggregate(latency, flits, warmup_events=0,
                    measurement_events=1, packet_flits=1)

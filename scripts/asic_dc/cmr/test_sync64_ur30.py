from __future__ import annotations

import csv

from run_sync64_ur30 import measurement_window_metrics


def write(path, fields, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader(); writer.writerows(rows)


def test_measurement_window_separates_source_and_network_backlog(tmp_path):
    latency = tmp_path / "latency.csv"
    events = tmp_path / "events.csv"
    packets = list(range(10000))
    write(latency, ["pkt_seq", "original_event_id"],
          [{"pkt_seq": packet, "original_event_id": packet + 1000} for packet in packets])
    rows = []
    for packet in packets:
        offer = packet * 10
        for flit in range(5):
            # Last offered packet has one source-queued flit at measurement end.
            req = offer + (1 if packet == 9999 and flit == 4 else 0)
            # One injected flit remains inside the network at measurement end.
            egress = offer + (1 if packet == 9999 and flit >= 3 else 0)
            rows.append({"kind": "TX", "port": 0, "pkt_seq": packet, "flit": flit,
                         "offer_ps": offer, "req_ps": req, "ack_ps": req,
                         "egress_req_ps": -1, "capture_ps": -1, "matched": 1})
            rows.append({"kind": "RX", "port": 0, "pkt_seq": packet, "flit": flit,
                         "offer_ps": -1, "req_ps": -1, "ack_ps": -1,
                         "egress_req_ps": egress, "capture_ps": egress, "matched": 1})
    write(events, ["kind", "port", "pkt_seq", "flit", "offer_ps", "req_ps", "ack_ps",
                   "egress_req_ps", "capture_ps", "matched"], rows)
    result = measurement_window_metrics(latency, events)
    assert result["measurement_source_backlog_flits"] == 1
    assert result["measurement_network_inflight_flits"] == 1
    assert result["measurement_total_backlog_flits"] == 2
    assert result["measurement_delivered_flits"] == 49998

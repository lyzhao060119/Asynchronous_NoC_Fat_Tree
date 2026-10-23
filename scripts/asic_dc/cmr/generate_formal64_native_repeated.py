#!/usr/bin/env python3
"""Derive the six frozen M16-64 repeated-unicast cases from native traces."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from collections import defaultdict
from pathlib import Path


SEEDS = (202701, 202702, 202703)
POINTS = (("MULTICAST10-AABB", 20), ("ALL-MULTICAST-AABB", 10))
WARMUP_EVENTS = 100
MEASUREMENT_EVENTS = 1000


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def destinations_by_event(packets: list[dict]) -> dict[str, set[int]]:
    result: dict[str, set[int]] = defaultdict(set)
    for packet in packets:
        result[str(packet["original_event_id"])].update(
            int(dest) for dest in packet["delivered_destinations"]
        )
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--package-root", type=Path)
    args = parser.parse_args()

    campaign = args.campaign_root.resolve()
    output = args.output_root.resolve()
    package_root = ((args.package_root.resolve() if args.package_root else None)
                    or campaign / "experiments" / "scripts")
    if not package_root.is_dir():
        raise SystemExit(f"missing DATE V3 package: {package_root}")
    sys.path.insert(0, str(package_root))
    from date_v3.canonical_trace import dump_jsonl, load_jsonl  # noqa: E402
    from date_v3.materialize_case import materialize, materialize_path  # noqa: E402

    cases = output / "cases"
    traces = output / "traces"
    cases.mkdir(parents=True, exist_ok=True)
    traces.mkdir(parents=True, exist_ok=True)
    rows: list[dict] = []
    for benchmark, load in POINTS:
        for seed in SEEDS:
            stem = f"{benchmark}_n64_s{seed}_m{load}"
            trace_path = campaign / "traces" / f"{stem}.jsonl"
            native_path = campaign / "cases" / f"{stem}_PROP_temp64_m16_top64.case"
            if not trace_path.is_file() or not native_path.is_file():
                raise RuntimeError(f"missing frozen input for {stem}")

            full_trace = load_jsonl(trace_path)
            warmup = [event for event in full_trace["events"] if event["phase"] == "warmup"][:WARMUP_EVENTS]
            measurement = [event for event in full_trace["events"] if event["phase"] == "measurement"][:MEASUREMENT_EVENTS]
            if len(warmup) != WARMUP_EVENTS or len(measurement) != MEASUREMENT_EVENTS:
                raise RuntimeError(f"insufficient frozen events for {stem}")
            selected = warmup + measurement
            for event_index, event in enumerate(selected):
                event["event_index"] = event_index
                event["phase"] = "warmup" if event_index < WARMUP_EVENTS else "measurement"
            header = dict(full_trace["header"])
            header["warmup_original_events"] = WARMUP_EVENTS
            header["measurement_original_events"] = MEASUREMENT_EVENTS
            header["trace_id"] = stem + "_compact1100"
            trace = {"header": header, "events": selected}
            compact_trace = traces / f"{stem}_compact1100.jsonl"
            dump_jsonl(trace, compact_trace)
            trace = load_jsonl(compact_trace)
            native = materialize(trace, top_lanes=64, routing="quadtree")
            repeated = materialize(
                trace,
                top_lanes=64,
                source_repeated_unicast=True,
                routing="quadtree",
            )
            if len(repeated["packets"]) >= (1 << 14):
                raise RuntimeError(f"legacy packet tag overflow for {stem}: {len(repeated['packets'])}")
            expected = {
                str(event["original_event_id"]): set(map(int, event["destinations"]))
                for event in trace["events"]
            }
            native_destinations = destinations_by_event(native["packets"])
            repeated_destinations = destinations_by_event(repeated["packets"])
            if native_destinations != expected or repeated_destinations != expected:
                raise RuntimeError(f"destination-set audit failed for {stem}")
            if len(repeated_destinations) != len(trace["events"]):
                raise RuntimeError(f"event coverage audit failed for {stem}")

            for mode, source_repeated, materialized in (
                ("NATIVE", False, native), ("REPEATED", True, repeated)
            ):
                case_path = materialize_path(
                    compact_trace, cases, top_lanes=64,
                    source_repeated_unicast=source_repeated,
                    routing="quadtree", sidecars=True,
                )
                packet_count = len(materialized["packets"])
                rows.append({
                    "benchmark": benchmark,
                    "load_mflit_port_s": load,
                    "seed": seed,
                    "mode": mode,
                    "trace": str(compact_trace),
                    "trace_sha256": sha256(compact_trace),
                    "full_trace": str(trace_path),
                    "full_trace_sha256": sha256(trace_path),
                    "native_case": str(native_path),
                    "native_case_sha256": sha256(native_path),
                    "case": str(case_path),
                    "case_sha256": sha256(case_path),
                    "packets_sidecar_sha256": sha256(case_path.with_suffix(".packets.json")),
                    "model_sidecar_sha256": sha256(case_path.with_suffix(".model.json")),
                    "original_events": len(trace["events"]),
                    "repeated_packets": packet_count,
                    "injected_flits": packet_count * 5,
                    "destination_copies": sum(len(value) for value in expected.values()),
                    "destination_audit": "PASS",
                })

    manifest_csv = output / "case_manifest.csv"
    with manifest_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    manifest = {
        "schema": "formal64-native-repeated-input-v1",
        "campaign_root": str(campaign),
        "points": [{"benchmark": b, "load": load} for b, load in POINTS],
        "seeds": list(SEEDS),
        "case_count": len(rows),
        "warmup_original_events": WARMUP_EVENTS,
        "measurement_original_events": MEASUREMENT_EVENTS,
        "packet_flits": 5,
        "source_queue_included_in_latency": True,
        "event_destination_equivalence": "PASS",
        "generator_sha256": sha256(Path(__file__)),
        "case_manifest_sha256": sha256(manifest_csv),
    }
    (output / "input_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    if len(rows) != 12:
        raise RuntimeError(f"expected 12 cases, got {len(rows)}")
    print("FORMAL64_NATIVE_REPEATED_GENERATION_PASS cases=12 destination_audit=PASS")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Validate a V3.2 optional SNN trace before it can be replayed.

This program does not generate traffic, submit jobs, or permit curation.  It
only accepts a frozen trace whose original one-to-many communication semantics
remain intact.  --require-gate-f additionally refuses validation until the
required 64→256→1024 gate-level sequence is green.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.hashutil import sha256_file  # noqa: E402
from date_v3.paths import EXPERIMENTS, REPO  # noqa: E402


def _fail(message: str) -> None:
    raise ValueError(message)


def _sha256_mapping(mapping: dict[str, Any]) -> str:
    payload = json.dumps(mapping, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def validate_trace(path: Path) -> dict[str, Any]:
    if not path.is_file():
        _fail("trace file does not exist: %s" % path)
    obj = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(obj, dict):
        _fail("trace must be a JSON object")
    required = (
        "schema",
        "trace_id",
        "source_sha256",
        "provenance",
        "license",
        "network_nodes",
        "endpoint_mapping",
        "preserves_original_multicast",
        "events",
    )
    missing = [field for field in required if field not in obj]
    if missing:
        _fail("trace missing " + ", ".join(missing))
    if obj["schema"] != "date-v3-snn-trace-v1":
        _fail("unexpected trace schema %r" % obj["schema"])
    if obj["network_nodes"] != 1024:
        _fail("trace must map to exactly 1024 network nodes")
    if obj["preserves_original_multicast"] is not True:
        _fail("one spike must remain one multicast injection")
    if not isinstance(obj["source_sha256"], str) or len(obj["source_sha256"]) != 64:
        _fail("source_sha256 must be a SHA-256 hex digest")
    mapping = obj["endpoint_mapping"]
    if not isinstance(mapping, dict):
        _fail("endpoint_mapping must be an object")
    for field in ("mapping_id", "mapping_sha256", "logical_to_network_node"):
        if field not in mapping:
            _fail("endpoint_mapping missing %s" % field)
    endpoints = mapping["logical_to_network_node"]
    if not isinstance(endpoints, dict) or not endpoints:
        _fail("logical_to_network_node must be a nonempty object")
    if mapping["mapping_sha256"] != _sha256_mapping(endpoints):
        _fail("endpoint mapping hash does not match logical_to_network_node")

    event_ids: set[int] = set()
    prior_order = -1
    multicast_events = 0
    for index, event in enumerate(obj["events"]):
        if not isinstance(event, dict):
            _fail("event %d is not an object" % index)
        for field in ("event_id", "order", "source", "destinations", "packet_flits"):
            if field not in event:
                _fail("event %d missing %s" % (index, field))
        if event["event_id"] in event_ids:
            _fail("duplicate event_id %r" % event["event_id"])
        event_ids.add(event["event_id"])
        if not isinstance(event["order"], int) or event["order"] < prior_order:
            _fail("events must have nondecreasing integer order")
        prior_order = event["order"]
        if event["packet_flits"] != 5:
            _fail("event %d is not a five-flit packet" % index)
        destinations = event["destinations"]
        if not isinstance(destinations, list) or not destinations:
            _fail("event %d has no destinations" % index)
        if len(destinations) != len(set(destinations)):
            _fail("event %d repeats a destination" % index)
        for endpoint in [event["source"], *destinations]:
            if not isinstance(endpoint, str) or not endpoint:
                _fail("event %d has an invalid logical endpoint" % index)
            if endpoint not in endpoints:
                _fail("event %d logical endpoint is not mapped: %s" % (index, endpoint))
            node = endpoints[endpoint]
            if not isinstance(node, int) or node < 0 or node >= 1024:
                _fail("event %d maps outside 0..1023: %s" % (index, endpoint))
        if len(destinations) > 1:
            multicast_events += 1
    if multicast_events == 0:
        _fail("trace has no multicast event and cannot test native multicast")
    obj["_file_sha256"] = sha256_file(path)
    obj["_multicast_events"] = multicast_events
    return obj


def require_gate_f() -> None:
    completed = subprocess.run(
        [sys.executable, str(SCRIPTS / "check_v31_gates.py"), "--gate", "F"],
        cwd=REPO,
        check=False,
    )
    if completed.returncode != 0:
        raise SystemExit(
            "TRACE_REPLAY_BLOCKED: Gate F is not green. "
            "Do not run optional SNN replay before required 1024-node evidence."
        )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate optional V3.2 SNN trace")
    parser.add_argument("trace", type=Path)
    parser.add_argument("--require-gate-f", action="store_true")
    args = parser.parse_args()
    try:
        trace = validate_trace(args.trace)
    except (ValueError, json.JSONDecodeError) as exc:
        print("SNN_TRACE_FAIL", exc, flush=True)
        return 1
    if args.require_gate_f:
        require_gate_f()
    print(
        "SNN_TRACE_PASS trace_id=%s events=%d multicast_events=%d sha256=%s"
        % (
            trace["trace_id"],
            len(trace["events"]),
            trace["_multicast_events"],
            trace["_file_sha256"],
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Run hierarchical DC/GLS for the frozen CMR_v1 PFAT64 archive.

The archive is emitted in an isolated build directory.  This launcher only
replaces the DUT and hand-written asynchronous RTL inputs; technology, DC,
GLS and testbench infrastructure continue to come from the live repository.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
ARCHIVE = REPO / "archive" / "NoC_v1_20260921"
GENERATED = REPO / "outputs" / "archive_pfat64_build_20261014" / "generated_cmr" / "fat_tree_noc64_1248"
RTL = GENERATED / "NoC_64nodes.v"
OPM_SELECTOR_OVERRIDE = os.environ.get("CMR_ARCHIVE_OPM_SELECTOR_OVERRIDE", "").strip()


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def _validate() -> None:
    if not RTL.is_file() or RTL.stat().st_size == 0:
        raise SystemExit("missing isolated archive PFAT64 RTL: " + str(RTL))
    text = RTL.read_text(encoding="utf-8")
    checks = {
        "routers": len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+routers?L", text, re.M)),
        "ipm_instances": len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M)),
        "adapters": len(re.findall(r"LanePhaseAdapterDFF\s*#", text)),
        "top_lanes": len(set(re.findall(r"io_top_input_(\d+)_", text))),
    }
    expected = {"routers": 21, "ipm_instances": 168, "adapters": 352, "top_lanes": 8}
    if checks != expected:
        raise SystemExit("archive PFAT64 structure mismatch: %r != %r" % (checks, expected))
    required = (
        "DelayElement #(.DelayUnitPs(150), .DelayValue(1)) AckoutGuard",
        "DelayElement #(.DelayUnitPs(150), .DelayValue(1)) BundlingSignal_MatchedDelay",
        "DelayElement #(.DelayUnitPs(50), .DelayValue(1)) AckinDelay",
    )
    missing = [item for item in required if item not in text]
    if missing:
        raise SystemExit("archive PFAT64 delay recipe mismatch: " + ", ".join(missing))
    if " OPMDelay" in text or "OPMReqoutBuffer_" in text:
        raise SystemExit("archive PFAT64 unexpectedly contains current OPM output protection")

    sources = sorted((ARCHIVE / "src").rglob("*.scala")) + sorted((ARCHIVE / "src").rglob("*.v"))
    manifest = {
        "archive": str(ARCHIVE.relative_to(REPO)).replace("\\", "/"),
        "generated_rtl": str(RTL.relative_to(REPO)).replace("\\", "/"),
        "generated_rtl_sha256": _sha(RTL),
        "structure": checks,
        "source_sha256": {
            str(path.relative_to(ARCHIVE)).replace("\\", "/"): _sha(path) for path in sources
        },
    }
    out = GENERATED / "archive_input_manifest.json"
    out.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("ARCHIVE_PFAT64_INPUT_PASS", checks, _sha(RTL), flush=True)


def _archive_inputs(original: dict[Path, str]) -> dict[Path, str]:
    live_async = REPO / "src" / "main" / "resources" / "ASYNC"
    archived_async = ARCHIVE / "src" / "main" / "resources" / "ASYNC"
    result: dict[Path, str] = {}
    for source, destination in original.items():
        try:
            relative = source.relative_to(live_async)
        except ValueError:
            result[source] = destination
            continue
        archived = archived_async / relative
        if relative.as_posix() == "CMR/OPMSelector.v" and OPM_SELECTOR_OVERRIDE:
            archived = Path(OPM_SELECTOR_OVERRIDE).resolve()
            if not archived.is_relative_to(REPO):
                raise SystemExit("OPM selector override must remain inside repository")
        if not archived.is_file():
            raise SystemExit("archive is missing required async RTL: " + str(archived))
        result[archived] = destination
    return result


def main() -> None:
    os.environ.setdefault("CMR_HIER_KIND", "1248")
    os.environ.setdefault("CMR_LIBRARY_CORNER", "tt0p8v25c")
    os.environ.setdefault("CMR_RCU_MATCHED_DELAY_STEPS", "1")
    os.environ.setdefault("CMR_RCU_MATCHED_DELAY_UNIT_PS", "150")
    os.environ.setdefault("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
    # The frozen archive predates Reqout DEL/buffer parameters.
    os.environ.setdefault("CMR_OPM_REQOUT_DELAY_STEPS", "0")
    os.environ.setdefault("CMR_OPM_REQOUT_BUFFER_STAGES", "0")
    os.environ.setdefault("CMR_IPM_ACKOUT_GUARD_DELAY_UNIT_PS", "150")
    os.environ.setdefault("CMR_PATH_STATE_IMPL", "srlatch")

    _validate()

    import run_remote_cmr_noc64_sdf as noc64

    original_inputs = noc64.shared_input_files
    noc64.generate_rtl = lambda profile: GENERATED
    noc64.shared_input_files = lambda: _archive_inputs(original_inputs())

    import run_remote_cmr_hier_dc as hierarchical

    hierarchical.main()


if __name__ == "__main__":
    main()

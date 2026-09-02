#!/usr/bin/env python3
"""Emit and structurally check V3.1.0 whole-network Verilog."""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

from check_cmr_router_geometry import check_noc64
from cmr_frozen_run_ids import require_emit_locked_delays
from hier_noc import unique_router_jobs
from run_remote_cmr_fat_tree_noc16_sdf import CIRCULAR_RTL

REPO = Path(__file__).resolve().parents[3]
EXPERIMENT_SCRIPTS = REPO / "DATE paper" / "experiments" / "scripts"
if str(EXPERIMENT_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(EXPERIMENT_SCRIPTS))

from date_v3.display_names import display_name  # noqa: E402
from date_v3.network_matrix import is_unsupported, matrix_row, netlist_owner  # noqa: E402


def sbt_cmd(main: str, extra: str) -> list[str]:
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    body = "runMain %s" % main
    if extra.strip():
        body = "runMain %s %s" % (main, extra.strip())
    return [sbt, body]


def check_generated(design_id: str, generated: Path) -> Path:
    row = matrix_row(design_id)
    emit = row["emit"]
    rtl = generated / emit["dut_file"]
    if not rtl.is_file():
        raise SystemExit("missing emitted DUT %s" % rtl)
    text = rtl.read_text(encoding="utf-8")
    if ("module %s" % emit["top"]) not in text:
        raise SystemExit("generated DUT is not named %s" % emit["top"])
    owner = netlist_owner(design_id)
    if owner in ("THIN64", "PROP64", "PFAT64", "FM64"):
        require_emit_locked_delays(text, label=design_id, ackin_unit_ps=50)
        check_noc64(generated, generated.name)
    else:
        require_emit_locked_delays(text, label=design_id, ackin_unit_ps=50)
    router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+\w+", text, re.M))
    ipm_count = len(re.findall(r"^\s+IPM(?:_\d+)?\s+InputPortModules_\d+", text, re.M))
    adapter_count = len(re.findall(r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*\d+\s*\)", text))
    expected = row["expected"]
    if expected.get("routers") and router_count != expected["routers"]:
        raise SystemExit(
            "%s router count %d != %s" % (design_id, router_count, expected["routers"])
        )
    if expected.get("ports") and ipm_count != expected["ports"]:
        raise SystemExit("%s IPM count %d != %s" % (design_id, ipm_count, expected["ports"]))
    if expected.get("adapters") is not None and adapter_count != expected["adapters"]:
        raise SystemExit(
            "%s adapter count %d != %s" % (design_id, adapter_count, expected["adapters"])
        )
    jobs = unique_router_jobs(text)
    print(
        "LOCAL_EMIT %s routers=%d ipm=%d adapters=%d unique_refs=%d"
        % (display_name(design_id), router_count, ipm_count, adapter_count, len(jobs)),
        flush=True,
    )
    return generated


def generate_network_rtl(design_id: str) -> Path:
    if is_unsupported(design_id):
        raise SystemExit(
            "refusing unsupported design %s: %s"
            % (display_name(design_id), matrix_row(design_id)["unsupported_reason"])
        )
    owner = netlist_owner(design_id)
    row = matrix_row(owner)
    emit = row["emit"]
    generated = REPO / emit["gen_dir"]
    rtl = generated / emit["dut_file"]
    force_emit = os.environ.get("CMR_FORCE_EMIT", "0") == "1"
    if rtl.is_file() and not force_emit:
        try:
            return check_generated(owner, generated)
        except SystemExit as exc:
            print("LOCAL_EMIT_RECHECK", exc, flush=True)
    env = os.environ.copy()
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_FORCE_EMIT"] = "1"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = "1"
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = "50"
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = "50"
    env["CMR_BYPASS_INTERLEVEL_FIFO"] = "1"
    for key, value in (emit.get("env") or {}).items():
        env[key] = str(value)
    cmd = sbt_cmd(emit["main"], emit.get("sbt_args") or "")
    print("NETWORK_EMIT", display_name(owner), cmd[-1], flush=True)
    subprocess.run(cmd, cwd=REPO, env=env, check=True)
    return check_generated(owner, generated)


def asic_input_files(design_id: str) -> dict[Path, str]:
    owner = netlist_owner(design_id)
    row = matrix_row(owner)
    emit = row["emit"]
    cmr_resource = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
    async_resource = REPO / "src" / "main" / "resources" / "ASYNC"
    files: dict[Path, str] = {}
    for name in (
        "DelayElement_ASIC.v",
        "Mutex2_ASIC.v",
        "Mutex4.v",
        "MullerC2.v",
        "DLatchBank.v",
        "V2CloseEvent.v",
    ):
        files[async_resource / name] = "rtl/" + name
    for name in (
        "CMRMutexN.v",
        "CMRFlattenedTAC.v",
        "Toggle.v",
        "HeadPredictor.v",
        "PhaseSelector.v",
        "AddressRegisterUnit.v",
        "InternalAckModule.v",
        "RouteSelAnd2.v",
        "OPMSelector.v",
        "PhaseResetDLatch.v",
        "LanePhaseAdapter.v",
        "WriteControlUnit.v",
        "WriteCounter.v",
        "WriteAckGenerator.v",
        "ReadControlUnit.v",
        "ReadCounter.v",
        "ReadRequestGenerator.v",
        "ReadPhaseSelector.v",
        "ReadAckGenerator.v",
        "WriteControlBlock.v",
        "ReadControlBlock.v",
    ) + tuple(CIRCULAR_RTL):
        candidate = cmr_resource / name
        if candidate.is_file():
            files[candidate] = "rtl/" + name
    files.update(
        {
            REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
            REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
            REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
            REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_child.tcl": "scripts/dc/run_dc_cmr_hier_child.tcl",
            REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_stitch.tcl": "scripts/dc/run_dc_cmr_hier_stitch.tcl",
            REPO / "scripts/asic_dc/cmr/run_gls_cmr_network.sh": "scripts/run_gls_cmr_network.sh",
            REPO / "sim/AsyncNoC/async_noc_scale_port_adapter.sv": "sim/tb/async_noc_scale_port_adapter.sv",
            REPO / "sim/AsyncNoC/testbench/tb_noc_async_keycase.sv": "sim/tb/tb_noc_async_keycase.sv",
        }
    )
    generated = generate_network_rtl(owner)
    remote_dir = "rtl/network_%s" % owner.lower()
    files[generated / emit["dut_file"]] = remote_dir + "/" + emit["dut_file"]
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing network input files: " + ", ".join(missing))
    return files

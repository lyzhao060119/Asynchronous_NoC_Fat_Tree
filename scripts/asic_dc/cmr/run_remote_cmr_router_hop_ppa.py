#!/usr/bin/env python3
"""Measure frozen CMR router single-hop PPA without running DC.

Thin L1/L2/L3 are (1,1).  Fat L1 is (1,2); Fat L2/L3 for the 1222 tree are
(2,2).  Each kind's run ID must already contain CMRRouter.ddc,
CMRRouter_post.v, CMRRouter.sdf, CMRRouter.sdc, and the synthesis reports.
Do not set CMR_HOP_PPA_RUN_ID to 20260830_cmr_router_level_baseline_del050
or a *_hop_del050_ackin050 netlist; those folders are frozen.
"""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import shlex
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from run_remote_cmr_flow import atomic_put, fetch_tree, job_id, remote_run, wait_job
from run_remote_cmr_noc16_sdf import connect
from cmr_frozen_run_ids import (
    NOT_FAT_VS_THIN_DELAY,
    refuse_overwrite,
    require_locked_delay_structure,
)
from cmr_primitive_geometries import DEFAULT_HOP_KINDS, HOP_PPA_RUN_ID, lookup


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_HOP_PPA_RUN_ID",
    HOP_PPA_RUN_ID,
)
RESULT_DIR = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID
HOP_MODES = [
    name.strip()
    for name in os.environ.get("CMR_HOP_MODES", "isolated,stream,idle,contention").split(",")
    if name.strip()
]


def kind_config(kind: str) -> dict:
    geom = lookup(kind)
    return {
        "ports": geom["ports"],
        "adapters": geom["adapters"],
        "selectors": geom["selectors"],
        "async": geom["async"],
        "mesh": geom["mesh"],
        "dut": geom["dut"],
        "netlist_envs": geom["netlist_envs"],
        "rx_default": geom["rx_default"],
        "dc_id": geom["dc_id"],
        "kind": geom["kind"],
    }


def rx_for(kind: str) -> str:
    env_name = "CMR_%s_RX_CAPTURE_NS" % kind.upper()
    return os.environ.get(env_name, kind_config(kind)["rx_default"])


def netlist_run_id(kind: str) -> str:
    for env_name in kind_config(kind)["netlist_envs"]:
        value = os.environ.get(env_name, "").strip()
        if value:
            return value
    return str(kind_config(kind).get("dc_id") or "")


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def checked(client, command: str) -> str:
    output = remote_run(client, command)
    if "__HOP_PPA_OK__" not in output:
        raise RuntimeError(output)
    return output


def read_remote(client, path: str) -> str:
    return remote_run(client, "cat %s" % shlex.quote(path))


def validate_artifact(client, kind: str, netlist_run_id: str) -> dict:
    config = kind_config(kind)
    dut = config["dut"]
    out = "%s/outputs/%s" % (ROOT, netlist_run_id)
    reports = "%s/reports/dc/%s" % (ROOT, netlist_run_id)
    required = (
        "%s/%s.ddc" % (out, dut),
        "%s/%s_post.v" % (out, dut),
        "%s/%s.sdf" % (out, dut),
        "%s/%s.sdc" % (out, dut),
        "%s/qor.rpt" % reports,
        "%s/cmr_structure.rpt" % reports,
        "%s/post_hashes.sha256" % reports,
    )
    command = " && ".join("test -s %s" % shlex.quote(path) for path in required)
    checked(client, command + " && echo __HOP_PPA_OK__")
    structure = read_remote(client, "%s/cmr_structure.rpt" % reports)
    values = dict(
        line.split("=", 1) for line in structure.splitlines() if "=" in line
    )
    actual_ports = int(values.get("IPM_COUNT", "-1"))
    actual_opm = int(values.get("OPM_COUNT", "-1"))
    actual_adapters = int(values.get("ADAPTER_COUNT", "-1"))
    if (actual_ports, actual_opm, actual_adapters) != (
        config["ports"], config["ports"], config["adapters"],
    ):
        raise RuntimeError(
            "%s run %s geometry mismatch: IPM=%s OPM=%s ADAPTER=%s, expected %s"
            % (kind, netlist_run_id, actual_ports, actual_opm, actual_adapters, config)
        )
    if not config["async"]:
        actual_sel = int(values.get("SELECTOR_COUNT", "-1"))
        if actual_sel != int(config["selectors"]):
            raise RuntimeError(
                "%s run %s selector mismatch: SELECTOR=%s expected %s"
                % (kind, netlist_run_id, actual_sel, config["selectors"])
            )
    if config["async"]:
        require_locked_delay_structure(values, label="%s %s" % (kind, netlist_run_id))
    elif netlist_run_id in NOT_FAT_VS_THIN_DELAY:
        print(
            "WARN %s %s is not the locked hop delay recipe: %s"
            % (kind, netlist_run_id, NOT_FAT_VS_THIN_DELAY[netlist_run_id]),
            flush=True,
        )
    hashes = read_remote(client, "%s/post_hashes.sha256" % reports)
    qor = read_remote(client, "%s/qor.rpt" % reports)
    area_match = re.search(r"(?:Total\s+)?Cell Area:\s*([0-9.eE+-]+)", qor, re.I)
    if not area_match:
        raise RuntimeError("could not locate Total cell area in %s/qor.rpt" % reports)
    return {
        "kind": kind,
        "netlist_run_id": netlist_run_id,
        "remote_output": out,
        "remote_reports": reports,
        "structure": values,
        "post_hashes": hashes,
        "total_cell_area_um2": float(area_match.group(1)),
    }


def discover_candidates(client) -> list[dict]:
    """List only complete standalone-router post-DC artifacts, read-only."""
    command = r"""
for f in {root}/outputs/*/CMRRouter.ddc; do
  test -s "$f" || continue
  r=$(basename "$(dirname "$f")")
  s={root}/reports/dc/$r/cmr_structure.rpt
  q={root}/reports/dc/$r/qor.rpt
  h={root}/reports/dc/$r/post_hashes.sha256
  test -s "$s" && test -s "$q" && test -s "$h" || continue
  printf 'RUN=%s ' "$r"
  awk -F= '/^(IPM_COUNT|OPM_COUNT|ADAPTER_COUNT)=/{printf "%s=%s ", $1, $2}' "$s"
  awk '/Total cell area:/{printf "AREA=%s\n", $4; exit}' "$q"
done
""".replace("{root}", shlex.quote(ROOT))
    output = remote_run(client, "bash -c %s" % shlex.quote(command))
    candidates = []
    for line in output.splitlines():
        values = dict(re.findall(r"([A-Z_]+)=([^ ]+)", line))
        if {"RUN", "IPM_COUNT", "OPM_COUNT", "ADAPTER_COUNT", "AREA"} <= values.keys():
            candidates.append(values)
    return candidates


def submit(client, command: str, label: str) -> str:
    response = remote_run(client, command)
    jid = job_id(response)
    print("JOB_SUBMIT", label, jid, flush=True)
    wait_job(client, jid, label)
    return jid


def copy_remote_file(sftp, remote: str, local: Path) -> None:
    local.parent.mkdir(parents=True, exist_ok=True)
    sftp.get(remote, str(local))


def parse_events(path: Path, *, mode: str, run_log: str = "") -> tuple[list[dict], float, float]:
    rows: list[dict] = []
    if path.is_file():
        with path.open(newline="", encoding="utf-8") as source:
            rows = list(csv.DictReader(source))
    window = re.search(r"PPA_WINDOW start=([0-9.]+) end=([0-9.]+)", run_log)
    if mode == "idle":
        if window:
            return rows, float(window.group(1)), float(window.group(2))
        return rows, 210.0, 260.0
    if not path.is_file():
        raise RuntimeError("missing hop_events.csv")
    if mode == "isolated" and len(rows) != 5:
        raise RuntimeError("R-U5 isolated expects 5 flit rows, found %d" % len(rows))
    if not rows:
        raise RuntimeError("expected hop event rows, found 0")
    start = float(rows[0]["input_req_ns"])
    end = float(rows[-1]["output_req_ns"])
    if end <= start:
        raise RuntimeError("invalid VCD power window %s:%s" % (start, end))
    return rows, start, end + 0.001


def selected_kinds() -> list[str]:
    requested = [
        name.strip()
        for name in os.environ.get("CMR_HOP_KINDS", ",".join(DEFAULT_HOP_KINDS)).split(",")
        if name.strip()
    ]
    unknown = []
    resolved = []
    for name in requested:
        try:
            resolved.append(lookup(name)["kind"])
        except KeyError:
            unknown.append(name)
    if unknown:
        raise RuntimeError("unsupported CMR_HOP_KINDS: %s" % unknown)
    if not resolved:
        raise RuntimeError("CMR_HOP_KINDS is empty")
    # Preserve order, drop duplicates after alias resolution.
    seen = set()
    unique = []
    for name in resolved:
        if name not in seen:
            unique.append(name)
            seen.add(name)
    return unique


def copy_gls_logs(sftp, remote_gls_log: str, local_kind: Path) -> None:
    for name in (
        "run.log", "stdout.log", "compile.log", "sdf_annotate.log",
        "hop_events.csv", "hop_ppa.vcd", "input_hashes.sha256", "lsf.log",
    ):
        try:
            copy_remote_file(sftp, "%s/%s" % (remote_gls_log, name), local_kind / "gls" / name)
        except OSError:
            if name not in ("sdf_annotate.log", "hop_events.csv", "hop_ppa.vcd", "lsf.log"):
                raise


def parse_power(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    # PrimeTime report layouts vary across releases.  Preserve the source
    # report and extract only explicitly-labelled totals when present.
    patterns = {
        "total_power_w": r"Total\s+Power\s*=\s*([0-9.eE+-]+)\s*([munp]?W)",
        "dynamic_power_w": r"Total\s+Dynamic\s+Power\s*=\s*([0-9.eE+-]+)\s*([munp]?W)",
        "leakage_power_w": r"Cell\s+Leakage\s+Power\s*=\s*([0-9.eE+-]+)\s*([munp]?W)",
    }
    scale = {"W": 1.0, "mW": 1e-3, "uW": 1e-6, "nW": 1e-9, "pW": 1e-12}
    result: dict[str, float | None] = {}
    for name, pattern in patterns.items():
        match = re.search(pattern, text, re.I)
        if match:
            unit = match.group(2) if match.lastindex >= 2 and match.group(2) else "W"
            if unit == "":
                unit = "W"
            result[name] = float(match.group(1)) * scale.get(unit, 1.0)
        else:
            bare = re.search(
                r"Total\s+Power\s*=\s*([0-9.eE+-]+)\s+\(" if name == "total_power_w"
                else r"Cell\s+Leakage\s+Power\s*=\s*([0-9.eE+-]+)" if name == "leakage_power_w"
                else r"Net\s+Switching\s+Power\s*=\s*([0-9.eE+-]+)",
                text,
                re.I,
            )
            result[name] = float(bare.group(1)) if bare else None
    return result


def annotate_energy(power: dict, duration_ns: float) -> dict:
    duration_s = duration_ns * 1e-9
    power["window_ns"] = duration_ns
    power["total_energy_j"] = (
        power["total_power_w"] * duration_s if power["total_power_w"] is not None else None
    )
    return power


def hbt_from_events(events: list[dict]) -> tuple[str, str, str]:
    if len(events) >= 5:
        head = events[0].get("hop_latency_ns", "")
        bodies = [float(events[i]["hop_latency_ns"]) for i in (1, 2, 3) if events[i].get("hop_latency_ns")]
        body = "%.3f" % (sum(bodies) / len(bodies)) if bodies else ""
        tail = events[4].get("hop_latency_ns", "")
        return head, body, tail
    if len(events) >= 3:
        return (
            events[0].get("hop_latency_ns", ""),
            events[1].get("hop_latency_ns", ""),
            events[2].get("hop_latency_ns", ""),
        )
    return "", "", ""


def run_kind(client, sftp, artifact: dict) -> dict:
    kind = artifact["kind"]
    config = kind_config(kind)
    netlist_run_id = artifact["netlist_run_id"]
    artifact["modes"] = {}
    gls_script = (
        "run_gls_cmr_router_hop_ppa.sh"
        if config["async"]
        else "run_gls_cmr_sync_router_hop_ppa.sh"
    )
    strip = (
        "tb_cmr_router_hop_ppa/dut"
        if config["async"]
        else "tb_sync_cmr_router_hop_ppa/dut"
    )
    for mode in HOP_MODES:
        tag = "%s_%s" % (kind, mode)
        local_kind = RESULT_DIR / kind / mode
        remote_gls_log = "%s/logs/hop_ppa/%s_%s/gls" % (ROOT, RUN_ID, tag)
        guard = "0.20"
        run_log_path = local_kind / "gls" / "run.log"
        events_path = local_kind / "gls" / "hop_events.csv"
        resume_gls = (
            os.environ.get("CMR_HOP_RESUME", "1") == "1"
            and run_log_path.is_file()
            and events_path.is_file()
            and "PPA_RESULT PASS" in run_log_path.read_text(encoding="utf-8", errors="replace")
        )
        if resume_gls:
            print("HOP_GLS_RESUME", tag, flush=True)
            gls_job = "resumed"
            copy_gls_logs(sftp, remote_gls_log, local_kind)
        else:
            command = (
                "mkdir -p {root}/logs/hop_ppa/{run}_{tag} {root}/reports/hop_ppa/{run}_{tag}; "
                "bsub -n 8 -oo {log}/lsf.log "
                "env CMR_REMOTE_ROOT={root} CMR_RUN_ID={run}_{tag} "
                "CMR_NETLIST_RUN_ID={netlist} CMR_HOP_KIND={kind} "
                "CMR_HOP_MODE={mode} CMR_HOP_MESH={mesh} "
                "CMR_RX_CAPTURE_NS={rx} CMR_ACK_TO_NEXT_REQ_GUARD_NS={guard} "
                "CMR_HOP_PATH_PROBE={probe} CMR_HOP_NO_SDF={nosdf} "
                "bash {root}/scripts/{script}"
            ).format(
                root=shlex.quote(ROOT), run=shlex.quote(RUN_ID), tag=shlex.quote(tag),
                kind=shlex.quote(kind), mode=shlex.quote(mode),
                mesh="1" if config["mesh"] else "0",
                netlist=shlex.quote(netlist_run_id), log=shlex.quote(remote_gls_log),
                rx=shlex.quote(rx_for(kind)), guard=shlex.quote(guard),
                probe=shlex.quote(os.environ.get("CMR_HOP_PATH_PROBE", "0")),
                nosdf=shlex.quote(os.environ.get("CMR_HOP_NO_SDF", "0")),
                script=gls_script,
            )
            response = remote_run(client, command)
            gls_job = job_id(response)
            print("JOB_SUBMIT", tag + "_gls", gls_job, flush=True)
            gls_error = None
            try:
                wait_job(client, gls_job, tag + "_gls")
            except RuntimeError as exc:
                gls_error = exc
            copy_gls_logs(sftp, remote_gls_log, local_kind)
            if gls_error is not None:
                run_log = run_log_path.read_text(encoding="utf-8", errors="replace") if run_log_path.exists() else ""
                raise RuntimeError("%s GLS LSF failed: %s\n%s" % (tag, gls_error, run_log[-4000:]))
        run_log = run_log_path.read_text(encoding="utf-8", errors="replace") if run_log_path.exists() else ""
        if "PPA_RESULT PASS" not in run_log or re.search(r"Timing violation|PPA_FAIL|PPA_RESULT FAIL", run_log):
            raise RuntimeError("%s strict GLS did not pass\n%s" % (tag, run_log[-4000:]))
        mode_row = {"gls_job_id": gls_job, "run_log_pass": True}
        if mode == "contention":
            artifact["modes"][mode] = mode_row
            continue
        events, start_ns, end_ns = parse_events(
            local_kind / "gls" / "hop_events.csv", mode=mode, run_log=run_log
        )
        mode_row["events"] = events
        mode_row["power_window_ns"] = {
            "start": start_ns, "end": end_ns, "duration": end_ns - start_ns,
        }
        if mode == "isolated" and len(events) >= 5:
            flit_windows = ",".join(
                [
                    "%.3f:%.3f" % (float(events[0]["input_req_ns"]), float(events[0]["output_req_ns"]) + 0.001),
                    "%.3f:%.3f" % (float(events[1]["input_req_ns"]), float(events[3]["output_req_ns"]) + 0.001),
                    "%.3f:%.3f" % (float(events[4]["input_req_ns"]), float(events[4]["output_req_ns"]) + 0.001),
                ]
            )
        elif events:
            flit_windows = ",".join(
                "%.3f:%.3f" % (float(row["input_req_ns"]), float(row["output_req_ns"]) + 0.001)
                for row in events[:3]
            )
        else:
            flit_windows = ""
        remote_power_log = "%s/logs/hop_ppa/%s_%s/power" % (ROOT, RUN_ID, tag)
        remote_power = "%s/reports/hop_ppa/%s_%s/power" % (ROOT, RUN_ID, tag)
        check_path = local_kind / "power" / "check_power.rpt"
        resume_px = (
            os.environ.get("CMR_HOP_RESUME", "1") == "1"
            and check_path.is_file()
            and (local_kind / "power" / "power.rpt").is_file()
        )
        if resume_px:
            print("HOP_PX_RESUME", tag, flush=True)
            mode_row["power_job_id"] = "resumed"
        else:
            command = (
                "mkdir -p {log}; bsub -n 4 -oo {log}/lsf.log "
                "env CMR_REMOTE_ROOT={root} CMR_RUN_ID={run}_{tag} "
                "CMR_NETLIST_RUN_ID={netlist} CMR_POWER_START_NS={start:.3f} "
                "CMR_POWER_END_NS={end:.3f} CMR_POWER_FLIT_WINDOWS={windows} "
                "CMR_DUT_NAME={dut} CMR_TB_STRIP={strip} "
                "/soft/synopsys/prime/V-2023.12/bin/pt_shell -f {root}/scripts/run_ptpx_cmr_router_hop_ppa.tcl"
            ).format(
                root=shlex.quote(ROOT), run=shlex.quote(RUN_ID), tag=shlex.quote(tag),
                netlist=shlex.quote(netlist_run_id), start=start_ns, end=end_ns,
                windows=shlex.quote(flit_windows),
                dut=shlex.quote(config["dut"]),
                strip=shlex.quote(strip),
                log=shlex.quote(remote_power_log),
            )
            mode_row["power_job_id"] = submit(client, command, tag + "_ptpx")
            try:
                fetch_tree(sftp, remote_power, local_kind / "power")
            except IOError:
                (local_kind / "power").mkdir(parents=True, exist_ok=True)
            try:
                copy_remote_file(
                    sftp, "%s/lsf.log" % remote_power_log, local_kind / "power" / "lsf.log"
                )
            except OSError:
                pass
        px_log = ""
        lsf_path = local_kind / "power" / "lsf.log"
        if lsf_path.is_file():
            px_log = lsf_path.read_text(encoding="utf-8", errors="replace")
        if not check_path.is_file():
            raise RuntimeError(
                "%s PT-PX did not write check_power.rpt\n%s" % (tag, px_log[-6000:])
            )
        if not resume_px and "PPA_POWER_PASS" not in px_log:
            raise RuntimeError(
                "%s PT-PX missing PPA_POWER_PASS\n%s" % (tag, px_log[-6000:])
            )
        check = check_path.read_text(encoding="utf-8", errors="replace")
        if re.search(r"\b(error|violation)\b", check, re.I) and not re.search(
            r"0\s+error", check, re.I
        ):
            raise RuntimeError("%s check_power reports an error or violation" % tag)
        power = annotate_energy(
            parse_power(local_kind / "power" / "power.rpt"),
            mode_row["power_window_ns"]["duration"],
        )
        n_flits = max(len(events), 1)
        power["energy_per_delivered_flit_j"] = (
            power["total_energy_j"] / n_flits if power["total_energy_j"] is not None else None
        )
        flit_power = {}
        for name in ("head", "body", "tail"):
            report = local_kind / "power" / ("power_%s.rpt" % name)
            if report.exists() and events:
                hop_ns = float(events[0]["hop_latency_ns"]) + 0.001
                flit_power[name] = annotate_energy(parse_power(report), hop_ns)
        power["per_flit"] = flit_power
        mode_row["power"] = power
        artifact["modes"][mode] = mode_row
        if mode == "isolated":
            artifact["events"] = events
            artifact["power"] = power
            artifact["power_window_ns"] = mode_row["power_window_ns"]
        if mode == "idle":
            artifact["idle_power"] = power
        if mode == "stream":
            artifact["active_power"] = power
    return artifact


def write_metrics(result: dict) -> None:
    rows = [
        "geometry,area_um2,max_opm_fanin,head_ns,body_ns,tail_ns,"
        "head_power_w,body_power_w,tail_power_w,packet_power_w,"
        "head_energy_j,body_energy_j,tail_energy_j,packet_energy_j,"
        "idle_power_w,active_power_w,physical_class"
    ]
    for artifact in result["artifacts"]:
        events = artifact.get("events") or []
        power = artifact.get("power") or {}
        per_flit = power.get("per_flit") or {} if isinstance(power, dict) else {}
        head_ns, body_ns, tail_ns = hbt_from_events(events)
        idle_w = ((artifact.get("idle_power") or {}) or {}).get("total_power_w")
        active_w = ((artifact.get("active_power") or {}) or {}).get("total_power_w")
        geom = lookup(artifact["kind"])

        def flit_field(name: str, field: str):
            value = (per_flit.get(name) or {}).get(field)
            return "" if value is None else "%.6e" % value

        rows.append(
            ",".join(
                [
                    artifact["kind"],
                    "%.3f" % artifact["total_cell_area_um2"],
                    str(geom["max_opm_fanin"]),
                    str(head_ns),
                    str(body_ns),
                    str(tail_ns),
                    flit_field("head", "total_power_w"),
                    flit_field("body", "total_power_w"),
                    flit_field("tail", "total_power_w"),
                    "" if power.get("total_power_w") is None else "%.6e" % power["total_power_w"],
                    flit_field("head", "total_energy_j"),
                    flit_field("body", "total_energy_j"),
                    flit_field("tail", "total_energy_j"),
                    "" if power.get("total_energy_j") is None else "%.6e" % power["total_energy_j"],
                    "" if idle_w is None else "%.6e" % idle_w,
                    "" if active_w is None else "%.6e" % active_w,
                    "post-synthesis",
                ]
            )
        )
    (RESULT_DIR / "metrics.csv").write_text("\n".join(rows) + "\n", encoding="utf-8")
    slim = []
    for artifact in result["artifacts"]:
        slim.append(
            {
                "kind": artifact["kind"],
                "netlist_run_id": artifact["netlist_run_id"],
                "total_cell_area_um2": artifact["total_cell_area_um2"],
                "physical_class": "post-synthesis",
                "head_ns": hbt_from_events(artifact.get("events") or [])[0],
                "body_ns": hbt_from_events(artifact.get("events") or [])[1],
                "tail_ns": hbt_from_events(artifact.get("events") or [])[2],
                "idle_power_w": ((artifact.get("idle_power") or {}) or {}).get("total_power_w"),
                "active_power_w": ((artifact.get("active_power") or {}) or {}).get("total_power_w"),
                "packet_energy_j": ((artifact.get("power") or {}) or {}).get("total_energy_j"),
                "modes_pass": sorted((artifact.get("modes") or {}).keys()),
            }
        )
    (RESULT_DIR / "calibration.json").write_text(
        json.dumps(
            {
                "run_id": result["run_id"],
                "physical_class": "post-synthesis",
                "primitives": slim,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def main() -> None:
    refuse_overwrite(RUN_ID, action="hop-ppa-results")
    kinds = selected_kinds()
    netlist_ids = {kind: netlist_run_id(kind) for kind in kinds}
    missing = [kind for kind in kinds if not netlist_ids[kind]]
    if missing:
        client = connect()
        try:
            candidates = discover_candidates(client)
        finally:
            client.close()
        print(json.dumps({"frozen_router_candidates": candidates, "missing_kinds": missing}, indent=2))
        return
    uploads = [
        (
            REPO / "scripts/asic_dc/cmr/tb_cmr_router_hop_ppa.sv",
            "%s/sim/tb/tb_cmr_router_hop_ppa.sv" % ROOT,
        ),
        (
            REPO / "scripts/asic_dc/cmr/tb_sync_cmr_router_hop_ppa.sv",
            "%s/sim/tb/tb_sync_cmr_router_hop_ppa.sv" % ROOT,
        ),
        (
            REPO / "scripts/asic_dc/cmr/run_gls_cmr_router_hop_ppa.sh",
            "%s/scripts/run_gls_cmr_router_hop_ppa.sh" % ROOT,
        ),
        (
            REPO / "scripts/asic_dc/cmr/tb_cmr_pfat48_path_probe.sv",
            "%s/sim/tb/tb_cmr_pfat48_path_probe.sv" % ROOT,
        ),
        (
            REPO / "scripts/asic_dc/cmr/run_gls_cmr_sync_router_hop_ppa.sh",
            "%s/scripts/run_gls_cmr_sync_router_hop_ppa.sh" % ROOT,
        ),
        (
            REPO / "scripts/asic_dc/power/run_ptpx_cmr_router_hop_ppa.tcl",
            "%s/scripts/run_ptpx_cmr_router_hop_ppa.tcl" % ROOT,
        ),
    ]
    bind_dir = REPO / "scripts" / "asic_dc" / "cmr" / "hop_binds"
    for vi in sorted(bind_dir.glob("*.vi")):
        uploads.append((vi, "%s/sim/tb/hop_binds/%s" % (ROOT, vi.name)))
    local_files = tuple(path for path, _ in uploads)
    client = connect()
    sftp = client.open_sftp()
    try:
        artifacts = [
            validate_artifact(client, kind, netlist_ids[kind]) for kind in kinds
        ]
        remote_run(client, "mkdir -p %s/sim/tb/hop_binds" % ROOT)
        for local, remote in uploads:
            atomic_put(client, sftp, local, remote)
        checked(
            client,
            "chmod +x %s %s && echo __HOP_PPA_OK__"
            % (
                shlex.quote("%s/scripts/run_gls_cmr_router_hop_ppa.sh" % ROOT),
                shlex.quote("%s/scripts/run_gls_cmr_sync_router_hop_ppa.sh" % ROOT),
            ),
        )
        RESULT_DIR.mkdir(parents=True, exist_ok=True)
        result = {
            "run_id": RUN_ID,
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "git_sha": subprocess.run(
                ["git", "-C", str(REPO), "rev-parse", "HEAD"],
                capture_output=True,
                text=True,
                check=False,
            ).stdout.strip(),
            "source_hashes": {str(path.relative_to(REPO)).replace("\\", "/"): sha256_file(path) for path in local_files},
            "artifacts": [run_kind(client, sftp, artifact) for artifact in artifacts],
        }
        (RESULT_DIR / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        write_metrics(result)
        print(
            "HOP_PPA_PASS",
            RUN_ID,
            ",".join(artifact["kind"] for artifact in result["artifacts"]),
            flush=True,
        )
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    main()

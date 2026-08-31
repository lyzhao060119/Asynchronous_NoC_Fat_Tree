#!/usr/bin/env python3
"""Remote ICC2 / ICC / Innovus P&R pilot for CMR Thin (1,1) and PROP (2,2).

License checkout and implementation run on LSF batch nodes, never on login.
Does not overwrite frozen DC hop netlists.  Writes locked_tool.json after
the import+route gate comparison.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))

from run_remote_cmr_flow import (  # noqa: E402
    atomic_put,
    atomic_put_bytes,
    job_id,
    remote_run,
)
from run_remote_cmr_noc16_sdf import connect  # noqa: E402


ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_PNR_RUN_ID",
    datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S") + "_cmr_pnr_pilot",
)
LOCAL = REPO / "scripts" / "asic_pnr" / "cmr" / "results" / RUN_ID
LOCK_PATH = REPO / "scripts" / "asic_pnr" / "cmr" / "locked_tool.json"
PNR_LOCAL = REPO / "scripts" / "asic_pnr" / "cmr"

SNPS_LIC = os.environ.get(
    "CMR_SNPSLMD_LICENSE_FILE",
    "1701@192.168.2.7:1701@192.168.2.153:1701@master",
)
CDS_LIC = os.environ.get(
    "CMR_CDS_LIC_FILE",
    "5280@192.168.2.7:5280@192.168.2.153:5280@master",
)

DESIGNS = {
    "thin_1x1": {
        "netlist_run_id": os.environ.get(
            "CMR_PNR_NETLIST_RUN_ID", "20260830_cmr_thin_l1_hop_del050_ackin050"
        ),
        "top": "CMRRouter",
        "expected_del050": "10",
        "expected_ports": "5",
        "sync": "0",
    },
    "prop_2x2": {
        "netlist_run_id": os.environ.get(
            "CMR_PNR_NETLIST_RUN_ID_PROP", "20260830_cmr_fat_l2_hop_del050_ackin050"
        ),
        "top": "CMRRouter",
        "expected_del050": "20",
        "expected_ports": "10",
        "sync": "0",
    },
}

TOOLS = ("icc2", "innovus")
POLLS = int(os.environ.get("CMR_PNR_POLLS", "720"))
POLL_S = int(os.environ.get("CMR_PNR_POLL_S", "30"))

UPLOAD = {
    PNR_LOCAL / "tech_t28hpc_pnr.tcl": "scripts/pnr/tech_t28hpc_pnr.tcl",
    PNR_LOCAL / "async_preserve.tcl": "scripts/pnr/async_preserve.tcl",
    PNR_LOCAL / "async_rtc_data_checks.tcl": "scripts/pnr/async_rtc_data_checks.tcl",
    PNR_LOCAL / "icc2" / "run_icc2_cmr_router.tcl": "scripts/pnr/icc2/run_icc2_cmr_router.tcl",
    PNR_LOCAL / "icc2" / "convert_ndm.tcl": "scripts/pnr/icc2/convert_ndm.tcl",
    PNR_LOCAL / "icc2" / "dump_tech_lef.tcl": "scripts/pnr/icc2/dump_tech_lef.tcl",
    PNR_LOCAL / "icc" / "run_icc_cmr_router.tcl": "scripts/pnr/icc/run_icc_cmr_router.tcl",
    PNR_LOCAL / "innovus" / "run_innovus_cmr_router.tcl": "scripts/pnr/innovus/run_innovus_cmr_router.tcl",
    PNR_LOCAL / "pt" / "run_pt_post_route.tcl": "scripts/pnr/pt/run_pt_post_route.tcl",
}


def lf(data: bytes) -> bytes:
    return data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")


def wait_job_long(client, jid: str, label: str, log_path: str) -> str:
    for poll in range(POLLS):
        response = remote_run(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__CMR_JOB_STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        marker = re.search(r"__CMR_JOB_STATE__([A-Z]*)", response)
        state = marker.group(1) if marker else ""
        if not state or state == "DONE":
            print("JOB_DONE", label, jid, state or "PURGED", flush=True)
            return remote_run(client, "cat %s 2>/dev/null || echo MISSING_LOG" % shlex.quote(log_path))
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            text = remote_run(
                client,
                "echo STATE=%s; echo LOG; cat %s 2>/dev/null; echo ERR; cat %s.err 2>/dev/null"
                % (state, shlex.quote(log_path), shlex.quote(log_path)),
            )
            print("JOB_EXIT", label, jid, state, flush=True)
            return text
        if poll % 4 == 0:
            print("JOB_WAIT", label, jid, state, "poll", poll, flush=True)
        time.sleep(POLL_S)
    raise RuntimeError("job polling timeout: %s %s" % (label, jid))


def wrapper(body: str) -> bytes:
    preamble = """#!/bin/bash
source /etc/profile >/dev/null 2>&1 || true
export SNPSLMD_LICENSE_FILE=%s
export LM_LICENSE_FILE=%s
export CDS_LIC_FILE=%s
export PATH=/soft/synopsys/icc2/V-2023.12/bin:/soft/synopsys/icc/V-2023.12-SP5/bin:/soft/synopsys/syn/V-2023.12/bin:/soft/synopsys/prime/V-2023.12/bin:/soft/cadence/INNOVUS21/bin:/soft/cadence/INNOVUS21/tools/bin:${PATH:-/usr/bin:/bin}
echo HOST=$(hostname)
echo DATE=$(date -Iseconds)
echo WHICH_ICC2=$(command -v icc2_shell)
echo WHICH_ICC=$(command -v icc_shell)
echo WHICH_INNOVUS=$(command -v innovus)
echo WHICH_PT=$(command -v pt_shell)
""" % (SNPS_LIC, SNPS_LIC, CDS_LIC)
    return lf((preamble + body + "\n").encode())


def submit(client, sftp, name: str, body: str, nproc: int = 8) -> tuple[str, str]:
    remote_dir = "%s/logs/pnr/%s" % (ROOT, RUN_ID)
    remote_run(client, "mkdir -p %s" % shlex.quote(remote_dir))
    wrapper_path = "%s/%s.sh" % (remote_dir, name)
    log_path = "%s/%s.log" % (remote_dir, name)
    atomic_put_bytes(client, sftp, wrapper(body), wrapper_path)
    remote_run(client, "chmod +x %s" % shlex.quote(wrapper_path))
    submit_text = remote_run(
        client,
        "bsub -n %d -o %s -e %s.err -J cmr_pnr_%s_%s %s"
        % (nproc, shlex.quote(log_path), shlex.quote(log_path), name, RUN_ID, shlex.quote(wrapper_path)),
    )
    jid = job_id(submit_text)
    print("LSF_JOB", name, jid, flush=True)
    return jid, log_path


def license_body(tool: str) -> str:
    if tool == "icc2":
        return (
            "module load icc2/2023.12 >/dev/null 2>&1 || true\n"
            "command -v icc2_shell || { echo MISSING_ICC2; exit 2; }\n"
            "icc2_shell -batch -x 'puts ICC2_LICENSE_OK; puts [version]; exit'\n"
        )
    if tool == "icc":
        return (
            "module load icc/2023.12 >/dev/null 2>&1 || true\n"
            "command -v icc_shell || { echo MISSING_ICC; exit 2; }\n"
            "icc_shell -x 'puts ICC_LICENSE_OK; puts [version]; exit'\n"
        )
    return (
        "command -v innovus || { echo MISSING_INNOVUS; exit 2; }\n"
        "printf '%s\\n' 'puts INNOVUS_LICENSE_OK' 'exit' > /tmp/cmr_innovus_lic.tcl\n"
        "innovus -nowin -overwrite -init /tmp/cmr_innovus_lic.tcl\n"
    )


def pnr_body(tool: str, design: str, cfg: dict) -> str:
    netlist = "%s/outputs/%s/CMRRouter_post.v" % (ROOT, cfg["netlist_run_id"])
    sdc = "%s/outputs/%s/CMRRouter.sdc" % (ROOT, cfg["netlist_run_id"])
    env = (
        "export CMR_REMOTE_ROOT=%s CMR_PNR_RUN_ID=%s CMR_PNR_NETLIST=%s "
        "CMR_PNR_SDC=%s CMR_PNR_TOP=%s CMR_PNR_SYNC=%s CMR_EXPECTED_DEL050=%s "
        "CMR_EXPECTED_PORTS=%s\n"
        % (
            shlex.quote(ROOT),
            shlex.quote("%s_%s_%s" % (RUN_ID, tool, design)),
            shlex.quote(netlist),
            shlex.quote(sdc),
            shlex.quote(cfg["top"]),
            cfg["sync"],
            cfg["expected_del050"],
            cfg["expected_ports"],
        )
    )
    if tool == "icc2":
        return env + (
            "module load icc2/2023.12 >/dev/null 2>&1 || true\n"
            "cd %s\n"
            "exec icc2_shell -batch -file %s/scripts/pnr/icc2/run_icc2_cmr_router.tcl\n"
            % (shlex.quote(ROOT), ROOT)
        )
    if tool == "icc":
        return env + (
            "module load icc/2023.12 >/dev/null 2>&1 || true\n"
            "cd %s\n"
            "exec icc_shell -f %s/scripts/pnr/icc/run_icc_cmr_router.tcl\n"
            % (shlex.quote(ROOT), ROOT)
        )
    return env + (
        "cd %s\n"
        "exec innovus -nowin -overwrite -init %s/scripts/pnr/innovus/run_innovus_cmr_router.tcl\n"
        % (shlex.quote(ROOT), ROOT)
    )


def passed(text: str) -> bool:
    return "CMR_PNR_PASS" in text or "ICC2_LICENSE_OK" in text or "ICC_LICENSE_OK" in text or "INNOVUS_LICENSE_OK" in text


def write_lock(result: dict) -> None:
    if LOCK_PATH.is_file() and os.environ.get("CMR_PNR_FORCE_LOCK", "0") != "1":
        try:
            existing = json.loads(LOCK_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = {}
        if existing.get("freeze") == "post-synthesis-only":
            print(
                "PNR_LOCK_FROZEN keeping",
                LOCK_PATH,
                "(set CMR_PNR_FORCE_LOCK=1 to replace)",
                flush=True,
            )
            (LOCAL / "pilot_summary.json").write_text(
                json.dumps({**result, "frozen_existing_lock": existing}, indent=2) + "\n",
                encoding="utf-8",
            )
            return
    LOCK_PATH.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    LOCAL.mkdir(parents=True, exist_ok=True)
    tool_filter = os.environ.get("CMR_PNR_TOOL", "").strip()
    design_filter = os.environ.get("CMR_PNR_DESIGN", "").strip()
    skip_impl = os.environ.get("CMR_PNR_LICENSE_ONLY", "0") == "1"
    env_nl = os.environ.get("CMR_PNR_NETLIST_RUN_ID", "").strip()
    if env_nl:
        if design_filter and design_filter in DESIGNS:
            DESIGNS[design_filter]["netlist_run_id"] = env_nl
        elif not design_filter:
            DESIGNS["thin_1x1"]["netlist_run_id"] = env_nl
    client = connect()
    try:
        remote_run(
            client,
            "mkdir -p %s/scripts/pnr/icc2 %s/scripts/pnr/icc %s/scripts/pnr/innovus "
            "%s/scripts/pnr/pt %s/reports/pnr %s/outputs/pnr %s/work %s/logs/pnr/%s"
            % (ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, ROOT, RUN_ID),
        )
        sftp = client.open_sftp()
        for local, dest in UPLOAD.items():
            print("UPLOAD", dest, flush=True)
            data = lf(local.read_bytes())
            atomic_put_bytes(client, sftp, data, ROOT + "/" + dest)

        license_ok = {}
        for tool in TOOLS:
            if tool_filter and tool != tool_filter:
                continue
            if os.environ.get("CMR_PNR_SKIP_LIC", "0") == "1":
                license_ok[tool] = True
                print("LICENSE", tool, "skipped", flush=True)
                continue
            jid, log = submit(client, sftp, "%s_lic" % tool, license_body(tool), nproc=2)
            text = wait_job_long(client, jid, "lic_" + tool, log)
            (LOCAL / ("%s_lic.log" % tool)).write_text(text, encoding="utf-8")
            license_ok[tool] = passed(text)
            print("LICENSE", tool, license_ok[tool], flush=True)

        if not skip_impl and license_ok.get("icc2"):
            dump_body = (
                "module load icc2/2023.12 >/dev/null 2>&1 || true\n"
                "export CMR_REMOTE_ROOT=%s\n"
                "export ICC_HOME=/soft/synopsys/icc/V-2023.12-SP5\n"
                "export SYNOPSYS=/soft/synopsys/icc/V-2023.12-SP5\n"
                "export PATH=/soft/synopsys/icc/V-2023.12-SP5/bin:/soft/synopsys/icc2/V-2023.12/bin:$PATH\n"
                "echo WHICH_ICC_SHELL=$(command -v icc_shell)\n"
                "echo WHICH_MILKYWAY=$(command -v Milkyway || true)\n"
                "echo WHICH_MW_SHELL=$(command -v mw_shell || true)\n"
                "cd %s\n"
                "exec icc2_lm_shell -batch -file %s/scripts/pnr/icc2/dump_tech_lef.tcl\n"
                % (shlex.quote(ROOT), shlex.quote(ROOT), ROOT)
            )
            jid, log = submit(client, sftp, "dump_tech_lef", dump_body, nproc=2)
            dump_text = wait_job_long(client, jid, "dump_tech_lef", log)
            (LOCAL / "dump_tech_lef.log").write_text(dump_text, encoding="utf-8")
            print("DUMP_TECH", "CMR_PNR_TECH_LEF_OK" in dump_text or "CMR_PNR_NDM_OK" in dump_text, flush=True)
            (LOCAL / "dump_tech_lef.log").write_text(dump_text, encoding="utf-8")
            if os.environ.get("CMR_PNR_DUMP_ONLY", "0") == "1":
                skip_impl = True

        impl = {}
        if not skip_impl:
            jobs = []
            for design, cfg in DESIGNS.items():
                if design_filter and design != design_filter:
                    continue
                for tool in ("icc2", "innovus"):
                    if tool_filter and tool != tool_filter:
                        continue
                    if not license_ok.get(tool, False) and not os.environ.get("CMR_PNR_FORCE_IMPL"):
                        print("SKIP_IMPL_NO_LICENSE", tool, design, flush=True)
                        continue
                    name = "%s_%s" % (tool, design)
                    jid, log = submit(client, sftp, name, pnr_body(tool, design, cfg), nproc=8)
                    jobs.append((name, tool, design, jid, log))
            for name, tool, design, jid, log in jobs:
                text = wait_job_long(client, jid, name, log)
                (LOCAL / ("%s.log" % name)).write_text(text, encoding="utf-8")
                impl[name] = {
                    "tool": tool,
                    "design": design,
                    "pass": "CMR_PNR_PASS" in text,
                    "structure_ok": "CMR_PNR_STRUCTURE_OK" in text or "CMR_PNR_PASS" in text,
                    "tail": "\n".join(text.splitlines()[-80:]),
                }
                print("IMPL", name, impl[name]["pass"], flush=True)

        sftp.close()
        icc2_ok = any(v.get("pass") for k, v in impl.items() if v["tool"] == "icc2")
        inv_ok = any(v.get("pass") for k, v in impl.items() if v["tool"] == "innovus")
        locked = None
        reason = ""
        physical_class = "post-synthesis"
        if icc2_ok:
            locked = "icc2"
            reason = "ICC2 completed route with async structure checks; keep Synopsys DC/DDC/PT chain."
            physical_class = "post-layout"
        elif inv_ok:
            locked = "innovus"
            reason = "Innovus completed route; ICC2 import/route did not pass the pilot gate."
            physical_class = "post-layout"
        elif license_ok.get("icc2") or license_ok.get("innovus") or license_ok.get("icc"):
            locked = None
            reason = "License checkout worked for at least one tool but implementation did not pass the pilot gate."
        else:
            locked = None
            reason = (
                "Definitive blocker: LSF license checkout failed for ICC2, ICC and Innovus, "
                "or implementation was skipped. Main evaluation stays post-synthesis MAXIMUM SDF "
                "until P&R recovers. Do not call results post-layout."
            )

        lock = {
            "schema": "date-v3-pnr-lock-v1",
            "updated_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            "pilot_run_id": RUN_ID,
            "locked_tool": locked,
            "mixed_tools_forbidden": True,
            "physical_class": physical_class,
            "pdk": {
                "tsmc_home": "/process/tsmc/CLN28HPC+/TSMCHOME",
                "cell": "tcbn28hpcplusbwp12t30p140",
                "lef": "/process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef/tcbn28hpcplusbwp12t30p140.lef",
                "mw": "/process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/milkyway/tcbn28hpcplusbwp12t30p140_170a/frame_only_VHV_0d5_0",
                "liberty_ss": "/process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp12t30p140_180a/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.lib",
                "db_ss": "/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140ssg0p81v125c_ccs.db",
            },
            "tools": {
                "icc2": "/soft/synopsys/icc2/V-2023.12/bin/icc2_shell",
                "icc": "/soft/synopsys/icc/V-2023.12-SP5/bin/icc_shell",
                "innovus": "/soft/cadence/INNOVUS21/bin/innovus",
                "pt": "/soft/synopsys/prime/V-2023.12/bin/pt_shell",
            },
            "async_preservation": [
                "DelayElement/DEL050",
                "Mutex feedback",
                "Muller-C",
                "LHCNDQD/LHSNDQD",
                "V2CloseEvent",
                "LanePhaseAdapter",
            ],
            "license": license_ok,
            "implementation": {k: {"pass": v["pass"], "design": v["design"], "tool": v["tool"]} for k, v in impl.items()},
            "reason": reason,
            "paper_rule": "Until locked_tool is set and post-route GLS/STA pass, Table I/model numbers are post-synthesis calibrated only.",
        }
        write_lock(lock)
        (LOCAL / "pilot_summary.json").write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
        print("PNR_LOCK", json.dumps(lock, indent=2), flush=True)
        if locked:
            return 0
        return 0 if skip_impl else 2
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())

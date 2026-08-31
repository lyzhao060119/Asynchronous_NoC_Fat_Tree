#!/usr/bin/env python3
"""Upload GLS smoke assets and run func then sdf on cluster."""
from __future__ import print_function

import os
import re
import time
from pathlib import Path

import paramiko

P = "/home/ghy19/Asynchronous_Router"
GLS = Path(__file__).resolve().parent / "sim_gls"
TIMING = Path(__file__).resolve().parent / "timing"
REPO = Path(__file__).resolve().parents[2]
CASES_R1 = REPO / "sim" / "AsyncRouterL1" / "testbench" / "cases"
CASES_N16 = REPO / "sim" / "AsyncNoC" / "testbench" / "small_cases"
CASES_N16_VCTM = REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases" / "VCTM_16"
CASES_N16_TAB = REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases" / "TAB_16"
NOC16_AXI_WRAPPER = REPO / "sim" / "AsyncNoC" / "async_noc16_axi_bram_wrapper.sv"
NOC16_AXI_TB = REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc16_async_axi_bram.sv"
NOC16_ULTRA_RTL = REPO / "generated_ultra" / "NoC_16nodes.v"

UPLOAD = [
    "patch_gls_netlist.py",
    "run_gls_smoke.sh",
    "run_gls_func.sh",
    "tb_gls_routerl1_func.sv",
    "tb_gls_noc16_func.sv",
    "tb_gls_router_wormhole_minimal.sv",
    "async_hs_port.sv",
    "filelist_routerl1_func.f",
    "filelist_noc16_func.f",
    "README.md",
]


def get_password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"^[ \t-]*\u5bc6\u7801[:\uff1a][ \t]*(\S+)", text, re.M)
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=get_password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def run(c, cmd):
    _, o, e = c.exec_command(cmd)
    return o.read().decode(errors="replace") + e.read().decode(errors="replace")


def put_bytes(sftp, local, remote):
    data = local.read_bytes().replace(b"\r\n", b"\n")
    with sftp.file(remote, "wb") as f:
        f.write(data)


def shquote(text):
    return "'" + str(text).replace("'", "'\\''") + "'"


def resolve_noc16_case(case_arg):
    raw = Path(case_arg)
    candidates = []
    if raw.is_absolute():
        candidates.append(raw)
    else:
        candidates.append(REPO / raw)
        candidates.append(CASES_N16 / raw)
        candidates.append(CASES_N16_VCTM / raw)
        candidates.append(CASES_N16_TAB / raw)
        if raw.suffix != ".case":
            candidates.append(CASES_N16 / (str(raw) + ".case"))
            candidates.append(CASES_N16_VCTM / (str(raw) + ".case"))
            candidates.append(CASES_N16_TAB / (str(raw) + ".case"))
    for path in candidates:
        if path.is_file():
            return path
    raise SystemExit("NoC16 case not found: %s" % case_arg)


def upload_noc16_case(c, case_arg):
    local = resolve_noc16_case(case_arg)
    remote_dir = "%s/sim_gls/cases/%s" % (P, local.parent.name)
    remote = "%s/%s" % (remote_dir, local.name)
    sftp = c.open_sftp()
    run(c, "mkdir -p %s" % shquote(remote_dir))
    put_bytes(sftp, local, remote)
    sftp.close()
    return local, remote


def fetch_if_exists(c, remote, local):
    sftp = c.open_sftp()
    try:
        try:
            sftp.stat(remote)
        except IOError:
            return False
        local.parent.mkdir(parents=True, exist_ok=True)
        sftp.get(remote, str(local))
        return True
    finally:
        sftp.close()


def noc16_case_args_from_env():
    if os.environ.get("GLS_NOC16_CASE_LIST"):
        return [
            item.strip()
            for item in os.environ["GLS_NOC16_CASE_LIST"].split(",")
            if item.strip()
        ]
    if os.environ.get("GLS_NOC16_CASE"):
        return [os.environ["GLS_NOC16_CASE"].strip()]
    raise SystemExit("Set GLS_NOC16_CASE or GLS_NOC16_CASE_LIST for *_noc16_case stages")


def run_noc16_case(c, mode, case_arg, timeout_scale):
    local, remote = upload_noc16_case(c, case_arg)
    stem = local.stem
    run_id = time.strftime("%Y%m%d_%H%M%S")
    safe_stem = re.sub(r"[^A-Za-z0-9_.-]", "_", stem)
    tag = "noc16_%s_%s_%s" % (mode, safe_stem, run_id)
    csv_remote = "%s/sim_gls/summary/%s.csv" % (P, tag)
    job = "async_gls_%s_%s_%s" % (mode, re.sub(r"[^A-Za-z0-9]", "_", stem)[:45], run_id[-6:])
    print("NOC16_CASE_SUBMIT mode=%s case=%s remote=%s csv=%s tag=%s" % (mode, local, remote, csv_remote, tag))
    submit(
        c,
        mode,
        "noc16",
        job,
        case_remote=remote,
        csv_remote=csv_remote,
        timeout_scale=timeout_scale,
        log_tag=tag,
    )
    ok = poll(
        c,
        mode,
        "noc16",
        ["TB_RESULT PASS"],
        "N16_%s_%s" % (mode.upper(), stem),
        max_polls=160 if mode == "sdf" else 80,
        sleep_s=30,
        job=job,
        log_tag=tag,
    )
    local_csv = Path(__file__).resolve().parent / "sim_gls" / "results" / ("%s.csv" % tag)
    if fetch_if_exists(c, csv_remote, local_csv):
        print("NOC16_CASE_CSV %s" % local_csv)
        try:
            print(local_csv.read_text(encoding="utf-8", errors="replace")[-2000:])
        except OSError:
            pass
    if not ok:
        print(run(c, "bkill -J %s 2>/dev/null || true" % shquote(job)))
    print("NOC16_CASE_%s %s" % ("PASS" if ok else "FAIL", stem))
    return ok


def upload(c, refresh_sdf_netlists=True):
    sftp = c.open_sftp()
    run(c, "mkdir -p %s/sim_gls/cases %s/sim_gls/summary %s/scripts/timing %s/logs" % (P, P, P, P))
    for name in UPLOAD:
        put_bytes(sftp, GLS / name, "%s/sim_gls/%s" % (P, name))
    put_bytes(sftp, NOC16_AXI_WRAPPER, "%s/sim_gls/async_noc16_axi_bram_wrapper.sv" % P)
    put_bytes(sftp, NOC16_AXI_TB, "%s/sim_gls/tb_noc16_async_axi_bram.sv" % P)
    # RTL pre-simulation uses the same NoC16 scoreboard but needs structural
    # Ultra primitive definitions in addition to the generated top-level RTL.
    for name in (
        "DelayElement_sim.v", "Mutex2_sim.v", "Mutex2.v", "MullerC2.v", "MullerC3.v",
        "TAC2.v", "Mutex3Grant.v", "Mutex5Anchor.v", "DLatchBank.v", "MousetrapStage.v",
    ):
        put_bytes(sftp, REPO / "src" / "main" / "resources" / "ASYNC" / name, "%s/rtl/%s" % (P, name))
    # Keep the RTL used by remote RTL simulation and any subsequent DC run in
    # lockstep with the local Ultra generation.
    put_bytes(sftp, NOC16_ULTRA_RTL, "%s/rtl/NoC_16nodes.v" % P)
    put_bytes(
        sftp,
        TIMING / "run_pt_noc16_e2e_timing.tcl",
        "%s/scripts/timing/run_pt_noc16_e2e_timing.tcl" % P,
    )
    put_bytes(sftp, CASES_R1 / "smoke_directed.case", "%s/sim_gls/cases/smoke_directed.case" % P)
    put_bytes(sftp, CASES_R1 / "smoke_directed_sdf.case", "%s/sim_gls/cases/smoke_directed_sdf.case" % P)
    put_bytes(sftp, CASES_R1 / "smoke_sdf_1pkt.case", "%s/sim_gls/cases/smoke_sdf_1pkt.case" % P)
    put_bytes(sftp, CASES_R1 / "e1_basic_unicast.case", "%s/sim_gls/cases/e1_basic_unicast.case" % P)
    put_bytes(
        sftp,
        CASES_N16 / "noc16_00_to_33_3flit_smoke.case",
        "%s/sim_gls/cases/noc16_00_to_33_3flit_smoke.case" % P,
    )
    put_bytes(
        sftp,
        CASES_N16 / "noc16_00_to_33_3flit_sdf.case",
        "%s/sim_gls/cases/noc16_00_to_33_3flit_sdf.case" % P,
    )
    sftp.close()
    sdf_refresh = (
        "rm -f {P}/outputs/RouterL1_post_sdf.v {P}/outputs/NoC_16nodes_post_sdf.v".format(P=P)
        if refresh_sdf_netlists
        else "# RTL-only run: preserve existing post-synthesis SDF copies"
    )
    print(run(c, """
chmod +x {P}/sim_gls/run_gls_smoke.sh {P}/sim_gls/run_gls_func.sh
sed -i 's/\\r$//' {P}/sim_gls/*.sh {P}/sim_gls/*.py {P}/sim_gls/*.sv {P}/sim_gls/*.f
# refresh patches (force new sdf identity copies — drop any stale behavioral Delay)
{sdf_refresh}
if [ "{patch_netlists}" = "1" ]; then
/usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode func \
  {P}/outputs/RouterL1_post.v {P}/outputs/RouterL1_post_func.v
/usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode sdf \
  {P}/outputs/RouterL1_post.v {P}/outputs/RouterL1_post_sdf.v
/usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode func \
  {P}/outputs/NoC_16nodes_post.v {P}/outputs/NoC_16nodes_post_func.v
/usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode sdf \
  {P}/outputs/NoC_16nodes_post.v {P}/outputs/NoC_16nodes_post_sdf.v
if [ -f {P}/outputs/RouterL1WormholeMinimal_post.v ]; then
  /usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode func \
    {P}/outputs/RouterL1WormholeMinimal_post.v {P}/outputs/RouterL1WormholeMinimal_post_func.v
  /usr/bin/python3 {P}/sim_gls/patch_gls_netlist.py --mode sdf \
    {P}/outputs/RouterL1WormholeMinimal_post.v {P}/outputs/RouterL1WormholeMinimal_post_sdf.v
fi
echo -n R1_func_delay=; grep -c 'assign #(1.0)' {P}/outputs/RouterL1_post_func.v
echo -n R1_sdf_beh_delay=; grep -c 'assign #(1.0)' {P}/outputs/RouterL1_post_sdf.v || echo 0
echo -n R1_sdf_beh_mutex=; grep -c 'assign #(0.1)' {P}/outputs/RouterL1_post_sdf.v || echo 0
echo -n R1_sdf_DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/RouterL1_post_sdf.v
echo -n R1_sdf_ND2=; grep -c 'ND2D1BWP12T30P140' {P}/outputs/RouterL1_post_sdf.v
if [ -f {P}/outputs/RouterL1WormholeMinimal_post_sdf.v ]; then
  echo -n WH_sdf_DEL=; grep -cE 'DEL[0-9]+D1BWP' {P}/outputs/RouterL1WormholeMinimal_post_sdf.v
  echo -n WH_sdf_ND2=; grep -c 'ND2D1BWP12T30P140' {P}/outputs/RouterL1WormholeMinimal_post_sdf.v || true
fi
fi
""".format(
        P=P,
        sdf_refresh=sdf_refresh,
        patch_netlists="1" if refresh_sdf_netlists else "0",
    )))


def submit(c, mode, design, job, case_remote=None, csv_remote=None, timeout_scale=None, log_tag=None):
    tag = log_tag or "%s_%s" % (design, mode)
    log = "%s/logs/gls_smoke_%s" % (P, tag)
    wrapper = "%s/logs/run_gls_smoke_%s.sh" % (P, tag)
    env_lines = ""
    for name in (
        "GLS_E2E_PROBE",
        "GLS_E2E_SRC_PORT",
        "GLS_E2E_DST_PORT",
        "GLS_DUMP_VCD",
        "GLS_DUMP_VCD_PATH",
        "GLS_PROBE",
        "GLS_STALL_PROBE",
        "GLS_STALL_WINDOW_CYCLES",
        "GLS_STALL_WINDOW_COUNT",
        "GLS_RTL_MUTEX_MODEL",
        "GLS_NOC16_HARNESS",
        "GLS_NOC16_PLUSARGS",
    ):
        val = os.environ.get(name)
        if val is not None:
            env_lines += "export %s='%s'\n" % (name, val.replace("'", "'\\''"))
    env_lines += "export GLS_LOG_TAG=%s\n" % shquote(tag)
    if case_remote:
        env_lines += "export GLS_NOC16_CASE=%s\n" % shquote(case_remote)
    if csv_remote:
        env_lines += "export GLS_NOC16_CSV=%s\n" % shquote(csv_remote)
    if timeout_scale:
        env_lines += "export GLS_NOC16_TIMEOUT_SCALE=%s\n" % shquote(timeout_scale)
        env_lines += "export GLS_TIMEOUT_SCALE=%s\n" % shquote(timeout_scale)
    case_arg = shquote(case_remote) if case_remote else ""
    body = """#!/bin/bash
set -uo pipefail
cd %s
%s
exec bash %s/sim_gls/run_gls_smoke.sh %s %s %s
""" % (P, env_lines, P, mode, design, case_arg)
    sftp = c.open_sftp()
    with sftp.file(wrapper, "w") as f:
        f.write(body.replace("\r\n", "\n"))
    sftp.close()
    print(
        run(
            c,
            """
chmod +x {w}; sed -i 's/\\r$//' {w}
: > {log}_bsub.log; : > {log}_bsub.err
: > {P}/logs/gls_{tag}_compile.log
: > {P}/logs/gls_{tag}_run.log
rm -f {csv}
bkill -J {job} 2>/dev/null || true
sleep 1
bsub -n 8 -o {log}_bsub.log -e {log}_bsub.err -J {job} {w}
bjobs -l -J {job} 2>/dev/null | sed -n '1,80p' || bjobs | head
""".format(
                w=wrapper,
                log=log,
                P=P,
                tag=tag,
                csv=shquote(csv_remote or ("%s/sim_gls/summary/%s_%s.csv" % (P, design, mode))),
                job=job,
            ),
        )
    )
    return tag


def poll(c, mode, design, needles, label, max_polls=120, sleep_s=30, job=None, log_tag=None):
    tag = log_tag or "%s_%s" % (design, mode)
    log = "%s/logs/gls_smoke_%s_bsub.log" % (P, tag)
    errlog = "%s/logs/gls_smoke_%s_bsub.err" % (P, tag)
    compilelog = "%s/logs/gls_%s_compile.log" % (P, tag)
    runlog = "%s/logs/gls_%s_run.log" % (P, tag)
    job = job or "async_gls_smoke_%s_%s" % (mode, design)
    last_sizes = None
    stagnant = 0
    for i in range(max_polls):
        text = run(
            c,
            """
bstat=$(bjobs -noheader -o 'stat' -J {jobq} 2>/dev/null | head -1)
if [ -z "$bstat" ]; then echo JOB_STATE=NO_JOB; else echo JOB_STATE=$bstat; fi
echo -n SIZE_BSUB_LOG=; wc -c < {logq} 2>/dev/null || echo 0
echo -n SIZE_BSUB_ERR=; wc -c < {errq} 2>/dev/null || echo 0
echo -n SIZE_COMPILE_LOG=; wc -c < {compileq} 2>/dev/null || echo 0
echo -n SIZE_RUN_LOG=; wc -c < {runq} 2>/dev/null || echo 0
echo '--- bjobs -l ---'
bjobs -l -J {jobq} 2>/dev/null | sed -n '1,40p' || true
echo '--- key tail ---'
grep -E 'TB_RESULT|TB_TIMEOUT|TB_FATAL|TB_INFO|TB_PROGRESS|TB_STALL|TB_EDGE|DBG_|SDF_METRIC|E2E_NS=|T_router=|T_noc=|E2E_EDGE|E2E_WRAPPED|E2E_WRAPPER|E2E_PROBE|E2E_SEG|setuphold|SDF annotate|ERROR:|Error-|IFNSDFA|reusing|patching|Finished|CPU Time|VCS Compile|simv_|func patch counts|INFO: MODE=|INFO: NOC16 harness=' \
  {logq} {errq} {compileq} {runq} 2>/dev/null | tail -80
echo '--- stderr tail ---'
grep -v 'ModuleCmd_Load.c.*ERROR:105' {errq} 2>/dev/null | tail -40 || true
""".format(
                jobq=shquote(job),
                logq=shquote(log),
                errq=shquote(errlog),
                compileq=shquote(compilelog),
                runq=shquote(runlog),
            ),
        )
        print("=== %s poll %d (every %ds) ===" % (label, i, sleep_s))
        print(text[-2400:])
        sizes = tuple(
            int(m.group(1))
            for name in ("SIZE_BSUB_LOG", "SIZE_BSUB_ERR", "SIZE_COMPILE_LOG", "SIZE_RUN_LOG")
            for m in [re.search(r"%s=(\d+)" % name, text)]
            if m
        )
        state_match = re.search(r"JOB_STATE=(\S+)", text)
        job_state = state_match.group(1) if state_match else "UNKNOWN"
        if all(n in text for n in needles):
            return True
        filtered_err = "\n".join(
            line for line in text.splitlines() if "ModuleCmd_Load.c" not in line
        )
        if "IFNSDFA" in text or "Illegal FileName for $sdf_annotate" in text:
            return False
        if "TB_RESULT FAIL" in text or "TB_FATAL" in text:
            return False
        if "ERROR:" in filtered_err or "Error-" in filtered_err:
            return False
        if "TB_TIMEOUT" in text and job_state == "NO_JOB":
            return False
        if job_state == "NO_JOB" and i > 0 and "TB_RESULT" not in text:
            return False
        if job_state == "RUN":
            if sizes and sizes == last_sizes:
                stagnant += 1
            else:
                stagnant = 0
            last_sizes = sizes
            if stagnant >= 3:
                print("STALL_DETECTED: logs did not grow for three consecutive RUN polls")
                return False
        if i + 1 < max_polls:
            time.sleep(sleep_s)
    return False


def main():
    stage = os.environ.get(
        "GLS_SMOKE_STAGE", "all"
    )  # all|rtl_noc16_case|func|func_noc16|func_noc16_case|sdf|sdf_noc16|sdf_noc16_case|...|upload
    c = connect()
    try:
        upload(c, refresh_sdf_netlists=(stage != "rtl_noc16_case"))
        print("UPLOAD_DONE")
        if stage == "upload":
            return
        run(c, "bkill -J 'async_gls*' 2>/dev/null; sleep 2; true")

        if stage in ("all", "func"):
            submit(c, "func", "routerl1", "async_gls_smoke_func_routerl1")
            ok = poll(c, "func", "routerl1", ["TB_RESULT PASS"], "FUNC_R1")
            print("FUNC_R1_PASS" if ok else "FUNC_R1_FAIL")
            if not ok:
                return
            submit(c, "func", "noc16", "async_gls_smoke_func_noc16")
            ok = poll(c, "func", "noc16", ["TB_RESULT PASS"], "FUNC_N16")
            print("FUNC_N16_PASS" if ok else "FUNC_N16_FAIL")
            if not ok:
                return

        if stage == "func_noc16":
            os.environ["GLS_E2E_PROBE"] = "1"
            submit(c, "func", "noc16", "async_gls_smoke_func_noc16")
            ok = poll(c, "func", "noc16", ["TB_RESULT PASS", "E2E_EDGE_REQ_NS="], "FUNC_N16", max_polls=24)
            print("FUNC_N16_PASS" if ok else "FUNC_N16_FAIL")
            return

        if stage == "func_noc16_case":
            all_ok = True
            for case_arg in noc16_case_args_from_env():
                ok = run_noc16_case(
                    c,
                    "func",
                    case_arg,
                    os.environ.get("GLS_NOC16_TIMEOUT_SCALE", "5"),
                )
                all_ok = all_ok and ok
                if not ok:
                    break
            print("FUNC_N16_CASE_PASS" if all_ok else "FUNC_N16_CASE_FAIL")
            return

        if stage == "rtl_noc16_case":
            all_ok = True
            for case_arg in noc16_case_args_from_env():
                ok = run_noc16_case(
                    c, "rtl", case_arg,
                    os.environ.get("GLS_NOC16_TIMEOUT_SCALE", "5"),
                )
                all_ok = all_ok and ok
                if not ok:
                    break
            print("RTL_N16_CASE_PASS" if all_ok else "RTL_N16_CASE_FAIL")
            return

        if stage == "sdf_routerl1_probe":
            os.environ["GLS_E2E_PROBE"] = "1"
            os.environ.setdefault("GLS_PROBE", "1")
            submit(c, "sdf", "routerl1", "async_gls_smoke_sdf_routerl1")
            ok = poll(
                c,
                "sdf",
                "routerl1",
                ["TB_RESULT PASS", "E2E_EDGE_REQ_NS=", "E2E_EDGE_VALID_NS="],
                "SDF_R1_PROBE",
                max_polls=48,
                sleep_s=60,
            )
            print("SDF_R1_PROBE_PASS" if ok else "SDF_R1_PROBE_FAIL")
            # Always dump pulse-width / probe snippets for 1x DEL250 experiments.
            print(
                run(
                    c,
                    """
grep -E 'TB_RESULT|GLS_PW|GLS_PROBE_DEMUX|E2E_EDGE|T_router=|TB_TIMEOUT|TB_MATCH|TB_INJECT' \
  {P}/logs/gls_smoke_sdf_routerl1_bsub.log {P}/logs/gls_routerl1_sdf_run.log 2>/dev/null | tail -80
""".format(
                        P=P
                    ),
                )
            )
            return

        if stage == "sdf_routerl1":
            submit(c, "sdf", "routerl1", "async_gls_smoke_sdf_routerl1")
            ok = poll(
                c,
                "sdf",
                "routerl1",
                ["TB_RESULT PASS", "T_router="],
                "SDF_R1",
                max_polls=48,
                sleep_s=60,
            )
            print("SDF_R1_PASS" if ok else "SDF_R1_FAIL")
            print(
                run(
                    c,
                    """
grep -E 'TB_RESULT|E2E_|T_router=|TB_TIMEOUT|setuphold' \
  {P}/logs/gls_smoke_sdf_routerl1_bsub.log {P}/logs/gls_routerl1_sdf_run.log 2>/dev/null | tail -40
""".format(
                        P=P
                    ),
                )
            )
            return

        if stage == "func_wormhole_minimal":
            os.environ.setdefault("GLS_PROBE", "1")
            submit(c, "func", "wormhole_minimal", "async_gls_smoke_func_wormhole")
            ok = poll(
                c,
                "func",
                "wormhole_minimal",
                ["TB_RESULT PASS", "SDF_METRIC"],
                "FUNC_WORMHOLE",
                max_polls=24,
                sleep_s=60,
            )
            print("FUNC_WORMHOLE_PASS" if ok else "FUNC_WORMHOLE_FAIL")
            return

        if stage == "sdf_wormhole_minimal":
            os.environ.setdefault("GLS_PROBE", "1")
            submit(c, "sdf", "wormhole_minimal", "async_gls_smoke_sdf_wormhole")
            ok = poll(
                c,
                "sdf",
                "wormhole_minimal",
                ["TB_RESULT PASS", "SDF_METRIC"],
                "SDF_WORMHOLE",
                max_polls=48,
                sleep_s=60,
            )
            print("SDF_WORMHOLE_PASS" if ok else "SDF_WORMHOLE_FAIL")
            print(
                run(
                    c,
                    """
grep -E 'TB_RESULT|SDF_METRIC|setuphold|TB_TIMEOUT|ERROR' \
  {P}/logs/gls_smoke_sdf_wormhole_minimal_bsub.log {P}/logs/gls_wormhole_minimal_sdf_run.log 2>/dev/null | tail -240
""".format(P=P),
                )
            )
            return

        if stage in ("all", "sdf", "sdf_noc16", "sdf_noc16_probe"):
            if stage != "sdf_noc16":
                submit(c, "sdf", "routerl1", "async_gls_smoke_sdf_routerl1")
                ok = poll(
                    c,
                    "sdf",
                    "routerl1",
                    ["TB_RESULT PASS", "T_router="],
                    "SDF_R1",
                    max_polls=48,
                )
                chk = run(
                    c,
                    "grep -c setuphold %s/logs/gls_routerl1_sdf_run.log 2>/dev/null || echo 0" % P,
                )
                print("setuphold_count", chk.strip())
                print("SDF_R1_PASS" if ok else "SDF_R1_FAIL")
                if not ok:
                    return
            if stage in ("sdf_noc16", "sdf_noc16_probe"):
                os.environ["GLS_E2E_PROBE"] = "1"
            submit(c, "sdf", "noc16", "async_gls_smoke_sdf_noc16")
            ok = poll(
                c,
                "sdf",
                "noc16",
                ["TB_RESULT PASS", "E2E_EDGE_REQ_NS=", "E2E_EDGE_VALID_NS="] if stage in ("sdf_noc16", "sdf_noc16_probe") else ["TB_RESULT PASS", "T_noc="],
                "SDF_N16",
                max_polls=48,
            )
            print("SDF_N16_PASS" if ok else "SDF_N16_FAIL")
        if stage == "sdf_noc16_case":
            all_ok = True
            for case_arg in noc16_case_args_from_env():
                ok = run_noc16_case(
                    c,
                    "sdf",
                    case_arg,
                    os.environ.get("GLS_NOC16_TIMEOUT_SCALE", "20"),
                )
                all_ok = all_ok and ok
                if not ok:
                    break
            print("SDF_N16_CASE_PASS" if all_ok else "SDF_N16_CASE_FAIL")
            return
        if stage == "timing":
            text = run(c, """
cd {P}
: > logs/pt_noc16_e2e_timing.log; : > logs/pt_noc16_e2e_timing.err
/soft/synopsys/prime/V-2023.12/bin/pt_shell -f scripts/timing/run_pt_noc16_e2e_timing.tcl \
  > logs/pt_noc16_e2e_timing.log 2> logs/pt_noc16_e2e_timing.err
tail -80 logs/pt_noc16_e2e_timing.log
echo '=== err ==='
tail -40 logs/pt_noc16_e2e_timing.err
ls -la reports/NoC_16nodes/timing_e2e_00_to_33_*.rpt 2>/dev/null
""".format(P=P))
            print(text[-5000:])
    finally:
        c.close()


if __name__ == "__main__":
    main()

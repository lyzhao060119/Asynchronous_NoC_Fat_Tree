#!/usr/bin/env python3
"""Frozen-manifest remote DC + strict SDF NoC16 runs for Ultra.

The canonical AXI/BRAM wrapper and testcase TB are deliberately uploaded as
source and used unchanged in VCS, matching the local xsim platform.
"""
import base64, hashlib, json, os, re, shlex, sys, time
from datetime import datetime
from pathlib import Path
import paramiko

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get("ULTRA_NOC16_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_noc16_sdf")
PROFILE = os.environ.get("ULTRA_DELAY_PROFILE", "ULTRA_P250_PRS_ACG_OPM75")
DEFAULT_CASES = ("TAB-NET-UR-3f-r0p02", "VCTM-MC5-NM-3f-r0p02")
CASES = tuple(name for name in re.split(r"[,\s]+", os.environ.get(
    "ULTRA_NOC16_CASE_LIST", ",".join(DEFAULT_CASES)).strip()) if name)
if not CASES:
    raise SystemExit("ULTRA_NOC16_CASE_LIST selected no cases")
RESULT = REPO / "scripts" / "asic_dc" / "ultra" / "results" / RUN_ID

def password():
    if os.environ.get("C1_PASS"): return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        # The repository documents are UTF-8.  Keep this Unicode spelling
        # here rather than the mojibake pattern inherited by an old runner.
        m = re.search(r"^[ \t-]*密码\s*[:：]\s*(\S+)", doc.read_text(encoding="utf-8", errors="replace"), re.M)
        if m: return m.group(1)
    raise SystemExit("Set C1_PASS or add the configured password entry in docs")
def run(c, cmd):
    # Drain a single combined stream.  Sequential stdout/stderr reads can
    # deadlock when LSF emits environment diagnostics while bsub is returning.
    _, o, _ = c.exec_command(cmd)
    o.channel.set_combine_stderr(True)
    return o.read().decode(errors="replace")
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def put(c, sftp, source, remote):
    data = source.read_bytes().replace(b"\r\n", b"\n"); temp = remote + ".upload"
    expected = hashlib.sha256(data).hexdigest()
    existing = re.findall(r"\b[0-9a-f]{64}\b", run(c, "sha256sum %s 2>/dev/null" % shlex.quote(remote)))
    if expected in existing:
        return
    with sftp.file(temp, "wb") as f:
        # The course SFTP service does not reliably drain a large pipelined
        # write.  Keep each packet committed before issuing the next one.
        for off in range(0, len(data), 8192):
            f.write(data[off:off+8192])
            f.flush()
    got = re.findall(r"\b[0-9a-f]{64}\b", run(c, "sha256sum %s" % shlex.quote(temp)))
    if expected not in got: raise RuntimeError("upload hash mismatch: " + str(source))
    try: sftp.posix_rename(temp, remote)
    except IOError: sftp.rename(temp, remote)
def put_small_atomic(c, source, remote):
    """Upload a diagnostic harness without SFTP pipelining.

    The remote service has intermittently returned a stale/truncated hash for
    short diagnostic uploads.  A single shell-side base64 decode is adequate
    for these two small files and keeps the published path atomic.
    """
    data = source.read_bytes().replace(b"\r\n", b"\n")
    expected = hashlib.sha256(data).hexdigest()
    existing = run(c, "sha256sum %s 2>/dev/null" % shlex.quote(remote)).split()
    if existing and existing[0] == expected:
        return
    payload = base64.b64encode(data).decode("ascii")
    temp = remote + ".upload"
    cmd = "printf %%s %s | base64 -d > %s && sha256sum %s && mv -f %s %s" % (
        shlex.quote(payload), shlex.quote(temp), shlex.quote(temp),
        shlex.quote(temp), shlex.quote(remote))
    output = run(c, cmd)
    hashes = re.findall(r"\b[0-9a-f]{64}\b", output)
    if expected not in hashes:
        raise RuntimeError("atomic upload hash mismatch: %s (remote=%s)" %
                           (source, " ".join(output.split()[:4])))
def wait_job(c, job, label):
    for _ in range(180):
        status = run(c, "bjobs -noheader -o stat %s 2>/dev/null" % shlex.quote(job)).strip()
        # LSF retains completed jobs as DONE/EXIT for a while.  They are
        # terminal states, not evidence that the wrapper is still running.
        if not status or re.search(r"\b(?:DONE|EXIT)\b", status):
            return
        print("%s: %s" % (label, status)); time.sleep(20)
    raise TimeoutError("job did not finish: " + job)
def connect():
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"), password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False, compress=True)
    return c
def case_file(name):
    small = REPO / "sim" / "AsyncNoC" / "testbench" / "small_cases" / (name + ".case")
    if small.exists(): return small
    for group in ("TAB_16", "VCTM_16"):
        path = REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases" / group / (name + ".case")
        if path.exists(): return path
    raise FileNotFoundError(name)
def job_id(text):
    m = re.search(r"Job <(\d+)>", text)
    if not m: raise RuntimeError("bsub failed: " + text)
    return m.group(1)

def run_async_boundary():
    """Remote DC + strict SDF for the clockless boundary platform.

    This is intentionally separate from the historical AXI/BRAM flow so its
    manifest, logs and result CSVs cannot be mistaken for wrapper results.
    """
    names = tuple(name for name in re.split(r"[,\s]+", os.environ.get(
        "ULTRA_ASYNC_BOUNDARY_CASE_LIST",
        "TAB-NET-UR-3f-r0p02,TAB-NET-UR-3f-r0p10,TAB-NET-UR-3f-r0p20,TAB-NET-UR-3f-r0p30").strip()) if name)
    run_id = os.environ.get("ULTRA_ASYNC_BOUNDARY_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_async_boundary")
    endpoint_ack_delay_ps = int(os.environ.get("ULTRA_ENDPOINT_ACK_DELAY_PS", "50"))
    if endpoint_ack_delay_ps not in (50, 75, 100, 150, 250):
        raise SystemExit("ULTRA_ENDPOINT_ACK_DELAY_PS must be one of 50,75,100,150,250")
    result = REPO / "scripts" / "asic_dc" / "ultra" / "results" / run_id
    # Freeze a locally generated NoC entry under exactly the profile which
    # will be used by the unified Boundary DUT DC run.  Earlier boundary runs
    # relied on a pre-existing generated NoC, which makes role-specific DEL
    # experiments non-reproducible.
    import subprocess
    gen_env = os.environ.copy()
    gen_env["ASYNC_PRIMITIVES"] = "asic"
    gen_env["ASYNC_DELAY_PROFILE"] = PROFILE
    subprocess.run([
        os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt"),
        "runMain NoC.ultra.UltraNoC16Main"
    ], cwd=REPO, env=gen_env, check=True)
    generated = REPO / "generated_ultra"
    resources = ["DelayElement_ASIC.v", "Mutex2_ASIC.v", "MullerC2.v", "MullerC3.v", "DLatchBank.v", "V2CloseEvent.v", "AsyncEndpointAckDelay.v", "MousetrapStage.v", "TAC2.v", "Mutex3Grant.v", "Mutex5Anchor.v", "UltraHeadCaptureCell.v", "AsyncRoundMembershipCell.v", "AsyncRoundDecisionCell.v", "AsyncArbiterTransactionController.v"]
    files = {generated / "NoC_16nodes.v": "rtl/NoC_16nodes.v"}
    for name in resources: files[REPO / "src" / "main" / "resources" / "ASYNC" / name] = "rtl/" + name
    for name in ("tech_t28ss.tcl", "async_primitives.tcl", "assert_no_gtech.tcl"):
        files[REPO / "scripts" / "asic_dc" / name] = "rtl/" + name
    files.update({
        REPO / "scripts" / "asic_dc" / "ultra" / "run_dc_ultra_noc16_boundary.tcl": "scripts/dc/run_dc_ultra_noc16_boundary.tcl",
        REPO / "scripts" / "asic_dc" / "ultra" / "run_gls_ultra_noc16_async_boundary.sh": "scripts/run_gls_ultra_noc16_async_boundary.sh",
        REPO / "sim" / "AsyncNoC" / "async_noc16_port_adapter.sv": "rtl/async_noc16_port_adapter.sv",
        REPO / "sim" / "AsyncNoC" / "async_endpoint_bank20.sv": "rtl/AsyncEndpointBank20.sv",
        REPO / "sim" / "AsyncNoC" / "async_noc16_boundary_dut.sv": "rtl/AsyncNoC16BoundaryDUT.sv",
        REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc16_async_boundary.sv": "sim/tb/tb_noc16_async_boundary.sv",
    })
    cases = {name: case_file(name) for name in names}
    def put_retry(c, sftp, source, remote):
        last = None
        for _ in range(3):
            try:
                put(c, sftp, source, remote)
                return
            except RuntimeError as exc:
                last = exc
                run(c, "rm -f %s" % shlex.quote(remote + ".upload"))
                time.sleep(1)
        raise last

    c = connect()
    dirs = "rtl scripts/dc scripts sim/tb sim/cases outputs reports/dc logs/dc logs/gls results sim/work"
    run(c, "mkdir -p " + " ".join(ROOT + "/" + d for d in dirs.split()))
    sftp = c.open_sftp()
    manifest = {}
    for src, dst in files.items():
        put_retry(c, sftp, src, ROOT + "/" + dst); manifest[dst] = sha(src)
    remote_cases = {}
    for name, src in cases.items():
        remote = ROOT + "/sim/cases/" + src.name
        put_retry(c, sftp, src, remote); remote_cases[name] = remote; manifest["case/" + src.name] = sha(src)
    sftp.close(); c.close(); c = connect()
    run(c, "chmod +x %s/scripts/run_gls_ultra_noc16_async_boundary.sh; sed -i 's/\\r$//' %s/scripts/run_gls_ultra_noc16_async_boundary.sh" % (ROOT, ROOT))

    def submit_dc(label, tcl):
        path = ROOT + "/logs/dc/%s_%s.sh" % (run_id, label)
        body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nexport ULTRA_REMOTE_ROOT=%s ULTRA_NOC16_RUN_ID=%s ULTRA_ENDPOINT_ACK_DELAY_PS=%s ASYNC_DELAY_PROFILE=%s\ncd %s\nexec dc_shell-t -64 -f %s/scripts/dc/%s\n" % (ROOT, run_id, endpoint_ack_delay_ps, PROFILE, ROOT, ROOT, tcl)
        encoded = base64.b64encode(body.encode()).decode()
        run(c, "mkdir -p %s/logs/dc; echo %s | base64 -d > %s; chmod +x %s" % (ROOT, shlex.quote(encoded), path, path))
        jid = job_id(run(c, "bsub -n 8 -o %s/logs/dc/%s_%s.log -e %s/logs/dc/%s_%s.err -J ultra_async_%s_%s %s" % (ROOT, run_id, label, ROOT, run_id, label, run_id, label, path)))
        wait_job(c, jid, label)
        log = run(c, "cat %s/logs/dc/%s_%s.log %s/logs/dc/%s_%s.err 2>/dev/null" % (ROOT, run_id, label, ROOT, run_id, label))
        if "ULTRA_BOUNDARY_DC_PASS" not in log:
            raise RuntimeError("%s DC failed for %s" % (label, run_id))
        return jid

    boundary_dc = submit_dc("boundary", "run_dc_ultra_noc16_boundary.tcl")
    status = {"run_id": run_id, "mode": "async_boundary_single_top", "endpoint_ack_delay_ps": endpoint_ack_delay_ps, "manifest": manifest, "dc": {"boundary": boundary_dc}, "cases": {}}
    for name, remote_case in remote_cases.items():
        wrapper = ROOT + "/logs/gls/%s/async_%s.sh" % (run_id, name)
        body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nexport ULTRA_REMOTE_ROOT=%s ULTRA_NOC16_RUN_ID=%s ULTRA_NOC16_CASE_NAME=%s ULTRA_NOC16_CASE_FILE=%s\nexec bash %s/scripts/run_gls_ultra_noc16_async_boundary.sh\n" % (ROOT, run_id, shlex.quote(name), shlex.quote(remote_case), ROOT)
        encoded = base64.b64encode(body.encode()).decode()
        run(c, "mkdir -p %s/logs/gls/%s; echo %s | base64 -d > %s; chmod +x %s" % (ROOT, run_id, shlex.quote(encoded), wrapper, wrapper))
        jid = job_id(run(c, "bsub -n 8 -o %s/logs/gls/%s/async_%s.bsub.log -e %s/logs/gls/%s/async_%s.bsub.err -J ultra_async_sdf_%s_%s %s" % (ROOT, run_id, name, ROOT, run_id, name, run_id, name, wrapper)))
        status["cases"][name] = {"job_id": jid}
    for name, state in status["cases"].items():
        wait_job(c, state["job_id"], "sdf " + name)
        log = run(c, "cat %s/logs/gls/%s/async_sdf/%s/run.log %s/logs/gls/%s/async_sdf/%s/compile.log 2>/dev/null" % (ROOT, run_id, name, ROOT, run_id, name))
        state["tb_pass"] = "TB_RESULT PASS" in log
        state["boundary_sdf_done"] = "boundary_sdf_annotate.log" in log or "Doing SDF annotation ...... Done" in log
        state["ifnsdfa"] = "IFNSDFA" in log
        print(name, "PASS" if state["tb_pass"] else "FAIL", flush=True)
    result.mkdir(parents=True, exist_ok=True)
    (result / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    c.close()
    if not all(v["tb_pass"] and not v["ifnsdfa"] for v in status["cases"].values()): sys.exit(2)

def main():
    if "--async-boundary" in sys.argv:
        run_async_boundary(); return
    if "--status" in sys.argv:
        c = connect()
        cmd = (
            "bjobs -a -u $USER 2>/dev/null | grep %s || true; "
            "find %s/logs/gls/%s -type f -printf '%%p %%s bytes\\n' 2>/dev/null; "
            "find %s/logs/gls/%s -type f \\( -name run.log -o -name '*.err' -o -name '*.bsub.log' \\) "
            "-exec sh -c 'echo ---$1; tail -50 $1' sh {} \\; 2>/dev/null"
        ) % (shlex.quote(RUN_ID), ROOT, RUN_ID, ROOT, RUN_ID)
        print(run(c, cmd)); c.close(); return
    if "--diagnose-tab" in sys.argv:
        c = connect()
        base = ROOT + "/logs/gls/" + RUN_ID
        cmd = (
            "grep -nEi 'timing violation|\\$hold|\\$setup|warning|error|TB_DEBUG unexpected|TB_RESULT' "
            "%s/rerun_TAB-NET-UR-3f-r0p02.bsub.log "
            "%s/sdf/TAB-NET-UR-3f-r0p02/compile.log "
            "%s/sdf/TAB-NET-UR-3f-r0p02/run.log 2>/dev/null | head -240"
        ) % (base, base, base)
        print(run(c, cmd)); c.close(); return
    if "--rerun-sdf" in sys.argv:
        # Reuse the already frozen DC netlist/SDF and the same GLS command
        # used by the previous NoC16 regression.  bsub -K is the completion
        # mechanism; no custom polling or dependency state machine is used.
        # Only the diagnosis harness is refreshed; the DUT netlist/SDF and
        # case are deliberately left untouched.
        c = connect()
        for source, remote in {
            REPO / "scripts" / "asic_dc" / "ultra" / "run_gls_ultra_noc16.sh": ROOT + "/scripts/run_gls_ultra_noc16.sh",
            REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc16_async_axi_bram.sv": ROOT + "/sim/tb/tb_noc16_async_axi_bram.sv",
        }.items():
            put_small_atomic(c, source, remote)
        # A rerun reuses the frozen netlist, but it must still publish every
        # requested case: the original low-load DC run may have uploaded only
        # r0p02.
        if os.environ.get("ULTRA_NOC16_RERUN_UPLOAD_CASES", "1") == "1":
            for name in CASES:
                source = case_file(name)
                put_small_atomic(c, source, ROOT + "/sim/cases/" + source.name)
        run(c, "chmod +x %s/scripts/run_gls_ultra_noc16.sh; sed -i 's/\\r$//' %s/scripts/run_gls_ultra_noc16.sh" % (ROOT, ROOT))
        for name in CASES:
            remote_case = ROOT + "/sim/cases/" + case_file(name).name
            job_log = ROOT + "/logs/gls/" + RUN_ID + "/rerun_" + name + ".bsub.log"
            job_err = ROOT + "/logs/gls/" + RUN_ID + "/rerun_" + name + ".bsub.err"
            inner = (
                "export ULTRA_REMOTE_ROOT=%s ULTRA_NOC16_RUN_ID=%s "
                "ULTRA_NOC16_NETLIST_RUN_ID=%s "
                "ULTRA_NOC16_CASE_NAME=%s ULTRA_NOC16_CASE_FILE=%s "
                "ULTRA_NOC16_TAB_TRACE=%s "
                "ULTRA_NOC16_TAB_TRACE_PORT=%s ULTRA_NOC16_TAB_TRACE_PKT=%s; "
                "exec bash %s/scripts/run_gls_ultra_noc16.sh"
            ) % (ROOT, RUN_ID,
                 shlex.quote(os.environ.get("ULTRA_NOC16_NETLIST_RUN_ID", RUN_ID)),
                 shlex.quote(name), shlex.quote(remote_case),
                 "1" if name.startswith("TAB-") and os.environ.get("ULTRA_NOC16_ENABLE_TAB_TRACE", "0") == "1" else "0",
                 shlex.quote(os.environ.get("ULTRA_NOC16_TAB_TRACE_PORT", "6")),
                 shlex.quote(os.environ.get("ULTRA_NOC16_TAB_TRACE_PKT", "89")), ROOT)
            submit = "mkdir -p %s/logs/gls/%s; bsub -K -n 8 -o %s -e %s -J ultra_noc16_rerun_%s_%s bash -lc %s" % (
                ROOT, RUN_ID, job_log, job_err, RUN_ID, name, shlex.quote(inner))
            print("RUNNING", name, flush=True)
            print(run(c, submit), flush=True)
            result_log = ROOT + "/logs/gls/" + RUN_ID + "/sdf/" + name + "/run.log"
            result = run(c, "cat %s 2>/dev/null || true" % shlex.quote(result_log))
            print(result, flush=True)
            if "TB_RESULT PASS" not in result:
                c.close(); raise SystemExit("NoC16 strict-SDF failed: " + name)
        c.close(); return
    import subprocess
    env = os.environ.copy(); env["ASYNC_PRIMITIVES"] = "asic"; env["ASYNC_DELAY_PROFILE"] = PROFILE
    subprocess.run([os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt"), "runMain NoC.ultra.UltraNoC16Main"], cwd=REPO, env=env, check=True)
    generated = REPO / "generated_ultra"
    resources = ["DelayElement_ASIC.v", "Mutex2_ASIC.v", "MullerC2.v", "MullerC3.v", "DLatchBank.v", "V2CloseEvent.v", "AsyncEndpointAckDelay.v", "MousetrapStage.v", "TAC2.v", "Mutex3Grant.v", "Mutex5Anchor.v", "UltraHeadCaptureCell.v", "AsyncRoundMembershipCell.v", "AsyncRoundDecisionCell.v", "AsyncArbiterTransactionController.v"]
    files = {generated / "NoC_16nodes.v": "rtl/NoC_16nodes.v"}
    for name in resources: files[REPO / "src" / "main" / "resources" / "ASYNC" / name] = "rtl/" + name
    for name in ("tech_t28ss.tcl", "async_primitives.tcl", "assert_no_gtech.tcl"):
        files[REPO / "scripts" / "asic_dc" / name] = "rtl/" + name
    files.update({
      REPO / "scripts" / "asic_dc" / "ultra" / "run_dc_ultra_noc16.tcl": "scripts/dc/run_dc_ultra_noc16.tcl",
      REPO / "scripts" / "asic_dc" / "ultra" / "run_gls_ultra_noc16.sh": "scripts/run_gls_ultra_noc16.sh",
      REPO / "sim" / "AsyncNoC" / "async_noc16_axi_bram_wrapper.sv": "sim/tb/async_noc16_axi_bram_wrapper.sv",
      REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc16_async_axi_bram.sv": "sim/tb/tb_noc16_async_axi_bram.sv",
    })
    cases = {name: case_file(name) for name in CASES}
    # LSF opens -o/-e before executing the wrapper.  The per-run GLS parent
    # must therefore exist at submission time, not only inside the wrapper.
    c = connect(); dirs = ("rtl scripts/dc scripts sim/tb sim/cases outputs reports/dc logs/dc logs/gls logs/gls/%s results/%s/csv sim/work" % (RUN_ID, RUN_ID))
    run(c, "mkdir -p " + " ".join(ROOT + "/" + d for d in dirs.split()))
    skip_upload = os.environ.get("ULTRA_NOC16_SKIP_UPLOAD", "0") == "1"
    manifest = {dst: sha(src) for src, dst in files.items()}
    remote_cases = {name: ROOT + "/sim/cases/" + src.name for name, src in cases.items()}
    if skip_upload:
        print("INFO using pre-uploaded frozen NoC16 manifest", flush=True)
    else:
        sftp = c.open_sftp()
        for src, dst in files.items():
            print("UPLOAD", dst, flush=True)
            put(c, sftp, src, ROOT + "/" + dst)
        for name, src in cases.items():
            remote = remote_cases[name]
            print("UPLOAD", "case/" + src.name, flush=True)
            put(c, sftp, src, remote); manifest["case/" + src.name] = sha(src)
        # This server does not reliably accept exec channels after a large
        # SFTP session.  Reconnect before DC/LSF.
        sftp.get_channel().close()
        c.close()
        c = connect()
    if not skip_upload:
        run(c, "chmod +x %s/scripts/run_gls_ultra_noc16.sh; sed -i 's/\\r$//' %s/scripts/run_gls_ultra_noc16.sh" % (ROOT, ROOT))
    dc_script = ROOT + "/logs/dc/%s.sh" % RUN_ID
    dc_body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nexport ULTRA_REMOTE_ROOT=%s ULTRA_NOC16_RUN_ID=%s ASYNC_DELAY_PROFILE=%s\ncd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_ultra_noc16.tcl\n" % (ROOT, RUN_ID, shlex.quote(PROFILE), ROOT, ROOT)
    run(c, "mkdir -p %s/logs/dc; printf %%s %s > %s; chmod +x %s" % (ROOT, shlex.quote(dc_body), dc_script, dc_script))
    print("SUBMIT_DC", flush=True)
    dc = job_id(run(c, "bsub -n 8 -o %s/logs/dc/%s.log -e %s/logs/dc/%s.err -J ultra_noc16_dc_%s %s" % (ROOT, RUN_ID, ROOT, RUN_ID, RUN_ID, dc_script)))
    print("DC_JOB", dc); wait_job(c, dc, "dc")
    dc_log = run(c, "cat %s/logs/dc/%s.log %s/logs/dc/%s.err 2>/dev/null" % (ROOT, RUN_ID, ROOT, RUN_ID))
    if "ULTRA_NOC16_DC_PASS" not in dc_log: raise RuntimeError("DC did not pass; see remote logs for run " + RUN_ID)
    status = {"run_id": RUN_ID, "remote_root": ROOT, "delay_profile": PROFILE, "manifest": manifest, "dc_job": dc, "cases": {}}
    for name, remote_case in remote_cases.items():
        wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (RUN_ID, name)
        body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nexport ULTRA_REMOTE_ROOT=%s ULTRA_NOC16_RUN_ID=%s ULTRA_NOC16_CASE_NAME=%s ULTRA_NOC16_CASE_FILE=%s\nexec bash %s/scripts/run_gls_ultra_noc16.sh\n" % (ROOT, RUN_ID, shlex.quote(name), shlex.quote(remote_case), ROOT)
        # LSF on this host treats -env as a command token, so publish an
        # explicit per-case wrapper instead of relying on scheduler env syntax.
        encoded = base64.b64encode(body.encode("utf-8")).decode("ascii")
        run(c, "echo %s | base64 -d > %s; chmod +x %s" %
            (shlex.quote(encoded), shlex.quote(wrapper), shlex.quote(wrapper)))
        jid = job_id(run(c, "bsub -n 8 -o %s/logs/gls/%s/sdf_%s.bsub.log -e %s/logs/gls/%s/sdf_%s.bsub.err -J ultra_noc16_sdf_%s_%s %s" % (ROOT, RUN_ID, name, ROOT, RUN_ID, name, RUN_ID, name, wrapper)))
        status["cases"][name] = {"job_id": jid, "remote_case": remote_case}; print("SDF_JOB", name, jid)
    for name, state in status["cases"].items(): wait_job(c, state["job_id"], "sdf " + name)
    for name in status["cases"]:
        text = run(c, "cat %s/logs/gls/%s/sdf/%s/run.log %s/logs/gls/%s/sdf/%s/compile.log 2>/dev/null" % (ROOT, RUN_ID, name, ROOT, RUN_ID, name))
        status["cases"][name]["tb_pass"] = "TB_RESULT PASS" in text
        status["cases"][name]["sdf_done"] = "Doing SDF annotation ...... Done" in text
        status["cases"][name]["ifnsdfa"] = "IFNSDFA" in text
        print(name, "PASS" if status["cases"][name]["tb_pass"] else "FAIL")
    RESULT.mkdir(parents=True, exist_ok=True); (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = c.open_sftp()
    def collect(remote, local):
        local.mkdir(parents=True, exist_ok=True)
        for ent in sftp.listdir_attr(remote):
            rp = remote + "/" + ent.filename; lp = local / ent.filename
            if ent.st_mode & 0o40000: collect(rp, lp)
            else: sftp.get(rp, str(lp))
    for folder in ("outputs", "reports/dc", "logs/dc", "logs/gls", "results"):
        try: collect(ROOT + "/" + folder + "/" + RUN_ID, RESULT / folder)
        except IOError: pass
    sftp.close(); c.close()
    if not all(v["tb_pass"] and v["sdf_done"] and not v["ifnsdfa"] for v in status["cases"].values()): sys.exit(2)
if __name__ == "__main__": main()

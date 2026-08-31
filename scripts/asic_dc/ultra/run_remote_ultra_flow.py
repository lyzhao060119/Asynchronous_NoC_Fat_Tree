#!/usr/bin/env python3
"""Reproducible remote DC -> func GLS -> SDF GLS -> STA flow for UltraRouter."""
import hashlib, json, os, re, shlex, sys, tarfile, time
from datetime import datetime
from pathlib import Path
import paramiko

REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get("ULTRA_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S"))
LOCAL_RESULT = REPO / "scripts" / "asic_dc" / "ultra" / "results" / RUN_ID

def password():
    if os.environ.get("C1_PASS"): return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        m = re.search(r"^[ \t-]*密码[:：][ \t]*(\S+)", doc.read_text(encoding="utf-8", errors="replace"), re.M)
        if m: return m.group(1)
    raise SystemExit("Set C1_PASS or add docs password entry")

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(c, cmd):
    _, o, e = c.exec_command(cmd); return (o.read()+e.read()).decode(errors="replace")
def atomic_put(c, sftp, local, remote):
    """Upload via a private temporary name, verify it, then atomically publish.

    A dropped SFTP channel must never truncate the frozen remote manifest.
    """
    data = local.read_bytes().replace(b"\r\n", b"\n")
    expected = hashlib.sha256(data).hexdigest()
    temporary = "%s.upload.%d" % (remote, os.getpid())
    with sftp.file(temporary, "wb") as f:
        # The course SFTP daemon drops large pipelined writes.  Keep each
        # protocol write small while retaining the temporary-file guarantee.
        for offset in range(0, len(data), 8192):
            f.write(data[offset:offset + 8192])
            f.flush()
    if sftp.stat(temporary).st_size != len(data):
        raise RuntimeError("partial upload: %s" % remote)
    observed = run(c, "sha256sum %s" % shlex.quote(temporary)).split()
    if not observed or observed[0] != expected:
        raise RuntimeError("remote SHA-256 mismatch: %s" % remote)
    try:
        sftp.posix_rename(temporary, remote)
    except IOError:
        sftp.rename(temporary, remote)
def poll(c, job):
    for _ in range(80):
        state = run(c, "bjobs -noheader -o stat %s 2>/dev/null" % shlex.quote(job)).strip()
        if not state: return "DONE"
        time.sleep(30)
    return "POLL_TIMEOUT"
def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for ent in sftp.listdir_attr(remote):
        rp, lp = remote + "/" + ent.filename, local / ent.filename
        if ent.filename in (".", ".."): continue
        if ent.st_mode & 0o40000: fetch_tree(sftp, rp, lp)
        else: sftp.get(rp, str(lp))

def archive_text(archive, member):
    with tarfile.open(archive, "r:gz") as tf:
        try:
            return tf.extractfile(member).read().decode(errors="replace")
        except KeyError:
            return ""

def write_summary(archive, target, run_id):
    dc = archive_text(archive, "logs/dc/%s.log" % run_id)
    func = archive_text(archive, "logs/gls/%s/func/run.log" % run_id)
    sdf_logs = {}
    with tarfile.open(archive, "r:gz") as tf:
        prefix = "logs/gls/%s/sdf/" % run_id
        for name in tf.getnames():
            if name.startswith(prefix) and name.endswith("/run.log") and "/gap" in name:
                relative = name[len(prefix):]
                case_name, gap_part, _ = relative.split("/", 2)
                gap = gap_part.removeprefix("gap")
                sdf_logs[case_name + ":" + gap] = tf.extractfile(name).read().decode(errors="replace")
    # Backward-compatible lookup for old one-shot runs.
    if not sdf_logs:
        sdf_logs["0"] = archive_text(archive, "logs/gls/%s/sdf/run.log" % run_id)
    sdf = sdf_logs.get("unicast3:0", next(iter(sdf_logs.values()), ""))
    sta = archive_text(archive, "logs/sta/%s.log" % run_id)
    first_fail = lambda text: next((line for line in text.splitlines()
                                    if "TB_RESULT FAIL" in line or "TB_FAIL" in line), None)
    sdf_all_pass = bool(sdf_logs) and all("TB_RESULT PASS" in text for text in sdf_logs.values())
    sdf_all_x_free = bool(sdf_logs) and all("TB_X_FAIL" not in text for text in sdf_logs.values())
    summary = {
        "run_id": run_id,
        "remote_root": ROOT,
        "dc": {"pass": "ULTRA_DC_PASS" in dc, "gtech_zero": "GTECH cell count after compile = 0" in dc},
        "func_gls": {
            "tb_pass": "TB_RESULT PASS" in func,
            "x_free": bool(func) and "TB_X_FAIL" not in func,
            "first_failure": first_fail(func),
        },
        "sdf_gls": {
            "annotation_done": bool(sdf_logs) and all("Doing SDF annotation ...... Done" in text for text in sdf_logs.values()),
            "ifnsdfa": any("IFNSDFA" in text for text in sdf_logs.values()),
            "x_free": sdf_all_x_free,
            "tb_pass": sdf_all_pass,
            "first_failure": first_fail(sdf),
            "gaps": {gap: {"tb_pass": "TB_RESULT PASS" in text,
                             "first_failure": first_fail(text)}
                     for gap, text in sorted(sdf_logs.items())},
        },
        "sta": {
            "done": "ULTRA_STA_DONE" in sta,
            "del250_count": int(re.search(r"DEL250_COUNT=(\d+)", sta).group(1)) if re.search(r"DEL250_COUNT=(\d+)", sta) else None,
            "timing_loops_reported": "timing loops detected" in archive_text(archive, "reports/sta/%s/check_timing.rpt" % run_id),
        },
        "archive": archive.name,
    }
    (target / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary

def main():
    if "--timing" in sys.argv:
        run_id = sys.argv[sys.argv.index("--timing") + 1]
        c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        c.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"), password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False)
        case_name = sys.argv[sys.argv.index("--timing") + 2] if len(sys.argv) > sys.argv.index("--timing") + 2 else "unicast3"
        log = "%s/logs/gls/%s/sdf/%s/gap0/run.log" % (ROOT, run_id, case_name)
        print(run(c, "[ -f %s ] && grep 'TB_FLIT_' %s || echo TIMING_LOG_MISSING" % (shlex.quote(log), shlex.quote(log))))
        c.close(); return
    if "--status" in sys.argv:
        c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        c.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"), password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False)
        run_filter = os.environ.get("ULTRA_RUN_ID")
        if run_filter:
            command = (
                "bjobs -a -u $USER 2>/dev/null | grep %s || true; "
                "find %s/logs/gls/%s -type f -printf '%%p %%s bytes\\n' 2>/dev/null; "
                "for f in %s/logs/dc/%s.log %s/logs/func/%s.log "
                "%s/logs/sdf/%s.log %s/logs/sta/%s.log "
                "%s/logs/gls/%s/func/run.log %s/logs/gls/%s/sdf/compile.log "
                "%s/logs/gls/%s/sdf/run.log; do "
                "[ -f \"$f\" ] && echo ---$f && tail -80 \"$f\"; done"
            ) % (shlex.quote(run_filter), ROOT, run_filter,
                 ROOT, run_filter, ROOT, run_filter, ROOT, run_filter,
                 ROOT, run_filter, ROOT, run_filter, ROOT, run_filter, ROOT, run_filter)
        else:
            command = "bjobs -u $USER 2>/dev/null | grep ultra_ || true; find %s/logs -maxdepth 3 -type f -printf '%%p %%s\\n' 2>/dev/null | tail -30; find %s/logs -type f -name '*.log' -exec sh -c 'echo ---$1; tail -30 $1' sh {} \\; 2>/dev/null | tail -180" % (ROOT, ROOT)
        print(run(c, command)); c.close(); return
    if "--collect" in sys.argv:
        run_id = sys.argv[sys.argv.index("--collect") + 1]
        c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        c.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"), password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False)
        target = REPO / "scripts" / "asic_dc" / "ultra" / "results" / run_id; target.mkdir(parents=True, exist_ok=True)
        archive = "%s/results/%s/artifacts.tgz" % (ROOT, run_id)
        run(c, "mkdir -p %s/results/%s; cd %s && tar -czf %s outputs/%s reports/dc/%s reports/sta/%s logs/dc/%s.* logs/func/%s.* logs/sdf/%s.* logs/sta/%s.* logs/gls/%s 2>/dev/null || true" % (ROOT, run_id, ROOT, archive, run_id, run_id, run_id, run_id, run_id, run_id, run_id, run_id))
        sftp = c.open_sftp(); local_archive = target / "artifacts.tgz"; sftp.get(archive, str(local_archive)); sftp.close(); c.close()
        print(json.dumps(write_summary(local_archive, target, run_id), indent=2)); print(target); return
    env = os.environ.copy(); env["ASYNC_PRIMITIVES"] = "asic"
    # OPM V2 control margin is now explicit RTL.  Sweep it by regenerating
    # the frozen entry with this profile; never stack a post-map ECO.
    delay_profile = os.environ.get("ULTRA_DELAY_PROFILE", "ULTRA_P250_PRS_ACG_OPM0")
    env["ASYNC_DELAY_PROFILE"] = delay_profile
    eco_delay = "NONE"
    eco_targets = ""
    # Generation is deliberately local; remote receives only a frozen manifest.
    import subprocess
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    subprocess.run([sbt, "runMain Router_Architecture.ultra.UltraRouterMain"], cwd=REPO, env=env, check=True)
    files = {
      REPO / "generated_ultra" / "UltraRouter.v": "rtl/UltraRouter.v",
      REPO / "src/main/resources/ASYNC/DelayElement_ASIC.v": "rtl/DelayElement_ASIC.v",
      REPO / "src/main/resources/ASYNC/Mutex2_ASIC.v": "rtl/Mutex2_ASIC.v",
      REPO / "src/main/resources/ASYNC/MullerC2.v": "rtl/MullerC2.v",
      REPO / "src/main/resources/ASYNC/MullerC3.v": "rtl/MullerC3.v",
      REPO / "src/main/resources/ASYNC/DLatchBank.v": "rtl/DLatchBank.v",
      REPO / "src/main/resources/ASYNC/V2CloseEvent.v": "rtl/V2CloseEvent.v",
      REPO / "src/main/resources/ASYNC/MousetrapStage.v": "rtl/MousetrapStage.v",
      REPO / "src/main/resources/ASYNC/TAC2.v": "rtl/TAC2.v",
      REPO / "src/main/resources/ASYNC/Mutex3Grant.v": "rtl/Mutex3Grant.v",
      REPO / "src/main/resources/ASYNC/Mutex5Anchor.v": "rtl/Mutex5Anchor.v",
      REPO / "src/main/resources/ASYNC/UltraHeadCaptureCell.v": "rtl/UltraHeadCaptureCell.v",
      REPO / "src/main/resources/ASYNC/AsyncRoundMembershipCell.v": "rtl/AsyncRoundMembershipCell.v",
      REPO / "src/main/resources/ASYNC/AsyncRoundDecisionCell.v": "rtl/AsyncRoundDecisionCell.v",
      REPO / "src/main/resources/ASYNC/AsyncArbiterTransactionController.v": "rtl/AsyncArbiterTransactionController.v",
      REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
      REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
      REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
      REPO / "scripts/asic_dc/ultra/async_ultra_router.sdc": "rtl/async_ultra_router.sdc",
      REPO / "scripts/asic_dc/ultra/async_ultra_router_dfire_control.sdc": "rtl/async_ultra_router_dfire_control.sdc",
      REPO / "scripts/asic_dc/ultra/async_ultra_router_datapath.sdc": "rtl/async_ultra_router_datapath.sdc",
      REPO / "scripts/asic_dc/ultra/async_ultra_opm_datapath.sdc": "rtl/async_ultra_opm_datapath.sdc",
      REPO / "scripts/asic_dc/ultra/create_ultra_datapath_targets.py": "scripts/create_ultra_datapath_targets.py",
      REPO / "scripts/asic_dc/ultra/run_dc_ultra_router.tcl": "scripts/dc/run_dc_ultra_router.tcl",
      REPO / "scripts/asic_dc/ultra/run_sta_ultra_router.tcl": "scripts/sta/run_sta_ultra_router.tcl",
      REPO / "scripts/asic_dc/ultra/run_gls_ultra_router.sh": "scripts/run_gls_ultra_router.sh",
      REPO / "scripts/asic_dc/sim_gls/patch_gls_netlist.py": "scripts/patch_gls_netlist.py",
      REPO / "sim/AsyncRouterL1/testbench/tb_ultra_router_boundary_smoke.sv": "sim/tb/tb_ultra_router_boundary_smoke.sv",
      REPO / "sim/AsyncRouterL1/testbench/tb_ultra_router_rtc_all_edges.sv": "sim/tb/tb_ultra_router_rtc_all_edges.sv",
    }
    # Phase-3 generated data targets are an immutable input to the remote run,
    # just like the frozen RTL and SDC.  Keep this optional so legacy flows
    # retain their exact upload manifest.
    dp_local_target = os.environ.get("ULTRA_DATAPATH_LOCAL_TARGET")
    if dp_local_target:
        dp_path = Path(dp_local_target)
        if not dp_path.is_file():
            raise SystemExit("ULTRA_DATAPATH_LOCAL_TARGET is not a file: %s" % dp_path)
        files[dp_path] = "rtl/" + dp_path.name
    # OPM_SYNTH uses a generated/frozen control-window Tcl in exactly the
    # same way Phase-3 uses a datapath target file.  The remote wrapper only
    # receives a path, so publish this immutable input in the manifest before
    # any dependent DC job is submitted.
    opm_ctrl_local_window = os.environ.get("ULTRA_OPM_CONTROL_LOCAL_WINDOW")
    if opm_ctrl_local_window:
        opm_ctrl_path = Path(opm_ctrl_local_window)
        if not opm_ctrl_path.is_file():
            raise SystemExit("ULTRA_OPM_CONTROL_LOCAL_WINDOW is not a file: %s" % opm_ctrl_path)
        files[opm_ctrl_path] = "rtl/" + opm_ctrl_path.name
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(os.environ.get("C1_HOST", "192.168.2.8"), username=os.environ.get("C1_USER", "ghy19"), password=password(), timeout=40, banner_timeout=90, allow_agent=False, look_for_keys=False, compress=True)
    dirs = " ".join(ROOT + "/" + d for d in ("rtl","scripts/dc","scripts/sta","sim/tb","sim/cases","sim/work","outputs","reports/dc","reports/sta","logs/dc","logs/gls","results/" + RUN_ID))
    run(c, "mkdir -p " + dirs)
    # Optional timing overlays are published only when a run requests them.
    # In particular, OPM_SYNTH may be proven safe at zero explicit margin by
    # its local V2 D/E RTC, in which case there is deliberately no control
    # window file or overlay to upload.
    sftp = c.open_sftp(); manifest = {str(dst): digest(src) for src, dst in files.items()}
    for src, dst in files.items(): atomic_put(c, sftp, src, ROOT + "/" + dst)
    sftp.close()
    run(c, "chmod +x %s/scripts/run_gls_ultra_router.sh; sed -i 's/\\r$//' %s/scripts/run_gls_ultra_router.sh" % (ROOT, ROOT))
    all_stages = [("dc", "dc_shell-t -64 -f %s/scripts/dc/run_dc_ultra_router.tcl" % ROOT), ("func", "bash %s/scripts/run_gls_ultra_router.sh func" % ROOT), ("sdf", "bash %s/scripts/run_gls_ultra_router.sh sdf" % ROOT), ("sta", "dc_shell-t -64 -f %s/scripts/sta/run_sta_ultra_router.tcl" % ROOT)]
    requested_stages = [s.strip() for s in os.environ.get("ULTRA_STAGES", "dc,func,sdf,sta").split(",") if s.strip()]
    unknown_stages = sorted(set(requested_stages) - set(s for s, _ in all_stages))
    if unknown_stages:
        raise SystemExit("Unknown ULTRA_STAGES: %s" % ",".join(unknown_stages))
    stages = [(stage, command) for stage, command in all_stages if stage in requested_stages]
    status = {"run_id": RUN_ID, "remote_root": ROOT, "delay_profile": delay_profile, "eco_delay": eco_delay, "manifest": manifest, "stages": {}}
    dc_job_id = None
    sim_args = os.environ.get("ULTRA_SIM_ARGS", "")
    body_gaps = os.environ.get("ULTRA_BODY_GAPS", "0")
    sdf_cases = os.environ.get("ULTRA_SDF_CASES", "unicast3")
    netlist_run_id = os.environ.get("ULTRA_NETLIST_RUN_ID", RUN_ID)
    dump_vcd = os.environ.get("ULTRA_DUMP_VCD", "0")
    trace_b_head = os.environ.get("ULTRA_TRACE_B_HEAD", "0")
    trace_v2 = os.environ.get("ULTRA_TRACE_V2", "0")
    trace_head_timing = os.environ.get("ULTRA_TRACE_HEAD_TIMING", "0")
    trace_datapath = os.environ.get("ULTRA_TRACE_DATAPATH", "0")
    gls_tb = os.environ.get("ULTRA_GLS_TB", "boundary")
    if gls_tb not in ("boundary", "rtc_all_edges"):
        raise SystemExit("ULTRA_GLS_TB must be boundary or rtc_all_edges")
    for stage, command in stages:
        wrapper = "%s/logs/%s/%s.sh" % (ROOT, stage, RUN_ID); log = "%s/logs/%s/%s.log" % (ROOT, stage, RUN_ID)
        dp_seed = os.environ.get("ULTRA_DATAPATH_SEED_DDC", "")
        dp_overlay = os.environ.get("ULTRA_DATAPATH_OVERLAY", "")
        dp_targets = os.environ.get("ULTRA_DATAPATH_TARGET_FILE", "")
        dp_report_dir = os.environ.get("ULTRA_DATAPATH_REPORT_DIR", "")
        opm_ctrl_overlay = os.environ.get("ULTRA_OPM_CONTROL_OVERLAY", "")
        opm_ctrl_window = os.environ.get("ULTRA_OPM_CONTROL_WINDOW_FILE", "")
        opm_ctrl_report = os.environ.get("ULTRA_OPM_CONTROL_REPORT_DIR", "")
        dfire_ctrl_overlay = os.environ.get("ULTRA_DFIRE_CONTROL_OVERLAY", "")
        if not dfire_ctrl_overlay and delay_profile.endswith("_DFIRE0"):
            dfire_ctrl_overlay = ROOT + "/rtl/async_ultra_router_dfire_control.sdc"
        script = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nmodule load syn 2>/dev/null || true\nexport ULTRA_REMOTE_ROOT=%s ULTRA_RUN_ID=%s ULTRA_NETLIST_RUN_ID=%s ASYNC_DELAY_PROFILE=%s ULTRA_ECO_DELAY=%s ULTRA_SIM_ARGS=%s ULTRA_BODY_GAPS=%s ULTRA_SDF_CASES=%s ULTRA_DUMP_VCD=%s ULTRA_TRACE_B_HEAD=%s ULTRA_TRACE_V2=%s ULTRA_TRACE_HEAD_TIMING=%s ULTRA_TRACE_DATAPATH=%s ULTRA_GLS_TB=%s ULTRA_DATAPATH_SEED_DDC=%s ULTRA_DATAPATH_OVERLAY=%s ULTRA_DATAPATH_TARGET_FILE=%s ULTRA_DATAPATH_REPORT_DIR=%s ULTRA_OPM_CONTROL_OVERLAY=%s ULTRA_OPM_CONTROL_WINDOW_FILE=%s ULTRA_OPM_CONTROL_REPORT_DIR=%s ULTRA_DFIRE_CONTROL_OVERLAY=%s\ncd %s\n%s\n" % (ROOT, RUN_ID, shlex.quote(netlist_run_id), shlex.quote(delay_profile), shlex.quote(eco_delay), shlex.quote(sim_args), shlex.quote(body_gaps), shlex.quote(sdf_cases), shlex.quote(dump_vcd), shlex.quote(trace_b_head), shlex.quote(trace_v2), shlex.quote(trace_head_timing), shlex.quote(trace_datapath), shlex.quote(gls_tb), shlex.quote(dp_seed), shlex.quote(dp_overlay), shlex.quote(dp_targets), shlex.quote(dp_report_dir), shlex.quote(opm_ctrl_overlay), shlex.quote(opm_ctrl_window), shlex.quote(opm_ctrl_report), shlex.quote(dfire_ctrl_overlay), ROOT, command)
        dependency = "" if dc_job_id is None else " -w 'done(%s)'" % dc_job_id
        submit = run(c, "mkdir -p %s/logs/%s; cat > %s <<'EOF'\n%sEOF\nchmod +x %s\nbsub%s -n 8 -o %s -e %s.err -J ultra_%s_%s %s" % (ROOT, stage, wrapper, script, wrapper, dependency, log, log, stage, RUN_ID, wrapper))
        match = re.search(r"Job <(\d+)>", submit)
        if not match:
            status["stages"][stage] = {"state": "SUBMIT_FAIL", "submit": submit}
            continue
        job_id = match.group(1)
        status["stages"][stage] = {"job_id": job_id, "state": "SUBMITTED", "submit": submit}
        if stage == "dc": dc_job_id = job_id
    run(c, "cat > %s/results/%s/result.json <<EOF\n%s\nEOF" % (ROOT, RUN_ID, json.dumps(status, indent=2)))
    LOCAL_RESULT.mkdir(parents=True, exist_ok=True); sftp = c.open_sftp()
    for folder in ("logs", "reports", "outputs", "results"):
        try: fetch_tree(sftp, ROOT + "/" + folder + "/" + RUN_ID, LOCAL_RESULT / folder)
        except IOError: pass
    (LOCAL_RESULT / "result.json").write_text(json.dumps(status, indent=2), encoding="utf-8")
    sftp.close(); c.close(); print(json.dumps(status, indent=2))
if __name__ == "__main__": main()

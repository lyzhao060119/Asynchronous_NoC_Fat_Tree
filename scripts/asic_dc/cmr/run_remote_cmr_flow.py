#!/usr/bin/env python3
"""Frozen-manifest remote DC and strict-SDF flow for CMRRouter geometries."""

import hashlib
import json
import os
import re
import shlex
import stat
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import paramiko

from cmr_frozen_run_ids import refuse_overwrite


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA_ROOT = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get("CMR_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_router_sdf")
ROUTER_LEVEL = int(os.environ.get("CMR_ROUTER_LEVEL", "1"))
CHILD_LANES = int(os.environ.get("CMR_CHILD_LANES", "1"))
PARENT_LANES = int(os.environ.get("CMR_PARENT_LANES", "1"))
USE_MESH = os.environ.get("CMR_USE_MESH_ROUTING", "0").strip() in ("1", "true", "mesh")
MESH_GRID = int(os.environ.get("CMR_MESH_GRID_SIZE", "8"))
MULTILANE = (CHILD_LANES, PARENT_LANES) != (1, 1)
JOB_POLLS = int(os.environ.get("CMR_JOB_POLLS", "240"))
EXPECTED_PHYSICAL_EDGES = (4 * CHILD_LANES + PARENT_LANES) ** 2 - (
    4 * CHILD_LANES * CHILD_LANES + PARENT_LANES * PARENT_LANES
)
if (CHILD_LANES, PARENT_LANES) == (1, 2):
    MULTILANE_TB_FILE = "tb_cmr_router_l1_multilane_smoke.sv"
    MULTILANE_TB_TOP = "tb_cmr_router_l1_multilane_smoke"
elif (CHILD_LANES, PARENT_LANES) == (2, 4):
    MULTILANE_TB_FILE = "tb_cmr_router_l2_multilane_smoke.sv"
    MULTILANE_TB_TOP = "tb_cmr_router_l2_multilane_smoke"
else:
    MULTILANE_TB_FILE = None
    MULTILANE_TB_TOP = None
APPROVED_CASES = (
    "unicast3",
    "mc_single3",
    "mc_disjoint_parallel3",
    "uc_overlap_release3",
    "mc_overlap_tailjoin3",
    "b_alone_head",
    "a_then_b_head_parallel",
)
if MULTILANE:
    APPROVED_CASES = ("multilane_complex",)
CASES = os.environ.get("CMR_SDF_CASES", ",".join(APPROVED_CASES))
CASE_LIST = [name for name in CASES.split(",") if name]
SEED_RUN_ID = os.environ.get("CMR_DC_SEED_RUN_ID", "").strip()
BUF_STAGES = os.environ.get("CMR_RCU_MATCHED_BUF_STAGES", "0").strip() or "0"
LANE01_STAGES = os.environ.get("CMR_LANE01_BUF_STAGES", "0").strip() or "0"
UNIT_PS = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")
STEPS = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")
OPM_ACKIN_STEPS = os.environ.get("CMR_OPM_ACKIN_DELAY_STEPS", "1")
OPM_ACKIN_UNIT_PS = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")
OPM_ACKIN_USE_BUF = os.environ.get("CMR_OPM_ACKIN_USE_BUF", "0").strip() or "0"
DC_ONLY = os.environ.get("CMR_DC_ONLY", "0") == "1"
LOCAL_RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def expected_adapters(child_lanes, parent_lanes):
    count = 0
    if parent_lanes > 1:
        count += 4 * child_lanes
    if child_lanes > 1:
        count += 4 * child_lanes * 3 + parent_lanes * 4
    return count


EXPECTED_ADAPTERS = expected_adapters(CHILD_LANES, PARENT_LANES)


def password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        match = re.search(
            r"^[ \t-]*密码[:：][ \t]*(\S+)",
            doc.read_text(encoding="utf-8", errors="replace"),
            re.M,
        )
        if match:
            return match.group(1)
    raise SystemExit("Set C1_PASS or add docs password entry")


def sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha256_file(path):
    return sha256_bytes(path.read_bytes().replace(b"\r\n", b"\n"))


def remote_run(client, command):
    _, stdout, stderr = client.exec_command(command)
    return (stdout.read() + stderr.read()).decode(errors="replace")


def atomic_put(client, sftp, local, remote):
    data = local.read_bytes().replace(b"\r\n", b"\n")
    return atomic_put_bytes(client, sftp, data, remote)


def atomic_put_bytes(client, sftp, data, remote):
    expected = sha256_bytes(data)
    temporary = "%s.upload.%d" % (remote, os.getpid())
    cmd = "bash --noprofile --norc -c %s" % shlex.quote("cat > " + temporary)
    transport = client.get_transport()
    if transport is None or not transport.is_active():
        raise RuntimeError("ssh transport inactive before upload %s" % remote)
    chan = transport.open_session()
    chan.exec_command(cmd)
    chan.sendall(data)
    chan.shutdown_write()
    status = chan.recv_exit_status()
    err = ""
    if chan.recv_stderr_ready():
        err = chan.recv_stderr(65536).decode(errors="replace")
    observed = remote_run(client, "sha256sum %s" % shlex.quote(temporary)).split()
    if observed and observed[0] == expected:
        remote_run(
            client,
            "mv -f %s %s" % (shlex.quote(temporary), shlex.quote(remote)),
        )
        return expected
    raise RuntimeError(
        "ssh cat upload failed %s status=%s err=%s" % (remote, status, err)
    )


def job_id(submit_text):
    match = re.search(r"Job <(\d+)>", submit_text)
    if not match:
        raise RuntimeError("LSF submission failed: " + submit_text)
    return match.group(1)


def wait_job(client, jid, label, polls=None):
    limit = JOB_POLLS if polls is None else polls
    for poll_index in range(limit):
        response = remote_run(
            client,
            "state=$(bjobs -noheader -o stat %s 2>/dev/null | tr -d '[:space:]'); "
            "printf '__CMR_JOB_STATE__%%s\\n' \"$state\"" % shlex.quote(jid),
        )
        marker = re.search(r"__CMR_JOB_STATE__([A-Z]*)", response)
        if not marker:
            raise RuntimeError("could not parse LSF state for %s: %s" % (jid, response))
        state = marker.group(1)
        if not state or state == "DONE":
            print("JOB_DONE", label, jid, state or "PURGED", flush=True)
            return
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            raise RuntimeError("LSF job %s %s ended in state %s" % (label, jid, state))
        print("JOB_WAIT", label, jid, state, "poll", poll_index, flush=True)
        time.sleep(30)
    raise RuntimeError("job polling timeout: %s %s" % (label, jid))


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        remote_path = remote + "/" + entry.filename
        local_path = local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, remote_path, local_path)
        else:
            sftp.get(remote_path, str(local_path))


def first_failure(text):
    lines = text.splitlines()
    # Protocol failures are the actionable test outcome.  Bare $setup/$hold
    # lines also occur in timing-check declarations, so only classify an
    # actual simulator "Timing violation" diagnostic as a runtime violation.
    for markers in (("TB_RESULT FAIL", "TB_X_FAIL"), ("Timing violation",)):
        match = next((line for line in lines if any(m in line for m in markers)), None)
        if match:
            return match
    return None


def first_timing_violation(text):
    return next((line for line in text.splitlines() if "Timing violation" in line), None)


def local_preflight():
    base_env = os.environ.copy()
    sbt = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
    if USE_MESH:
        target = "router_l%d_c%d_p%d_mesh" % (ROUTER_LEVEL, CHILD_LANES, PARENT_LANES)
    elif not MULTILANE:
        target = "router_l%d" % ROUTER_LEVEL
    else:
        target = "router_l%d_c%d_p%d" % (ROUTER_LEVEL, CHILD_LANES, PARENT_LANES)
    skip_emit = os.environ.get("CMR_SKIP_EMIT", "0") == "1"
    if not skip_emit:
        subprocess.run([sbt, "compile"], cwd=REPO, env=base_env, check=True)
        if os.environ.get("CMR_SKIP_LOCAL_SMOKE", "0") != "1":
            sim_env = base_env.copy()
            sim_env["ASYNC_PRIMITIVES"] = "sim"
            subprocess.run(
                [
                    sbt,
                    "runMain",
                    "Router_Architecture.CMR.CMRRouterMain",
                    str(ROUTER_LEVEL),
                    str(CHILD_LANES),
                    str(PARENT_LANES),
                    "1" if USE_MESH else "0",
                    str(MESH_GRID),
                ],
                cwd=REPO,
                env=sim_env,
                check=True,
            )
            if (
                not USE_MESH
                and ROUTER_LEVEL == 1
                and (CHILD_LANES, PARENT_LANES) == (1, 1)
            ):
                vivado = os.environ.get(
                    "VIVADO_CMD", "vivado.bat" if os.name == "nt" else "vivado"
                )
                subprocess.run(
                    [vivado, "-mode", "batch", "-source", "run_smoke.tcl"],
                    cwd=REPO / "sim" / "CMR",
                    check=True,
                )
            else:
                print(
                    "SKIP_LOCAL_VIVADO_SMOKE level=%s c%sp%s mesh=%s"
                    % (ROUTER_LEVEL, CHILD_LANES, PARENT_LANES, int(USE_MESH)),
                    flush=True,
                )

        asic_env = base_env.copy()
        asic_env["ASYNC_PRIMITIVES"] = "asic"
        subprocess.run(
            [
                sbt,
                "runMain",
                "Router_Architecture.CMR.CMRRouterMain",
                str(ROUTER_LEVEL),
                str(CHILD_LANES),
                str(PARENT_LANES),
                "1" if USE_MESH else "0",
                str(MESH_GRID),
            ],
            cwd=REPO,
            env=asic_env,
            check=True,
        )

    entry = REPO / "generated_cmr" / target / "CMRRouter.v"
    text = entry.read_text(encoding="utf-8", errors="replace")
    direct_edges = re.findall(
        r"assign OutputPortModules_(\d+)_io_Reqin_\d+ = InputPortModules_(\d+)_io_Reqout_\d+;",
        text,
    )
    physical_edges = re.findall(r"assign OutputPortModules_\d+_io_Reqin_\d+ = ", text)
    uturns = [(out_port, in_port) for out_port, in_port in direct_edges if out_port == in_port]
    if len(physical_edges) != EXPECTED_PHYSICAL_EDGES or uturns:
        raise RuntimeError("CMR entry topology mismatch: edges=%d uturns=%r" % (len(physical_edges), uturns))
    print("LOCAL_STRUCTURE LEGAL_REQ_EDGES=%d UTURN_EDGES=0" % EXPECTED_PHYSICAL_EDGES, flush=True)
    subprocess.run(
        [
            sys.executable,
            str(REPO / "scripts" / "asic_dc" / "cmr" / "check_cmr_router_geometry.py"),
            "--root",
            str(REPO / "generated_cmr"),
            target,
        ],
        cwd=REPO,
        check=True,
    )
    return entry


def main():
    refuse_overwrite(RUN_ID, action="dc")
    if not DC_ONLY and (
        not CASE_LIST
        or len(CASE_LIST) != len(set(CASE_LIST))
        or any(c not in APPROVED_CASES for c in CASE_LIST)
    ):
        raise SystemExit(
            "CMR_SDF_CASES must be a non-empty unique subset of the approved boundary cases"
        )
    if not DC_ONLY and MULTILANE and MULTILANE_TB_FILE is None:
        print(
            "CMR_FLOW_INFO no boundary-smoke TB for (%d,%d); DC then hop R-U5 GLS"
            % (CHILD_LANES, PARENT_LANES),
            flush=True,
        )
    if SEED_RUN_ID and int(BUF_STAGES) < 1 and int(LANE01_STAGES) < 1:
        raise SystemExit(
            "CMR_DC_SEED_RUN_ID requires CMR_RCU_MATCHED_BUF_STAGES>=1 or CMR_LANE01_BUF_STAGES>=1"
        )
    if int(LANE01_STAGES) >= 1 and EXPECTED_ADAPTERS < 1:
        raise SystemExit("CMR_LANE01_BUF_STAGES requires a multi-lane geometry with adapters")
    if int(STEPS) == 0 and int(BUF_STAGES) >= 1:
        raise SystemExit("CMR_RCU_MATCHED_DELAY_STEPS=0 cannot insert RCU matched bufs")

    if SEED_RUN_ID:
        print(
            "INCREMENTAL_SEED",
            SEED_RUN_ID,
            "buf_stages",
            BUF_STAGES,
            "lane01_stages",
            LANE01_STAGES,
            "expected_adapters",
            EXPECTED_ADAPTERS,
            "unit_ps",
            UNIT_PS,
            "steps",
            STEPS,
            flush=True,
        )
        print("LOCAL_STRUCTURE LEGAL_REQ_EDGES=%d UTURN_EDGES=0" % EXPECTED_PHYSICAL_EDGES, flush=True)
        entry = None
    else:
        entry = local_preflight()
    cmr_resource = REPO / "src" / "main" / "resources" / "ASYNC" / "CMR"
    files = {
        REPO / "src/main/resources/ASYNC/DelayElement_ASIC.v": "rtl/DelayElement_ASIC.v",
        REPO / "src/main/resources/ASYNC/DontTouchBuf_ASIC.v": "rtl/DontTouchBuf_ASIC.v",
        REPO / "src/main/resources/ASYNC/Mutex2_ASIC.v": "rtl/Mutex2_ASIC.v",
        REPO / "scripts/asic_dc/cmr/tb_cmr_router_hop_ppa.sv": "sim/tb/tb_cmr_router_hop_ppa.sv",
        REPO / "src/main/resources/ASYNC/Mutex4.v": "rtl/Mutex4.v",
        REPO / "src/main/resources/ASYNC/MullerC2.v": "rtl/MullerC2.v",
        cmr_resource / "CMRMutexN.v": "rtl/CMRMutexN.v",
        cmr_resource / "CMRFlattenedTAC.v": "rtl/CMRFlattenedTAC.v",
        cmr_resource / "LanePhaseAdapter.v": "rtl/LanePhaseAdapter.v",
        REPO / "src/main/resources/ASYNC/DLatchBank.v": "rtl/DLatchBank.v",
        REPO / "src/main/resources/ASYNC/V2CloseEvent.v": "rtl/V2CloseEvent.v",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        REPO / "scripts/asic_dc/cmr/async_cmr_router.sdc": "rtl/async_cmr_router.sdc",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_router.tcl": "scripts/dc/run_dc_cmr_router.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_router.sh": "scripts/run_gls_cmr_router.sh",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_router_hop_ppa.sh":
            "scripts/run_gls_cmr_router_hop_ppa.sh",
    }
    if entry is not None:
        files[entry] = "rtl/runs/%s/CMRRouter.v" % RUN_ID
    bind_dir = REPO / "scripts" / "asic_dc" / "cmr" / "hop_binds"
    if not any(bind_dir.glob("*.vi")):
        subprocess.run(
            [sys.executable, str(REPO / "scripts" / "asic_dc" / "cmr" / "gen_cmr_hop_dut_bind.py")],
            cwd=REPO,
            check=True,
        )
    if bind_dir.is_dir():
        for vi in sorted(bind_dir.glob("*.vi")):
            files[vi] = "sim/tb/hop_binds/" + vi.name
    if MULTILANE and MULTILANE_TB_FILE is not None:
        files[REPO / "sim" / "CMR" / "testbench" / MULTILANE_TB_FILE] = "sim/tb/" + MULTILANE_TB_FILE
    for name in (
        "Toggle.v",
        "HeadPredictor.v",
        "PhaseSelector.v",
        "AddressRegisterUnit.v",
        "InternalAckModule.v",
        "RouteSelAnd2.v",
        "OPMSelector.v",
        "PhaseResetDLatch.v",
        "WriteControlUnit.v",
        "WriteCounter.v",
        "WriteAckGenerator.v",
        "ReadControlUnit.v",
        "ReadCounter.v",
        "ReadRequestGenerator.v",
        "ReadPhaseSelector.v",
        "ReadAckGenerator.v",
    ):
        files[cmr_resource / name] = "rtl/" + name
    missing = [str(path) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("Missing CMR remote input files: " + ", ".join(missing))

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
        compress=True,
    )
    directories = (
        "rtl rtl/runs/%s scripts/dc scripts/sta sim/tb sim/tb/hop_binds sim/cases "
        "sim/work outputs reports/dc reports/sta logs/dc logs/gls results/%s work"
        % (RUN_ID, RUN_ID)
    )
    remote_run(client, "mkdir -p " + " ".join(ROOT + "/" + d for d in directories.split()))

    # Preserve provenance exactly as requested: copy reference stimulus from
    # the remote Ultra tree, then make a CMR-owned boundary-only adaptation.
    copy_command = (
        "cp -a {ultra}/sim/cases/. {cmr}/sim/cases/ && "
        "cp {ultra}/sim/tb/tb_ultra_router_boundary_smoke.sv "
        "{cmr}/sim/tb/tb_ultra_router_boundary_smoke.reference.sv && "
        "sed -e 's/tb_ultra_router_boundary_smoke/tb_cmr_router_boundary_smoke/g' "
        "-e 's/UltraRouter dut/CMRRouter dut/g' "
        "{cmr}/sim/tb/tb_ultra_router_boundary_smoke.reference.sv > "
        "{cmr}/sim/tb/tb_cmr_router_boundary_smoke.sv"
    ).format(ultra=shlex.quote(ULTRA_ROOT), cmr=shlex.quote(ROOT))
    copy_output = remote_run(client, copy_command)
    if copy_output.strip():
        print(copy_output, flush=True)

    sftp = client.open_sftp()
    manifest = {
        "run_id": RUN_ID,
        "remote_root": ROOT,
        "ultra_reference_root": ULTRA_ROOT,
        "cases": CASE_LIST,
        "local_structure": {"legal_req_edges": EXPECTED_PHYSICAL_EDGES, "uturn_edges": 0},
        "seed_run_id": SEED_RUN_ID or None,
        "rcu_matched_buf_stages": int(BUF_STAGES),
        "lane01_buf_stages": int(LANE01_STAGES),
        "expected_adapters": EXPECTED_ADAPTERS,
        "rcu_matched_delay_unit_ps": int(UNIT_PS),
        "rcu_matched_delay_steps": int(STEPS),
        "opm_ackin_delay_steps": int(OPM_ACKIN_STEPS),
        "opm_ackin_delay_unit_ps": int(OPM_ACKIN_UNIT_PS),
        "opm_ackin_use_buf": OPM_ACKIN_USE_BUF == "1",
        "files": {},
    }
    for source, destination in files.items():
        print("UPLOAD", destination, flush=True)
        manifest["files"][destination] = atomic_put(
            client, sftp, source, ROOT + "/" + destination
        )
    if entry is not None:
        remote_run(
            client,
            "cp -f %s %s"
            % (
                shlex.quote(ROOT + "/rtl/runs/" + RUN_ID + "/CMRRouter.v"),
                shlex.quote(ROOT + "/rtl/CMRRouter.v"),
            ),
        )
    copied_hashes = remote_run(
        client,
        "sha256sum %s/sim/tb/tb_ultra_router_boundary_smoke.reference.sv "
        "%s/sim/tb/tb_cmr_router_boundary_smoke.sv %s/sim/cases/*.case"
        % (ROOT, ROOT, ROOT),
    )
    manifest["remote_copied_sha256"] = [
        line for line in copied_hashes.splitlines() if re.match(r"^[0-9a-f]{64}  ", line)
    ]
    atomic_put_bytes(
        client,
        sftp,
        (json.dumps(manifest, indent=2) + "\n").encode(),
        ROOT + "/results/" + RUN_ID + "/manifest.json",
    )
    sftp.close()
    remote_run(client, "chmod +x %s/scripts/run_gls_cmr_router.sh" % ROOT)
    if SEED_RUN_ID:
        probe = remote_run(
            client,
            "test -s %s && echo OK"
            % shlex.quote(ROOT + "/outputs/" + SEED_RUN_ID + "/CMRRouter.ddc"),
        )
        if "OK" not in probe:
            raise RuntimeError("missing seed DDC " + SEED_RUN_ID)

    dc_wrapper = ROOT + "/logs/dc/" + RUN_ID + ".sh"
    dc_log = ROOT + "/logs/dc/" + RUN_ID + ".log"
    dc_body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_RUN_ID=%s CMR_EXPECTED_PORTS=%d "
        "CMR_EXPECTED_EDGES=%d CMR_EXPECTED_ADAPTERS=%d CMR_RCU_MAT_MAX_NS=%s "
        "CMR_DC_SEED_RUN_ID=%s CMR_RCU_MATCHED_BUF_STAGES=%s "
        "CMR_LANE01_BUF_STAGES=%s "
        "CMR_RCU_MATCHED_DELAY_UNIT_PS=%s CMR_RCU_MATCHED_DELAY_STEPS=%s "
        "CMR_OPM_ACKIN_DELAY_STEPS=%s CMR_OPM_ACKIN_DELAY_UNIT_PS=%s "
        "CMR_OPM_ACKIN_USE_BUF=%s CMR_DUT_V=%s\n"
        "cd %s\ndc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_router.tcl\n"
        % (ROOT, shlex.quote(RUN_ID), 4 * CHILD_LANES + PARENT_LANES,
           EXPECTED_PHYSICAL_EDGES, EXPECTED_ADAPTERS,
           shlex.quote(os.environ.get("CMR_RCU_MAT_MAX_NS", "0.20")),
           shlex.quote(SEED_RUN_ID),
           shlex.quote(BUF_STAGES),
           shlex.quote(LANE01_STAGES),
           shlex.quote(str(UNIT_PS)),
           shlex.quote(str(STEPS)),
           shlex.quote(OPM_ACKIN_STEPS),
           shlex.quote(OPM_ACKIN_UNIT_PS),
           shlex.quote(OPM_ACKIN_USE_BUF),
           shlex.quote(ROOT + "/rtl/runs/" + RUN_ID + "/CMRRouter.v"),
           ROOT, ROOT)
    )
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, dc_body.encode(), dc_wrapper)
    sftp.close()
    remote_run(client, "chmod +x %s" % dc_wrapper)
    dc_submit = remote_run(
        client,
        "bsub -n 8 -o %s -e %s.err -J cmr_dc_%s %s"
        % (dc_log, dc_log, RUN_ID, dc_wrapper),
    )
    dc_job = job_id(dc_submit)
    print("DC_JOB", dc_job, flush=True)
    wait_job(client, dc_job, "dc")
    # LSF can expose DONE a few moments before the output spool is fully
    # flushed to the requested log.  Wait for an explicit flow marker rather
    # than treating that short visibility window as a DC failure.
    dc_text = ""
    for _ in range(12):
        dc_text = remote_run(client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log))
        if "CMR_DC_PASS" in dc_text or "CMR_DC_FAIL" in dc_text:
            break
        time.sleep(5)
    if "CMR_DC_PASS" not in dc_text:
        print(dc_text[-12000:], flush=True)
        raise RuntimeError("CMR DC failed: " + (first_failure(dc_text) or "see remote log"))

    skip_boundary = (
        DC_ONLY
        or USE_MESH
        or (MULTILANE and MULTILANE_TB_FILE is None)
        or os.environ.get("CMR_HOP_SDF_ONLY", "0") == "1"
    )
    if skip_boundary:
        local_summary = {
            "run_id": RUN_ID,
            "dc_only": True,
            "hop_sdf_pending": True,
            "use_mesh_routing": USE_MESH,
            "physical_class": "post-synthesis",
            "remote_root": ROOT,
            "manifest": manifest,
            "dc": {
                "job_id": dc_job,
                "pass": True,
                "gtech_zero": "GTECH cell count after compile = 0" in dc_text,
                "seqgen_zero": "SEQUENCE_PLACEHOLDER" not in dc_text and "SEQGEN=0" in dc_text,
            },
        }
        LOCAL_RESULT.mkdir(parents=True, exist_ok=True)
        sftp = client.open_sftp()
        try:
            for remote_path, local_name in (
                (ROOT + "/outputs/" + RUN_ID, "outputs"),
                (ROOT + "/reports/dc/" + RUN_ID, "reports_dc"),
                (ROOT + "/results/" + RUN_ID, "results"),
            ):
                try:
                    fetch_tree(sftp, remote_path, LOCAL_RESULT / local_name)
                except IOError:
                    pass
        finally:
            sftp.close()
        (LOCAL_RESULT / "summary.json").write_text(
            json.dumps(local_summary, indent=2) + "\n", encoding="utf-8"
        )
        print("CMR_DC_PASS", RUN_ID, "boundary_sdf=skip hop_ppa next", flush=True)
        client.close()
        return

    sdf_wrapper = ROOT + "/logs/gls/" + RUN_ID + "/sdf.sh"
    sdf_body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_RUN_ID=%s CMR_NETLIST_RUN_ID=%s "
        "CMR_SDF_CASES=%s CMR_TB_FILE=%s CMR_TB_TOP=%s\n"
        "exec bash %s/scripts/run_gls_cmr_router.sh\n"
        % (ROOT, shlex.quote(RUN_ID), shlex.quote(RUN_ID), shlex.quote(CASES),
           MULTILANE_TB_FILE if MULTILANE else "tb_cmr_router_boundary_smoke.sv",
           MULTILANE_TB_TOP if MULTILANE else "tb_cmr_router_boundary_smoke", ROOT)
    )
    remote_run(client, "mkdir -p %s/logs/gls/%s" % (ROOT, RUN_ID))
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, sdf_body.encode(), sdf_wrapper)
    sftp.close()
    remote_run(client, "chmod +x %s" % sdf_wrapper)
    sdf_submit = remote_run(
        client,
        "bsub -n 8 -o %s/logs/gls/%s/sdf.bsub.log "
        "-e %s/logs/gls/%s/sdf.bsub.err -J cmr_sdf_%s %s"
        % (ROOT, RUN_ID, ROOT, RUN_ID, RUN_ID, sdf_wrapper),
    )
    sdf_job = job_id(sdf_submit)
    print("SDF_JOB", sdf_job, flush=True)
    wait_job(client, sdf_job, "sdf")

    compile_log = remote_run(
        client, "cat %s/logs/gls/%s/sdf/compile.log 2>/dev/null" % (ROOT, RUN_ID)
    )
    annotation_log = remote_run(
        client, "cat %s/logs/gls/%s/sdf/sdf_annotate.log 2>/dev/null" % (ROOT, RUN_ID)
    )
    annotation_errors = re.search(r"Total errors:\s*(\d+)", annotation_log)
    summary = {
        "run_id": RUN_ID,
        "remote_root": ROOT,
        "manifest": manifest,
        "dc": {
            "job_id": dc_job,
            "pass": "CMR_DC_PASS" in dc_text,
            "gtech_zero": "GTECH cell count after compile = 0" in dc_text,
            "seqgen_zero": "SEQUENCE_PLACEHOLDER" not in dc_text and "SEQGEN=0" in dc_text,
        },
        "sdf": {
            "job_id": sdf_job,
            "compile_failure": first_failure(compile_log),
            "annotation_error_count": int(annotation_errors.group(1)) if annotation_errors else None,
            "cases": {},
        },
    }
    all_pass = True
    for case_name in CASE_LIST:
        run_log = remote_run(
            client,
            "cat %s/logs/gls/%s/sdf/%s/run.log "
            "%s/logs/gls/%s/sdf/%s/stdout.log 2>/dev/null"
            % (ROOT, RUN_ID, case_name, ROOT, RUN_ID, case_name),
        )
        case_status = {
            "tb_pass": "TB_RESULT PASS" in run_log,
            "annotation_done": "Doing SDF annotation ...... Done" in run_log,
            "ifnsdfa": "IFNSDFA" in run_log,
            "x_failure": "TB_X_FAIL" in run_log,
            "timing_violation": first_timing_violation(run_log) is not None,
            "first_timing_violation": first_timing_violation(run_log),
            "timing_violation_count": run_log.count("Timing violation"),
            "setup_violation_count": run_log.count("$setup("),
            "hold_violation_count": run_log.count("$hold("),
            "first_failure": first_failure(run_log),
        }
        summary["sdf"]["cases"][case_name] = case_status
        passed = (
            case_status["tb_pass"]
            and case_status["annotation_done"]
            and not case_status["ifnsdfa"]
            and not case_status["x_failure"]
            and case_status["timing_violation_count"] == 0
        )
        all_pass = all_pass and passed
        print("SDF_CASE", case_name, "PASS" if passed else "FAIL", case_status, flush=True)
        for line in run_log.splitlines():
            if "TB_FLIT_E2E " in line or "TB_RTC_SAMPLE rtc=OPM_V2_CHILD0_PARENT" in line:
                print(line, flush=True)

    sftp = client.open_sftp()
    atomic_put_bytes(
        client,
        sftp,
        (json.dumps(summary, indent=2) + "\n").encode(),
        ROOT + "/results/" + RUN_ID + "/summary.json",
    )
    LOCAL_RESULT.mkdir(parents=True, exist_ok=True)
    for remote_path, local_name in (
        (ROOT + "/outputs/" + RUN_ID, "outputs"),
        (ROOT + "/reports/dc/" + RUN_ID, "reports_dc"),
        (ROOT + "/logs/gls/" + RUN_ID, "logs_gls"),
        (ROOT + "/results/" + RUN_ID, "results"),
    ):
        try:
            fetch_tree(sftp, remote_path, LOCAL_RESULT / local_name)
        except IOError:
            pass
    (LOCAL_RESULT / "summary.json").write_text(
        json.dumps(summary, indent=2) + "\n", encoding="utf-8"
    )
    sftp.close()
    client.close()
    print(json.dumps(summary, indent=2), flush=True)
    print("LOCAL_RESULT", LOCAL_RESULT, flush=True)
    if not all_pass:
        sys.exit(2)


if __name__ == "__main__":
    main()

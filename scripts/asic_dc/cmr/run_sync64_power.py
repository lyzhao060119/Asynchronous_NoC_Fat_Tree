#!/usr/bin/env python3
"""Two-point Sync B8 frozen-netlist activity and PT-PX pipeline.

The runner uploads only testbench/power-control inputs.  It reuses the remote
canonical cases and the frozen 20260915 Sync netlist; it never invokes DC.
"""
from __future__ import annotations

import argparse, csv, hashlib, json, os, re, shlex, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
from run_remote_cmr_fat_tree_noc16_sdf import connect, job_id  # noqa: E402
from run_core64_power import parse_power_report  # noqa: E402

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
DATA = "/prjtemp/ghy19/paper64_sync_power"
LOCAL = REPO / "DATE paper/experiments/raw/paper64"
SYNC_UR = LOCAL / "sync64_ur_20260916_161922" / "summary.csv"
ASYNC_POWER = LOCAL / "network_power_20260916_084500_paper64_network8" / "power_summary.csv"
NETLIST_RUN = "20260915_231600_sync_prop_temp64_b8_dc"
CASE_DIR = f"{ROOT}/sim/prop_temp64_20260913_prop_temp64_asap_uc_m5_500/cases"
POINTS = (("sync_m100", 100), ("sync_common_high", 420))
FILES = {
    "adapter": REPO / "sim/AsyncNoC/sync_noc64_port_adapter.sv",
    "tb": REPO / "sim/AsyncNoC/testbench/tb_noc64_sync_boundary.sv",
    "failfast": HERE / "tb_cmr_noc64_sync_boundary_failfast.sv",
    "pt": REPO / "scripts/asic_dc/power/run_ptpx_cmr_mesh_power.tcl",
}


def archive(run_id: str) -> Path:
    return LOCAL / f"sync64_power_{run_id}"


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def rcmd(client, command: str) -> str:
    _, stdout, stderr = client.exec_command(command)
    out, err = stdout.read().decode(errors="replace"), stderr.read().decode(errors="replace")
    rc = stdout.channel.recv_exit_status()
    if rc:
        raise RuntimeError(f"remote RC={rc}: {command}\n{err[-1200:]}\n{out[-1200:]}")
    return out


def positive(sftp, path: str) -> int:
    try:
        size = sftp.stat(path).st_size
    except IOError as exc:
        raise RuntimeError("missing remote input " + path) from exc
    if size <= 0:
        raise RuntimeError("empty remote input " + path)
    return size


def remote_hashes(client, paths: list[str]) -> dict[str, str]:
    text = rcmd(client, "sha256sum " + " ".join(shlex.quote(x) for x in paths))
    result = {path: digest for digest, path in re.findall(r"(?m)^([0-9a-f]{64})\s+(.+)$", text)}
    if set(result) != set(paths):
        raise RuntimeError("incomplete remote SHA-256 result")
    return result


def upload(sftp, local: Path, remote: str) -> str:
    data = local.read_bytes()
    with sftp.file(remote + ".uploading", "wb") as stream:
        stream.write(data)
    sftp.posix_rename(remote + ".uploading", remote)
    return hashlib.sha256(data).hexdigest()


def save(out: Path, state: dict) -> None:
    (out / "manifest.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")


def load(out: Path) -> dict:
    return json.loads((out / "manifest.json").read_text(encoding="utf-8"))


def accepted_rows() -> dict[int, dict]:
    rows = {int(row["load"]): row for row in csv.DictReader(SYNC_UR.open(newline="", encoding="utf-8"))}
    selected = {load: rows[load] for _, load in POINTS}
    for load, row in selected.items():
        if row["full_drain_pass"] != "True" or row["near_lossless"] != "True":
            raise RuntimeError(f"Sync performance gate failed at M{load}")
        if int(row["measurement_flits"]) != 50000 or int(row["measurement_delivered_flits"]) <= 0:
            raise RuntimeError(f"Sync denominator gate failed at M{load}")
    return selected


def preflight(out: Path, run_id: str) -> None:
    if out.exists():
        raise RuntimeError("refusing overwrite " + str(out))
    if not SYNC_UR.is_file() or not ASYNC_POWER.is_file():
        raise RuntimeError("accepted Sync performance or Async power baseline missing")
    perf = accepted_rows()
    async_rows = {row["id"]: row for row in csv.DictReader(ASYNC_POWER.open(newline="", encoding="utf-8"))}
    if not {"prop_m100", "dynamic_common_high"} <= set(async_rows):
        raise RuntimeError("accepted Async M100/M420 PT-PX rows missing")
    for name, path in FILES.items():
        if not path.is_file() or path.stat().st_size <= 0:
            raise RuntimeError("missing local input " + name)
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp()
        netbase = f"{ROOT}/outputs/{NETLIST_RUN}"
        frozen = [f"{netbase}/SyncNoC_64nodes.{ext}" for ext in ("ddc", "sdc", "sdf")]
        frozen.insert(2, f"{netbase}/SyncNoC_64nodes_post.v")
        cases = [f"{CASE_DIR}/TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16.case" for _, load in POINTS]
        sizes = {path: positive(sftp, path) for path in frozen + cases}
        hashes = remote_hashes(client, frozen + cases)
        for _, load in POINTS:
            path = f"{CASE_DIR}/TOPO-UR_n64_s202701_m{load}_PROP_temp64_top16.case"
            if hashes[path] != perf[load]["case_sha256"]:
                raise RuntimeError(f"canonical trace mismatch at M{load}")
        out.mkdir(parents=True)
        state = {
            "run_id": run_id, "created_utc": datetime.now(timezone.utc).isoformat(),
            "git_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
            "git_dirty": bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=REPO)),
            "netlist_run_id": NETLIST_RUN, "clock_period_ns": 1.05, "case_tick_ns": 1.0,
            "frozen_files": frozen, "remote_sizes": sizes, "remote_sha256": hashes,
            "local_input_sha256": {name: sha(path) for name, path in FILES.items()},
            "points": [{"id": tag, "load": load, "performance": perf[load]} for tag, load in POINTS],
            "async_reuse": [async_rows["prop_m100"], async_rows["dynamic_common_high"]],
            "stages": {"preflight": "PASS"},
        }
        save(out, state)
        print("SYNC64_POWER_PREFLIGHT_PASS points=2 dc_jobs=0", flush=True)
    finally:
        if sftp: sftp.close()
        client.close()


def activity_wrapper(state: dict, tag: str, load_value: int, input_dir: str, log: str) -> str:
    netbase = f"{ROOT}/outputs/{NETLIST_RUN}"
    case = f"{CASE_DIR}/TOPO-UR_n64_s202701_m{load_value}_PROP_temp64_top16.case"
    return f'''#!/bin/bash
source /etc/profile 2>/dev/null || true
set -euo pipefail
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${{VCS_HOME:-/soft/synopsys/vcs/V-2023.12}}
export PATH="$VCS_HOME/bin:$PATH"
WORK={shlex.quote(DATA + '/' + state['run_id'] + '/work/' + tag)}
LOG={shlex.quote(log)}
CASE={shlex.quote(case)}
NETLIST={shlex.quote(netbase + '/SyncNoC_64nodes_post.v')}
SDF={shlex.quote(netbase + '/SyncNoC_64nodes.sdf')}
LIB=/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v
mkdir -p "$WORK" "$LOG"
cd "$WORK"
test "$(awk '$1=="meta" && $2=="case_tick_ns" {{print $3; exit}}' "$CASE")" = 1.000
cat > sdf_boot.sv <<EOF
module sdf_boot;
 initial begin
  \\$sdf_annotate("$SDF", tb_cmr_noc64_sync_boundary_failfast.core.noc.dut, , "sdf_annotate.log", "MAXIMUM", ,);
 end
endmodule
EOF
cat > filelist.f <<EOF
$LIB
$NETLIST
{input_dir}/sync_noc64_port_adapter.sv
{input_dir}/tb_noc64_sync_boundary.sv
{input_dir}/tb_cmr_noc64_sync_boundary_failfast.sv
$WORK/sdf_boot.sv
EOF
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +define+CMR_SYNC64_TOP16 -f filelist.f \
 -top tb_cmr_noc64_sync_boundary_failfast -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv +CASE_FILE="$CASE" +RESULT_CSV="$LOG/result.csv" +EVENT_CSV="$LOG/events.csv" \
 +LATENCY_CSV="$LOG/latency.csv" +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" \
 +V3_METRICS_CSV="$LOG/v3_metrics.csv" +CLOCK_PERIOD_NS=1.05 +CASE_TICK_NS=1 \
 +RX_CAPTURE_NS=0 +STALL_TIMEOUT_NS=100000 +HARD_TIMEOUT_NS=2000000 \
 +DUMP_VCD="$LOG/measurement.vcd" +DUMP_MEASUREMENT_ONLY -l "$LOG/run.log" > "$LOG/stdout.log" 2>&1
RC=$?
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log"
sha256sum "$CASE" "$NETLIST" "$SDF" "$LOG/measurement.vcd" > "$LOG/input_hashes.sha256"
test "$RC" -eq 0
grep -q 'Total errors: 0' "$LOG/sdf_annotate.log"
grep -q 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' "$LOG/run.log"
! grep -Eiq 'TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:|Timing violation' "$LOG/run.log" "$LOG/stdout.log"
test -s "$LOG/measurement.vcd"
echo 'SYNC64_POWER_ACTIVITY_PASS tag={tag} load={load_value}'
'''


def submit_activity(out: Path, retry: bool = False) -> None:
    state = load(out)
    if state.get("activity_jobs") and not retry:
        raise RuntimeError("activity already submitted")
    if retry:
        prior = state.get("activity_jobs", [])
        if len(prior) != 2:
            raise RuntimeError("retry requires the two original activity attempts")
        state.setdefault("excluded_activity_jobs", []).extend(
            [{**job, "excluded_reason": "profile initialization exited under errexit"} for job in prior]
        )
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp()
        base = f"{DATA}/{state['run_id']}"
        input_dir = base + "/inputs"
        rcmd(client, "mkdir -p " + shlex.quote(input_dir))
        mapping = {"adapter": "sync_noc64_port_adapter.sv", "tb": "tb_noc64_sync_boundary.sv", "failfast": "tb_cmr_noc64_sync_boundary_failfast.sv", "pt": "run_ptpx_cmr_mesh_power.tcl"}
        uploaded = {name: upload(sftp, FILES[name], input_dir + "/" + remote_name) for name, remote_name in mapping.items()}
        if uploaded != state["local_input_sha256"]:
            raise RuntimeError("uploaded input SHA mismatch")
        state["remote_input_dir"] = input_dir
        state["activity_jobs"] = []
        for tag, load_value in POINTS:
            log = f"{base}/logs/activity/{tag}"
            rcmd(client, "mkdir -p " + shlex.quote(log))
            wrapper = log + "/run.sh"
            with sftp.file(wrapper, "w") as stream:
                stream.write(activity_wrapper(state, tag, load_value, input_dir, log))
            sftp.chmod(wrapper, 0o755)
            jid = job_id(rcmd(client, f"bsub -n 8 -m 'node21 node26 node24 node18' -oo {shlex.quote(log+'/lsf.log')} -eo {shlex.quote(log+'/lsf.err')} -J s64act_{load_value} {shlex.quote(wrapper)}"))
            state["activity_jobs"].append({"id": tag, "load": load_value, "job_id": jid, "remote_log": log})
            print("SYNC64_POWER_ACTIVITY_SUBMITTED", tag, jid, flush=True)
        state["stages"]["activity"] = "SUBMITTED"
        save(out, state)
    finally:
        if sftp: sftp.close()
        client.close()


def status(out: Path) -> None:
    state = load(out)
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp()
        for job in state.get("activity_jobs", []) + state.get("ptpx_jobs", []):
            listing = rcmd(client, f"bjobs -a -noheader -o 'jobid stat queue exec_host' {job['job_id']} 2>/dev/null || true")
            try:
                with sftp.file(job["remote_log"] + "/lsf.log", "rb") as stream: tail = stream.read().decode(errors="replace")[-1200:]
            except IOError: tail = ""
            marker = "PASS" if ("SYNC64_POWER_ACTIVITY_PASS" in tail or "CMR_POWER_PASS" in tail) else "NO_PASS_MARKER"
            print("SYNC64_POWER_STATUS", job["id"], job["job_id"], listing.strip(), marker, flush=True)
    finally:
        if sftp: sftp.close()
        client.close()


def collect_activity(out: Path) -> None:
    state = load(out); perf = {int(p["load"]): p["performance"] for p in state["points"]}
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp(); accepted = []
        for job in state["activity_jobs"]:
            log = job["remote_log"]
            with sftp.file(log + "/lsf.log", "rb") as stream: stage = stream.read().decode(errors="replace")
            if "SYNC64_POWER_ACTIVITY_PASS" not in stage:
                raise RuntimeError("activity not accepted: " + job["id"] + "\n" + stage[-1600:])
            local = out / "activity" / job["id"]; local.mkdir(parents=True, exist_ok=True)
            for name in ("compile.log", "run.log", "stdout.log", "sdf_annotate.log", "result.csv", "events.csv", "latency.csv", "flit_latency.csv", "v3_metrics.csv", "input_hashes.sha256"):
                positive(sftp, log + "/" + name); sftp.get(log + "/" + name, str(local / name))
            run = (local / "run.log").read_text(errors="replace")
            match = re.search(r"TB_METRICS_V2 window_ps=(\d+):(\d+)", run)
            if not match: raise RuntimeError("missing measurement window " + job["id"])
            start, end = map(int, match.groups())
            expected = perf[job["load"]]
            expected_start = int(expected["measurement_start_ps"])
            expected_end = int(expected["measurement_end_ps"])
            # The offline cohort summary records the last measurement Header
            # timestamp.  The activity TB deliberately uses the equivalent
            # half-open interval [first Header, last Header + one case tick),
            # matching the established Async power-window convention.
            if start != expected_start or end != expected_end + 1000:
                raise RuntimeError("activity/performance window mismatch " + job["id"])
            vcd = log + "/measurement.vcd"; vcd_size = positive(sftp, vcd); vcd_sha = remote_hashes(client, [vcd])[vcd]
            accepted.append({"id": job["id"], "load": job["load"], "remote_vcd": vcd, "vcd_bytes": vcd_size,
                             "vcd_sha256": vcd_sha, "measurement_start_ps": start, "measurement_end_ps": end,
                             "performance_last_header_ps": expected_end,
                             "window_end_convention": "last_measurement_header_plus_one_case_tick",
                             "delivered_flits": int(expected["measurement_delivered_flits"]), "local_log": str(local)})
            print("SYNC64_POWER_ACTIVITY_ACCEPTED", job["id"], "vcd_bytes=" + str(vcd_size), flush=True)
        state["accepted_activity"] = accepted; state["stages"]["activity"] = "PASS"; save(out, state)
    finally:
        if sftp: sftp.close()
        client.close()


def submit_ptpx(out: Path, retry_m100: bool = False) -> None:
    state = load(out)
    if state["stages"].get("activity") != "PASS": raise RuntimeError("activity gate incomplete")
    if state.get("ptpx_jobs") and not retry_m100: raise RuntimeError("PT-PX already submitted")
    if retry_m100:
        old = state.get("ptpx_jobs", [])
        failed = [job for job in old if job["id"] == "sync_m100"]
        passed = [job for job in old if job["id"] == "sync_common_high"]
        if len(failed) != 1 or len(passed) != 1:
            raise RuntimeError("M100 retry requires one prior M100 and one retained M420 job")
        state.setdefault("excluded_ptpx_jobs", []).append({**failed[0], "excluded_reason": "PT temporary FSDB hit home-directory quota"})
        state["ptpx_jobs"] = passed
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp(); base = f"{DATA}/{state['run_id']}"
        if not retry_m100: state["ptpx_jobs"] = []
        netbase = f"{ROOT}/outputs/{NETLIST_RUN}"
        for activity in state["accepted_activity"]:
            if retry_m100 and activity["id"] != "sync_m100": continue
            tag = activity["id"]; log = f"{base}/logs/ptpx/{tag}"; report = f"{base}/reports/ptpx/{tag}"
            rcmd(client, "mkdir -p " + shlex.quote(log) + " " + shlex.quote(report))
            env = {
                "SYNOPSYS_LC_ROOT": "/soft/synopsys/lc/V-2023.12", "CMR_POWER_DDC": netbase + "/SyncNoC_64nodes.ddc",
                "CMR_POWER_SDC": netbase + "/SyncNoC_64nodes.sdc", "CMR_POWER_NETLIST": netbase + "/SyncNoC_64nodes_post.v",
                "CMR_POWER_SDF": netbase + "/SyncNoC_64nodes.sdf", "CMR_POWER_VCD": activity["remote_vcd"],
                "CMR_POWER_TOP": "SyncNoC_64nodes", "CMR_POWER_STRIP_PATH": "tb_cmr_noc64_sync_boundary_failfast/core/noc/dut",
                "CMR_POWER_START_NS": f"{activity['measurement_start_ps']/1000:.3f}", "CMR_POWER_END_NS": f"{activity['measurement_end_ps']/1000:.3f}",
                "CMR_POWER_REPORT_DIR": report,
            }
            wrapper = log + "/run.sh"
            work = f"{base}/work/ptpx/{tag}"
            rcmd(client, "mkdir -p " + shlex.quote(work))
            body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\nset -euo pipefail\ncd " + shlex.quote(work) + "\n" + "\n".join("export " + k + "=" + shlex.quote(v) for k, v in env.items()) + "\nexec /soft/synopsys/prime/V-2023.12/bin/pt_shell -f " + shlex.quote(state["remote_input_dir"] + "/run_ptpx_cmr_mesh_power.tcl") + "\n"
            with sftp.file(wrapper, "w") as stream: stream.write(body)
            sftp.chmod(wrapper, 0o755)
            jid = job_id(rcmd(client, f"bsub -n 4 -m 'node21 node26 node24 node18' -oo {shlex.quote(log+'/lsf.log')} -eo {shlex.quote(log+'/lsf.err')} -J s64px_{activity['load']} {shlex.quote(wrapper)}"))
            state["ptpx_jobs"].append({"id": tag, "load": activity["load"], "job_id": jid, "remote_log": log, "remote_report": report})
            print("SYNC64_POWER_PTPX_SUBMITTED", tag, jid, flush=True)
        state["stages"]["ptpx"] = "SUBMITTED"; save(out, state)
    finally:
        if sftp: sftp.close()
        client.close()


def collect_ptpx(out: Path) -> None:
    state = load(out); activity = {x["id"]: x for x in state["accepted_activity"]}
    os.environ.setdefault("C1_HOST", "192.168.2.8")
    client, sftp = connect(attempts=3), None
    try:
        sftp = client.open_sftp(); rows = []
        for job in state["ptpx_jobs"]:
            with sftp.file(job["remote_log"] + "/lsf.log", "rb") as stream: stage = stream.read().decode(errors="replace")
            if "CMR_POWER_PASS" not in stage or "PT-063" in stage:
                raise RuntimeError("PT-PX gate failed " + job["id"] + "\n" + stage[-2000:])
            local = out / "ptpx" / job["id"]; local.mkdir(parents=True, exist_ok=True)
            for name in ("power.rpt", "power_hierarchy.rpt", "power_cells.rpt", "activity.rpt", "unannotated_activity.rpt", "check_power.rpt", "input_hashes.sha256"):
                positive(sftp, job["remote_report"] + "/" + name); sftp.get(job["remote_report"] + "/" + name, str(local / name))
            check = (local / "check_power.rpt").read_text(errors="replace")
            if re.search(r"(?i)\b(error|violation)\b", check) and not re.search(r"(?i)(0\s+errors?|errors?\s*:\s*0|0\s+violations?)", check):
                raise RuntimeError("check_power not clean " + job["id"])
            act = (local / "activity.rpt").read_text(errors="replace")
            if re.search(r"(?i)(no\s+switching\s+activity|0\s+annotated)", act): raise RuntimeError("zero activity " + job["id"])
            dynamic, leakage, total = parse_power_report(local / "power.rpt"); a = activity[job["id"]]
            duration_ns = (a["measurement_end_ps"] - a["measurement_start_ps"]) / 1000.0
            energy_j = total * duration_ns * 1e-9
            rows.append({"id": job["id"], "design": "SYNC_PROP_temp64_B8", "load": job["load"],
                         "window_start_ps": a["measurement_start_ps"], "window_end_ps": a["measurement_end_ps"],
                         "dynamic_power_w": dynamic, "leakage_power_w": leakage, "total_power_w": total,
                         "total_energy_j": energy_j, "delivered_flits": a["delivered_flits"],
                         "total_pj_per_delivered_flit": energy_j * 1e12 / a["delivered_flits"],
                         "vcd_sha256": a["vcd_sha256"], "power_report_sha256": sha(local / "power.rpt"),
                         "ptpx_job_id": job["job_id"], "pass": True,
                         "physical_class": "post-synthesis time-based PT-PX estimate; pre-CTS clock activity"})
            print("SYNC64_POWER_PTPX_ACCEPTED", job["id"], "total_w=" + str(total), flush=True)
        state["accepted_ptpx"] = rows; state["stages"]["ptpx"] = "PASS"; save(out, state)
    finally:
        if sftp: sftp.close()
        client.close()


def finalize(out: Path) -> None:
    state = load(out); rows = state.get("accepted_ptpx", [])
    if len(rows) != 2 or {x["id"] for x in rows} != {x[0] for x in POINTS}: raise RuntimeError("two accepted Sync PT-PX points required")
    fields = list(rows[0]);
    with (out / "power_summary.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields); writer.writeheader(); writer.writerows(rows)
    (out / "power_acceptance.csv").write_bytes((out / "power_summary.csv").read_bytes())
    (out / "async_sync_power.csv").write_text("", encoding="utf-8")
    combined = []
    for row in state["async_reuse"]:
        combined.append({"clocking": "Async", "load": 100 if row["id"] == "prop_m100" else 420, "total_power_w": row["total_power_w"], "total_pj_per_delivered_flit": row["total_pj_per_delivered_flit"], "source_id": row["id"]})
    for row in rows:
        combined.append({"clocking": "Sync", "load": row["load"], "total_power_w": row["total_power_w"], "total_pj_per_delivered_flit": row["total_pj_per_delivered_flit"], "source_id": row["id"]})
    with (out / "async_sync_power.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(combined[0])); writer.writeheader(); writer.writerows(combined)
    (out / "RESULTS.md").write_text("# Sync64 power\n\nM100 and common-high M420 passed frozen-netlist, measurement-window, time-based PT-PX. Results include active synchronous clock power before CTS and are not post-layout measurements.\n", encoding="utf-8")
    state["stages"]["finalize"] = "PASS"; state["finalized_utc"] = datetime.now(timezone.utc).isoformat(); save(out, state)
    print("SYNC64_POWER_FINALIZE_PASS", out, flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("preflight", "submit-activity", "retry-activity", "status", "collect-activity", "submit-ptpx", "retry-ptpx-m100", "collect-ptpx", "finalize"))
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args(); out = archive(args.run_id)
    if args.stage == "preflight": preflight(out, args.run_id)
    elif args.stage == "submit-activity": submit_activity(out)
    elif args.stage == "retry-activity": submit_activity(out, retry=True)
    elif args.stage == "status": status(out)
    elif args.stage == "collect-activity": collect_activity(out)
    elif args.stage == "submit-ptpx": submit_ptpx(out)
    elif args.stage == "retry-ptpx-m100": submit_ptpx(out, retry_m100=True)
    elif args.stage == "collect-ptpx": collect_ptpx(out)
    else: finalize(out)


if __name__ == "__main__": main()

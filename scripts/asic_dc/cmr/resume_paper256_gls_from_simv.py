#!/usr/bin/env python3
"""Resume 256-node GLS from existing simv workdirs (skip VCS compile).

Used when LSF jobs burned their CPU budget on compile and died before
TB_RESULT. Reuses WORK/simv if present; otherwise falls back to full script.
"""
from __future__ import annotations

import json
import os
import shlex
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import job_id  # noqa: E402

REMOTE_ROOT = "/home/ghy19/Asynchronous_Router_CMR"
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
NETLIST = "20260914_prop_temp256_b8_hier_dc_06"
TOP = "PROP_temp256"

# (run_id, case_stem)
JOBS = [
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_low_native_PROP_temp256_top0"),
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_low_repeated_PROP_temp256_top0"),
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_medium_native_PROP_temp256_top0"),
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_medium_repeated_PROP_temp256_top0"),
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_high_native_PROP_temp256_top0"),
    ("20260915_121842_cmr_e2_f16_cross_tier256", "MC-F16_n256_s202701_high_repeated_PROP_temp256_top0"),
    ("20260915_121920_cmr_e1_ur_three_dut256", "TOPO-UR_n256_s202701_m5_PROP_temp256_top0"),
    ("20260915_121920_cmr_e1_ur_three_dut256", "TOPO-UR_n256_s202701_m20_PROP_temp256_top0"),
]


def wrapper_body(run_id: str, stem: str) -> str:
    work = "%s/sim/work/%s/sdf/%s" % (REMOTE_ROOT, run_id, stem)
    log = "%s/logs/gls/%s/sdf/%s" % (REMOTE_ROOT, run_id, stem)
    csv = "%s/results/%s/csv/sdf_%s.csv" % (REMOTE_ROOT, run_id, stem)
    case = "%s/sim/cases_network/%s.case" % (REMOTE_ROOT, stem)
    return """#!/bin/bash
source /etc/profile 2>/dev/null || true
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
set -euo pipefail
WORK=%s
LOG=%s
CSV=%s
CASE_FILE=%s
mkdir -p "$LOG" "$(dirname "$CSV")"
test -x "$WORK/simv"
cd "$WORK"
set +e
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \\
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \\
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" \\
  +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 \\
  +STALL_TIMEOUT_NS=1200000 +HARD_TIMEOUT_NS=6000000 \\
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp -f sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp -f "$CSV" "$LOG/result.csv" 2>/dev/null || true
if [[ ! -s "$LOG/sdf_annotate.log" ]]; then echo CMR_NETWORK_GLS_FAIL missing sdf_annotate.log; exit 2; fi
if ! grep -q 'TB_RESULT PASS' "$LOG/run.log" "$LOG/stdout.log"; then
  echo CMR_NETWORK_GLS_FAIL missing TB_RESULT PASS; exit 2
fi
echo CMR_NETWORK_GLS_PASS %s | tee -a "$LOG/stdout.log"
exit "$rc"
""" % (
        shlex.quote(work)[1:-1] if False else work,
        log,
        csv,
        case,
        stem,
    )


def main() -> int:
    client = connect_failover()
    submitted = []
    try:
        for run_id, stem in JOBS:
            rel = "logs/gls/%s/sdf_%s_resume.sh" % (run_id, stem)
            body = wrapper_body(run_id, stem)
            # write via python heredoc on remote
            client, _ = remote_run_failover(
                client,
                "mkdir -p %s/logs/gls/%s && cat > %s/%s <<'EOF'\n%s\nEOF\nchmod +x %s/%s"
                % (REMOTE_ROOT, run_id, REMOTE_ROOT, rel, body, REMOTE_ROOT, rel),
            )
            job_log = "%s/logs/gls/%s/sdf_%s_resume.job.log" % (REMOTE_ROOT, run_id, stem)
            client, out = remote_run_failover(
                client,
                "bsub -n 8 -W 720 %s -o %s -e %s.err -J %s %s/%s"
                % (
                    HOSTS,
                    shlex.quote(job_log),
                    shlex.quote(job_log),
                    shlex.quote("resume_" + stem[:40]),
                    REMOTE_ROOT,
                    rel,
                ),
            )
            jid = job_id(out)
            print("RESUME_SUBMITTED", stem, jid, flush=True)
            submitted.append({"case": stem, "run_id": run_id, "job": jid})
    finally:
        client.close()
    out = HERE / "results" / "paper256_gls_resume"
    out.mkdir(parents=True, exist_ok=True)
    (out / "state.json").write_text(json.dumps({"jobs": submitted}, indent=2), encoding="utf-8")
    print("RESUME_COUNT", len(submitted), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

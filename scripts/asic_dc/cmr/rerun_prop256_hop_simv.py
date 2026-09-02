#!/usr/bin/env python3
"""Run already-linked KEY-256 simv with +HOP_PROBE on a free node."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry, job_id

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN = "20260901_192534_cmr_descal_prop256_hop"
CASE = "KEY-256_n256_s900001_zero_PROP256_top0"
WORK = "%s/sim/work/%s/rtl/%s" % (ROOT, RUN, CASE)
LOG = "%s/logs/gls/%s/rtl/%s" % (ROOT, RUN, CASE)
CASE_FILE = "%s/sim/cases_noc256/%s.case" % (ROOT, CASE)
CSV = "%s/results/%s/csv/rtl_%s.csv" % (ROOT, RUN, CASE)

WRAP = ROOT + "/logs/gls/%s/rerun_hop.sh" % RUN


def main() -> int:
    body = r"""#!/bin/bash
source /etc/profile 2>/dev/null || true
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
cd %(work)s
chmod +x ./simv
./simv +CASE_FILE=%(case)s +RESULT_CSV=%(csv)s \
  +EVENT_CSV=%(log)s/events.csv +LATENCY_CSV=%(log)s/latency.csv \
  +V3_METRICS_CSV=%(log)s/v3_metrics.csv \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS=0.05 \
  +HOP_PROBE -l %(log)s/run.log 2>&1 | tee %(log)s/stdout.log
""" % {"work": WORK, "case": CASE_FILE, "csv": CSV, "log": LOG}
    client = connect()
    sftp = client.open_sftp()
    tmp = WRAP + ".upload"
    with sftp.file(tmp, "w") as handle:
        handle.write(body.replace("\r\n", "\n"))
    try:
        sftp.remove(WRAP)
    except IOError:
        pass
    sftp.rename(tmp, WRAP)
    sftp.close()
    client, _ = remote_run_retry(client, "chmod +x %s; sed -i 's/\\r$//' %s" % (WRAP, WRAP))
    client, submit = remote_run_retry(
        client,
        'bsub -n 8 -m "node26 node24 node18" -o %s/rerun_hop.bsub.log '
        "-e %s/rerun_hop.bsub.err -J cmr_descal_noc256_prop_hop_rerun %s"
        % (ROOT + "/logs/gls/" + RUN, ROOT + "/logs/gls/" + RUN, WRAP),
    )
    print(submit, flush=True)
    print("HOP_RERUN", job_id(submit), flush=True)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

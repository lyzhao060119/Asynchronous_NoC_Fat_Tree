#!/usr/bin/env python3
"""Read-only then LSF-batch probe of ICC2 / ICC / Innovus / TSMC 28HPC+ PDK.

Login-node license checkout is forbidden.  Binary existence and PDK listing
are allowed on the login node; actual tool startup uses bsub.
"""
from __future__ import annotations

import json
import os
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))

from run_remote_cmr_flow import atomic_put_bytes, job_id, remote_run, wait_job  # noqa: E402
from run_remote_cmr_noc16_sdf import connect  # noqa: E402


ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
RUN_ID = os.environ.get(
    "CMR_PNR_PROBE_RUN_ID",
    datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S") + "_cmr_pnr_probe",
)
LOCAL = REPO / "scripts" / "asic_pnr" / "cmr" / "results" / RUN_ID
SKIP_LSF = os.environ.get("CMR_PNR_PROBE_SKIP_LSF", "0") == "1"

DISCOVER_SH = r"""
set -eu
printf 'HOST=%s\n' "$(hostname)"
printf 'DATE=%s\n' "$(date -Iseconds)"
printf 'USER=%s\n' "$(id -un)"
printf 'PWD=%s\n' "$(pwd)"
printf 'MODULE_AVAIL\n'
module avail syn icc icc2 innovus cadence synopsys 2>&1 | sed -n '1,80p' || true
printf 'BINARIES\n'
for p in \
  /soft/synopsys/icc2/V-2023.12/bin/icc2_shell \
  /soft/synopsys/icc2/V-2023.12/bin/icc2_lm_shell \
  /soft/synopsys/syn/V-2023.12/bin/dc_shell-t \
  /soft/synopsys/pts/V-2023.12/bin/pt_shell \
  /soft/synopsys/icc/O-2018.06-SP5/bin/icc_shell \
  /soft/cadence/INNOVUS21/bin/innovus \
  /soft/cadence/INNOVUS21/tools/bin/innovus
do
  if [ -x "$p" ]; then printf 'EXE_OK %s\n' "$p"; else printf 'EXE_MISSING %s\n' "$p"; fi
done
printf 'WHICH\n'
for x in icc2_shell icc_shell icc2_lm_shell innovus pt_shell dc_shell-t; do
  w=$(command -v "$x" 2>/dev/null || true)
  printf 'WHICH_%s=%s\n' "$x" "${w:-MISSING}"
done
printf 'LICENSE_ENV\n'
printenv SNPSLMD_LICENSE_FILE LM_LICENSE_FILE CDS_LIC_FILE CDS_LIC_ONLY 2>/dev/null || true
printf 'PDK_ROOTS\n'
for d in \
  /process/tsmc/CLN28HPC+ \
  /process/tsmc/CLN28HPC+/TSMCHOME \
  /process/course_lib/t28hpc+
do
  if [ -d "$d" ]; then printf 'DIR_OK %s\n' "$d"; else printf 'DIR_MISSING %s\n' "$d"; fi
done
printf 'LEF\n'
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef 2>/dev/null | head
printf 'MW\n'
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/milkyway/tcbn28hpcplusbwp12t30p140_170a 2>/dev/null | head
printf 'GDS\n'
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/gds/tcbn28hpcplusbwp12t30p140_170a 2>/dev/null | head
printf 'NDM\n'
find /process/tsmc/CLN28HPC+/TSMCHOME/digital -maxdepth 4 -iname '*ndm*' -o -iname '*.nlib' -o -iname '*ndm' 2>/dev/null | head -40
printf 'CCS\n'
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS 2>/dev/null | head
printf 'TECH_TF\n'
find /process/tsmc/CLN28HPC+/TSMCHOME -maxdepth 6 \( -name '*.tf' -o -name '*tech.lef' -o -name '*Tech.lef' \) 2>/dev/null | head -40
printf 'RC_KIT\n'
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/design_rule 2>/dev/null
ls -1 /process/tsmc/CLN28HPC+/TSMCHOME/PDK 2>/dev/null
printf 'FROZEN_NETLISTS\n'
for rid in \
  20260830_cmr_thin_l1_hop_del050_ackin050 \
  20260830_cmr_fat_l2_hop_del050_ackin050 \
  20260830_cmr_fat_l1_hop_del050_ackin050 \
  20260830_cmr_router_level_baseline_del050 \
  20260831_014622_cmr_sync_noc64_thin_p50 \
  20260831_084457_cmr_sync_noc64_fat1222_p50 \
  20260901_cmr_sync_noc64_thin_p50 \
  20260901_cmr_sync_noc64_fat1222_p50 \
  20260830_095259_cmr_noc64_p50_1222 \
  20260828_cmr_cfifo_tp_nogrant_p50
do
  v="$CMR_REMOTE_ROOT/outputs/$rid/CMRRouter_post.v"
  n="$CMR_REMOTE_ROOT/outputs/$rid/NoC_64nodes_post.v"
  m="$CMR_REMOTE_ROOT/outputs/$rid/CMRMeshNoC_post.v"
  s="$CMR_REMOTE_ROOT/outputs/$rid/SyncNoC_64nodes_post.v"
  if [ -s "$v" ]; then printf 'NETLIST_OK %s CMRRouter_post.v\n' "$rid"
  elif [ -s "$n" ]; then printf 'NETLIST_OK %s NoC_64nodes_post.v\n' "$rid"
  elif [ -s "$m" ]; then printf 'NETLIST_OK %s CMRMeshNoC_post.v\n' "$rid"
  elif [ -s "$s" ]; then printf 'NETLIST_OK %s SyncNoC_64nodes_post.v\n' "$rid"
  else printf 'NETLIST_MISSING %s\n' "$rid"
  fi
done
printf 'RECENT_MESH64\n'
ls -1dt "$CMR_REMOTE_ROOT/outputs/"*mesh64* 2>/dev/null | head -8 || true
printf 'PROBE_LISTING_DONE\n'
"""


ICC2_LIC = r"""
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export PATH=/soft/synopsys/icc2/V-2023.12/bin:$PATH
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
icc2_shell -batch -x 'puts "ICC2_LICENSE_OK version=[version]"; exit'
"""

ICC_LIC = r"""
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
for p in /soft/synopsys/icc/*/bin/icc_shell; do
  if [ -x "$p" ]; then export PATH="$(dirname "$p"):$PATH"; break; fi
done
if command -v icc_shell >/dev/null 2>&1; then
  icc_shell -x 'puts "ICC_LICENSE_OK version=[version]"; exit'
else
  echo ICC_LICENSE_MISSING_BINARY
  exit 2
fi
"""

INNOVUS_LIC = r"""
source /etc/profile 2>/dev/null || true
export PATH=/soft/cadence/INNOVUS21/bin:/soft/cadence/INNOVUS21/tools/bin:$PATH
innovus -nowin -overwrite -init /dev/stdin <<'EOF'
puts "INNOVUS_LICENSE_OK version=$::env(INNOVUS_VERSION)"
exit
EOF
"""


def submit_probe(client, sftp, name: str, body: str) -> str:
    remote_dir = "%s/logs/pnr/%s" % (ROOT, RUN_ID)
    remote_run(client, "mkdir -p %s" % shlex.quote(remote_dir))
    wrapper = "%s/%s.sh" % (remote_dir, name)
    log = "%s/%s.log" % (remote_dir, name)
    atomic_put_bytes(client, sftp, ("#!/bin/bash\nset -euo pipefail\n" + body).encode(), wrapper)
    remote_run(client, "chmod +x %s" % shlex.quote(wrapper))
    submit = remote_run(
        client,
        "bsub -n 2 -o %s -e %s.err -J cmr_pnr_%s_%s %s"
        % (shlex.quote(log), shlex.quote(log), name, RUN_ID, shlex.quote(wrapper)),
    )
    jid = job_id(submit)
    print("LSF_JOB", name, jid, flush=True)
    return jid


def fetch_log(client, name: str) -> str:
    path = "%s/logs/pnr/%s/%s.log" % (ROOT, RUN_ID, name)
    return remote_run(client, "cat %s 2>/dev/null || echo MISSING_LOG" % shlex.quote(path))


def main() -> int:
    LOCAL.mkdir(parents=True, exist_ok=True)
    client = connect()
    try:
        listing = remote_run(
            client,
            "export CMR_REMOTE_ROOT=%s; bash --noprofile --norc -s <<'EOS'\n%s\nEOS"
            % (shlex.quote(ROOT), DISCOVER_SH),
        )
        (LOCAL / "listing.txt").write_text(listing, encoding="utf-8")
        print(listing, flush=True)
        summary = {
            "run_id": RUN_ID,
            "remote_root": ROOT,
            "utc": datetime.now(timezone.utc).isoformat(),
            "listing_marker": "PROBE_LISTING_DONE" in listing,
            "icc2_bin": "EXE_OK /soft/synopsys/icc2/V-2023.12/bin/icc2_shell" in listing,
            "innovus_bin": any(
                line.startswith("EXE_OK ") and "innovus" in line.lower()
                for line in listing.splitlines()
            ),
            "pdk_root": "DIR_OK /process/tsmc/CLN28HPC+" in listing,
        }
        license = {}
        if not SKIP_LSF:
            sftp = client.open_sftp()
            jobs = {
                "icc2": submit_probe(client, sftp, "icc2_lic", ICC2_LIC),
                "icc": submit_probe(client, sftp, "icc_lic", ICC_LIC),
                "innovus": submit_probe(client, sftp, "innovus_lic", INNOVUS_LIC),
            }
            sftp.close()
            for name, jid in jobs.items():
                try:
                    wait_job(client, jid, "pnr_lic_" + name)
                    text = fetch_log(client, name + "_lic")
                except Exception as exc:  # noqa: BLE001
                    text = "JOB_ERROR %s" % exc
                (LOCAL / ("%s_lic.log" % name)).write_text(text, encoding="utf-8")
                license[name] = {
                    "job_id": jid,
                    "ok": any(
                        marker in text
                        for marker in (
                            "ICC2_LICENSE_OK",
                            "ICC_LICENSE_OK",
                            "INNOVUS_LICENSE_OK",
                        )
                    ),
                    "tail": "\n".join(text.splitlines()[-40:]),
                }
                print("LICENSE", name, license[name]["ok"], flush=True)
        summary["license"] = license
        (LOCAL / "probe_summary.json").write_text(
            json.dumps(summary, indent=2) + "\n", encoding="utf-8"
        )
        print("PROBE_SUMMARY", json.dumps(summary, indent=2), flush=True)
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Fetch LSF P&R probe logs and list PDK/tech files. Login-node listing only."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
from run_remote_cmr_flow import remote_run  # noqa: E402
from run_remote_cmr_noc16_sdf import connect  # noqa: E402

CMD = r"""
sh -c '
echo ==== LSF_LOGS ====
for f in /home/ghy19/Asynchronous_Router_CMR/logs/pnr/20260831_054314_cmr_pnr_probe/*; do
  echo "----- $f"
  tail -80 "$f" 2>/dev/null || true
done
echo ==== MODULES ====
module avail icc icc2 syn pt prime 2>&1 | head -60
ls -d /soft/synopsys/icc2/* /soft/synopsys/icc/* /soft/synopsys/pts/* /soft/synopsys/prime* /soft/synopsys/syn/* 2>/dev/null
echo ==== ICC_BIN ====
ls /soft/synopsys/icc2/V-2023.12/bin | head
ls /tools/env/module/synopsys 2>/dev/null | head
find /soft/synopsys -maxdepth 3 -name icc_shell -o -name pt_shell 2>/dev/null | head
echo ==== LEF_FULL ====
ls -l /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef
echo ==== MW_FULL ====
ls -l /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/milkyway/tcbn28hpcplusbwp12t30p140_170a
echo ==== CCS_LIB ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp12t30p140_180a | head
find /process/tsmc/CLN28HPC+/TSMCHOME/digital/Front_End/timing_power_noise/CCS/tcbn28hpcplusbwp12t30p140_180a -name "*ssg0p81v125c*" | head
echo ==== TECHFILES ====
find /process/tsmc/CLN28HPC+/TSMCHOME/PDK /process/tsmc/CLN28HPC+/TSMCHOME/design_rule /process/tsmc/CLN28HPC+/TSMCHOME/digital -iname "*.tf" -o -iname "*tech.lef" -o -iname "*9lm*" 2>/dev/null | head -80
echo ==== RC ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28clrp051_2_0 | head
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28cldr002_2_0 | head
ls /process/tsmc/CLN28HPC+/TSMCHOME/PDK/PDK1.8_2P3A | head
echo ==== COURSE_LIB ====
ls /process/course_lib/t28hpc+ | head -40
echo DONE
'
"""


def main() -> None:
    client = connect()
    try:
        print(remote_run(client, CMD))
    finally:
        client.close()


if __name__ == "__main__":
    main()

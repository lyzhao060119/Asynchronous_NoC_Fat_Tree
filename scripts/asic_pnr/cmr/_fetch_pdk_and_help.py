#!/usr/bin/env python3
"""Login-node listing: MW help dump, PDK tech files, extra EDA binaries."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
from run_remote_cmr_flow import remote_run  # noqa: E402
from run_remote_cmr_noc16_sdf import connect  # noqa: E402

CMD = r"""
sh -c '
echo ==== GENERATE_FRAME_HELP ====
cat /home/ghy19/Asynchronous_Router_CMR/work/generate_frame_from_mw.help 2>/dev/null || echo MISSING_HELP
echo ==== MW_DIR ====
MW=/process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/milkyway/tcbn28hpcplusbwp12t30p140_170a
ls -la "$MW"
echo ---- frame_only ----
ls -la "$MW/frame_only_VHV_0d5_0" | head -40
echo ---- frame_only inner ----
ls -la "$MW/frame_only_VHV_0d5_0/tcbn28hpcplusbwp12t30p140" | head -40
echo ---- cell_frame ----
ls -la "$MW/cell_frame_VHV_0d5_0" 2>/dev/null | head -20
echo ==== LEF_HEAD ====
head -80 /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef/tcbn28hpcplusbwp12t30p140.lef
echo ==== LEF_LAYER_COUNT ====
grep -c "^LAYER " /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef/tcbn28hpcplusbwp12t30p140.lef || true
echo ==== LEF_SIBLINGS ====
find /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef -maxdepth 3 -type d | head -80
echo ==== TECH_SEARCH ====
find /process/tsmc/CLN28HPC+ /process/course_lib/t28hpc+ -maxdepth 8 \( \
  -iname "*.tf" -o -iname "*tech*.lef" -o -iname "*techlef*" -o -iname "*prtf*" \
  -o -iname "*9lm*.lef" -o -iname "*.ndm" -o -iname "*icc2*" -o -iname "*innovus*" \
\) 2>/dev/null | head -120
echo ==== TSMC_HOME_TOP ====
ls /process/tsmc/CLN28HPC+/TSMCHOME
echo ==== DIGITAL_BE ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End
echo ==== COURSE_LIB ====
ls -la /process/course_lib/t28hpc+ | head -50
echo ==== EXTRA_BINS ====
ls -d /soft/synopsys/icc2 /soft/synopsys/icc /soft/synopsys/fc /soft/synopsys/fusion* /soft/synopsys/mw /soft/synopsys/milkyway /soft/cadence/INNOVUS21 /soft/cadence/QRC* /soft/cadence/QUANTUS* 2>/dev/null
find /soft/synopsys -maxdepth 3 -name fc_shell -o -name icc2_lm_shell -o -name mw_shell -o -name export_icc2_frame 2>/dev/null | head
echo ==== PDK18 ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/PDK/PDK1.8_2P3A | head -40
find /process/tsmc/CLN28HPC+/TSMCHOME/PDK/PDK1.8_2P3A -maxdepth 4 \( -iname "*lef*" -o -iname "*.tf" -o -iname "*tech*" \) 2>/dev/null | head -60
echo ==== DESIGN_RULE ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28clrp051_2_0 | head -40
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28cldr002_2_0 | head -40
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

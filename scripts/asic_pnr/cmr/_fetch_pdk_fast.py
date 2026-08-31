#!/usr/bin/env python3
"""Fast login-node listing: ICC bins, course_lib, OA PDK, no recursive TSMC find."""
from __future__ import annotations

import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "scripts" / "asic_dc" / "cmr"))
from run_remote_cmr_flow import remote_run  # noqa: E402
from run_remote_cmr_noc16_sdf import connect  # noqa: E402

CMD = r"""
bash --noprofile --norc -c '
echo ==== ICC_BIN ====
ls /soft/synopsys/icc/V-2023.12-SP5/bin 2>/dev/null | head -60
echo ==== ICC2_BIN ====
ls /soft/synopsys/icc2/V-2023.12/bin 2>/dev/null | head -40
echo ==== WHICH_ON_LOGIN ====
ls -l /soft/synopsys/icc/V-2023.12-SP5/bin/icc_shell /soft/synopsys/icc/V-2023.12-SP5/bin/Milkyway /soft/synopsys/icc/V-2023.12-SP5/bin/mw_shell 2>/dev/null
echo ==== TSMC_HOME ====
ls /process/tsmc/CLN28HPC+/TSMCHOME
echo ==== DIGITAL_BE ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End
echo ==== LEF_KIT ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef
echo ==== LEF_CELL_DIR ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp12t30p140_170a/lef
echo ==== MW_INNER ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/digital/Back_End/milkyway/tcbn28hpcplusbwp12t30p140_170a/frame_only_VHV_0d5_0/tcbn28hpcplusbwp12t30p140 | head -40
echo ==== COURSE_LIB ====
ls /process/course_lib/t28hpc+ | head -80
echo ==== PDK18 ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/PDK/PDK1.8_2P3A | head -40
echo ==== CDSLIB ====
head -40 /process/tsmc/CLN28HPC+/TSMCHOME/PDK/PDK1.8_2P3A/cds.lib 2>/dev/null || echo NO_CDSLIB
echo ==== DESIGN_RULE_RP ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28clrp051_2_0 | head -40
echo ==== DESIGN_RULE_DR ====
ls /process/tsmc/CLN28HPC+/TSMCHOME/design_rule/tn28cldr002_2_0 | head -40
echo ==== LMSTAT_SNPS ====
export SNPSLMD_LICENSE_FILE=1701@192.168.2.7:1701@192.168.2.153:1701@master
LMUTIL=/soft/synopsys/icc2/V-2023.12/bin/lmutil
if [ ! -x "$LMUTIL" ]; then LMUTIL=$(ls /soft/synopsys/*/lmutil /soft/synopsys/*/*/bin/lmutil 2>/dev/null | head -1); fi
if [ -x "$LMUTIL" ]; then
  "$LMUTIL" lmstat -c "$SNPSLMD_LICENSE_FILE" 2>/dev/null | grep -iE "icc2|Galaxy-ICC|Galaxy-Common|Milkyway|Design-Compiler|Prime" | head -40
else
  echo NO_LMUTIL
fi
echo FAST_DONE
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

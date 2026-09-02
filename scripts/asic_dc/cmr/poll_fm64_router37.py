#!/usr/bin/env python3
"""Names inside uniquified dest router CMRRouter_37 / meshR_4_5."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
POST = ROOT + "/outputs/20260901_172539_cmr_descal_fm64/CMRMeshNoC_post.v"
RTL = ROOT + "/rtl/mesh64/CMRMeshNoC.v"
GLS = ROOT + "/logs/gls/20260901_172539_cmr_descal_fm64"


def main() -> int:
    client = connect()
    cmd = r"""
echo ===CSV_ALL===
cat %(gls)s/sdf/DBG-64_fm64_6to44/events.csv
echo ===TOPO_MISSING===
grep TB_MISSING %(gls)s/sdf/TOPO-UR_n64_s900001_zero_FM64_top0/run.log | head
echo ===ROUTER37_HEAD===
awk '/^module CMRRouter_37 /{p=1} p{print} /^endmodule/{if(p){exit}}' %(post)s | head -n 80
echo ===ROUTER37_OPM===
awk '/^module CMRRouter_37 /{p=1} p{print} /^endmodule/{if(p){exit}}' %(post)s | grep -E 'OPM|OutputPortModules|InputPortModules|PktPath|TailPassed|io_outputs_parent' | head -n 60
echo ===RTL_PARENT===
grep -n 'io_outputs_parent_0' %(rtl)s | head -n 20
echo ===MESH_WIRES_45===
grep -n 'meshR_4_5_io_' %(post)s | grep -E 'parent|child_1' | head -n 40
""" % {"gls": GLS, "post": POST, "rtl": RTL}
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Pull FM64 SDF artifacts and dest-router hierarchy. No DC, no VCD."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run_retry

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
STAMP = "20260901_172539_cmr_descal_fm64"


def main() -> int:
    client = connect()
    cmd = """
OUT=%(root)s/outputs/%(stamp)s
GLS=%(root)s/logs/gls/%(stamp)s
RTL=%(root)s/rtl/mesh64/CMRMeshNoC.v
echo ===HIER_POST===
grep -n 'meshR_4_5' $OUT/CMRMeshNoC_post.v | head -n 20
echo ===MODULE_POST===
grep -n 'module CMR' $OUT/CMRMeshNoC_post.v | head -n 20
echo ===BLOCKSET===
echo -n post_BlockSet=; grep -c BlockSet $OUT/CMRMeshNoC_post.v
echo -n post_OPMSelector=; grep -c OPMSelector $OUT/CMRMeshNoC_post.v
echo ===HIER_RTL===
grep -n 'meshR_4_5\\|OutputPortModules_4' $RTL | head -n 30
echo ===EVENTS_LS===
ls -la $GLS/sdf/DBG-64_fm64_6to44/ | head
echo ===CSV===
head -n 5 $GLS/sdf/DBG-64_fm64_6to44/events.csv
echo ---rx---
grep ',44,' $GLS/sdf/DBG-64_fm64_6to44/events.csv | head -n 20
echo ===UNEX===
grep -E 'TB_UNEX_|TB_RESULT|TB_MESH_LOCAL44|TB_UNEXPECTED' $GLS/sdf/DBG-64_fm64_6to44/run.log | head -n 80
echo ===TOPO_MISS===
grep -E 'TB_MISSING_PORT|TB_STALL|TB_RESULT' $GLS/sdf/TOPO-UR_n64_s900001_zero_FM64_top0/run.log | head -n 40
""" % {"root": ROOT, "stamp": STAMP}
    client, text = remote_run_retry(client, cmd)
    print(text)
    client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

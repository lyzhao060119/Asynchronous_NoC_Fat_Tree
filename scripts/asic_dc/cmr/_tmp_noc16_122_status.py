import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run

c = connect()
cmd = r"""
ROOT=/home/ghy19/Asynchronous_Router_CMR
RID=20260830_104653_cmr_noc16_122_p50
echo '=== 122 DC MARKERS ==='
grep -E 'CMR_NOC16_STRUCTURE|CMR_NOC16_DC_PASS|CMR_NOC16_DC_FAIL|CMR_NOC16_BYPASS' "$ROOT/logs/dc/${RID}.log" 2>/dev/null | grep -v 'puts '
echo '=== FUNC TAB GREP ==='
grep -E 'TB_RESULT|TB_STALL_FAIL |TB_X_FAIL|TB_UNEXPECTED|TB_INFO NUM_CORES|TB_FATAL' \
  "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50/run.log" \
  "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50/stdout.log" 2>/dev/null | head -n 40
echo '=== FUNC SMOKE ==='
grep -E 'TB_RESULT' "$ROOT/logs/gls/$RID/func/noc16_00_to_33_3flit_sdf/run.log" 2>/dev/null
echo '=== 1248 JOB ==='
bjobs -noheader -o 'jobid stat job_name run_time' 11487901 2>/dev/null
"""
print(remote_run(c, cmd))
c.close()

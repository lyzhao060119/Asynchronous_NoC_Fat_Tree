import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run

c = connect()
cmd = r"""
ROOT=/home/ghy19/Asynchronous_Router_CMR
RID=20260830_095259_cmr_noc64_p50_1222
echo '=== 1222 DC MARKERS ==='
grep -E 'CMR_NOC64_|Error:|error:' "$ROOT/logs/dc/${RID}.log" 2>/dev/null | tail -n 40
echo '=== 1222 FUNC TAB DIR ==='
ls -la "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50" 2>/dev/null
echo '=== 1222 FUNC TAB BSUB TAIL ==='
tail -c 6000 "$ROOT/logs/gls/$RID/func_TAB-NET-UR-3f-r0p50.bsub.log" 2>/dev/null
echo
echo '=== 1222 FUNC TAB BSUB ERR ==='
tail -c 3000 "$ROOT/logs/gls/$RID/func_TAB-NET-UR-3f-r0p50.bsub.err" 2>/dev/null
echo
echo '=== 1222 FUNC TAB RUN GREP ==='
grep -E 'TB_|FATAL|Error|error|CMR_NOC64_GLS|CPU Time|Out of memory' \
  "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50/run.log" \
  "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50/compile.log" \
  "$ROOT/logs/gls/$RID/func/TAB-NET-UR-3f-r0p50/stdout.log" 2>/dev/null | tail -n 80
echo '=== 1222 FUNC SMOKE ==='
grep -E 'TB_RESULT' "$ROOT/logs/gls/$RID/func/noc64_00_to_77_3flit/run.log" 2>/dev/null
echo '=== 1248 JOB ==='
bjobs -noheader -o 'jobid stat job_name run_time' 11487901 2>/dev/null
echo '=== 1248 DC LOG ==='
ls -l "$ROOT/logs/dc/"*1248* 2>/dev/null
tail -n 20 "$ROOT/logs/dc/20260830_095259_cmr_noc64_p50_1248.log" 2>/dev/null
"""
print(remote_run(c, cmd))
c.close()

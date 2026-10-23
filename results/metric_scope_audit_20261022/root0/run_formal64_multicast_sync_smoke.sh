#!/bin/bash
# Compile Sync M16 and accept the lowest-load strict-SDF multicast smoke only
# after scoreboard, annotation, and timing diagnostics all pass.
set -euo pipefail
ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_SYNC64_RUN_ID:?}
CASE_NAME=${CMR_SYNC64_CASE_NAME:?}
bash "$ROOT/scripts/run_gls_cmr_sync_noc64.sh"
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
grep -Eq 'Total errors:[[:space:]]*0' "$LOG/sdf_annotate.log"
grep -Eq 'Doing SDF annotation .* Done' "$LOG/run.log"
grep -Eq 'TB_RESULT PASS injected=55000 delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0' "$LOG/run.log"
! grep -Eiq 'Total errors:[[:space:]]*[1-9]|Timing violation|TB_RESULT FAIL|TB_PROTOCOL_X|TB_FATAL|Fatal:' \
  "$LOG/sdf_annotate.log" "$LOG/run.log" "$LOG/stdout.log"
test -s "$LOG/result.csv" && test -s "$LOG/latency.csv"
echo "FORMAL64_SYNC_MC_SMOKE_PASS run=$RUN_ID case=$CASE_NAME"

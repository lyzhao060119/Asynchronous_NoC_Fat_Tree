#!/bin/bash
# One strict-SDF 30-point multicast sweep using the compiled Sync M16 simv.
set -euo pipefail
BENCHMARK=${1:?multicast benchmark id}
SEED=${2:?202701,202702,202703}
ROOT=${FORMAL64_REMOTE_ROOT:?}
RUN_ID=${FORMAL64_RUN_ID:?}
SIMV=${FORMAL64_SYNC_SIMV:?}
SDF_LOG=${FORMAL64_SYNC_SDF_LOG:?}
NETLIST_RUN_ID=${FORMAL64_NETLIST_RUN_ID:?}
ARCHIVE_ROOT=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
LOADS=(5 10 20 40 60 80 100 120 140 160 180 200 220 240 260 280 300 320 340 360 380 400 420 440 460 480 500 600 700 800)
case "$SEED" in 202701|202702|202703) ;; *) exit 2 ;; esac
test -x "$SIMV"
test -s "$SDF_LOG"
grep -Eq 'Total errors:[[:space:]]*0' "$SDF_LOG"
passed=0; failed=0
for load in "${LOADS[@]}"; do
  stem="${BENCHMARK}_n64_s${SEED}_m${load}_SYNC_PROP_temp64_m16_top64"
  case_file="$ROOT/cases/${stem}.case"
  log="$ROOT/logs/SYNC_M16/${stem}"
  csv="$ROOT/results/SYNC_M16/${stem}.csv"
  mkdir -p "$log" "$(dirname "$csv")"
  test -s "$case_file"
  cd "$log"
  sha256sum "$case_file" "$SIMV" \
    "$ARCHIVE_ROOT/outputs/$NETLIST_RUN_ID/SyncNoC_64nodes_post.v" \
    "$ARCHIVE_ROOT/outputs/$NETLIST_RUN_ID/SyncNoC_64nodes.sdf" > input_hashes.log
  set +e
  "$SIMV" +CASE_FILE="$case_file" +RESULT_CSV="$csv" \
    +EVENT_CSV=/dev/null +LATENCY_CSV="$log/latency.csv" \
    +FLIT_LATENCY_CSV=/dev/null +V3_METRICS_CSV="$log/v3_metrics.csv" \
    +CLOCK_PERIOD_NS=1.0 +CASE_TICK_NS=1 +RX_CAPTURE_NS=0 \
    -l "$log/run.log" > "$log/stdout.log" 2>&1
  rc=$?
  set -e
  cp "$SDF_LOG" "$log/sdf_annotate.log"
  if [[ "$rc" -eq 0 ]] && \
     grep -Eq 'Doing SDF annotation .* Done' "$log/run.log" && \
     grep -Eq 'TB_RESULT PASS injected=55000 delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0' "$log/run.log" && \
     ! grep -Eiq 'Total errors:[[:space:]]*[1-9]|Timing violation|TB_RESULT FAIL|TB_PROTOCOL_X|TB_FATAL|Fatal:' "$log/sdf_annotate.log" "$log/run.log" "$log/stdout.log" && \
     test -s "$csv"; then
    gzip -f "$log/latency.csv"
    passed=$((passed+1)); echo "FORMAL64_SYNC_MC_CASE_PASS benchmark=$BENCHMARK seed=$SEED load=$load" | tee acceptance.log
  else
    failed=$((failed+1)); echo "FORMAL64_SYNC_MC_CASE_FAIL benchmark=$BENCHMARK seed=$SEED load=$load rc=$rc" | tee acceptance.log
  fi
done
echo "FORMAL64_SYNC_MC_GRID_COMPLETE benchmark=$BENCHMARK seed=$SEED passed=$passed failed=$failed"
if [[ "$passed" -eq 30 ]] && [[ "$failed" -eq 0 ]]; then
  echo "FORMAL64_SYNC_MC_GRID_PASS benchmark=$BENCHMARK seed=$SEED"
else
  echo "FORMAL64_SYNC_MC_GRID_PRESSURE_COMPLETE benchmark=$BENCHMARK seed=$SEED passed=$passed failed=$failed"
fi

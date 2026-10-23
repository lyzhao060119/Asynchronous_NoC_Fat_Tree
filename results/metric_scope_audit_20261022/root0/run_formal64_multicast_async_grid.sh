#!/bin/bash
# One strict-SDF 30-point multicast sweep for an asynchronous 64-node DUT.
set -euo pipefail
DESIGN=${1:?PROP_M16, FM64, or PFAT64}
BENCHMARK=${2:?multicast benchmark id}
SEED=${3:?202701,202702,202703}
ROOT=${FORMAL64_REMOTE_ROOT:?}
RUN_ID=${FORMAL64_RUN_ID:?}
NETLIST_RUN_ID=${FORMAL64_NETLIST_RUN_ID:?}
ARCHIVE_ROOT=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
RUNNER="$ROOT/run_e2_bc_hotspot64_remote.sh"
LOADS=(5 10 20 40 60 80 100 120 140 160 180 200 220 240 260 280 300 320 340 360 380 400 420 440 460 480 500 600 700 800)
case "$DESIGN" in
  PROP_M16) CASE_DESIGN=PROP_temp64_m16; TOP=64 ;;
  FM64) CASE_DESIGN=FM64; TOP=0 ;;
  PFAT64) CASE_DESIGN=PFAT64; TOP=8 ;;
  *) exit 2 ;;
esac
case "$SEED" in 202701|202702|202703) ;; *) exit 2 ;; esac
if [[ "${FORMAL64_SKIP_COMPILE:-0}" != 1 ]]; then
  env E2_REMOTE_ROOT="$ROOT" E2_RUN_ID="$RUN_ID" E2_NETLIST_RUN_ID="$NETLIST_RUN_ID" \
    CMR_ARCHIVE_ROOT="$ARCHIVE_ROOT" bash "$RUNNER" compile "$DESIGN"
fi
passed=0; failed=0
for load in "${LOADS[@]}"; do
  stem="${BENCHMARK}_n64_s${SEED}_m${load}_${CASE_DESIGN}_top${TOP}"
  case_file="$ROOT/cases/${stem}.case"
  result_name="${BENCHMARK}_n64_s${SEED}_m${load}_${DESIGN}"
  test -s "$case_file"
  if env E2_REMOTE_ROOT="$ROOT" E2_RUN_ID="$RUN_ID" E2_NETLIST_RUN_ID="$NETLIST_RUN_ID" \
      CMR_ARCHIVE_ROOT="$ARCHIVE_ROOT" E2_ALLOW_MULTICAST=1 \
      E2_COMPACT_OUTPUT=1 \
      E2_CASE_NAME="$result_name" E2_CASE_FILE="$case_file" \
      bash "$RUNNER" run "$DESIGN"; then
    passed=$((passed+1))
  else
    failed=$((failed+1)); echo "FORMAL64_MC_CASE_FAIL $DESIGN $BENCHMARK $SEED $load"
  fi
done
echo "FORMAL64_MC_GRID_COMPLETE design=$DESIGN benchmark=$BENCHMARK seed=$SEED passed=$passed failed=$failed"
if [[ "$passed" -eq 30 ]] && [[ "$failed" -eq 0 ]]; then
  echo "FORMAL64_MC_GRID_PASS design=$DESIGN benchmark=$BENCHMARK seed=$SEED"
else
  # Saturation/timeouts are retained as pressure results, but must not prevent
  # the next independent seed or benchmark from running.  The low-load smoke
  # is the correctness gate; collectors exclude failed points from curves.
  echo "FORMAL64_MC_GRID_PRESSURE_COMPLETE design=$DESIGN benchmark=$BENCHMARK seed=$SEED passed=$passed failed=$failed"
fi

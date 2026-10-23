#!/bin/bash
# One resumable 30-point strict-SDF sweep for a topology/mode/seed tuple.
set -euo pipefail

DESIGN=${1:?PFAT64, PROP_M16, or FM64}
BENCHMARK=${2:?TOPO-UR, TOPO-BC, or HOTSPOT10}
SEED=${3:?canonical seed}
ROOT=${E2_REMOTE_ROOT:?}
RUN_ID=${E2_RUN_ID:?}
NETLIST_RUN_ID=${E2_NETLIST_RUN_ID:?}
ARCHIVE_ROOT=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
RUNNER="$ROOT/run_e2_bc_hotspot64_remote.sh"
LOADS=(5 10 20 40 60 80 100 120 140 160 180 200 220 240 260 280 300 320 340 360 380 400 420 440 460 480 500 600 700 800)

case "$DESIGN" in PFAT64|PROP_M16|FM64) ;; *) exit 2 ;; esac
case "$BENCHMARK" in TOPO-UR|TOPO-BC|HOTSPOT10) ;; *) exit 2 ;; esac
case "$SEED" in 202701|202702|202703) ;; *) exit 2 ;; esac

# M16 intentionally consumes the same core-only PFAT64 materialization.
CASE_DESIGN=$DESIGN
CASE_SUFFIX=$DESIGN
if [[ "$DESIGN" == PROP_M16 ]]; then
  CASE_DESIGN=PFAT64
  CASE_SUFFIX=PFAT64_top8
elif [[ "$DESIGN" == PFAT64 ]]; then
  CASE_SUFFIX=PFAT64_top8
elif [[ "$DESIGN" == FM64 ]]; then
  CASE_SUFFIX=FM64_top0
fi

if [[ "${E2_SKIP_COMPILE:-0}" != 1 ]]; then
  env E2_REMOTE_ROOT="$ROOT" E2_RUN_ID="$RUN_ID" \
      E2_NETLIST_RUN_ID="$NETLIST_RUN_ID" CMR_ARCHIVE_ROOT="$ARCHIVE_ROOT" \
      bash "$RUNNER" compile "$DESIGN"
else
  test -x "$ROOT/work/$DESIGN/simv"
fi

passed=0
failed=0
attempted=0
for load in "${LOADS[@]}"; do
  case_name="${BENCHMARK}_n64_s${SEED}_m${load}_${CASE_SUFFIX}"
  case_file="$ROOT/cases/${case_name}.case"
  result_name="${BENCHMARK}_n64_s${SEED}_m${load}_${DESIGN}"
  case_log="$ROOT/logs/$DESIGN/$result_name"
  result_csv="$ROOT/results/$DESIGN/$result_name.csv"
  test -s "$case_file"
  if [[ -s "$result_csv" && -s "$case_log/stage.log" && -s "$case_log/run.log" ]] &&
     grep -q 'E2_CASE_PASS' "$case_log/stage.log" &&
     grep -q 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' "$case_log/run.log"; then
    echo "E2_GRID_RESUME_SKIP design=$DESIGN benchmark=$BENCHMARK seed=$SEED load=$load"
    passed=$((passed + 1))
    attempted=$((attempted + 1))
    continue
  fi
  attempted=$((attempted + 1))
  if env E2_REMOTE_ROOT="$ROOT" E2_RUN_ID="$RUN_ID" \
         E2_NETLIST_RUN_ID="$NETLIST_RUN_ID" CMR_ARCHIVE_ROOT="$ARCHIVE_ROOT" \
         E2_CASE_NAME="$result_name" E2_CASE_FILE="$case_file" \
         bash "$RUNNER" run "$DESIGN"; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "E2_GRID_CASE_FAIL design=$DESIGN benchmark=$BENCHMARK seed=$SEED load=$load case=$result_name"
  fi
done

test "$attempted" -eq 30
echo "E2_GRID_COMPLETE design=$DESIGN benchmark=$BENCHMARK seed=$SEED attempted=$attempted passed=$passed failed=$failed"
if [[ "$failed" -eq 0 ]]; then
  echo "E2_GRID_PASS design=$DESIGN benchmark=$BENCHMARK seed=$SEED cases=$passed"
fi

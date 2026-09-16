#!/bin/bash
# One benchmark job; each load is a paired configuration and fails closed.
set -euo pipefail
ROOT=${E2_REMOTE_ROOT:?}
RUN_ID=${E2_RUN_ID:?}
BENCHMARK=${1:?TOPO-BC or HOTSPOT10}
ARCHIVE=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
case "$BENCHMARK" in TOPO-BC|HOTSPOT10) ;; *) exit 2 ;; esac
SHELL="$ROOT/run_e2_bc_hotspot64_remote.sh"
LOADS=(10 20 $(seq 40 20 500) 600 700 800)
test "${#LOADS[@]}" -eq 29
test -s "$ROOT/e2_input_manifest.json"
command -v flock >/dev/null

for load in "${LOADS[@]}"; do
  echo "E2_PAIR_BEGIN benchmark=$BENCHMARK load=$load"
  for design in PROP_temp64 FM64; do
    if [[ "$design" == PROP_temp64 ]]; then
      netlist=20260913_prop_temp64_asap_uc_m5_200
      top=16
    else
      netlist=20260913_104506_cmr_fm64_rpsdel150
      top=0
    fi
    name="${BENCHMARK}_n64_s202701_m${load}_${design}_top${top}"
    test -s "$ROOT/cases/$name.case"
    # $sdf_annotate writes into simv's compilation directory. Serialize any
    # runs sharing this design's simv until the per-case log is moved away.
    if ! flock -x "$ROOT/work/$design/e2_sdf.lock" env \
      E2_REMOTE_ROOT="$ROOT" E2_RUN_ID="$RUN_ID" \
      E2_NETLIST_RUN_ID="$netlist" CMR_ARCHIVE_ROOT="$ARCHIVE" \
      E2_CASE_NAME="$name" E2_CASE_FILE="$ROOT/cases/$name.case" \
      bash "$SHELL" run "$design"; then
      echo "E2_BENCHMARK_STOP benchmark=$BENCHMARK load=$load design=$design"
      exit 3
    fi
  done
  echo "E2_PAIR_PASS benchmark=$BENCHMARK load=$load"
done
echo "E2_BENCHMARK_PASS benchmark=$BENCHMARK paired_loads=30"

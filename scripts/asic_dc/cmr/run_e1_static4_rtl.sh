#!/bin/bash
# DATE 2027 E1 Static4 RTL-only aggregate smoke/full-drain run. No DC/SDF.
set -euo pipefail

STAGE=${1:?compile-smoke or full}
ROOT=${E1_REMOTE_ROOT:?fresh E1 run directory}
RUN_ID=${E1_RUN_ID:?}
WORK="$ROOT/work"
LOG="$ROOT/logs/$STAGE"
TB="$ROOT/src/tb_cmr_router_multi_lane_agg.sv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
mkdir -p "$WORK" "$LOG"

if [[ "$STAGE" == compile-smoke ]]; then
  test -s "$ROOT/rtl/CMRRouter.v"
  test -s "$TB" && test -s "$ROOT/src/async_ports_c1_p4.vi"
  find "$ROOT/rtl" -maxdepth 1 -name '*.v' -type f -size 0 -print | grep -q . && {
    echo "E1_STATIC4_FAIL zero-size RTL" >&2; exit 2;
  } || true
  sha256sum "$ROOT"/rtl/*.v "$TB" "$ROOT/src/async_ports_c1_p4.vi" > "$LOG/input_hashes.sha256"
  {
    echo "$ROOT/rtl/CMRRouter.v"
    find "$ROOT/rtl" -maxdepth 1 -name '*.v' ! -name CMRRouter.v -type f | sort
    echo "$TB"
  } > "$WORK/filelist.f"
  cd "$WORK"
  vcs -full64 -sverilog -timescale=1ns/1ps +define+GEOM_C1_P4 \
    "+incdir+$ROOT/src" -f filelist.f -top tb_cmr_router_hop_ppa \
    -o simv -l "$LOG/compile.log"
  test -x simv
  echo "E1_STATIC4_COMPILE_PASS run=$RUN_ID" | tee "$LOG/stage.log"
  set +e
  ./simv +NO_FULL_VCD +NUM_PACKETS=20 +TX_SETUP_NS=0.05 \
    +RX_CAPTURE_NS=0.09 +HOP_KIND=static_c1p4 \
    +EVENT_CSV="$LOG/aggregate.csv" -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
  rc=${PIPESTATUS[0]}
  set -e
  grep -q 'AGG_RESULT PASS .*sent=400 received=400 parent_lanes=4' "$LOG/run.log"
  grep -q 'PPA_RESULT PASS geometry=static_c1p4 mode=multi_lane_agg' "$LOG/run.log"
  for lane in 0 1 2 3; do
    grep -q "AGG_LANE lane=$lane delivered_flits=100 utilization_share=0.250000000" "$LOG/run.log"
  done
  grep -q 'imbalance_max_over_mean=1.000000000' "$LOG/run.log"
  ! grep -Eiq 'AGG_FAIL|PPA_RESULT FAIL|Fatal:|ERROR:' "$LOG/run.log" "$LOG/stdout.log"
  test -s "$LOG/aggregate.csv"
  echo "E1_STATIC4_RTL_SMOKE_PASS sent=400 received=400 lanes=4x100 rc=$rc" | tee -a "$LOG/stage.log"
  exit "$rc"
fi

if [[ "$STAGE" != full ]]; then
  echo "E1_STATIC4_FAIL unknown stage=$STAGE" >&2
  exit 2
fi
test -x "$WORK/simv"
cd "$WORK"
echo "E1_STATIC4_FULL_RUN run=$RUN_ID" | tee "$LOG/stage.log"
set +e
./simv +NO_FULL_VCD +NUM_PACKETS=1000 +TX_SETUP_NS=0.05 \
  +RX_CAPTURE_NS=0.09 +HOP_KIND=static_c1p4 \
  +EVENT_CSV="$LOG/aggregate.csv" -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
grep -q 'AGG_RESULT PASS .*sent=20000 received=20000 parent_lanes=4' "$LOG/run.log"
grep -q 'PPA_RESULT PASS geometry=static_c1p4 mode=multi_lane_agg' "$LOG/run.log"
for lane in 0 1 2 3; do
  grep -q "AGG_LANE lane=$lane delivered_flits=5000 utilization_share=0.250000000" "$LOG/run.log"
done
grep -q 'imbalance_max_over_mean=1.000000000' "$LOG/run.log"
! grep -Eiq 'AGG_FAIL|PPA_RESULT FAIL|Fatal:|ERROR:' "$LOG/run.log" "$LOG/stdout.log"
test -s "$LOG/aggregate.csv"
echo "E1_STATIC4_RTL_FULL_PASS sent=20000 received=20000 lanes=4x5000 rc=$rc" | tee -a "$LOG/stage.log"
exit "$rc"

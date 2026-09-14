#!/bin/bash
# DATE V3 256-core RTL key-case GLS on the cluster (VCS, behavioral DelayElement).
# Not a 256-node DC.  CMR_NOC256_KIND=prop|fm.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NOC256_RUN_ID:?}
KIND=${CMR_NOC256_KIND:-prop}
CASE_NAME=${CMR_NOC256_CASE_NAME:?}
CASE_FILE=${CMR_NOC256_CASE_FILE:?}
GEN_DIR=${CMR_NOC256_GEN_DIR:?}
EXTRA_SIM_ARGS=${CMR_NOC256_SIM_ARGS:-}
RX_CAPTURE_NS=${CMR_NOC256_RX_CAPTURE_NS:-0.05}
STALL_TIMEOUT_NS=${CMR_NOC256_STALL_TIMEOUT_NS:-200000}
HARD_TIMEOUT_NS=${CMR_NOC256_HARD_TIMEOUT_NS:-800000}

if [[ "$KIND" == "fm" || "$KIND" == "FM256" ]]; then
  KIND=fm
  TB_DEFINE="+define+CMR_NOC256_FM"
  DUT_NAME="CMRMeshNoC.v"
else
  KIND=prop
  TB_DEFINE=""
  DUT_NAME="NoC_256nodes.v"
fi

LOG="$ROOT/logs/gls/$RUN_ID/rtl/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/rtl/$CASE_NAME"
CSV="$ROOT/results/$RUN_ID/csv/rtl_$CASE_NAME.csv"
if [[ "$EXTRA_SIM_ARGS" == *DUMP_SCOPED_VCD* ]]; then
  EXTRA_SIM_ARGS="$EXTRA_SIM_ARGS +DUMP_VCD=$LOG/shared_routers.vcd"
fi

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$GEN_DIR/$DUT_NAME"
test -s "$ROOT/sim/tb/async_noc256_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_noc256_async_keycase.sv"
test -s "$ROOT/rtl/DelayElement_sim.v"
test -s "$ROOT/rtl/Mutex2_sim.v"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

{
  echo "$ROOT/rtl/DelayElement_sim.v"
  echo "$ROOT/rtl/Mutex2_sim.v"
  echo "$ROOT/rtl/Mutex4.v"
  echo "$ROOT/rtl/MullerC2.v"
  echo "$ROOT/rtl/CMRMutexN.v"
  echo "$ROOT/rtl/CMRFlattenedTAC.v"
  echo "$ROOT/rtl/LanePhaseAdapter.v"
  find "$GEN_DIR" -maxdepth 1 -type f -name '*.v' \
    ! -name 'DelayElement*' ! -name 'Mutex2*' ! -name 'Mutex4.v' \
    ! -name 'MullerC2.v' ! -name 'CMRMutexN.v' ! -name 'CMRFlattenedTAC.v' \
    ! -name 'LanePhaseAdapter.v' | sort
  echo "$ROOT/sim/tb/async_noc256_port_adapter.sv"
  echo "$ROOT/sim/tb/tb_noc256_async_keycase.sv"
} > "$WORK/filelist.f"

sha256sum "$CASE_FILE" "$GEN_DIR/$DUT_NAME" \
  "$ROOT/rtl/DelayElement_sim.v" \
  "$ROOT/sim/tb/async_noc256_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc256_async_keycase.sv" | tee "$LOG/input_hashes.log"
echo "CMR_NOC256_RTL kind=$KIND rx_capture=$RX_CAPTURE_NS" | tee -a "$LOG/input_hashes.log"

cd "$WORK"
find "$WORK" -exec touch -c {} + 2>/dev/null || true
set +e
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps +notimingcheck +no_notifier $TB_DEFINE \
  -f filelist.f -top tb_noc256_async_keycase \
  -o simv -l "$LOG/compile.log"
vcs_rc=$?
set -e
if [[ ! -x ./simv ]]; then
  chmod +x ./simv 2>/dev/null || true
fi
if [[ ! -x ./simv ]]; then
  echo "CMR_NOC256_RTL_FAIL vcs rc=$vcs_rc simv missing under $WORK" >&2
  exit 2
fi
if [[ "$vcs_rc" -ne 0 ]]; then
  echo "CMR_NOC256_RTL_WARN vcs rc=$vcs_rc continuing because simv exists" >&2
fi

set +e
# shellcheck disable=SC2086
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
if grep -q "TB_RESULT PASS" "$LOG/run.log" 2>/dev/null; then
  echo "CMR_NOC256_RTL_PASS kind=$KIND case=$CASE_NAME"
else
  echo "CMR_NOC256_RTL_FAIL kind=$KIND case=$CASE_NAME" >&2
  exit 2
fi
exit "$rc"

#!/bin/bash
# Functional gate-level CMR NoC16 harness.  Deliberately does not load SDF:
# this validates the post-DC netlist's Boolean/protocol connectivity only.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NOC16_RUN_ID:?}
CASE_NAME=${CMR_NOC16_CASE_NAME:?}
CASE_FILE=${CMR_NOC16_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_NOC16_NETLIST_RUN_ID:?}
RX_CAPTURE_NS=${CMR_NOC16_RX_CAPTURE_NS:-5}
STALL_TIMEOUT_NS=${CMR_NOC16_STALL_TIMEOUT_NS:-20000}
HARD_TIMEOUT_NS=${CMR_NOC16_HARD_TIMEOUT_NS:-200000}
L2_X_PROBE=${CMR_NOC16_L2_X_PROBE:-0}
THIN_STALL_PROBE=${CMR_NOC16_THIN_STALL_PROBE:-0}
FUNCTIONAL_STALL_PROBE=${CMR_NOC16_FUNCTIONAL_STALL_PROBE:-0}
IPM1_ACK_PROBE=${CMR_NOC16_IPM1_ACK_PROBE:-0}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/func/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/func/$CASE_NAME"
CSV="$ROOT/results/$RUN_ID/csv/$CASE_NAME.csv"
NETLIST_RAW="$OUT/NoC_16nodes_post.v"
NETLIST="$OUT/NoC_16nodes_post_func.v"
PATCH_TOOL="$ROOT/scripts/patch_gls_netlist.py"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST_RAW"
test -s "$PATCH_TOOL"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST_RAW" "$PATCH_TOOL" "$LIB" \
  "$ROOT/sim/tb/async_noc16_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc16_async_boundary.sv" \
  "$ROOT/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv" | tee "$LOG/input_hashes.log"

PY=$(command -v python3 || command -v python || true)
if [[ -z "$PY" ]]; then
  echo "FUNC_GLS_FATAL no Python interpreter for functional netlist patch" >&2
  exit 2
fi
"$PY" "$PATCH_TOOL" "$NETLIST_RAW" "$NETLIST" --mode cmr_func | tee "$LOG/netlist_patch.log"
if ! grep -q 'q0 = ~(req0 & q1)' "$NETLIST" || ! grep -q 'assign #(1.0)' "$NETLIST"; then
  echo "FUNC_GLS_FATAL functional Mutex/Delay patch incomplete" >&2
  exit 2
fi
sha256sum "$NETLIST" >> "$LOG/input_hashes.log"

cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$ROOT/sim/tb/async_noc16_port_adapter.sv
$ROOT/sim/tb/tb_noc16_async_boundary.sv
$ROOT/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv
EOF

PROBE_TOP=""
if [[ "$L2_X_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_l2_parent_x_probe.sv"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_l2_parent_x_probe.sv" >> "$LOG/input_hashes.log"
  echo "$ROOT/sim/tb/tb_cmr_thin_l2_parent_x_probe.sv" >> "$WORK/filelist.f"
  PROBE_TOP="-top tb_cmr_thin_l2_parent_x_probe"
fi
if [[ "$THIN_STALL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv" >> "$LOG/input_hashes.log"
  echo "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv" >> "$WORK/filelist.f"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_core8_stall_probe"
fi
if [[ "$FUNCTIONAL_STALL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv"
  sha256sum "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv" >> "$LOG/input_hashes.log"
  echo "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv" >> "$WORK/filelist.f"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_functional_stall_probe"
fi
if [[ "$IPM1_ACK_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv" >> "$LOG/input_hashes.log"
  echo "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv" >> "$WORK/filelist.f"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_ipm1_ack_probe"
fi

cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +notimingcheck +no_notifier -f filelist.f \
  -top tb_cmr_noc16_async_boundary_failfast $PROBE_TOP -o simv -l "$LOG/compile.log"
set +e
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +notimingcheck +no_notifier \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"

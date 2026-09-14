#!/bin/bash
# 2x2 CMR TopMesh MAXIMUM-SDF GLS. MODE=sdf only; +notimingcheck is forbidden.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_TOPMESH2_RUN_ID:?}
CASE_NAME=${CMR_TOPMESH2_CASE_NAME:?}
CASE_FILE=${CMR_TOPMESH2_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_TOPMESH2_NETLIST_RUN_ID:-$RUN_ID}
EXTRA_SIM_ARGS=${CMR_TOPMESH2_SIM_ARGS:-}
STALL_TIMEOUT_NS=${CMR_TOPMESH2_STALL_TIMEOUT_NS:-2000000}
HARD_TIMEOUT_NS=${CMR_TOPMESH2_HARD_TIMEOUT_NS:-4000000}
RX_CAPTURE_NS=${CMR_TOPMESH2_RX_CAPTURE_NS:-0.1}
SDF_SCOPE="tb_cmr_topmesh2.noc.dut"

if [[ "$EXTRA_SIM_ARGS" == *notimingcheck* ]]; then
  echo "CMR_TOPMESH2_GLS_FAIL +notimingcheck is forbidden" >&2
  exit 2
fi

LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
CSV="$ROOT/results/$RUN_ID/csv/sdf_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST_RAW="$OUT/CMRTopMesh_post.v"
SDF="$OUT/CMRTopMesh.sdf"

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST_RAW"
test -s "$SDF"
test -s "$ROOT/sim/tb/async_topmesh2_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_cmr_topmesh2.sv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST_RAW" "$SDF" "$LIB" \
  "$ROOT/sim/tb/async_topmesh2_port_adapter.sv" \
  "$ROOT/sim/tb/tb_cmr_topmesh2.sv" | tee "$LOG/input_hashes.log"
echo "CMR_TOPMESH2_GLS mode=sdf rx_capture=$RX_CAPTURE_NS scope=$SDF_SCOPE" | tee -a "$LOG/input_hashes.log"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $SDF_SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $SDF scope=$SDF_SCOPE");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST_RAW
$ROOT/sim/tb/async_topmesh2_port_adapter.sv
$ROOT/sim/tb/tb_cmr_topmesh2.sv
$WORK/sdf_boot.sv
EOF

cd "$WORK"
find "$WORK" -exec touch -c {} + 2>/dev/null || true
set +e
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk -f filelist.f \
  -top tb_cmr_topmesh2 -top sdf_boot \
  -o simv -l "$LOG/compile.log"
vcs_rc=$?
set -e
if [[ ! -x ./simv ]]; then
  echo "CMR_TOPMESH2_GLS_FAIL vcs rc=$vcs_rc simv missing under $WORK" >&2
  exit 2
fi
if grep -E '\+notimingcheck' "$LOG/compile.log" >/dev/null 2>&1; then
  echo "CMR_TOPMESH2_GLS_FAIL compile used +notimingcheck" >&2
  exit 2
fi

set +e
# shellcheck disable=SC2086
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" \
  $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
# HARD_TIMEOUT_NS is accepted as an env for logs only; the TB uses timeout_cycles.
echo "CMR_TOPMESH2_GLS hard_timeout_env=$HARD_TIMEOUT_NS rc=$rc" >> "$LOG/input_hashes.log"
exit "$rc"

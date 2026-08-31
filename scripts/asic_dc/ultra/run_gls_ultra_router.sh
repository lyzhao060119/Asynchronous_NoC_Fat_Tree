#!/bin/bash
set -euo pipefail
MODE=${1:?func|sdf}; ROOT=${ULTRA_REMOTE_ROOT:?}; RUN_ID=${ULTRA_RUN_ID:?}
NETLIST_RUN_ID=${ULTRA_NETLIST_RUN_ID:-$RUN_ID}
# A smoke-only run may retain its own logs/work directory while reusing a
# frozen, already-signed-off DC netlist/SDF from NETLIST_RUN_ID.
OUT="$ROOT/outputs/$NETLIST_RUN_ID"; LOG="$ROOT/logs/gls/$RUN_ID/$MODE"; WORK="$ROOT/sim/work/$RUN_ID/$MODE"
EXPECTED_WORK="$ROOT/sim/work/$RUN_ID/$MODE"
if [ "$WORK" != "$EXPECTED_WORK" ] || [ -z "$RUN_ID" ]; then
  echo "Refusing to clean unexpected GLS work path: $WORK" >&2
  exit 2
fi
rm -rf -- "$WORK"
mkdir -p "$LOG" "$WORK"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}; export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
TB_KIND=${ULTRA_GLS_TB:-boundary}
case "$TB_KIND" in
  boundary)
    TB_FILE="tb_ultra_router_boundary_smoke.sv"
    TB_TOP="tb_ultra_router_boundary_smoke"
    ;;
  rtc_all_edges)
    TB_FILE="tb_ultra_router_rtc_all_edges.sv"
    TB_TOP="tb_ultra_router_rtc_all_edges"
    ;;
  *)
    echo "Unsupported ULTRA_GLS_TB=$TB_KIND" >&2
    exit 2
    ;;
esac
cp "$ROOT/sim/tb/$TB_FILE" "$WORK/"
RAW_NETLIST="$OUT/UltraRouter_post.v"
if [ "$MODE" = sdf ]; then
  # Strict SDF GLS must use DC's physical netlist unchanged.  It has no
  # dependency on the functional patch helper or a Python interpreter.
  NETLIST="$RAW_NETLIST"
  sha256sum "$NETLIST" | tee "$LOG/netlist_hashes.log"
else
  NETLIST="$OUT/UltraRouter_post_func.v"
  env -u LD_LIBRARY_PATH -u PYTHONHOME -u PYTHONPATH python3 \
    "$ROOT/scripts/patch_gls_netlist.py" --mode func "$RAW_NETLIST" "$NETLIST" | tee "$LOG/patch.log"
  sha256sum "$RAW_NETLIST" "$NETLIST" | tee "$LOG/netlist_hashes.log"
fi
if [ "$MODE" = func ]; then
  MUTEX_COUNT=$(sed -n 's/.*patched_mutex_modules=\([0-9][0-9]*\).*/\1/p' "$LOG/patch.log")
  DELAY_COUNT=$(sed -n 's/.*patched_delay_modules=\([0-9][0-9]*\).*/\1/p' "$LOG/patch.log")
  if [ -z "$MUTEX_COUNT" ] || [ "$MUTEX_COUNT" -eq 0 ] || [ -z "$DELAY_COUNT" ] || [ "$DELAY_COUNT" -eq 0 ]; then
    echo "FUNC_PATCH_FAIL mutex=$MUTEX_COUNT delay=$DELAY_COUNT" | tee -a "$LOG/patch.log"
    exit 2
  fi
fi
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$WORK/$TB_FILE
EOF
if [ "$MODE" = sdf ]; then cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin \$sdf_annotate("$OUT/UltraRouter.sdf", $TB_TOP.dut, , "sdf_annotate.log", "MAXIMUM", ,); \$display("TB_INFO SDF annotate $OUT/UltraRouter.sdf"); end endmodule
EOF
echo "$WORK/sdf_boot.sv" >> "$WORK/filelist.f"; fi
cd "$WORK"
TOPS="-top $TB_TOP"
MODE_OPTS=""
TRACE_DEFINE=""
if [ "$MODE" = sdf ]; then
  TOPS="$TOPS -top sdf_boot"
  TRACE_DEFINE="+define+ULTRA_TRACE_SDF"
else
  # Functional GLS has no SDF to break the intentional asynchronous feedback
  # loops. Give otherwise-zero-delay library gates one simulator time unit.
  MODE_OPTS="+delay_mode_unit"
fi
if [ "${ULTRA_TRACE_V2:-0}" = "1" ]; then
  TRACE_DEFINE="$TRACE_DEFINE +define+ULTRA_TRACE_V2"
fi
if [ "${ULTRA_TRACE_HEAD_TIMING:-0}" = "1" ]; then
  TRACE_DEFINE="$TRACE_DEFINE +define+ULTRA_TRACE_HEAD_TIMING"
fi
if [ "${ULTRA_TRACE_DATAPATH:-0}" = "1" ]; then
  TRACE_DEFINE="$TRACE_DEFINE +define+ULTRA_TRACE_DATAPATH"
fi
vcs -full64 -sverilog $TRACE_DEFINE -timescale=1ns/1ps +no_notifier $MODE_OPTS -f filelist.f $TOPS -o simv -l "$LOG/compile.log"
SIM_ARGS="${ULTRA_SIM_ARGS:-}"

# Compile the physical SDF design once, then vary only the diagnostic delay
# between the verified Head transfer and the Body injection.  Each execution
# has separate evidence; no internal probe participates in TB flow control.
GAPS="${ULTRA_BODY_GAPS:-0}"
if [ "$MODE" != "sdf" ]; then GAPS="0"; fi
IFS=',' read -r -a GAP_LIST <<< "$GAPS"
CASES="${ULTRA_SDF_CASES:-unicast3}"
if [ "$MODE" != "sdf" ]; then CASES="unicast3"; fi
if [ "$TB_KIND" = "rtc_all_edges" ]; then CASES="rtc_all_edges"; fi
IFS=',' read -r -a CASE_LIST <<< "$CASES"
SIM_STATUS=0
for CASE_NAME in "${CASE_LIST[@]}"; do
  if ! [[ "$CASE_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Invalid ULTRA_SDF_CASES entry: $CASE_NAME" >&2
    exit 2
  fi
  for GAP in "${GAP_LIST[@]}"; do
    if ! [[ "$GAP" =~ ^[0-9]+$ ]]; then
      echo "Invalid ULTRA_BODY_GAPS entry: $GAP" >&2
      exit 2
    fi
    GAP_LOG="$LOG/$CASE_NAME/gap$GAP"
    mkdir -p "$GAP_LOG"
    GAP_ARGS="$SIM_ARGS"
    if [ "$TB_KIND" = "boundary" ]; then GAP_ARGS="$GAP_ARGS +SMOKE_CASE=$CASE_NAME"; fi
    if [ "${ULTRA_TRACE_B_HEAD:-0}" = "1" ]; then GAP_ARGS="$GAP_ARGS +TRACE_B_HEAD"; fi
    if [ "${ULTRA_DUMP_VCD:-0}" = "1" ]; then
      GAP_ARGS="$GAP_ARGS +DUMP_VCD=$GAP_LOG/ultra_router_${MODE}.vcd"
    fi
    set +e
    ./simv $GAP_ARGS -l "$GAP_LOG/run.log" 2>&1 | tee "$GAP_LOG/stdout.log"
    RC=${PIPESTATUS[0]}
    if [ "${ULTRA_DUMP_VCD:-0}" = "1" ] && [ -f "ultra_router_${CASE_NAME}.vcd" ]; then
      mv "ultra_router_${CASE_NAME}.vcd" "$GAP_LOG/ultra_router_${MODE}.vcd"
    fi
    set -e
    if [ "$RC" -ne 0 ]; then SIM_STATUS=$RC; fi
  done
done
exit "$SIM_STATUS"

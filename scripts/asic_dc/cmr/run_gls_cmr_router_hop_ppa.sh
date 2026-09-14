#!/bin/bash
# Strict MAX-SDF R-U5 hop capture.  Consumes an existing post-DC directory.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_RUN_ID:?}
NETLIST_RUN_ID=${CMR_NETLIST_RUN_ID:?}
KIND=${CMR_HOP_KIND:?set CMR_HOP_KIND to a supported router geometry}
MODE=${CMR_HOP_MODE:-isolated}
MESH=${CMR_HOP_MESH:-0}
PATH_PROBE=${CMR_HOP_PATH_PROBE:-0}
NO_SDF=${CMR_HOP_NO_SDF:-0}
TB_NAME=${CMR_HOP_TB_NAME:-tb_cmr_router_hop_ppa.sv}
NO_VCD=${CMR_HOP_NO_VCD:-0}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/hop_ppa/$RUN_ID/gls"
WORK_BASE=${CMR_HOP_WORK_BASE:-$ROOT/sim/work/hop_ppa}
case "$WORK_BASE" in
  "$ROOT/sim/work/hop_ppa"|/tmp/cmr_hop_ppa_ghy19) ;;
  *) echo "Unsupported CMR_HOP_WORK_BASE: $WORK_BASE" >&2; exit 2 ;;
esac
WORK="$WORK_BASE/$RUN_ID"
EXPECTED_WORK="$WORK_BASE/$RUN_ID"

case "$KIND" in
  thin_l1_1to1|thin_l2_1to1|thin_l3_1to1|async_thin_1x1|async_flatmesh_1x1)
    VCS_DEFINE="+define+GEOM_C1_P1" ;;
  fat_l1_1to2|async_fat_1x2)
    VCS_DEFINE="+define+GEOM_C1_P2" ;;
  prop_temp_c1p4|async_fat_1x4)
    VCS_DEFINE="+define+GEOM_C1_P4" ;;
  fat_l2_2to2|fat_l3_2to2|async_prop_2x2|async_topmesh_2x2)
    VCS_DEFINE="+define+GEOM_C2_P2" ;;
  fat_l2_2to4|async_pfat_2x4)
    VCS_DEFINE="+define+GEOM_C2_P4" ;;
  fat_l3_4to8|async_pfat_4x8)
    VCS_DEFINE="+define+GEOM_C4_P8" ;;
  *) echo "Unsupported CMR_HOP_KIND: $KIND" >&2; exit 2 ;;
esac
case "$KIND" in
  async_flatmesh_1x1|async_topmesh_2x2) MESH=1 ;;
esac
if [ "$WORK" != "$EXPECTED_WORK" ] || [ -z "$RUN_ID" ]; then
  echo "Refusing to clean unexpected work path: $WORK" >&2
  exit 2
fi
test -s "$OUT/CMRRouter_post.v"
test -s "$OUT/CMRRouter.sdf"
test -s "$OUT/CMRRouter.ddc"
mkdir -p "$WORK_BASE"
rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
case "$TB_NAME" in
  tb_cmr_router_hop_ppa.sv|tb_cmr_router_c1p4_sustained.sv|tb_cmr_router_multi_lane_agg.sv) ;;
  *) echo "Unsupported CMR_HOP_TB_NAME: $TB_NAME" >&2; exit 2 ;;
esac
TB="$ROOT/sim/tb/$TB_NAME"
if [ "$TB_NAME" = "tb_cmr_router_c1p4_sustained.sv" ]; then
  test "$KIND" = "async_fat_1x4" || test "$KIND" = "prop_temp_c1p4"
  RX_DEFAULT=0.001
elif [ "$TB_NAME" = "tb_cmr_router_multi_lane_agg.sv" ]; then
  case "$KIND" in
    async_thin_1x1|async_fat_1x2|async_fat_1x4|prop_temp_c1p4|thin_l1_1to1|fat_l1_1to2) ;;
    *) echo "Unsupported multi-lane agg KIND: $KIND" >&2; exit 2 ;;
  esac
  RX_DEFAULT=0.09
else
  RX_DEFAULT=0.09
fi
BIND="$ROOT/sim/tb/hop_binds"
test -s "$TB"
test -d "$BIND"

cp "$TB" "$WORK/tb_cmr_router_hop_ppa.sv"
cp "$BIND"/*.vi "$WORK/"
PROBE="$ROOT/sim/tb/tb_cmr_pfat48_path_probe.sv"
PROBE_TOPS=""
if [ "$PATH_PROBE" = "1" ]; then
  test -s "$PROBE"
  cp "$PROBE" "$WORK/"
  PROBE_TOPS="-top tb_cmr_pfat48_path_probe"
fi
sha256sum "$OUT/CMRRouter.ddc" "$OUT/CMRRouter_post.v" "$OUT/CMRRouter.sdf" \
  "$WORK/tb_cmr_router_hop_ppa.sv" | tee "$LOG/input_hashes.sha256"
if [ "$NO_SDF" = "1" ]; then
  cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial \$display("PPA_INFO NO_SDF mode=$MODE mesh=$MESH");
endmodule
EOF
else
  cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$OUT/CMRRouter.sdf", tb_cmr_router_hop_ppa.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("PPA_INFO SDF_MAX $OUT/CMRRouter.sdf mode=$MODE mesh=$MESH");
  end
endmodule
EOF
fi
{
  echo "$LIB"
  echo "$OUT/CMRRouter_post.v"
  echo "$WORK/tb_cmr_router_hop_ppa.sv"
  if [ "$PATH_PROBE" = "1" ]; then
    echo "$WORK/tb_cmr_pfat48_path_probe.sv"
  fi
  echo "$WORK/sdf_boot.sv"
} > "$WORK/filelist.f"

cd "$WORK"
VCS_EXTRA=""
if [ "$PATH_PROBE" = "1" ]; then
  VCS_EXTRA="-debug_access+r"
fi
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier +incdir+$WORK \
  $VCS_DEFINE $VCS_EXTRA -f filelist.f -top tb_cmr_router_hop_ppa $PROBE_TOPS -top sdf_boot \
  -o simv -l "$LOG/compile.log"
SIMV_PLUS=""
if [ "$PATH_PROBE" = "1" ] || [ "$NO_VCD" = "1" ]; then
  SIMV_PLUS="+NO_FULL_VCD"
fi
if [ "$NO_SDF" = "1" ]; then
  # Zero-delay gates hang in mutex/C-element loops.  Unit delay lets time
  # advance so the same TB timeout can finish.
  SIMV_PLUS="$SIMV_PLUS +delay_mode_unit"
fi
set +e
./simv +RX_CAPTURE_NS="${CMR_RX_CAPTURE_NS:-$RX_DEFAULT}" +TX_SETUP_NS="${CMR_TX_SETUP_NS:-0.05}" \
  +ACK_TO_NEXT_REQ_GUARD_NS="${CMR_ACK_TO_NEXT_REQ_GUARD_NS:-0.20}" \
  +HOP_KIND="$KIND" +HOP_MODE="$MODE" +MESH="$MESH" \
  +NUM_PACKETS="${CMR_HOP_NUM_PACKETS:-1}" \
  +EVENT_CSV="$LOG/hop_events.csv" \
  +VCD="$LOG/hop_ppa.vcd" $SIMV_PLUS -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
SIM_STATUS=${PIPESTATUS[0]}
set -e
cp "$WORK/sdf_annotate.log" "$LOG/" 2>/dev/null || true

if [ "$PATH_PROBE" = "1" ]; then
  grep -E "PFAT48_STUCK|PFAT48_PROBE" "$LOG/run.log" || true
  echo "PPA_PROBE_DONE"
  exit 0
fi
if grep -Eqi 'Timing violation|PPA_FAIL|PPA_RESULT FAIL|SDF.*error|Total errors:[[:space:]]*[1-9]' "$LOG/run.log" "$LOG/sdf_annotate.log" 2>/dev/null; then
  echo "PPA_GLS_FAIL protocol, timing, or SDF annotation error" >&2
  exit 3
fi
grep -q 'PPA_RESULT PASS' "$LOG/run.log"
if [ "$TB_NAME" = "tb_cmr_router_c1p4_sustained.sv" ]; then
  grep -q 'SUSTAINED_RESULT PASS packets=10000 sent=50000 received=50000' "$LOG/run.log"
  grep -Eq 'Total errors:[[:space:]]*0([[:space:]]|$)' "$LOG/sdf_annotate.log"
fi
if [ "$TB_NAME" = "tb_cmr_router_multi_lane_agg.sv" ]; then
  grep -q 'AGG_RESULT PASS' "$LOG/run.log"
  grep -Eq 'Total errors:[[:space:]]*0([[:space:]]|$)' "$LOG/sdf_annotate.log"
fi
test -s "$LOG/hop_events.csv"
if [ "$NO_VCD" != "1" ]; then
  test -s "$LOG/hop_ppa.vcd"
fi
exit "$SIM_STATUS"

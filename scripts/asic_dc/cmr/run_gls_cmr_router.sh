#!/bin/bash
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_RUN_ID:?}
NETLIST_RUN_ID=${CMR_NETLIST_RUN_ID:-$RUN_ID}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/sdf"
WORK="$ROOT/sim/work/$RUN_ID/sdf"
EXPECTED_WORK="$ROOT/sim/work/$RUN_ID/sdf"
if [ "$WORK" != "$EXPECTED_WORK" ] || [ -z "$RUN_ID" ]; then
  echo "Refusing to clean unexpected GLS work path: $WORK" >&2
  exit 2
fi
rm -rf -- "$WORK"
mkdir -p "$LOG" "$WORK"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/CMRRouter_post.v"
SDF="$OUT/CMRRouter.sdf"
TB_FILE=${CMR_TB_FILE:-tb_cmr_router_boundary_smoke.sv}
TB_TOP=${CMR_TB_TOP:-tb_cmr_router_boundary_smoke}

test -s "$NETLIST"
test -s "$SDF"
cp "$ROOT/sim/tb/$TB_FILE" "$WORK/"
sha256sum "$NETLIST" "$SDF" "$WORK/$TB_FILE" | tee "$LOG/input_hashes.log"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $TB_TOP.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $SDF");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$WORK/$TB_FILE
$WORK/sdf_boot.sv
EOF

cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier -f filelist.f \
  -top "$TB_TOP" -top sdf_boot -o simv -l "$LOG/compile.log"

CASES=${CMR_SDF_CASES:-unicast3,mc_single3,mc_disjoint_parallel3,uc_overlap_release3,mc_overlap_tailjoin3,b_alone_head,a_then_b_head_parallel}
IFS=',' read -r -a CASE_LIST <<< "$CASES"
SIM_STATUS=0
for CASE_NAME in "${CASE_LIST[@]}"; do
  if ! [[ "$CASE_NAME" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Invalid CMR_SDF_CASES entry: $CASE_NAME" >&2
    exit 2
  fi
  CASE_LOG="$LOG/$CASE_NAME"
  mkdir -p "$CASE_LOG"
  set +e
  ./simv +SMOKE_CASE="$CASE_NAME" -l "$CASE_LOG/run.log" 2>&1 | tee "$CASE_LOG/stdout.log"
  RC=${PIPESTATUS[0]}
  set -e
  if [ "$RC" -ne 0 ]; then SIM_STATUS=$RC; fi
done
if [ -f "$WORK/sdf_annotate.log" ]; then
  cp "$WORK/sdf_annotate.log" "$LOG/sdf_annotate.log"
fi
exit "$SIM_STATUS"

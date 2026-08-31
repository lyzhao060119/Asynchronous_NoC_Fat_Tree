#!/bin/bash
# Post-synth GLS smoke: func (Mutex+Delay behavioral, no SDF) or sdf (gate-level + SDF).
# Usage: run_gls_smoke.sh <rtl|func|sdf> <routerl1|noc16|wormhole_minimal> [CASE_PATH]
set -uo pipefail

MODE="${1:-func}"
DESIGN="${2:-routerl1}"
CASE_ARG="${3:-}"
PROJECT_DIR="${PROJECT_DIR:-/home/ghy19/Asynchronous_Router}"
ENV_FILE="$PROJECT_DIR/sim_gls/env.local"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

LIB_V="${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}"
OUT_DIR="$PROJECT_DIR/outputs"
GLS_DIR="$PROJECT_DIR/sim_gls"
LOG_DIR="$PROJECT_DIR/logs"
SIM_BASE="${HOME}/simulation/async_gls_smoke"
mkdir -p "$SIM_BASE" "$LOG_DIR" "$GLS_DIR/summary" "$GLS_DIR/cases"

export VCS_HOME="${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}"
export PATH="$VCS_HOME/bin:${PATH:-}"
ulimit -s unlimited || true

set +e
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null
set -e

if [[ "$MODE" != "rtl" && "$MODE" != "func" && "$MODE" != "sdf" ]]; then
  echo "usage: $0 <rtl|func|sdf> <routerl1|noc16|wormhole_minimal> [CASE_PATH]" >&2
  exit 2
fi

case "$DESIGN" in
  routerl1)
    POST_SRC="$OUT_DIR/RouterL1_post.v"
    POST_FUNC="$OUT_DIR/RouterL1_post_func.v"
    POST_SDF="$OUT_DIR/RouterL1_post_sdf.v"
    SDF_FILE="$OUT_DIR/RouterL1_dc.sdf"
    TB="$GLS_DIR/tb_gls_routerl1_func.sv"
    TOP=tb_gls_routerl1_func
    DEFAULT_CASE="$GLS_DIR/cases/smoke_directed.case"
    if [[ "$MODE" == "sdf" ]]; then
      DEFAULT_CASE="$GLS_DIR/cases/smoke_directed_sdf.case"
    fi
    CSV="$GLS_DIR/summary/routerl1_${MODE}.csv"
    WORK="$SIM_BASE/work_routerl1_${MODE}"
    ;;
  noc16)
    POST_SRC="$OUT_DIR/NoC_16nodes_post.v"
    POST_FUNC="$OUT_DIR/NoC_16nodes_post_func.v"
    POST_SDF="$OUT_DIR/NoC_16nodes_post_sdf.v"
    SDF_FILE="$OUT_DIR/NoC_16nodes_dc.sdf"
    NOC16_HARNESS="${GLS_NOC16_HARNESS:-axi}"
    case "$NOC16_HARNESS" in
      axi)
        TB="$GLS_DIR/tb_noc16_async_axi_bram.sv"
        NOC16_WRAPPER="$GLS_DIR/async_noc16_axi_bram_wrapper.sv"
        TOP=tb_noc16_async_axi_bram
        SDF_DUT_PATH="${TOP}.dut.dut"
        ;;
      direct)
        TB="$GLS_DIR/tb_gls_noc16_func.sv"
        NOC16_WRAPPER="$GLS_DIR/async_hs_port.sv"
        TOP=tb_gls_noc16_func
        SDF_DUT_PATH="${TOP}.dut"
        ;;
      *)
        echo "ERROR: GLS_NOC16_HARNESS must be axi or direct" >&2
        exit 2
        ;;
    esac
    DEFAULT_CASE="$GLS_DIR/cases/noc16_00_to_33_3flit_smoke.case"
    if [[ "$MODE" == "sdf" ]]; then
      DEFAULT_CASE="$GLS_DIR/cases/noc16_00_to_33_3flit_sdf.case"
    fi
    CSV="$GLS_DIR/summary/noc16_${MODE}.csv"
    WORK="$SIM_BASE/work_noc16_${MODE}"
    if [[ "$MODE" == "rtl" ]]; then
      POST_SRC="$PROJECT_DIR/rtl/NoC_16nodes.v"
    fi
    ;;
  wormhole_minimal)
    POST_SRC="$OUT_DIR/RouterL1WormholeMinimal_post.v"
    POST_FUNC="$OUT_DIR/RouterL1WormholeMinimal_post_func.v"
    POST_SDF="$OUT_DIR/RouterL1WormholeMinimal_post_sdf.v"
    SDF_FILE="$OUT_DIR/RouterL1WormholeMinimal_dc.sdf"
    TB="$GLS_DIR/tb_gls_router_wormhole_minimal.sv"
    TOP=tb_gls_router_wormhole_minimal
    DEFAULT_CASE="$GLS_DIR/cases/smoke_directed.case"
    CSV="$GLS_DIR/summary/wormhole_minimal_${MODE}.csv"
    WORK="$SIM_BASE/work_wormhole_minimal_${MODE}"
    ;;
  *)
    echo "usage: $0 <func|sdf> <routerl1|noc16|wormhole_minimal> [CASE_PATH]" >&2
    exit 2
    ;;
esac

CASE_FILE="${CASE_ARG:-$DEFAULT_CASE}"
if [[ "$DESIGN" == "noc16" && -n "${GLS_NOC16_CASE:-}" ]]; then
  CASE_FILE="$GLS_NOC16_CASE"
fi
if [[ -n "${GLS_CSV:-}" ]]; then
  CSV="$GLS_CSV"
fi
if [[ "$DESIGN" == "noc16" && -n "${GLS_NOC16_CSV:-}" ]]; then
  CSV="$GLS_NOC16_CSV"
fi
PATCH_PY="$GLS_DIR/patch_gls_netlist.py"
LOG_TAG="${GLS_LOG_TAG:-${DESIGN}_${MODE}}"
LOG_TAG="${LOG_TAG//[^A-Za-z0-9_.-]/_}"
WORK="${WORK}_${LOG_TAG}"

for f in "$POST_SRC" "$TB" "$LIB_V" "$CASE_FILE" "$PATCH_PY"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    exit 1
  fi
done
if [[ "$DESIGN" == "noc16" && ! -f "$NOC16_WRAPPER" ]]; then
  echo "ERROR: missing NoC16 harness source $NOC16_WRAPPER" >&2
  exit 1
fi
if [[ "$MODE" == "sdf" && ! -f "$SDF_FILE" ]]; then
  echo "ERROR: missing SDF $SDF_FILE" >&2
  exit 1
fi

which vcs || { echo "ERROR: vcs not in PATH"; exit 1; }
echo "INFO: vcs=$(which vcs)"
echo "INFO: MODE=$MODE DESIGN=$DESIGN CASE=$CASE_FILE"
if [[ "$DESIGN" == "noc16" ]]; then
  echo "INFO: NOC16 harness=$NOC16_HARNESS top=$TOP"
fi
echo "INFO: +notimingcheck +no_notifier (no +nospecify); SDF also uses +pulse_e/0 +pulse_r/0"

PULSE_ARGS=()
TIMEOUT_SCALE=5
if [[ "$MODE" == "sdf" ]]; then
  PULSE_ARGS=(+pulse_e/0 +pulse_r/0)
  TIMEOUT_SCALE=10
fi
if [[ -n "${GLS_TIMEOUT_SCALE:-}" ]]; then
  TIMEOUT_SCALE="$GLS_TIMEOUT_SCALE"
fi
if [[ "$DESIGN" == "noc16" && -n "${GLS_NOC16_TIMEOUT_SCALE:-}" ]]; then
  TIMEOUT_SCALE="$GLS_NOC16_TIMEOUT_SCALE"
fi

VCS_RT_ARGS=(+notimingcheck +no_notifier)
if [[ "$MODE" == "sdf" ]]; then
  VCS_RT_ARGS+=(+pulse_e/0 +pulse_r/0)
fi
VCS_COMPILE_ARGS=()
SIM_PLUSARGS=()
if [[ "${GLS_PROBE:-0}" == "1" && "$DESIGN" == "routerl1" ]]; then
  VCS_COMPILE_ARGS+=(+define+GLS_GATE_PROBE)
  SIM_PLUSARGS+=(+GLS_PROBE=1)
  echo "INFO: GLS_PROBE enabled for RouterL1 gate-level internal tracing"
fi
if [[ "${GLS_DUMP_VCD:-0}" == "1" && "$DESIGN" == "noc16" ]]; then
  DUMP_VCD_PATH="${GLS_DUMP_VCD_PATH:-$LOG_DIR/noc16_${MODE}_smoke.vcd}"
  rm -f "$DUMP_VCD_PATH"
  SIM_PLUSARGS+=(+DUMP_VCD="$DUMP_VCD_PATH")
  echo "INFO: GLS_DUMP_VCD enabled for NoC16 -> $DUMP_VCD_PATH"
fi
if [[ "${GLS_E2E_PROBE:-0}" == "1" && "$DESIGN" == "noc16" ]]; then
  if [[ "${GLS_ROUTE_PROBE:-0}" == "1" ]]; then
    VCS_COMPILE_ARGS+=(+define+NOC16_ROUTE_PROBE)
    echo "INFO: GLS_ROUTE_PROBE enabled for NoC16 inter-router segment tracing"
  fi
  SIM_PLUSARGS+=(+E2E_EDGE_PROBE=1)
  SIM_PLUSARGS+=(+E2E_SRC_PORT="${GLS_E2E_SRC_PORT:-0}")
  SIM_PLUSARGS+=(+E2E_DST_PORT="${GLS_E2E_DST_PORT:-15}")
  echo "INFO: GLS_E2E_PROBE enabled for NoC16 src=${GLS_E2E_SRC_PORT:-0} dst=${GLS_E2E_DST_PORT:-15}"
fi
if [[ "${GLS_STALL_PROBE:-0}" == "1" && "$DESIGN" == "noc16" ]]; then
  VCS_COMPILE_ARGS+=(+define+NOC16_STAGE1_STALL_PROBE)
  SIM_PLUSARGS+=(+STALL_PROBE=1)
  SIM_PLUSARGS+=(+STALL_WINDOW_CYCLES="${GLS_STALL_WINDOW_CYCLES:-10000}")
  SIM_PLUSARGS+=(+STALL_WINDOW_COUNT="${GLS_STALL_WINDOW_COUNT:-3}")
  echo "INFO: GLS_STALL_PROBE enabled for NoC16 window=${GLS_STALL_WINDOW_CYCLES:-10000} count=${GLS_STALL_WINDOW_COUNT:-3}"
fi
if [[ "$DESIGN" == "noc16" && -n "${GLS_NOC16_PLUSARGS:-}" ]]; then
  for plusarg in $GLS_NOC16_PLUSARGS; do
    SIM_PLUSARGS+=("+$plusarg")
  done
fi
if [[ "${GLS_E2E_PROBE:-0}" == "1" && "$DESIGN" == "routerl1" ]]; then
  SIM_PLUSARGS+=(+E2E_EDGE_PROBE=1)
  SIM_PLUSARGS+=(+E2E_SRC_PORT="${GLS_E2E_SRC_PORT:-0}")
  SIM_PLUSARGS+=(+E2E_DST_PORT="${GLS_E2E_DST_PORT:-4}")
  echo "INFO: GLS_E2E_PROBE enabled for RouterL1 src=${GLS_E2E_SRC_PORT:-0} dst=${GLS_E2E_DST_PORT:-4}"
fi

PY=/usr/bin/python3
if [[ ! -x "$PY" ]]; then
  PY=$(command -v python3 || command -v python || true)
fi
if [[ -z "$PY" ]]; then
  echo "ERROR: no python available to patch netlist" >&2
  exit 1
fi

if [[ "$MODE" == "rtl" ]]; then
  POST="$POST_SRC"
elif [[ "$MODE" == "func" ]]; then
  POST="$POST_FUNC"
  NEED_PATCH=1
  SRC_DELAY_MODULES=$(grep -cE '^module[[:space:]]+DelayElement_DelayValue' "$POST_SRC" || true)
  SRC_MUTEX_MODULES=$(grep -cE '^module[[:space:]]+Mutex2' "$POST_SRC" || true)
  if [[ -f "$POST" ]]; then
    POST_FUNC_DELAY_ASSIGNS=$(grep -c 'assign #(1.0)' "$POST" || true)
    POST_FUNC_MUTEX_ASSIGNS=$(grep -c 'assign #(0.1)' "$POST" || true)
  else
    POST_FUNC_DELAY_ASSIGNS=0
    POST_FUNC_MUTEX_ASSIGNS=0
  fi
  if [[ -f "$POST" ]] \
      && { [[ "$SRC_DELAY_MODULES" -eq 0 ]] || [[ "$POST_FUNC_DELAY_ASSIGNS" -ge "$SRC_DELAY_MODULES" ]]; } \
      && { [[ "$SRC_MUTEX_MODULES" -eq 0 ]] || [[ "$POST_FUNC_MUTEX_ASSIGNS" -ge "$SRC_MUTEX_MODULES" ]]; }; then
    echo "INFO: reusing $POST"
    NEED_PATCH=0
  fi
  if [[ "$NEED_PATCH" -eq 1 ]]; then
    echo "INFO: patching --mode func -> $POST"
    "$PY" "$PATCH_PY" --mode func "$POST_SRC" "$POST"
  fi
  POST_FUNC_DELAY_ASSIGNS=$(grep -c 'assign #(1.0)' "$POST" || true)
  POST_FUNC_MUTEX_ASSIGNS=$(grep -c 'assign #(0.1)' "$POST" || true)
  if { [[ "$SRC_DELAY_MODULES" -gt 0 ]] && [[ "$POST_FUNC_DELAY_ASSIGNS" -lt "$SRC_DELAY_MODULES" ]]; } \
      || { [[ "$SRC_MUTEX_MODULES" -gt 0 ]] && [[ "$POST_FUNC_MUTEX_ASSIGNS" -lt "$SRC_MUTEX_MODULES" ]]; }; then
    echo "ERROR: func patch incomplete in $POST" >&2
    echo "INFO: source Delay modules=$SRC_DELAY_MODULES func delay assigns=$POST_FUNC_DELAY_ASSIGNS" >&2
    echo "INFO: source Mutex modules=$SRC_MUTEX_MODULES func mutex assigns=$POST_FUNC_MUTEX_ASSIGNS" >&2
    exit 1
  fi
  echo "INFO: func patch counts source_delay=$SRC_DELAY_MODULES func_delay_assigns=$POST_FUNC_DELAY_ASSIGNS source_mutex=$SRC_MUTEX_MODULES func_mutex_assigns=$POST_FUNC_MUTEX_ASSIGNS"
else
  POST="$POST_SDF"
  NEED_PATCH=1
  SRC_DELAY_MODULES=$(grep -cE '^module[[:space:]]+DelayElement_DelayValue' "$POST_SRC" || true)
  SRC_MUTEX_MODULES=$(grep -cE '^module[[:space:]]+Mutex2' "$POST_SRC" || true)
  # sdf: full gate-level — keep Mutex ND2/INV + DEL* (no behavioral # delays)
  if [[ -f "$POST" ]] \
      && { [[ "$SRC_DELAY_MODULES" -eq 0 ]] || grep -qE 'DEL[0-9]+D1' "$POST"; } \
      && { [[ "$SRC_MUTEX_MODULES" -eq 0 ]] || grep -q 'ND2D1' "$POST"; } \
      && ! grep -q 'assign #(0.1)' "$POST" && ! grep -q 'assign #(1.0)' "$POST"; then
    echo "INFO: reusing gate-level $POST (no sim Mutex/Delay patch)"
    NEED_PATCH=0
  fi
  if [[ "$NEED_PATCH" -eq 1 ]]; then
    echo "INFO: writing --mode sdf (identity; keep Mutex+DEL*) -> $POST"
    "$PY" "$PATCH_PY" --mode sdf "$POST_SRC" "$POST"
  fi
  if grep -q 'assign #(0.1)' "$POST" || grep -q 'assign #(1.0)' "$POST"; then
    echo "ERROR: sdf netlist must NOT use behavioral Mutex/Delay assigns" >&2
    exit 1
  fi
  if { [[ "$SRC_DELAY_MODULES" -gt 0 ]] && ! grep -qE 'DEL[0-9]+D1' "$POST"; } \
      || { [[ "$SRC_MUTEX_MODULES" -gt 0 ]] && ! grep -q 'ND2D1' "$POST"; }; then
    echo "ERROR: sdf netlist missing DEL* or required Mutex ND2 cells in $POST" >&2
    echo "INFO: source Delay modules=$SRC_DELAY_MODULES source Mutex modules=$SRC_MUTEX_MODULES" >&2
    exit 1
  fi
  echo -n "INFO: DEL* count in post_sdf="; grep -cE 'DEL[0-9]+D1BWP' "$POST" || true
  echo -n "INFO: Mutex ND2 count in post_sdf="; grep -c 'ND2D1BWP12T30P140' "$POST" || true
fi

echo -n "INFO: mutex assigns="; grep -c 'assign #(0.1)' "$POST" || true
echo -n "INFO: delay #(1.0) assigns="; grep -c 'assign #(1.0)' "$POST" || true

mkdir -p "$WORK"
cd "$WORK"
rm -rf csrc simv* *.daidir
cp -f "$TB" .
if [[ "$DESIGN" == "noc16" ]]; then
  cp -f "$NOC16_WRAPPER" .
fi

cat > filelist_local.f <<EOF
$LIB_V
$POST
EOF
if [[ "$DESIGN" == "noc16" ]]; then
  echo "$WORK/$(basename "$NOC16_WRAPPER")" >> filelist_local.f
  if [[ "$MODE" == "rtl" ]]; then
    RTL_MUTEX_MODEL="${GLS_RTL_MUTEX_MODEL:-sim}"
    case "$RTL_MUTEX_MODEL" in
      sim)        RTL_MUTEX_SOURCE="Mutex2_sim.v" ;;
      structural) RTL_MUTEX_SOURCE="Mutex2.v" ;;
      *)
        echo "ERROR: GLS_RTL_MUTEX_MODEL must be sim or structural" >&2
        exit 2
        ;;
    esac
    echo "INFO: RTL mutex model=$RTL_MUTEX_MODEL source=$RTL_MUTEX_SOURCE"
    for primitive in DelayElement_sim.v "$RTL_MUTEX_SOURCE" MullerC2.v MullerC3.v TAC2.v Mutex3Grant.v Mutex5Anchor.v DLatchBank.v MousetrapStage.v; do
      echo "$PROJECT_DIR/rtl/$primitive" >> filelist_local.f
    done
  fi
fi
echo "$WORK/$(basename "$TB")" >> filelist_local.f

SIMV="simv_${DESIGN}_${MODE}"
VCS_TOP_ARGS=(-top "$TOP")
if [[ "$MODE" == "sdf" ]]; then
  cat > sdf_boot.sv <<EOF
\`timescale 1ns/1ps
module sdf_boot;
  initial begin
    \$sdf_annotate("${SDF_FILE}", ${SDF_DUT_PATH:-${TOP}.dut}, , "sdf_${DESIGN}_smoke.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate ${SDF_FILE} -> ${SDF_DUT_PATH:-${TOP}.dut}");
  end
endmodule
EOF
  echo "$WORK/sdf_boot.sv" >> filelist_local.f
  VCS_TOP_ARGS+=(-top sdf_boot)
fi

# Clear stale compile log so pollers don't see old IFNSDFA
: > "$LOG_DIR/gls_${LOG_TAG}_compile.log"
$VCS_HOME/bin/vcs +v2k -timescale=1ns/1ps -sverilog -full64 \
  "${VCS_RT_ARGS[@]}" \
  ${VCS_COMPILE_ARGS[@]+"${VCS_COMPILE_ARGS[@]}"} \
  -f filelist_local.f "${VCS_TOP_ARGS[@]}" \
  -o "$SIMV" \
  -l "$LOG_DIR/gls_${LOG_TAG}_compile.log"

test -x "./$SIMV"

./"$SIMV" \
  "${VCS_RT_ARGS[@]}" \
  ${SIM_PLUSARGS[@]+"${SIM_PLUSARGS[@]}"} \
  +CASE="$CASE_FILE" \
  +CSV="$CSV" \
  +TIMEOUT_SCALE="$TIMEOUT_SCALE" \
  -l "$LOG_DIR/gls_${LOG_TAG}_run.log"

echo "=== extract ==="
grep -E 'TB_RESULT|TB_TIMEOUT|TB_FATAL|TB_INFO|TB_PROGRESS|TB_STALL|DBG_|E2E_NS=|T_router=|T_noc=|E2E_EDGE|E2E_WRAPPED|E2E_WRAPPER|E2E_PROBE|E2E_SEG|setuphold|SDF' \
  "$LOG_DIR/gls_${LOG_TAG}_run.log" || true
if [[ "$DESIGN" == "wormhole_minimal" ]]; then
  echo "=== wormhole metrics extract ==="
  grep -E 'TB_RESULT|TB_OUT|SDF_METRIC|setuphold|SDF' \
    "$LOG_DIR/gls_${LOG_TAG}_run.log" | tail -240 || true
fi
if [[ "${GLS_PROBE:-0}" == "1" && "$DESIGN" == "routerl1" ]]; then
  echo "=== probe extract ==="
  grep -E 'GLS_PROBE|GLS_PW|TB_INJECT|TB_MATCH|TB_TIMEOUT|TB_RESULT|E2E_EDGE' \
    "$LOG_DIR/gls_${LOG_TAG}_run.log" | tail -200 || true
fi

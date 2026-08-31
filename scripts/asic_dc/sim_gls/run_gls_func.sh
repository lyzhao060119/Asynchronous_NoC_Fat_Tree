#!/bin/bash
# No-SDF gate-level functional VCS (ANPV-style +notimingcheck).
# Usage: run_gls_func.sh routerl1|noc16 [CASE_PATH]
set -uo pipefail

DESIGN="${1:-routerl1}"
CASE_ARG="${2:-}"
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
SIM_BASE="${HOME}/simulation/async_gls_func"
mkdir -p "$SIM_BASE" "$LOG_DIR" "$GLS_DIR/summary" "$GLS_DIR/cases"

export VCS_HOME="${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}"
export PATH="$VCS_HOME/bin:${PATH:-}"
ulimit -s unlimited || true

set +e
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null
set -e

case "$DESIGN" in
  routerl1)
    POST_SRC="$OUT_DIR/RouterL1_post.v"
    POST_FUNC="$OUT_DIR/RouterL1_post_func.v"
    TB="$GLS_DIR/tb_gls_routerl1_func.sv"
    FL="$GLS_DIR/filelist_routerl1_func.f"
    TOP=tb_gls_routerl1_func
    DEFAULT_CASE="$GLS_DIR/cases/smoke_directed.case"
    CSV="$GLS_DIR/summary/routerl1_func.csv"
    WORK="$SIM_BASE/work_routerl1_func"
    ;;
  noc16)
    POST_SRC="$OUT_DIR/NoC_16nodes_post.v"
    POST_FUNC="$OUT_DIR/NoC_16nodes_post_func.v"
    TB="$GLS_DIR/tb_gls_noc16_func.sv"
    FL="$GLS_DIR/filelist_noc16_func.f"
    TOP=tb_gls_noc16_func
    DEFAULT_CASE="$GLS_DIR/cases/noc16_00_to_33_3flit_smoke.case"
    CSV="$GLS_DIR/summary/noc16_func.csv"
    WORK="$SIM_BASE/work_noc16_func"
    ;;
  *)
    echo "usage: $0 routerl1|noc16 [CASE_PATH]" >&2
    exit 2
    ;;
esac

CASE_FILE="${CASE_ARG:-$DEFAULT_CASE}"

for f in "$POST_SRC" "$TB" "$FL" "$LIB_V" "$CASE_FILE"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing $f" >&2
    exit 1
  fi
done

which vcs || { echo "ERROR: vcs not in PATH"; exit 1; }
echo "INFO: vcs=$(which vcs)"
echo "INFO: DESIGN=$DESIGN POST_SRC=$POST_SRC CASE=$CASE_FILE"
echo "INFO: no SDF annotate; +notimingcheck; Mutex behavioral patch for GLS func"

# Sim-only netlist: replace uniquified Mutex2_* ND2 loops with delayed assigns.
# Prefer a pre-patched netlist (login node) so compute nodes without python3 still work.
POST="$POST_FUNC"
NEED_PATCH=1
if [[ -f "$POST_FUNC" ]] && grep -q 'assign #(0.1)' "$POST_FUNC" && grep -q 'assign #(1.0)' "$POST_FUNC"; then
  echo "INFO: reusing existing Mutex+Delay patched netlist $POST_FUNC"
  NEED_PATCH=0
fi
if [[ "$NEED_PATCH" -eq 1 ]]; then
  PY=/usr/bin/python3
  if [[ ! -x "$PY" ]]; then
    PY=$(command -v python3 || command -v python || true)
  fi
  echo "INFO: patching Mutex+Delay with $PY -> $POST_FUNC"
  if [[ -z "$PY" ]]; then
    echo "ERROR: no python available to patch Mutex" >&2
    exit 1
  fi
  set +e
  "$PY" "$GLS_DIR/patch_gls_netlist.py" --mode func "$POST_SRC" "$POST_FUNC"
  patch_status=$?
  set -e
  if [[ "$patch_status" -ne 0 || ! -f "$POST_FUNC" ]]; then
    echo "ERROR: Mutex patch failed status=$patch_status" >&2
    exit 1
  fi
fi
echo -n "INFO: behavioral mutex assigns="; grep -c 'assign #(0.1)' "$POST" || true
echo -n "INFO: behavioral delay assigns="; grep -c 'assign #(1.0)' "$POST" || true
if ! grep -q 'assign #(0.1)' "$POST"; then
  echo "ERROR: post_func has no behavioral Mutex assigns" >&2
  exit 1
fi
if ! grep -q 'assign #(1.0)' "$POST"; then
  echo "ERROR: post_func has no behavioral DelayElement assigns" >&2
  exit 1
fi
POST="$POST_FUNC"

mkdir -p "$WORK"
cd "$WORK"
rm -rf csrc simv* *.daidir

# Absolute paths in filelist; also copy TB helpers for relative entries
cp -f "$FL" .
cp -f "$TB" .
if [[ "$DESIGN" == "noc16" ]]; then
  cp -f "$GLS_DIR/async_hs_port.sv" .
fi

# Rewrite filelist to use absolute TB paths under WORK where needed
cat > filelist_local.f <<EOF
$LIB_V
$POST
EOF
if [[ "$DESIGN" == "noc16" ]]; then
  echo "$WORK/async_hs_port.sv" >> filelist_local.f
fi
echo "$WORK/$(basename "$TB")" >> filelist_local.f

$VCS_HOME/bin/vcs +v2k -timescale=1ns/1ps -sverilog -full64 \
  +notimingcheck +no_notifier \
  -f filelist_local.f -top "$TOP" \
  -o "simv_${DESIGN}_func" \
  -l "$LOG_DIR/gls_${DESIGN}_func_compile.log"

test -x "./simv_${DESIGN}_func"

./simv_${DESIGN}_func \
  +notimingcheck +no_notifier \
  +CASE="$CASE_FILE" \
  +CSV="$CSV" \
  +TIMEOUT_SCALE=5 \
  -l "$LOG_DIR/gls_${DESIGN}_func_run.log"

echo "=== TB_RESULT extract ==="
grep -E 'TB_RESULT|TB_TIMEOUT|TB_FATAL|TB_INFO' \
  "$LOG_DIR/gls_${DESIGN}_func_run.log" || true

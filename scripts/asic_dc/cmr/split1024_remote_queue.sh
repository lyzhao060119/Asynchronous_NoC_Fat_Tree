#!/bin/bash
# Login-side scheduler only: every DC computation runs through LSF.
set -eo pipefail
R=/home/ghy19/Asynchronous_Router_CMR/campaigns/20261020_split1024_tt_r1
KINDS=${CMR_QUEUE_KINDS:-mesh m16}
MAX_CHILDREN=${CMR_QUEUE_MAX_CHILDREN:-4}
LOCK_TAG=${CMR_QUEUE_LOCK_TAG:-all}
exec 9>"$R/remote_queue_${LOCK_TAG}.lock"
flock -n 9 || { echo QUEUE_ALREADY_RUNNING; exit 1; }
# Reconcile jobs left by a preceding scheduler before rewriting any wrapper.
WAIT_PATTERN='^sq_(mesh|m16)_'
if [ "$KINDS" = m16 ]; then WAIT_PATTERN='^sq_m16_'; fi
while bjobs -u ghy19 -noheader -o job_name 2>/dev/null | grep -Eq "$WAIT_PATTERN"; do
 echo WAIT_PREVIOUS_QUEUE_JOBS; sleep 15
done
template="$R/logs/dc/20261020_split1024_tt_r1_mesh_c300_rsplitl1c1p1x9y12m1g32s0a0.sh"
oldref=CMRRouter_split_l1_c1_p1_x9_y12_m1_g32_s0_a0
oldcid=20261020_split1024_tt_r1_mesh_c300_rsplitl1c1p1x9y12m1g32s0a0
declare -A running
active_names=$(bjobs -u ghy19 -noheader -o job_name 2>/dev/null || true)
ok() {
 local cid=$1 ref=$2
 grep -q '^CMR_HIER_CHILD_DC_PASS ' "$R/logs/dc/$cid.log" 2>/dev/null &&
 test -s "$R/outputs/$cid/$ref.ddc" && test -s "$R/outputs/$cid/${ref}_post.v" && test -s "$R/outputs/$cid/$ref.sdf"
}
for kind in $KINDS; do
 parent=20261020_split1024_tt_r1_$kind
 pairs=(); pending=(); refs=(); index=0
 while IFS=$'\t' read -r ref x y level child parentlanes mesh grid shift static; do
  [ "$ref" != ref ] || continue
  safe=${ref/CMRRouter/r}; safe=${safe//_/}
  printf -v cid '%s_c%02d_%s' "$parent" "$index" "$safe"
  index=$((index+1)); pairs+=("$cid:$ref")
  ok "$cid" "$ref" && continue
  if printf '%s\n' "$active_names" | grep -Fx "cmr_hier_child_$cid" >/dev/null; then
   while bjobs -J "cmr_hier_child_$cid" -noheader -o stat 2>/dev/null | grep -Eq '^(RUN|PEND|PSUSP|USUSP|SSUSP)$'; do
    echo "WAIT_EXISTING $cid"; sleep 15
   done
  fi
  ok "$cid" "$ref" && continue
  ports=$((4*child+parentlanes)); adapters=0
  [ "$parentlanes" -le 1 ] || adapters=$((adapters+4*child))
  [ "$child" -le 1 ] || adapters=$((adapters+12*child+4*parentlanes))
  wrapper="$R/logs/dc/$cid.sh"
  sed -e "s/$oldcid/$cid/g" -e "s/$oldref/$ref/g" \
      -e "s@rtl/split/mesh/children/@rtl/split/$kind/children/@g" \
      -e "s/CMR_EXPECTED_PORTS=5 /CMR_EXPECTED_PORTS=$ports /g" \
      -e "s/CMR_EXPECTED_ADAPTERS=0 /CMR_EXPECTED_ADAPTERS=$adapters /g" \
      "$template" > "$wrapper.tmp"
  test -s "$wrapper.tmp"; mv "$wrapper.tmp" "$wrapper"; chmod +x "$wrapper"
  pending+=("$cid"); refs+=("$ref")
 done < "$R/rtl/split/$kind/routers.tsv"
 echo "REMOTE_QUEUE_PLAN $kind remaining=${#pending[@]} total=$index"
 next=0; running=()
 while [ "$next" -lt "${#pending[@]}" ] || [ "${#running[@]}" -gt 0 ]; do
  for jid in "${!running[@]}"; do
   pos=${running[$jid]}; cid=${pending[$pos]}; ref=${refs[$pos]}
   state=$(bjobs -noheader -o stat "$jid" 2>/dev/null | tr -d '[:space:]' || true)
   if ok "$cid" "$ref"; then
    echo "REMOTE_CHILD_PASS $jid $cid"; unset 'running[$jid]'
   elif [[ "$state" =~ ^(EXIT|ZOMBI|UNKWN)$ ]] || [ -z "$state" ]; then
    echo "REMOTE_QUEUE_FAIL $jid $cid state=$state"; exit 2
   fi
  done
  while [ "${#running[@]}" -lt "$MAX_CHILDREN" ] && [ "$next" -lt "${#pending[@]}" ]; do
   cid=${pending[$next]}
   out=$(bsub -n 4 -R 'span[hosts=1]' -J "sq_${kind}_${next}" -o "$R/logs/dc/$cid.log" -e "$R/logs/dc/$cid.log.err" "$R/logs/dc/$cid.sh")
   jid=$(printf '%s' "$out" | sed -n 's/.*Job <\([0-9]*\)>.*/\1/p')
   test -n "$jid"; running[$jid]=$next
   echo "REMOTE_CHILD_SUBMIT $jid $cid"; next=$((next+1))
  done
  sleep 15
 done
 top=CMRMeshNoC; ports=5120; adapters=0
 if [ "$kind" = m16 ]; then top=PROP_temp1024_m16; ports=8192; adapters=4096; fi
 list=$(IFS=,; echo "${pairs[*]}")
 stitch="$R/logs/dc/${parent}_stitch.sh"
 { echo '#!/bin/bash'; echo 'source /etc/profile 2>/dev/null || true'; echo 'module load syn 2>/dev/null || true'
 printf 'export CMR_REMOTE_ROOT=%q CMR_HIER_STITCH_RUN_ID=%q CMR_HIER_TOP=%q CMR_HIER_DUT_V=%q CMR_HIER_CHILD_LIST=%q CMR_EXPECTED_ROUTERS=1024 CMR_EXPECTED_PORTS=%s CMR_EXPECTED_ADAPTERS=%s CMR_EXPECTED_FIFOS=0 CMR_NETWORK_NODES=1024 CMR_LIBRARY_CORNER=tt0p8v25c\n' "$R" "$parent" "$top" "$R/rtl/split/$kind/top/$top.v" "$list" "$ports" "$adapters"
 printf 'cd %q\nexec dc_shell-t -64 -f %q\n' "$R" "$R/scripts/dc/run_dc_cmr_hier_stitch.tcl"
 } > "$stitch"
 chmod +x "$stitch"
 out=$(bsub -n 8 -R 'span[hosts=1]' -J "sq_${kind}_stitch" -o "$R/logs/dc/$parent.log" -e "$R/logs/dc/$parent.log.err" "$stitch")
 jid=$(printf '%s' "$out" | sed -n 's/.*Job <\([0-9]*\)>.*/\1/p'); test -n "$jid"
 echo "REMOTE_STITCH_SUBMIT $kind $jid"
 while ! grep -q '^CMR_NETWORK_DC_PASS ' "$R/logs/dc/$parent.log" 2>/dev/null; do
  state=$(bjobs -noheader -o stat "$jid" 2>/dev/null | tr -d '[:space:]' || true)
  [[ ! "$state" =~ ^(EXIT|ZOMBI|UNKWN)$ ]] || exit 3
  sleep 30
 done
 echo "REMOTE_NETWORK_PASS $kind"
done
echo REMOTE_SPLIT1024_BOTH_PASS

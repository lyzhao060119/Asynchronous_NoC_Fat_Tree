#!/bin/bash
set -euo pipefail
echo CLEANUP_NATIVE_START
R=/home/ghy19/Asynchronous_Router_CMR
active=$(bjobs -u ghy19 -l 2>&1) || { echo ACTIVE_AUDIT_FAILED; exit 2; }
freed=0
remove_old() {
  local d="$1" parent="$2"
  [ -d "$d" ] || return 0
  [ ! -L "$d" ] || return 0
  local resolved
  resolved=$(readlink -f "$d")
  [ "$(dirname "$resolved")" = "$parent" ] || { echo REFUSE_PATH "$d"; exit 3; }
  if printf '%s' "$active" | grep -F "$(basename "$d")" >/dev/null; then
    echo SKIP_ACTIVE "$d"; return 0
  fi
  local bytes
  bytes=$(du -sx -B1 "$d" | cut -f1)
  echo DELETE_BEGIN "$bytes" "$resolved"
  rm -rf --one-file-system -- "$resolved"
  [ ! -e "$resolved" ]
  freed=$((freed+bytes))
  echo DELETE_DONE "$bytes" "$resolved"
}
old=(20260913_1130_prop256_1248_topmesh48_hierdc_stitch_node19
     20260914_prop_temp256_b8_hier_dc_06
     20260915_122347_cmr_mesh256_hier_dc
     20261013_cmr_mesh256_tt_clickopt_r1
     20260915_122347_cmr_pfat_temp256_hier_dc)
for prefix in "${old[@]}"; do
  for d in "$R/outputs/$prefix" "$R/outputs/${prefix}"_c*; do
    remove_old "$d" "$R/outputs"
  done
done
for d in "$R/work/"*dc*202609*; do remove_old "$d" "$R/work"; done
count=0
while IFS= read -r -d '' p; do
  [ ! -L "$p" ] || continue
  [ ! -e "$p.gz" ] && [ ! -e "$p.gz.cleanup_tmp" ] || continue
  if printf '%s' "$active" | grep -F "$(basename "$p")" >/dev/null; then
    echo SKIP_ACTIVE "$p"; continue
  fi
  before=$(stat -c '%s:%Y' "$p")
  bytes=$(stat -c '%s' "$p")
  echo GZIP_BEGIN "$bytes" "$p"
  hash=$(sha256sum "$p" | cut -d' ' -f1)
  gzip -1 -c -- "$p" > "$p.gz.cleanup_tmp"
  recovered=$(gzip -dc -- "$p.gz.cleanup_tmp" | sha256sum | cut -d' ' -f1)
  [ "$hash" = "$recovered" ] && [ "$before" = "$(stat -c '%s:%Y' "$p")" ] || {
    echo VERIFY_FAIL "$p"; exit 4;
  }
  packed=$(stat -c '%s' "$p.gz.cleanup_tmp")
  if [ "$packed" -ge "$bytes" ]; then
    rm -- "$p.gz.cleanup_tmp"; continue
  fi
  touch -r "$p" "$p.gz.cleanup_tmp"
  mv -- "$p.gz.cleanup_tmp" "$p.gz"
  rm -- "$p"
  freed=$((freed+bytes-packed)); count=$((count+1))
  echo GZIP_DONE "$((bytes-packed))" "$hash" "$p.gz"
done < <(find "$R/logs" -type f -mmin +2880 -size +1M \( -name '*.log' -o -name '*.out' -o -name '*.err' -o -name '*.rpt' -o -name '*.txt' -o -name '*.vcd' -o -name '*.fsdb' \) -print0)
echo CLEANUP_PASS "freed_bytes=$freed" "compressed_files=$count"

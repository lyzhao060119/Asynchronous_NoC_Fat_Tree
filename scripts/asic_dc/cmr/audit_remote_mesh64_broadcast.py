#!/usr/bin/env python3
"""Print compact remote evidence for current Mesh64 broadcast cases."""

from __future__ import annotations

import json

from run_remote_cmr_noc16_sdf import connect


ROOT = "/prjtemp/ghy19/date2027_formal64/20261015_193500_formal64_multicast_inputs_r1"
JOB = ROOT + "/jobs/20261017_191000_mesh64_xfirsty_multicast_scan_r2.json"


def run(client, command: str) -> str:
    _stdin, stdout, stderr = client.exec_command(command, timeout=300)
    output = stdout.read().decode(errors="replace")
    error = stderr.read().decode(errors="replace")
    if error:
        output += "\nSTDERR:\n" + error
    return output


def main() -> None:
    client = connect()
    try:
        print("REMOTE_CONNECTED", flush=True)
        command = f"""python3 - <<'PY'
import json
from pathlib import Path

root = Path({ROOT!r})
job = json.loads(Path({JOB!r}).read_text())
print('JOB_JSON', json.dumps(job, sort_keys=True))
for seed in (202701, 202702, 202703):
  for load in (10, 20, 40):
    stem = f'ALL-BROADCAST_n64_s{{seed}}_m{{load}}_FM64'
    result = root / 'results' / 'FM64' / (stem + '.csv')
    logdir = root / 'logs' / 'FM64' / stem
    print('CASE', stem)
    print('RESULT_EXISTS', result.exists(), result.stat().st_size if result.exists() else -1,
          result.stat().st_mtime_ns if result.exists() else -1)
    if result.exists():
      print('RESULT_TEXT', result.read_text(errors='replace').strip())
    for name in ('stage.log','run.log','stdout.log','sdf_annotate.log','input_hashes.log'):
      path = logdir / name
      print('FILE', name, path.exists(), path.stat().st_size if path.exists() else -1,
            path.stat().st_mtime_ns if path.exists() else -1)
      if path.exists() and name in ('stage.log','input_hashes.log'):
        print('FULL', name, json.dumps(path.read_text(errors='replace').splitlines()))
      if path.exists() and name != 'sdf_annotate.log':
        lines = path.read_text(errors='replace').splitlines()
        keep = [line for line in lines if any(token in line for token in (
          'CASE_PASS','CASE_FAIL','TB_RESULT','TB_X_','TB_STALL','TB_HARD_TIMEOUT',
          'Fatal:','Timing violation','Total errors','SDF annotation'))]
        print('MARKERS', name, json.dumps(keep[-30:]))
      elif path.exists():
        with path.open(errors='replace') as stream:
          lines = stream.readlines()[-200:]
        keep = [line.strip() for line in lines if any(token in line for token in (
          'Total errors','SDF annotation','Error:','Warning:'))]
        print('MARKERS', name, json.dumps(keep[-30:]))
PY"""
        print(run(client, command), flush=True)
    finally:
        client.close()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Stage isolated sources remotely and submit generation plus two compiles."""
from pathlib import Path
import json
import shlex
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks"
ARCHIVE = "/home/ghy19/Asynchronous_Router_CMR"
MESH = "20261018_123500_mesh256_xfirsty_tt_resynth_r1"
M16 = "20261019_085616_m16_dc256_tt_r1"


def main():
    c = connect()
    try:
        print(remote_run(c, f"mkdir -p {ROOT}/src {ROOT}/jobs {ROOT}/manifests {ROOT}/experiments/scripts/date_v3"))
        s = c.open_sftp()
        files = [(REPO / "scripts/asic_dc/cmr/formal256_campaign.py", "formal256_campaign.py"),
                 (REPO / "scripts/asic_dc/cmr/formal256_control.py", "formal256_control.py"),
                 (REPO / "scripts/asic_dc/cmr/run_formal256.sh", "run_formal256.sh"),
                 (REPO / "sim/AsyncNoC/testbench/tb_noc_async_keycase.sv", "src/tb_noc_async_keycase.sv"),
                 (REPO / "sim/AsyncNoC/async_noc_scale_port_adapter.sv", "src/async_noc_scale_port_adapter.sv")]
        files += [(p, "experiments/scripts/date_v3/" + p.name)
                  for p in (REPO / "DATE_paper/experiments/scripts/date_v3").glob("*.py")]
        for local, relative in files:
            data = local.read_bytes().replace(b"\r\n", b"\n")
            with s.file(ROOT + "/" + relative, "wb") as f:
                f.write(data)
        config = (f"ARCHIVE={ARCHIVE}\nMESH_RUN={MESH}\nM16_RUN={M16}\n"
                  "LIB_V=/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v\n")
        with s.file(ROOT + "/config.sh", "w") as f:
            f.write(config)
        s.close()
        cmd = f'''set -e
cd {ROOT}
for p in {ARCHIVE}/outputs/{MESH}/CMRMeshNoC{{.ddc,_post.v,.sdf}} {ARCHIVE}/outputs/{M16}/PROP_temp256_m16{{.ddc,_post.v,.sdf}}; do test -s "$p"; sha256sum "$p"; done > manifests/netlist_hashes.sha256
/soft/GNU/python3.12/bin/python3 formal256_campaign.py build-tb --root {ROOT}
/soft/GNU/python3.12/bin/python3 -m py_compile formal256_campaign.py
bash -n run_formal256.sh
sha256sum formal256_campaign.py run_formal256.sh src/* config.sh > manifests/source_hashes.sha256
bsub -q normal -n 1 -J f256_inputs -o {ROOT}/jobs/generate_r2.log -e {ROOT}/jobs/generate_r2.err "/soft/GNU/python3.12/bin/python3 {ROOT}/formal256_campaign.py generate --root {ROOT}"
for d in Mesh256 M16_256; do
bsub -q normal -n 1 -R 'span[hosts=1]' -J f256_compile_$d -o {ROOT}/jobs/compile_${{d}}_r2.log -e {ROOT}/jobs/compile_${{d}}_r2.err "env FORMAL256_ROOT={ROOT} bash {ROOT}/run_formal256.sh $d compile"
done
'''
        print(remote_run(c, cmd), flush=True)
        print("FORMAL256_REMOTE_ROOT", ROOT)
    finally:
        c.close()


if __name__ == "__main__":
    main()

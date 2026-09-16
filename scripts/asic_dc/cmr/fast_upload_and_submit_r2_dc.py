#!/usr/bin/env python3
"""Fast SFTP chunk upload for Round-2 large RTL, then hier-DC submit-only."""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from _tmp_paper64_common import connect_failover, remote_run_failover  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import reconnect  # noqa: E402

ROOT = "/home/ghy19/Asynchronous_Router_CMR"
FM_RUN = "20260915_122347_cmr_mesh256_hier_dc"
PFAT_RUN = "20260915_122347_cmr_pfat_temp256_hier_dc"
CHUNK = 1024 * 1024

FILES = (
    (
        REPO / "generated_cmr/pfat_temp256/PFAT_temp256.v",
        "rtl/network_pfat_temp256/PFAT_temp256.v",
    ),
    (
        REPO / "generated_cmr/mesh_noc256_11/CMRMeshNoC.v",
        "rtl/network_fm256/CMRMeshNoC.v",
    ),
)


def sha_local(path: Path) -> tuple[bytes, str]:
    data = path.read_bytes().replace(b"\r\n", b"\n")
    return data, hashlib.sha256(data).hexdigest()


def upload_one(client, local: Path, rel_dest: str):
    data, digest = sha_local(local)
    remote = "%s/%s" % (ROOT, rel_dest)
    temporary = remote + ".upload_fast_%d" % os.getpid()
    client, probe = remote_run_failover(
        client,
        "mkdir -p %s && (test -s %s && sha256sum %s || echo MISSING)"
        % (
            remote.rsplit("/", 1)[0],
            remote,
            remote,
        ),
    )
    if digest in probe:
        print("UPLOAD_SKIP", rel_dest, digest[:16], flush=True)
        return client
    print("UPLOAD_FAST_START", rel_dest, len(data), flush=True)
    for attempt in range(6):
        try:
            sftp = client.open_sftp()
            with sftp.file(temporary, "wb") as handle:
                for offset in range(0, len(data), CHUNK):
                    handle.write(data[offset : offset + CHUNK])
                    if offset and offset % (8 * CHUNK) == 0:
                        print("UPLOAD_FAST_PROGRESS", rel_dest, offset, len(data), flush=True)
                handle.flush()
            sftp.close()
            client, check = remote_run_failover(
                client,
                "test $(stat -c %%s %s) -eq %d && sha256sum %s && mv -f %s %s && echo OK"
                % (temporary, len(data), temporary, temporary, remote),
            )
            if digest in check and "OK" in check:
                print("UPLOAD_FAST_OK", rel_dest, digest[:16], flush=True)
                return client
            print("UPLOAD_FAST_VERIFY_FAIL", attempt, check[-200:], flush=True)
        except Exception as exc:
            print("UPLOAD_FAST_RETRY", attempt, exc, flush=True)
            try:
                client.close()
            except Exception:
                pass
            time.sleep(2 + attempt)
            client = connect_failover()
    raise RuntimeError("fast upload failed " + rel_dest)


def launch(kind: str, run_id: str) -> int:
    env = os.environ.copy()
    env.update(
        {
            "C1_HOST": os.environ.get("C1_HOST", "192.168.2.8"),
            "CMR_HIER_KIND": kind,
            "CMR_HIER_STITCH_RUN_ID": run_id,
            "CMR_HIER_SKIP_GLS": "1",
            "CMR_HIER_CHILD_BATCH_SIZE": "4",
            "CMR_DESCAL": "1",
            "CMR_DESCAL_SUBMIT_ONLY": "1",
            "CMR_DES_BSUB_EXTRA": '-m "node21 node26 node24 node18"',
            "CMR_HIER_CHILD_BSUB": "-n 4",
            "CMR_HIER_STITCH_BSUB": "-n 8",
            "CMR_RCU_MATCHED_DELAY_UNIT_PS": "50",
            "CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS": "150",
            "PYTHONUNBUFFERED": "1",
        }
    )
    print("HIER_SUBMIT", kind, run_id, flush=True)
    return subprocess.run(
        [sys.executable, str(HERE / "run_remote_cmr_hier_dc.py")],
        cwd=str(HERE),
        env=env,
    ).returncode


def main() -> int:
    client = connect_failover()
    try:
        for local, dest in FILES:
            if not local.is_file():
                raise SystemExit("missing " + str(local))
            client = upload_one(client, local, dest)
    finally:
        try:
            client.close()
        except Exception:
            pass

    rc_pfat = launch("pfat_temp256", PFAT_RUN)
    print("PFAT_RC", rc_pfat, flush=True)
    rc_fm = launch("mesh256", FM_RUN)
    print("FM_RC", rc_fm, flush=True)
    if rc_pfat == 0 and rc_fm == 0:
        print("R2_DC_BOTH_SUBMITTED", PFAT_RUN, FM_RUN, flush=True)
        return 0
    print("R2_DC_PARTIAL", "pfat", rc_pfat, "fm", rc_fm, flush=True)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

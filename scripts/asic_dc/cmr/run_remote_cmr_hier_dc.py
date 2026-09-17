#!/usr/bin/env python3
"""Parallel hop-sized unique-router DC + link-only top stitch.

Same-level nodes keep compile-time coordinates.  Each unique CMRRouter*
module is one DC job; the stitch job only instantiates those DDC files and
writes NoC_64nodes_post.v / CMRMeshNoC_post.v plus hierarchical MAXIMUM SDF.

CMR_HIER_KIND=thin|1248|1222|mesh|prop256|prop_temp256|prop_temp256_m16|mesh256|prop1024|mesh1024.
CMR_DESCAL_SUBMIT_ONLY=1 returns after bsub.
If stitch/SDF scope fails, the matrix launcher falls back to one full-network
DC per missing design (still parallel across designs).
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import sys
import base64
from datetime import datetime
from pathlib import Path

from cmr_descal_env import apply_bsub, is_descal, submit_only
from cmr_frozen_run_ids import refuse_overwrite
from hier_noc import child_run_id, unique_router_jobs
from run_remote_cmr_flow import atomic_put_bytes
from run_remote_cmr_fat_tree_noc16_sdf import (
    atomic_put_retry,
    connect,
    job_id,
    reconnect,
    remote_run_retry,
    wait_job,
)


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
KIND = os.environ.get("CMR_HIER_KIND", "thin").strip().lower()
PARENT_RUN_ID = os.environ.get(
    "CMR_HIER_STITCH_RUN_ID",
    os.environ.get("CMR_NOC64_RUN_ID")
    or os.environ.get("CMR_MESH64_RUN_ID")
    or datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_descal_hier",
)
CHILD_BSUB = apply_bsub(os.environ.get("CMR_HIER_CHILD_BSUB", "-n 4"))
STITCH_BSUB = apply_bsub(os.environ.get("CMR_HIER_STITCH_BSUB", "-n 8"))
SUBMIT_ONLY = submit_only()
DC_POLLS = int(os.environ.get("CMR_HIER_DC_POLLS", "1440"))
# The login node can reject a long burst of bsub requests with an empty
# response.  Keep each wave small and verify its child markers before
# releasing the next one.  Zero retains the historical all-at-once behavior.
CHILD_BATCH_SIZE = int(os.environ.get("CMR_HIER_CHILD_BATCH_SIZE", "8"))
SKIP_UPLOAD = os.environ.get("CMR_HIER_SKIP_UPLOAD", "0") == "1"
RCU_STEPS = int(os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1"))
RCU_UNIT_PS = int(os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50"))
MESH_RCU_UNIT_PS = int(os.environ.get("CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS", "150"))
ACKIN_UNIT_PS = int(os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50"))
RESULT_ROOT = REPO / "scripts" / "asic_dc" / "cmr" / "results"


def upload_large_verified(client, source: Path, destination: str):
    """Atomically upload a large RTL file in bounded SFTP writes.

    A single Paramiko SFTP stream has repeatedly left a zero-byte DUT on the
    login node.  Use fixed-offset, base64-decoded blocks so a retry overwrites
    its own block rather than appending a duplicate.
    """
    data = source.read_bytes().replace(b"\r\n", b"\n")
    digest = hashlib.sha256(data).hexdigest()
    remote = ROOT + "/" + destination
    temporary = "%s.upload.%d" % (remote, os.getpid())
    client, _ = remote_run_retry(client, ": > " + shlex.quote(temporary))
    block_bytes = 48 * 1024
    for index, offset in enumerate(range(0, len(data), block_bytes)):
        encoded = base64.b64encode(data[offset : offset + block_bytes]).decode("ascii")
        command = (
            "printf %%s %s | base64 -d | dd of=%s bs=%d seek=%d conv=notrunc status=none && echo CMR_BLOCK_OK"
            % (shlex.quote(encoded), shlex.quote(temporary), block_bytes, index)
        )
        for attempt in range(5):
            client, output = remote_run_retry(client, command)
            if "CMR_BLOCK_OK" in output:
                break
            print("UPLOAD_LARGE_BLOCK_RETRY", destination, index, attempt, repr(output[-300:]), flush=True)
        else:
            raise RuntimeError("base64 block upload failed %s block=%d" % (destination, index))
        if index and index % 64 == 0:
            print("UPLOAD_LARGE_PROGRESS", destination, offset, len(data), flush=True)
    client, output = remote_run_retry(
        client,
        "test $(stat -c %%s %s) -eq %d && sha256sum %s && echo CMR_UPLOAD_SIZE_OK"
        % (shlex.quote(temporary), len(data), shlex.quote(temporary)),
    )
    if digest not in output or "CMR_UPLOAD_SIZE_OK" not in output:
        raise RuntimeError("SHA-256 or size mismatch for " + destination + ": " + output)
    client, _ = remote_run_retry(
        client, "mv -f %s %s" % (shlex.quote(temporary), shlex.quote(remote))
    )
    print("UPLOAD_LARGE_OK", destination, len(data), digest, flush=True)
    return client


def _job(kind: str, run_id: str) -> str:
    if is_descal():
        return "cmr_descal_%s_%s" % (kind, run_id)
    return "cmr_%s_%s" % (kind, run_id)


def _parse_stat_sizes(text: str) -> dict[str, int]:
    """Parse `stat -c '%s %n'` lines, ignoring login-shell module noise."""
    sizes: dict[str, int] = {}
    for line in text.splitlines():
        parts = line.strip().split(None, 1)
        if len(parts) != 2 or not parts[0].isdigit():
            continue
        sizes[parts[1]] = int(parts[0])
    return sizes


def _child_artifacts_ok(client, cid: str, ref: str):
    """Return (client, ok) if child log PASSed and ddc/post.v/sdf are non-empty."""
    dc_log = ROOT + "/logs/dc/" + cid + ".log"
    out_dir = ROOT + "/outputs/" + cid
    client, pass_probe = remote_run_retry(
        client,
        "grep -E '^CMR_HIER_CHILD_DC_PASS ' %s >/dev/null 2>&1 "
        "&& echo HAS_PASS || echo NO_PASS" % shlex.quote(dc_log),
    )
    if "HAS_PASS" not in pass_probe:
        return client, False
    client, sizes_text = remote_run_retry(
        client,
        "stat -c '%%s %%n' %s %s %s 2>/dev/null || true"
        % (
            shlex.quote(out_dir + "/" + ref + ".ddc"),
            shlex.quote(out_dir + "/" + ref + "_post.v"),
            shlex.quote(out_dir + "/" + ref + ".sdf"),
        ),
    )
    sizes = _parse_stat_sizes(sizes_text)
    needed = [
        out_dir + "/" + ref + ".ddc",
        out_dir + "/" + ref + "_post.v",
        out_dir + "/" + ref + ".sdf",
    ]
    return client, all(path in sizes and sizes[path] > 0 for path in needed)


def _prepare() -> dict:
    if KIND == "mesh":
        from run_remote_cmr_mesh64_sdf import generate_rtl, shared_input_files

        generated = generate_rtl()
        dut_name = "CMRMeshNoC.v"
        top = "CMRMeshNoC"
        remote_dut = "rtl/mesh64/CMRMeshNoC.v"
        expected = {"routers": 64, "ports": 320, "adapters": 0}
        files = shared_input_files()
    elif KIND in ("thin", "1248", "1222"):
        from run_remote_cmr_noc64_sdf import PROFILES, generate_rtl, shared_input_files

        generated = generate_rtl(KIND)
        dut_name = "NoC_64nodes.v"
        top = "NoC_64nodes"
        remote_dut = "rtl/noc64_%s/NoC_64nodes.v" % KIND
        cfg = PROFILES[KIND]
        expected = {
            "routers": 21,
            "ports": cfg["expected_ports"],
            "adapters": cfg["expected_adapters"],
        }
        files = shared_input_files()
    elif KIND == "prop_temp256":
        # Experimental B8 network.  This is intentionally independent from
        # the locked PROP256 (PFAT-tile) matrix entry.
        from run_remote_cmr_noc64_sdf import shared_input_files

        generated = REPO / "generated_cmr" / "prop_temp256"
        dut_name = "PROP_temp256.v"
        top = "PROP_temp256"
        remote_dut = "rtl/network_prop_temp256/PROP_temp256.v"
        expected = {"routers": 224, "ports": 1536, "adapters": 640}
        files = shared_input_files()
    elif KIND == "prop_temp256_m16":
        # M16 variant: L3(1,4) + 16 Mesh(1,4) planes. Independent of frozen B8.
        from run_remote_cmr_noc64_sdf import shared_input_files

        generated = REPO / "generated_cmr" / "prop_temp256_m16"
        dut_name = "PROP_temp256_m16.v"
        top = "PROP_temp256_m16"
        remote_dut = "rtl/network_prop_temp256_m16/PROP_temp256_m16.v"
        expected = {"routers": 256, "ports": 2048, "adapters": 1024}
        files = shared_input_files()
    elif KIND == "pfat_temp256":
        from run_remote_cmr_noc64_sdf import shared_input_files

        generated = REPO / "generated_cmr" / "pfat_temp256"
        dut_name = "PFAT_temp256.v"
        top = "PFAT_temp256"
        remote_dut = "rtl/network_pfat_temp256/PFAT_temp256.v"
        # 4*21 tile + 4*4 mesh = 100 routers.
        # Hier stitch measured IPM/OPM = 768 on the first authorized run
        # (20260915_122347); do not use the placeholder 800.
        expected = {"routers": 100, "ports": 768, "adapters": 0}
        files = shared_input_files()
    elif KIND in ("prop256", "mesh256", "prop1024", "mesh1024"):
        from v31_emit import asic_input_files, generate_network_rtl

        sys.path.insert(0, str(REPO / "DATE paper" / "experiments" / "scripts"))
        from date_v3.network_matrix import matrix_row

        design_id = {
            "prop256": "PROP256",
            "mesh256": "FM256",
            "prop1024": "PROP1024",
            "mesh1024": "FM1024",
        }[KIND]
        generated = generate_network_rtl(design_id)
        row = matrix_row(design_id)
        emit = row["emit"]
        dut_name = emit["dut_file"]
        top = emit["top"]
        remote_dut = "rtl/network_%s/%s" % (design_id.lower(), dut_name)
        expected = {
            "routers": row["expected"]["routers"],
            "ports": row["expected"]["ports"],
            "adapters": row["expected"]["adapters"] or 0,
        }
        files = asic_input_files(design_id)
    else:
        raise SystemExit(
            "CMR_HIER_KIND must be thin, 1248, 1222, mesh, prop256, prop_temp256, "
            "prop_temp256_m16, pfat_temp256, mesh256, prop1024, or mesh1024; got %r"
            % KIND
        )
    verilog = (generated / dut_name).read_text(encoding="utf-8")
    jobs = unique_router_jobs(verilog)
    if not jobs:
        raise SystemExit("no unique CMRRouter modules in %s" % (generated / dut_name))
    files[generated / dut_name] = remote_dut
    files[REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_child.tcl"] = "scripts/dc/run_dc_cmr_hier_child.tcl"
    files[REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_stitch.tcl"] = "scripts/dc/run_dc_cmr_hier_stitch.tcl"
    files[REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc64.sh"] = "scripts/run_gls_cmr_noc64.sh"
    files[REPO / "scripts/asic_dc/cmr/run_gls_cmr_mesh64.sh"] = "scripts/run_gls_cmr_mesh64.sh"
    files[REPO / "scripts/asic_dc/cmr/run_gls_cmr_network.sh"] = "scripts/run_gls_cmr_network.sh"
    nodes = {
        "prop256": 256,
        "prop_temp256": 256,
        "prop_temp256_m16": 256,
        "pfat_temp256": 256,
        "mesh256": 256,
        "prop1024": 1024,
        "mesh1024": 1024,
    }.get(KIND, 64)
    return {
        "generated": generated,
        "dut_name": dut_name,
        "top": top,
        "remote_dut": remote_dut,
        "expected": expected,
        "jobs": jobs,
        "files": files,
        "nodes": nodes,
        "large": KIND
        in (
            "prop256",
            "prop_temp256",
            "prop_temp256_m16",
            "pfat_temp256",
            "mesh256",
            "prop1024",
            "mesh1024",
        ),
        "net_kind": (
            "fm"
            if KIND.startswith("mesh")
            else (
                "pfat_temp"
                if KIND == "pfat_temp256"
                else (
                    "prop_temp"
                    if KIND in ("prop_temp256", "prop_temp256_m16")
                    else "prop"
                )
            )
        ),
    }


def main() -> None:
    refuse_overwrite(PARENT_RUN_ID, action="hier-dc")
    prep = _prepare()
    print(
        "HIER_PLAN kind=%s parent=%s unique_refs=%d top=%s"
        % (KIND, PARENT_RUN_ID, len(prep["jobs"]), prep["top"]),
        flush=True,
    )
    client = connect()
    remote_dut_dir = prep["remote_dut"].rsplit("/", 1)[0]
    client, _ = remote_run_retry(
        client,
        "mkdir -p %s/%s %s/scripts/dc %s/rtl %s/logs/dc %s/logs/gls/%s %s/outputs "
        "%s/reports/dc %s/work %s/sim/cases_noc64 %s/sim/cases_network %s/sim/tb"
        % (
            ROOT, remote_dut_dir, ROOT, ROOT, ROOT, ROOT, PARENT_RUN_ID, ROOT,
            ROOT, ROOT, ROOT, ROOT, ROOT,
        ),
    )
    if SKIP_UPLOAD:
        print("HIER_UPLOAD_SKIPPED explicit CMR_HIER_SKIP_UPLOAD=1", flush=True)
    else:
        sftp = client.open_sftp()
        for source, destination in prep["files"].items():
            print("UPLOAD", destination, flush=True)
            if source.stat().st_size > 1024 * 1024:
                # Resume-friendly: skip multi-minute upload when remote already matches.
                digest = hashlib.sha256(
                    source.read_bytes().replace(b"\r\n", b"\n")
                ).hexdigest()
                client, remote_hash = remote_run_retry(
                    client,
                    "test -s %s && sha256sum %s || echo MISSING"
                    % (
                        shlex.quote(ROOT + "/" + destination),
                        shlex.quote(ROOT + "/" + destination),
                    ),
                )
                if digest in remote_hash:
                    print("UPLOAD_SKIP_MATCH", destination, digest, flush=True)
                    continue
                sftp.close()
                client = upload_large_verified(client, source, destination)
                sftp = client.open_sftp()
            else:
                client, sftp, _digest = atomic_put_retry(client, sftp, source, destination)
        sftp.close()
    remote_run_retry(
        client,
        "sed -i 's/\\r$//' %s/scripts/dc/run_dc_cmr_hier_child.tcl "
        "%s/scripts/dc/run_dc_cmr_hier_stitch.tcl; "
        "chmod +x %s/scripts/run_gls_cmr_noc64.sh %s/scripts/run_gls_cmr_mesh64.sh "
        "%s/scripts/run_gls_cmr_network.sh 2>/dev/null || true"
        % (ROOT, ROOT, ROOT, ROOT, ROOT),
    )

    child_jids = []
    child_pairs = []
    batch_size = len(prep["jobs"]) if CHILD_BATCH_SIZE <= 0 else CHILD_BATCH_SIZE
    force_child = os.environ.get("CMR_HIER_FORCE_CHILD", "0") == "1"
    for batch_start in range(0, len(prep["jobs"]), batch_size):
      batch_jobs = prep["jobs"][batch_start : batch_start + batch_size]
      batch_submissions = []
      for batch_offset, job in enumerate(batch_jobs):
        index = batch_start + batch_offset
        cid = child_run_id(PARENT_RUN_ID, index, job["ref"])
        refuse_overwrite(cid, action="hier-child")
        if not force_child:
          client, already = _child_artifacts_ok(client, cid, job["ref"])
          if already:
            child_pairs.append("%s:%s" % (cid, job["ref"]))
            print("HIER_CHILD_SKIP_EXISTING", job["ref"], cid, flush=True)
            continue
          # Avoid duplicate bsub while a previous resume left the child RUN/PEND.
          jname = _job("hier_child", cid)
          client, running = remote_run_retry(
              client,
              "bjobs -J %s -noheader 2>/dev/null | awk '{print $1\" \"$3}' | head -n 1"
              % shlex.quote(jname),
          )
          run_line = ""
          for line in running.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0].isdigit() and parts[1] in ("RUN", "PEND", "PSUSP"):
              run_line = line.strip()
              break
          if run_line:
            jid = run_line.split()[0]
            child_jids.append(jid)
            child_pairs.append("%s:%s" % (cid, job["ref"]))
            batch_submissions.append((jid, cid, job["ref"]))
            print("HIER_CHILD_ATTACH_RUNNING", job["ref"], jid, cid, flush=True)
            continue
        wrapper = ROOT + "/logs/dc/" + cid + ".sh"
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "module load syn 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_HIER_CHILD_RUN_ID=%s CMR_HIER_REF=%s "
            "CMR_HIER_DUT_V=%s CMR_EXPECTED_PORTS=%d CMR_EXPECTED_ADAPTERS=%d "
            "CMR_RCU_MATCHED_DELAY_STEPS=%d CMR_RCU_MATCHED_DELAY_UNIT_PS=%d "
            "CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS=%d CMR_OPM_ACKIN_DELAY_UNIT_PS=%d\n"
            "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_hier_child.tcl\n"
            % (
                ROOT,
                shlex.quote(cid),
                shlex.quote(job["ref"]),
                shlex.quote(ROOT + "/" + prep["remote_dut"]),
                job["expected_ports"],
                job["expected_adapters"],
                RCU_STEPS,
                RCU_UNIT_PS,
                MESH_RCU_UNIT_PS,
                ACKIN_UNIT_PS,
                ROOT,
                ROOT,
            )
        )
        sftp = client.open_sftp()
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        client, _ = remote_run_retry(client, "chmod +x %s" % wrapper)
        client, wrap_stat = remote_run_retry(
            client,
            "test -s %s && wc -c < %s && echo WRAPPER_OK || echo WRAPPER_EMPTY"
            % (shlex.quote(wrapper), shlex.quote(wrapper)),
        )
        if "WRAPPER_OK" not in wrap_stat:
          raise RuntimeError("child wrapper missing/empty before bsub: %s (%s)" % (wrapper, wrap_stat))
        jname = _job("hier_child", cid)
        dc_log = ROOT + "/logs/dc/" + cid + ".log"
        client, submit = remote_run_retry(
            client,
            "bsub %s -o %s -e %s.err -J %s %s"
            % (CHILD_BSUB, dc_log, dc_log, shlex.quote(jname), wrapper),
        )
        jid = job_id(submit)
        child_jids.append(jid)
        child_pairs.append("%s:%s" % (cid, job["ref"]))
        batch_submissions.append((jid, cid, job["ref"]))
        print("HIER_CHILD_JOB", job["ref"], jid, cid, flush=True)

      # In submit-only mode callers deliberately want the historical
      # fire-and-forget submission.  Normal DC runs gate each wave on the
      # explicit child marker and non-empty DDC/SDF/netlist artifacts.
      if not SUBMIT_ONLY:
        for jid, cid, ref in batch_submissions:
          client = wait_job(client, jid, "hier_child", polls=DC_POLLS)
          dc_log = ROOT + "/logs/dc/" + cid + ".log"
          child_log = ""
          # LSF can report DONE slightly before the PASS line is flushed.
          for attempt in range(8):
            client, child_log = remote_run_retry(
                client, "cat %s %s.err 2>/dev/null" % (dc_log, dc_log)
            )
            if "CMR_HIER_CHILD_DC_PASS " in child_log:
              break
            client, already = _child_artifacts_ok(client, cid, ref)
            if already:
              child_log = "CMR_HIER_CHILD_DC_PASS artifacts_ok_retry"
              break
            import time as _time

            _time.sleep(5 + attempt)
          if "CMR_HIER_CHILD_DC_PASS " not in child_log:
            print(child_log[-16000:], flush=True)
            raise RuntimeError("hierarchical child failed for %s" % cid)
          # _05 left DONE jobs with 0-byte DDC/SDF/netlist.  Do not advance.
          out_dir = ROOT + "/outputs/" + cid
          client, sizes_text = remote_run_retry(
              client,
              "stat -c '%%s %%n' %s %s %s 2>/dev/null || true"
              % (
                  shlex.quote(out_dir + "/" + ref + ".ddc"),
                  shlex.quote(out_dir + "/" + ref + "_post.v"),
                  shlex.quote(out_dir + "/" + ref + ".sdf"),
              ),
          )
          sizes = _parse_stat_sizes(sizes_text)
          needed = [
              out_dir + "/" + ref + ".ddc",
              out_dir + "/" + ref + "_post.v",
              out_dir + "/" + ref + ".sdf",
          ]
          bad = [path for path in needed if sizes.get(path, 0) <= 0]
          if bad:
            # One more short wait for NFS flush of write_file outputs.
            import time as _time

            _time.sleep(8)
            client, sizes_text = remote_run_retry(
                client,
                "stat -c '%%s %%n' %s %s %s 2>/dev/null || true"
                % (
                    shlex.quote(out_dir + "/" + ref + ".ddc"),
                    shlex.quote(out_dir + "/" + ref + "_post.v"),
                    shlex.quote(out_dir + "/" + ref + ".sdf"),
                ),
            )
            sizes = _parse_stat_sizes(sizes_text)
            bad = [path for path in needed if sizes.get(path, 0) <= 0]
          if bad:
            print(sizes_text, flush=True)
            raise RuntimeError(
              "hierarchical child produced empty artifacts for %s: %s" % (cid, bad)
            )
        print(
            "HIER_CHILD_BATCH_PASS start=%d count=%d submitted=%d"
            % (batch_start, len(batch_jobs), len(batch_submissions)),
            flush=True,
        )

    # ended() not done(): child EXIT used to leave stitch PEND forever.
    # Resume may skip already-PASS children, so dep can be empty.
    dep = " && ".join("ended(%s)" % jid for jid in child_jids)
    child_ids = [pair.split(":", 1)[0] for pair in child_pairs]
    wait_children = (
        "for cid in %s; do\n"
        "  log=%s/logs/dc/${cid}.log\n"
        "  ok=0\n"
        "  i=0\n"
        "  while [ \"$i\" -lt 720 ]; do\n"
        "    if grep -E '^CMR_HIER_CHILD_DC_PASS ' \"$log\" >/dev/null 2>&1; then ok=1; break; fi\n"
        "    if grep -E '^CMR_HIER_CHILD_DC_FAIL ' \"$log\" >/dev/null 2>&1; then\n"
        "      echo CMR_HIER_STITCH_FAIL child $cid; exit 2\n"
        "    fi\n"
        "    i=$((i+1))\n"
        "    sleep 15\n"
        "  done\n"
        "  if [ \"$ok\" -ne 1 ]; then echo CMR_HIER_STITCH_FAIL timeout $cid; exit 2; fi\n"
        "done\n"
        % (" ".join(child_ids), ROOT)
    )
    stitch_wrap = ROOT + "/logs/dc/" + PARENT_RUN_ID + "_stitch.sh"
    stitch_body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        + wait_children
        + "export CMR_REMOTE_ROOT=%s CMR_HIER_STITCH_RUN_ID=%s CMR_HIER_TOP=%s "
        "CMR_HIER_DUT_V=%s CMR_HIER_CHILD_LIST=%s "
        "CMR_EXPECTED_ROUTERS=%d CMR_EXPECTED_PORTS=%d CMR_EXPECTED_ADAPTERS=%d "
        "CMR_EXPECTED_FIFOS=0 CMR_NETWORK_NODES=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_hier_stitch.tcl\n"
        % (
            ROOT,
            shlex.quote(PARENT_RUN_ID),
            shlex.quote(prep["top"]),
            shlex.quote(ROOT + "/" + prep["remote_dut"]),
            shlex.quote(",".join(child_pairs)),
            prep["expected"]["routers"],
            prep["expected"]["ports"],
            prep["expected"]["adapters"],
            shlex.quote(str(prep.get("nodes", 64))),
            ROOT,
            ROOT,
        )
    )
    sftp = client.open_sftp()
    atomic_put_bytes(client, sftp, stitch_body.encode(), stitch_wrap)
    sftp.close()
    client, _ = remote_run_retry(client, "chmod +x %s" % stitch_wrap)
    # Do not use bsub -w ended(jid): long hier runs leave stale LSF ids that
    # later fail with "No matching job found".  The stitch wrapper already waits
    # on CMR_HIER_CHILD_DC_PASS markers for every child.
    stitch_log = ROOT + "/logs/dc/" + PARENT_RUN_ID + ".log"
    stitch_name = _job("hier_stitch", PARENT_RUN_ID)
    stitch_cmd = "bsub %s -o %s -e %s.err -J %s %s" % (
        STITCH_BSUB,
        stitch_log,
        stitch_log,
        shlex.quote(stitch_name),
        stitch_wrap,
    )
    client, stitch_submit = remote_run_retry(client, stitch_cmd)
    stitch_jid = job_id(stitch_submit)
    print(
        "HIER_STITCH_JOB",
        stitch_jid,
        "children_submitted",
        len(child_jids),
        "children_total",
        len(child_pairs),
        flush=True,
    )

    gls_jobs = []
    case_raw = (
        os.environ.get("CMR_NETWORK_CASES")
        or os.environ.get("CMR_NOC64_CASES")
        or os.environ.get("CMR_MESH64_CASES")
        or ""
    )
    case_names = [name for name in case_raw.split(",") if name]
    skip_gls = os.environ.get("CMR_HIER_SKIP_GLS", "0") == "1"
    case_dir = None
    if os.environ.get("CMR_NETWORK_V3_CASE_DIR"):
        case_dir = Path(os.environ["CMR_NETWORK_V3_CASE_DIR"])
    elif os.environ.get("CMR_NOC64_V3_CASE_DIR"):
        case_dir = Path(os.environ["CMR_NOC64_V3_CASE_DIR"])
    if not skip_gls and case_names:
        if case_dir is None:
            raise SystemExit("hier GLS needs CMR_NETWORK_V3_CASE_DIR or CMR_NOC64_V3_CASE_DIR")
        sftp = client.open_sftp()
        remote_cases = {}
        case_remote_dir = "sim/cases_network" if prep["large"] else "sim/cases_noc64"
        for name in case_names:
            local = case_dir / (name + ".case")
            if not local.is_file():
                raise SystemExit("missing hier GLS case " + str(local))
            dest = case_remote_dir + "/" + name + ".case"
            client, sftp, _digest = atomic_put_retry(client, sftp, local, dest)
            remote_cases[name] = ROOT + "/" + dest
        sftp.close()
        gls_bsub = apply_bsub(os.environ.get("CMR_HIER_GLS_BSUB", "-n 8"))
        for name in case_names:
            wrapper = ROOT + "/logs/gls/%s/sdf_%s.sh" % (PARENT_RUN_ID, name)
            if prep["large"]:
                body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_NETWORK_RUN_ID=%s "
                    "CMR_NETWORK_NETLIST_RUN_ID=%s CMR_NETWORK_CASE_NAME=%s "
                    "CMR_NETWORK_CASE_FILE=%s CMR_NETWORK_GLS_MODE=sdf "
                    "CMR_NETWORK_NODES=%s CMR_NETWORK_KIND=%s CMR_NETWORK_TOP=%s "
                    "CMR_NETWORK_RX_CAPTURE_NS=0.1\n"
                    "exec bash %s/scripts/run_gls_cmr_network.sh\n"
                    % (
                        ROOT, shlex.quote(PARENT_RUN_ID), shlex.quote(PARENT_RUN_ID),
                        shlex.quote(name), shlex.quote(remote_cases[name]),
                        shlex.quote(str(prep["nodes"])),
                        shlex.quote(prep["net_kind"]),
                        shlex.quote(prep["top"]),
                        ROOT,
                    )
                )
                jname = _job("network_sdf_%s" % name, PARENT_RUN_ID)
            elif prep["top"] == "CMRMeshNoC":
                body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_MESH64_RUN_ID=%s "
                    "CMR_MESH64_NETLIST_RUN_ID=%s CMR_MESH64_CASE_NAME=%s "
                    "CMR_MESH64_CASE_FILE=%s CMR_MESH64_GLS_MODE=sdf "
                    "CMR_MESH64_RX_CAPTURE_NS=0.1\n"
                    "exec bash %s/scripts/run_gls_cmr_mesh64.sh\n"
                    % (
                        ROOT, shlex.quote(PARENT_RUN_ID), shlex.quote(PARENT_RUN_ID),
                        shlex.quote(name), shlex.quote(remote_cases[name]), ROOT,
                    )
                )
                jname = _job("mesh64_sdf_%s" % name, PARENT_RUN_ID)
            else:
                body = (
                    "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
                    "export CMR_REMOTE_ROOT=%s CMR_NOC64_RUN_ID=%s "
                    "CMR_NOC64_NETLIST_RUN_ID=%s CMR_NOC64_CASE_NAME=%s "
                    "CMR_NOC64_CASE_FILE=%s CMR_NOC64_GLS_MODE=sdf "
                    "CMR_FAT_LANE_PROFILE=%s CMR_NOC64_RX_CAPTURE_NS=0.1 "
                    "CMR_NOC64_INJECT_MAX_RATE=0 CMR_NOC64_SIM_ARGS=\n"
                    "exec bash %s/scripts/run_gls_cmr_noc64.sh\n"
                    % (
                        ROOT, shlex.quote(PARENT_RUN_ID), shlex.quote(PARENT_RUN_ID),
                        shlex.quote(name), shlex.quote(remote_cases[name]),
                        shlex.quote(KIND), ROOT,
                    )
                )
                jname = _job("noc64_%s_sdf_%s" % (KIND, name), PARENT_RUN_ID)
            sftp = client.open_sftp()
            atomic_put_bytes(client, sftp, body.encode(), wrapper)
            sftp.close()
            client, _ = remote_run_retry(client, "chmod +x %s" % wrapper)
            client, submit = remote_run_retry(
                client,
                "bsub %s -w %s -o %s/logs/gls/%s/sdf_%s.bsub.log "
                "-e %s/logs/gls/%s/sdf_%s.bsub.err -J %s %s"
                % (
                    gls_bsub, shlex.quote("ended(%s)" % stitch_jid),
                    ROOT, PARENT_RUN_ID, name,
                    ROOT, PARENT_RUN_ID, name,
                    shlex.quote(jname), wrapper,
                ),
            )
            gjid = job_id(submit)
            gls_jobs.append(gjid)
            print("HIER_GLS_JOB", name, gjid, flush=True)

    status = {
        "kind": KIND,
        "parent_run_id": PARENT_RUN_ID,
        "top": prep["top"],
        "unique_refs": [job["ref"] for job in prep["jobs"]],
        "child_jobs": child_jids,
        "stitch_job": stitch_jid,
        "gls_jobs": gls_jobs,
        "submit_only": SUBMIT_ONLY,
        "netlist_run_id": PARENT_RUN_ID,
    }
    result_dir = RESULT_ROOT / PARENT_RUN_ID
    result_dir.mkdir(parents=True, exist_ok=True)
    (result_dir / "hier_plan.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    if SUBMIT_ONLY:
        print("HIER_SUBMITTED", PARENT_RUN_ID, flush=True)
        client.close()
        return
    client = wait_job(client, stitch_jid, "hier_stitch", polls=DC_POLLS)
    client, log = remote_run_retry(client, "cat %s %s.err 2>/dev/null" % (stitch_log, stitch_log))
    token = "CMR_NOC64_DC_PASS"
    if prep["large"]:
        token = "CMR_NETWORK_DC_PASS"
    elif prep["top"] == "CMRMeshNoC":
        token = "CMR_MESH64_DC_PASS"
    if token not in log:
        print(log[-16000:], flush=True)
        raise RuntimeError("hierarchical stitch failed for %s" % PARENT_RUN_ID)
    print("HIER_STITCH_PASS", PARENT_RUN_ID, flush=True)
    client.close()


if __name__ == "__main__":
    main()

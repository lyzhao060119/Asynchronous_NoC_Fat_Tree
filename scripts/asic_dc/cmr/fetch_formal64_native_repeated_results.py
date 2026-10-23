#!/usr/bin/env python3
"""Fetch only the compact Native-vs-Repeated CSV evidence from the remote run."""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from run_remote_cmr_noc16_sdf import connect


DEFAULT_REMOTE = (
    "/home/ghy19/Asynchronous_Router_CMR/formal64_native_repeated/"
    "20261019_m16_native_repeated_compact_r4"
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remote", default=DEFAULT_REMOTE)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    client = connect()
    sftp = client.open_sftp()
    fetched: list[tuple[str, Path]] = []
    try:
        for name in ("manifest.json",):
            local = output / name
            sftp.get(f"{args.remote}/{name}", str(local))
            fetched.append((name, local))
        for name in ("case_manifest.csv", "input_manifest.json"):
            try:
                local = output / name
                sftp.get(f"{args.remote}/inputs/{name}", str(local))
                fetched.append((name, local))
            except OSError:
                pass
        for tag in sorted(sftp.listdir(f"{args.remote}/activity")):
            local = output / f"{tag}.csv"
            sftp.get(f"{args.remote}/activity/{tag}/result.csv", str(local))
            fetched.append((tag, local))
    finally:
        sftp.close()
        client.close()

    for label, path in fetched:
        print(f"{label}\t{path.stat().st_size}\t{sha256(path)}")
    result_count = sum(path.name.startswith("PROP_") for _, path in fetched)
    if result_count != 12:
        raise SystemExit(f"FETCH_FAIL result_csv={result_count} expected=12")
    print(f"FETCH_PASS files={len(fetched)} result_csv={result_count} root={output}")


if __name__ == "__main__":
    main()

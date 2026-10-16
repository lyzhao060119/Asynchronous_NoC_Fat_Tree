from __future__ import annotations

import subprocess
from pathlib import Path

from .paths import REPO


def _git(args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=REPO,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def snapshot(repo: Path | None = None) -> dict:
    del repo
    sha = _git(["rev-parse", "HEAD"]) or None
    dirty = bool(_git(["status", "--porcelain"]))
    describe = _git(["describe", "--always", "--dirty"]) or None
    return {"sha": sha, "dirty": dirty, "describe": describe}

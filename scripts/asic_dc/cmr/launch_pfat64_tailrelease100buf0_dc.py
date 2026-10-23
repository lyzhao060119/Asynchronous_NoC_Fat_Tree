"""Submit isolated archive PFAT64 with Tail release DEL100 + BUFFD0."""
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RUNNER = HERE / "run_remote_archive_pfat64.py"
CANDIDATE = HERE / "candidates/pfat_tailrelease100buf0/OPMSelector.v"

def main():
    run = datetime.now().strftime("%Y%m%d_%H%M%S") + "_archive_pfat64_tailrel100buf0_tt_r1"
    env = os.environ.copy()
    env.update({
        "CMR_HIER_STITCH_RUN_ID": run,
        "CMR_ARCHIVE_OPM_SELECTOR_OVERRIDE": str(CANDIDATE),
        "CMR_DESCAL_SUBMIT_ONLY": "1",
        "CMR_HIER_SKIP_GLS": "1",
        "CMR_HIER_CHILD_BATCH_SIZE": "4",
        "CMR_HIER_CHILD_BSUB": "-n 4",
        "CMR_HIER_STITCH_BSUB": "-n 8",
    })
    completed = subprocess.run([sys.executable, str(RUNNER)], cwd=REPO, env=env)
    if completed.returncode:
        raise SystemExit(completed.returncode)
    print("PFAT_TAILREL100BUF0_DC_SUBMITTED", run)

if __name__ == "__main__":
    main()

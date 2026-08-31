import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_fat_tree_noc16_sdf import connect, remote_run

c = connect()
print(
    remote_run(
        c,
        "echo === JOB ===; "
        "bjobs -noheader -o 'jobid stat job_name run_time' 11487401; "
        "echo === LOGS ===; "
        "ls -lt /home/ghy19/Asynchronous_Router_CMR/logs/dc | sed -n '1,12p'; "
        "echo === TAIL ===; "
        "log=$(ls -1t /home/ghy19/Asynchronous_Router_CMR/logs/dc/*.log 2>/dev/null | head -n 20 | "
        "awk '/cmr_noc64/ {print; exit}'); "
        "echo LOG=$log; "
        "tail -n 50 \"$log\" 2>/dev/null; "
        "echo === MARKERS ===; "
        "grep -E 'CMR_NOC64_|Error:|error:|compile_ultra|Beginning Pass' \"$log\" 2>/dev/null | tail -n 40",
    )
)
c.close()

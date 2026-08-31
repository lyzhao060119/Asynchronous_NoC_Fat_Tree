#!/usr/bin/env python3
"""Query available DEL* cells in the remote TSMC28 library.

The result is intentionally small and local: timing/results/wormhole_stage1/
delay_cell_inventory.csv. The script does not copy library files back.
"""
from __future__ import print_function

import csv
import os
import re
import time
from pathlib import Path

import paramiko


P = "/home/ghy19/Asynchronous_Router"
REPO = Path(__file__).resolve().parents[2]
RESULT_DIR = Path(__file__).resolve().parent / "timing" / "results" / "wormhole_stage1"
UNITS = [50, 75, 100, 125, 150, 250]


def get_password():
    if os.environ.get("C1_PASS"):
        return os.environ["C1_PASS"]
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"^[ \t-]*密码[:：][ \t]*(\S+)", text, re.M)
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def connect():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        os.environ.get("C1_HOST", "192.168.2.8"),
        username=os.environ.get("C1_USER", "ghy19"),
        password=get_password(),
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def run(c, cmd):
    _, o, e = c.exec_command(cmd)
    return o.read().decode(errors="replace") + e.read().decode(errors="replace")


def put_text(c, remote, text):
    sftp = c.open_sftp()
    with sftp.file(remote, "w") as f:
        f.write(text)
    sftp.close()


def main():
    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    c = connect()
    try:
        run(c, "mkdir -p {0}/scripts {0}/logs".format(P))
        tcl = r'''
source scripts/tech_t28ss.tcl
set fh [open logs/delay_cell_inventory_dc.csv w]
puts $fh "unit,db_count,db_cells"
foreach unit {50 75 100 125 150 250} {
  set pattern [format "*/DEL%03dD1BWP12T30P140" $unit]
  set cells [get_object_name [get_lib_cells -quiet $pattern]]
  puts $fh "$unit,[llength $cells],[join $cells { }]"
  puts "DELAY_CELL_DB unit=$unit count=[llength $cells] cells=[join $cells { }]"
}
close $fh
exit
'''
        put_text(c, P + "/scripts/query_delay_cells.tcl", tcl)
        launch = run(c, """
cd {P}
source /etc/profile 2>/dev/null || true
module load syn 2>/dev/null || true
export SYNOPSYS=/soft/synopsys/syn/V-2023.12
export PATH=$SYNOPSYS/bin:$PATH
: > logs/query_delay_cells.log
: > logs/query_delay_cells.err
bsub -n 1 -o logs/query_delay_cells.log -e logs/query_delay_cells.err -J async_delay_query dc_shell-t -64 -f scripts/query_delay_cells.tcl
""".format(P=P))
        print(launch.strip())
        for idx in range(18):
            time.sleep(10)
            status = run(c, """
cd {P}
tmp=$(bjobs -J async_delay_query 2>/dev/null | head -3 || true)
if [ -z "$tmp" ]; then echo NO_JOB; else echo "$tmp"; fi
grep -E 'DELAY_CELL_DB|Error|ERROR|Warning' logs/query_delay_cells.log logs/query_delay_cells.err 2>/dev/null | tail -20
""".format(P=P))
            print("=== delay query poll %d ===" % idx)
            print(status[-2000:], flush=True)
            if "NO_JOB" in status and "DELAY_CELL_DB unit=250" in status:
                break

        raw = run(c, """
cd {P}
echo '==verilog=='
for u in 50 75 100 125 150 250; do
  printf "DEL%03d_VERILOG=" "$u"
  grep -c "DEL$(printf "%03d" "$u")D1BWP12T30P140" /process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v 2>/dev/null || true
done
echo '==dc=='
cat logs/delay_cell_inventory_dc.csv 2>/dev/null || true
echo '==logtail=='
tail -80 logs/query_delay_cells.log 2>/dev/null || true
tail -40 logs/query_delay_cells.err 2>/dev/null || true
""".format(P=P))
    finally:
        c.close()

    (RESULT_DIR / "delay_cell_inventory.raw.log").write_text(raw, encoding="utf-8")
    db_counts = {}
    in_dc = False
    for line in raw.splitlines():
        if line.strip() == "==dc==":
            in_dc = True
            continue
        if line.startswith("=="):
            in_dc = False
        if in_dc and re.match(r"^\d+,", line):
            unit, count, cells = line.split(",", 2)
            db_counts[int(unit)] = (int(count), cells)

    verilog_counts = {}
    for m in re.finditer(r"DEL(\d+)_VERILOG=(\d+)", raw):
        verilog_counts[int(m.group(1))] = int(m.group(2))

    csv_path = RESULT_DIR / "delay_cell_inventory.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["unit", "db_count", "verilog_count", "usable", "db_cells"])
        w.writeheader()
        for unit in UNITS:
            db_count, cells = db_counts.get(unit, (0, ""))
            v_count = verilog_counts.get(unit, 0)
            w.writerow({
                "unit": unit,
                "db_count": db_count,
                "verilog_count": v_count,
                "usable": "YES" if db_count > 0 and v_count > 0 else "NO",
                "db_cells": cells,
            })
    print("WROTE", csv_path)
    for unit in UNITS:
        db_count, _ = db_counts.get(unit, (0, ""))
        v_count = verilog_counts.get(unit, 0)
        usable = "YES" if db_count > 0 and v_count > 0 else "NO"
        print("DEL%03d usable=%s db=%d verilog=%d" % (unit, usable, db_count, v_count))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generate a read-only XMR monitor for PROP_temp64 parent-lane handshakes."""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "scripts" / "asic_dc" / "cmr" / "tb_prop_temp64_lane_monitor.sv"
ROOT = "tb_cmr_noc64_async_boundary_failfast.core"
DUT = ROOT + ".g_behavioral_noc_prop_temp.noc.dut.tile"


def main() -> None:
    rows: list[tuple[str, int, int, int, str]] = []
    for level in (1, 2):
        for q in range(4):
            for index in range(4):
                axis = "i" if level == 1 else "k"
                router = f"propL{level}_q{q}_{axis}{index}"
                for lane in range(4):
                    signal = f"{DUT}.{router}.io_outputs_parent_{lane}_HS_Ack"
                    req = f"{DUT}.{router}.io_outputs_parent_{lane}_HS_Req"
                    rows.append((f"count_{level}_{q}_{index}_{lane}", level,
                                 4 * q + index, lane, f"{signal}|{req}"))
    body = [
        "`timescale 1ns/1ps",
        "module tb_prop_temp64_lane_monitor;",
        "  reg [2047:0] lane_csv;",
        "  integer fd;",
    ]
    body.extend(f"  integer {name} = 0;" for name, *_ in rows)
    body.extend([
        "  function automatic in_measurement;",
        "    begin",
        f"      in_measurement = ({ROOT}.running &&",
        f"        ($realtime * 1000.0 >= {ROOT}.measurement_start_ps) &&",
        f"        ($realtime * 1000.0 < {ROOT}.measurement_end_ps));",
        "    end",
        "  endfunction",
    ])
    for name, _, _, _, signals in rows:
        ack, req = signals.split("|")
        body.append(f"  always @({ack}) if (in_measurement() && ({ack} === {req})) {name} = {name} + 1;")
    body.extend([
        "  final begin",
        "    lane_csv = \"prop_temp64_lane_counts.csv\";",
        "    if ($value$plusargs(\"LANE_CSV=%s\", lane_csv)) ;",
        "    fd = $fopen(lane_csv, \"w\");",
        "    $fwrite(fd, \"level,router,parent_lane,accepted_flits\\n\");",
    ])
    for name, level, router, lane, _ in rows:
        body.append(f"    $fwrite(fd, \"{level},{router},{lane},%0d\\n\", {name});")
    body.extend([
        "    $fclose(fd);",
        "    $display(\"CMR_LANE_MONITOR_PASS rows=128 output=%0s\", lane_csv);",
        "  end",
        "endmodule",
        "",
    ])
    OUT.write_text("\n".join(body), encoding="utf-8")
    print(OUT)


if __name__ == "__main__":
    main()

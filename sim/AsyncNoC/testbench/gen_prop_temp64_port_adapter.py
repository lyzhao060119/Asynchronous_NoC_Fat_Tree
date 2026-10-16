#!/usr/bin/env python3
"""Emit packed-port adapters for the legacy PROP and current M16 tree."""
from pathlib import Path

from gen_noc64_port_adapter import emit_module


def main() -> None:
    output = Path(__file__).resolve().parents[1] / "async_prop_temp64_port_adapter.sv"
    legacy = emit_module(16).replace(
        "async_noc64_port_adapter_top16", "async_prop_temp64_port_adapter_top16"
    ).replace("NoC_64nodes dut", "PROP_temp64 dut")
    m16 = emit_module(64).replace(
        "async_noc64_port_adapter_top64", "async_prop_temp64_m16_port_adapter_top64"
    ).replace("NoC_64nodes dut", "PROP_temp64_m16 dut")
    body = legacy + "\n\n" + m16
    output.write_text("`timescale 1ns/1ps\n`default_nettype none\n" + body +
                      "\n`default_nettype wire\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()

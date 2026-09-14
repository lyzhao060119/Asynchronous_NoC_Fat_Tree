#!/usr/bin/env python3
"""Emit a dedicated packed-port adapter for PROP_temp64."""
from pathlib import Path

from gen_noc64_port_adapter import emit_module


def main() -> None:
    output = Path(__file__).resolve().parents[1] / "async_prop_temp64_port_adapter.sv"
    body = emit_module(16).replace(
        "async_noc64_port_adapter_top16", "async_prop_temp64_port_adapter_top16"
    ).replace("NoC_64nodes dut", "PROP_temp64 dut")
    output.write_text("`timescale 1ns/1ps\n`default_nettype none\n" + body +
                      "\n`default_nettype wire\n", encoding="utf-8")
    print(output)


if __name__ == "__main__":
    main()

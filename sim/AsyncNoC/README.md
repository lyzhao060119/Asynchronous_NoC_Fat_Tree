# AsyncNoC 16-node regression

This directory ports the synchronous project's `.case` format, `gen_cases.py`
generator, and AXI-Lite/BRAM simulation style to the asynchronous toggle-handshake
NoC.

## Layout

- `testbench/gen_cases.py` — same VCTM/TAB case generator as SyncNoC
- `testbench/async_hs_port.sv` — toggle Req/Ack sender and receiver
- `testbench/tb_noc16_async.sv` — direct NoC_16nodes testbench
- `async_noc16_axi_bram_wrapper.sv` — AXI-Lite control + per-port TX/RX BRAM wrapper
- `testbench/tb_noc16_async_axi_bram.sv` — AXI/BRAM NoC16 testbench
- `testbench/generated_cases/` — generated `.case` files
- `run_noc16_smoke.tcl` — Vivado xsim AXI smoke script
- `run_noc16_all_cases_vivado.tcl` — Vivado xsim AXI batch regression script
- `summary/` — CSV summaries written by the testbench

## Generate cases

```powershell
cd <repo-root>
python sim/AsyncNoC/testbench/gen_cases.py --suite all --scale validation
```

## Generate RTL

```powershell
cd <repo-root>
sbt "runMain NoC.NoC_16nodes --target-dir generated"
```

## Run one smoke case (Vivado xsim)

```powershell
cd sim/AsyncNoC
vivado -mode batch -source run_noc16_smoke.tcl
```

The AXI/BRAM wrapper uses `AXI_ADDR_WIDTH=20`, `AXI_DATA_WIDTH=32`,
`TX_DEPTH=1024`, and `RX_DEPTH=1024`. The port stride is `0x2000`, so each
port has enough TX/RX address space for the full 1024 entries. This covers
`testbench/generated_cases/VCTM_16/VCTM-MC10-RU-5f-r0p30.case`, whose peak
per-port TX/RX occupancy is 460 flits, and leaves margin for the current
generated validation cases.

`run_noc16_smoke.tcl` uses
`testbench/small_cases/noc16_00_to_33_3flit_smoke.case`, a 3-flit packet from
physical coordinate `(0,0)` to `(3,3)`.

## FPGA Constraints

For synthesis/implementation of the AXI wrapper or raw `NoC_16nodes`, include:

```tcl
read_xdc constraints/async_noc16_axi_fpga.xdc
```

The XDC creates a 50MHz clock (`20ns`) on `s_axi_aclk` or `clock`, protects
`DelayElement` / `Mutex2` LUT structures from optimization, and marks intentional
async feedback nets as legal combinational loops.

## Run batch regression (Vivado xsim)

```powershell
cd <repo-root>
vivado -mode batch -source sim/AsyncNoC/run_noc16_all_cases_vivado.tcl
```

Useful filters:

```powershell
$env:ASYNC_NOC16_CASE_LIST="VCTM-NoMC-1f-r0p02"
$env:ASYNC_NOC16_GROUP_GLOB="VCTM_16"
$env:ASYNC_NOC16_CASE_GLOB="VCTM-NoMC-1f-*"
```

Async primitive profile:

```powershell
$env:ASYNC_PRIMITIVES="sim"   # default RTL functional model
$env:ASYNC_PRIMITIVES="fpga"  # compile synthesizable LUT primitive structures
```

The batch script defaults to the AXI/BRAM platform. To run the older direct
toggle-handshake testbench, set:

```powershell
$env:ASYNC_NOC16_SIM_MODE="direct"
```

## Handshake note

The async DUT uses **toggle** two-phase handshake (`full = Req ^ Ack`). The AXI
wrapper keeps the external simulation interface clocked and synchronous while it
drives the NoC boundary using Req/Ack toggles internally.

With `ASYNC_PRIMITIVES=sim`, CSV latency columns are RTL testbench-time
regression metrics only. Use `docs/async_timing.md` for FPGA timing calibration
and real async delay measurement.

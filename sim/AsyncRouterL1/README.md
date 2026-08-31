# Async RouterL1 directed verification

Single-router acceptance tests aligned with `sim/SyncRouterL1` cases, using toggle (two-phase) handshake in the testbench.

## Prerequisites

```bash
# From repo root — regenerate RTL after Scala changes
sbt "runMain Router_Architecture.instantiation.RouterL1"

# Generate cases (delegates to SyncRouterL1 gen_cases.py)
python sim/AsyncRouterL1/testbench/gen_cases.py --case all
```

## Run

```bash
cd sim/AsyncRouterL1
vivado -mode batch -source run_smoke.tcl    # smoke only
vivado -mode batch -source run_all_cases.tcl # full directed suite
```

The scripts use `ASYNC_PRIMITIVES=sim` by default. Set
`ASYNC_PRIMITIVES=fpga` to compile the synthesizable LUT-based async primitive
models for synthesis-oriented checks.

Or manually with xsim (Windows: use `-f xsim.args` to avoid PowerShell `-testplusarg` parsing):

```bash
cd sim/AsyncRouterL1
xvlog -sv -work work ../../generated/RouterL1.v ../../src/main/resources/ASYNC/DelayElement_sim.v ../../src/main/resources/ASYNC/Mutex2_sim.v testbench/fanin_debug_probe.sv testbench/tb_asyncrouter_l1.sv
xelab -timescale 1ns/1ps work.tb_asyncrouter_l1 -s tb_asyncrouter_l1_sim
xsim tb_asyncrouter_l1_sim -f xsim.args
```

## Layout

| Path | Role |
|------|------|
| `testbench/tb_asyncrouter_l1.sv` | Toggle handshake TB (mirrors sync case format) |
| `testbench/cases/*.case` | Generated directed cases |
| `summary/*.csv` | Per-case metrics |
| `../../generated/RouterL1.v` | Chisel-generated DUT |

## Handshake

- Input driver: wait `Req===Ack`, present data, toggle `Req`, wait completion.
- Output receiver: on `Req!==Ack`, sample flit and toggle `Ack`.

Same `.case` files as sync; stress cases (`mixed`, `random-load`) may need longer `timeout_cycles` in case files for async completion.

## Acceptance status (2026-07-06)

| Case | Result | Notes |
|------|--------|-------|
| smoke_directed | PASS | 9/9 flits |
| e1_basic_unicast | PASS | 12/12 flits |
| fanout_alternating_gap0 | PASS | 24/24 flits |
| hw_multicast_fanout4_gap0 | PASS | 12/12 delivered (3 injected multicast) |
| serial_unicast_fanout4_gap0 | PASS | 12/12 flits |
| fanin_4in_gap0 | PASS | 12/12 flits (4-child concurrent fan-in) |
| mixed_seed1_gap0 | FAIL | 28/36 delivered, 8 missing |
| random_load_seed1_gap0 | FAIL | timeout during inject (33/144) |

Directed unicast / fanout / multicast smoke path is green. Next RTL debug target: **fanin** (multi-input same-cycle launch).

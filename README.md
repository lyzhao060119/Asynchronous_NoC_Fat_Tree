# Asynchronous NoC Fat Tree

Chisel implementation of an asynchronous multicast NoC built from a three-level fat-tree and a top-layer mesh interconnect.

## Overview

This repository contains:

- A hierarchical quadtree-style multicast network built from `RouterL1`, `RouterL2`, and `RouterL3`
- A `TopLayer` mesh that connects multiple quadtree instances into a larger NoC
- Asynchronous handshake-based datapaths using `Req/Ack` channels
- Verilog generation entry points for standalone routers and NoC top levels
- Simulation scripts for both ModelSim/Questa and Vivado `xsim`

The current fork behavior is multicast-oriented: one input flit is held at the source side, multiple selected outputs consume it independently, and the input is released only after all active branches finish.

## Repository Layout

- `src/main/scala/DataStruct`: flit and handshake bundles
- `src/main/scala/Router_Architecture`: router pipeline, routing logic, async primitives
- `src/main/scala/NoC`: top-level NoC compositions
- `src/main/resources/ASYNC`: supporting Verilog async cells
- `sim/testbenches`: HDL testbenches
- `sim/modelsim`: ModelSim/Questa scripts
- `sim/xsim`: Vivado `xsim` scripts
- `sim/work`: generated simulation outputs and logs

## Architecture

### Router hierarchy

- `RouterL1`: leaf router, `childLanes = 1`, `parentLanes = 2`
- `RouterL2`: intermediate router, `childLanes = 2`, `parentLanes = 4`
- `RouterL3`: upper tree router, `childLanes = 4`, `parentLanes = 8`
- `RouterTop`: top mesh router used by `TopLayer`

### Top-level compositions

- `NoC.three_level_quadtree`: one 8x8 tile of 64 cores plus 8 top ports
- `NoC.quadtree_and_mesh`: four `three_level_quadtree` instances connected by `TopLayer`

### Flit format

The packet payload is 22 bits wide:

- bit `21`: `isHead`
- bit `20`: `isTail`
- bits `19:14`: `destX`
- bits `13:8`: `destY`
- bits `7:5`: `copyX`
- bits `4:2`: `copyY`
- bits `1:0`: packet `id`

The handshake interface is `HS_Packet`, which combines `Req/Ack` control with the 22-bit payload.

## Build and Verilog Generation

This project uses:

- Scala `2.13.14`
- Chisel `3.6.1`
- `sbt`

Compile the Scala/Chisel sources:

```powershell
sbt compile
```

Generate Verilog for a single 8x8 quadtree tile:

```powershell
sbt "runMain NoC.three_level_quadtree"
```

Generate Verilog for the quadtree plus top-layer mesh:

```powershell
sbt "runMain NoC.quadtree_and_mesh"
```

Generate Verilog for a standalone L1 router:

```powershell
sbt "runMain Router_Architecture.instantiation.RouterL1"
```

Generated files are written to `generated/`, which is intentionally ignored by Git.

## Simulation

Detailed script locations are listed in [sim/README.md](sim/README.md).

### Vivado xsim

Run the `three_level_quadtree` throughput benchmark in batch mode:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch
```

Open the same design in GUI mode:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode gui
```

`launch.ps1` prints the exact `source` commands for the current machine. In the `xsim` Tcl console, source the wave and benchmark scripts it prints.

### ModelSim / Questa

Available scripts include:

- `sim/modelsim/three_level_quadtree/throughput_3flit.do`
- `sim/modelsim/three_level_quadtree/throughput_wave.do`
- `sim/modelsim/three_level_quadtree/complex_test.do`

There is also a standalone RouterL1 testbench:

- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`

## Measured Benchmark

The current `three_level_quadtree` throughput benchmark uses four concurrent diagonal long-distance unicast flows:

- `0 -> 63`
- `7 -> 56`
- `56 -> 7`
- `63 -> 0`

Each packet contains 3 flits. Measured over a 500 ns window after warmup, the observed aggregate throughput is:

- `2.008 flits/ns`
- `0.664 packets/ns`
- `44.176 bits/ns`

These numbers were reproduced with Vivado `xsim` using the batch script in `sim/xsim/three_level_quadtree`.

## Notes

- `sim/work/` stores simulator outputs and is ignored by Git.
- `generated/` is not tracked; regenerate it locally when needed.
- The repository focuses on source code, generators, and reusable simulation scripts rather than checked-in build artifacts.

## License

This project is released under the MIT License. See [LICENSE](LICENSE).

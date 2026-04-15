# Asynchronous Fat-Tree Multicast NoC

This repository contains Chisel implementations of an asynchronous multicast NoC:

- `NoC.three_level_quadtree`: one 8x8 quadtree tile (64 core ports + 8 top ports)
- `NoC.quadtree_and_mesh`: 2x2 quadtree-tiles connected by `TopLayer`
- `NoC.TopLayer`: standalone top-layer mesh generator (used by the dedicated mesh testbench)

The network uses request/acknowledge handshakes and supports multi-flit unicast and rectangle multicast, including cross-quadtree multicast.

## Current Status

- Quadtree routing suppresses same-tree back-edge re-forwarding to avoid duplicate sends and loops.
- Quadtree root routing supports cross-tree rectangle multicast (partial overlap keeps local fanout and duplicates upward).
- Top-layer routing supports cross-quadtree rectangle spread with ingress-aware duplicate suppression.

## Architecture

- `RouterL1`: leaf router (`childLanes=1`, `parentLanes=2`)
- `RouterL2`: middle router (`childLanes=2`, `parentLanes=4`)
- `RouterL3`: root router (`childLanes=4`, `parentLanes=8`)
- `RouterTop`: top-layer mesh router

## Flit Layout (28 bits)

<<<<<<< HEAD
- `NoC.three_level_quadtree`: one tile with 64 core ports + 8 top ports
- `NoC.quadtree_and_mesh`: 2x2 tile network connected by `TopLayer`

## Flit Layout (28 bits)

=======
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd
- `[27]` `isHead`
- `[26]` `isTail`
- `[25:20]` `y1`
- `[19:14]` `x1`
- `[13:8]` `y0`
- `[7:2]` `x0`
- `[1:0]` packet `id`

Coordinates are global rectangle corners (`(x0,y0)` and `(x1,y1)`), and routing logic normalizes min/max bounds internally.

Definitions: `src/main/scala/DataStruct/Packet.scala`.

<<<<<<< HEAD
Main testbench: `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`  
DUT macro header: `sim/testbenches/three_level_quadtree/three_level_quadtree_dut_inst.vh`

Included regression cases:

- `T1` multi-flit unicast (`core0 -> core63`)
- `T2` multi-flit rectangle multicast (`x2..5, y1..3`)
- `T3` inverted rectangle bounds normalization
- `T4` full-tree multicast (`8x8`)
- `T5` out-of-tree destination routing upward to exactly one top lane
- `T6` top-input downlink multicast to local cores
- `T7` multicast backpressure branch throttling behavior
- `T8` competing multicasts with overlap region
- `T9` unicast contention to the same destination
- `T10` triple-overlap multicast contention (mixed core/top injection)

## Verification Coverage (quadtree_and_mesh_tb)

Main testbench: `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`  
DUT macro header: `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_dut_inst.vh`

Included regression cases:

- `T1` same-tree unicast
- `T2` cross-tree unicast
- `T3` cross-tree rectangle multicast across tile boundaries
- `T4` unicast contention to the same global destination
- `T5` west-boundary PE injection into local core
- `T6` packet-level bubble insertion with concurrent background flow
- `T7` inverted global rectangle bounds normalization
- `T8` triple-rectangle overlap contention (`A-only`, `A+C`, `A+B`, `A+B+C`, `B-only` checks)
- `T9` overlap contention under slow-hotspot backpressure

## Build and Run

Requirements:
=======
## Build Requirements
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd

- Scala `2.13.14`
- `sbt`
- Vivado simulator (`xvlog`, `xelab`, `xsim`)

## Generate RTL

```powershell
sbt "runMain NoC.three_level_quadtree"
sbt "runMain NoC.quadtree_and_mesh"
sbt "runMain NoC.TopLayer"
```

## Run Simulation (Recommended Scripts)

`three_level_quadtree`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode gui
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test multicast
```

`quadtree_and_mesh`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode gui -Regenerate
```

`toplayer_mesh`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode gui
```

Generated Vivado/xsim outputs are placed under `sim/work/xsim/...` instead of the project root.

## Cleanup Generated Artifacts

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes generated webtalk artifacts and cleans legacy root-level Vivado outputs (`.Xil`, `xsim.dir`, logs, backup journals). Legacy root outputs are archived under `sim/work/xsim/archive`.

## Verification Assets

- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv` (`T1..T9`)
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv` (`T1..T5`, includes cross-tree multicast)
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv` (`M1..M6`, includes cross-tree rectangle multicast)
- `sim/xsim/*` for scripted xsim runs

For simulation-specific details, see [sim/README.md](sim/README.md).

## Repository Layout

- `src/main/scala/DataStruct`: packet and handshake definitions
- `src/main/scala/Router_Architecture`: router building blocks and routing logic
- `src/main/scala/NoC`: top-level network generators
- `src/main/resources/ASYNC`: async Verilog cells (`DelayElement`, `Mutex2`, `MrGo`)
- `sim/testbenches`: SystemVerilog testbenches
- `sim/modelsim`: ModelSim/Questa scripts
- `sim/xsim`: Vivado xsim launch/Tcl scripts

## License

MIT. See [LICENSE](LICENSE).

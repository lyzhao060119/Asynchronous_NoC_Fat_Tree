# Asynchronous Fat-Tree Multicast NoC

This repository contains a Chisel implementation of an asynchronous multicast NoC built from:

- a three-level quadtree tile (`NoC.three_level_quadtree`)
- a top mesh connecting multiple tiles (`NoC.quadtree_and_mesh`)
- a standalone top-layer mesh generator for isolated mesh verification (`NoC.TopLayer`)

The design uses request/acknowledge handshakes and supports multi-flit unicast and rectangle multicast, including cross-tile multicast.

## Current Status

- Quadtree routing suppresses same-tree back-edge re-forwarding to avoid duplicate sends and loops.
- Quadtree root routing supports cross-tree rectangle multicast by keeping local fanout while also duplicating upward when needed.
- Top-layer routing supports rectangle spread across multiple quadtree tiles with ingress-aware duplicate suppression.

## Architecture

- `RouterL1`: leaf router (`childLanes=1`, `parentLanes=2`)
- `RouterL2`: middle router (`childLanes=2`, `parentLanes=4`)
- `RouterL3`: root router of one quadtree tile (`childLanes=4`, `parentLanes=8`)
- `RouterTop`: top-layer mesh router

Top-level generators:

- `NoC.three_level_quadtree`: one 8x8 quadtree tile with 64 core ports and 8 top ports
- `NoC.quadtree_and_mesh`: a tile-network generator connected by `TopLayer`; default is 2x2 tiles = 256 cores
- `NoC.TopLayer`: a standalone top mesh used by the dedicated mesh testbench; default is 4x4 tiles

Recommended scale split:

- `256-node` (`2x2` tiles): directed and constrained-random verification
- `1024-node` (`4x4` tiles): paper-scale system simulations

## Flit Layout (28 bits)

- `[27]` `isHead`
- `[26]` `isTail`
- `[25:20]` `y1`
- `[19:14]` `x1`
- `[13:8]` `y0`
- `[7:2]` `x0`
- `[1:0]` packet `id`

Coordinates encode two global rectangle corners, `(x0, y0)` and `(x1, y1)`. Routing logic normalizes min/max bounds internally.

Definitions are in `src/main/scala/DataStruct/Packet.scala`.

## Verification Coverage

`three_level_quadtree_tb`:

- `T1` multi-flit unicast
- `T2` multi-flit rectangle multicast
- `T3` inverted rectangle bounds normalization
- `T4` full-tree multicast
- `T5` out-of-tree destination routing upward
- `T6` top-input downlink multicast to local cores
- `T7` multicast backpressure branch throttling
- `T8` competing multicasts with overlap
- `T9` unicast contention to the same destination
- `T10` triple-overlap multicast contention

`quadtree_and_mesh_tb`:

- `T1` same-tree unicast
- `T2` cross-tree unicast
- `T3` cross-tree rectangle multicast across tile boundaries
- `T4` unicast contention to the same global destination
- `T5` west-boundary PE injection into a local core
- `T6` packet-level bubble insertion with concurrent background flow
- `T7` inverted global rectangle bounds normalization
- `T8` triple-rectangle overlap contention
- `T9` overlap contention under slow-hotspot backpressure

`toplayer_mesh_tb`:

- `M1..M6` rectangle-routing regressions on the standalone top mesh

For simulation-specific usage and the paper-oriented verification plan, see:

- [sim/README.md](sim/README.md)
- [sim/SIMULATION_README.md](sim/SIMULATION_README.md)

## Build Requirements

- Scala `2.13.14`
- Chisel `3.6.1`
- `sbt`
- Vivado simulator tools (`xvlog`, `xelab`, `xsim`) for the scripted flows

## Generate RTL

```powershell
sbt "runMain NoC.three_level_quadtree"
sbt "runMain NoC.quadtree_and_mesh"
sbt "runMain NoC.TopLayer"
sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir generated_1024"
```

Useful scale-selection flags:

- `--verify-256`: force the default 2x2 tile full-NoC build
- `--paper-1024`: switch the full-NoC build to 4x4 tiles
- `--quad-num-x <N> --quad-num-y <M>`: explicitly choose the full-NoC tile array
- `--grid-x <N> --grid-y <M>`: equivalent aliases for the standalone `TopLayer` generator

## Run Simulation

Recommended scripted runs:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test multicast
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_rand_suite.ps1 -Cases 24 -MaxPkts 3
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern uniform_unicast -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern cross_tile_unicast -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern hotspot_unicast -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern uniform_multicast -NumFlows 1 -RectW 4 -RectH 4 -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern mixed_unicast_multicast -NumFlows 4 -RectW 4 -RectH 4 -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -Mode batch -Pattern overlapping_multicast -NumFlows 4 -RectW 4 -RectH 4 -PacketGapNs 20 -WarmupNs 20000 -MeasureNs 50000
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_suite.ps1 -Pattern uniform_unicast -PacketGapsCsv "0,10,20,40" -SeedsCsv "12345,22345"
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_rect_sweep.ps1 -Pattern uniform_multicast -RectSizesCsv "1,2,4,8,16" -SeedsCsv "12345,22345"
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf_ack_sweep.ps1 -Pattern uniform_multicast -AckDelaysCsv "1,5,10,20" -SeedsCsv "12345,22345"
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode batch
```

Generated Vivado outputs are placed under `sim/work/xsim/...` instead of the repository root.

Performance CSVs emitted by `run_perf.ps1` / `run_perf_suite.ps1` include both head-to-head latency and packet completion latency, which makes the results easier to use directly in paper plots.

## Cleanup Generated Artifacts

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes generated webtalk artifacts and cleans legacy root-level Vivado outputs (`.Xil`, `xsim.dir`, logs, backup journals). Legacy root outputs are archived under `sim/work/xsim/archive`.

## Repository Layout

- `src/main/scala/DataStruct`: packet and handshake definitions
- `src/main/scala/Router_Architecture`: router building blocks and routing logic
- `src/main/scala/NoC`: top-level network generators
- `src/main/resources/ASYNC`: async Verilog cells (`DelayElement`, `Mutex2`, `MrGo`)
- `sim/testbenches`: SystemVerilog testbenches
- `sim/modelsim`: ModelSim/Questa scripts
- `sim/xsim`: Vivado xsim launch and Tcl scripts
- `sim/work`: generated simulator outputs

## License

MIT. See [LICENSE](LICENSE).

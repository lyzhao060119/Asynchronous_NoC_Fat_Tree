# Asynchronous Fat-Tree Multicast NoC

Chinese version: [README.zh-CN.md](README.zh-CN.md)

This repository contains a Chisel implementation of an asynchronous multicast NoC built from:

- a three-level quadtree tile (`three_level_quadtree`)
- a top mesh connecting multiple tiles (`quadtree_and_mesh`)

The design uses request/acknowledge handshakes and supports multi-flit unicast and rectangle multicast.

## Current Status

Recent fixes completed in this branch:

- Routing now uses ingress direction suppression inside the same tree to avoid back-edge re-forwarding (duplicate sends / loops during multicast contention).
- Level-1 local-injection exception is preserved so local destinations are still reachable.
- The `three_level_quadtree` SystemVerilog testbench monitor was rewritten to non-blocking delayed-ACK scheduling (`pending + fork/join_none`) to avoid missed flit counting.

## Architecture

- `RouterL1`: leaf router (`childLanes=1`, `parentLanes=2`)
- `RouterL2`: middle router (`childLanes=2`, `parentLanes=4`)
- `RouterL3`: root router of one quadtree tile (`childLanes=4`, `parentLanes=8`)
- `RouterTop`: top-layer mesh router

Top-level generators:

- `NoC.three_level_quadtree`: one tile with 64 core ports + 8 top ports
- `NoC.quadtree_and_mesh`: 4x4 tile network connected by `TopLayer`

## Flit Layout (22 bits)

- `[21]` `isHead`
- `[20]` `isTail`
- `[19:16]` `treeId` (top mesh tree index)
- `[15:13]` `xMin`
- `[12:10]` `xMax`
- `[9:7]` `yMin`
- `[6:4]` `yMax`
- `[3:2]` reserved
- `[1:0]` packet `id`

Definitions are in `src/main/scala/DataStruct/Packet.scala`.

## Verification Coverage (three_level_quadtree_tb)

Main testbench: `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`  
DUT macro header: `sim/testbenches/three_level_quadtree/three_level_quadtree_dut_inst.vh`

Included regression cases:

- `T1` multi-flit unicast (`core0 -> core63`)
- `T2` multi-flit rectangle multicast (`x2..5, y1..3`)
- `T3` inverted rectangle bounds normalization
- `T4` full-tree multicast (`8x8`)
- `T5` tree-id mismatch routing upward to exactly one top lane
- `T6` top-input downlink multicast to local cores
- `T7` multicast backpressure branch throttling behavior
- `T8` competing multicasts with overlap region
- `T9` unicast contention to the same destination

## Build and Run

Requirements:

- Scala `2.13.14`
- Chisel `3.6.1`
- `sbt`
- Vivado `xsim` (for the commands below)

Generate Verilog:

```powershell
sbt "runMain NoC.three_level_quadtree"
```

Compile and run the main regression:

```powershell
xvlog -sv -i sim/testbenches/three_level_quadtree generated/three_level_quadtree.v sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv
xelab --timescale 1ns/1ps three_level_quadtree_tb -s three_level_quadtree_tb_sim
xsim three_level_quadtree_tb_sim -runall
```

Expected pass banner:

```text
[TB] all three_level_quadtree tests PASSED
```

You can also use helper scripts under `sim/xsim/three_level_quadtree` and details in [sim/README.md](sim/README.md).

## Repository Layout

- `src/main/scala/DataStruct`: packet and handshake definitions
- `src/main/scala/Router_Architecture`: router blocks and routing logic
- `src/main/scala/NoC`: top-level NoC compositions
- `src/main/resources/ASYNC`: async Verilog cells (`DelayElement`, `Mutex2`, etc.)
- `sim/testbenches`: SystemVerilog testbenches
- `sim/modelsim`: ModelSim/Questa scripts
- `sim/xsim`: Vivado xsim scripts

## License

MIT. See [LICENSE](LICENSE).

Simulation files are organized by role:

- `sim/testbenches`: reusable SystemVerilog testbenches and helper scripts
- `sim/modelsim`: ModelSim/Questa `.do` scripts
- `sim/xsim`: Vivado `xsim` PowerShell/Tcl launch scripts (grouped by DUT)
- `sim/work`: generated simulator outputs (libraries, logs, waves, temp artifacts)

## Key Testbenches

- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`
- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/toplayer_mesh/toplayer_mesh_tb.sv`

## Vivado xsim Usage

`three_level_quadtree`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode gui
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test multicast
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput -Regenerate
```

`quadtree_and_mesh`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/launch.ps1 -Mode gui -Regenerate
```

`toplayer_mesh`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode gui -Regenerate
```

All launchers execute in `sim/work/xsim/<target>`, keeping generated Vivado outputs out of the repository root.

## Script Notes

- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`: 4 unicast flows with throughput and latency summary.
- `sim/xsim/three_level_quadtree/multicast_rect_smoke.tcl`: 2x2 rectangle multicast smoke test.
- `sim/xsim/quadtree_and_mesh/run_all.tcl`: run to completion and quit for quadtree+mesh batch flow.
- `sim/xsim/toplayer_mesh/run_all.tcl`: run to completion and quit for top-layer mesh batch flow.

## Cleanup

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes generated webtalk artifacts and cleans legacy root-level Vivado files (`.Xil`, `xsim.dir`, logs, backup journals, root `.wdb`). Legacy root outputs are archived under `sim/work/xsim/archive`.

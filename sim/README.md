Simulation files are organized by role:

- `sim/testbenches`: reusable HDL testbenches
- `sim/modelsim`: ModelSim/Questa `.do` scripts
- `sim/xsim`: Vivado `xsim` Tcl and launch scripts
- `sim/work`: generated simulator outputs, logs, libraries, wave databases

Current files:

- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`
- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/modelsim/three_level_quadtree/complex_test.do`
- `sim/modelsim/three_level_quadtree/throughput_3flit.do`
- `sim/modelsim/three_level_quadtree/throughput_wave.do`
- `sim/xsim/three_level_quadtree/launch.ps1`
- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`
- `sim/xsim/three_level_quadtree/multicast_rect_smoke.tcl`
- `sim/xsim/three_level_quadtree/throughput_wave.tcl`

Vivado usage:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode gui
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test multicast
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch -Test throughput -Regenerate
```

`launch.ps1` runs `xvlog/xelab/xsim` inside `sim/work/xsim/three_level_quadtree`, so Vivado outputs no longer clutter the project root.

Notes:

- `throughput_3flit.tcl`: 4 unicast flows (new packet format: `treeId + rectangle`) with throughput and head-to-head latency summary.
- `multicast_rect_smoke.tcl`: one 2x2 rectangle multicast smoke test (expects delivery to 4 destinations only).

Cleanup:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes `webtalk`/`.Xil` artifacts and root-level legacy Vivado logs, and archives legacy xsim workspace under `sim/work/xsim/archive/root_legacy` when present.

Vivado New Project (GUI) with HDL testbench:

1. Add design sources:
   - `generated/three_level_quadtree.v`
   - `src/main/resources/ASYNC/DelayElement.v`
   - `src/main/resources/ASYNC/MrGo.v`
   - `src/main/resources/ASYNC/Mutex2.v`
2. Add simulation source:
   - `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
3. Set simulation top:
   - `three_level_quadtree_tb`
4. Run Behavioral Simulation.

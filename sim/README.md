Simulation files are organized by role:

- `sim/testbenches`: reusable HDL testbenches
- `sim/modelsim`: ModelSim/Questa `.do` scripts
- `sim/xsim`: Vivado `xsim` Tcl and launch scripts
- `sim/work`: generated simulator outputs, logs, libraries, wave databases

Current files:

- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`
- `sim/modelsim/three_level_quadtree/complex_test.do`
- `sim/modelsim/three_level_quadtree/throughput_3flit.do`
- `sim/modelsim/three_level_quadtree/throughput_wave.do`
- `sim/xsim/three_level_quadtree/launch.ps1`
- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`
- `sim/xsim/three_level_quadtree/throughput_wave.tcl`

Vivado usage:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode gui
powershell -ExecutionPolicy Bypass -File sim/xsim/three_level_quadtree/launch.ps1 -Mode batch
```

`launch.ps1` runs `xvlog/xelab/xsim` inside `sim/work/xsim/three_level_quadtree`, so Vivado outputs no longer clutter the project root.

Simulation files are organized by role:

- `sim/testbenches`: reusable SystemVerilog testbenches and helper scripts
- `sim/modelsim`: ModelSim/Questa `.do` scripts
- `sim/xsim`: Vivado `xsim` PowerShell/Tcl launch scripts grouped by DUT
- `sim/work`: generated simulator outputs, logs, waves, and temporary artifacts

If you are planning verification for a paper or thesis, use [SIMULATION_README.md](SIMULATION_README.md) as the main methodology guide. This file focuses on day-to-day script usage.

## Key Testbenches

- `sim/testbenches/routerl1/routerl1_three_flit_packet_tb.sv`
- `sim/testbenches/three_level_quadtree/three_level_quadtree_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_tb.sv`
- `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_tb.sv`
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
powershell -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_rand.ps1 -Mode batch -Seed 12345 -Cases 24 -MaxPkts 3
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
```

`toplayer_mesh`:

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode batch
powershell -ExecutionPolicy Bypass -File sim/xsim/toplayer_mesh/launch.ps1 -Mode gui -Regenerate
```

All launchers execute inside `sim/work/xsim/<target>`, which keeps generated Vivado outputs out of the repository root.

## Script Notes

- `sim/xsim/three_level_quadtree/throughput_3flit.tcl`: 4 unicast flows with throughput and head-to-head latency summary
- `sim/xsim/three_level_quadtree/multicast_rect_smoke.tcl`: one 2x2 rectangle multicast smoke test
- `sim/xsim/quadtree_and_mesh/run_all.tcl`: run-to-completion batch flow for the full quadtree+mesh DUT
- `sim/xsim/quadtree_and_mesh/run_rand.ps1`: single-seed constrained-random correctness regression
- `sim/xsim/quadtree_and_mesh/run_rand_suite.ps1`: multi-seed constrained-random correctness sweep with CSV/log output under `sim/results/simulation`
- `sim/xsim/quadtree_and_mesh/run_perf.ps1`: single-point performance run with CSV/log output under `sim/results/simulation`; reports head latency and packet completion latency
- `sim/xsim/quadtree_and_mesh/run_perf_suite.ps1`: multi-gap and multi-seed performance sweep that consolidates child CSV rows; use `-SeedsCsv` and `-PacketGapsCsv` when launching from `powershell -File ...`
- `sim/xsim/quadtree_and_mesh/run_perf_rect_sweep.ps1`: multi-seed rectangle-size sweep for multicast traffic patterns
- `sim/xsim/quadtree_and_mesh/run_perf_ack_sweep.ps1`: multi-seed ack-delay sweep for latency and throughput sensitivity studies
- `sim/xsim/toplayer_mesh/run_all.tcl`: run-to-completion batch flow for the standalone top mesh DUT

## Cleanup

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes generated webtalk artifacts and cleans legacy root-level Vivado files (`.Xil`, `xsim.dir`, logs, backup journals, root `.wdb`). Legacy root outputs are archived under `sim/work/xsim/archive`.

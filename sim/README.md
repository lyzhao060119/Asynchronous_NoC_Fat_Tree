Simulation files are organized by role:

- `sim/testbenches`: reusable SystemVerilog testbenches and helper scripts
- `sim/modelsim`: ModelSim/Questa `.do` scripts and PowerShell wrappers
- `sim/xsim`: Vivado `xsim` PowerShell/Tcl launch scripts grouped by DUT
- `sim/work`: generated simulator outputs, logs, waves, and temporary artifacts

If you are planning verification for a paper or thesis, use [SIMULATION_README.md](SIMULATION_README.md) as the main methodology guide. This file focuses on day-to-day script usage.
If you want the final locked Chinese experiment plan with fixed traffic patterns, measurement parameters, and the synchronous baseline requirement, use [FINAL_EXPERIMENT_GUIDE_CN.md](FINAL_EXPERIMENT_GUIDE_CN.md).
If you want the dedicated Chinese addendum for power, batch-size studies, synchronous counterpart fairness, and multicast algorithm baselines, use [POWER_AND_BASELINE_GUIDE_CN.md](POWER_AND_BASELINE_GUIDE_CN.md).
If you want the paper-derived initialization checklist and the step-by-step simulation protocol that maps the cited papers onto this repository, use [PAPER_DERIVED_SIMULATION_PROTOCOL_CN.md](PAPER_DERIVED_SIMULATION_PROTOCOL_CN.md).

Current scale convention:

- `NoC.quadtree_and_mesh` defaults to `2x2` tiles (`256` total cores) and is the regression target for Level 1/2 verification.
- `NoC.TopLayer` defaults to `4x4` tiles and matches the standalone top-mesh testbench.
- For paper-scale full-NoC runs, regenerate the DUT with `sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir generated_1024"` and point future scripts to that output.

Current simulator convention:

- `256-node + ModelSim` is the default path for Level 1/2 verification, the Level 3.1 single-point smoke, and early script bring-up for Level 3.2/3.4.
- `1024-node + xsim` is the default path for final Level 3.1 latency-throughput curves, final Level 3.2 multicast scaling, Level 3.3 workloads, and scale-sensitive Level 3.4 studies.
- On the current machine, `ModelSim Intel FPGA Edition 2020.1` can compile the `1024-node` light performance testbench but fails during `vsim` design load with a memory allocation error, so it is not the default `1024-node` execution path.

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

## Vivado GUI Manual Run For 1024 Perf

If you want to debug the `1024-node` lightweight performance testbench manually in Vivado GUI, first prepare the GUI-editable headers without launching the simulator:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/xsim/quadtree_and_mesh/run_perf.ps1 -PrepareOnly -Pattern uniform_unicast -NumFlows 1 -PacketGapNs 20 -AckDelayNs 1 -EdgeN 4 -GeneratedDirName generated -WarmupNs 100 -MeasureNs 200
```

After that:

- Edit `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_cfg.vh` if you want to change pattern, timeout, or lock `flow0` to a fixed `(src_q, src_c) -> (dst_q, dst_c)` case.
- The preparation step auto-detects the actual DUT shape from `generated/quadtree_and_mesh.sv`, so the recommended simulation top may be `quadtree_and_mesh_perf_tb` or `quadtree_and_mesh_perf_1024_light_tb` depending on what is really in `generated/`.
- Add these files as simulation sources in Vivado GUI:
  `generated/quadtree_and_mesh.sv`
  `src/main/resources/ASYNC/MrGo.v`
  `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_1024_light_tb.sv`
  `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_perf_cfg.vh`
  `sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_dut_inst.vh`
  `sim/testbenches/quadtree_and_mesh/layers-quadtree_and_mesh-Verification.sv`
- Add include directories:
  `generated`
  `sim/testbenches/quadtree_and_mesh`
- Set simulation top to `quadtree_and_mesh_perf_1024_light_tb`.

All launchers execute inside `sim/work/xsim/<target>`, which keeps generated Vivado outputs out of the repository root.

## ModelSim Usage

`quadtree_and_mesh` 3.1 smoke:

```powershell
powershell -ExecutionPolicy Bypass -File sim/modelsim/quadtree_and_mesh/run_perf_smoke.ps1
powershell -ExecutionPolicy Bypass -File sim/modelsim/quadtree_and_mesh/run_perf_smoke.ps1 -Mode gui
```

This wrapper is intentionally scoped to the verified `256-node + uniform_unicast` single-point smoke. It generates temporary `quadtree_and_mesh_perf_cfg.vh` and `quadtree_and_mesh_dut_inst.vh` files under `sim/work/modelsim/...`, passes that include directory before `sim/testbenches/quadtree_and_mesh`, and leaves the repo-tracked headers untouched.

## Remote Server Usage

For remote servers, prefer batch simulation instead of GUI:

- Keep the server flow headless and run `run_perf.ps1`, `run_rand.ps1`, or `launch.ps1` inside `tmux`/`screen`.
- Use a fast local scratch directory for temporary Vivado files via `-RunRoot`, instead of writing large `xelab/xsim` artifacts into the repo.
- Generate the DUT once, then reuse the same generated directory for multiple seeds and traffic points.
- Copy back only the CSV and raw log files under `sim/results/simulation`, instead of the full simulator work directory.

If the remote server is Linux and does not have PowerShell, keep the same file set and launch `xvlog/xelab/xsim` directly with the same top module and include directories listed above.

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
- `sim/modelsim/quadtree_and_mesh/run_perf_smoke.ps1`: `256-node` ModelSim smoke for Level 3.1; emits a one-row summary CSV and uses temporary include headers under `sim/work/modelsim`
- `sim/xsim/toplayer_mesh/run_all.tcl`: run-to-completion batch flow for the standalone top mesh DUT

## Cleanup

```powershell
powershell -ExecutionPolicy Bypass -File sim/xsim/cleanup_outputs.ps1
```

This removes generated webtalk artifacts and cleans legacy root-level Vivado files (`.Xil`, `xsim.dir`, logs, backup journals, root `.wdb`). Legacy root outputs are archived under `sim/work/xsim/archive`.

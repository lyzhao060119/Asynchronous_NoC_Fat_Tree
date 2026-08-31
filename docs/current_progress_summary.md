# Current Project Progress Summary

Last updated: 2026-07-24

This document is the clean high-level checkpoint for the current async NoC work.
Detailed historical logs remain in `docs/gls_post_synth_progress.md`,
`docs/async_timing.md`, and `docs/noc16_remote_post_synth_chain.md`.
For a hardware-oriented description of Router handshake domains, data paths,
control paths, and cross-domain control signals, see
`docs/router_handshake_domains.md`.
For the agreed timing optimization roadmap toward `<2ns` and then `<1.5ns`,
see `docs/router_timing_optimization_plan.md`.

## 1. Current Stable Baseline

The current RouterL1 baseline is `P100_FIFO_ONLY`:

- ASIC primitive profile: `ASYNC_PRIMITIVES=asic`
- Delay profile: `ASYNC_DELAY_PROFILE=P100_FIFO_ONLY`
- Delay mapping: FIFO `Dfire` uses `DEL100`; all other accepted RouterL1
  handshake delay roles remain `DEL150`.
- RouterL1 DC result: `GTECH=0`, `DEL100=12`, `DEL150=49`.
- RouterL1 SDF GLS smoke: PASS, 9/9 delivered.
- RouterL1 direct DUT-boundary head flit E2E: `E2E_EDGE_REQ/VALID_NS=2.147ns`.

This is currently the fastest passing RouterL1 SDF profile. More aggressive
profiles that lowered OPM/context/priority or other forward domains to `DEL100`
failed RouterL1 SDF smoke with one missing flit.

## 2. NoC16 Post-Synthesis Chain

The NoC16 remote post-synthesis chain has been brought up:

- Remote project root: `~/Asynchronous_Router`
- DC outputs: `outputs/NoC_16nodes_post.v`,
  `outputs/NoC_16nodes_dc.sdf`, `outputs/NoC_16nodes.ddc`,
  `outputs/NoC_16nodes_dc.sdc`
- Full gate-level SDF smoke: PASS on `noc16_00_to_33_3flit_sdf.case`
- Wrapper-observed `T_noc` is not the precise async path delay because it
  includes testbench sampling/wrapper latency.
- Direct DUT-boundary NoC16 probe result on the existing NoC16 netlist:
  `E2E_EDGE_REQ_NS=30.635ns`, `E2E_EDGE_VALID_NS=30.635ns`.

Power is also working with a project-local PrimeTime PX time-based VCD flow:

- Script: `scripts/asic_dc/power/run_ptpx_noc16_power.tcl`
- VCD: `logs/noc16_sdf_smoke.vcd`
- Smoke window: `150ns-350ns`
- Total power: `3.494e-03 W`
- Net switching: `6.178e-06 W`
- Cell internal: `4.915e-05 W`
- Cell leakage: `3.439e-03 W`

The reference script at
`/home/zhangjl19/ANPX/Nature_Sim/PowerSim/power.tcl` was not modified.

## 3. RouterL1 Delay Profile Scan

Remote RouterL1 SDF profile results:

| Profile | DEL100 roles | SDF result | Direct E2E |
|---------|--------------|------------|------------|
| `P150_BASELINE` | none | PASS 9/9 | `2.226ns` |
| `P100_FIFO_ONLY` | FIFO `Dfire` | PASS 9/9 | `2.147ns` |
| `P100_FORWARD_SHORT` | FIFO + OPM `Dfire` | FAIL, delivered 8/9 | first flit `2.066ns` |
| `P100_SHORT_ONLY` | FIFO/OPM/context/priority short roles | FAIL, delivered 8/9 | first flit `2.066ns` |

Conclusion: lowering delay cells globally or broadly is not safe. The accepted
route is per-domain delay sizing, with `P100_FIFO_ONLY` as the stable point.
Further RouterL1 E2E improvement should come from reducing the long reqGen
control cone, not from blindly shrinking more DelayElements.

## 4. ReqGen Timing Hotspot

A dedicated current-DDC STA report was added:

- Wrapper: `scripts/asic_dc/run_dc_r1_reqgen_segments.py`
- Tcl: `scripts/asic_dc/timing/run_dc_routerl1_reqgen_segment_timing.tcl`
- Local results: `scripts/asic_dc/timing/results/reqgen_segment_*`
- Remote results: `~/Asynchronous_Router/reports/RouterL1/reqgen_segment_*`

Current `P100_FIFO_ONLY` DDC results:

| Segment | Delay | Status |
|---------|------:|--------|
| selector flit register to reqGen launch `DEL/I` | `0.980ns` | OK |
| selector flit register to `ipm/control/io_destMask_0_*` | `0.940ns` | OK |
| selector flit register to `ipm/control/io_canLaunch_0` | `0.980ns` | OK |
| `routeSelector/currentDestVec`, `requestMask`, `eligibility` sub-boundaries | N/A | optimized away in final DDC |

The detailed report shows the longest path starts at
`ipm/inputPorts_0_datapath_selector_outBuffer_outReg_flit_reg_3_/Q`, enters
`ipm/control/io_inBits_0_flit[3]`, passes through a long `InputControlModule`
gate cone, reaches `ipm/control/io_destMask_0_2` around `0.88-0.94ns`, reaches
`ipm/control/io_canLaunch_0` around `0.96ns`, then enters the reqGen launch
DelayElement input around `0.98ns`.

Conclusion: the last `canLaunch -> launchPulse` gate is not the real hotspot.
The hotspot is upstream inside `InputControlModule`, especially route/dest-mask
and lane-mask construction before `io_destMask`.

## 5. Recommended Next Work

Immediate RTL optimization target:

1. Read and optimize `InputControlModule` and its control helpers with focus on
   destination-mask generation, lane reservation fan-in, and repeated route/mask
   construction.
2. Keep `P100_FIFO_ONLY` as the reference delay profile during optimization.
3. After each meaningful RTL change, regenerate RouterL1, run local Vivado
   directed smoke, then run remote RouterL1 DC + SDF GLS + reqGen STA.
4. Only after RouterL1 improves and passes SDF should NoC16 be regenerated and
   re-synthesized with the updated RouterL1 RTL.

If exact attribution across Chisel submodules is needed, create a separate
timing-only DC build with hierarchy preservation or `dont_touch` on
`routeSelector`, `laneReservation`, `requestMask`, and `eligibility`. Do not use
that analysis build as the signoff SDF netlist.

## 6. Command Record

Generate RouterL1 RTL with the current stable ASIC profile:

```powershell
$env:ASYNC_PRIMITIVES='asic'
$env:ASYNC_DELAY_PROFILE='P100_FIFO_ONLY'
sbt "runMain Router_Architecture.instantiation.RouterL1"
```

Run RouterL1 delay profile sweep on the remote server:

```powershell
$env:C1_PASS='<remote-password>'
python scripts/asic_dc/run_routerl1_delay_profile_sweep.py P150_BASELINE P100_FIFO_ONLY
```

Run RouterL1 combo budget STA:

```powershell
$env:C1_PASS='<remote-password>'
python scripts/asic_dc/run_dc_r1_combo_budget.py
```

Run RouterL1 reqGen segmented STA:

```powershell
$env:C1_PASS='<remote-password>'
python scripts/asic_dc/run_dc_r1_reqgen_segments.py
```

Run RouterL1 SDF GLS with DUT-boundary E2E probe:

```powershell
$env:C1_PASS='<remote-password>'
python scripts/asic_dc/upload_and_run_gls_smoke.py sdf_routerl1_probe
```

Run NoC16 SDF GLS with DUT-boundary E2E probe:

```powershell
$env:C1_PASS='<remote-password>'
python scripts/asic_dc/upload_and_run_gls_smoke.py sdf_noc16_probe
```

Run NoC16 SDF GLS with VCD for PrimeTime PX:

```powershell
$env:C1_PASS='<remote-password>'
$env:GLS_DUMP_VCD='1'
python scripts/asic_dc/upload_and_run_gls_smoke.py sdf_noc16
```

## 7. Stage-A A1/A2 Attempt, 2026-07-24

Goal: keep `P100_FIFO_ONLY`, do not merge/split handshake domains, and reduce
RouterL1 DUT-boundary head E2E from `2.147ns` to below `2.0ns`.

Implemented safe parts:

- `MulticastRequestMaskModule` A2 rewrite:
  - build `headWantedMask(i)(o)` directly from the unique physical output
    reverse mapping `dirOfPhys(o)` / `laneOfPhys(o)`;
  - share a per-port zero mask;
  - replace the `when / elsewhen / otherwise` destination-mask assignment with
    `Mux(useHead, headWantedMask, Mux(useStore, storedMask, zeroMask))`.
- `InputEligibilityModule` keeps the higher-priority-head guard. The proposed
  A1 removal was tried and reverted because it is not yet protocol-safe for the
  existing interleaved traffic stress case.
- `sim/AsyncRouterL1/run_all_cases.tcl` now supports:
  - `ASYNC_ROUTERL1_CASE_LIST='caseA,caseB'`
  - `ASYNC_ROUTERL1_CASE_GLOB='pattern*.case'`
- `run_dc_routerl1_reqgen_segment_timing.tcl` now also emits per-bit
  `destMask_0_[0..5]` reports and top50 timing reports.

Local functional checks:

```powershell
$env:ASYNC_PRIMITIVES='sim'
$env:ASYNC_DELAY_PROFILE='P100_FIFO_ONLY'
sbt "runMain Router_Architecture.instantiation.RouterL1"

$env:ASYNC_PRIMITIVES='sim'
$env:ASYNC_ROUTERL1_CASE_LIST='smoke_directed,hw_multicast_fanout4_gap0,fanin_4in_gap0,random_load_seed1_gap0'
vivado -mode batch -source run_all_cases.tcl
```

Result: the four selected RouterL1 cases passed.

`mixed_seed1_gap0` is still failing in local Vivado both before and after the
A2 mask rewrite (`injected_flits=30`, `delivered_flits=29`, `missing=7`,
`timeout=1`). Treat it as a separate existing stress-case/debug item, not as
evidence that A2 changed behavior.

NoC16 local check:

```powershell
$env:ASYNC_PRIMITIVES='sim'
$env:ASYNC_DELAY_PROFILE='P100_FIFO_ONLY'
sbt "runMain NoC.NoC_16nodes"

$env:ASYNC_NOC16_CASE_LIST='VCTM-MC5-NM-5f-r0p02'
vivado -mode batch -source sim/AsyncNoC/run_noc16_all_cases_vivado.tcl
```

Result: PASS, `injected_flits=5000`, `delivered_flits=5550`, `missing=0`,
`timeout=0`.

Remote signoff commands used:

```powershell
$env:ASYNC_PRIMITIVES='asic'
$env:ASYNC_DELAY_PROFILE='P100_FIFO_ONLY'
sbt "runMain Router_Architecture.instantiation.RouterL1"
sbt "runMain NoC.NoC_16nodes"

$env:C1_PASS='<remote-password>'
python scripts/asic_dc/remote_upload_and_run.py upload
python scripts/asic_dc/run_dc_r1_only.py
python scripts/asic_dc/upload_and_run_gls_smoke.py sdf_routerl1_probe
python scripts/asic_dc/run_dc_r1_combo_budget.py
python scripts/asic_dc/run_dc_r1_reqgen_segments.py
```

Remote RouterL1 DC result:

- `INFO: async RouterL1 DC complete`
- final `GTECH=0`
- DEL profile unchanged: `DEL100=12`, `DEL150=49`, `DEL075=0`, `DEL250=0`
- outputs updated at remote
  `~/Asynchronous_Router/outputs/RouterL1_post.v`,
  `RouterL1.ddc`, `RouterL1_dc.sdc`, `RouterL1_dc.sdf`.

Remote RouterL1 SDF GLS probe result:

- `TB_RESULT PASS case=smoke_directed_sdf`
- `E2E_EDGE_REQ_NS=2.147`
- `E2E_EDGE_VALID_NS=2.147`
- `E2E_WRAPPED_NS=59.000`

Conclusion: A2 is functionally safe on the selected checks but does not reduce
the post-synthesis SDF edge E2E. The `<2ns` Stage-A target is not yet reached.

New STA evidence:

- `combo_budget_bypass.csv` remains:
  - `reqgen_launchPulse = 0.980ns`
  - `vc_arbiter_Dfire = 0.340ns`
  - `demux_launchPulse = 0.220ns`
- `reqgen_segment_destmask_bits.csv`:
  - `destMask_0_0..3 = 0.940ns`
  - `destMask_0_4 = 0.930ns`
  - `destMask_0_5 = 0.940ns`
- top50 reports show the critical path reaches `ipm/control/io_destMask_0_2`
  around `0.88ns`, then `OR3/OR4` builds `io_canLaunch_0` around `0.96ns`,
  and the final `canLaunch -> launch DEL/I` gate adds only about `0.02ns`.

Updated hotspot judgment: the current bottleneck is the flattened
`InputControlModule` route/lane/head-eligibility cone feeding `destMask` and
`canLaunch`, not the final launch gate and not a single destMask bit.

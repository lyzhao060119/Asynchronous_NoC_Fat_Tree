# CMR Router primitive P&R (archived)

Phase 1 of DATE V3.0.2 **closed as FAIL**. DATE V3 does **not** place-and-route
Router primitives or networks. This directory is an archived record plus recovery
scripts; the experiment orchestrator must not invoke it.

## Freeze (2026-08-31)

`locked_tool.json` is frozen to **`physical_class: post-synthesis`**.

ICC2 and Innovus **licenses work** on LSF. Import/place/route does **not**: the TSMC 28HPC+ digital kit has cell LEF + MW FRAM + GDS + CCS, but **no technology LEF / `.tf` / NDM**. Cell LEF goes SITE → MACRO with no LAYER table; pins name M1. ICC classic (`Galaxy-ICC`) is not licensed, so `generate_frame_from_mw` cannot export MW FRAM. Thin `(1,1)` ICC2 and Innovus import both failed; place/route never started.

Paper numbers must be labelled **post-synthesis calibrated** (DC + MAXIMUM SDF). Do not write post-layout. Lifting this freeze is **out of DATE V3 scope** (would need a TSMC APR/PRTF kit and a new project, not a V3 Phase).

| File | Role |
|---|---|
| `locked_tool.json` | Frozen decision + PDK paths + blocker |
| `pilot_gate_report.json` | Pilot evidence vs §20.4 checklist |
| `tech_t28hpc_pnr.tcl` | TSMC 28HPC+ `tcbn28hpcplusbwp12t30p140` LEF/MW/CCS/QRC discovery |
| `async_preserve.tcl` | Dont-touch DelayElement, Mutex, Muller-C, latches, V2, LanePhaseAdapter |
| `async_rtc_data_checks.tcl` | Paired RTC → post-route `set_data_check` |
| `icc2/run_icc2_cmr_router.tcl` | ICC2 import / floorplan / place / route (no CTS for async) |
| `icc/run_icc_cmr_router.tcl` | ICC classic Milkyway fallback (not licensed here) |
| `innovus/run_innovus_cmr_router.tcl` | Innovus 21.35 LEF import chain |
| `pt/run_pt_post_route.tcl` | PrimeTime post-route STA / SDF |
| `run_remote_cmr_pnr_pilot.py` | LSF batch driver (login node must not run the tools) |

```text
python scripts/asic_pnr/cmr/probe_remote_pnr.py
python scripts/asic_pnr/cmr/run_remote_cmr_pnr_pilot.py
```

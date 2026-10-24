# Sync M16 clock-gating candidate

TT / 0.8 V / 25 C; 1 ns clock. Original ungated experiment is retained.

- DC job 15106801 completed. Structure: 48 routers, 384 IPMs/OPMs,
  64 top input/output ports, 192 synchronous lane selectors.
- DC report: 5,376 inserted clock gates; 76,800 gated registers (86.21%),
  12,288 ungated registers. WNS 0.00100231 ns, WHS 0.0300058 ns.
- Initial `report_timing -check_type` commands are unsupported in DC
  V-2023.12; two CMD-013 redirect errors are retained, not suppressed.
  The broad CKLN/CKAN/CKLG filter count 12,094 is NOT the ICG count.
- Read-only DDC audit job 15113501 checks actual CKLN enables individually.
- Old prepare job 15106901 was stopped before releasing downstream jobs.
  Replacement prepare job 15113601 depends on the new audit and verifies
  its PASS marker, absence of tool errors, endpoint coverage and margins.
- Power scope remains eight benchmarks, three original seeds, original
  injection points/case hashes/TB, MAXIMUM SDF, measurement-window VCD,
  time-based PT-PX. First simulation gates the remaining cases.

Remote experiment:
`/home/ghy19/Asynchronous_Router_CMR/experiments/20261024_sync_m16_clock_gating_tt_r1`

Remote power campaign:
`/prjtemp/ghy19/formal64_power_clock_gating/20261024_sync_m16_clock_gating_tt_r1`

## Follow-up: startup race and isolated correction

- Audit r3/job 15113701: all 5,376 actual CKLN E endpoints measured;
  zero no-path and zero negative setup/hold slack. Broad CKAN clock logic
  is excluded from the ICG count.
- Initial synthesis additionally logged PWR-191 for requesting `latch_posedge`
  while the library provides `latch_posedge_precontrol`. Actual mapped ICGs
  and their timing were audited. Job 15114201 confirmed the library-aware
  `-control_point before` style without tool errors. Original errors remain
  documented; the initial DC log is not claimed error-free.
- Original strict test 15114501 failed: no received flits, ready=0. Probe
  15123101 showed write pointer 00001 during reset, 00000 immediately after
  reset deassertion at a rising edge; TE=0. Independent probe 15123301 changed
  only reset release to the falling edge and restored one-hot pointer and
  normal write progress. This isolates a TB reset/gated-clock sampling race.
- Failed-smoke pending descendants were cancelled; original logs/VCD retained.
- New power campaign directory ends in `_resetfix_r2`, with the same DDC,
  SDF, cases, sampling, clock and assertions. The sole TB correction is one
  falling-edge wait before reset deassertion; both TB hashes are recorded.
- New prepare 15123601; compile 15123701 DONE; strict smoke 15123801 RUN.
  All 24 cases remain required; the smoke gates later simulations.
- PT-063 environment cause was resolved using the tool's own message manual:
  `SYNOPSYS_LC_ROOT=/soft/synopsys/lc/V-2023.12`. Independent startup probe
  15123401 completed without the former Library Compiler startup error.

No new power results or complete campaign acceptance established yet.

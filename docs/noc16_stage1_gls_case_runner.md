# Stage1 NoC16 GLS Case Runner

## Purpose

This flow runs Stage1 `NoC_16nodes` post-synthesis GLS directly from VCTM `.case`
files, without the AXI wrapper. The testbench drives the 20 NoC HS ports directly,
but Stage1 cases are restricted to core ports `0..15`; any use of top ports
`16..19` is rejected by the TB.

## Commands

Smoke:

```powershell
$env:GLS_SMOKE_STAGE='func_noc16'
python scripts/asic_dc/upload_and_run_gls_smoke.py

$env:GLS_SMOKE_STAGE='sdf_noc16'
python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Single VCTM case:

```powershell
$env:GLS_SMOKE_STAGE='func_noc16_case'
$env:GLS_NOC16_CASE='VCTM-MC1-NM-5f-r0p02'
$env:GLS_NOC16_TIMEOUT_SCALE='5'
python scripts/asic_dc/upload_and_run_gls_smoke.py

$env:GLS_SMOKE_STAGE='sdf_noc16_case'
$env:GLS_NOC16_CASE='VCTM-MC1-NM-5f-r0p02'
$env:GLS_NOC16_TIMEOUT_SCALE='20'
python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Multiple VCTM cases:

```powershell
$env:GLS_SMOKE_STAGE='func_noc16_case'
$env:GLS_NOC16_CASE_LIST='VCTM-MC1-NM-5f-r0p02,VCTM-MC1-NM-5f-r0p10,VCTM-MC5-NM-5f-r0p10,VCTM-MC10-NM-5f-r0p10'
$env:GLS_NOC16_TIMEOUT_SCALE='5'
python scripts/asic_dc/upload_and_run_gls_smoke.py
```

## Anti-Hang Rules

The wrapper now prints progress at least every 30 seconds while polling:

- job id and `bjobs -l` summary immediately after submit;
- job state on every poll;
- compile/run/bsub log sizes;
- key log tail including `TB_RESULT`, `TB_TIMEOUT`, `TB_FATAL`, `TB_PROGRESS`;
- stderr tail, ignoring the known C1 module-load noise.

Each VCTM case gets a unique timestamped job/log tag, so stale logs cannot be
mistaken for the active run. If a run is judged failed or stalled, the wrapper
kills that exact job.

## TB Notes

- `async_hs_sender` now latches `send_data` when `send_pulse` is accepted.
- `async_hs_receiver` no longer requires an extra sampled empty window between
  two-phase output toggles; it captures when `Req != Ack` and then sets `Ack <= Req`.
- The NoC16 TB supports concurrent scheduled inputs from `.case`, expected-flit
  matching, rx overflow detection, timeout detection, throughput, and
  avg/max/p95/p99 packet latency.
- CSV files are copied back to `scripts/asic_dc/sim_gls/results/`.

## Current Results

As of 2026-07-27:

| Run | Result | Notes |
| --- | --- | --- |
| `func_noc16` smoke | PASS | Stage1M `A75/BR75/BG150/OM150`, `DEL=80`; direct edge `E2E_EDGE_REQ_NS=12.000ns`, wrapper `90ns`. |
| `sdf_noc16` smoke | PASS | Real SDF annotate; direct edge `E2E_EDGE_REQ_NS=3.895ns`, wrapper `80ns`, missing/unexpected/timeout/rx_overflow all 0. |
| `func VCTM-MC1-NM-5f-r0p02` | PASS | CSV copied back; missing/unexpected/timeout/rx_overflow all 0. |
| `func VCTM-MC1-NM-5f-r0p10` | PASS | CSV copied back; missing/unexpected/timeout/rx_overflow all 0. |
| `func VCTM-MC5-NM-5f-r0p10` | STALLED | Reproducibly stops around `injected=1547/5000 rx=1559/5505`; stall probe dumps NoC router/link snapshot and exits. |
| `sdf VCTM-MC1-NM-5f-r0p02` | STALLED | Stops around `injected=1648/5000 rx=1668/5135`; job killed by wrapper. |
| `func VCTM-MC5-NM-5f-r0p10-cycle1875-closed2605` | PASS | Reduced cycle-window case before atomic-mask fix. |
| `func VCTM-MC5-NM-5f-r0p10-cycle1930-closed2680` | PASS | Was FAIL before atomic-mask fix; now passes. |
| `func VCTM-MC5-NM-5f-r0p10-cycle2000-closed2770` | FAIL | Partial-grant poisoning removed, but a later holder/context cycle remains. |

The smoke GLS chain is therefore working. The direct VCTM runner is also working
for light func cases, while higher pressure exposes a Stage1/direct-HS progress
stall that needs protocol/debug probes before treating MC5/MC10 as accepted.

The latest smoke numbers use edge probes by default. Treat `E2E_EDGE_REQ_NS` and
`E2E_EDGE_VALID_NS` as the real DUT-boundary timing. `T_noc/E2E_NS` is the old
wrapper-observed sampling metric and includes tens of ns of TB overhead.

Detailed deadlock evidence and reduction notes are in
`docs/stage1_noc16_deadlock_debug.md`. Use cycle-window reduction with
`--complete-started-packets`; raw file-prefix cases can truncate a wormhole
packet and create a fake holder/context deadlock.

# NoC16 Remote Post-Synth Chain Runbook

This is the stable command record for the NoC16 ASIC/post-synthesis flow. Do
not put passwords in this file. Set `C1_PASS` in the local shell before using
the Python upload helpers.

Remote project root:

```bash
/home/ghy19/Asynchronous_Router
```

## 1. Local regenerate RTL

From the local repo root:

```bash
$env:ASYNC_PRIMITIVES = "asic"
sbt "runMain NoC.NoC_16nodes"
```

Static sanity checks:

```bash
rg -n "launchedReq|forkBusy = launchedReq \\^ io_inAck" generated/NoC_16nodes.v
rg -n "DelayElement #\\(\\.DelayValue\\(4\\)\\)" generated/NoC_16nodes.v
```

## 2. Upload RTL/scripts and run NoC16 DC

Set credentials in the local shell, then:

```bash
python scripts/asic_dc/remote_upload_and_run.py upload
python scripts/asic_dc/run_dc_noc16_only.py
```

Remote acceptance checks:

```bash
cd /home/ghy19/Asynchronous_Router
grep -E "INFO: async NoC_16nodes DC complete|final GTECH cell count" logs/dc_noc16.log
grep -E "DEL|ND2" reports/NoC_16nodes/async_primitives.csv
grep -c "GTECH" outputs/NoC_16nodes_post.v
ls -la outputs/NoC_16nodes_post.v outputs/NoC_16nodes_dc.sdf outputs/NoC_16nodes.ddc outputs/NoC_16nodes_dc.sdc
```

Expected current baseline:

```text
GTECH = 0
DEL_delay = 1748
ND2D1_mutex = 472 or current regenerated primitive count
```

## 3. GLS smoke

Upload GLS assets:

```bash
GLS_SMOKE_STAGE=upload python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Run behavior-patched functional smoke:

```bash
GLS_SMOKE_STAGE=func python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Run NoC16 full gate-level SDF smoke only:

```bash
GLS_SMOKE_STAGE=sdf_noc16 python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Remote direct command equivalent:

```bash
cd /home/ghy19/Asynchronous_Router
bash sim_gls/run_gls_smoke.sh sdf noc16
```

Acceptance grep:

```bash
grep -E "TB_RESULT|E2E_NS=|T_noc=" logs/gls_noc16_sdf_run.log
```

Current baseline:

```text
TB_RESULT PASS
wrapped T_noc = 110 ns for the current widened SDF wrapper run
```

Older non-VCD/non-probe run may show `T_noc=60ns`; this is wrapper-observed
and clock-quantized, not the precise DUT boundary propagation time.

## 4. Precise SDF E2E edge probe

Default top-boundary probe, safe for the post-synth netlist:

```bash
cd /home/ghy19/Asynchronous_Router
GLS_E2E_PROBE=1 GLS_E2E_SRC_PORT=0 GLS_E2E_DST_PORT=15 \
  bash sim_gls/run_gls_smoke.sh sdf noc16
```

Or through the local helper:

```bash
GLS_SMOKE_STAGE=sdf_noc16_probe python scripts/asic_dc/upload_and_run_gls_smoke.py
```

Acceptance grep:

```bash
grep -E "TB_RESULT|E2E_EDGE_REQ_NS|E2E_EDGE_VALID_NS|E2E_WRAPPED_NS|E2E_WRAPPER_OVERHEAD_NS" \
  logs/gls_noc16_sdf_run.log
```

Current measured result:

```text
TB_RESULT PASS
E2E_EDGE_REQ_NS   = 30.635 ns
E2E_EDGE_VALID_NS = 30.635 ns
E2E_WRAPPED_NS    = 110.000 ns
E2E_WRAPPER_OVERHEAD_NS = 79.365 ns
```

Do not enable route segment probes by default. `GLS_ROUTE_PROBE=1` compiles
hierarchical inter-router references and can fail with VCS XMRE when DC has
optimized or renamed internal nets. Use it only after checking the actual
post-synth netlist hierarchy.

## 5. Power VCD and PrimeTime PX

Generate SDF VCD:

```bash
cd /home/ghy19/Asynchronous_Router
GLS_DUMP_VCD=1 GLS_DUMP_VCD_PATH=logs/noc16_sdf_smoke.vcd \
  bash sim_gls/run_gls_smoke.sh sdf noc16
```

Run PT PX time-based power:

```bash
cd /home/ghy19/Asynchronous_Router
NOC16_POWER_START=205 NOC16_POWER_END=405 \
  /soft/synopsys/prime/V-2023.12/bin/pt_shell \
  -f scripts/power/run_ptpx_noc16_power.tcl \
  > logs/ptpx_noc16_power.log 2> logs/ptpx_noc16_power.err
```

Acceptance grep:

```bash
grep -E "Number of annotated nets|fully annotated leaf cells|Total simulation time|Error:|INFO:" logs/ptpx_noc16_power.log
cat reports/NoC_16nodes/power_timebased_smoke.rpt
```

Current power baseline:

```text
Net Switching Power = 6.178e-06 W
Cell Internal Power = 3.262e-05 W
Cell Leakage Power  = 3.510e-03 W
Total Power         = 3.549e-03 W
VCD annotation      = 100%
```

If PrimeTime exits with `PT-001` / FlexNet `-15,234`, the license server is not
reachable from that job. Do not change RTL or power Tcl for that failure; retry
from the known working environment or wait for the license service to recover.

## 6. Static timing reports

PrimeTime report script:

```bash
cd /home/ghy19/Asynchronous_Router
/soft/synopsys/prime/V-2023.12/bin/pt_shell \
  -f scripts/timing/run_pt_noc16_e2e_timing.tcl \
  > logs/pt_noc16_e2e_timing.log 2> logs/pt_noc16_e2e_timing.err
```

Expected reports:

```text
reports/NoC_16nodes/timing_e2e_00_to_33_*.rpt
```

Current limitation:

```text
PrimeTime timing run is blocked by PT license checkout failure:
PT-001, FlexNet -15,234, license path 1701@192.168.2.7
```

Existing DC reports from synthesis remain available:

```bash
ls -la reports/NoC_16nodes/timing_setup.rpt \
       reports/NoC_16nodes/timing_hold.rpt \
       reports/NoC_16nodes/timing_through_del.rpt
```

Use the SDF edge probe result as the current precise end-to-end number until
PrimeTime timing reports can be regenerated.

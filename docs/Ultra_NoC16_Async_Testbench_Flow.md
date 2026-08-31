# Ultra NoC16 asynchronous testbench flow

Last updated: 2026-08-12

## Purpose

This is the canonical performance and strict-SDF test environment for the Ultra NoC16. It implements the two-phase bundled-data boundary discipline of Ultra: data is stable before a local `Req` phase transition and the receiver returns `Ack` only after capturing the flit. It also follows Transition's injector/switch/absorber principle: boundary traffic is independent at every port and the handshake is a physical feedback path, rather than a common simulation clock.

The previous AXI/BRAM wrapper remains useful for its AXI interface regression. It is not the signoff performance environment because its clocked receiver can return `AckOut` in the same simulation time slot as `ReqOut`.

## Topology

`tb_noc16_async_boundary.sv` directly instantiates the vectorized `async_noc16_port_adapter`, which is only a naming adapter around `NoC_16nodes`. It does not modify the router or add a clock domain.

There are two elaboration tops:

- `tb_noc16_async_boundary`: event-driven behavioral endpoints.
- `tb_noc16_async_boundary_structural`: `AsyncEndpointBank20`, with a Mousetrap source and sink at each of the 20 NoC boundary ports.

For a structural source, TB `Req/Data` enter a Mousetrap stage, its captured `ReqX/DataOut` drive the NoC, and NoC input `Ack` returns to the stage's `AckX`. For a structural sink, NoC output `Req/Data` enter a Mousetrap stage; the stage's captured `ReqX` is the NoC `Ack`, while the event-driven consumer returns the stage's `AckX` after recording the captured data. This preserves the physical capture-before-ack relationship without instantiating 40 full routers outside NoC16.

## Traffic and timing contract

`input_cycle` is only an offered-load timestamp:

```text
offer_time = case_epoch + input_cycle × CASE_TICK_NS
```

`CASE_TICK_NS` defaults to 20 ns, matching the historical AXI wrapper cycle. No `posedge` process generates or consumes a NoC handshake. Each source has its own event process and preserves its own case order; ports due at the same time start concurrently.

Default endpoint timing is `TX_SETUP_NS=0.05 ns` and `RX_CAPTURE_NS=0.05 ns`. `TX_SETUP_NS` is an external bundled-data setup constraint. `RX_CAPTURE_NS` models behavioral consumer capture only. Structural signoff includes a protected sink-to-NoC Ack delay; the selected physical implementation is `DEL075`.

## Measurements and artifacts

The summary CSV retains the existing columns and packet-latency definition: each delivered Tail is measured from its Head's NoC ingress acknowledgement to the Tail's NoC egress request. `events.csv` records offered, request, ingress-acknowledgement, egress-request and capture times in ps. `latency_detail.csv` provides the matching tail records for path analysis.

The checker consumes the same `.case` grammar as the historical platform. As with that platform, flits are matched by output port and still-unseen expected content; it does not impose a false global arrival order on packets issued by different input ports. It records every mismatch and continues until drain or timeout.

## Local use

From `sim/AsyncNoC`:

```powershell
$env:NOC16_ENDPOINT_MODE = 'behavioral' # or 'structural'
$env:NOC16_CASE_FILE = "$PWD/testbench/generated_cases/TAB_16/TAB-NET-UR-3f-r0p02.case"
vivado -mode batch -source run_noc16_async_boundary.tcl
```

Outputs are written to `results/async_boundary/<mode>/`.

## Strict SDF use

Synthesize `AsyncNoC16BoundaryDUT` as one DC top containing the endpoint bank, adapter and NoC. Strict SDF annotates this one netlist/SDF at the boundary DUT instance; do not compile independently synthesized endpoint and NoC netlists. Set `ULTRA_ENDPOINT_ACK_DELAY_PS` to `50`, `75`, `100`, `150`, or `250`; the selected signoff value is `75`, retained as 20 direct `DEL075` cells. Do not use `+nospecify`, `+notimingcheck`, force, or a behavioral gate-netlist patch.

The dedicated remote entry scripts are `run_dc_ultra_noc16_boundary.tcl` and `run_gls_ultra_noc16_async_boundary.sh`. They intentionally do not alter the existing AXI/BRAM GLS runner or its result namespace.

The required first regressions are TAB 3-flit p02 and VCTM-MC5-NM 3-flit p02; then TAB p10/p20/p30. A high-load failure is a DUT result unless the endpoint event log proves a protocol violation such as same-timestamp output Req/Ack.

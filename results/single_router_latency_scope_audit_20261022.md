# Single Router latency scope correction

The 2026-10-22 r2 `isolated` mode means one packet and one source. It injects the next flit after input Ack, without waiting for the previous flit's output. Its reported mean includes queueing within that packet. It does not measure isolated-flit intrinsic hop latency.

Historical `tb_cmr_router_hop_ppa.sv` uses `drive_port(..., wait_rx=1)` in isolated mode. Each subsequent flit waits for the previous output before injection. The two measurements are not equivalent.

| Design | Historical isolated-flit latencies, Head/B1/B2/B3/Tail (ns) | Mean (ns) | 2026-10-22 single-packet mean including queueing (ns) |
|---|---|---:|---:|
| Async Thin c1p1 | 0.710 / 0.450 / 0.524 / 0.452 / 0.521 | 0.5314 | 1.7044 |
| Async c1p4 | 1.101 / 0.696 / 0.771 / 0.698 / 0.768 | 0.8068 | 2.4302 |

The c1p4 historical Head is greater than 1 ns; its Body/Tail and five-flit mean are below 1 ns.

The hardware also changed. The historical c1p4 synthesis manifest records RCU 1xDEL050 and Ackin 1xDEL050. The 2026-10-22 synthesis records RCU 1xDEL100, Ackin delay disabled, ReqOut 1xDEL050 plus one buffer, and current DFF-based RTL. Their areas are 12601.680 versus 17033.520003 um2. These are different baselines, so the numerical difference cannot be attributed entirely to queueing.

The new c1p4 raw request-to-request latencies are 1.229 / 1.838 / 2.460 / 3.004 / 3.620 ns. Ingress times are 210.050 / 210.326 / 210.658 / 211.002 / 211.337 ns; output request times are 211.279 / 212.164 / 213.118 / 214.006 / 214.957 ns. The fixed 90 ps receiver capture delay is excluded.

The newly reported energy is tied to its actual new traffic window. Historical latency numbers must not be substituted into the new energy/area row as if it were one matched experiment.

To recover a comparable isolated-flit result for the current netlists, rerun with output-paced injection and retain independent packet-stream measurements. Freeze the exact RTL, delay recipe, library, port/lane mapping and receiver timing before comparing baselines.

Sources:

- `scripts/asic_dc/cmr/results/20260914_cmr_c1p4_async_sync_hop_ppa/async_fat_1x4/isolated/gls/hop_events.csv`
- `scripts/asic_dc/cmr/results/20260912_205700_cmr_primitive_hop_ppa_rpsdel050/async_thin_1x1/isolated/gls/hop_events.csv`
- `scripts/asic_dc/cmr/results/20260914_cmr_prop_temp_c1p4_rpsdel050_r1/summary.json`
- `scripts/asic_dc/cmr/results/20261022_router_ppa_r1_async_c1p4/reports_dc/cmr_structure.rpt`
- `scripts/asic_dc/cmr/results/single_router_20261022_r2/isolated_flits.csv`
- `scripts/asic_dc/cmr/tb_cmr_router_hop_ppa.sv`

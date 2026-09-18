# Final 64/256-node results

This folder is the paper-facing result set derived only from
`experiments/curated/validated_64_256_csv_20260918`. Raw logs and older figure
directories are not parsed by the final builder.

## Metric policy

- Unicast and locality latency: mean flit latency in ns.
- Multicast latency: mean transaction completion latency in ns.
- No percentile or maximum latency is exported to the publication tables.
- Throughput uses measured offered/delivered rates. For 256-node E1, offered
  rate is reconstructed as `(delivered_flits / delivery_ratio) * 1e6 /
  (measurement_window_ps * 256)`.
- Throughput includes all correctness/full-drain passes. Latency includes only
  paired, near-lossless, uncensored, paper-eligible points.

## Figures

- `fig01_64_throughput`: all eligible 64-node throughput scans on one measured-rate axis.
- `fig02_64_latency`: all paired, near-lossless 64-node mean-latency scans on one axis.
- `fig03_256_global_locality`: 256-node global UR throughput/latency and locality latency.
- `fig04_multicast`: 64-node fanout and F16 plus 256-node cross-tier F16.
- `fig05_network_power64`: grouped bars for accepted 64-node network power and energy.
- The two 64-node scans use color for topology (Mesh, PROP, FAT) and marker shape
  for mode (UR Async, UR Sync, BC, Hotspot10). The asynchronous UR series uses
  Dynamic lane selection.
- Router lane scaling has parent-lane count on its x-axis, while power/energy are
  single-load implementation measurements. They are shown in the power figure and
  retained with provenance in `data/power64_all_accepted.csv`.
- The multicast figure also includes M5 F16 energy per useful destination; it uses
  pJ/useful destination, separate from the unicast pJ/flit comparison.
- In the 256-node global UR latency panel, the M60 setpoint is omitted; its
  throughput observations remain in the throughput panel and source tables.
- `data/256/`: all 59 CSVs from the validated 256 evidence bundle, including accepted
  case results and audit data. The `data/fig*.csv` files are the compact plotting views.

Paper legends use only Mesh, PROP and FAT for topology comparisons. Internal
configuration names and run identifiers remain in CSV provenance columns.

## 64-node Mesh high-load coverage

- The Mesh UR throughput sweep contains 30 accepted points.
  At setpoint M800, it measured
  604.22 Mflit/s/port offered,
  204.54 delivered, and a backlog
  of 32545 flits.
- The Mesh UR latency curve contains 15 paired near-lossless
  points and reaches 204.14
  Mflit/s/port offered. Higher-load runs remain represented in throughput data;
  saturated/censored points are excluded from the positive mean-latency curve.
- `data/mesh64_ur_latency_eligibility_audit.csv` retains all 30
  measured Mesh UR sweep rows, including observed per-flit means and censor flags.
  For example, M800 has an observed per-flit mean of
  507.24 ns,
  but no complete cohort mean; it is marked right-censored and is not plotted as a
  positive latency comparison point.
- Mesh BC and Hotspot10 eligible latency scans reach 146.27
  and 195.02
  Mflit/s/port, respectively.

## Exclusions and limitations

- 64-node multicast M60 and 256-node cross-tier F16 M40 are censored stress points.
- 256-node locality p=0.90 is excluded from the paired positive comparison because
  PROP is not near-lossless there.
- 256-node power is outside the experiment plan.
- Sync power is a post-synthesis, pre-CTS estimate and is not used for an
  unconditional Async/Sync implementation-efficiency claim.
- Area is retained in `data/area_summary.csv` but is not plotted.
- Existing frozen figures are superseded for presentation purposes, but are not deleted.

## 256-node result snapshot

- Global UR has 20 paired offered-load settings and 40 full-drain DUT results. The
  common near-lossless latency subset has 18 results. At setting M160, both designs
  measure 89.35
  Mflit/s/port offered and 89.34 delivered; mean latency is
  69.49 ns for PROP and 165.75 ns for Mesh.
- Locality uses three paired eligible points at p=0.247, 0.50 and 0.75. By p=0.75,
  mean latency falls 58.8% from the uniform-equivalent point for PROP and
  53.5% for Mesh. The p=0.90 PROP point is excluded because its backlog is above the near-lossless limit.
- Cross-tier F16 uses adjacent 8+8 destinations. All four M5/M20 Native/Repeated cases
  pass the paper gate. Mean completion latency is 13.38/167.55 ns at M5 and
  39.31/380.00 ns at M20 (Native/Repeated). M40 is retained only in the exclusion register.
- The detailed accepted-data copy contains 59 CSV files (62.7 MiB) across global UR, locality, and cross-tier F16. It includes per-case simulator tables and counters; raw DC netlists and full simulator logs remain referenced by the upstream source paths in `source_manifest.csv`.

## Node-level (isolated router primitive) PPA

Per-router hop delay, DC cell area and power for the seven frozen async router
primitives, from the paper hop-PPA campaign `20260912_205700_cmr_primitive_hop_ppa_rpsdel050`
(post-synthesis, MAXIMUM-SDF + time-based PT-PX, no place-and-route). The full
per-flit power/energy breakdown is retained in `data/node_ppa.csv`; the network-level
64-node area/power lives separately in `data/area_summary.csv` and
`data/power64_all_accepted.csv`.

| Topology | Geometry | Area (µm²) | Head (ns) | Body (ns) | Tail (ns) | Idle (mW) | Active (mW) | Packet energy (pJ) |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Thin | async_thin_1x1 | 7293 | 0.710 | 0.475 | 0.521 | 0.469 | 1.578 | 6.68 |
| Mesh | async_flatmesh_1x1 | 7273 | 0.709 | 0.475 | 0.521 | 0.467 | 1.564 | 6.58 |
| FAT | async_fat_1x2 | 9189 | 1.038 | 0.692 | 0.746 | 0.586 | 1.499 | 8.32 |
| PROP | async_prop_2x2 | 18145 | 1.194 | 0.768 | 0.819 | 1.138 | 2.033 | 12.00 |
| TopMesh | async_topmesh_2x2 | 18130 | 1.193 | 0.768 | 0.819 | 1.138 | 2.023 | 11.89 |
| PFAT | async_pfat_2x4 | 23002 | 1.257 | 0.797 | 0.841 | 1.429 | 2.315 | 13.97 |
| PFAT | async_pfat_4x8 | 61187 | 1.584 | 0.913 | 0.960 | 3.642 | 4.526 | 30.42 |

- Geometry is child x parent tier ports; `max_opm_fanin` and per-flit head/body/tail
  power/energy are carried in `data/node_ppa.csv`.
- These are isolated-primitive measurements: they are not the 64/256-node
  network totals and should not be summed into network area/power directly.

## Accepted input counts

| Dataset | Rows |
| --- | ---: |
| `64/01_ur/throughput_all_accepted.csv` | 90 |
| `64/01_ur/pre_saturation_latency_accepted.csv` | 44 |
| `64/02_benchmarks/bc_hotspot_all_accepted.csv` | 120 |
| `64/02_benchmarks/bc_hotspot_latency_eligible.csv` | 62 |
| `64/04_multicast/clean_fanout_400tx.csv` | 8 |
| `64/06_router/router_lane_scaling.csv` | 3 |
| `64/07_sync_b8/ur_all_full_drain.csv` | 30 |
| `64/07_sync_b8/ur_pre_saturation_latency.csv` | 19 |
| `256/01_global_ur/throughput_all_full_drain.csv` | 40 |
| `256/01_global_ur/common_near_lossless_latency.csv` | 18 |
| `256/02_locality/locality_m120_paired_summary.csv` | 6 |
| `256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv` | 4 |

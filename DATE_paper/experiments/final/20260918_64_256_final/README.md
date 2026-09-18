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

- `fig01_unicast64`: UR, BC and Hotspot10 throughput/mean-latency scans.
- `fig02_unicast256`: global UR throughput/mean latency and locality sensitivity.
- `fig03_multicast`: 64-node fanout and F16 plus 256-node cross-tier F16.
- `fig04_implementation64`: Dynamic/Static, Async/Sync, router lane scaling and M100 power/energy.
- `data/256/`: all 59 CSVs from the validated 256 evidence bundle, including accepted
  case results and audit data. The `data/fig*.csv` files are the compact plotting views.

Paper legends use only Mesh, PROP and FAT for topology comparisons. Internal
configuration names and run identifiers remain in CSV provenance columns.

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

## Accepted input counts

| Dataset | Rows |
| --- | ---: |
| `64/01_ur/throughput_all_accepted.csv` | 90 |
| `64/01_ur/pre_saturation_latency_accepted.csv` | 44 |
| `64/02_benchmarks/bc_hotspot_all_accepted.csv` | 120 |
| `64/02_benchmarks/bc_hotspot_latency_eligible.csv` | 62 |
| `64/03_static4/static4_paper_points.csv` | 3 |
| `64/04_multicast/clean_fanout_400tx.csv` | 8 |
| `64/06_router/router_lane_scaling.csv` | 3 |
| `64/07_sync_b8/ur_all_full_drain.csv` | 30 |
| `64/07_sync_b8/ur_pre_saturation_latency.csv` | 19 |
| `256/01_global_ur/throughput_all_full_drain.csv` | 40 |
| `256/01_global_ur/common_near_lossless_latency.csv` | 18 |
| `256/02_locality/locality_m120_paired_summary.csv` | 6 |
| `256/03_f16_cross_tier/f16_2tile_m5_m20_summary.csv` | 4 |

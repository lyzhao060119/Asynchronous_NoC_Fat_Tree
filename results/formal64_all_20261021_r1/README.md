# 64-node experiment snapshot — 2026-10-21

## Files to use

All five figure sets are available as both `.png` and vector `.pdf`:

- `formal64_async_latency_curves`: eight benchmark latency curves.
- `formal64_async_throughput_curves`: measurement-window delivered-copy throughput.
- `formal64_throughput_summary`: peak throughput and throughput at the highest near-lossless load (different metrics).
- `formal64_power_energy`: reported synthesis-level network power and energy estimates.
- `formal64_native_repeated`: separate, compact M16 Native versus Repeated control experiment.

Primary data:

- `scan_results_all_seeds.csv`: 2,815 selected per-case observations, including Sync M16 and rejected results.
- `superseded_scan_records.csv`: earlier/duplicate observations; not used in plots.
- `formal64_seed_averages.csv`: three-seed arithmetic means and sample standard deviations. A group requires all three accepted seeds.
- `throughput_summary.csv`: peak throughput and near-lossless operating point.
- `power_results_all_seeds.csv`: 80 per-case power records, including 12 compact Native/Repeated cases.
- `power_seed_averages.csv`: 22 complete three-seed benchmark/design groups; compact cases are excluded from these groups.
- `native_repeated_seed_averages.csv`: separate compact-test statistics.
- `coverage.csv`, `missing_or_rejected.csv`, `export_gaps.csv`, `analysis_issues.csv`: explicit coverage and missing evidence.
- `candidate_provenance_audit.csv`: separates pipeline PASS from the current-candidate eligibility used in figures.
- `source_manifest.json`, `download_hashes.json`, and `power_reports/`: source paths, hashes and compact original reports. No RTL, library, waveform, netlist or large raw log was downloaded.

## Accepted scan coverage

| Design | Accepted selected cases | Notes |
|---|---:|---|
| Async M16 | 720 / 720 | Eight benchmarks, three seeds, 30 loads. |
| Sync M16 | 720 / 720 | Preserved in CSV; deliberately excluded from figures. |
| Mesh64 | 636 current-candidate accepted / 720 stored | 76 old-netlist broadcast records are retained but excluded; eight current broadcast records are rejected. Only m5/m10 have complete current three-seed broadcast points. |
| PFAT64 | 655 / 655 found | Nine unicast grid positions lack a selected result. Broadcast was deliberately stopped after observed saturation; existing higher-load results are retained. |

The repaired PFAT multicast acceptance remains 372/372 required cases: four benchmarks × 90 plus broadcast m5/m10/m20/m40 × three seeds. Existing accepted broadcast m60/m80 and other completed points are preserved; no new higher-load run was requested here.

## Measurement definitions

- 64 nodes, five-flit packets; full scans normally use 1,000 warm-up and 10,000 measured original transactions. Seeds: 202701, 202702, 202703.
- X-axis: nominal case injection in Mflit/s/port, not the observed finite-window offered rate.
- Latency: original transaction's scheduled offer to its last destination Tail; source queueing is included. Pressure-point latency describes completed events and must not be interpreted as stable operating latency.
- Throughput: delivered destination-copy flits divided by measurement duration and 64 ports. This is not original-transaction throughput; fanout affects it.
- Filled markers: all seeds deliver at least 99% of canonical measurement-cohort copy flits in the measurement window. Open markers/dashes: accepted, eventually drained pressure cases below that threshold. Rejected or missing seeds do not become zeros or two-seed means.
- Peak throughput: greatest three-seed mean delivered-copy rate among accepted points. The second summary panel instead uses the highest nominal load meeting the 99% criterion in every seed. These definitions are not interchangeable.
- Power loads: UR80, BC40, Hotspot10-80, MC5-40, MC10-20, MC-static20, All-MC10, Broadcast5, in Mflit/s/port. Same benchmark loads across designs.
- Energy = reported total power × measurement duration. Energy/original divides by offered measurement-cohort original events; energy/copy divides by measurement-window delivered packet copies. Neither is a flit-energy metric, and the former is not a count of completed originals.
- Native/Repeated is a separate matched control: 100 warm-up plus 1,000 measured originals, MC10 at m20 and All-MC at m10, three seeds. Its shorter cohorts are never merged with full scans.

## Provenance and limitations

1. Current Mesh multicast performance is from `20261017_190000_mesh64_xfirsty_dc_r3`; smoke observations and 76 leftover old-netlist broadcast records are excluded. Existing unicast results are reused with their original per-row hashes. The observed Mesh broadcast bar from m5/m10 is **not** a measured saturation capacity; current high-load coverage is incomplete.
2. PFAT multicast is the archive Fig.2 arbiter candidate `20261019_archive_pfat64_fig2_tailrel100buf0_tt_r1`, with `_r2` accepted reruns preferred over old incomplete copies. PFAT unicast is reused historical evidence, not a new run of the repaired candidate.
3. Mesh power is **historical pre-X-first routing**, not the current Mesh performance candidate. It is explicitly labeled in the figure. No matched-current Mesh power rerun is implied.
4. M16 All-Broadcast has only two complete power seeds; Mesh All-Broadcast power is absent from the available batch. Those three-seed bars are marked `n/a`, not zero. No Sync M16 power campaign is represented in these figures.
5. PT-PX pipeline PASS and full activity annotation do not establish error-free power signoff. Inspected logs contain `PT-063: Library Compiler executable path is not set`; per-case `pt_errors` is retained. `check_power.rpt` reports out-of-range slew/load table use. These are reported synthesis-model estimates with unresolved accuracy limitations.
6. Negative recovery/removal SDF compatibility warnings remain. This export does not establish complete timing signoff, cross-PVT validity, or post-layout power.

## Reproduction

Collection scripts are under `scripts/asic_dc/cmr/`: `export_all64_snapshot.py`, `fetch_all64_snapshot.py`, `plot_all64_snapshot.py`. Run plotting with `D:\anaconda\python.exe scripts/asic_dc/cmr/plot_all64_snapshot.py --root results/formal64_all_20261021_r1`.

`download_hashes.json` verifies downloaded source evidence only; generated analysis and figures have their own `figure_hashes.json`. The raw remote outputs were not deleted or modified.

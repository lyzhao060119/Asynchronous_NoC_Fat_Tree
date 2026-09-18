# 256-node E2/E3 curated evidence

Remote LSF job: `12471101` (`compact256_repair_20260918_123846_repair`).
Frozen PROP-M16 and FlatMesh256 netlists were reused; no DC or PT-PX ran.

## What is included

- `summary_*.csv` and `acceptance_*.csv`: paper-facing measures and strict gates.
- `case_results/`: the 14 simulator result CSVs.
- `events/`, `latency/`, `flit_latency/`: direct per-case CSV evidence used to
  derive full-drain completion, window delivery/backlog, and latency.
- `upper_mesh_counters/`: accepted Req/Ack lane counts for the four PROP-M16
  locality runs; these are observed boundary handshakes, not route estimates.
- `source_traces/`: canonical locality/F16 input traces and destination sets.
- `figures/`: Fig.256-2 and Fig.256-3 PDF/PNG outputs.
- `repair_manifest.json`, `execution_manifest.json`, `pull_manifest.json`,
  `sdf_acceptance.json`, and `archive_manifest.json`: run inputs, case and trace
  hashes, remote/local file hashes, SDF evidence, and archive checksums.
- `run_repair.sh`: the submitted remote invocation and execution order.

The duplicated, approximately 300 MB-per-run SDF annotation text logs are not
duplicated into this Git package. Their exact SHA-256 and per-case `Total errors:
0` checks are recorded in `sdf_acceptance.json`; full logs remain in the local
raw archive and the remote run directory identified there.

## Acceptance snapshot

- Locality M120: 8/8 full-drain TB/SDF passes. The uniform-equivalent control is
  near-lossless for both designs. Seven points meet the fixed near-lossless
  threshold; PROP-M16 at `p=0.90` has backlog 6 and is censored.
- On paired near-lossless points through `p=0.75`, mean-latency reduction from
  the uniform-equivalent control is 58.8% for PROP-M16 and 53.5% for
  FlatMesh256. Do not extend this comparison to `p=0.90`.
- Adjacent-two-tile F16: 6/6 full-drain TB/SDF passes and 400/400 originals with
  6400 useful destination deliveries per point. M5/M20 are paper-eligible;
  M40 is retained as a censored stress point.

See `RESULTS.md` and the CSVs for per-point values and reasons.

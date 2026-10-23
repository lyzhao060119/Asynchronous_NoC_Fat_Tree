# 256-node final experiment results

Verified on 2026-10-20. Scope: Mesh256 and M16-256, TT/0.8 V/25 C,
5-flit packets, seeds 202701/202702/202703. No synchronous results or power
measurements are included.

## Acceptance

- 540 Native scans: UR, Multicast10-AABB, All-Multicast-AABB; 90 per
  topology/benchmark. All valid.
- 12 Repeated comparisons: all valid. Native comparison points reused.
- All 552 final runtime logs audited, exact delivery and complete original
  transaction coverage required. No detected timing/X/fatal/file-I/O errors.
- SDF annotation errors and missing timing checks: zero. Other annotation
  warning categories are retained in the frozen annotation audit, not hidden.
- The original quota-failed Mesh Repeated run is retained remotely; retry
  14594101 passed with complete Tail records.

## Files

- `summary/raw_metrics.csv`: 552 seed-level observations and trace hashes.
- `summary/three_seed_means.csv`: 184 mean/std groups, valid sample counts.
- `summary/native_repeated_comparison.csv`: matched loads and latency ratios.
- `summary/area_comparison.csv`: frozen DC total cell area and leaf counts.
- `summary/scan_coverage.csv`: per-topology/benchmark coverage.
- `manifests/full_reduction_audit.json`: all-case acceptance and runtime audit.
- `manifests/result_hashes.json`: remote metrics/log SHA-256 bindings.
- `figures/`: PNG and PDF latency, throughput, combined and comparison figures.

Latency is scheduled original-transaction generation to last destination Tail,
including source queueing. Throughput counts delivered destination-copy flits
inside the fixed measurement window, normalized by 256 ports. Drain does not
extend the throughput window. Pressure points are hollow; filled points require
all three seeds' window delivery >=99%. All plotted latency values are from
valid fully drained runs. Repeated copies share the original generation time.

Multicast10 comparison load is40 Mflit/s/port (20% of Mesh saturation200);
All-Multicast load is20 (25% of saturation80). Fanout drawn equiprobably from
2/4/8/16 with exact AABB destinations, excluding source. Comparison error bars
are three-seed sample standard deviation. Mesh Repeated All-Multicast includes
a seed below99% window delivery but all seeds ultimately drain; it is pressure
evidence, not uniformly near-lossless performance.

Area: Mesh 2.075487 mm2; M16 4.100582 mm2. Synthesis cell area only, no P&R.
Full netlists, SDF, traces, latency records and logs remain remote.

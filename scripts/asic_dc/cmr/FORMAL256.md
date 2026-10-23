# Formal256 campaign

The active campaign is remote:
`/home/ghy19/Asynchronous_Router_CMR/experiments/20261019_formal256_r3_checks`.
The earlier `20261019_formal256_r1` retains input generation and diagnostic
simulations only. `20261019_formal256_r2_ntc` diagnosed split-check matching.
Neither directory's preliminary smoke results are formal scan evidence.

## Frozen inputs

- Mesh: `20261018_123500_mesh256_xfirsty_tt_resynth_r1`, top `CMRMeshNoC`.
- M16: `20261019_085616_m16_dc256_tt_r1`, top `PROP_temp256_m16`.
- Both SDF headers identify TT / 0.80 V / 25 C.
- Three benchmarks: TOPO-UR, MULTICAST10-AABB, ALL-MULTICAST-AABB.
- Seeds 202701/202702/202703; 30 loads: 5, 10, 20, 40:20:500, 600, 700, 800.
- 1,000 warm-up + 10,000 measurement original events, five flits each.
- Multicast destinations are exact AABBs with equiprobable F2/F4/F8/F16.
- 270 canonical traces and 540 native cases were generated on the remote host.
  The r3 campaign links their immutable directories from r1. Its manifest
  records the original absolute paths and hashes.

## Measurement and identity

The test payload uses an 18-bit physical packet identity: low 14 bits in
Body/Tail `[25:12]`, high four bits in `[5:2]`. Routing Head encoding, flit
types, magic `[8:6]`, and flit index `[11:9]` retain their meanings. No DUT
source is changed. The TB allows 131,072 physical packets and 8,192 received
flits per port; generation fails on capacity overflow.

Every physical copy retains its original ready cycle. The source driver
serializes service through Req/Ack without shifting the scheduled timestamps.
Original-event latency is the last destination Tail minus scheduled generation
time. The reducer also reports first/mean destination latency, completed
original transactions inside the observation window, and copy-flit throughput.
Warm-up is excluded. Timeout points have no valid latency mean.

## Execution

Use shared `/soft/GNU/python3.12/bin/python3` on compute nodes. The login-only
`/usr/bin/python385` is unsuitable for batch jobs. Use the repository connection
helper with local `D:\anaconda\python.exe`.

VCS requires `+neg_tchk +define+NTC+RECREM`; the library explicitly provides
combined setuphold/recrem checks under these macros. The original SDF 2.1
contains split SETUP/HOLD and RECOVERY/HOLD checks. `formal256_sdf_checks.py`
creates a separate SDF 3.0 view by combining only exact endpoint/edge/condition
pairs, preserving each min/typ/max value and all delay lines. The original SDF
is never overwritten. The real-library two-cell pilot (14571501) passed with
zero annotation errors, zero warnings and no runtime violations. Full-network
pairing completed with zero orphan HOLD checks: Mesh 365,745 RECREM + 721,250
SETUPHOLD; M16 600,432 RECREM + 1,174,240 SETUPHOLD. Each view has a numeric
and endpoint audit plus original/derived SHA-256 manifest.

Negative-limit warnings (`SDFCOM_NL`) and missing-check warnings
(`SDFCOM_CFTC`) stop the formal gate. Other annotation warnings retain
their categories and counts. Annotation logs are frozen once per executable
and referenced from individual cases rather than copied hundreds of times.

Active jobs at submission:

| Stage | Mesh | M16 |
|---|---|---|
| Compatible-SDF conversion (DONE) | 14571601 | 14571701 |
| NTC compilation with paired checks | 14571801 | 14571901 |
| Read-only DDC area extraction | 14572001 | 14572101 |
| Directed and m5 gate | 14572201 | 14572301 |

`14572401` schedules finalization after both gates succeed. Each gate runs an
explicit high-ID/fanout test, duplicate/missing negative tests, small canonical
cases, and all three benchmark/seed m5 cases. Only then does it submit nine
independent one-core grids (29 remaining loads each) for that design.

`formal256_control.py schedule-finish` schedules the selector after all 18 grids
end. The selector audits all 540 metrics, chooses each Native Mesh multicast
benchmark's first load reaching 99% peak three-seed throughput, and selects the
largest existing load at or below 25% saturation with three valid Native Mesh
seeds and >=99% measurement-copy delivery. Unbounded saturation or no eligible
load stops selection explicitly. The selected trace generates 12 Repeated
cases; Native data is reused. Final reporting follows their terminal jobs.

Do not rerun the launcher to poll jobs. Inspect specific IDs, `work/*/compile.log`,
`logs/*/*/run.log`, `manifests/grid_jobs_*.json`, and per-case `metrics.json`.
LSF stdout files can remain absent until a job exits.

## Acceptance and handoff

- Formal PASS requires successful annotation, no unsupported negative checks,
  zero timing/X/fatal messages, exact scoreboard delivery, complete original
  events, and zero missing/unexpected/timeout.
- Data/X/timing failures stop the affected grid and set a design-wide halt
  marker. Timeout outcomes remain unclassified pressure observations pending
  diagnosis, and never become valid latency data.
- `summary/raw_metrics.csv` retains seeds and statuses;
  `summary/three_seed_means.csv` retains sample counts, mean and standard
  deviation; `summary/coverage.json` must account for all 552 formal cases.
- Pull only these summaries, hashes and manifests. `plot_formal256.py` produces
  PNG/PDF curves and Native/Repeated comparisons locally once coverage is
  complete. Rendering and numerical audit remain required before delivery.
- Whole-network area reports are extracted read-only from the frozen DDCs by
  `formal256_area.tcl`; no compile/optimization command is run. Audit the
  explicit AREA_PASS marker and nonempty `area/*/area.csv` before use.

Local regression: `D:\anaconda\python.exe scripts/asic_dc/cmr/test_formal256_campaign.py`.
SDF pairing regression: `D:\anaconda\python.exe scripts/asic_dc/cmr/test_formal256_sdf_checks.py`.

## Final verification (2026-10-20)

All 540 Native and 12 Repeated formal points passed final reduction and runtime
log audit. The Mesh All-Multicast Repeated seed 202703/load20 initially lost its
Tail CSV to quota exhaustion; original evidence remains in the
`_failed_quota_original` directory. Retry 14594101 restored complete Tail
evidence; report 14594201 and `finalize_formal256.py` confirmed 552/552 valid.
The full audit excludes directed/small tests by exact formal case naming.

`finalize_formal256.py` repairs the empty area CSV from numeric `Total cell area`
in the frozen DC report, without resynthesis. Area is Mesh 2,075,487.427456 um2
and M16 4,100,581.969559 um2. `summarize_formal256.py` independently checks all
552 unique keys and 184 three-seed mean/std groups.

Final small artifacts are under `results/formal256_20261019_r3_checks/`:
`summary/`, `manifests/full_reduction_audit.json`, `manifests/result_hashes.json`,
and `figures/`. Native/Repeated uses load40 for Multicast10 (20% of Mesh
saturation200) and load20 for All-Multicast (25% of saturation80).
Filled markers require all three seeds' window delivery >=99%; hollow markers
are valid, fully drained pressure results. Final drain correctness does not
imply >=99% delivery within the fixed measurement window. Error bars in the
Native/Repeated plot show sample standard deviation across three seeds.

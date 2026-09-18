# compact256 repaired E2/E3

Run compact256_repair_20260918_123846, job 12471101. Frozen netlists were reused; no DC or PT-PX ran.

- Locality M120: 8/8 full-drain TB/SDF passes; uniform-equivalent control paired near-lossless: True. Near-lossless points require ratio >=99% and backlog <=5. Latency figure uses paired near-lossless points only. Result: within paired near-lossless p<= 0.75, PROP relative reduction 58.8% vs FlatMesh 53.5%; p=0.90 PROP is full-drain but censored (backlog>5).
- Cross-tier F16 adjacent two-tile 8+8: 6/6 TB/SDF passes. F16 M5/M20 claim: F16 M5/M20 paired evidence accepted. M40 is retained as a censored stress point and excluded from positive latency conclusions.
- F16 destination delivery requires 400/400 original transactions and all 6400 destinations. See summary/acceptance CSVs for per-case data.
- Inputs, commands, raw logs, monitor counters, and file hashes are preserved in this directory.

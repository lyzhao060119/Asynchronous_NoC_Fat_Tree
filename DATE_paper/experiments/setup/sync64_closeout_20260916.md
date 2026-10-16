# Sync64 B8 closeout status (2026-09-16)

This note supersedes the older `Sync M5 blocked` status in the legacy plan files.

- Frozen implementation: `20260915_231600_sync_prop_temp64_b8_dc`.
- Sync clock: 1.05 ns; canonical case tick: 1.000 ns.
- The old job `12388301` is retained only as evidence of an invalid hard-coded
  `CASE_TICK_NS=20` configuration. It is not a DUT failure.
- Corrected M5 smoke: 55,000/55,000 flits, `TB_RESULT PASS`, MAXIMUM-SDF with
  `Total errors: 0`.
- Complete UR run: `sync64_ur_20260916_161922`, 30/30 unique loads accepted.
- Common Async/Sync near-lossless high: M420, selected automatically using
  delivery ratio >=99% and measurement source backlog <=5 flits.
- Sync paper-eligible mean and p95 latency are monotonically non-decreasing;
  both trend audits report zero adjacent decreases and Spearman rho 1.0.
- Network power is limited to M100 and M420. Async values are reused from the
  accepted eight-point archive; only the two Sync activity/PT-PX points are new.
- Router mechanism evidence is the accepted Async c1p1/c1p2/c1p4 aggregate
  MAXIMUM-SDF lane scaling. Dynamic4/Static4 is retained as a limiting result,
  not as evidence that Dynamic selection necessarily improves performance.

All power numbers are post-synthesis, time-based PT-PX estimates. Sync clock
power includes the pre-CTS ideal clock activity and is not a post-layout result.

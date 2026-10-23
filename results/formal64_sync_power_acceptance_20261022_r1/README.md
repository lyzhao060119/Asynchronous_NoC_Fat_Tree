# Sync M16 power acceptance snapshot, 2026-10-22

This audit covers the 24-point Sync M16 power supplement. It does not declare
the entire campaign complete. Remote status was inspected at 08:39 CST;
compute-node waveform/integrity audit job 14887101 subsequently completed.

| Check | Passed / total |
| --- | ---: |
| Simulation scoreboard | 6 / 24 |
| PT-PX case PASS | 5 / 24 |
| Complete audited record including archive and waveform boundaries | 5 / 24 |
| Unqualified final power acceptance | 0 / 24 |

## Completed records

| Benchmark | Seed | Load (Mflit/s/port) | Reported power (mW) | Finding |
| --- | ---: | ---: | ---: | --- |
| UR | 202701 | 80 | 281.2 | Integrity passed; PT-063 remains |
| UR | 202702 | 80 | 281.6 | Integrity passed; PT-063 remains |
| UR | 202703 | 80 | 280.9 | Integrity passed; PT-063 remains |
| Bit complement | 202701 | 40 | 277.2 | Integrity passed; PT-063 remains |
| Bit complement | 202702 | 40 | 276.6 | Integrity passed; PT-063 remains |

For all five: 55000/55000 flits, zero missing/unexpected/timeout, SDF annotation
zero errors, no matched runtime timing/protocol-failure signatures, 100% net
activity annotation, nonempty required reports, matching frozen DDC/netlist/SDF
hashes, measurement-window waveform boundary coverage, successful gzip decode,
and decompressed SHA-256/size matching the verified archive manifest.

No waveform truncation was found in these five completed records. This is a
boundary/integrity check, not proof of every possible internal timing event.

## Reservations and remaining work

- Every completed PT log retains `Library Compiler executable path is not set
  (PT-063)`. They are provisional synthesis-level power estimates, not clean
  final power signoff. Library-table extrapolation warnings remain separately
  relevant.
- Bit-complement seed 202703 has passed simulation and is still in PT-PX at
  the inspected snapshot. The other 18 points have not completed the required
  chain. The machine category `INCOMPLETE_OR_FAILED` covers these 19 records;
  it does not imply 19 experimental failures.
- Unfinished records and unresolved warnings prevent full-campaign acceptance.
- Do not silently mix these results into final published averages/plots as
  warning-free accepted data.

Remote evidence: `/home/ghy19/Asynchronous_Router_CMR/power_audit/20261022_sync_acceptance_r1/`
contains `acceptance.json`, `summary.json`, and the audit logs. Full waveforms
remain remote; no reruns or large downloads were performed.

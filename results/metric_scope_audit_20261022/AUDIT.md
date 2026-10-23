# 64 / 256 metric scope audit - 2026-10-22

## Conclusion

Output-throughput arithmetic and output-window inclusion rules agree. The
campaigns do NOT have identical end-to-end statistical semantics: latency
population and source schedule materialization differ. Do not label the two
latency datasets as directly matched cross-scale measurements.

## Evidence binding

Remote source was read without changing DUT, TB or jobs. Small source/launcher
and compile-evidence snapshots are under root0/root1/root2; remote paths and
SHA-256 are in evidence_hashes.json. Selected CSV provenance is preserved in
selected_provenance.json.

- root0: 64 multicast campaign, including current X-first Mesh compile log.
- root1: 64 current unicast campaign. Its work/filelist and input_hashes point
  back to root0 sources. TB SHA-256 equals root0's actual downloaded TB:
  92d9c70726f58860639fdcb6e941e36f5cad7c7a7327b679300ba0ae4c39fc70.
- root2: 256 actual generated fast TB SHA-256
  147e0abd6b0487beda6c53eb61669a44943e4a0cdc03498a18d09fe9f6d6587a,
  matching the frozen campaign source manifest.
- 64 sample runtime commands confirm CASE_TICK_NS=1, RX_CAPTURE_NS=0.1,
  ACK_TO_NEXT_REQ_GUARD_NS=0.2 and INJECT_MAX_RATE=0.
  256 runner uses the same values (guard0.2 from TB default).

## Matched definitions

1. Throughput numerator: scoreboard-matched destination-copy flits from the
   measurement cohort, with output Req event time inside [start,end).
2. Denominator: (end-start) seconds times core ports (64 or256), divided by1e6
   to obtain Mflit/s/port; not all directional/top ports.
3. Window: earliest measurement input offer cycle through latest +1tick;
   actual tick1ns. Canonical planned/case time, not actual handshake completion.
4. Post-window drain is excluded from throughput and used for correctness.
5. Warmup1000, measurement10000 originals; each packet5flits. Exclusion is by
   event identity, not guaranteed temporal completion of all warmup traffic.
6. Peak plotted is maximum three-seed mean across accepted30 load points, not
   average of independently selected per-seed peaks. Std is from that load.

## Confirmed differences

| Item | 64 | 256 | Effect |
|---|---|---|---|
| Latency population | Per destination Tail completed inside measurement window; direct TB summary | All10000 measurement originals after drain; max destination Tail per original | 64 right-censors late packets and weights destinations, unlike256 |
| Multicast latency aggregation | Mean of per-copy Tail latency | Mean of per-original last-destination Tail latency | Not the same statistic even at low load |
| Planned source time | materialize_case.serialized_offer_start enforces >=1tick per physical packet per source | Native preserves exact canonical ready_cycle; source driver queues naturally | Same nominal rate does not imply identical offer process |
| Repeated ready time | Physical copies serialized in case materialization | All copies retain original ready time | Source replication queue cost starts at different points |
| Finite sample density | About156 measurement originals/source | About39/source | Different finite-window and extreme-arrival effects |
| Timeout budgets | Stall50us, hard400us in inspected64 runner | Stall1.2ms, hard6ms | Affects acceptance, not passing-case throughput formula |
| Timing model checks | Inspected64 compile uses +neg_tchk without NTC/RECREM | +neg_tchk and NTC/RECREM with exact paired-SDF view | Strict timing-check evidence is not identical |

64 source: root0/src/tb_noc64_async_boundary.sv lines455-461 (window),
699-704 (throughput),721-735 (window-censored per-copy latency),
and root0/experiments/scripts/date_v3/materialize_case.py (serialization).
256 source: root2/src/tb_formal256_fast.sv lines253-258,410-416;
campaign collect_case computes event max across all matched destination tails.
64 plotting reads offer_to_tail_mean_ns directly; the README's claim that this
is per-original last-destination latency is therefore not established by the
actual implementation and should not be used as evidence of matched semantics.

## Recommended correction, not performed by this read-only audit

Retain original observations. Re-reduce64 Tail records using the256 rule:
measurement original ID -> destination set -> latest Tail after complete drain;
use canonical scheduled time as origin. Missing Tail records stay uncovered.
Throughput bars need not be recomputed merely for the latency mismatch, but
cross-scale capacity claims still need matched finite-duration methodology.
If strict matched source scheduling is required, either quantify the case-time
shifts from existing sidecars or run a small matched control; renaming columns
alone cannot remove that difference. No simulation was restarted here.

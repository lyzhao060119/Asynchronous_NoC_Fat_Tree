# Async vs Sync Alignment Notes

## Control semantics (aligned in this change)

| Area | Async (after alignment) | Sync (reference) |
|------|-------------------------|------------------|
| Packet context | `storedDir`, `storedLane`, `storedMask`; save on head launch, clear on tail complete | Same |
| Multicast mask | Body/tail reuse `storedMask` | Same |
| Lane reservation | Per-input independent selection with `canConnect` rotation | Same |
| Eligibility | `InputEligibilityModule` gates fork mask (holder + output empty) | `headEligible` / `bodyTailEligible` in `RouterCoreModule` |

## Intentionally not aligned

| Area | Async | Sync | Recommendation |
|------|-------|------|----------------|
| Handshake | Toggle `Req^Ack`, event-driven `AsyncClock` | Valid/ready on global clock | Keep async — core design choice |
| Router shell | IPM + OPM split | Monolithic `RouterCoreModule` | Keep split — matches paper structure |
| Input buffering | `AsyncFifo` per VC (default `fifoDepth=1` for latency) | `InputVCBuffer` with `vcCount`/`vcDepth` | Depth 1 is the latency default; deadlock/high-injection sweeps are separate |
| Same-dir lane alloc | Per-dir coordinated RR match (sync PerDir policy) | `PerDirHeadAllocator` | Aligned policy; async still resolves residual races in OPM mutex |
| Output scheduling | Per-port `AsyncArbiter` (mutex tree) | Multi-grant greedy scheduler | Independent ports already overlap; no explicit multi-grant scan |

## VC evaluation

Sync Stage 2 uses `vcCount=2` to overlap head/body packets on the same physical port. The async design already allows independent per-port fork/arbiter pipelines; adding VC would mean multiple `AsyncFifo` chains per port plus VC selection logic. **Not required for functional alignment** with sync test cases (which validate routing/multicast semantics, not peak VC throughput).

## Multi-grant evaluation

Sync multi-grant allows multiple inputs to fire to non-overlapping outputs in one cycle. Async routers naturally progress each input on its own handshake timeline; overlapping grants emerge from independent `AsyncFork` instances. The alignment work ensures **per-flit atomic multicast** and **holder semantics** match sync; explicit multi-grant replication is unnecessary unless profiling shows input stalls from lack of same-cycle grants.

## Verification

- Case format: shared `gen_cases.py` / `.case` files from SyncNoC
- Driver: `sim/AsyncNoC/testbench/async_hs_port.sv` (toggle handshake)
- Entry: `NoC.NoC_16nodes` + `tb_noc16_async.v`

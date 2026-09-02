# DATE V3.2.0 experiment tree

This directory is the reproducible control plane for
[`setup/NoC_Experiment_Design_V3.2.0.md`](setup/NoC_Experiment_Design_V3.2.0.md).
V3.1.0, V3.0.2, and V3.0.1 remain historical documents.

Human-facing names are complete English, for example
“Asynchronous balanced hierarchical network, 256 nodes”.
Internal `design_id`, benchmark keys, and run identifiers stay as compatibility
keys so historical hashes remain valid.

**Logic synthesis** (Design Compiler) maps register-transfer-level Verilog to a
standard-cell gate netlist. **Maximum-delay Standard Delay Format gate-level
simulation** annotates that netlist at the slow corner. Both are still
post-synthesis (zero wire load), not place-and-route. The software event
network simulator in `model/des/` is a predictor and cross-check only.

| Path | Git | Role |
|---|---|---|
| `configs/` | yes | Design / benchmark / seed / schema / plan JSON, including display names |
| `configs/inventory/v31_network_matrix.json` | yes | Frozen independent netlist matrix |
| `registry/` | yes | Run index and per-run `date-experiment-run-v1` manifests |
| `raw/` | no | Waveforms, delay files, logs, per-event CSV |
| `intermediate/` | no | Derived tables that can be rebuilt from raw |
| `curated/` | yes | Paper numbers; never hand-edited |
| `figures/` | yes | PDF/SVG/PNG plus plot metadata |
| `scripts/run_experiment.py` | yes | `plan` / `run` / `resume` / `status` / `archive` |
| `model/` | yes | Post-synthesis timing/energy-calibrated software event model |

```text
python "DATE paper/experiments/scripts/run_experiment.py" plan --plan phase0_import
python "DATE paper/experiments/scripts/run_experiment.py" status
python "DATE paper/experiments/scripts/print_v32_status.py"
python "DATE paper/experiments/scripts/check_v32_gates.py" --include-v31-gate-a
python "DATE paper/experiments/scripts/validate_paper_results.py"
```

Remote synthesis and gate-level simulation stay in `scripts/asic_dc/cmr/`.
DATE V3 does **not** run place-and-route: `scripts/asic_pnr/cmr/` is an archived
Phase 1 record only.

A run cannot enter `curated/` without a manifest, config hash, traffic hash
(when applicable), netlist hash, delay-file hash (for 256/1024 paper points),
and `frozen_structure_ok`. Archive-only identifiers remain `paper_eligible=false`.

## Whole-network matrix (V3.2.0)

Independent netlists that each need their own synthesis netlist and
maximum-delay file:

- Asynchronous narrow / balanced / progressively widened hierarchical networks, 64 nodes
- Asynchronous flat mesh network, 64 nodes
- Synchronous narrow / balanced hierarchical networks, 64 nodes (already signed)
- Asynchronous balanced hierarchical network, 256 nodes
- Asynchronous flat mesh network, 256 nodes
- Asynchronous balanced hierarchical network, 1024 nodes
- Asynchronous flat mesh network, 1024 nodes

The 1024-node boundary packet-replication comparison reuses the 1024-node
hierarchical netlist; only injection policy changes. Four-lane top mesh is
unsupported. No synchronous 256- or 1024-node network is added.

Staged gates: 64-node template (Gate B) before 256-node synthesis (Gate C/D)
before 1024-node synthesis (Gate E/F). A failure stops the next size and keeps
evidence. It does not fall back to the software event model.

```text
python "DATE paper/experiments/scripts/check_v31_gates.py" --gate B
python "DATE paper/experiments/scripts/run_v31_network_gates.py" --dry-run --design PROP256
```

## Phase 4 traffic

Canonical JSONL first, then RTL `.case` + model input. Paired designs share one trace.
Do not fold V3 traces into the old 3-flit `gen_cases_noc64.py`.

```text
python "DATE paper/experiments/scripts/check_phase4.py"
python "DATE paper/experiments/scripts/gen_cases_v3.py" --paper --materialize --design THIN64 --design PROP64 --design SYNC_THIN64 --design SYNC_PROP64 --benchmark BF-STRESS64
python "DATE paper/experiments/scripts/gen_cases_v3.py" --keycase-256 --materialize --design PROP256
```

`--paper` / `--full` = 3 seeds + 1000 warmup + 10000 measurement + coarse loads.
Display names for those benchmarks:

- 64-node hierarchical-width stress traffic
- Uniform random single-destination traffic, 64/256/1024 nodes
- 1024-node fixed sixteen-destination cross-group multicast traffic
- 1024-node mixed single-destination and multicast traffic

`Tmax` is last *intended* destination tail minus source header injection
(`head_inject_req_ps`). Formal 11k-event post-synthesis delay-format runs are
Phase 6 Gates C–F, not this generator gate.

## Removed field-programmable gate-array work and optional trace replay

The available field-programmable gate-array target cannot fit either complete
64-node balanced hierarchical network in its lookup-table capacity. V3.2.0
therefore has no field-programmable gate-array design, traffic benchmark, or
paper result. A 4-by-4 prototype is not a reduced 64-node validation and must
not be reported as one.

After Gate F, one frozen spiking-neural-network multicast trace may be replayed
as optional application evidence. It must preserve one spike as one multicast
injection and include source hash, provenance/license, and a logical-to-1024
endpoint mapping. It runs only on the signed 1024-node hierarchical netlist and
its boundary packet-replication policy. See
[`configs/application_traces/`](configs/application_traces/).

## Phase 5 software event model

Packet/flit-level model in `model/des/`, timed from
`model/calibration/20260901_primitive_ru5_post_synthesis.json`.
Every model number is **post-synthesis calibrated**. Do not write post-layout.
V3.2.0 does not use this model as the 256/1024 paper source.

```text
python "DATE paper/experiments/scripts/test_des_v3.py"
python "DATE paper/experiments/scripts/check_phase5.py"
python "DATE paper/experiments/scripts/check_phases_1_5.py"
```

Calibration uses seed `900001`, never paper seeds `202701/202702/202703`.
`model/calibration/locked.json` keeps `paper_matrix_allowed=false` until
whole-network delay-format traces exist. Table I uses isolated-router evidence
and does not need network model numbers.

Never overwrite frozen hop or synchronous 64-node directories.

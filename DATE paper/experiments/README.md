# DATE V3 experiment tree

This directory is the reproducible control plane for
[`setup/NoC_Experiment_Design_V3.0.2.md`](setup/NoC_Experiment_Design_V3.0.2.md).
V3.0.1 remains the historical claim document.

| Path | Git | Role |
|---|---|---|
| `configs/` | yes | Design / benchmark / seed / schema / plan JSON |
| `registry/` | yes | Run index and per-run `date-experiment-run-v1` manifests |
| `raw/` | no | VCD, SDF, SPEF, logs, per-event CSV |
| `intermediate/` | no | Derived tables that can be rebuilt from raw |
| `curated/` | yes | Table I and Fig. A/B/C numbers; never hand-edited |
| `figures/` | yes | PDF/SVG/PNG plus plot metadata |
| `scripts/run_experiment.py` | yes | `plan` / `run` / `resume` / `status` / `archive` |
| `model/` | later | Timing-calibrated discrete-event model |

```text
python "DATE paper/experiments/scripts/run_experiment.py" plan --plan phase0_import
python "DATE paper/experiments/scripts/run_experiment.py" status
python "DATE paper/experiments/scripts/run_experiment.py" validate-curated
```

Remote DC/GLS stays in `scripts/asic_dc/cmr/`. DATE V3 does **not** run P&R: `scripts/asic_pnr/cmr/` is an archived Phase 1 record only, and the orchestrator must not invoke it.
The orchestrator only sets environment variables and invokes the DC/GLS drivers.

A run cannot enter `curated/` without a manifest, config hash, traffic hash (when applicable), and `frozen_structure_ok`.
Archive-only IDs (Ackin-250, CFifo/BUFFD0) are imported with `paper_eligible=false`.

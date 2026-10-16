Post-synthesis timing-calibrated discrete-event model (Phase 5).

Calibration JSON produced by Router-primitive **MAXIMUM SDF / PT-PX** (DC ZeroWireload, not P&R) lives under
`calibration/` (`20260901_primitive_ru5_post_synthesis.json`). Isolated hop H/B/T is locked in
`calibration/locked.json`. Formal 64/256/1024 DES matrix runs stay forbidden until
`paper_matrix_allowed` is true (network MAXIMUM-SDF cal). Label every model number
`post-synthesis calibrated`; do not write post-layout.

## Layout

- `des/` — flit-level simulator (RCU, 4-branch CMR buffer, OPM grant, Q64 / TopMesh / FM / H-REP)
- `calibration/20260901_primitive_ru5_post_synthesis.json` — frozen primitive H/B/T + energy
- `calibration/locked.json` — `model_version` + `calibration_hash` written by `calibrate_des.py --write-lock`

## Isolation

DES itself is local Python.  Do not submit DC/GLS onto hosts already running
another Phase 5 job.  Optional GLS must use job prefix `cmr_descal_`, a new run
ID, and `CMR_DES_BSUB_EXTRA` if you need to pin different LSF nodes.  Frozen
hop and Sync64 directories are never overwritten.

## Calibration pack

```text
python "DATE paper/experiments/scripts/prepare_descal.py"
python "DATE paper/experiments/scripts/run_descal_gls.py" --probe
python "DATE paper/experiments/scripts/calibrate_des.py" --pack "DATE paper/experiments/intermediate/des_calibration" --write-lock
```

`paper_matrix_allowed` stays false until `rtl/<DESIGN>/<tag>/events.jsonl` from
V3 5-flit MAXIMUM-SDF (64) / RTL keycase (256) passes §21. Do not SKIP_DC the
Ackin-250 Fat NoC64 netlist for this compare.

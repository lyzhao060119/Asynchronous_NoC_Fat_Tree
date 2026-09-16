# Round 2 baseline DC authorization gate (2026-09-15)

**Status: COMPLETE — BOTH BASELINES FROZEN + SMOKE PASS**

| DUT | Run ID | Status |
|---|---|---|
| PFAT_temp256 | `20260915_122347_cmr_pfat_temp256_hier_dc` | **PASS + smoke 2/2**; `FROZEN_PFAT_TEMP256_NETLIST_RUN_ID` |
| FlatMesh256 | `20260915_122347_cmr_mesh256_hier_dc` | **PASS + smoke 2/2**; `FROZEN_FM256_NETLIST_RUN_ID` |

E2 F16: **6/6 PASS** + Fig.256-2 plotted.  
E1 UR: PROP coarse done; PFAT coarse mostly PASS; FM256 coarse running.

Launcher: `python scripts/asic_dc/cmr/launch_r2_baseline_hier_dc.py`  
(`CMR_HIER_SKIP_GLS=1`, `CMR_DESCAL_SUBMIT_ONLY=1`, Tree DEL050 / Mesh DEL150)

## Ready inputs

| DUT | RTL path | Structure | Hier kind | Top module |
|---|---|---|---|---|
| PFAT_temp256 | `generated_cmr/pfat_temp256/PFAT_temp256.v` (~40 MB) | PASS | `pfat_temp256` | `PFAT_temp256` |
| FlatMesh256 | `generated_cmr/mesh_noc256_11/CMRMeshNoC.v` (~67 MB) | PASS | `mesh256` | `CMRMeshNoC` |

## After both DC PASS

1. Directed + low-load smoke SKIP_DC for each.
2. Export:
   - `CMR_FM256_NETLIST=20260915_122347_cmr_mesh256_hier_dc`
   - `CMR_PFAT_TEMP256_NETLIST=20260915_122347_cmr_pfat_temp256_hier_dc`
3. `python scripts/asic_dc/cmr/run_e1_ur_three_dut256.py all`

## Forbidden

- Overwriting PROP_temp256 frozen `20260914_prop_temp256_b8_hier_dc_06`
- Reusing incomplete `20260914_mesh256_hier_dc_01`

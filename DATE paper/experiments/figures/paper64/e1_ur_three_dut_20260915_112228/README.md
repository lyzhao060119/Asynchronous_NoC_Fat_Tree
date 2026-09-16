# E1 three-DUT UR ASAP results

Archive: `DATE paper/experiments/raw/paper64/e1_ur_three_dut_20260915_112228`
Figures: `DATE paper/experiments/figures/paper64/e1_ur_three_dut_20260915_112228`

Injection: `v3_exp_header_asap_body`, seed 202701, 30 load points.
Evidence: post-synthesis MAXIMUM-SDF GLS estimates.

PFAT64: 12 historical low-load points + 18 fill points (M220–M800) all TB PASS 55000/55000.
PROP_temp64 / FlatMesh64: reused local 30-point aggregated metrics.

Latency panel includes only near-lossless points (backlog<=5; PFAT uses measurement backlog).

## Saturation summary

| Design | Peak delivered | Highest near-lossless |
|---|---:|---:|
| PROP_temp64 | 379.195994 | M420 (302.194149) |
| PFAT64 | 137.782777 | M160 (127.019817) |
| FM64 | 239.00542 | M280 (199.227716) |

Near-lossless point counts: {'PROP_temp64': 19, 'PFAT64': 10, 'FM64': 15}

Commit `01cc2b8af6b2918155ea372c38b7a1cd61ad780d` dirty=True.


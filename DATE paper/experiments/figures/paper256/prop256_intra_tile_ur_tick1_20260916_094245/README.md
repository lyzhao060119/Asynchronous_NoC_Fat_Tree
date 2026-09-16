# PROP_temp256 intra-tile UR (CASE_TICK=1)

- Design: PROP_temp256 B8 (frozen `20260914_prop_temp256_b8_hier_dc_06`)
- Constraint: destination always in same 8x8 tile as source (no upper Mesh)
- Injection: v3_exp_header_asap_body
- Run id: `20260916_cmr_prop256_intra_tile_ur`
- Loads: 5,20,40,80,120,160,200,280,400,600

## Results

| load | pass | thr | avg lat (ns) |
|---:|:---:|---:|---:|
| 5 | PASS | 0.751 | 7.597 |
| 20 | PASS | 3.001 | 8.061 |
| 40 | FAIL | 5.170 | 8.664 |
| 80 | FAIL | 9.811 | 10.044 |
| 120 | FAIL | 14.061 | 11.393 |
| 160 | FAIL | 17.019 | 12.602 |
| 200 | FAIL | 19.105 | 13.843 |
| 280 | PASS | 24.118 | 16.162 |
| 400 | FAIL | 28.111 | 20.209 |
| 600 | FAIL | 31.507 | 22.810 |

## Contrast vs Global UR tick1 (PROP only)

| load | intra pass/lat | global pass/lat |
|---:|---|---|
| 5 | PASS / 7.6 | PASS / 11.3 |
| 20 | PASS / 8.1 | PASS / 21.3 |
| 40 | FAIL / 8.7 | PASS / 37.2 |
| 80 | FAIL / 10.0 | FAIL / 62.2 |
| 120 | FAIL / 11.4 | FAIL / 76.5 |
| 160 | FAIL / 12.6 | FAIL / 84.1 |
| 200 | FAIL / 13.8 | FAIL / 88.0 |
| 280 | PASS / 16.2 | FAIL / 93.2 |
| 400 | FAIL / 20.2 | FAIL / 94.0 |
| 600 | FAIL / 22.8 | FAIL / 95.5 |

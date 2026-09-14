# Mesh64 vs PROP_temp64 ASAP TOPO-UR m5-800

- Injection: v3_exp_header_asap_body, seed 202701
- Mesh netlist (frozen): 20260913_104506_cmr_fm64_rpsdel150
- PROP_temp64 netlist (frozen): 20260913_prop_temp64_asap_uc_m5_200
- Mesh GLS run: 20260914_000444_cmr_fm64_asap_uc_m5_500
- PROP GLS run: 20260913_prop_temp64_asap_uc_m5_500
- Cases: 60 (30 loads x 2 designs), all TB PASS
- Cell area: Mesh 469899.021, PROP_temp 520533.044 (ratio 1.108)

Files:
- aggregated_metrics.csv
- area_compare.csv
- flatmesh64-vs-prop-temp64-asap-unicast.{png,pdf}
- tb_result_lines.txt
- csv/<design>/sdf_*.csv
- dc/<design>/qor.rpt (+ structure)

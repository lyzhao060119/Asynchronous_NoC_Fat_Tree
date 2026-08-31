# AsyncNoC summary outputs

`run_noc16_all_cases_vivado.tcl` writes CSV summaries here by case group:

- `VCTM_16/VCTM_16.csv`
- `TAB_16/TAB_16.csv`
- `misc/<group>.csv`

The async testbench currently records functional regression fields:
`group, case, expected_flits, matched_flits, missing_flits, received_flits, pass_fail`.

# Fig.256-2 (tick=1 restart)

- CASE_TICK_NS=1
- Run: `20260915_tick1_cmr_e2_f16_cross_tier256`
- Netlist: `20260914_prop_temp256_b8_hier_dc_06`
- Loads: M5 / M20 / M40 (PROP pre-sat calibrated from E1)
- Destinations: 4+4+4+4 across tiles

## Markers
```
/home/ghy19/Asynchronous_Router_CMR/logs/gls/20260915_tick1_cmr_e2_f16_cross_tier256/sdf/MC-F16_n256_s202701_high_repeated_PROP_temp256_top0/run.log:TB_RESULT FAIL injected=5069 delivered=5060 missing=60 unexpected=0 timeout=1 drainable=0
/home/ghy19/Asynchronous_Router_CMR/logs/gls/20260915_tick1_cmr_e2_f16_cross_tier256/sdf/MC-F16_n256_s202701_high_repeated_PROP_temp256_top0/stdout.log:TB_RESULT FAIL injected=5069 delivered=5060 missing=60 unexpected=0 timeout=1 drainable=0
TB_RESULT FAIL injected=5069 delivered=5060 missing=60 unexpected=0 timeout=1 drainable=0
TB_RESULT PASS injected=160 delivered=36580 missing=0 unexpected=0 timeout=0 drainable=1
TB_RESULT PASS injected=2560 delivered=2560 missing=0 unexpected=0 timeout=0 drainable=1
TB_RESULT PASS injected=320 delivered=71900 missing=0 unexpected=0 timeout=0 drainable=1
TB_RESULT PASS injected=320 delivered=73280 missing=0 unexpected=0 timeout=0 drainable=1
TB_RESULT PASS injected=5120 delivered=5120 missing=0 unexpected=0 timeout=0 drainable=1
ModuleCmd_Load.c(213):ERROR:105: Unable to locate a modulefile for 'INVS211'
ModuleCmd_Load.c(213):ERROR:105: Unable to locate a modulefile for 'IC618'
ModuleCmd_Load.c(213):ERROR:105: Unable to locate a modulefile for 'QUANTUS23.1'
```

# Sync M16 power execution optimization, 2026-10-22

This is an execution/scheduling change, not a new traffic or physical-power
model. Cases, measurement windows, 1-GHz clock, TT library, DDC/SDF and
acceptance checks remain unchanged. Running long analyses were not restarted.

- Account cap verified with `busers ghy19`: 32 slots.
- Existing two synthesis jobs reserve 16 slots and remain untouched.
- Activity acquisition uses two serialized SDF-log slots; it no longer waits
  for prior PT-PX/archive completion. PT-PX/archive can overlap acquisition.
- Sixteen pending Sync PT-PX cases changed from four requested slots to one,
  with `set_host_options -max_cores 1`, disabled overthreading, and one-thread
  OMP/MKL/OpenBLAS environment settings. Long-running old jobs retain their
  original allocations until completion.
- The initial diagnostic used unsupported `report_host_options`; one startup
  failed before power analysis. Its logs were retained, the command removed,
  and remaining new-recipe jobs temporarily held. Revised check job 14890201
  explicitly printed `PT_CORE_RECIPE_CHECK_PASS` and CMCR-103 confirmed core
  limit 1. The wrapper now requires that exact output marker before starting.
- Failed startup reused its original VCD in retry 14890301, with separate
  `reports_r4`/`ptpx_r4.log`. Its archive dependency and the current repair
  manifest were updated. The other fifteen held analyses were resumed.
- Original analysis Tcl is copied byte-for-byte as the recipe base; only
  execution-resource controls wrap it. Remaining PT-063/library-table warning
  reservations are not removed or reclassified as resolved by this change.

Remote evidence root:
`/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1`.
See `parallel_pipeline_r3.json`, `singlecore_recipe_r4/adjustments.json`,
`singlecore_recipe_r4/check2.log`, `singlecore_recipe_r4/recovery2.json`, and
the updated `repair_submission_r2.json`. Verify current job states live;
successful submission/configuration is not final power acceptance.

Historical completed jobs used about one CPU on average despite four slots
reserved. More case-level concurrency should improve campaign throughput;
no claim of a measured fourfold speedup or identical per-case runtime is made.

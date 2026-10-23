# Workspace cleanup - 2026-10-23

`previous_results.zip` preserves all 206 previously tracked result files that
were already absent from the working tree before this cleanup. Original paths,
byte sizes and SHA-256 hashes are recorded in `manifest.json`, along with the
source Git commit. The ZIP was fully read back and every hash verified.

Current result directories retain their original names and evidence files.
Raw reports, logs, audit records and intermediate experiment points are retained;
archiving does not assert that any measurement is publication eligible.

Recent experiment, plotting and split-emission driver sources hidden by the
repository scripts ignore rule are explicitly tracked, including local Python
imports. Existing source contents are preserved.

Deleted reproducible root compilation leftovers: `xvlog.log`, `xvlog.pb`.
Python syntax, JSON parsing and Git whitespace checks were performed. Hardware
simulation, synthesis and numerical reproduction are outside this cleanup.

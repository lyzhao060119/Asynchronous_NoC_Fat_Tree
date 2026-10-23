# 256 Native/Repeated latency using the 64 TB measurement definition

This is a re-reduction of existing accepted 256 Tail records, not a rerun.
Both topologies, both selected benchmarks, three seeds and two modes:24 runs.
The M16-only figure uses12 of these runs, matching the requested plot scope.

For each matched destination Tail record:

1. Require its physical packet to belong to the measurement cohort.
2. Require physical-packet planned Head offer and output Tail Req timestamp
   both inside the fixed half-open measurement interval [start,end).
3. Compute `(Tail Req time - physical Head offer time)/1000` in ns.
4. Average all eligible destination copies within that run, then take the
   arithmetic mean and sample standard deviation over three seeds.

This matches the inclusion and averaging rule in the actual64 boundary TB's
`offer_to_tail_mean_ns`. It does NOT group destinations by original transaction
or take the last destination; it excludes post-window completions. Copy counts
included/excluded and SHA-256 of each input Tail CSV are retained.

The old256 metric remains unchanged in its original directory and is also
retained as `old_last_destination_latency_ns` in the new summary. The newly
defined metric deliberately inherits64's window-censoring and copy-weighting;
it is not an estimate of all-transaction completion latency under overload.

IMPORTANT: matching a metric does not match traffic or source scheduling.
64 control uses MC10/load20 and All-MC/load10 with1000 measurement originals;
256 uses MC10/load40 and All-MC/load20 with10000 measurement originals.
64 materializes serialized per-source offers;256 preserves canonical times.
These conditions are NOT retrospectively changed or silently normalized.
The two scales can now be labeled with the same latency definition, but are
not controlled equal-load/equal-stimulus experiments.

The decomposition uses planned offer to Head request as source-side waiting
(including TX setup), and Head request to destination Tail as subsequent
delivery. It must not be confused with ingress-Ack-to-Tail network latency.

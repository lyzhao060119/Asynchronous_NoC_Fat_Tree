# Optional spiking-neural-network trace replay

No source trace is selected in V3.2.0. Do not place an unverified trace in this
directory and do not create paper results from it.

After Gate F passes, a candidate trace must validate against
[`../schema/snn_trace.schema.json`](../schema/snn_trace.schema.json) and satisfy
[`snn_trace_replay_policy.json`](snn_trace_replay_policy.json).

The trace preserves the original communication object: one spike event with a
destination set becomes one native multicast injection. A pre-flattened set of
unicast records cannot support the native-multicast comparison.

Only the signed 1024-node balanced hierarchical network and its boundary
packet-replication comparison may consume this trace. It is optional evidence:
invalid, weak, or incomplete replay results are archived and never block the
required synthetic gate-level matrix.

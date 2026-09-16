# PROP_temp64 Static4 RTL implementation (2026-09-15)

## Result and evidence boundary

`PROP_temp64_static4` is implemented and emitted as a complete 64-node RTL
topology.  The result in this note is **RTL/structural evidence only**.  No DC,
STA, SDF GLS, or PT-PX run was started.

## Static rule

Static4 changes only a c1p4 router's upward choice:

```
child ingress direction 0,1,2,3 -> parent output lane 0,1,2,3
```

It keeps all four physical parent lanes, output-port modules, datapaths, phase
adapters, and inter-router links.  It removes the availability-driven
`LaneSelector` from these upward branches and replaces it with a fixed one-hot
selection (`4'h1`, `4'h2`, `4'h4`, or `4'h8`).

The rule is not applied to parent ingress ports.  Downward traffic still enters
through any parent lane and uses the existing destination route computation to
select any child direction.  Therefore the implementation does not create
bidirectional ownership of an L1 child lane by one L2 router.

For every quadrant `q`, local L1 index `i`, and L2 plane `k`, both original
connections remain present:

```
L1(q,i).parent_output(k) -> L2(q,k).child_input((~i) & 3)
L2(q,k).child_output((~i) & 3) -> L1(q,i).parent_input(k)
```

The same separation is retained on all L2-L3 links.

## Reproduction

Emit the complete topology with the paper delay recipe:

```powershell
$env:CMR_RCU_MATCHED_DELAY_UNIT_PS='50'
$env:CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS='150'
sbt "runMain NoC.CMR.PROPtemp64Static4Main"
```

Run the fail-closed structural audit and Scala regression:

```powershell
python scripts/asic_dc/cmr/check_prop_temp64_static4.py
sbt "testOnly Router_Architecture.CMR.CMRStaticLaneMappingSpec NoC.CMR.CMRNetworkDutSpec"
```

Observed acceptance markers:

```
STATIC64_STRUCTURE_PASS top_ports=482 routers=48 l1=16 l2=16 l3=16 l1_l2_full_duplex_links=64 l2_l3_full_duplex_links=64 dynamic_selectors=0
Tests: succeeded 20, failed 0
```

The emitted top is
`generated_cmr/prop_temp64_static4/PROP_temp64_static4.v`.  Publication-facing
throughput, latency, area, or power comparisons remain blocked until matched
DC/STA and MAXIMUM-SDF experiments are explicitly authorized and pass.

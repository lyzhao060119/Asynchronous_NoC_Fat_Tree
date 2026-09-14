# CMR Q64 parallel-plane topology proposal

Status: architecture proposal, **not** an implemented or MAXIMUM-SDF-validated DUT.
Priority: packet/flit latency and sustained throughput under contention. Counts below
are structural; none are measured performance gains.

## Evidence motivating the change

The retained Q64 MAXIMUM-SDF uniform-random scan
`20260913_asap_uc_m5_200_mesh64_pfat64` compares FM64 with PFAT64
`(1,2,4,8)` at the top boundary, without a clustered upper mesh. At nominal
M160 the **actual offered** rate is 127.03 Mflit/port/s in both runs. PFAT64
has 1204.7 ns offer-to-tail p99 versus 42.3 ns for FM64. At nominal M180,
PFAT64 offers 144.57 but delivers 137.78 Mflit/port/s during the measurement
window, with 2188 flits of backlog; its run still ends `TB_RESULT PASS` after
drain. This motivates an architecture experiment, but does not establish that
the wide Mutex alone caused the delay.

Source: `DATE paper/experiments/raw/paper64/20260913_asap_uc_m5_200_mesh64_pfat64/`.
PFAT64 run ID: `20260913_1310_cmr_pfat64_rpsdel050_asap_uc_m5_200`.

## Coordinates and links common to both distributed-L3 variants

One 8x8 tile has 16 L1 routers grouped into four quadrants `q=0..3`, four
L1 routers `i=0..3` per quadrant. Existing quadtree direction numbering is
preserved: `childDir(i) = (~i) & 3`. There are four L2 copies per quadrant,
indexed `k=0..3`; each is `(childLanes=1, parentLanes=4)`.

```text
L1(q,i): child=1, parent=4
L2(q,k): child=1, parent=4

L1(q,i).parent[k] <-> L2(q,k).child[childDir(i)][0]
```

`<->` represents the separate upward and downward handshake channels.
Thus the 16 L1 routers and 16 L2 routers have 64 bidirectional link pairs.
Each L1 can select one of four L2 copies on an upward packet branch. No
physical lane is broadcast into four L2 inputs.

## Candidate A: four L3 routers, one upper mesh router

```text
L3(j): child=4, parent=1, j=0..3

L2(q,k).parent[j] <-> L3(j).child[childDir(q)][k]
L3(j).parent[0]    <-> Mesh.local[j]
```

This gives 64 L2-to-L3 link pairs and four L3-to-mesh pairs. With the
proposed `MeshLocal=4, interconnect=2`, the upper mesh has only **two**
inter-tile link pairs per neighbor. A single L3 `(4,1)` still has a maximum
OPM source count of 16. This is a useful control experiment but a poor first
choice if the objective is to remove wide arbitration and improve sustained
inter-tile throughput.

## Candidate B4: sixteen L3 routers, four mesh planes

```text
L3(j,k): child=1, parent=1, j,k=0..3
Mesh[j]: local=4, interconnect=2, j=0..3

L2(q,k).parent[j] <-> L3(j,k).child[childDir(q)][0]
L3(j,k).parent[0]  <-> Mesh[j].local[k]
```

Each `Mesh[j]` is a complete, independent grid over the tiles, with two
physical lanes in each neighboring direction. There are 16 L3-to-mesh pairs
per tile and eight inter-tile pairs per neighboring tile pair. L3 has only
four-way OPM arbitration. A `Mesh(2,4)` has maximum OPM source count 10.

The shared index `k` is intentional: an in-tile L3-to-L2 downward path uses
the same `k` as the arriving L2. From mesh, `Mesh[j].local[k]` reaches
`L3(j,k)`, which can reach every quadrant and, through `L2(q,k)`, every L1
in that quadrant. None of the sixteen L3 routers is restricted to one
destination quadrant.

## Performance-first prototype B8

Split each B4 mesh plane into two smaller planes while keeping the same
aggregate inter-tile and local link counts:

```text
L3(j,k): child=1, parent=1, j,k=0..3
Mesh[j,h]: local=2, interconnect=1, j=0..3, h=0..1

L2(q,k).parent[j] <-> L3(j,k).child[childDir(q)][0]
L3(j,k).parent[0]  <-> Mesh[j, k/2].local[k%2]
```

There are eight independent `Mesh(1,2)` grids. The total per tile is
16 L1 + 16 L2 + 16 L3 + 8 mesh routers = **56 routers**. Physical link
pairs per tile are 64 L1-to-L2, 64 L2-to-L3, and 16 L3-to-mesh. Between
adjacent tiles there are eight mesh link pairs, one in each plane. The
largest theoretical OPM source count is 7 in L1/L2 `(1,4)`, 4 in L3
`(1,1)`, and 5 in mesh `(1,2)`. These source counts follow the current
`CMRParameters.childOpmFanIn` and `parentOpmFanIn` formulas; they are not
post-synthesis Mutex widths or timing measurements.

For an upward packet, L1 chooses `k` and L2 chooses `j`, providing 16
first-hop/L3 combinations. For cross-tile delivery, that selects mesh plane
`(j,k/2)`. At the destination tile, the plane can choose either local lane
and thus either `k'` in its pair; `L3(j,k')` reaches all four quadrants,
and `L2(q,k')` reaches all four L1s within a quadrant. This gives a
constructive path between any source and destination. Intra-quadrant paths
turn at L2, inter-quadrant paths turn at L3, and cross-tile paths traverse
one mesh plane. The tree still performs destination-directed multicast
branching; each upward branch selects one physical lane per direction.

Eight `Mesh(1,2)` routers retain the same 16 local inputs and eight
inter-tile lanes as four `Mesh(2,4)` routers, but reduce the mesh OPM source
count from 10 to 5 and avoid mesh-wide two-lane direction selection. The
tradeoff is weaker ability to switch planes after entry: congestion on one
plane cannot be bypassed by another mesh router. B4 may win under skewed
traffic because its mesh router can choose among two interconnect lanes and
four local lanes. This must be tested; B8 is a performance hypothesis,
not a proven winner. The folded-Clos analysis below exposes a more important
tradeoff than mesh-plane selection: inside a tile, B4 and B8 preserve `k`
through L3, so the 16 `(j,k)` combinations are not 16 independently usable
middle-stage choices under arbitrary existing connections.

## Folded-Clos assessment

A folded Clos places the ingress and egress halves of a multistage Clos on
the same physical routers. Traffic rises to a selected common-ancestor
switch and descends to the destination; nearby destinations can turn before
the root. The current CMR quadtree already has this *up-then-down* behavior.
What its 16/4/1 organization lacks is independent, fully connected
middle-stage choice. Calling it "folded Clos" would not cure the PFAT64
MAXIMUM-SDF congestion.

A compact textbook-style Q64 folded Clos would use 16 leaf switches with
four PEs each, directly connected to `m` shared spine switches. With four
spines, each leaf needs four uplinks and each spine needs an input/output
connection to **every one of the 16 leaves**. An inter-leaf packet would
traverse three routers: leaf, spine, leaf, versus five for the current
L1-L2-L3-L2-L1 route. But a spine output has roughly 15-16 competing leaf
sources in the current CMR architecture, restoring the wide
arbitration problem and requiring longer on-chip links. A circuit-switching
Clos `C(n,m,r)` with `n=4` is rearrangeably nonblocking at `m>=4` and
strictly nonblocking at `m>=7` **only under its full-connectivity and
unicast circuit assumptions**. Those theorems do not bound latency or
guarantee congestion freedom for finite-buffer packet-switched multicast.

The proposed B8 fabric is sparse. For traffic staying within the tile,
an L1-to-L1 path goes through `L2(q,k)` and `L3(j,k)`, then descends via
`L2(q',k)` to the destination L1. The source and destination must have a
common available `k`; choosing another `j` cannot change `k`. For example,
if three existing source-leaf connections occupy `k={0,1,2}` and three
destination-leaf connections occupy `k={1,2,3}`, both new endpoints have
a free port, yet no common `k` exists. This is a **circuit-level blocking
counterexample**, not a claim that CMR packets are permanently blocked:
packet handshakes can wait for a lane to free. It does show why path count
alone cannot predict p99 latency. B4 has the same in-tile constraint.

Candidate A's `(4,1)` L3 can select a different downward child lane and
therefore remap `k`, but its 16-way parent-output contention may dominate
the timing. A small 4x4 permutation stage between L2 and the 16 `(1,1)`
L3 routers would also decouple source and destination `k`, at the cost of
additional switches/handshakes on both upward and downward paths. Neither
is an automatic improvement. B8 remains the first *low-arbitration*
prototype; A should remain an experimental control for the value of `k`
remapping. An optional permutation-stage variant should be considered only
if adversarial or hotspot results show that fixed `k` is the limiting factor.

A smaller remapping experiment keeps eight mesh planes and replaces the 16
`L3(1,1)` routers with eight `L3(2,2)` routers. With `h=k/2` and `t=k%2`:

```text
L2(q,k).parent[j]  <-> L3(j,h).child[childDir(q)][t]
L3(j,h).parent[t]  <-> Mesh[j,h].local[t]
```

An L3 output can then choose either `k` in its two-lane group, including
for in-tile downward traffic. The largest L3 OPM source count becomes 8;
the number of routers per tile falls from B8's 56 to 48. The `(2,2)`
geometry is already supported, but it inserts two-lane selectors and phase
adapters on L3 branches where B8's `(1,1)` routers need none. Its timing
and protocol risk must be measured; it is a useful diagnostic for the
fixed-`k` hypothesis, not a guaranteed upgrade.

The routing policy is as important as the wires. The current packet-lifetime
`LaneSelector` sees local competing OPM grants, not downstream queue depth
or plane congestion. Folded-Clos studies report substantial benefit from
adaptive upward-path allocation, especially with limited buffering; their
reported gains cannot be transferred to this asynchronous CMR design without
implementing and measuring a suitable packet-level policy. A policy must
also preserve per-packet lane hold and verify multicast copy counts and
flow-ordering requirements. CMR already branches in the tree using a
direction-level multicast route mask; merely renaming the graph folded Clos
does not add a new multicast primitive. Choosing separate roots for different
branches may improve distribution but must not duplicate destination copies
or create a cyclic wait through shared downstream acknowledgements.

Primary sources: [Clos's original switching-network paper](https://onlinelibrary.wiley.com/doi/abs/10.1002/j.1538-7305.1953.tb01433.x),
[Kim, Dally and Abts on adaptive folded-Clos routing](https://icn.kaist.ac.kr/~jjk12/papers/2006SC.pdf),
the [BlackWidow folded-Clos implementation](https://cseweb.ucsd.edu/classes/wi07/cse291-a/papers/blackwidow.pdf),
and [ClosNN's multicast-oriented design](https://www.researchgate.net/publication/317596226_Customizing_Clos_Network-on-Chip_for_Neural_Networks).
The published workloads, routers, flow control, and process technology differ
from this asynchronous CMR NoC; they motivate comparisons, not PPA claims.

## Implementation and validation constraints

* `CMRParameters.SupportedLaneGeometries` must add `(1,4)` for L1/L2.
  L3 `(1,1)` and B8 mesh `(1,2)` are already supported geometries.
* `NoCRouterChannelConfig` and `CMRFatTree` currently derive L2 child lane
  count from L1 parent lane count and instantiate exactly 16/4/1 routers.
  The new parallel graph needs its own explicit generator and inventory;
  simply changing the lane profile is insufficient.
* `CMRTopMesh` currently makes one router per tile. B8 needs eight separate
  coordinate-identical mesh planes, each connected only to the matching
  plane in neighboring tiles. Tree and mesh routing coordinates remain the
  tile/quadrant coordinates; `j`, `k`, and `h` are physical-plane indices,
  not new destination-address bits.
* Preserve the existing up-tree -> mesh -> down-tree turn discipline and
  verify multicast uniqueness, packet-lifetime lane hold, deadlock freedom,
  and the absence of an accidental cross-plane short. Existing
  `LaneSelector` senses local OPM grants, not downstream queue occupancy;
  sixteen physical paths do not imply congestion-aware global load balance.
* The bottleneck at a single PE input/output remains one child lane.
  No version of this topology can exceed that endpoint's service rate.
* Compare A, B4, B8, the optional L3 `(2,2)` variant, PFAT64, and FM64
  using identical offered **actual**
  traffic and MAXIMUM-SDF conditions. Check zero-load latency, offered versus
  delivered rate, p50/p95/p99, backlog growth, and packet/flit correctness
  for uniform, hotspot, transpose, and multicast loads. A drained PASS alone
  is not evidence of sustainable throughput.
* Include a fixed-`k` stress case with several simultaneous inter-quadrant
  flows targeting different PEs in one L1. Record per-`k` occupancy and
  waiting time. This separates structural blocking from mesh-plane effects.

These variants are multistage path-diverse networks, not mathematically
nonblocking Clos networks. No area/power claim is implied by having fewer
routers than a flat mesh: B8 adds many physical links and handshakes.

Relevant primary research: [Flattened Butterfly](https://people.eecs.berkeley.edu/~kubitron/cs258/handouts/papers/ISCA_FBFLY.pdf)
on path diversity and the need for effective load balancing; [Sanchez et al.
NoC topology analysis](https://csl.stanford.edu/~christos/publications/2010.noc-arch.taco.pdf)
on fat-tree bandwidth and high-radix arbitration tradeoffs. Neither paper
validates this particular CMR implementation.

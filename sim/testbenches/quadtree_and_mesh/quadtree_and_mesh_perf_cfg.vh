// GUI-editable performance configuration for quadtree_and_mesh perf testbenches.
// Pattern codes: 0=uniform_unicast, 1=local_unicast, 2=cross_tile_unicast, 3=hotspot_unicast, 4=uniform_multicast, 5=mixed_unicast_multicast, 6=overlapping_multicast.
// Top modules:
//   - quadtree_and_mesh_perf_1024_light_tb : 4 kinds of unicast traffic
//   - quadtree_and_mesh_perf_1024_tb       : unicast + multicast + mixed traffic
`define PERF_SEED 12345
`define PERF_PATTERN 0
`define PERF_NUM_FLOWS 4
`define PERF_PACKET_GAP_NS 20
`define PERF_ACK_DELAY_NS 1
`define PERF_RECT_W 1
`define PERF_RECT_H 1
`define PERF_EDGE_N 4
`define PERF_N_CORE 64
`define PERF_TOP_LANE 4
`define PERF_HANDSHAKE_TIMEOUT_NS 500000
`define PERF_GLOBAL_TIMEOUT_NS 8000000
`define PERF_WARMUP_NS 20000
`define PERF_MEASURE_NS 50000

// Fixed-flow override is supported by the 1024-node performance testbenches.
// Uncomment the block below when you want to debug one fixed source/destination pair in GUI.
// `define PERF_FORCE_FLOW0 1
// `define PERF_FLOW0_SRC_Q 0
// `define PERF_FLOW0_SRC_C 0
// `define PERF_FLOW0_DST_Q 0
// `define PERF_FLOW0_DST_C 1

`timescale 1ns/1ps
`default_nettype none
`include "quadtree_and_mesh_perf_cfg.vh"

`ifndef PERF_SEED
`define PERF_SEED 12345
`endif

`ifndef PERF_PATTERN
`define PERF_PATTERN 0
`endif

`ifndef PERF_NUM_FLOWS
`define PERF_NUM_FLOWS 4
`endif

`ifndef PERF_PACKET_GAP_NS
`define PERF_PACKET_GAP_NS 0
`endif

`ifndef PERF_ACK_DELAY_NS
`define PERF_ACK_DELAY_NS 1
`endif

`ifndef PERF_WARMUP_NS
`define PERF_WARMUP_NS 100000
`endif

`ifndef PERF_MEASURE_NS
`define PERF_MEASURE_NS 500000
`endif

module quadtree_and_mesh_perf_tb;
  localparam int FLIT_W = 28;
  localparam int N_QUAD = 4;
  localparam int N_CORE = 64;
  localparam int EDGE_N = 2;
  localparam int TOP_LANE = 4;
  localparam int MAX_FLOWS = 4;
  localparam int HANDSHAKE_TIMEOUT_NS = 500000;
  localparam int GLOBAL_TIMEOUT_NS = 8000000;
  localparam int PACKET_LEN = 3;

  localparam int PERF_PATTERN_UNIFORM_UNICAST = 0;
  localparam int PERF_PATTERN_LOCAL_UNICAST = 1;
  localparam int PERF_PATTERN_CROSS_TILE_UNICAST = 2;
  localparam int PERF_PATTERN_HOTSPOT_UNICAST = 3;

  localparam int CFG_SEED = `PERF_SEED;
  localparam int CFG_PATTERN = `PERF_PATTERN;
  localparam int CFG_NUM_FLOWS = `PERF_NUM_FLOWS;
  localparam int CFG_PACKET_GAP_NS = `PERF_PACKET_GAP_NS;
  localparam int CFG_ACK_DELAY_NS = `PERF_ACK_DELAY_NS;
  localparam int CFG_WARMUP_NS = `PERF_WARMUP_NS;
  localparam int CFG_MEASURE_NS = `PERF_MEASURE_NS;

  typedef longint unsigned ps_queue_t[$];

  logic clock;
  logic reset;

  logic core_in_req [0:N_QUAD-1][0:N_CORE-1];
  wire  core_in_ack [0:N_QUAD-1][0:N_CORE-1];
  logic [FLIT_W-1:0] core_in_flit [0:N_QUAD-1][0:N_CORE-1];

  wire  core_out_req [0:N_QUAD-1][0:N_CORE-1];
  logic core_out_ack [0:N_QUAD-1][0:N_CORE-1];
  wire  [FLIT_W-1:0] core_out_flit [0:N_QUAD-1][0:N_CORE-1];

  logic east_to_req [0:EDGE_N-1][0:TOP_LANE-1];
  wire  east_to_ack [0:EDGE_N-1][0:TOP_LANE-1];
  logic [FLIT_W-1:0] east_to_flit [0:EDGE_N-1][0:TOP_LANE-1];
  logic north_to_req [0:EDGE_N-1][0:TOP_LANE-1];
  wire  north_to_ack [0:EDGE_N-1][0:TOP_LANE-1];
  logic [FLIT_W-1:0] north_to_flit [0:EDGE_N-1][0:TOP_LANE-1];
  logic west_to_req [0:EDGE_N-1][0:TOP_LANE-1];
  wire  west_to_ack [0:EDGE_N-1][0:TOP_LANE-1];
  logic [FLIT_W-1:0] west_to_flit [0:EDGE_N-1][0:TOP_LANE-1];
  logic south_to_req [0:EDGE_N-1][0:TOP_LANE-1];
  wire  south_to_ack [0:EDGE_N-1][0:TOP_LANE-1];
  logic [FLIT_W-1:0] south_to_flit [0:EDGE_N-1][0:TOP_LANE-1];

  wire  east_from_req [0:EDGE_N-1][0:TOP_LANE-1];
  logic east_from_ack [0:EDGE_N-1][0:TOP_LANE-1];
  wire  [FLIT_W-1:0] east_from_flit [0:EDGE_N-1][0:TOP_LANE-1];
  wire  north_from_req [0:EDGE_N-1][0:TOP_LANE-1];
  logic north_from_ack [0:EDGE_N-1][0:TOP_LANE-1];
  wire  [FLIT_W-1:0] north_from_flit [0:EDGE_N-1][0:TOP_LANE-1];
  wire  west_from_req [0:EDGE_N-1][0:TOP_LANE-1];
  logic west_from_ack [0:EDGE_N-1][0:TOP_LANE-1];
  wire  [FLIT_W-1:0] west_from_flit [0:EDGE_N-1][0:TOP_LANE-1];
  wire  south_from_req [0:EDGE_N-1][0:TOP_LANE-1];
  logic south_from_ack [0:EDGE_N-1][0:TOP_LANE-1];
  wire  [FLIT_W-1:0] south_from_flit [0:EDGE_N-1][0:TOP_LANE-1];

  integer core_ack_delay_ns [0:N_QUAD-1][0:N_CORE-1];
  logic core_ack_pending [0:N_QUAD-1][0:N_CORE-1];

  integer edge_ack_delay_ns [0:EDGE_N-1][0:TOP_LANE-1];
  logic east_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic north_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic west_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic south_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];

  integer flow_src_q [0:MAX_FLOWS-1];
  integer flow_src_c [0:MAX_FLOWS-1];
  integer flow_dst_q [0:MAX_FLOWS-1];
  integer flow_dst_c [0:MAX_FLOWS-1];
  integer flow_src_gx [0:MAX_FLOWS-1];
  integer flow_src_gy [0:MAX_FLOWS-1];
  integer flow_dst_gx [0:MAX_FLOWS-1];
  integer flow_dst_gy [0:MAX_FLOWS-1];
  logic [1:0] flow_id [0:MAX_FLOWS-1];
  logic [FLIT_W-1:0] flow_head [0:MAX_FLOWS-1];
  logic [FLIT_W-1:0] flow_body [0:MAX_FLOWS-1];
  logic [FLIT_W-1:0] flow_tail [0:MAX_FLOWS-1];

  integer flow_injected_flits [0:MAX_FLOWS-1];
  integer flow_injected_packets [0:MAX_FLOWS-1];
  integer flow_delivered_flits [0:MAX_FLOWS-1];
  integer flow_delivered_packets [0:MAX_FLOWS-1];
  integer flow_latency_samples [0:MAX_FLOWS-1];
  longint unsigned flow_latency_sum_ps [0:MAX_FLOWS-1];
  longint unsigned flow_latency_min_ps [0:MAX_FLOWS-1];
  longint unsigned flow_latency_max_ps [0:MAX_FLOWS-1];
  ps_queue_t flow_head_send_ps [0:MAX_FLOWS-1];

  integer tile_delivered_flits [0:N_QUAD-1];

  integer injected_flits;
  integer injected_packets;
  integer delivered_flits;
  integer delivered_packets;
  integer unexpected_core_flits;
  integer unexpected_top_flits;
  integer boundary_head_count;
  longint unsigned total_latency_sum_ps;
  integer total_latency_samples;
  ps_queue_t latency_samples_ps;

  bit measure_active;
  bit start_traffic;
  bit stop_flows;
  string pattern_name;

  `include "quadtree_and_mesh_dut_inst.vh"
  `QAM_INSTANTIATE_DUT(dut)

  function automatic int min2(input int a, input int b);
    if (a <= b) min2 = a;
    else min2 = b;
  endfunction

  function automatic int core_index(input int x, input int y);
    core_index = x + (y * 8);
  endfunction

  function automatic int q_index_of_global(input int gx, input int gy);
    q_index_of_global = (gx / 8) + ((gy / 8) * EDGE_N);
  endfunction

  function automatic int c_index_of_global(input int gx, input int gy);
    c_index_of_global = core_index(gx % 8, gy % 8);
  endfunction

  function automatic int global_x_of_core(input int q, input int c);
    global_x_of_core = ((q % EDGE_N) * 8) + (c % 8);
  endfunction

  function automatic int global_y_of_core(input int q, input int c);
    global_y_of_core = ((q / EDGE_N) * 8) + (c / 8);
  endfunction

  function automatic [FLIT_W-1:0] mk_flit_rect(
    input bit isHead,
    input bit isTail,
    input [5:0] x0,
    input [5:0] y0,
    input [5:0] x1,
    input [5:0] y1,
    input [1:0] pktId
  );
    mk_flit_rect = {isHead, isTail, y1, x1, y0, x0, pktId};
  endfunction

  function automatic longint unsigned now_ps();
    now_ps = longint'(($realtime * 1000.0) + 0.5);
  endfunction

  function automatic real ps_to_ns(input longint unsigned ps);
    ps_to_ns = ps / 1000.0;
  endfunction

  function automatic int flow_match(
    input int q,
    input int c,
    input logic [1:0] pktId
  );
    int f;
    flow_match = -1;
    for (f = 0; f < CFG_NUM_FLOWS; f = f + 1) begin
      if ((flow_dst_q[f] == q) && (flow_dst_c[f] == c) && (flow_id[f] == pktId)) begin
        flow_match = f;
      end
    end
  endfunction

  function automatic bit is_idle();
    int q;
    int c;
    int e;
    int l;
    bit ok;
    ok = 1'b1;
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        if (core_in_req[q][c] !== core_in_ack[q][c]) ok = 1'b0;
        if (core_out_req[q][c] !== core_out_ack[q][c]) ok = 1'b0;
        if (core_ack_pending[q][c]) ok = 1'b0;
      end
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        if (east_to_req[e][l] !== east_to_ack[e][l]) ok = 1'b0;
        if (north_to_req[e][l] !== north_to_ack[e][l]) ok = 1'b0;
        if (west_to_req[e][l] !== west_to_ack[e][l]) ok = 1'b0;
        if (south_to_req[e][l] !== south_to_ack[e][l]) ok = 1'b0;

        if (east_from_req[e][l] !== east_from_ack[e][l]) ok = 1'b0;
        if (north_from_req[e][l] !== north_from_ack[e][l]) ok = 1'b0;
        if (west_from_req[e][l] !== west_from_ack[e][l]) ok = 1'b0;
        if (south_from_req[e][l] !== south_from_ack[e][l]) ok = 1'b0;

        if (east_from_ack_pending[e][l]) ok = 1'b0;
        if (north_from_ack_pending[e][l]) ok = 1'b0;
        if (west_from_ack_pending[e][l]) ok = 1'b0;
        if (south_from_ack_pending[e][l]) ok = 1'b0;
      end
    end
    is_idle = ok;
  endfunction

  task automatic set_uniform_ack_delay(input int delay_ns);
    int q;
    int c;
    int e;
    int l;
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        core_ack_delay_ns[q][c] = delay_ns;
      end
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        edge_ack_delay_ns[e][l] = delay_ns;
      end
    end
  endtask

  task automatic sample_random_core(output int q, output int c);
    q = $urandom_range(N_QUAD - 1, 0);
    c = $urandom_range(N_CORE - 1, 0);
  endtask

  task automatic configure_pattern_name();
    case (CFG_PATTERN)
      PERF_PATTERN_UNIFORM_UNICAST: pattern_name = "uniform_unicast";
      PERF_PATTERN_LOCAL_UNICAST: pattern_name = "local_unicast";
      PERF_PATTERN_CROSS_TILE_UNICAST: pattern_name = "cross_tile_unicast";
      PERF_PATTERN_HOTSPOT_UNICAST: pattern_name = "hotspot_unicast";
      default: begin
        $fatal(1, "[QAM-PERF] unsupported PERF_PATTERN=%0d", CFG_PATTERN);
      end
    endcase
  endtask

  task automatic build_flow_table();
    bit src_used [0:N_QUAD-1][0:N_CORE-1];
    int q;
    int c;
    int f;
    int tries;
    int tmp_q;
    int tmp_c;
    int dst_q;
    int dst_c;
    int hotspot_q;
    int hotspot_c;

    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        src_used[q][c] = 1'b0;
      end
    end

    hotspot_q = 0;
    hotspot_c = 0;
    if (CFG_PATTERN == PERF_PATTERN_HOTSPOT_UNICAST) begin
      sample_random_core(hotspot_q, hotspot_c);
    end

    for (f = 0; f < CFG_NUM_FLOWS; f = f + 1) begin
      tries = 0;
      do begin
        sample_random_core(tmp_q, tmp_c);
        tries = tries + 1;
        if (tries > 1000) begin
          $fatal(1, "[QAM-PERF] unable to find unique source for flow %0d", f);
        end
      end while (
        src_used[tmp_q][tmp_c] ||
        ((CFG_PATTERN == PERF_PATTERN_HOTSPOT_UNICAST) &&
         (tmp_q == hotspot_q) && (tmp_c == hotspot_c))
      );

      src_used[tmp_q][tmp_c] = 1'b1;
      flow_src_q[f] = tmp_q;
      flow_src_c[f] = tmp_c;

      case (CFG_PATTERN)
        PERF_PATTERN_UNIFORM_UNICAST: begin
          tries = 0;
          do begin
            sample_random_core(dst_q, dst_c);
            tries = tries + 1;
            if (tries > 1000) begin
              $fatal(1, "[QAM-PERF] unable to find destination for flow %0d", f);
            end
          end while ((dst_q == tmp_q) && (dst_c == tmp_c));
        end
        PERF_PATTERN_LOCAL_UNICAST: begin
          dst_q = tmp_q;
          tries = 0;
          do begin
            dst_c = $urandom_range(N_CORE - 1, 0);
            tries = tries + 1;
            if (tries > 1000) begin
              $fatal(1, "[QAM-PERF] unable to find local destination for flow %0d", f);
            end
          end while (dst_c == tmp_c);
        end
        PERF_PATTERN_CROSS_TILE_UNICAST: begin
          tries = 0;
          do begin
            sample_random_core(dst_q, dst_c);
            tries = tries + 1;
            if (tries > 1000) begin
              $fatal(1, "[QAM-PERF] unable to find cross-tile destination for flow %0d", f);
            end
          end while (dst_q == tmp_q);
        end
        PERF_PATTERN_HOTSPOT_UNICAST: begin
          dst_q = hotspot_q;
          dst_c = hotspot_c;
        end
        default: begin
          $fatal(1, "[QAM-PERF] unsupported PERF_PATTERN=%0d", CFG_PATTERN);
        end
      endcase

      flow_dst_q[f] = dst_q;
      flow_dst_c[f] = dst_c;
      flow_src_gx[f] = global_x_of_core(flow_src_q[f], flow_src_c[f]);
      flow_src_gy[f] = global_y_of_core(flow_src_q[f], flow_src_c[f]);
      flow_dst_gx[f] = global_x_of_core(flow_dst_q[f], flow_dst_c[f]);
      flow_dst_gy[f] = global_y_of_core(flow_dst_q[f], flow_dst_c[f]);
      flow_id[f] = f[1:0];

      flow_head[f] = mk_flit_rect(
        1'b1, 1'b0,
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_id[f]
      );
      flow_body[f] = mk_flit_rect(
        1'b0, 1'b0,
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_id[f]
      );
      flow_tail[f] = mk_flit_rect(
        1'b0, 1'b1,
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_dst_gx[f][5:0], flow_dst_gy[f][5:0],
        flow_id[f]
      );
    end
  endtask

  task automatic send_core_flit(
    input int q,
    input int c,
    input logic [FLIT_W-1:0] flit_word,
    input string tag
  );
    time t0;
    core_in_flit[q][c] = flit_word;
    core_in_req[q][c] = ~core_in_req[q][c];
    t0 = $time;
    while (core_in_ack[q][c] !== core_in_req[q][c]) begin
      #1;
      if (($time - t0) > HANDSHAKE_TIMEOUT_NS) begin
        $fatal(1, "[%0s] core_in handshake timeout on q=%0d c=%0d", tag, q, c);
      end
    end
  endtask

  task automatic run_flow(input int flow_idx);
    string tag;
    tag = $sformatf("FLOW%0d", flow_idx);
    wait(start_traffic);
    while (!stop_flows) begin
      send_core_flit(flow_src_q[flow_idx], flow_src_c[flow_idx], flow_head[flow_idx], tag);
      if (measure_active) begin
        injected_flits = injected_flits + 1;
        flow_injected_flits[flow_idx] = flow_injected_flits[flow_idx] + 1;
        flow_head_send_ps[flow_idx].push_back(now_ps());
      end

      send_core_flit(flow_src_q[flow_idx], flow_src_c[flow_idx], flow_body[flow_idx], tag);
      if (measure_active) begin
        injected_flits = injected_flits + 1;
        flow_injected_flits[flow_idx] = flow_injected_flits[flow_idx] + 1;
      end

      send_core_flit(flow_src_q[flow_idx], flow_src_c[flow_idx], flow_tail[flow_idx], tag);
      if (measure_active) begin
        injected_flits = injected_flits + 1;
        injected_packets = injected_packets + 1;
        flow_injected_flits[flow_idx] = flow_injected_flits[flow_idx] + 1;
        flow_injected_packets[flow_idx] = flow_injected_packets[flow_idx] + 1;
      end

      if (CFG_PACKET_GAP_NS > 0) begin
        #(CFG_PACKET_GAP_NS);
      end
    end
  endtask

  task automatic wait_for_idle(input string tag);
    time t0;
    int stable_cycles;
    t0 = $time;
    stable_cycles = 0;
    while (stable_cycles < 20) begin
      #1;
      if (is_idle()) begin
        stable_cycles = stable_cycles + 1;
      end else begin
        stable_cycles = 0;
      end
      if (($time - t0) > GLOBAL_TIMEOUT_NS) begin
        $fatal(1, "[%0s] timeout waiting for idle", tag);
      end
    end
  endtask

  task automatic report_summary();
    ps_queue_t sorted_lat_ps;
    int f;
    int q;
    int pending_heads;
    int idx95;
    int idx99;
    real measure_ns;
    real offered_load;
    real avg_latency_ns;
    real p95_latency_ns;
    real p99_latency_ns;
    real injected_flit_per_ns;
    real injected_pkt_per_ns;
    real delivered_flit_per_ns;
    real delivered_pkt_per_ns;
    real per_flow_avg_ns;

    measure_ns = CFG_MEASURE_NS;
    offered_load = (CFG_PACKET_GAP_NS >= 0) ? (3.0 / (3.0 + CFG_PACKET_GAP_NS)) : 0.0;
    injected_flit_per_ns = injected_flits / measure_ns;
    injected_pkt_per_ns = injected_packets / measure_ns;
    delivered_flit_per_ns = delivered_flits / measure_ns;
    delivered_pkt_per_ns = delivered_packets / measure_ns;

    sorted_lat_ps = latency_samples_ps;
    if (sorted_lat_ps.size() > 0) begin
      sorted_lat_ps.sort();
      idx95 = ((sorted_lat_ps.size() * 95) + 99) / 100 - 1;
      idx99 = ((sorted_lat_ps.size() * 99) + 99) / 100 - 1;
      if (idx95 < 0) idx95 = 0;
      if (idx99 < 0) idx99 = 0;
      if (idx95 >= sorted_lat_ps.size()) idx95 = sorted_lat_ps.size() - 1;
      if (idx99 >= sorted_lat_ps.size()) idx99 = sorted_lat_ps.size() - 1;

      avg_latency_ns = ps_to_ns(total_latency_sum_ps) / total_latency_samples;
      p95_latency_ns = ps_to_ns(sorted_lat_ps[idx95]);
      p99_latency_ns = ps_to_ns(sorted_lat_ps[idx99]);
    end else begin
      avg_latency_ns = 0.0;
      p95_latency_ns = 0.0;
      p99_latency_ns = 0.0;
    end

    pending_heads = 0;
    for (f = 0; f < CFG_NUM_FLOWS; f = f + 1) begin
      pending_heads = pending_heads + flow_head_send_ps[f].size();
    end

    $display("");
    $display("[QAM-PERF] ==== Performance Summary ====");
    $display("[QAM-PERF] pattern=%0s seed=%0d flows=%0d gap_ns=%0d ack_delay_ns=%0d",
      pattern_name, CFG_SEED, CFG_NUM_FLOWS, CFG_PACKET_GAP_NS, CFG_ACK_DELAY_NS);
    $display("[QAM-PERF] warmup_ns=%0d measure_ns=%0d offered_load=%.6f",
      CFG_WARMUP_NS, CFG_MEASURE_NS, offered_load);
    $display("[QAM-PERF] injected_packets=%0d injected_flits=%0d delivered_packets=%0d delivered_flits=%0d",
      injected_packets, injected_flits, delivered_packets, delivered_flits);
    $display("[QAM-PERF] injected_pkt_per_ns=%.6f injected_flit_per_ns=%.6f",
      injected_pkt_per_ns, injected_flit_per_ns);
    $display("[QAM-PERF] throughput_pkt_per_ns=%.6f throughput_flit_per_ns=%.6f",
      delivered_pkt_per_ns, delivered_flit_per_ns);
    $display("[QAM-PERF] avg_latency_ns=%.3f p95_latency_ns=%.3f p99_latency_ns=%.3f samples=%0d",
      avg_latency_ns, p95_latency_ns, p99_latency_ns, total_latency_samples);
    $display("[QAM-PERF] unexpected_core_flits=%0d unexpected_top_flits=%0d boundary_heads=%0d pending_heads=%0d",
      unexpected_core_flits, unexpected_top_flits, boundary_head_count, pending_heads);

    for (q = 0; q < N_QUAD; q = q + 1) begin
      $display("[QAM-PERF] tile=%0d delivered_flits=%0d throughput_flit_per_ns=%.6f",
        q, tile_delivered_flits[q], tile_delivered_flits[q] / measure_ns);
    end

    for (f = 0; f < CFG_NUM_FLOWS; f = f + 1) begin
      if (flow_latency_samples[f] > 0) begin
        per_flow_avg_ns = ps_to_ns(flow_latency_sum_ps[f]) / flow_latency_samples[f];
      end else begin
        per_flow_avg_ns = 0.0;
      end

      $display("[QAM-PERF] flow=%0d src=(q%0d,c%0d,g%0d,%0d) dst=(q%0d,c%0d,g%0d,%0d) id=%0d",
        f,
        flow_src_q[f], flow_src_c[f], flow_src_gx[f], flow_src_gy[f],
        flow_dst_q[f], flow_dst_c[f], flow_dst_gx[f], flow_dst_gy[f],
        flow_id[f]
      );
      $display("[QAM-PERF] flow=%0d injected_pkts=%0d delivered_pkts=%0d injected_flits=%0d delivered_flits=%0d avg_latency_ns=%.3f samples=%0d",
        f,
        flow_injected_packets[f], flow_delivered_packets[f],
        flow_injected_flits[f], flow_delivered_flits[f],
        per_flow_avg_ns, flow_latency_samples[f]
      );
    end

    $display(
      "[QAM-PERF-CSV] dut=quadtree_and_mesh,tb=quadtree_and_mesh_perf_tb,seed=%0d,traffic_pattern=%0s,packet_type=unicast,packet_len=%0d,rect_w=1,rect_h=1,offered_load=%.6f,num_flows=%0d,packet_gap_ns=%0d,ack_delay_ns=%0d,warmup_ns=%0d,measure_ns=%0d,avg_latency_ns=%.3f,p95_latency_ns=%.3f,p99_latency_ns=%.3f,injected_flit_per_ns=%.6f,injected_pkt_per_ns=%.6f,throughput_flit_per_ns=%.6f,throughput_pkt_per_ns=%.6f,injected_packets=%0d,injected_flits=%0d,delivered_packets=%0d,delivered_flits=%0d,unexpected_core_flits=%0d,unexpected_top_flits=%0d,boundary_head_count=%0d,pending_heads=%0d",
      CFG_SEED, pattern_name, PACKET_LEN, offered_load, CFG_NUM_FLOWS, CFG_PACKET_GAP_NS,
      CFG_ACK_DELAY_NS, CFG_WARMUP_NS, CFG_MEASURE_NS,
      avg_latency_ns, p95_latency_ns, p99_latency_ns,
      injected_flit_per_ns, injected_pkt_per_ns,
      delivered_flit_per_ns, delivered_pkt_per_ns,
      injected_packets, injected_flits, delivered_packets, delivered_flits,
      unexpected_core_flits, unexpected_top_flits, boundary_head_count, pending_heads
    );
  endtask

  initial clock = 1'b0;
  always #1 clock = ~clock;

  genvar gq;
  genvar gc;
  generate
    for (gq = 0; gq < N_QUAD; gq = gq + 1) begin : GEN_CORE_MON_Q
      for (gc = 0; gc < N_CORE; gc = gc + 1) begin : GEN_CORE_MON_C
        always @(core_out_req[gq][gc] or reset) begin
          integer dly;
          integer flow_idx;
          logic req_snapshot;
          logic [FLIT_W-1:0] flit_snapshot;
          longint unsigned lat_ps;
          longint unsigned send_ps;

          if (reset) begin
            core_out_ack[gq][gc] <= 1'b0;
            core_ack_pending[gq][gc] <= 1'b0;
          end else if (core_out_req[gq][gc] !== core_out_ack[gq][gc]) begin
            if (core_ack_pending[gq][gc]) begin
              $fatal(1, "[QAM-PERF] overlapping core_out handshake on q=%0d c=%0d", gq, gc);
            end

            flit_snapshot = core_out_flit[gq][gc];
            if (measure_active) begin
              flow_idx = flow_match(gq, gc, flit_snapshot[1:0]);
              if (flow_idx >= 0) begin
                delivered_flits = delivered_flits + 1;
                flow_delivered_flits[flow_idx] = flow_delivered_flits[flow_idx] + 1;
                tile_delivered_flits[gq] = tile_delivered_flits[gq] + 1;

                if (flit_snapshot[27]) begin
                  if (flow_head_send_ps[flow_idx].size() > 0) begin
                    send_ps = flow_head_send_ps[flow_idx].pop_front();
                    lat_ps = now_ps() - send_ps;
                    latency_samples_ps.push_back(lat_ps);
                    total_latency_sum_ps = total_latency_sum_ps + lat_ps;
                    total_latency_samples = total_latency_samples + 1;
                    flow_latency_sum_ps[flow_idx] = flow_latency_sum_ps[flow_idx] + lat_ps;
                    flow_latency_samples[flow_idx] = flow_latency_samples[flow_idx] + 1;
                    if ((flow_latency_samples[flow_idx] == 1) || (lat_ps < flow_latency_min_ps[flow_idx])) begin
                      flow_latency_min_ps[flow_idx] = lat_ps;
                    end
                    if (lat_ps > flow_latency_max_ps[flow_idx]) begin
                      flow_latency_max_ps[flow_idx] = lat_ps;
                    end
                  end else begin
                    boundary_head_count = boundary_head_count + 1;
                  end
                end

                if (flit_snapshot[26]) begin
                  delivered_packets = delivered_packets + 1;
                  flow_delivered_packets[flow_idx] = flow_delivered_packets[flow_idx] + 1;
                end
              end else begin
                unexpected_core_flits = unexpected_core_flits + 1;
              end
            end

            core_ack_pending[gq][gc] <= 1'b1;
            dly = core_ack_delay_ns[gq][gc];
            req_snapshot = core_out_req[gq][gc];
            fork
              begin
                #(dly);
                core_out_ack[gq][gc] <= req_snapshot;
                core_ack_pending[gq][gc] <= 1'b0;
              end
            join_none
          end
        end
      end
    end
  endgenerate

  genvar ge;
  genvar gl;
  generate
    for (ge = 0; ge < EDGE_N; ge = ge + 1) begin : GEN_EDGE_MON_E
      for (gl = 0; gl < TOP_LANE; gl = gl + 1) begin : GEN_EDGE_MON_L
        always @(east_from_req[ge][gl] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            east_from_ack[ge][gl] <= 1'b0;
            east_from_ack_pending[ge][gl] <= 1'b0;
          end else if (east_from_req[ge][gl] !== east_from_ack[ge][gl]) begin
            if (east_from_ack_pending[ge][gl]) begin
              $fatal(1, "[QAM-PERF] overlapping east_from handshake on [%0d][%0d]", ge, gl);
            end
            if (measure_active) begin
              unexpected_top_flits = unexpected_top_flits + 1;
            end
            east_from_ack_pending[ge][gl] <= 1'b1;
            dly = edge_ack_delay_ns[ge][gl];
            req_snapshot = east_from_req[ge][gl];
            fork
              begin
                #(dly);
                east_from_ack[ge][gl] <= req_snapshot;
                east_from_ack_pending[ge][gl] <= 1'b0;
              end
            join_none
          end
        end

        always @(north_from_req[ge][gl] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            north_from_ack[ge][gl] <= 1'b0;
            north_from_ack_pending[ge][gl] <= 1'b0;
          end else if (north_from_req[ge][gl] !== north_from_ack[ge][gl]) begin
            if (north_from_ack_pending[ge][gl]) begin
              $fatal(1, "[QAM-PERF] overlapping north_from handshake on [%0d][%0d]", ge, gl);
            end
            if (measure_active) begin
              unexpected_top_flits = unexpected_top_flits + 1;
            end
            north_from_ack_pending[ge][gl] <= 1'b1;
            dly = edge_ack_delay_ns[ge][gl];
            req_snapshot = north_from_req[ge][gl];
            fork
              begin
                #(dly);
                north_from_ack[ge][gl] <= req_snapshot;
                north_from_ack_pending[ge][gl] <= 1'b0;
              end
            join_none
          end
        end

        always @(west_from_req[ge][gl] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            west_from_ack[ge][gl] <= 1'b0;
            west_from_ack_pending[ge][gl] <= 1'b0;
          end else if (west_from_req[ge][gl] !== west_from_ack[ge][gl]) begin
            if (west_from_ack_pending[ge][gl]) begin
              $fatal(1, "[QAM-PERF] overlapping west_from handshake on [%0d][%0d]", ge, gl);
            end
            if (measure_active) begin
              unexpected_top_flits = unexpected_top_flits + 1;
            end
            west_from_ack_pending[ge][gl] <= 1'b1;
            dly = edge_ack_delay_ns[ge][gl];
            req_snapshot = west_from_req[ge][gl];
            fork
              begin
                #(dly);
                west_from_ack[ge][gl] <= req_snapshot;
                west_from_ack_pending[ge][gl] <= 1'b0;
              end
            join_none
          end
        end

        always @(south_from_req[ge][gl] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            south_from_ack[ge][gl] <= 1'b0;
            south_from_ack_pending[ge][gl] <= 1'b0;
          end else if (south_from_req[ge][gl] !== south_from_ack[ge][gl]) begin
            if (south_from_ack_pending[ge][gl]) begin
              $fatal(1, "[QAM-PERF] overlapping south_from handshake on [%0d][%0d]", ge, gl);
            end
            if (measure_active) begin
              unexpected_top_flits = unexpected_top_flits + 1;
            end
            south_from_ack_pending[ge][gl] <= 1'b1;
            dly = edge_ack_delay_ns[ge][gl];
            req_snapshot = south_from_req[ge][gl];
            fork
              begin
                #(dly);
                south_from_ack[ge][gl] <= req_snapshot;
                south_from_ack_pending[ge][gl] <= 1'b0;
              end
            join_none
          end
        end
      end
    end
  endgenerate

  initial begin
    int q;
    int c;
    int e;
    int l;
    int f;

    if ((CFG_NUM_FLOWS < 1) || (CFG_NUM_FLOWS > MAX_FLOWS)) begin
      $fatal(1, "[QAM-PERF] PERF_NUM_FLOWS must be in [1,%0d], got %0d", MAX_FLOWS, CFG_NUM_FLOWS);
    end
    if (CFG_PACKET_GAP_NS < 0) begin
      $fatal(1, "[QAM-PERF] PERF_PACKET_GAP_NS must be non-negative");
    end
    if (CFG_WARMUP_NS <= 0 || CFG_MEASURE_NS <= 0) begin
      $fatal(1, "[QAM-PERF] PERF_WARMUP_NS and PERF_MEASURE_NS must be positive");
    end

    reset = 1'b1;
    measure_active = 1'b0;
    start_traffic = 1'b0;
    stop_flows = 1'b0;
    injected_flits = 0;
    injected_packets = 0;
    delivered_flits = 0;
    delivered_packets = 0;
    unexpected_core_flits = 0;
    unexpected_top_flits = 0;
    boundary_head_count = 0;
    total_latency_sum_ps = 0;
    total_latency_samples = 0;

    for (q = 0; q < N_QUAD; q = q + 1) begin
      tile_delivered_flits[q] = 0;
      for (c = 0; c < N_CORE; c = c + 1) begin
        core_in_req[q][c] = 1'b0;
        core_in_flit[q][c] = '0;
        core_out_ack[q][c] = 1'b0;
        core_ack_pending[q][c] = 1'b0;
      end
    end

    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        east_to_req[e][l] = 1'b0;
        east_to_flit[e][l] = '0;
        north_to_req[e][l] = 1'b0;
        north_to_flit[e][l] = '0;
        west_to_req[e][l] = 1'b0;
        west_to_flit[e][l] = '0;
        south_to_req[e][l] = 1'b0;
        south_to_flit[e][l] = '0;

        east_from_ack[e][l] = 1'b0;
        north_from_ack[e][l] = 1'b0;
        west_from_ack[e][l] = 1'b0;
        south_from_ack[e][l] = 1'b0;

        east_from_ack_pending[e][l] = 1'b0;
        north_from_ack_pending[e][l] = 1'b0;
        west_from_ack_pending[e][l] = 1'b0;
        south_from_ack_pending[e][l] = 1'b0;
      end
    end

    for (f = 0; f < MAX_FLOWS; f = f + 1) begin
      flow_src_q[f] = 0;
      flow_src_c[f] = 0;
      flow_dst_q[f] = 0;
      flow_dst_c[f] = 0;
      flow_src_gx[f] = 0;
      flow_src_gy[f] = 0;
      flow_dst_gx[f] = 0;
      flow_dst_gy[f] = 0;
      flow_id[f] = '0;
      flow_head[f] = '0;
      flow_body[f] = '0;
      flow_tail[f] = '0;
      flow_injected_flits[f] = 0;
      flow_injected_packets[f] = 0;
      flow_delivered_flits[f] = 0;
      flow_delivered_packets[f] = 0;
      flow_latency_samples[f] = 0;
      flow_latency_sum_ps[f] = 0;
      flow_latency_min_ps[f] = 0;
      flow_latency_max_ps[f] = 0;
    end

    set_uniform_ack_delay(CFG_ACK_DELAY_NS);
    configure_pattern_name();
    #30;
    reset = 1'b0;
    build_flow_table();

    $display("[QAM-PERF] reset released at t=%0t", $time);
    $display("[QAM-PERF] seed=%0d pattern=%0s flows=%0d gap_ns=%0d ack_delay_ns=%0d warmup_ns=%0d measure_ns=%0d",
      CFG_SEED, pattern_name, CFG_NUM_FLOWS, CFG_PACKET_GAP_NS, CFG_ACK_DELAY_NS, CFG_WARMUP_NS, CFG_MEASURE_NS
    );
    for (f = 0; f < CFG_NUM_FLOWS; f = f + 1) begin
      $display("[QAM-PERF] flow=%0d src=(q%0d,c%0d,g%0d,%0d) dst=(q%0d,c%0d,g%0d,%0d) id=%0d",
        f,
        flow_src_q[f], flow_src_c[f], flow_src_gx[f], flow_src_gy[f],
        flow_dst_q[f], flow_dst_c[f], flow_dst_gx[f], flow_dst_gy[f],
        flow_id[f]
      );
    end

    fork
      if (CFG_NUM_FLOWS > 0) run_flow(0);
      if (CFG_NUM_FLOWS > 1) run_flow(1);
      if (CFG_NUM_FLOWS > 2) run_flow(2);
      if (CFG_NUM_FLOWS > 3) run_flow(3);
    join_none

    start_traffic = 1'b1;

    #(CFG_WARMUP_NS);
    measure_active = 1'b1;
    $display("[QAM-PERF] measurement window started at t=%0t", $time);

    #(CFG_MEASURE_NS);
    measure_active = 1'b0;
    stop_flows = 1'b1;
    $display("[QAM-PERF] measurement window ended at t=%0t", $time);

    wait_for_idle("QAM perf drain");
    report_summary();

    if ((unexpected_core_flits != 0) || (unexpected_top_flits != 0)) begin
      $fatal(1, "[QAM-PERF] unexpected traffic observed during performance run");
    end

    #10;
    $finish;
  end
endmodule

`default_nettype wire

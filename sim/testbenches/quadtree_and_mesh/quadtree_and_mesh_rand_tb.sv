`timescale 1ns/1ps
`default_nettype none
`include "quadtree_and_mesh_rand_cfg.vh"

`ifndef RAND_SEED
`define RAND_SEED 1379260429
`endif

`ifndef RAND_NUM_CASES
`define RAND_NUM_CASES 24
`endif

`ifndef RAND_MAX_PKTS
`define RAND_MAX_PKTS 3
`endif

module quadtree_and_mesh_rand_tb;
  localparam int FLIT_W = 28;
  localparam int N_QUAD = 4;      // 2x2 tree tiles
  localparam int N_CORE = 64;     // per tile
  localparam int EDGE_N = 2;      // 2 rows / 2 cols
  localparam int TOP_LANE = 4;
  localparam int MAX_RX_PER_PORT = 1024;
  localparam int DEFAULT_ACK_DELAY_NS = 1;
  localparam int HANDSHAKE_TIMEOUT_NS = 500000;
  localparam int GLOBAL_TIMEOUT_NS = 8000000;
  localparam int SRC_KIND_CORE = 0;
  localparam int SRC_KIND_WEST = 1;

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

  integer core_rx_count [0:N_QUAD-1][0:N_CORE-1];
  reg [FLIT_W-1:0] core_rx_mem [0:N_QUAD-1][0:N_CORE-1][0:MAX_RX_PER_PORT-1];
  time core_rx_time [0:N_QUAD-1][0:N_CORE-1][0:MAX_RX_PER_PORT-1];
  logic core_ack_pending [0:N_QUAD-1][0:N_CORE-1];
  integer core_ack_delay_ns [0:N_QUAD-1][0:N_CORE-1];

  integer east_from_rx_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer north_from_rx_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer west_from_rx_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer south_from_rx_count [0:EDGE_N-1][0:TOP_LANE-1];

  logic east_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic north_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic west_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];
  logic south_from_ack_pending [0:EDGE_N-1][0:TOP_LANE-1];

  integer edge_ack_delay_ns [0:EDGE_N-1][0:TOP_LANE-1];

  integer base_core_count [0:N_QUAD-1][0:N_CORE-1];
  integer exp_core_flits [0:N_QUAD-1][0:N_CORE-1];

  integer base_east_from_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer base_north_from_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer base_west_from_count [0:EDGE_N-1][0:TOP_LANE-1];
  integer base_south_from_count [0:EDGE_N-1][0:TOP_LANE-1];

  `include "quadtree_and_mesh_dut_inst.vh"
  `QAM_INSTANTIATE_DUT(dut)

  function automatic int min2(input int a, input int b);
    if (a <= b) min2 = a;
    else min2 = b;
  endfunction

  function automatic int max2(input int a, input int b);
    if (a >= b) max2 = a;
    else max2 = b;
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

  function automatic bit point_in_rect(
    input int px,
    input int py,
    input int x0,
    input int y0,
    input int x1,
    input int y1
  );
    int xLo;
    int xHi;
    int yLo;
    int yHi;
    xLo = min2(x0, x1);
    xHi = max2(x0, x1);
    yLo = min2(y0, y1);
    yHi = max2(y0, y1);
    point_in_rect = ((px >= xLo) && (px <= xHi) && (py >= yLo) && (py <= yHi));
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
    // payload[27]:isHead payload[26]:isTail
    // payload[25:20]:y1 payload[19:14]:x1
    // payload[13:8]:y0  payload[7:2]:x0
    // payload[1:0]:id
    mk_flit_rect = {
      isHead,
      isTail,
      y1,
      x1,
      y0,
      x0,
      pktId
    };
  endfunction

  function automatic int core_id_count(
    input int q,
    input int c,
    input int base_idx,
    input [1:0] pktId
  );
    int idx;
    int cnt;
    cnt = 0;
    for (idx = base_idx; idx < core_rx_count[q][c]; idx = idx + 1) begin
      if (core_rx_mem[q][c][idx][1:0] == pktId) begin
        cnt = cnt + 1;
      end
    end
    core_id_count = cnt;
  endfunction

  function automatic time core_time_of_id_n(
    input int q,
    input int c,
    input int base_idx,
    input [1:0] pktId,
    input int nth
  );
    int idx;
    int seen;
    time t;
    seen = 0;
    t = 0;
    for (idx = base_idx; idx < core_rx_count[q][c]; idx = idx + 1) begin
      if (core_rx_mem[q][c][idx][1:0] == pktId) begin
        seen = seen + 1;
        if (seen == nth) begin
          t = core_rx_time[q][c][idx];
        end
      end
    end
    core_time_of_id_n = t;
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

  task automatic set_default_ack_delay();
    int q;
    int c;
    int e;
    int l;
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        core_ack_delay_ns[q][c] = DEFAULT_ACK_DELAY_NS;
      end
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        edge_ack_delay_ns[e][l] = DEFAULT_ACK_DELAY_NS;
      end
    end
  endtask

  task automatic clear_expected();
    int q;
    int c;
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        exp_core_flits[q][c] = 0;
      end
    end
  endtask

  task automatic begin_case(input string case_name);
    int q;
    int c;
    int e;
    int l;
    $display("\n[QAM-TB] ==== %0s ====", case_name);
    clear_expected();
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        base_core_count[q][c] = core_rx_count[q][c];
      end
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        base_east_from_count[e][l] = east_from_rx_count[e][l];
        base_north_from_count[e][l] = north_from_rx_count[e][l];
        base_west_from_count[e][l] = west_from_rx_count[e][l];
        base_south_from_count[e][l] = south_from_rx_count[e][l];
      end
    end
  endtask

  task automatic expect_core_flits(input int q, input int c, input int flit_count);
    exp_core_flits[q][c] = exp_core_flits[q][c] + flit_count;
  endtask

  task automatic expect_global_flits(input int gx, input int gy, input int flit_count);
    int q;
    int c;
    if ((gx < 0) || (gy < 0) || (gx >= (EDGE_N * 8)) || (gy >= (EDGE_N * 8))) begin
      return;
    end
    q = q_index_of_global(gx, gy);
    c = c_index_of_global(gx, gy);
    expect_core_flits(q, c, flit_count);
  endtask

  task automatic expect_global_rect_flits(
    input int x0,
    input int x1,
    input int y0,
    input int y1,
    input int flit_count
  );
    int xLo;
    int xHi;
    int yLo;
    int yHi;
    int gx;
    int gy;
    xLo = min2(x0, x1);
    xHi = max2(x0, x1);
    yLo = min2(y0, y1);
    yHi = max2(y0, y1);
    for (gy = yLo; gy <= yHi; gy = gy + 1) begin
      for (gx = xLo; gx <= xHi; gx = gx + 1) begin
        expect_global_flits(gx, gy, flit_count);
      end
    end
  endtask

  task automatic check_expected_counts(input string tag);
    int q;
    int c;
    int e;
    int l;
    int got;
    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        got = core_rx_count[q][c] - base_core_count[q][c];
        if (got != exp_core_flits[q][c]) begin
          $fatal(
            1,
            "[%0s] core_out[q=%0d][c=%0d] expected %0d flits, got %0d",
            tag, q, c, exp_core_flits[q][c], got
          );
        end
      end
    end

    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < TOP_LANE; l = l + 1) begin
        if ((east_from_rx_count[e][l] - base_east_from_count[e][l]) != 0) begin
          $fatal(1, "[%0s] unexpected east_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((north_from_rx_count[e][l] - base_north_from_count[e][l]) != 0) begin
          $fatal(1, "[%0s] unexpected north_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((west_from_rx_count[e][l] - base_west_from_count[e][l]) != 0) begin
          $fatal(1, "[%0s] unexpected west_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((south_from_rx_count[e][l] - base_south_from_count[e][l]) != 0) begin
          $fatal(1, "[%0s] unexpected south_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
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

  task automatic send_core_flit(
    input int q,
    input int c,
    input [FLIT_W-1:0] flit_word,
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

  task automatic send_core_packet3(
    input int q,
    input int c,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input string tag
  );
    send_core_flit(q, c, head_flit, tag);
    send_core_flit(q, c, body_flit, tag);
    send_core_flit(q, c, tail_flit, tag);
  endtask

  task automatic send_core_packet3_bubble(
    input int q,
    input int c,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input int gap_ns,
    input string tag
  );
    send_core_flit(q, c, head_flit, tag);
    #(gap_ns);
    send_core_flit(q, c, body_flit, tag);
    #(gap_ns);
    send_core_flit(q, c, tail_flit, tag);
  endtask

  task automatic send_west_to_flit(
    input int y,
    input int lane,
    input [FLIT_W-1:0] flit_word,
    input string tag
  );
    time t0;
    west_to_flit[y][lane] = flit_word;
    west_to_req[y][lane] = ~west_to_req[y][lane];
    t0 = $time;
    while (west_to_ack[y][lane] !== west_to_req[y][lane]) begin
      #1;
      if (($time - t0) > HANDSHAKE_TIMEOUT_NS) begin
        $fatal(1, "[%0s] west_toPE handshake timeout on y=%0d lane=%0d", tag, y, lane);
      end
    end
  endtask

  task automatic send_west_to_packet3(
    input int y,
    input int lane,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input string tag
  );
    send_west_to_flit(y, lane, head_flit, tag);
    send_west_to_flit(y, lane, body_flit, tag);
    send_west_to_flit(y, lane, tail_flit, tag);
  endtask

  task automatic send_west_to_packet3_bubble(
    input int y,
    input int lane,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input int gap_ns,
    input string tag
  );
    send_west_to_flit(y, lane, head_flit, tag);
    #(gap_ns);
    send_west_to_flit(y, lane, body_flit, tag);
    #(gap_ns);
    send_west_to_flit(y, lane, tail_flit, tag);
  endtask

  task automatic launch_packet3(
    input int src_kind,
    input int src_a,
    input int src_b,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input int gap_ns,
    input string tag
  );
    if (src_kind == SRC_KIND_CORE) begin
      if (gap_ns > 0) begin
        send_core_packet3_bubble(src_a, src_b, head_flit, body_flit, tail_flit, gap_ns, tag);
      end else begin
        send_core_packet3(src_a, src_b, head_flit, body_flit, tail_flit, tag);
      end
    end else begin
      if (gap_ns > 0) begin
        send_west_to_packet3_bubble(src_a, src_b, head_flit, body_flit, tail_flit, gap_ns, tag);
      end else begin
        send_west_to_packet3(src_a, src_b, head_flit, body_flit, tail_flit, tag);
      end
    end
  endtask

  task automatic check_core_triplet(
    input string tag,
    input int q,
    input int c,
    input [FLIT_W-1:0] h,
    input [FLIT_W-1:0] b,
    input [FLIT_W-1:0] t
  );
    int base_idx;
    base_idx = base_core_count[q][c];
    if ((core_rx_count[q][c] - base_idx) < 3) begin
      $fatal(1, "[%0s] core_out[q=%0d][c=%0d] has fewer than 3 flits", tag, q, c);
    end
    if (core_rx_mem[q][c][base_idx + 0] !== h) begin
      $fatal(1, "[%0s] core_out[q=%0d][c=%0d] head flit mismatch", tag, q, c);
    end
    if (core_rx_mem[q][c][base_idx + 1] !== b) begin
      $fatal(1, "[%0s] core_out[q=%0d][c=%0d] body flit mismatch", tag, q, c);
    end
    if (core_rx_mem[q][c][base_idx + 2] !== t) begin
      $fatal(1, "[%0s] core_out[q=%0d][c=%0d] tail flit mismatch", tag, q, c);
    end
  endtask

  task automatic check_global_triplet(
    input string tag,
    input int gx,
    input int gy,
    input [FLIT_W-1:0] h,
    input [FLIT_W-1:0] b,
    input [FLIT_W-1:0] t
  );
    int q;
    int c;
    q = q_index_of_global(gx, gy);
    c = c_index_of_global(gx, gy);
    check_core_triplet(tag, q, c, h, b, t);
  endtask

  task automatic check_core_id_triplet(
    input string tag,
    input int q,
    input int c,
    input int base_idx,
    input [1:0] pktId
  );
    int k;
    int state;
    reg [FLIT_W-1:0] f;
    state = 0;
    for (k = base_idx; k < core_rx_count[q][c]; k = k + 1) begin
      f = core_rx_mem[q][c][k];
      if (f[1:0] == pktId) begin
        case (state)
          0: begin
            if (!(f[27] == 1'b1 && f[26] == 1'b0)) begin
              $fatal(1, "[%0s] core_out[q=%0d][c=%0d] id=%0d head format error", tag, q, c, pktId);
            end
            state = 1;
          end
          1: begin
            if (!(f[27] == 1'b0 && f[26] == 1'b0)) begin
              $fatal(1, "[%0s] core_out[q=%0d][c=%0d] id=%0d body format error", tag, q, c, pktId);
            end
            state = 2;
          end
          2: begin
            if (!(f[27] == 1'b0 && f[26] == 1'b1)) begin
              $fatal(1, "[%0s] core_out[q=%0d][c=%0d] id=%0d tail format error", tag, q, c, pktId);
            end
            state = 3;
          end
          default: begin
            $fatal(1, "[%0s] core_out[q=%0d][c=%0d] id=%0d more than 3 flits", tag, q, c, pktId);
          end
        endcase
      end
    end
    if (state != 3) begin
      $fatal(1, "[%0s] core_out[q=%0d][c=%0d] id=%0d incomplete triplet", tag, q, c, pktId);
    end
  endtask

  task automatic check_global_id_triplet(
    input string tag,
    input int gx,
    input int gy,
    input int base_idx,
    input [1:0] pktId
  );
    int q;
    int c;
    q = q_index_of_global(gx, gy);
    c = c_index_of_global(gx, gy);
    check_core_id_triplet(tag, q, c, base_idx, pktId);
  endtask

  task automatic check_packet_rect_delivery(
    input string tag,
    input int x0,
    input int y0,
    input int x1,
    input int y1,
    input [1:0] pktId
  );
    int xLo;
    int xHi;
    int yLo;
    int yHi;
    int gx;
    int gy;
    int q;
    int c;
    int base_idx;
    xLo = min2(x0, x1);
    xHi = max2(x0, x1);
    yLo = min2(y0, y1);
    yHi = max2(y0, y1);
    for (gy = yLo; gy <= yHi; gy = gy + 1) begin
      for (gx = xLo; gx <= xHi; gx = gx + 1) begin
        q = q_index_of_global(gx, gy);
        c = c_index_of_global(gx, gy);
        base_idx = base_core_count[q][c];
        if (core_id_count(q, c, base_idx, pktId) != 3) begin
          $fatal(
            1,
            "[%0s] global(%0d,%0d) expected one id=%0d triplet",
            tag, gx, gy, pktId
          );
        end
        check_global_id_triplet(tag, gx, gy, base_idx, pktId);
      end
    end
  endtask

  initial clock = 1'b0;
  always #1 clock = ~clock;

  genvar gq;
  genvar gc;
  generate
    for (gq = 0; gq < N_QUAD; gq = gq + 1) begin : GEN_CORE_MON_Q
      for (gc = 0; gc < N_CORE; gc = gc + 1) begin : GEN_CORE_MON_C
        always @(core_out_req[gq][gc] or reset) begin
          integer idx;
          integer dly;
          logic req_snapshot;
          if (reset) begin
            core_out_ack[gq][gc] <= 1'b0;
            core_ack_pending[gq][gc] <= 1'b0;
          end else if (core_out_req[gq][gc] !== core_out_ack[gq][gc]) begin
            if (core_ack_pending[gq][gc]) begin
              $fatal(1, "[MON] overlapping core_out handshake on q=%0d c=%0d", gq, gc);
            end
            idx = core_rx_count[gq][gc];
            if (idx < MAX_RX_PER_PORT) begin
              core_rx_mem[gq][gc][idx] = core_out_flit[gq][gc];
              core_rx_time[gq][gc][idx] = $time;
            end
            core_rx_count[gq][gc] = idx + 1;
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
              $fatal(1, "[MON] overlapping east_from handshake on [%0d][%0d]", ge, gl);
            end
            east_from_rx_count[ge][gl] = east_from_rx_count[ge][gl] + 1;
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
              $fatal(1, "[MON] overlapping north_from handshake on [%0d][%0d]", ge, gl);
            end
            north_from_rx_count[ge][gl] = north_from_rx_count[ge][gl] + 1;
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
              $fatal(1, "[MON] overlapping west_from handshake on [%0d][%0d]", ge, gl);
            end
            west_from_rx_count[ge][gl] = west_from_rx_count[ge][gl] + 1;
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
              $fatal(1, "[MON] overlapping south_from handshake on [%0d][%0d]", ge, gl);
            end
            south_from_rx_count[ge][gl] = south_from_rx_count[ge][gl] + 1;
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
    int seed;
    int num_cases;
    int max_packets;
    int case_idx;
    int pkt_count;
    int pkt;
    int prev;
    int tries;
    int slow_count;
    int slow_idx;
    int shape_sel;
    int slow_gx;
    int slow_gy;
    int slow_q;
    int slow_c;
    int src_kind [0:2];
    int src_a [0:2];
    int src_b [0:2];
    int src_gx [0:2];
    int src_gy [0:2];
    int gap_ns [0:2];
    int rect_x_lo [0:2];
    int rect_x_hi [0:2];
    int rect_y_lo [0:2];
    int rect_y_hi [0:2];
    int rect_x0 [0:2];
    int rect_x1 [0:2];
    int rect_y0 [0:2];
    int rect_y1 [0:2];
    bit duplicate_src;
    logic [1:0] pkt_id [0:2];
    logic [FLIT_W-1:0] h [0:2];
    logic [FLIT_W-1:0] b [0:2];
    logic [FLIT_W-1:0] t [0:2];
    string case_tag;
    string pkt_tag [0:2];

    seed = `RAND_SEED;
    num_cases = `RAND_NUM_CASES;
    max_packets = `RAND_MAX_PKTS;
    if (num_cases < 1) num_cases = 1;
    if (max_packets < 1) max_packets = 1;
    if (max_packets > 3) max_packets = 3;

    reset = 1'b1;

    for (q = 0; q < N_QUAD; q = q + 1) begin
      for (c = 0; c < N_CORE; c = c + 1) begin
        core_in_req[q][c] = 1'b0;
        core_in_flit[q][c] = '0;
        core_out_ack[q][c] = 1'b0;
        core_ack_pending[q][c] = 1'b0;
        core_rx_count[q][c] = 0;
        exp_core_flits[q][c] = 0;
        base_core_count[q][c] = 0;
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

        east_from_rx_count[e][l] = 0;
        north_from_rx_count[e][l] = 0;
        west_from_rx_count[e][l] = 0;
        south_from_rx_count[e][l] = 0;

        base_east_from_count[e][l] = 0;
        base_north_from_count[e][l] = 0;
        base_west_from_count[e][l] = 0;
        base_south_from_count[e][l] = 0;
      end
    end

    set_default_ack_delay();
    #30;
    reset = 1'b0;
    $display("[QAM-RAND] reset released at t=%0t ns", $time);
    $display("[QAM-RAND] seed=%0d cases=%0d max_packets=%0d", seed, num_cases, max_packets);

    for (case_idx = 0; case_idx < num_cases; case_idx = case_idx + 1) begin
      set_default_ack_delay();
      slow_count = $urandom_range(2, 0);
      for (slow_idx = 0; slow_idx < slow_count; slow_idx = slow_idx + 1) begin
        slow_gx = $urandom_range((EDGE_N * 8) - 1, 0);
        slow_gy = $urandom_range((EDGE_N * 8) - 1, 0);
        slow_q = q_index_of_global(slow_gx, slow_gy);
        slow_c = c_index_of_global(slow_gx, slow_gy);
        core_ack_delay_ns[slow_q][slow_c] = 40 + (20 * $urandom_range(4, 1));
      end

      if (max_packets == 1) begin
        pkt_count = 1;
      end else begin
        pkt_count = 1 + $urandom_range(max_packets - 1, 0);
      end

      for (pkt = 0; pkt < pkt_count; pkt = pkt + 1) begin
        pkt_id[pkt] = pkt[1:0];
        pkt_tag[pkt] = $sformatf("R%0d-P%0d", case_idx, pkt);
        src_kind[pkt] = ($urandom_range(99, 0) < 75) ? SRC_KIND_CORE : SRC_KIND_WEST;

        tries = 0;
        duplicate_src = 1'b0;
        do begin
          if (src_kind[pkt] == SRC_KIND_CORE) begin
            src_a[pkt] = $urandom_range(N_QUAD - 1, 0);
            src_b[pkt] = $urandom_range(N_CORE - 1, 0);
          end else begin
            src_a[pkt] = $urandom_range(EDGE_N - 1, 0);
            src_b[pkt] = $urandom_range(TOP_LANE - 1, 0);
          end

          duplicate_src = 1'b0;
          for (prev = 0; prev < pkt; prev = prev + 1) begin
            if ((src_kind[prev] == src_kind[pkt]) &&
                (src_a[prev] == src_a[pkt]) &&
                (src_b[prev] == src_b[pkt])) begin
              duplicate_src = 1'b1;
            end
          end
          tries = tries + 1;
        end while (duplicate_src && (tries < 20));

        if (src_kind[pkt] == SRC_KIND_CORE) begin
          src_gx[pkt] = global_x_of_core(src_a[pkt], src_b[pkt]);
          src_gy[pkt] = global_y_of_core(src_a[pkt], src_b[pkt]);
        end else begin
          src_gx[pkt] = -1;
          src_gy[pkt] = -1;
        end

        tries = 0;
        do begin
          shape_sel = $urandom_range(99, 0);
          if (shape_sel < 35) begin
            rect_x_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_x_hi[pkt] = rect_x_lo[pkt];
            rect_y_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_y_hi[pkt] = rect_y_lo[pkt];
          end else if (shape_sel < 65) begin
            rect_x_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_y_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_x_hi[pkt] = min2((EDGE_N * 8) - 1, rect_x_lo[pkt] + $urandom_range(2, 0));
            rect_y_hi[pkt] = min2((EDGE_N * 8) - 1, rect_y_lo[pkt] + $urandom_range(2, 0));
          end else if (shape_sel < 85) begin
            rect_x_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_y_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_x_hi[pkt] = min2((EDGE_N * 8) - 1, rect_x_lo[pkt] + $urandom_range(5, 1));
            rect_y_hi[pkt] = min2((EDGE_N * 8) - 1, rect_y_lo[pkt] + $urandom_range(5, 1));
          end else begin
            rect_x_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_y_lo[pkt] = $urandom_range((EDGE_N * 8) - 1, 0);
            rect_x_hi[pkt] = min2((EDGE_N * 8) - 1, rect_x_lo[pkt] + $urandom_range(8, 3));
            rect_y_hi[pkt] = min2((EDGE_N * 8) - 1, rect_y_lo[pkt] + $urandom_range(8, 3));
          end
          tries = tries + 1;
        end while ((src_kind[pkt] == SRC_KIND_CORE) &&
                    point_in_rect(
                      src_gx[pkt], src_gy[pkt],
                      rect_x_lo[pkt], rect_y_lo[pkt], rect_x_hi[pkt], rect_y_hi[pkt]
                    ) &&
                    (tries < 20));

        if ((src_kind[pkt] == SRC_KIND_CORE) &&
            point_in_rect(
              src_gx[pkt], src_gy[pkt],
              rect_x_lo[pkt], rect_y_lo[pkt], rect_x_hi[pkt], rect_y_hi[pkt]
            )) begin
          rect_x_lo[pkt] = (src_gx[pkt] + 1 + $urandom_range((EDGE_N * 8) - 2, 0)) % (EDGE_N * 8);
          rect_x_hi[pkt] = rect_x_lo[pkt];
          rect_y_lo[pkt] = (src_gy[pkt] + 1 + $urandom_range((EDGE_N * 8) - 2, 0)) % (EDGE_N * 8);
          rect_y_hi[pkt] = rect_y_lo[pkt];
        end

        if ($urandom_range(1, 0)) begin
          rect_x0[pkt] = rect_x_hi[pkt];
          rect_x1[pkt] = rect_x_lo[pkt];
        end else begin
          rect_x0[pkt] = rect_x_lo[pkt];
          rect_x1[pkt] = rect_x_hi[pkt];
        end

        if ($urandom_range(1, 0)) begin
          rect_y0[pkt] = rect_y_hi[pkt];
          rect_y1[pkt] = rect_y_lo[pkt];
        end else begin
          rect_y0[pkt] = rect_y_lo[pkt];
          rect_y1[pkt] = rect_y_hi[pkt];
        end

        gap_ns[pkt] = ($urandom_range(99, 0) < 30) ? (10 * $urandom_range(1, 5)) : 0;

        h[pkt] = mk_flit_rect(1'b1, 1'b0, rect_x0[pkt][5:0], rect_y0[pkt][5:0], rect_x1[pkt][5:0], rect_y1[pkt][5:0], pkt_id[pkt]);
        b[pkt] = mk_flit_rect(1'b0, 1'b0, rect_x0[pkt][5:0], rect_y0[pkt][5:0], rect_x1[pkt][5:0], rect_y1[pkt][5:0], pkt_id[pkt]);
        t[pkt] = mk_flit_rect(1'b0, 1'b1, rect_x0[pkt][5:0], rect_y0[pkt][5:0], rect_x1[pkt][5:0], rect_y1[pkt][5:0], pkt_id[pkt]);
      end

      case_tag = $sformatf("R%0d random correctness pkts=%0d slow=%0d", case_idx, pkt_count, slow_count);
      begin_case(case_tag);
      for (pkt = 0; pkt < pkt_count; pkt = pkt + 1) begin
        expect_global_rect_flits(rect_x0[pkt], rect_x1[pkt], rect_y0[pkt], rect_y1[pkt], 3);
        if (src_kind[pkt] == SRC_KIND_CORE) begin
          $display(
            "[QAM-RAND] %0s src=core(q=%0d,c=%0d,g=(%0d,%0d)) rect=(%0d,%0d)->(%0d,%0d) id=%0d gap=%0d",
            pkt_tag[pkt], src_a[pkt], src_b[pkt], src_gx[pkt], src_gy[pkt],
            rect_x0[pkt], rect_y0[pkt], rect_x1[pkt], rect_y1[pkt], pkt_id[pkt], gap_ns[pkt]
          );
        end else begin
          $display(
            "[QAM-RAND] %0s src=west(y=%0d,lane=%0d) rect=(%0d,%0d)->(%0d,%0d) id=%0d gap=%0d",
            pkt_tag[pkt], src_a[pkt], src_b[pkt],
            rect_x0[pkt], rect_y0[pkt], rect_x1[pkt], rect_y1[pkt], pkt_id[pkt], gap_ns[pkt]
          );
        end
      end

      case (pkt_count)
        1: begin
          launch_packet3(src_kind[0], src_a[0], src_b[0], h[0], b[0], t[0], gap_ns[0], pkt_tag[0]);
        end
        2: begin
          fork
            launch_packet3(src_kind[0], src_a[0], src_b[0], h[0], b[0], t[0], gap_ns[0], pkt_tag[0]);
            launch_packet3(src_kind[1], src_a[1], src_b[1], h[1], b[1], t[1], gap_ns[1], pkt_tag[1]);
          join
        end
        default: begin
          fork
            launch_packet3(src_kind[0], src_a[0], src_b[0], h[0], b[0], t[0], gap_ns[0], pkt_tag[0]);
            launch_packet3(src_kind[1], src_a[1], src_b[1], h[1], b[1], t[1], gap_ns[1], pkt_tag[1]);
            launch_packet3(src_kind[2], src_a[2], src_b[2], h[2], b[2], t[2], gap_ns[2], pkt_tag[2]);
          join
        end
      endcase

      wait_for_idle(case_tag);
      check_expected_counts(case_tag);
      for (pkt = 0; pkt < pkt_count; pkt = pkt + 1) begin
        check_packet_rect_delivery(case_tag, rect_x0[pkt], rect_y0[pkt], rect_x1[pkt], rect_y1[pkt], pkt_id[pkt]);
      end
    end

    set_default_ack_delay();
    $display("\n[QAM-RAND] all random quadtree_and_mesh tests PASSED");
    #10;
    $finish;
  end
endmodule

`default_nettype wire

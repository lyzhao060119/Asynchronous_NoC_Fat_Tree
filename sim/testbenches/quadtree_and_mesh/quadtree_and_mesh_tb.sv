`timescale 1ns/1ps
`default_nettype none

module quadtree_and_mesh_tb;
  localparam int FLIT_W = 28;
  localparam int N_QUAD = 4;      // 2x2 tree tiles
  localparam int N_CORE = 64;     // per tile
  localparam int EDGE_N = 2;      // 2 rows / 2 cols
  localparam int TOP_LANE = 4;
  localparam int MAX_RX_PER_PORT = 1024;
  localparam int DEFAULT_ACK_DELAY_NS = 1;
  localparam int HANDSHAKE_TIMEOUT_NS = 500000;
  localparam int GLOBAL_TIMEOUT_NS = 8000000;

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
    reg [FLIT_W-1:0] h0;
    reg [FLIT_W-1:0] b0;
    reg [FLIT_W-1:0] t0;
    reg [FLIT_W-1:0] h1;
    reg [FLIT_W-1:0] b1;
    reg [FLIT_W-1:0] t1;
    reg [FLIT_W-1:0] h2;
    reg [FLIT_W-1:0] b2;
    reg [FLIT_W-1:0] t2;
    int base_idx;
    int q_hot;
    int c_hot;
    time t_head_slow;
    time t_body_slow;
    time t_tail_slow;

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
    $display("[QAM-TB] reset released at t=%0t ns", $time);

    // T1) Same-tree multi-flit unicast: q1 core0 -> q1 core63 (global 15,7)
    begin_case("T1 same-tree unicast q1 core0->core63");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd15, 6'd7, 6'd15, 6'd7, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd15, 6'd7, 6'd15, 6'd7, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd15, 6'd7, 6'd15, 6'd7, 2'd1);
    expect_global_flits(15, 7, 3);
    send_core_packet3(1, 0, h0, b0, t0, "T1");
    wait_for_idle("T1");
    check_expected_counts("T1");
    check_global_triplet("T1", 15, 7, h0, b0, t0);

    // T2) Cross-tree multi-flit unicast: q0 core0 -> q3 core63 (global 15,15)
    begin_case("T2 cross-tree unicast q0 core0->q3 core63");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    expect_global_flits(15, 15, 3);
    send_core_packet3(0, 0, h0, b0, t0, "T2");
    wait_for_idle("T2");
    check_expected_counts("T2");
    check_global_triplet("T2", 15, 15, h0, b0, t0);

    // T3) Cross-tree rectangle multicast across boundaries: x6..9, y6..9
    begin_case("T3 cross-tree multicast rect x6..9 y6..9");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd6, 6'd6, 6'd9, 6'd9, 2'd3);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd6, 6'd6, 6'd9, 6'd9, 2'd3);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd6, 6'd6, 6'd9, 6'd9, 2'd3);
    expect_global_rect_flits(6, 9, 6, 9, 3);
    send_core_packet3(0, 1, h0, b0, t0, "T3");
    wait_for_idle("T3");
    check_expected_counts("T3");
    check_global_triplet("T3", 6, 6, h0, b0, t0);
    check_global_triplet("T3", 8, 6, h0, b0, t0);
    check_global_triplet("T3", 6, 8, h0, b0, t0);
    check_global_triplet("T3", 8, 8, h0, b0, t0);

    // T4) Two unicast packets contending for same destination (global 15,15)
    begin_case("T4 cross-tree unicast contention same destination");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd15, 6'd15, 6'd15, 6'd15, 2'd1);
    h1 = mk_flit_rect(1'b1, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    b1 = mk_flit_rect(1'b0, 1'b0, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    t1 = mk_flit_rect(1'b0, 1'b1, 6'd15, 6'd15, 6'd15, 6'd15, 2'd2);
    expect_global_flits(15, 15, 6);
    fork
      send_core_packet3(0, 2, h0, b0, t0, "T4-A");
      send_core_packet3(1, 61, h1, b1, t1, "T4-B");
    join
    wait_for_idle("T4");
    check_expected_counts("T4");
    base_idx = base_core_count[3][63];
    if (core_id_count(3, 63, base_idx, 2'b01) != 3) begin
      $fatal(1, "[T4] q3 core63 id=1 flit count mismatch");
    end
    if (core_id_count(3, 63, base_idx, 2'b10) != 3) begin
      $fatal(1, "[T4] q3 core63 id=2 flit count mismatch");
    end

    // T5) Injection from west boundary PE into local trees
    begin_case("T5 west boundary injection to q2 core(1,2)");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd1, 6'd10, 6'd1, 6'd10, 2'd0);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd1, 6'd10, 6'd1, 6'd10, 2'd0);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd1, 6'd10, 6'd1, 6'd10, 2'd0);
    expect_global_flits(1, 10, 3);
    send_west_to_packet3(1, 0, h0, b0, t0, "T5");
    wait_for_idle("T5");
    check_expected_counts("T5");
    check_global_triplet("T5", 1, 10, h0, b0, t0);

    // T6) Bubble injection between flits + concurrent background flow
    begin_case("T6 bubble-injected packet with concurrent traffic");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd14, 6'd1, 6'd14, 6'd1, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd14, 6'd1, 6'd14, 6'd1, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd14, 6'd1, 6'd14, 6'd1, 2'd1);
    h1 = mk_flit_rect(1'b1, 1'b0, 6'd1, 6'd14, 6'd1, 6'd14, 2'd2);
    b1 = mk_flit_rect(1'b0, 1'b0, 6'd1, 6'd14, 6'd1, 6'd14, 2'd2);
    t1 = mk_flit_rect(1'b0, 1'b1, 6'd1, 6'd14, 6'd1, 6'd14, 2'd2);
    expect_global_flits(14, 1, 3);
    expect_global_flits(1, 14, 3);
    fork
      send_core_packet3_bubble(0, 3, h0, b0, t0, 40, "T6-A");
      send_core_packet3(3, 60, h1, b1, t1, "T6-B");
    join
    wait_for_idle("T6");
    check_expected_counts("T6");
    check_global_triplet("T6", 14, 1, h0, b0, t0);
    check_global_triplet("T6", 1, 14, h1, b1, t1);

    // T7) Inverted bounds should be normalized in global rectangle routing
    begin_case("T7 inverted global rectangle normalization");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd11, 6'd12, 6'd4, 6'd3, 2'd3);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd11, 6'd12, 6'd4, 6'd3, 2'd3);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd11, 6'd12, 6'd4, 6'd3, 2'd3);
    expect_global_rect_flits(4, 11, 3, 12, 3);
    send_core_packet3(2, 5, h0, b0, t0, "T7");
    wait_for_idle("T7");
    check_expected_counts("T7");
    check_global_triplet("T7", 4, 3, h0, b0, t0);
    check_global_triplet("T7", 11, 3, h0, b0, t0);
    check_global_triplet("T7", 4, 12, h0, b0, t0);
    check_global_triplet("T7", 11, 12, h0, b0, t0);
    check_global_triplet("T7", 8, 8, h0, b0, t0);

    // T8) Three overlapping multicast rectangles contend on shared regions
    begin_case("T8 triple-rectangle overlap contention");
    // A: x2..13 y2..13 id=0
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd2, 6'd2, 6'd13, 6'd13, 2'd0);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd2, 6'd2, 6'd13, 6'd13, 2'd0);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd2, 6'd2, 6'd13, 6'd13, 2'd0);
    // B: x8..15 y8..15 id=1
    h1 = mk_flit_rect(1'b1, 1'b0, 6'd8, 6'd8, 6'd15, 6'd15, 2'd1);
    b1 = mk_flit_rect(1'b0, 1'b0, 6'd8, 6'd8, 6'd15, 6'd15, 2'd1);
    t1 = mk_flit_rect(1'b0, 1'b1, 6'd8, 6'd8, 6'd15, 6'd15, 2'd1);
    // C: x6..11 y6..11 id=2 (from west boundary)
    h2 = mk_flit_rect(1'b1, 1'b0, 6'd6, 6'd6, 6'd11, 6'd11, 2'd2);
    b2 = mk_flit_rect(1'b0, 1'b0, 6'd6, 6'd6, 6'd11, 6'd11, 2'd2);
    t2 = mk_flit_rect(1'b0, 1'b1, 6'd6, 6'd6, 6'd11, 6'd11, 2'd2);
    expect_global_rect_flits(2, 13, 2, 13, 3);
    expect_global_rect_flits(8, 15, 8, 15, 3);
    expect_global_rect_flits(6, 11, 6, 11, 3);
    fork
      send_core_packet3(0, 0, h0, b0, t0, "T8-A");
      send_core_packet3(3, 63, h1, b1, t1, "T8-B");
      send_west_to_packet3(1, 1, h2, b2, t2, "T8-C");
    join
    wait_for_idle("T8");
    check_expected_counts("T8");

    // A+B+C overlap point: (9,9)
    base_idx = base_core_count[q_index_of_global(9, 9)][c_index_of_global(9, 9)];
    if (core_id_count(q_index_of_global(9, 9), c_index_of_global(9, 9), base_idx, 2'b00) != 3 ||
        core_id_count(q_index_of_global(9, 9), c_index_of_global(9, 9), base_idx, 2'b01) != 3 ||
        core_id_count(q_index_of_global(9, 9), c_index_of_global(9, 9), base_idx, 2'b10) != 3) begin
      $fatal(1, "[T8] global(9,9) expected id0/id1/id2 triplets");
    end
    check_global_id_triplet("T8", 9, 9, base_idx, 2'b00);
    check_global_id_triplet("T8", 9, 9, base_idx, 2'b01);
    check_global_id_triplet("T8", 9, 9, base_idx, 2'b10);

    // A+B only point: (13,13)
    base_idx = base_core_count[q_index_of_global(13, 13)][c_index_of_global(13, 13)];
    if (core_id_count(q_index_of_global(13, 13), c_index_of_global(13, 13), base_idx, 2'b00) != 3 ||
        core_id_count(q_index_of_global(13, 13), c_index_of_global(13, 13), base_idx, 2'b01) != 3 ||
        core_id_count(q_index_of_global(13, 13), c_index_of_global(13, 13), base_idx, 2'b10) != 0) begin
      $fatal(1, "[T8] global(13,13) expected id0+id1 only");
    end
    check_global_id_triplet("T8", 13, 13, base_idx, 2'b00);
    check_global_id_triplet("T8", 13, 13, base_idx, 2'b01);

    // A+C only point: (6,6)
    base_idx = base_core_count[q_index_of_global(6, 6)][c_index_of_global(6, 6)];
    if (core_id_count(q_index_of_global(6, 6), c_index_of_global(6, 6), base_idx, 2'b00) != 3 ||
        core_id_count(q_index_of_global(6, 6), c_index_of_global(6, 6), base_idx, 2'b01) != 0 ||
        core_id_count(q_index_of_global(6, 6), c_index_of_global(6, 6), base_idx, 2'b10) != 3) begin
      $fatal(1, "[T8] global(6,6) expected id0+id2 only");
    end
    check_global_id_triplet("T8", 6, 6, base_idx, 2'b00);
    check_global_id_triplet("T8", 6, 6, base_idx, 2'b10);

    // A only point: (3,3)
    base_idx = base_core_count[q_index_of_global(3, 3)][c_index_of_global(3, 3)];
    if (core_id_count(q_index_of_global(3, 3), c_index_of_global(3, 3), base_idx, 2'b00) != 3 ||
        core_id_count(q_index_of_global(3, 3), c_index_of_global(3, 3), base_idx, 2'b01) != 0 ||
        core_id_count(q_index_of_global(3, 3), c_index_of_global(3, 3), base_idx, 2'b10) != 0) begin
      $fatal(1, "[T8] global(3,3) expected id0 only");
    end
    check_global_id_triplet("T8", 3, 3, base_idx, 2'b00);

    // B only point: (15,15)
    base_idx = base_core_count[q_index_of_global(15, 15)][c_index_of_global(15, 15)];
    if (core_id_count(q_index_of_global(15, 15), c_index_of_global(15, 15), base_idx, 2'b00) != 0 ||
        core_id_count(q_index_of_global(15, 15), c_index_of_global(15, 15), base_idx, 2'b01) != 3 ||
        core_id_count(q_index_of_global(15, 15), c_index_of_global(15, 15), base_idx, 2'b10) != 0) begin
      $fatal(1, "[T8] global(15,15) expected id1 only");
    end
    check_global_id_triplet("T8", 15, 15, base_idx, 2'b01);

    // T9) Overlap contention with slow hotspot backpressure
    set_default_ack_delay();
    q_hot = q_index_of_global(10, 10);
    c_hot = c_index_of_global(10, 10);
    core_ack_delay_ns[q_hot][c_hot] = 80;
    begin_case("T9 overlap contention under slow hotspot backpressure");
    h0 = mk_flit_rect(1'b1, 1'b0, 6'd8, 6'd8, 6'd12, 6'd12, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 6'd8, 6'd8, 6'd12, 6'd12, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 6'd8, 6'd8, 6'd12, 6'd12, 2'd1);
    h1 = mk_flit_rect(1'b1, 1'b0, 6'd10, 6'd10, 6'd14, 6'd14, 2'd2);
    b1 = mk_flit_rect(1'b0, 1'b0, 6'd10, 6'd10, 6'd14, 6'd14, 2'd2);
    t1 = mk_flit_rect(1'b0, 1'b1, 6'd10, 6'd10, 6'd14, 6'd14, 2'd2);
    expect_global_rect_flits(8, 12, 8, 12, 3);
    expect_global_rect_flits(10, 14, 10, 14, 3);
    fork
      send_core_packet3(0, 4, h0, b0, t0, "T9-A");
      send_core_packet3(1, 62, h1, b1, t1, "T9-B");
    join
    wait_for_idle("T9");
    check_expected_counts("T9");

    base_idx = base_core_count[q_hot][c_hot];
    if (core_id_count(q_hot, c_hot, base_idx, 2'b01) != 3 ||
        core_id_count(q_hot, c_hot, base_idx, 2'b10) != 3) begin
      $fatal(1, "[T9] hotspot global(10,10) expected id1+id2");
    end
    check_global_id_triplet("T9", 10, 10, base_idx, 2'b01);
    check_global_id_triplet("T9", 10, 10, base_idx, 2'b10);

    base_idx = base_core_count[q_index_of_global(8, 8)][c_index_of_global(8, 8)];
    if (core_id_count(q_index_of_global(8, 8), c_index_of_global(8, 8), base_idx, 2'b01) != 3 ||
        core_id_count(q_index_of_global(8, 8), c_index_of_global(8, 8), base_idx, 2'b10) != 0) begin
      $fatal(1, "[T9] global(8,8) expected id1 only");
    end
    check_global_id_triplet("T9", 8, 8, base_idx, 2'b01);

    base_idx = base_core_count[q_index_of_global(14, 14)][c_index_of_global(14, 14)];
    if (core_id_count(q_index_of_global(14, 14), c_index_of_global(14, 14), base_idx, 2'b01) != 0 ||
        core_id_count(q_index_of_global(14, 14), c_index_of_global(14, 14), base_idx, 2'b10) != 3) begin
      $fatal(1, "[T9] global(14,14) expected id2 only");
    end
    check_global_id_triplet("T9", 14, 14, base_idx, 2'b10);

    t_head_slow = core_time_of_id_n(q_hot, c_hot, base_core_count[q_hot][c_hot], 2'b01, 1);
    t_body_slow = core_time_of_id_n(q_hot, c_hot, base_core_count[q_hot][c_hot], 2'b01, 2);
    t_tail_slow = core_time_of_id_n(q_hot, c_hot, base_core_count[q_hot][c_hot], 2'b01, 3);
    if ((t_head_slow == 0) || (t_body_slow == 0) || (t_tail_slow == 0)) begin
      $fatal(1, "[T9] failed to capture hotspot timing for id=1");
    end
    if ((t_body_slow - t_head_slow) < 60) begin
      $fatal(1, "[T9] hotspot id=1 head->body gap too small: %0t ns", (t_body_slow - t_head_slow));
    end
    if ((t_tail_slow - t_body_slow) < 60) begin
      $fatal(1, "[T9] hotspot id=1 body->tail gap too small: %0t ns", (t_tail_slow - t_body_slow));
    end
    set_default_ack_delay();

    $display("\n[QAM-TB] all quadtree_and_mesh tests PASSED");
    #10;
    $finish;
  end
endmodule

`default_nettype wire

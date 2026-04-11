`timescale 1ns/1ps
`default_nettype none

module three_level_quadtree_tb;
  localparam int FLIT_W = 22;
  localparam int N_CORE = 64;
  localparam int N_TOP = 8;
  localparam int MAX_RX_PER_PORT = 2048;
  localparam int DEFAULT_ACK_DELAY_NS = 1;
  localparam int HANDSHAKE_TIMEOUT_NS = 200000;
  localparam int GLOBAL_TIMEOUT_NS = 2000000;

  logic clock;
  logic reset;

  logic [N_CORE-1:0] core_in_req;
  wire  [N_CORE-1:0] core_in_ack;
  logic [FLIT_W-1:0] core_in_flit [0:N_CORE-1];

  wire  [N_CORE-1:0] core_out_req;
  logic [N_CORE-1:0] core_out_ack;
  wire  [FLIT_W-1:0] core_out_flit [0:N_CORE-1];

  logic [N_TOP-1:0] top_in_req;
  wire  [N_TOP-1:0] top_in_ack;
  logic [FLIT_W-1:0] top_in_flit [0:N_TOP-1];

  wire  [N_TOP-1:0] top_out_req;
  logic [N_TOP-1:0] top_out_ack;
  wire  [FLIT_W-1:0] top_out_flit [0:N_TOP-1];

  integer core_rx_count [0:N_CORE-1];
  reg [FLIT_W-1:0] core_rx_mem [0:N_CORE-1][0:MAX_RX_PER_PORT-1];
  time core_rx_time [0:N_CORE-1][0:MAX_RX_PER_PORT-1];

  integer top_rx_count [0:N_TOP-1];
  reg [FLIT_W-1:0] top_rx_mem [0:N_TOP-1][0:MAX_RX_PER_PORT-1];
  time top_rx_time [0:N_TOP-1][0:MAX_RX_PER_PORT-1];

  integer core_ack_delay_ns [0:N_CORE-1];
  integer top_ack_delay_ns [0:N_TOP-1];
  logic core_ack_pending [0:N_CORE-1];
  logic top_ack_pending [0:N_TOP-1];

  integer base_core_count [0:N_CORE-1];
  integer base_top_count [0:N_TOP-1];
  integer exp_core_flits [0:N_CORE-1];
  integer exp_top_flits [0:N_TOP-1];

  `include "three_level_quadtree_dut_inst.vh"
  `TLQ_INSTANTIATE_DUT(dut)

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

  function automatic [FLIT_W-1:0] mk_flit_rect(
    input bit isHead,
    input bit isTail,
    input [3:0] treeId,
    input [2:0] xMin,
    input [2:0] xMax,
    input [2:0] yMin,
    input [2:0] yMax,
    input [1:0] pktId
  );
    mk_flit_rect = {
      isHead,              // [21]
      isTail,              // [20]
      treeId,              // [19:16]
      xMin,                // [15:13]
      xMax,                // [12:10]
      yMin,                // [9:7]
      yMax,                // [6:4]
      2'b00,               // [3:2] reserved
      pktId                // [1:0]
    };
  endfunction

  function automatic bit outputs_idle();
    integer i;
    begin
      outputs_idle = 1'b1;
      for (i = 0; i < N_CORE; i = i + 1) begin
        if (core_out_req[i] !== core_out_ack[i]) outputs_idle = 1'b0;
      end
      for (i = 0; i < N_TOP; i = i + 1) begin
        if (top_out_req[i] !== top_out_ack[i]) outputs_idle = 1'b0;
      end
    end
  endfunction

  function automatic int core_id_count(
    input int idx,
    input int start_idx,
    input bit [1:0] id
  );
    integer k;
    integer c;
    begin
      c = 0;
      for (k = start_idx; k < core_rx_count[idx]; k = k + 1) begin
        if (core_rx_mem[idx][k][1:0] === id) c = c + 1;
      end
      core_id_count = c;
    end
  endfunction

  function automatic time core_time_of_id_n(
    input int idx,
    input int start_idx,
    input bit [1:0] id,
    input int nth
  );
    integer k;
    integer seen;
    time t;
    begin
      seen = 0;
      t = 0;
      for (k = start_idx; k < core_rx_count[idx]; k = k + 1) begin
        if (core_rx_mem[idx][k][1:0] === id) begin
          seen = seen + 1;
          if (seen == nth) t = core_rx_time[idx][k];
        end
      end
      core_time_of_id_n = t;
    end
  endfunction

  task automatic set_default_ack_delay();
    integer i;
    begin
      for (i = 0; i < N_CORE; i = i + 1) begin
        core_ack_delay_ns[i] = DEFAULT_ACK_DELAY_NS;
      end
      for (i = 0; i < N_TOP; i = i + 1) begin
        top_ack_delay_ns[i] = DEFAULT_ACK_DELAY_NS;
      end
    end
  endtask

  task automatic begin_case(input string case_name);
    integer i;
    begin
      $display("\n[TB] ==== %s ====", case_name);
      for (i = 0; i < N_CORE; i = i + 1) begin
        base_core_count[i] = core_rx_count[i];
        exp_core_flits[i] = 0;
      end
      for (i = 0; i < N_TOP; i = i + 1) begin
        base_top_count[i] = top_rx_count[i];
        exp_top_flits[i] = 0;
      end
    end
  endtask

  task automatic expect_core_flit_count(input int idx, input int flits);
    begin
      if (idx < 0 || idx >= N_CORE) begin
        $fatal(1, "expect_core_flit_count: core index out of range %0d", idx);
      end
      exp_core_flits[idx] = exp_core_flits[idx] + flits;
    end
  endtask

  task automatic expect_top_flit_count(input int idx, input int flits);
    begin
      if (idx < 0 || idx >= N_TOP) begin
        $fatal(1, "expect_top_flit_count: top index out of range %0d", idx);
      end
      exp_top_flits[idx] = exp_top_flits[idx] + flits;
    end
  endtask

  task automatic expect_rect_flit_count(
    input int x0,
    input int x1,
    input int y0,
    input int y1,
    input int flits_per_core
  );
    integer x;
    integer y;
    integer xl;
    integer xh;
    integer yl;
    integer yh;
    begin
      xl = min2(x0, x1);
      xh = max2(x0, x1);
      yl = min2(y0, y1);
      yh = max2(y0, y1);
      for (y = yl; y <= yh; y = y + 1) begin
        for (x = xl; x <= xh; x = x + 1) begin
          expect_core_flit_count(core_index(x, y), flits_per_core);
        end
      end
    end
  endtask

  task automatic wait_for_idle(input string tag);
    integer waited;
    integer quiet;
    begin
      waited = 0;
      quiet = 0;
      while (quiet < 12) begin
        #1;
        waited = waited + 1;
        if (outputs_idle()) quiet = quiet + 1;
        else quiet = 0;
        if (waited >= HANDSHAKE_TIMEOUT_NS) begin
          $fatal(1, "[%s] timeout waiting for idle at t=%0t ns", tag, $time);
        end
      end
    end
  endtask

  task automatic check_expected_counts(input string tag);
    integer i;
    integer got;
    begin
      for (i = 0; i < N_CORE; i = i + 1) begin
        got = core_rx_count[i] - base_core_count[i];
        if (got != exp_core_flits[i]) begin
          $fatal(
            1,
            "[%s] core_out[%0d] expected %0d flits, got %0d",
            tag,
            i,
            exp_core_flits[i],
            got
          );
        end
      end
      for (i = 0; i < N_TOP; i = i + 1) begin
        got = top_rx_count[i] - base_top_count[i];
        if (got != exp_top_flits[i]) begin
          $fatal(
            1,
            "[%s] top_out[%0d] expected %0d flits, got %0d",
            tag,
            i,
            exp_top_flits[i],
            got
          );
        end
      end
    end
  endtask

  task automatic send_core_flit(input int src, input logic [FLIT_W-1:0] flit);
    integer waited;
    begin
      if (src < 0 || src >= N_CORE) begin
        $fatal(1, "send_core_flit: source index out of range %0d", src);
      end
      core_in_flit[src] = flit;
      core_in_req[src] = ~core_in_req[src];
      waited = 0;
      while (core_in_ack[src] !== core_in_req[src]) begin
        #1;
        waited = waited + 1;
        if (waited >= HANDSHAKE_TIMEOUT_NS) begin
          $fatal(1, "timeout waiting core_in ack: src=%0d t=%0t ns", src, $time);
        end
      end
    end
  endtask

  task automatic send_top_flit(input int src, input logic [FLIT_W-1:0] flit);
    integer waited;
    begin
      if (src < 0 || src >= N_TOP) begin
        $fatal(1, "send_top_flit: source index out of range %0d", src);
      end
      top_in_flit[src] = flit;
      top_in_req[src] = ~top_in_req[src];
      waited = 0;
      while (top_in_ack[src] !== top_in_req[src]) begin
        #1;
        waited = waited + 1;
        if (waited >= HANDSHAKE_TIMEOUT_NS) begin
          $fatal(1, "timeout waiting top_in ack: src=%0d t=%0t ns", src, $time);
        end
      end
    end
  endtask

  task automatic send_core_packet3(
    input int src,
    input logic [FLIT_W-1:0] head_flit,
    input logic [FLIT_W-1:0] body_flit,
    input logic [FLIT_W-1:0] tail_flit
  );
    begin
      send_core_flit(src, head_flit);
      send_core_flit(src, body_flit);
      send_core_flit(src, tail_flit);
    end
  endtask

  task automatic send_top_packet3(
    input int src,
    input logic [FLIT_W-1:0] head_flit,
    input logic [FLIT_W-1:0] body_flit,
    input logic [FLIT_W-1:0] tail_flit
  );
    begin
      send_top_flit(src, head_flit);
      send_top_flit(src, body_flit);
      send_top_flit(src, tail_flit);
    end
  endtask

  task automatic check_core_exact_packet(
    input string tag,
    input int idx,
    input logic [FLIT_W-1:0] head_flit,
    input logic [FLIT_W-1:0] body_flit,
    input logic [FLIT_W-1:0] tail_flit
  );
    integer base;
    begin
      base = base_core_count[idx];
      if ((core_rx_count[idx] - base) != 3) begin
        $fatal(1, "[%s] core_out[%0d] expected exactly 3 flits", tag, idx);
      end
      if (core_rx_mem[idx][base + 0] !== head_flit) begin
        $fatal(1, "[%s] core_out[%0d] head mismatch", tag, idx);
      end
      if (core_rx_mem[idx][base + 1] !== body_flit) begin
        $fatal(1, "[%s] core_out[%0d] body mismatch", tag, idx);
      end
      if (core_rx_mem[idx][base + 2] !== tail_flit) begin
        $fatal(1, "[%s] core_out[%0d] tail mismatch", tag, idx);
      end
    end
  endtask

  task automatic check_top_exact_packet(
    input string tag,
    input int idx,
    input logic [FLIT_W-1:0] head_flit,
    input logic [FLIT_W-1:0] body_flit,
    input logic [FLIT_W-1:0] tail_flit
  );
    integer base;
    begin
      base = base_top_count[idx];
      if ((top_rx_count[idx] - base) != 3) begin
        $fatal(1, "[%s] top_out[%0d] expected exactly 3 flits", tag, idx);
      end
      if (top_rx_mem[idx][base + 0] !== head_flit) begin
        $fatal(1, "[%s] top_out[%0d] head mismatch", tag, idx);
      end
      if (top_rx_mem[idx][base + 1] !== body_flit) begin
        $fatal(1, "[%s] top_out[%0d] body mismatch", tag, idx);
      end
      if (top_rx_mem[idx][base + 2] !== tail_flit) begin
        $fatal(1, "[%s] top_out[%0d] tail mismatch", tag, idx);
      end
    end
  endtask

  task automatic check_packet_on_rect(
    input string tag,
    input int x0,
    input int x1,
    input int y0,
    input int y1,
    input logic [FLIT_W-1:0] head_flit,
    input logic [FLIT_W-1:0] body_flit,
    input logic [FLIT_W-1:0] tail_flit
  );
    integer x;
    integer y;
    integer xl;
    integer xh;
    integer yl;
    integer yh;
    begin
      xl = min2(x0, x1);
      xh = max2(x0, x1);
      yl = min2(y0, y1);
      yh = max2(y0, y1);
      for (y = yl; y <= yh; y = y + 1) begin
        for (x = xl; x <= xh; x = x + 1) begin
          check_core_exact_packet(tag, core_index(x, y), head_flit, body_flit, tail_flit);
        end
      end
    end
  endtask

  task automatic check_core_id_triplet(
    input string tag,
    input int idx,
    input int start_idx,
    input bit [1:0] id
  );
    integer k;
    integer state;
    reg [FLIT_W-1:0] f;
    begin
      state = 0;
      for (k = start_idx; k < core_rx_count[idx]; k = k + 1) begin
        f = core_rx_mem[idx][k];
        if (f[1:0] === id) begin
          case (state)
            0: begin
              if (!(f[21] === 1'b1 && f[20] === 1'b0)) begin
                $fatal(1, "[%s] core_out[%0d] id=%0d head format error", tag, idx, id);
              end
              state = 1;
            end
            1: begin
              if (!(f[21] === 1'b0 && f[20] === 1'b0)) begin
                $fatal(1, "[%s] core_out[%0d] id=%0d body format error", tag, idx, id);
              end
              state = 2;
            end
            2: begin
              if (!(f[21] === 1'b0 && f[20] === 1'b1)) begin
                $fatal(1, "[%s] core_out[%0d] id=%0d tail format error", tag, idx, id);
              end
              state = 3;
            end
            default: begin
              $fatal(1, "[%s] core_out[%0d] id=%0d more than 3 flits", tag, idx, id);
            end
          endcase
        end
      end
      if (state != 3) begin
        $fatal(1, "[%s] core_out[%0d] id=%0d incomplete triplet", tag, idx, id);
      end
    end
  endtask

  task automatic check_two_triplets_atomic(input string tag, input int idx);
    integer base;
    reg [FLIT_W-1:0] f0;
    reg [FLIT_W-1:0] f1;
    reg [FLIT_W-1:0] f2;
    reg [FLIT_W-1:0] f3;
    reg [FLIT_W-1:0] f4;
    reg [FLIT_W-1:0] f5;
    bit [1:0] id_a;
    bit [1:0] id_b;
    begin
      base = base_core_count[idx];
      if ((core_rx_count[idx] - base) != 6) begin
        $fatal(1, "[%s] core_out[%0d] expected 6 flits under contention", tag, idx);
      end

      f0 = core_rx_mem[idx][base + 0];
      f1 = core_rx_mem[idx][base + 1];
      f2 = core_rx_mem[idx][base + 2];
      f3 = core_rx_mem[idx][base + 3];
      f4 = core_rx_mem[idx][base + 4];
      f5 = core_rx_mem[idx][base + 5];
      id_a = f0[1:0];
      id_b = f3[1:0];

      if (id_a === id_b) begin
        $fatal(1, "[%s] core_out[%0d] expected two packet IDs, got one", tag, idx);
      end
      if ((f1[1:0] !== id_a) || (f2[1:0] !== id_a) || (f4[1:0] !== id_b) || (f5[1:0] !== id_b)) begin
        $fatal(1, "[%s] core_out[%0d] packet interleaving detected", tag, idx);
      end

      if (!(f0[21] === 1'b1 && f0[20] === 1'b0 &&
            f1[21] === 1'b0 && f1[20] === 1'b0 &&
            f2[21] === 1'b0 && f2[20] === 1'b1)) begin
        $fatal(1, "[%s] core_out[%0d] first packet H/B/T sequence error", tag, idx);
      end
      if (!(f3[21] === 1'b1 && f3[20] === 1'b0 &&
            f4[21] === 1'b0 && f4[20] === 1'b0 &&
            f5[21] === 1'b0 && f5[20] === 1'b1)) begin
        $fatal(1, "[%s] core_out[%0d] second packet H/B/T sequence error", tag, idx);
      end
    end
  endtask

  genvar g_core;
  generate
    for (g_core = 0; g_core < N_CORE; g_core = g_core + 1) begin : GEN_CORE_MON
      always @(core_out_req[g_core] or reset) begin : CORE_MON
        integer slot;
        integer dly;
        logic req_snapshot;
        if (reset) begin
          core_out_ack[g_core] <= 1'b0;
          core_ack_pending[g_core] <= 1'b0;
        end else if (core_out_req[g_core] !== core_out_ack[g_core]) begin
          if (core_ack_pending[g_core]) begin
            $fatal(
              1,
              "core_out[%0d] req toggled again before ack completed (monitor delay too large or protocol violation)",
              g_core
            );
          end
          slot = core_rx_count[g_core];
          if (slot >= MAX_RX_PER_PORT) begin
            $fatal(1, "core_out[%0d] monitor buffer overflow", g_core);
          end
          core_rx_mem[g_core][slot] = core_out_flit[g_core];
          core_rx_time[g_core][slot] = $time;
          core_rx_count[g_core] = slot + 1;
          core_ack_pending[g_core] <= 1'b1;
          dly = core_ack_delay_ns[g_core];
          req_snapshot = core_out_req[g_core];
          fork
            begin
              #(dly);
              core_out_ack[g_core] <= req_snapshot;
              core_ack_pending[g_core] <= 1'b0;
            end
          join_none;
        end
      end
    end
  endgenerate

  genvar g_top;
  generate
    for (g_top = 0; g_top < N_TOP; g_top = g_top + 1) begin : GEN_TOP_MON
      always @(top_out_req[g_top] or reset) begin : TOP_MON
        integer slot;
        integer dly;
        logic req_snapshot;
        if (reset) begin
          top_out_ack[g_top] <= 1'b0;
          top_ack_pending[g_top] <= 1'b0;
        end else if (top_out_req[g_top] !== top_out_ack[g_top]) begin
          if (top_ack_pending[g_top]) begin
            $fatal(
              1,
              "top_out[%0d] req toggled again before ack completed (monitor delay too large or protocol violation)",
              g_top
            );
          end
          slot = top_rx_count[g_top];
          if (slot >= MAX_RX_PER_PORT) begin
            $fatal(1, "top_out[%0d] monitor buffer overflow", g_top);
          end
          top_rx_mem[g_top][slot] = top_out_flit[g_top];
          top_rx_time[g_top][slot] = $time;
          top_rx_count[g_top] = slot + 1;
          top_ack_pending[g_top] <= 1'b1;
          dly = top_ack_delay_ns[g_top];
          req_snapshot = top_out_req[g_top];
          fork
            begin
              #(dly);
              top_out_ack[g_top] <= req_snapshot;
              top_ack_pending[g_top] <= 1'b0;
            end
          join_none;
        end
      end
    end
  endgenerate

  initial begin
    clock = 1'b0;
    forever #5 clock = ~clock;
  end

  initial begin : TB_INIT
    integer i;
    integer j;
    reset = 1'b1;
    core_in_req = '0;
    core_out_ack = '0;
    top_in_req = '0;
    top_out_ack = '0;

    for (i = 0; i < N_CORE; i = i + 1) begin
      core_in_flit[i] = '0;
      core_rx_count[i] = 0;
      base_core_count[i] = 0;
      exp_core_flits[i] = 0;
      core_ack_delay_ns[i] = DEFAULT_ACK_DELAY_NS;
      core_ack_pending[i] = 1'b0;
      for (j = 0; j < MAX_RX_PER_PORT; j = j + 1) begin
        core_rx_mem[i][j] = '0;
        core_rx_time[i][j] = 0;
      end
    end

    for (i = 0; i < N_TOP; i = i + 1) begin
      top_in_flit[i] = '0;
      top_rx_count[i] = 0;
      base_top_count[i] = 0;
      exp_top_flits[i] = 0;
      top_ack_delay_ns[i] = DEFAULT_ACK_DELAY_NS;
      top_ack_pending[i] = 1'b0;
      for (j = 0; j < MAX_RX_PER_PORT; j = j + 1) begin
        top_rx_mem[i][j] = '0;
        top_rx_time[i][j] = 0;
      end
    end

    #30;
    reset = 1'b0;
    $display("[TB] reset released at t=%0t ns", $time);
  end

  initial begin
    #GLOBAL_TIMEOUT_NS;
    $fatal(1, "Global timeout (%0d ns) reached", GLOBAL_TIMEOUT_NS);
  end

  initial begin : MAIN_TEST
    logic [FLIT_W-1:0] h0;
    logic [FLIT_W-1:0] b0;
    logic [FLIT_W-1:0] t0;
    logic [FLIT_W-1:0] h1;
    logic [FLIT_W-1:0] b1;
    logic [FLIT_W-1:0] t1;
    integer i;
    integer lane;
    integer lane_count;
    integer top_delta;
    integer base_idx;
    time t_head_fast;
    time t_body_fast;
    time t_tail_fast;
    time t_head_slow;
    time t_body_slow;
    time t_tail_slow;

    wait (reset === 1'b0);
    #20;

    // 1) Multi-flit unicast: core0 -> core63
    begin_case("T1 multi-flit unicast core0->core63");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    expect_core_flit_count(63, 3);
    send_core_packet3(0, h0, b0, t0);
    wait_for_idle("T1");
    check_expected_counts("T1");
    check_core_exact_packet("T1", 63, h0, b0, t0);

    // 2) Multi-flit multicast rectangle: x=2..5, y=1..3
    begin_case("T2 multi-flit multicast rectangle x2..5 y1..3");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd2, 3'd5, 3'd1, 3'd3, 2'd2);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd2, 3'd5, 3'd1, 3'd3, 2'd2);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd2, 3'd5, 3'd1, 3'd3, 2'd2);
    expect_rect_flit_count(2, 5, 1, 3, 3);
    send_core_packet3(9, h0, b0, t0);
    wait_for_idle("T2");
    check_expected_counts("T2");
    check_packet_on_rect("T2", 2, 5, 1, 3, h0, b0, t0);

    // 3) Multicast with inverted bounds: x=6..4, y=5..3 -> x=4..6, y=3..5
    begin_case("T3 multicast inverted bounds");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd6, 3'd4, 3'd5, 3'd3, 2'd3);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd6, 3'd4, 3'd5, 3'd3, 2'd3);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd6, 3'd4, 3'd5, 3'd3, 2'd3);
    expect_rect_flit_count(4, 6, 3, 5, 3);
    send_core_packet3(31, h0, b0, t0);
    wait_for_idle("T3");
    check_expected_counts("T3");
    check_packet_on_rect("T3", 4, 6, 3, 5, h0, b0, t0);

    // 4) Full-tree multicast: 8x8
    begin_case("T4 full-tree multicast 8x8");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd0, 3'd7, 3'd0, 3'd7, 2'd0);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd0, 3'd7, 3'd0, 3'd7, 2'd0);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd0, 3'd7, 3'd0, 3'd7, 2'd0);
    expect_rect_flit_count(0, 7, 0, 7, 3);
    send_core_packet3(27, h0, b0, t0);
    wait_for_idle("T4");
    check_expected_counts("T4");
    check_packet_on_rect("T4", 0, 7, 0, 7, h0, b0, t0);

    // 5) Tree-id mismatch should go upward to exactly one top_output lane
    begin_case("T5 tree-id mismatch upward routing");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd4, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd4, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd4, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    send_core_packet3(5, h0, b0, t0);
    wait_for_idle("T5");
    lane = -1;
    lane_count = 0;
    for (i = 0; i < N_CORE; i = i + 1) begin
      if ((core_rx_count[i] - base_core_count[i]) != 0) begin
        $fatal(1, "[T5] unexpected core output traffic on core_out[%0d]", i);
      end
    end
    for (i = 0; i < N_TOP; i = i + 1) begin
      top_delta = top_rx_count[i] - base_top_count[i];
      if (top_delta != 0) begin
        lane = i;
        lane_count = lane_count + 1;
        if (top_delta != 3) begin
          $fatal(1, "[T5] top_out[%0d] expected 3 flits, got %0d", i, top_delta);
        end
      end
    end
    if (lane_count != 1) begin
      $fatal(1, "[T5] expected exactly one active top_output lane, got %0d", lane_count);
    end
    check_top_exact_packet("T5", lane, h0, b0, t0);

    // 6) Injection from top_input down to local cores
    begin_case("T6 top_input to local multicast");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    expect_rect_flit_count(6, 7, 6, 7, 3);
    send_top_packet3(3, h0, b0, t0);
    wait_for_idle("T6");
    check_expected_counts("T6");
    check_packet_on_rect("T6", 6, 7, 6, 7, h0, b0, t0);

    // 7) Multicast backpressure: one slow branch should throttle all branches
    set_default_ack_delay();
    core_ack_delay_ns[63] = 60;
    begin_case("T7 multicast branch throttling under backpressure");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd3);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd3);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd3);
    expect_rect_flit_count(6, 7, 6, 7, 3);
    send_core_packet3(0, h0, b0, t0);
    wait_for_idle("T7");
    check_expected_counts("T7");
    check_packet_on_rect("T7", 6, 7, 6, 7, h0, b0, t0);
    base_idx = base_core_count[63];
    t_head_slow = core_time_of_id_n(63, base_idx, 2'b11, 1);
    t_body_slow = core_time_of_id_n(63, base_idx, 2'b11, 2);
    t_tail_slow = core_time_of_id_n(63, base_idx, 2'b11, 3);
    if ((t_head_slow == 0) || (t_body_slow == 0) || (t_tail_slow == 0)) begin
      $fatal(1, "[T7] failed to capture id=3 timing on slow branch core_out[63]");
    end

    base_idx = base_core_count[54];
    t_head_fast = core_time_of_id_n(54, base_idx, 2'b11, 1);
    t_body_fast = core_time_of_id_n(54, base_idx, 2'b11, 2);
    t_tail_fast = core_time_of_id_n(54, base_idx, 2'b11, 3);
    if ((t_head_fast == 0) || (t_body_fast == 0) || (t_tail_fast == 0)) begin
      $fatal(1, "[T7] failed to capture id=3 timing on fast branch core_out[54]");
    end

    if ((t_body_slow - t_head_slow) < 50) begin
      $fatal(1, "[T7] slow branch head->body gap too small: %0t ns", (t_body_slow - t_head_slow));
    end
    if ((t_tail_slow - t_body_slow) < 50) begin
      $fatal(1, "[T7] slow branch body->tail gap too small: %0t ns", (t_tail_slow - t_body_slow));
    end
    set_default_ack_delay();

    // 8) Competing multicast packets with overlap rectangle
    begin_case("T8 multicast contention with overlap");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd4, 3'd7, 3'd4, 3'd7, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd4, 3'd7, 3'd4, 3'd7, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd4, 3'd7, 3'd4, 3'd7, 2'd1);
    h1 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    b1 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    t1 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd6, 3'd7, 3'd6, 3'd7, 2'd2);
    expect_rect_flit_count(4, 7, 4, 7, 3);
    expect_rect_flit_count(6, 7, 6, 7, 3);
    fork
      send_core_packet3(0, h0, b0, t0);
      send_core_packet3(63, h1, b1, t1);
    join
    wait_for_idle("T8");
    check_expected_counts("T8");
    for (i = 0; i < 4; i = i + 1) begin
      case (i)
        0: base_idx = 54;
        1: base_idx = 55;
        2: base_idx = 62;
        default: base_idx = 63;
      endcase
      if (core_id_count(base_idx, base_core_count[base_idx], 2'b01) != 3) begin
        $fatal(1, "[T8] core_out[%0d] id=1 flit count mismatch", base_idx);
      end
      if (core_id_count(base_idx, base_core_count[base_idx], 2'b10) != 3) begin
        $fatal(1, "[T8] core_out[%0d] id=2 flit count mismatch", base_idx);
      end
      check_core_id_triplet("T8", base_idx, base_core_count[base_idx], 2'b01);
      check_core_id_triplet("T8", base_idx, base_core_count[base_idx], 2'b10);
    end
    if (core_id_count(60, base_core_count[60], 2'b01) != 3) begin
      $fatal(1, "[T8] core_out[60] should contain only id=1 packet");
    end
    if (core_id_count(60, base_core_count[60], 2'b10) != 0) begin
      $fatal(1, "[T8] core_out[60] should not contain id=2 packet");
    end
    check_core_id_triplet("T8", 60, base_core_count[60], 2'b01);

    // 9) Two unicast packets contending for same destination
    begin_case("T9 unicast contention same destination");
    h0 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    b0 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    t0 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    h1 = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd2);
    b1 = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd2);
    t1 = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd2);
    expect_core_flit_count(63, 6);
    fork
      send_core_packet3(7, h0, b0, t0);
      send_core_packet3(56, h1, b1, t1);
    join
    wait_for_idle("T9");
    check_expected_counts("T9");
    if (core_id_count(63, base_core_count[63], 2'b01) != 3 ||
        core_id_count(63, base_core_count[63], 2'b10) != 3) begin
      $fatal(1, "[T9] core_out[63] id-wise flit count mismatch");
    end
    check_two_triplets_atomic("T9", 63);

    $display("\n[TB] all three_level_quadtree tests PASSED");
    #40;
    $finish;
  end
endmodule

`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

module toplayer_mesh_tb;
  localparam int FLIT_W = 28;
  localparam int GRID_X = 4;
  localparam int GRID_Y = 4;
  localparam int N_TREE = GRID_X * GRID_Y;
  localparam int TREE_LANE = 8;
  localparam int EDGE_N = 4;
  localparam int EDGE_LANE = 4;

  localparam int MAX_RX_PER_TREE = 512;
  localparam int DEFAULT_ACK_DELAY_NS = 1;
  localparam int HANDSHAKE_TIMEOUT_NS = 500000;
  localparam int GLOBAL_TIMEOUT_NS = 10000000;

  logic clock;
  logic reset;

  logic in_req [0:N_TREE-1][0:TREE_LANE-1];
  wire  in_ack [0:N_TREE-1][0:TREE_LANE-1];
  logic [FLIT_W-1:0] in_flit [0:N_TREE-1][0:TREE_LANE-1];

  wire  out_req [0:N_TREE-1][0:TREE_LANE-1];
  logic out_ack [0:N_TREE-1][0:TREE_LANE-1];
  wire  [FLIT_W-1:0] out_flit [0:N_TREE-1][0:TREE_LANE-1];

  logic east_to_req [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  east_to_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  logic [FLIT_W-1:0] east_to_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  logic north_to_req [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  north_to_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  logic [FLIT_W-1:0] north_to_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  logic west_to_req [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  west_to_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  logic [FLIT_W-1:0] west_to_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  logic south_to_req [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  south_to_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  logic [FLIT_W-1:0] south_to_flit [0:EDGE_N-1][0:EDGE_LANE-1];

  wire  east_from_req [0:EDGE_N-1][0:EDGE_LANE-1];
  logic east_from_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  [FLIT_W-1:0] east_from_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  north_from_req [0:EDGE_N-1][0:EDGE_LANE-1];
  logic north_from_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  [FLIT_W-1:0] north_from_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  west_from_req [0:EDGE_N-1][0:EDGE_LANE-1];
  logic west_from_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  [FLIT_W-1:0] west_from_flit [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  south_from_req [0:EDGE_N-1][0:EDGE_LANE-1];
  logic south_from_ack [0:EDGE_N-1][0:EDGE_LANE-1];
  wire  [FLIT_W-1:0] south_from_flit [0:EDGE_N-1][0:EDGE_LANE-1];

  integer tree_rx_count [0:N_TREE-1];
  reg [FLIT_W-1:0] tree_rx_mem [0:N_TREE-1][0:MAX_RX_PER_TREE-1];
  logic out_ack_pending [0:N_TREE-1][0:TREE_LANE-1];
  integer tree_ack_delay_ns [0:N_TREE-1][0:TREE_LANE-1];

  integer east_from_rx_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer north_from_rx_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer west_from_rx_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer south_from_rx_count [0:EDGE_N-1][0:EDGE_LANE-1];

  logic east_from_ack_pending [0:EDGE_N-1][0:EDGE_LANE-1];
  logic north_from_ack_pending [0:EDGE_N-1][0:EDGE_LANE-1];
  logic west_from_ack_pending [0:EDGE_N-1][0:EDGE_LANE-1];
  logic south_from_ack_pending [0:EDGE_N-1][0:EDGE_LANE-1];
  integer edge_from_ack_delay_ns [0:EDGE_N-1][0:EDGE_LANE-1];

  integer base_tree_count [0:N_TREE-1];
  integer exp_tree_flits [0:N_TREE-1];
  integer base_east_from_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer base_north_from_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer base_west_from_count [0:EDGE_N-1][0:EDGE_LANE-1];
  integer base_south_from_count [0:EDGE_N-1][0:EDGE_LANE-1];

  `include "toplayer_mesh_dut_inst.vh"
  `TLM_INSTANTIATE_DUT(dut)

  function automatic int min2(input int a, input int b);
    if (a <= b) min2 = a;
    else min2 = b;
  endfunction

  function automatic int max2(input int a, input int b);
    if (a >= b) max2 = a;
    else max2 = b;
  endfunction

  function automatic int tree_index(input int x, input int y);
    tree_index = x + (y * GRID_X);
  endfunction

  function automatic [FLIT_W-1:0] mk_rect_flit(
    input bit isHead,
    input bit isTail,
    input [5:0] x0,
    input [5:0] y0,
    input [5:0] x1,
    input [5:0] y1,
    input [1:0] pktId
  );
    mk_rect_flit = {
      isHead, // [27]
      isTail, // [26]
      y1,     // [25:20]
      x1,     // [19:14]
      y0,     // [13:8]
      x0,     // [7:2]
      pktId   // [1:0]
    };
  endfunction

  function automatic bit is_idle();
    int t;
    int l;
    int e;
    bit ok;
    ok = 1'b1;

    for (t = 0; t < N_TREE; t = t + 1) begin
      for (l = 0; l < TREE_LANE; l = l + 1) begin
        if (in_req[t][l] !== in_ack[t][l]) ok = 1'b0;
        if (out_req[t][l] !== out_ack[t][l]) ok = 1'b0;
        if (out_ack_pending[t][l]) ok = 1'b0;
      end
    end

    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < EDGE_LANE; l = l + 1) begin
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
    int t;
    int l;
    int e;
    for (t = 0; t < N_TREE; t = t + 1) begin
      for (l = 0; l < TREE_LANE; l = l + 1) begin
        tree_ack_delay_ns[t][l] = DEFAULT_ACK_DELAY_NS;
      end
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < EDGE_LANE; l = l + 1) begin
        edge_from_ack_delay_ns[e][l] = DEFAULT_ACK_DELAY_NS;
      end
    end
  endtask

  task automatic clear_expected();
    int t;
    for (t = 0; t < N_TREE; t = t + 1) begin
      exp_tree_flits[t] = 0;
    end
  endtask

  task automatic begin_case(input string case_name);
    int t;
    int e;
    int l;
    $display("\n[TLM-TB] ==== %0s ====", case_name);
    clear_expected();
    for (t = 0; t < N_TREE; t = t + 1) begin
      base_tree_count[t] = tree_rx_count[t];
    end
    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < EDGE_LANE; l = l + 1) begin
        base_east_from_count[e][l] = east_from_rx_count[e][l];
        base_north_from_count[e][l] = north_from_rx_count[e][l];
        base_west_from_count[e][l] = west_from_rx_count[e][l];
        base_south_from_count[e][l] = south_from_rx_count[e][l];
      end
    end
  endtask

  task automatic expect_tree_flits(input int t, input int flit_count);
    exp_tree_flits[t] = exp_tree_flits[t] + flit_count;
  endtask

  task automatic expect_tree_rect(
    input int tx0,
    input int tx1,
    input int ty0,
    input int ty1,
    input int flit_count
  );
    int x;
    int y;
    int xLo;
    int xHi;
    int yLo;
    int yHi;
    xLo = min2(tx0, tx1);
    xHi = max2(tx0, tx1);
    yLo = min2(ty0, ty1);
    yHi = max2(ty0, ty1);
    for (y = yLo; y <= yHi; y = y + 1) begin
      for (x = xLo; x <= xHi; x = x + 1) begin
        expect_tree_flits(tree_index(x, y), flit_count);
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

  task automatic check_expected_counts(input string tag);
    int t;
    int e;
    int l;
    int got;
    bit has_mismatch;
    has_mismatch = 1'b0;

    for (t = 0; t < N_TREE; t = t + 1) begin
      got = tree_rx_count[t] - base_tree_count[t];
      if (got != exp_tree_flits[t]) begin
        has_mismatch = 1'b1;
        $display(
          "[%0s] tree_out[%0d] expected %0d flits, got %0d",
          tag, t, exp_tree_flits[t], got
        );
      end
    end

    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < EDGE_LANE; l = l + 1) begin
        if ((east_from_rx_count[e][l] - base_east_from_count[e][l]) != 0) begin
          has_mismatch = 1'b1;
          $display("[%0s] unexpected east_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((north_from_rx_count[e][l] - base_north_from_count[e][l]) != 0) begin
          has_mismatch = 1'b1;
          $display("[%0s] unexpected north_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((west_from_rx_count[e][l] - base_west_from_count[e][l]) != 0) begin
          has_mismatch = 1'b1;
          $display("[%0s] unexpected west_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
        if ((south_from_rx_count[e][l] - base_south_from_count[e][l]) != 0) begin
          has_mismatch = 1'b1;
          $display("[%0s] unexpected south_fromPE traffic on [%0d][%0d]", tag, e, l);
        end
      end
    end

    if (has_mismatch) begin
      $fatal(1, "[%0s] count mismatch", tag);
    end
  endtask

  task automatic send_input_flit(
    input int tree,
    input int lane,
    input [FLIT_W-1:0] flit_word,
    input string tag
  );
    time t0;
    in_flit[tree][lane] = flit_word;
    in_req[tree][lane] = ~in_req[tree][lane];
    t0 = $time;
    while (in_ack[tree][lane] !== in_req[tree][lane]) begin
      #1;
      if (($time - t0) > HANDSHAKE_TIMEOUT_NS) begin
        $fatal(
          1,
          "[%0s] input handshake timeout tree=%0d lane=%0d",
          tag, tree, lane
        );
      end
    end
  endtask

  task automatic send_input_packet3(
    input int tree,
    input int lane,
    input [FLIT_W-1:0] head_flit,
    input [FLIT_W-1:0] body_flit,
    input [FLIT_W-1:0] tail_flit,
    input string tag
  );
    send_input_flit(tree, lane, head_flit, tag);
    send_input_flit(tree, lane, body_flit, tag);
    send_input_flit(tree, lane, tail_flit, tag);
  endtask

  task automatic check_tree_triplet(
    input string tag,
    input int tree,
    input [FLIT_W-1:0] h,
    input [FLIT_W-1:0] b,
    input [FLIT_W-1:0] t
  );
    int base_idx;
    base_idx = base_tree_count[tree];
    if ((tree_rx_count[tree] - base_idx) != 3) begin
      $fatal(1, "[%0s] tree_out[%0d] expected exactly 3 flits", tag, tree);
    end
    if (tree_rx_mem[tree][base_idx + 0] !== h) begin
      $fatal(1, "[%0s] tree_out[%0d] head mismatch", tag, tree);
    end
    if (tree_rx_mem[tree][base_idx + 1] !== b) begin
      $fatal(1, "[%0s] tree_out[%0d] body mismatch", tag, tree);
    end
    if (tree_rx_mem[tree][base_idx + 2] !== t) begin
      $fatal(1, "[%0s] tree_out[%0d] tail mismatch", tag, tree);
    end
  endtask

  initial clock = 1'b0;
  always #1 clock = ~clock;

  genvar gt;
  genvar gl;
  generate
    for (gt = 0; gt < N_TREE; gt = gt + 1) begin : GEN_TREE_MON_T
      for (gl = 0; gl < TREE_LANE; gl = gl + 1) begin : GEN_TREE_MON_L
        always @(out_req[gt][gl] or reset) begin
          integer slot;
          integer dly;
          logic req_snapshot;
          if (reset) begin
            out_ack[gt][gl] <= 1'b0;
            out_ack_pending[gt][gl] <= 1'b0;
          end else if (out_req[gt][gl] !== out_ack[gt][gl]) begin
            if (out_ack_pending[gt][gl]) begin
              $fatal(1, "[MON] overlapping tree_out handshake on [%0d][%0d]", gt, gl);
            end
            slot = tree_rx_count[gt];
            if (slot >= MAX_RX_PER_TREE) begin
              $fatal(1, "[MON] tree_out monitor buffer overflow on tree=%0d", gt);
            end
            tree_rx_mem[gt][slot] = out_flit[gt][gl];
            tree_rx_count[gt] = slot + 1;

            out_ack_pending[gt][gl] <= 1'b1;
            dly = tree_ack_delay_ns[gt][gl];
            req_snapshot = out_req[gt][gl];
            fork
              begin
                #(dly);
                out_ack[gt][gl] <= req_snapshot;
                out_ack_pending[gt][gl] <= 1'b0;
              end
            join_none
          end
        end
      end
    end
  endgenerate

  genvar ge;
  genvar el;
  generate
    for (ge = 0; ge < EDGE_N; ge = ge + 1) begin : GEN_EDGE_MON_E
      for (el = 0; el < EDGE_LANE; el = el + 1) begin : GEN_EDGE_MON_L
        always @(east_from_req[ge][el] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            east_from_ack[ge][el] <= 1'b0;
            east_from_ack_pending[ge][el] <= 1'b0;
          end else if (east_from_req[ge][el] !== east_from_ack[ge][el]) begin
            if (east_from_ack_pending[ge][el]) begin
              $fatal(1, "[MON] overlapping east_from handshake on [%0d][%0d]", ge, el);
            end
            east_from_rx_count[ge][el] = east_from_rx_count[ge][el] + 1;
            east_from_ack_pending[ge][el] <= 1'b1;
            dly = edge_from_ack_delay_ns[ge][el];
            req_snapshot = east_from_req[ge][el];
            fork
              begin
                #(dly);
                east_from_ack[ge][el] <= req_snapshot;
                east_from_ack_pending[ge][el] <= 1'b0;
              end
            join_none
          end
        end

        always @(north_from_req[ge][el] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            north_from_ack[ge][el] <= 1'b0;
            north_from_ack_pending[ge][el] <= 1'b0;
          end else if (north_from_req[ge][el] !== north_from_ack[ge][el]) begin
            if (north_from_ack_pending[ge][el]) begin
              $fatal(1, "[MON] overlapping north_from handshake on [%0d][%0d]", ge, el);
            end
            north_from_rx_count[ge][el] = north_from_rx_count[ge][el] + 1;
            north_from_ack_pending[ge][el] <= 1'b1;
            dly = edge_from_ack_delay_ns[ge][el];
            req_snapshot = north_from_req[ge][el];
            fork
              begin
                #(dly);
                north_from_ack[ge][el] <= req_snapshot;
                north_from_ack_pending[ge][el] <= 1'b0;
              end
            join_none
          end
        end

        always @(west_from_req[ge][el] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            west_from_ack[ge][el] <= 1'b0;
            west_from_ack_pending[ge][el] <= 1'b0;
          end else if (west_from_req[ge][el] !== west_from_ack[ge][el]) begin
            if (west_from_ack_pending[ge][el]) begin
              $fatal(1, "[MON] overlapping west_from handshake on [%0d][%0d]", ge, el);
            end
            west_from_rx_count[ge][el] = west_from_rx_count[ge][el] + 1;
            west_from_ack_pending[ge][el] <= 1'b1;
            dly = edge_from_ack_delay_ns[ge][el];
            req_snapshot = west_from_req[ge][el];
            fork
              begin
                #(dly);
                west_from_ack[ge][el] <= req_snapshot;
                west_from_ack_pending[ge][el] <= 1'b0;
              end
            join_none
          end
        end

        always @(south_from_req[ge][el] or reset) begin
          integer dly;
          logic req_snapshot;
          if (reset) begin
            south_from_ack[ge][el] <= 1'b0;
            south_from_ack_pending[ge][el] <= 1'b0;
          end else if (south_from_req[ge][el] !== south_from_ack[ge][el]) begin
            if (south_from_ack_pending[ge][el]) begin
              $fatal(1, "[MON] overlapping south_from handshake on [%0d][%0d]", ge, el);
            end
            south_from_rx_count[ge][el] = south_from_rx_count[ge][el] + 1;
            south_from_ack_pending[ge][el] <= 1'b1;
            dly = edge_from_ack_delay_ns[ge][el];
            req_snapshot = south_from_req[ge][el];
            fork
              begin
                #(dly);
                south_from_ack[ge][el] <= req_snapshot;
                south_from_ack_pending[ge][el] <= 1'b0;
              end
            join_none
          end
        end
      end
    end
  endgenerate

  initial begin
    int t;
    int l;
    int e;

    reset = 1'b1;

    for (t = 0; t < N_TREE; t = t + 1) begin
      tree_rx_count[t] = 0;
      base_tree_count[t] = 0;
      exp_tree_flits[t] = 0;
      for (l = 0; l < TREE_LANE; l = l + 1) begin
        in_req[t][l] = 1'b0;
        in_flit[t][l] = '0;
        out_ack[t][l] = 1'b0;
        out_ack_pending[t][l] = 1'b0;
        tree_ack_delay_ns[t][l] = DEFAULT_ACK_DELAY_NS;
      end
    end

    for (e = 0; e < EDGE_N; e = e + 1) begin
      for (l = 0; l < EDGE_LANE; l = l + 1) begin
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
        edge_from_ack_delay_ns[e][l] = DEFAULT_ACK_DELAY_NS;

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
    $display("[TLM-TB] reset released at t=%0t ns", $time);
  end

  initial begin
    #GLOBAL_TIMEOUT_NS;
    $fatal(1, "[TLM-TB] global timeout reached");
  end

  initial begin
    reg [FLIT_W-1:0] h;
    reg [FLIT_W-1:0] b;
    reg [FLIT_W-1:0] t;

    wait (reset === 1'b0);
    #20;

    // M1: 2x2 destination in mesh, source outside rectangle.
    // Dest trees: x=2..3, y=1..2.
    begin_case("M1 2x2 rectangle, source outside");
    h = mk_rect_flit(1'b1, 1'b0, 6'd16, 6'd8, 6'd31, 6'd23, 2'd0);
    b = mk_rect_flit(1'b0, 1'b0, 6'd16, 6'd8, 6'd31, 6'd23, 2'd0);
    t = mk_rect_flit(1'b0, 1'b1, 6'd16, 6'd8, 6'd31, 6'd23, 2'd0);
    expect_tree_rect(2, 3, 1, 2, 3);
    // Pick a source with same row to enter destination rectangle from West side.
    send_input_packet3(tree_index(0, 1), 0, h, b, t, "M1");
    wait_for_idle("M1");
    check_expected_counts("M1");
    check_tree_triplet("M1", tree_index(2, 1), h, b, t);
    check_tree_triplet("M1", tree_index(3, 1), h, b, t);
    check_tree_triplet("M1", tree_index(2, 2), h, b, t);
    check_tree_triplet("M1", tree_index(3, 2), h, b, t);

    // M2: 1x2 destination in mesh, source outside rectangle.
    // Dest trees: x=1..1, y=1..2.
    begin_case("M2 1x2 rectangle, source outside");
    h = mk_rect_flit(1'b1, 1'b0, 6'd8, 6'd8, 6'd15, 6'd23, 2'd1);
    b = mk_rect_flit(1'b0, 1'b0, 6'd8, 6'd8, 6'd15, 6'd23, 2'd1);
    t = mk_rect_flit(1'b0, 1'b1, 6'd8, 6'd8, 6'd15, 6'd23, 2'd1);
    expect_tree_rect(1, 1, 1, 2, 3);
    send_input_packet3(tree_index(3, 0), 0, h, b, t, "M2");
    wait_for_idle("M2");
    check_expected_counts("M2");
    check_tree_triplet("M2", tree_index(1, 1), h, b, t);
    check_tree_triplet("M2", tree_index(1, 2), h, b, t);

    // M3: 2x2 destination in mesh, source inside rectangle.
    // Dest trees: x=1..2, y=1..2.
    begin_case("M3 2x2 rectangle, source inside");
    h = mk_rect_flit(1'b1, 1'b0, 6'd8, 6'd8, 6'd23, 6'd23, 2'd2);
    b = mk_rect_flit(1'b0, 1'b0, 6'd8, 6'd8, 6'd23, 6'd23, 2'd2);
    t = mk_rect_flit(1'b0, 1'b1, 6'd8, 6'd8, 6'd23, 6'd23, 2'd2);
    expect_tree_rect(1, 2, 1, 2, 3);
    send_input_packet3(tree_index(1, 1), 0, h, b, t, "M3");
    wait_for_idle("M3");
    check_expected_counts("M3");
    check_tree_triplet("M3", tree_index(1, 1), h, b, t);
    check_tree_triplet("M3", tree_index(2, 1), h, b, t);
    check_tree_triplet("M3", tree_index(1, 2), h, b, t);
    check_tree_triplet("M3", tree_index(2, 2), h, b, t);

    // M4: 1x2 destination in mesh, source inside rectangle.
    // Dest trees: x=2..2, y=1..2.
    begin_case("M4 1x2 rectangle, source inside");
    h = mk_rect_flit(1'b1, 1'b0, 6'd16, 6'd8, 6'd23, 6'd23, 2'd3);
    b = mk_rect_flit(1'b0, 1'b0, 6'd16, 6'd8, 6'd23, 6'd23, 2'd3);
    t = mk_rect_flit(1'b0, 1'b1, 6'd16, 6'd8, 6'd23, 6'd23, 2'd3);
    expect_tree_rect(2, 2, 1, 2, 3);
    send_input_packet3(tree_index(2, 1), 0, h, b, t, "M4");
    wait_for_idle("M4");
    check_expected_counts("M4");
    check_tree_triplet("M4", tree_index(2, 1), h, b, t);
    check_tree_triplet("M4", tree_index(2, 2), h, b, t);

    // M5: explicit cross-tree multicast over a 3x2 tree rectangle.
    // Source is above rectangle to force vertical ingress, then X-trunk fanout.
    // Dest trees: x=1..3, y=0..1.
    begin_case("M5 cross-tree multicast 3x2 rectangle");
    h = mk_rect_flit(1'b1, 1'b0, 6'd8, 6'd0, 6'd31, 6'd15, 2'd0);
    b = mk_rect_flit(1'b0, 1'b0, 6'd8, 6'd0, 6'd31, 6'd15, 2'd0);
    t = mk_rect_flit(1'b0, 1'b1, 6'd8, 6'd0, 6'd31, 6'd15, 2'd0);
    expect_tree_rect(1, 3, 0, 1, 3);
    send_input_packet3(tree_index(0, 3), 0, h, b, t, "M5");
    wait_for_idle("M5");
    check_expected_counts("M5");
    check_tree_triplet("M5", tree_index(1, 0), h, b, t);
    check_tree_triplet("M5", tree_index(3, 1), h, b, t);

    // M6: full-mesh cross-tree multicast over all 4x4 trees.
    begin_case("M6 cross-tree multicast full 4x4");
    h = mk_rect_flit(1'b1, 1'b0, 6'd0, 6'd0, 6'd31, 6'd31, 2'd1);
    b = mk_rect_flit(1'b0, 1'b0, 6'd0, 6'd0, 6'd31, 6'd31, 2'd1);
    t = mk_rect_flit(1'b0, 1'b1, 6'd0, 6'd0, 6'd31, 6'd31, 2'd1);
    expect_tree_rect(0, 3, 0, 3, 3);
    send_input_packet3(tree_index(2, 2), 0, h, b, t, "M6");
    wait_for_idle("M6");
    check_expected_counts("M6");
    check_tree_triplet("M6", tree_index(0, 0), h, b, t);
    check_tree_triplet("M6", tree_index(3, 3), h, b, t);

    $display("\n[TLM-TB] all Mesh rectangle tests PASSED");
    #20;
    $finish;
  end
endmodule

`default_nettype wire

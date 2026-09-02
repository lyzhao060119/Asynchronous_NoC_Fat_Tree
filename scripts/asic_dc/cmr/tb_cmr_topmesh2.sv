`timescale 1ns/1ps

// 2x2 CMR TopMesh MAXIMUM-SDF GLS.  Scoreboard is tile-level: a flit may
// egress on either Local lane of the destination tile.
module tb_cmr_topmesh2;
  localparam integer TILES = 4;
  localparam integer LANES = 2;
  localparam integer NUM_PORTS = TILES * LANES;
  localparam integer FLIT_W = 28;
  localparam integer MAX_INPUT_FLITS = 4096;
  localparam integer MAX_EXPECT_FLITS = 4096;
  localparam integer MAX_RX_PER_PORT = 512;
  localparam integer STR_CHARS = 256;

  reg reset;
  reg [NUM_PORTS-1:0] tb_in_req;
  wire [NUM_PORTS-1:0] tb_in_ack;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data;
  wire [NUM_PORTS-1:0] tb_out_req;
  reg [NUM_PORTS-1:0] tb_out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  async_topmesh2_port_adapter noc (
    .reset(reset),
    .in_req(tb_in_req),
    .in_ack(tb_in_ack),
    .in_data(tb_in_data),
    .out_req(tb_out_req),
    .out_ack(tb_out_ack),
    .out_data(tb_out_data)
  );

  integer input_count, expected_count, unexpected_flits, missing_flits;
  integer injected_flits, delivered_flits, reset_cycles, timeout_cycles;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];
  reg input_accepted [0:MAX_INPUT_FLITS-1];
  integer expected_tile [0:MAX_EXPECT_FLITS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];
  integer rx_count [0:NUM_PORTS-1];
  integer last_egress_ps [0:NUM_PORTS-1];
  integer active_input [0:NUM_PORTS-1];
  reg [NUM_PORTS-1:0] input_done;
  reg running, timed_out, finish_requested, csv_dumped, x_failed;
  real case_tick_ns, tx_setup_ns, rx_capture_ns, ack_to_next_req_guard_ns;
  real case_epoch_ns, timeout_ns, drain_ns, stall_timeout_ns, last_progress_ns;
  reg [STR_CHARS*8-1:0] case_file, csv_file, case_name, case_group;
  event rx_activity;

  function integer now_ps;
    real t;
    begin
      t = $realtime * 1000.0;
      now_ps = $rtoi(t + 0.5);
    end
  endfunction

  function integer total_rx;
    integer p, total;
    begin
      total = 0;
      for (p = 0; p < NUM_PORTS; p = p + 1) total = total + rx_count[p];
      total_rx = total;
    end
  endfunction

  function integer tile_of;
    input integer port;
    begin
      tile_of = port / LANES;
    end
  endfunction

  task automatic parse_case;
    integer fd, n, p, cyc, pkt, idx, line_no, tile;
    reg [STR_CHARS*8-1:0] line, tag;
    reg [FLIT_W-1:0] flit;
    begin
      input_count = 0;
      expected_count = 0;
      reset_cycles = 10;
      timeout_cycles = 200000;
      case_name = "";
      case_group = "";
      fd = $fopen(case_file, "r");
      if (fd == 0) begin
        $display("TB_FATAL cannot open CASE_FILE");
        $finish;
      end
      line_no = 0;
      while (!$feof(fd)) begin
        line = "";
        if ($fgets(line, fd) != 0) begin
          line_no = line_no + 1;
          tag = "";
          if ($sscanf(line, "%s", tag) == 1 && tag != "#") begin
            if (tag == "case") n = $sscanf(line, "%s %s", tag, case_name);
            else if (tag == "group") n = $sscanf(line, "%s %s", tag, case_group);
            else if (tag == "reset_cycles") n = $sscanf(line, "%s %d", tag, reset_cycles);
            else if (tag == "timeout_cycles") n = $sscanf(line, "%s %d", tag, timeout_cycles);
            else if (tag == "input") begin
              n = $sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt, flit);
              if (n != 5 || p < 0 || p >= NUM_PORTS || input_count >= MAX_INPUT_FLITS) begin
                $display("TB_FATAL malformed input at line %0d", line_no);
                $finish;
              end
              input_cycle[input_count] = cyc;
              input_port[input_count] = p;
              input_pkt_seq[input_count] = pkt;
              input_flit[input_count] = flit;
              input_accepted[input_count] = 1'b0;
              input_count = input_count + 1;
            end else if (tag == "expect_tile") begin
              n = $sscanf(line, "%s %d %d %d %h", tag, tile, pkt, cyc, flit);
              if (n != 5 || tile < 0 || tile >= TILES || expected_count >= MAX_EXPECT_FLITS) begin
                $display("TB_FATAL malformed expect_tile at line %0d", line_no);
                $finish;
              end
              expected_tile[expected_count] = tile;
              expected_pkt_seq[expected_count] = pkt;
              expected_is_tail[expected_count] = cyc[0];
              expected_flit[expected_count] = flit;
              expected_seen[expected_count] = 1'b0;
              expected_count = expected_count + 1;
            end
          end
        end
      end
      $fclose(fd);
      $display("TB_INFO case=%0s inputs=%0d expects=%0d", case_name, input_count, expected_count);
    end
  endtask

  task automatic drive_port(input integer port);
    integer i;
    real due_ns;
    begin
      wait (running);
      for (i = 0; i < input_count; i = i + 1) if (input_port[i] == port) begin
        due_ns = case_epoch_ns + input_cycle[i] * case_tick_ns;
        if ($realtime < due_ns) #(due_ns - $realtime);
        wait ((tb_in_req[port] === tb_in_ack[port]));
        tb_in_data[port*FLIT_W +: FLIT_W] = input_flit[i];
        #(tx_setup_ns);
        active_input[port] = i;
        tb_in_req[port] = ~tb_in_req[port];
        wait (tb_in_req[port] === tb_in_ack[port]);
        input_accepted[i] = 1'b1;
        active_input[port] = -1;
        last_progress_ns = $realtime;
        if (ack_to_next_req_guard_ns > 0.0) #(ack_to_next_req_guard_ns);
      end
      input_done[port] = 1'b1;
    end
  endtask

  task automatic receive_port(input integer port);
    integer slot, scan, exp_idx, tile;
    reg found;
    reg [FLIT_W-1:0] captured;
    begin
      forever begin
        wait (running && (tb_out_req[port] !== tb_out_ack[port]));
        if ((tb_out_req[port] === 1'bx) || (tb_out_ack[port] === 1'bx) ||
            (^tb_out_data[port*FLIT_W +: FLIT_W] === 1'bx)) begin
          $display("TB_X_FAIL port=%0d t=%0t req=%b ack=%b data=%h",
                   port, $time, tb_out_req[port], tb_out_ack[port],
                   tb_out_data[port*FLIT_W +: FLIT_W]);
          x_failed = 1'b1;
        end
        #(rx_capture_ns);
        captured = tb_out_data[port*FLIT_W +: FLIT_W];
        tile = tile_of(port);
        slot = rx_count[port];
        if (slot >= MAX_RX_PER_PORT) begin
          $display("TB_FATAL RX overflow port=%0d", port);
          $finish;
        end
        exp_idx = -1;
        found = 1'b0;
        for (scan = 0; scan < expected_count; scan = scan + 1)
          if (!found && !expected_seen[scan] &&
              (expected_tile[scan] == tile) &&
              (captured === expected_flit[scan])) begin
            exp_idx = scan;
            found = 1'b1;
            expected_seen[scan] = 1'b1;
          end
        if (!found) begin
          unexpected_flits = unexpected_flits + 1;
          $display("TB_UNEXPECTED_FAIL port=%0d tile=%0d flit=%h", port, tile, captured);
        end
        rx_count[port] = slot + 1;
        last_progress_ns = $realtime;
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  task automatic dump_results;
    integer i, fd;
    reg pass_ok;
    begin
      if (csv_dumped) disable dump_results;
      csv_dumped = 1'b1;
      injected_flits = 0;
      missing_flits = 0;
      delivered_flits = total_rx();
      for (i = 0; i < input_count; i = i + 1)
        if (input_accepted[i]) injected_flits = injected_flits + 1;
      for (i = 0; i < expected_count; i = i + 1)
        if (!expected_seen[i]) begin
          missing_flits = missing_flits + 1;
          $display("TB_MISSING tile=%0d pkt=%0d tail=%0d flit=%h",
                   expected_tile[i], expected_pkt_seq[i],
                   expected_is_tail[i], expected_flit[i]);
        end
      pass_ok = !timed_out && !x_failed &&
                (injected_flits == input_count) &&
                (missing_flits == 0) &&
                (unexpected_flits == 0);
      fd = $fopen(csv_file, "w");
      $fwrite(fd, "case_name,injected_flits,delivered_flits,missing_flits,unexpected_flits,timeout,x_fail,pass_fail\n");
      $fwrite(fd, "%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0s\n",
              case_name, injected_flits, delivered_flits, missing_flits,
              unexpected_flits, timed_out, x_failed, pass_ok ? "PASS" : "FAIL");
      $fclose(fd);
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d x=%0d elapsed_ns=%0.3f",
               pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits,
               missing_flits, unexpected_flits, timed_out, x_failed,
               $realtime - case_epoch_ns);
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_ports
      always @(tb_out_req[gp])
        if (running && (tb_out_req[gp] !== tb_out_ack[gp]))
          last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
      initial drive_port(gp);
    end
  endgenerate

  always @(tb_in_req or tb_in_ack or tb_out_req or tb_out_ack) begin
    if (running &&
        (((^tb_in_req) === 1'bx) || ((^tb_in_ack) === 1'bx) ||
         ((^tb_out_req) === 1'bx) || ((^tb_out_ack) === 1'bx))) begin
      $display("TB_X_FAIL boundary_control t=%0t in_req=%b in_ack=%b out_req=%b out_ack=%b",
               $time, tb_in_req, tb_in_ack, tb_out_req, tb_out_ack);
      x_failed = 1'b1;
    end
  end

  initial begin
    integer p;
    case_file = "";
    csv_file = "topmesh2_summary.csv";
    case_tick_ns = 20.0;
    tx_setup_ns = 0.05;
    rx_capture_ns = 0.10;
    ack_to_next_req_guard_ns = 0.20;
    stall_timeout_ns = 2000000.0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("STALL_TIMEOUT_NS=%f", stall_timeout_ns)) ;
    if (case_file == "") begin
      $display("TB_FATAL +CASE_FILE is required");
      $finish;
    end
    parse_case();
    reset = 1'b1;
    tb_in_req = '0;
    tb_in_data = '0;
    tb_out_ack = '0;
    input_done = '0;
    running = 1'b0;
    timed_out = 1'b0;
    finish_requested = 1'b0;
    csv_dumped = 1'b0;
    x_failed = 1'b0;
    unexpected_flits = 0;
    for (p = 0; p < NUM_PORTS; p = p + 1) begin
      rx_count[p] = 0;
      last_egress_ps[p] = -1;
      active_input[p] = -1;
    end
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
    case_epoch_ns = $realtime;
    timeout_ns = timeout_cycles * case_tick_ns;
    drain_ns = 256.0 * case_tick_ns;
    last_progress_ns = $realtime;
    running = 1'b1;
  end

  initial begin : completion_watchdog
    wait (running);
    fork
      begin
        wait (&input_done);
        while (total_rx() < expected_count) @rx_activity;
        #(drain_ns);
        if (!finish_requested) begin
          dump_results();
          finish_requested = 1'b1;
          #1 $finish;
        end
      end
      begin
        #(timeout_ns);
        if (!finish_requested) begin
          timed_out = 1'b1;
          $display("TB_HARD_TIMEOUT");
          dump_results();
          finish_requested = 1'b1;
          #1 $finish;
        end
      end
      begin
        while (!finish_requested) begin
          #100.0;
          if (running && (($realtime - last_progress_ns) > stall_timeout_ns) &&
              (total_rx() < expected_count)) begin
            $display("TB_STALL_FAIL idle_ns=%0.3f rx=%0d expected=%0d",
                     $realtime - last_progress_ns, total_rx(), expected_count);
            timed_out = 1'b1;
            dump_results();
            finish_requested = 1'b1;
            #1 $finish;
          end
        end
      end
    join_any
    disable fork;
  end
endmodule

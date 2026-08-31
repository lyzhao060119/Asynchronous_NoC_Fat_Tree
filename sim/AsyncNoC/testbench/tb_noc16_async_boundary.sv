`timescale 1ns/1ps

// Canonical event-driven NoC16 traffic harness.  CASE_TICK_NS is an offered
// load scale only: no request or acknowledgement is driven by a clock edge.
// +INJECT_MAX_RATE skips the CASE_TICK wait and issues the next case flit as
// soon as the previous boundary handshake completes (plus WP-01 guard).
// 64-core Fat-tree uses the same NUM_CORES/TOP_LANES split in
// tb_noc64_async_boundary.sv (NUM_CORES=64, TOP_LANES=8 or 2).
module noc16_async_boundary_core #(
  parameter integer STRUCTURAL_ENDPOINTS = 0,
  // A direct combinational port adapter can return Ack in the same simulation
  // time slot as Req propagation.  CMR gate-level runs use the race-free
  // single completion wait; legacy Ultra tops retain the original sequence.
  parameter integer ROBUST_DIRECT_HANDSHAKE = 0,
  parameter integer TOP_LANES = 4
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_CORES = 16;
  localparam integer NUM_PORTS = NUM_CORES + TOP_LANES;
  localparam integer MAX_INPUT_FLITS = 131072;
  localparam integer MAX_EXPECT_FLITS = 262144;
  localparam integer MAX_RX_PER_PORT = 32768;
  localparam integer MAX_PKT_SEQ = 262144;
  localparam integer STR_CHARS = 256;

  reg reset;
  reg [NUM_PORTS-1:0] tb_in_req;
  wire [NUM_PORTS-1:0] tb_in_ack;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data;
  wire [NUM_PORTS-1:0] tb_out_req;
  reg [NUM_PORTS-1:0] tb_out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  wire [NUM_PORTS-1:0] noc_in_req, noc_in_ack;
  wire [NUM_PORTS*FLIT_W-1:0] noc_in_data;
  wire [NUM_PORTS-1:0] noc_out_req, noc_out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] noc_out_data;

  reg [NUM_PORTS-1:0] input_done;
  reg running, timed_out, finish_requested;

  integer reset_cycles, timeout_cycles;
  integer inject_max_rate;
  real case_tick_ns, tx_setup_ns, rx_capture_ns, ack_to_next_req_guard_ns, timeout_scale;
  real case_epoch_ns, timeout_ns, drain_ns;
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file;
  reg [STR_CHARS*8-1:0] case_name, case_group;
  reg [2047:0] dump_vcd;

  integer input_count, expected_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];
  integer input_offer_ps [0:MAX_INPUT_FLITS-1];
  integer input_req_ps [0:MAX_INPUT_FLITS-1];
  integer input_ack_ps [0:MAX_INPUT_FLITS-1];
  reg input_accepted [0:MAX_INPUT_FLITS-1];
  integer active_input [0:NUM_PORTS-1];

  integer expected_port_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer expected_port_count [0:NUM_PORTS-1];
  integer expected_cursor [0:NUM_PORTS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [NUM_PORTS-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];

  integer rx_count [0:NUM_PORTS-1];
  integer rx_time_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer rx_egress_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer rx_expected_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg [FLIT_W-1:0] rx_flit [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg rx_match [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer last_egress_ps [0:NUM_PORTS-1];
  integer packet_head_ack_ps [0:MAX_PKT_SEQ-1];
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer delivered_packets, latency_count;
  integer latency_ps [0:MAX_EXPECT_FLITS-1];
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

  function integer total_expected;
    integer p, total;
    begin
      total = 0;
      for (p = 0; p < NUM_PORTS; p = p + 1) total = total + expected_port_count[p];
      total_expected = total;
    end
  endfunction

  generate
    if (STRUCTURAL_ENDPOINTS != 0) begin : g_structural_endpoints
      AsyncNoC16BoundaryDUT fabric (
        .reset(reset), .tb_in_req(tb_in_req), .tb_in_ack(tb_in_ack), .tb_in_data(tb_in_data),
        .tb_out_req(tb_out_req), .tb_out_ack(tb_out_ack), .tb_out_data(tb_out_data)
      );
    end else begin : g_behavioral_endpoints
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
    end
  endgenerate

  generate
    if (STRUCTURAL_ENDPOINTS != 0) begin : g_structural_aliases
      // Boundary diagnostics retain these names; they are not used to drive
      // the structural DUT.  The physical instance is g_structural_endpoints.fabric.
      assign noc_in_req  = g_structural_endpoints.fabric.noc_in_req;
      assign noc_in_ack  = g_structural_endpoints.fabric.noc_in_ack;
      assign noc_in_data = g_structural_endpoints.fabric.noc_in_data;
      assign noc_out_req = g_structural_endpoints.fabric.noc_out_req;
      assign noc_out_ack = g_structural_endpoints.fabric.noc_out_ack;
      assign noc_out_data = g_structural_endpoints.fabric.noc_out_data;
    end else if (TOP_LANES == 4) begin : g_behavioral_noc
      async_noc16_port_adapter noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end else begin : g_behavioral_noc_122
      async_noc16_port_adapter_top2 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end
  endgenerate

  task automatic parse_case;
    integer fd, n, p, cyc, pkt, idx, line_no;
    reg [STR_CHARS*8-1:0] line, tag, word;
    reg [31:0] mask_word;
    reg [FLIT_W-1:0] flit;
    begin
      input_count = 0; expected_count = 0;
      reset_cycles = 10; timeout_cycles = 5000000;
      case_name = ""; case_group = "";
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        expected_port_count[p] = 0; expected_cursor[p] = 0; rx_count[p] = 0;
        last_egress_ps[p] = -1; active_input[p] = -1;
      end
      for (idx = 0; idx < MAX_PKT_SEQ; idx = idx + 1) packet_head_ack_ps[idx] = -1;
      fd = $fopen(case_file, "r");
      if (fd == 0) begin $display("TB_FATAL cannot open CASE_FILE=%0s", case_file); $finish; end
      line_no = 0;
      while (!$feof(fd)) begin
        line = "";
        if ($fgets(line, fd) != 0) begin
          line_no = line_no + 1; tag = ""; word = "";
          if ($sscanf(line, "%s", tag) == 1 && tag != "#") begin
            if (tag == "case") n = $sscanf(line, "%s %s", tag, case_name);
            else if (tag == "group") n = $sscanf(line, "%s %s", tag, case_group);
            else if (tag == "reset_cycles") n = $sscanf(line, "%s %d", tag, reset_cycles);
            else if (tag == "timeout_cycles") n = $sscanf(line, "%s %d", tag, timeout_cycles);
            else if (tag == "input") begin
              n = $sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt, flit);
              if (n != 5 || p < 0 || p >= NUM_PORTS || input_count >= MAX_INPUT_FLITS) begin
                $display("TB_FATAL malformed input at line %0d", line_no); $finish;
              end
              input_cycle[input_count] = cyc; input_port[input_count] = p;
              input_pkt_seq[input_count] = pkt; input_flit[input_count] = flit;
              input_offer_ps[input_count] = -1; input_req_ps[input_count] = -1;
              input_ack_ps[input_count] = -1; input_accepted[input_count] = 1'b0;
              input_count = input_count + 1;
            end else if (tag == "expect") begin
              n = $sscanf(line, "%s %h %d %d %h", tag, mask_word, pkt, cyc, flit);
              if (n != 5 || expected_count >= MAX_EXPECT_FLITS) begin
                $display("TB_FATAL malformed expect at line %0d", line_no); $finish;
              end
              expected_mask[expected_count] = mask_word[NUM_PORTS-1:0];
              expected_pkt_seq[expected_count] = pkt; expected_is_tail[expected_count] = cyc[0];
              expected_flit[expected_count] = flit; expected_seen[expected_count] = 1'b0;
              for (p = 0; p < NUM_PORTS; p = p + 1) if (mask_word[p]) begin
                if (expected_port_count[p] >= MAX_RX_PER_PORT) begin $display("TB_FATAL expected queue overflow p=%0d", p); $finish; end
                expected_port_index[p][expected_port_count[p]] = expected_count;
                expected_port_count[p] = expected_port_count[p] + 1;
              end
              expected_count = expected_count + 1;
            end
          end
        end
      end
      $fclose(fd);
      if (total_expected() != expected_count) begin
        $display("TB_FATAL expected masks must be one-hot: entries=%0d expanded=%0d", expected_count, total_expected()); $finish;
      end
    end
  endtask

  task automatic drive_port(input integer port);
    integer i;
    real due_ns;
    reg old_noc_req;
    begin
      for (i = 0; i < input_count; i = i + 1) if (input_port[i] == port) begin
        if (!inject_max_rate) begin
          due_ns = case_epoch_ns + input_cycle[i] * case_tick_ns;
          if ($realtime < due_ns) #(due_ns - $realtime);
          input_offer_ps[i] = $rtoi(due_ns * 1000.0 + 0.5);
        end
        // This wait is at the physical NoC boundary, not at a TB clock edge.
        wait ((noc_in_req[port] === noc_in_ack[port]) && (tb_in_req[port] === tb_in_ack[port]));
        if (inject_max_rate) input_offer_ps[i] = now_ps();
        tb_in_data[port*FLIT_W +: FLIT_W] = input_flit[i];
        #(tx_setup_ns);
        active_input[port] = i;
        old_noc_req = noc_in_req[port];
        tb_in_req[port] = ~tb_in_req[port];
        if (ROBUST_DIRECT_HANDSHAKE != 0) begin
          // Install the completion wait immediately after the outer Req
          // transition.  Splitting propagation and completion into two waits
          // can miss an Ack produced in the same VCS time slot.
          input_req_ps[i] = now_ps();
          wait (tb_in_req[port] === tb_in_ack[port]);
        end else begin
          // In structural mode Req reaches this point through a source
          // Mousetrap; in behavioral mode this is the same physical boundary.
          wait (noc_in_req[port] !== old_noc_req);
          input_req_ps[i] = now_ps();
          wait (noc_in_req[port] === noc_in_ack[port]);
        end
        input_ack_ps[i] = now_ps();
        input_accepted[i] = 1'b1;
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PKT_SEQ)
          packet_head_ack_ps[input_pkt_seq[i]] = input_ack_ps[i];
        active_input[port] = -1;
        // CMR-WP-01 interface contract: after observing completion, a source
        // must leave enough time for the receiver's write pointer to close
        // the old CellFull latch and open exactly one next latch before it
        // toggles the next Req/data bundle.  This is an environment timing
        // constraint, not a delay inserted into the Ack channel itself.
        if (ack_to_next_req_guard_ns > 0.0) #(ack_to_next_req_guard_ns);
      end
      input_done[port] = 1'b1;
    end
  endtask

  task automatic receive_port(input integer port);
    integer slot, exp_idx, scan;
    reg found;
    reg [FLIT_W-1:0] captured;
    begin
      forever begin
        wait (running && (tb_out_req[port] !== tb_out_ack[port]));
        if ((tb_out_req[port] === 1'bx) || (tb_out_ack[port] === 1'bx) || (^tb_out_data[port*FLIT_W +: FLIT_W] === 1'bx)) begin
          $display("TB_PROTOCOL_X port=%0d t=%0t req=%b ack=%b data=%h", port, $time, tb_out_req[port], tb_out_ack[port], tb_out_data[port*FLIT_W +: FLIT_W]);
        end
        #(rx_capture_ns);
        captured = tb_out_data[port*FLIT_W +: FLIT_W];
        slot = rx_count[port];
        if (slot >= MAX_RX_PER_PORT) begin $display("TB_FATAL RX overflow port=%0d", port); $finish; end
        rx_time_ps[port][slot] = now_ps();
        rx_egress_ps[port][slot] = last_egress_ps[port];
        rx_flit[port][slot] = captured;
        // Traffic from distinct input ports is concurrent, so a case file
        // cannot prescribe one global arrival order at a shared output.  Keep
        // the established checker contract: consume one still-unseen expected
        // flit for this output and preserve every delivery in the event log.
        exp_idx = -1; found = 1'b0;
        for (scan = 0; scan < expected_count; scan = scan + 1)
          if (!found && !expected_seen[scan] && expected_mask[scan][port] && (captured === expected_flit[scan])) begin
            exp_idx = scan; found = 1'b1; expected_seen[scan] = 1'b1;
          end
        rx_expected_index[port][slot] = exp_idx;
        rx_match[port][slot] = found;
        if (rx_match[port][slot]) expected_cursor[port] = expected_cursor[port] + 1;
        else unexpected_flits = unexpected_flits + 1;
        rx_count[port] = slot + 1;
        // Ack is deliberately delayed from observed capture; never follows a
        // clock edge and never collapses a NoC output pulse in the same slot.
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  task automatic write_results;
    integer p, s, i, j, tmp, fd_summary, fd_events, fd_latency;
    integer lat_sum, max_lat, p95_lat, p99_lat, rank95, rank99, packet, lat, injected_packets;
    real avg_lat_ns, elapsed_ns, throughput;
    reg pass_ok;
    begin
      injected_flits = 0; injected_packets = 0; missing_flits = 0; delivered_flits = total_rx();
      delivered_packets = 0; latency_count = 0; lat_sum = 0; max_lat = 0;
      for (i = 0; i < input_count; i = i + 1) if (input_accepted[i]) begin
        injected_flits = injected_flits + 1;
        if (input_flit[i][27]) injected_packets = injected_packets + 1;
      end
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s]) begin
          i = rx_expected_index[p][s];
          if (expected_is_tail[i]) begin
            packet = expected_pkt_seq[i];
            if (packet >= 0 && packet < MAX_PKT_SEQ && packet_head_ack_ps[packet] >= 0 && rx_egress_ps[p][s] >= 0) begin
              lat = rx_egress_ps[p][s] - packet_head_ack_ps[packet];
              latency_ps[latency_count] = lat; latency_count = latency_count + 1;
              lat_sum = lat_sum + lat; if (lat > max_lat) max_lat = lat;
              delivered_packets = delivered_packets + 1;
            end
          end
        end
      end
      for (i = 0; i < expected_count; i = i + 1) if (!expected_seen[i]) missing_flits = missing_flits + 1;
      for (i = 0; i < latency_count; i = i + 1) for (j = i + 1; j < latency_count; j = j + 1)
        if (latency_ps[j] < latency_ps[i]) begin tmp = latency_ps[i]; latency_ps[i] = latency_ps[j]; latency_ps[j] = tmp; end
      if (latency_count > 0) begin
        rank95 = (95 * latency_count + 99) / 100; if (rank95 > latency_count) rank95 = latency_count;
        rank99 = (99 * latency_count + 99) / 100; if (rank99 > latency_count) rank99 = latency_count;
        p95_lat = latency_ps[rank95-1]; p99_lat = latency_ps[rank99-1];
      end else begin p95_lat = 0; p99_lat = 0; end
      avg_lat_ns = latency_count ? (lat_sum * 1.0 / latency_count / 1000.0) : 0.0;
      elapsed_ns = $realtime - case_epoch_ns;
      throughput = elapsed_ns > 0.0 ? (delivered_flits * case_tick_ns / elapsed_ns) : 0.0;
      pass_ok = !timed_out && (injected_flits == input_count) && (missing_flits == 0) && (unexpected_flits == 0);

      fd_summary = $fopen(csv_file, "w");
      $fwrite(fd_summary, "group,case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,rx_overflow,measure_cycles,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      $fwrite(fd_summary, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0,%0d,%f,%f,%f,%f,%f,%0s\n", case_group, case_name, injected_packets, delivered_packets, injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, $rtoi(elapsed_ns/case_tick_ns), throughput, avg_lat_ns, max_lat/1000.0, p95_lat/1000.0, p99_lat/1000.0, pass_ok ? "PASS" : "FAIL");
      $fclose(fd_summary);

      fd_events = $fopen(event_csv_file, "w");
      $fwrite(fd_events, "kind,port,pkt_seq,flit,offer_ps,req_ps,ack_ps,egress_req_ps,capture_ps,matched\n");
      for (i = 0; i < input_count; i = i + 1)
        $fwrite(fd_events, "TX,%0d,%0d,%h,%0d,%0d,%0d,-1,-1,%0d\n", input_port[i], input_pkt_seq[i], input_flit[i], input_offer_ps[i], input_req_ps[i], input_ack_ps[i], input_accepted[i]);
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        $fwrite(fd_events, "RX,%0d,%0d,%h,-1,-1,-1,%0d,%0d,%0d\n", p, rx_expected_index[p][s] >= 0 ? expected_pkt_seq[rx_expected_index[p][s]] : -1, rx_flit[p][s], rx_egress_ps[p][s], rx_time_ps[p][s], rx_match[p][s]);
      $fclose(fd_events);

      fd_latency = $fopen(latency_csv_file, "w");
      $fwrite(fd_latency, "port,pkt_seq,tail_flit,head_ingress_ack_ps,tail_egress_req_ps,tail_capture_ps,network_latency_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s] && expected_is_tail[rx_expected_index[p][s]]) begin
        i = rx_expected_index[p][s]; packet = expected_pkt_seq[i];
        $fwrite(fd_latency, "%0d,%0d,%h,%0d,%0d,%0d,%f\n", p, packet, rx_flit[p][s], packet_head_ack_ps[packet], rx_egress_ps[p][s], rx_time_ps[p][s], (rx_egress_ps[p][s]-packet_head_ack_ps[packet])/1000.0);
      end
      $fclose(fd_latency);
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d inject_max_rate=%0d elapsed_ns=%0.3f flits_per_ns=%0.6f", pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, inject_max_rate, elapsed_ns, elapsed_ns > 0.0 ? (delivered_flits / elapsed_ns) : 0.0);
      finish_requested = 1'b1;
      #1 $finish;
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_boundary_monitors
      always @(noc_out_req[gp]) if (running && noc_out_req[gp] !== noc_out_ack[gp]) last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
    end
  endgenerate

  initial begin
    case_file = ""; csv_file = "async_noc16_summary.csv"; event_csv_file = "async_noc16_events.csv"; latency_csv_file = "async_noc16_latency.csv";
    // Both boundary delays are physical setup/capture intervals, not clocks.
    // The structural sink adds its own DEL050 before returning NoC Ack.
    case_tick_ns = 20.0; tx_setup_ns = 0.05; rx_capture_ns = 0.05;
    // Direct-boundary mode has no physical endpoint wrapper.  Its default
    // therefore enforces the same CMR-WP-01 source contract as the structural
    // endpoint's DEL150+DEL050 turnaround cell chain.
    ack_to_next_req_guard_ns = 0.20; timeout_scale = 1.0; inject_max_rate = 0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    if ($test$plusargs("INJECT_MAX_RATE")) inject_max_rate = 1;
    if ($value$plusargs("DUMP_VCD=%s", dump_vcd)) begin $dumpfile(dump_vcd); $dumpvars(0, noc16_async_boundary_core); end
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    $display("TB_INFO ACK_TO_NEXT_REQ_GUARD_NS=%0.3f INJECT_MAX_RATE=%0d CASE_TICK_NS=%0.3f", ack_to_next_req_guard_ns, inject_max_rate, case_tick_ns);
    parse_case();
    reset = 1'b1; tb_in_req = '0; tb_in_data = '0; tb_out_ack = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
    case_epoch_ns = $realtime;
    timeout_ns = timeout_cycles * case_tick_ns * timeout_scale;
    drain_ns = 1024.0 * case_tick_ns;
    running = 1'b1;
    fork
      drive_port(0); drive_port(1); drive_port(2); drive_port(3); drive_port(4);
      drive_port(5); drive_port(6); drive_port(7); drive_port(8); drive_port(9);
      drive_port(10); drive_port(11); drive_port(12); drive_port(13); drive_port(14);
      drive_port(15); drive_port(16); drive_port(17); drive_port(18); drive_port(19);
    join
  end

  initial begin : completion_watchdog
    wait(running);
    fork
      begin
        wait(&input_done);
        while (total_rx() < total_expected()) @rx_activity;
        #(drain_ns);
        if (!finish_requested) write_results();
      end
      begin
        #(timeout_ns);
        if (!finish_requested) begin timed_out = 1'b1; write_results(); end
      end
    join_any
    disable fork;
  end

`ifdef ASYNC_NOC16_CORE0_TO15_TRACE
  // Simulation-only strict-SDF trace for the unique Core0 -> Core15 path.
  // These aliases neither drive nor gate the DUT; they exist solely to make
  // the first missing two-phase edge observable in the unified boundary run.
  // Physical route: source0 -> L1(0,0).in3/out4 -> upFIFO3 -> L2.in3/out0
  //                 -> downFIFO0 -> L1(1,1).in4/out0 -> sink15.
  wire c015_tb_req = tb_in_req[0];
  wire c015_tb_ack = tb_in_ack[0];
  wire [27:0] c015_tb_data = tb_in_data[0*FLIT_W +: FLIT_W];
  wire c015_src_req = g_structural_endpoints.fabric.noc_in_req[0];
  wire c015_src_ack = g_structural_endpoints.fabric.noc_in_ack[0];
  wire [27:0] c015_src_data = g_structural_endpoints.fabric.noc_in_data[0*FLIT_W +: FLIT_W];
  wire c015_sink_req = g_structural_endpoints.fabric.noc_out_req[15];
  wire c015_sink_ack = g_structural_endpoints.fabric.noc_out_ack[15];
  wire [27:0] c015_sink_data = g_structural_endpoints.fabric.noc_out_data[15*FLIT_W +: FLIT_W];
  wire c015_tb_out_req = tb_out_req[15];
  wire c015_tb_out_ack = tb_out_ack[15];
  wire [27:0] c015_tb_out_data = tb_out_data[15*FLIT_W +: FLIT_W];

  wire c015_l1a_reqx = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.inputModules_3.io_ReqX;
  wire c015_l1a_ackx = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.inputModules_3.ackGenerator.io_AckX;
  wire c015_l1a_en = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.inputModules_3.mousetrap.latch_en;
  wire c015_l1a_v1q = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.inputModules_3.mousetrap.request_latch.q;
  wire [27:0] c015_l1a_v1data = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.inputModules_3.mousetrap.data_latch.q;
  wire c015_l1a_req = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.requestBanks_3.io_Req_3;
  wire c015_l1a_ack = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.requestBanks_3.io_Ack_3;
  wire c015_l1a_done = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.requestBanks_3.io_Done_3;
  wire c015_l1a_ppe = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.requestBanks_3.io_PPE_3;
  wire c015_l1a_grant = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.io_Grant_3;
  wire c015_l1a_mg = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.io_MG_3;
  wire c015_l1a_l1d = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestLatches_3.d;
  wire c015_l1a_l1e = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestLatches_3.en;
  wire c015_l1a_l1q = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestLatches_3.q;
  wire c015_l1a_l5d = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestOutLatch.d;
  wire c015_l1a_l5e = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestOutLatch.en;
  wire c015_l1a_l5q = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.requestOutLatch.q;
  wire [27:0] c015_l1a_v2d = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.dataOutLatch.d;
  wire [27:0] c015_l1a_v2q = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.dataOutLatch.q;
  wire c015_l1a_cp = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.closeEvent.close_clock;
  wire c015_l1a_ackcp = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.ackState_3_reg.CP;
  wire c015_l1a_ackq = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.ackState_3_reg.Q;
  wire c015_l1a_outreq = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.io_ReqOut;
  wire c015_l1a_outack = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.io_AckOut;
  wire [27:0] c015_l1a_outdata = g_structural_endpoints.fabric.noc.dut.routerL1_0_0.outputModules_4.io_DataOut_flit;

  wire c015_up_enq_req = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_enq_HS_Req;
  wire c015_up_enq_ack = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_enq_HS_Ack;
  wire [27:0] c015_up_enq_data = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_enq_Data_flit;
  wire c015_up_deq_req = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_deq_HS_Req;
  wire c015_up_deq_ack = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_deq_HS_Ack;
  wire [27:0] c015_up_deq_data = g_structural_endpoints.fabric.noc.dut.upwardLinkFifos_3.io_deq_Data_flit;

  wire c015_l2_reqx = g_structural_endpoints.fabric.noc.dut.routerL2.inputModules_3.io_ReqX;
  wire c015_l2_ackx = g_structural_endpoints.fabric.noc.dut.routerL2.inputModules_3.ackGenerator.io_AckX;
  wire c015_l2_en = g_structural_endpoints.fabric.noc.dut.routerL2.inputModules_3.mousetrap.latch_en;
  wire c015_l2_req = g_structural_endpoints.fabric.noc.dut.routerL2.requestBanks_3.io_Req_0;
  wire c015_l2_ack = g_structural_endpoints.fabric.noc.dut.routerL2.requestBanks_3.io_Ack_0;
  wire c015_l2_done = g_structural_endpoints.fabric.noc.dut.routerL2.requestBanks_3.io_Done_0;
  wire c015_l2_ppe = g_structural_endpoints.fabric.noc.dut.routerL2.requestBanks_3.io_PPE_0;
  wire c015_l2_grant = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.io_Grant_2;
  wire c015_l2_mg = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.io_MG_2;
  wire c015_l2_l1d = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestLatches_2.d;
  wire c015_l2_l1e = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestLatches_2.en;
  wire c015_l2_l1q = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestLatches_2.q;
  wire c015_l2_l5d = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestOutLatch.d;
  wire c015_l2_l5e = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestOutLatch.en;
  wire c015_l2_l5q = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.requestOutLatch.q;
  wire [27:0] c015_l2_v2d = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.dataOutLatch.d;
  wire [27:0] c015_l2_v2q = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.dataOutLatch.q;
  wire c015_l2_cp = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.closeEvent.close_clock;
  wire c015_l2_ackcp = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.ackState_2_reg.CP;
  wire c015_l2_ackq = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.ackState_2_reg.Q;
  wire c015_l2_outreq = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.io_ReqOut;
  wire c015_l2_outack = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.io_AckOut;
  wire [27:0] c015_l2_outdata = g_structural_endpoints.fabric.noc.dut.routerL2.outputModules_0.io_DataOut_flit;

  wire c015_down_enq_req = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_enq_HS_Req;
  wire c015_down_enq_ack = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_enq_HS_Ack;
  wire [27:0] c015_down_enq_data = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_enq_Data_flit;
  wire c015_down_deq_req = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_deq_HS_Req;
  wire c015_down_deq_ack = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_deq_HS_Ack;
  wire [27:0] c015_down_deq_data = g_structural_endpoints.fabric.noc.dut.downwardLinkFifos_0.io_deq_Data_flit;

  wire c015_l1b_reqx = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.inputModules_4.io_ReqX;
  wire c015_l1b_ackx = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.inputModules_4.ackGenerator.io_AckX;
  wire c015_l1b_en = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.inputModules_4.mousetrap.latch_en;
  wire c015_l1b_req = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.requestBanks_4.io_Req_0;
  wire c015_l1b_ack = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.requestBanks_4.io_Ack_0;
  wire c015_l1b_done = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.requestBanks_4.io_Done_0;
  wire c015_l1b_ppe = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.requestBanks_4.io_PPE_0;
  wire c015_l1b_grant = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.io_Grant_3;
  wire c015_l1b_mg = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.io_MG_3;
  wire c015_l1b_l1d = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestLatches_3.d;
  wire c015_l1b_l1e = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestLatches_3.en;
  wire c015_l1b_l1q = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestLatches_3.q;
  wire c015_l1b_l5d = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestOutLatch.d;
  wire c015_l1b_l5e = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestOutLatch.en;
  wire c015_l1b_l5q = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.requestOutLatch.q;
  wire [27:0] c015_l1b_v2d = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.dataOutLatch.d;
  wire [27:0] c015_l1b_v2q = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.dataOutLatch.q;
  wire c015_l1b_cp = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.closeEvent.close_clock;
  wire c015_l1b_ackcp = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.ackState_3_reg.CP;
  wire c015_l1b_ackq = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.ackState_3_reg.Q;
  wire c015_l1b_outreq = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.io_ReqOut;
  wire c015_l1b_outack = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.io_AckOut;
  wire [27:0] c015_l1b_outdata = g_structural_endpoints.fabric.noc.dut.routerL1_1_1.outputModules_0.io_DataOut_flit;
  time c015_l1b_close_start_ps;
  time c015_l1b_close_width_ps;
  integer c015_l1b_close_seq;

  integer c015_trace_fd;
  integer c015_trace_enable;
  reg [2047:0] c015_trace_file, c015_trace_vcd;
  task automatic c015_snapshot;
    input [8*32-1:0] tag;
    begin
      if (c015_trace_enable && c015_trace_fd != 0) begin
        $fdisplay(c015_trace_fd, "C015 t=%0.3fns tag=%0s SRC={tb %b/%b %h noc %b/%b %h} L1A={V1 %b/%b E=%b Q=%b %h RG=%b/%b D=%b PPE=%b G=%b MG=%b L1=%b/%b/%b L5=%b/%b/%b V2=%h/%h CP=%b AckDFF=%b/%b OUT=%b/%b %h} UP={ENQ %b/%b %h DEQ %b/%b %h}", $realtime, tag, c015_tb_req, c015_tb_ack, c015_tb_data, c015_src_req, c015_src_ack, c015_src_data, c015_l1a_reqx, c015_l1a_ackx, c015_l1a_en, c015_l1a_v1q, c015_l1a_v1data, c015_l1a_req, c015_l1a_ack, c015_l1a_done, c015_l1a_ppe, c015_l1a_grant, c015_l1a_mg, c015_l1a_l1d, c015_l1a_l1e, c015_l1a_l1q, c015_l1a_l5d, c015_l1a_l5e, c015_l1a_l5q, c015_l1a_v2d, c015_l1a_v2q, c015_l1a_cp, c015_l1a_ackcp, c015_l1a_ackq, c015_l1a_outreq, c015_l1a_outack, c015_l1a_outdata, c015_up_enq_req, c015_up_enq_ack, c015_up_enq_data, c015_up_deq_req, c015_up_deq_ack, c015_up_deq_data);
        $fdisplay(c015_trace_fd, "C015 t=%0.3fns tag=%0s L2={V1 %b/%b E=%b RG=%b/%b D=%b PPE=%b G=%b MG=%b L1=%b/%b/%b L5=%b/%b/%b V2=%h/%h CP=%b AckDFF=%b/%b OUT=%b/%b %h} DOWN={ENQ %b/%b %h DEQ %b/%b %h} L1B={V1 %b/%b E=%b RG=%b/%b D=%b PPE=%b G=%b MG=%b L1=%b/%b/%b L5=%b/%b/%b V2=%h/%h CP=%b AckDFF=%b/%b OUT=%b/%b %h close_low_ps=%0d} SINK={noc %b/%b %h tb %b/%b %h}", $realtime, tag, c015_l2_reqx, c015_l2_ackx, c015_l2_en, c015_l2_req, c015_l2_ack, c015_l2_done, c015_l2_ppe, c015_l2_grant, c015_l2_mg, c015_l2_l1d, c015_l2_l1e, c015_l2_l1q, c015_l2_l5d, c015_l2_l5e, c015_l2_l5q, c015_l2_v2d, c015_l2_v2q, c015_l2_cp, c015_l2_ackcp, c015_l2_ackq, c015_l2_outreq, c015_l2_outack, c015_l2_outdata, c015_down_enq_req, c015_down_enq_ack, c015_down_enq_data, c015_down_deq_req, c015_down_deq_ack, c015_down_deq_data, c015_l1b_reqx, c015_l1b_ackx, c015_l1b_en, c015_l1b_req, c015_l1b_ack, c015_l1b_done, c015_l1b_ppe, c015_l1b_grant, c015_l1b_mg, c015_l1b_l1d, c015_l1b_l1e, c015_l1b_l1q, c015_l1b_l5d, c015_l1b_l5e, c015_l1b_l5q, c015_l1b_v2d, c015_l1b_v2q, c015_l1b_cp, c015_l1b_ackcp, c015_l1b_ackq, c015_l1b_outreq, c015_l1b_outack, c015_l1b_outdata, c015_l1b_close_width_ps, c015_sink_req, c015_sink_ack, c015_sink_data, c015_tb_out_req, c015_tb_out_ack, c015_tb_out_data);
      end
    end
  endtask
  initial begin
    c015_trace_enable = 0; c015_trace_fd = 0; c015_l1b_close_start_ps = 0; c015_l1b_close_width_ps = 0; c015_l1b_close_seq = 0;
    if ($test$plusargs("CORE0_TO15_TRACE")) c015_trace_enable = 1;
    if (c015_trace_enable) begin
      if (!$value$plusargs("CORE0_TO15_TRACE_FILE=%s", c015_trace_file)) c015_trace_file = "core0_to_core15.trace";
      c015_trace_fd = $fopen(c015_trace_file, "w");
      if (c015_trace_fd == 0) begin $display("TB_FATAL cannot open CORE0_TO15_TRACE_FILE=%0s", c015_trace_file); $finish; end
      $fdisplay(c015_trace_fd, "# Core0 -> Core15 unified-boundary strict-SDF trace; aliases are read-only");
      if ($value$plusargs("CORE0_TO15_TRACE_VCD=%s", c015_trace_vcd)) begin
        $dumpfile(c015_trace_vcd);
        $dumpvars(0, c015_tb_req, c015_tb_ack, c015_tb_data, c015_src_req, c015_src_ack, c015_src_data, c015_l1a_reqx, c015_l1a_ackx, c015_l1a_req, c015_l1a_ack, c015_l1a_done, c015_l1a_ppe, c015_l1a_outreq, c015_l1a_outack, c015_up_enq_req, c015_up_enq_ack, c015_up_deq_req, c015_up_deq_ack, c015_l2_reqx, c015_l2_ackx, c015_l2_req, c015_l2_ack, c015_l2_done, c015_l2_ppe, c015_l2_outreq, c015_l2_outack, c015_down_enq_req, c015_down_enq_ack, c015_down_deq_req, c015_down_deq_ack, c015_l1b_reqx, c015_l1b_ackx, c015_l1b_en, c015_l1b_req, c015_l1b_ack, c015_l1b_done, c015_l1b_ppe, c015_l1b_l1d, c015_l1b_l1e, c015_l1b_l1q, c015_l1b_l5d, c015_l1b_l5e, c015_l1b_l5q, c015_l1b_v2d, c015_l1b_v2q, c015_l1b_cp, c015_l1b_ackcp, c015_l1b_ackq, c015_l1b_outreq, c015_l1b_outack, c015_sink_req, c015_sink_ack, c015_tb_out_req, c015_tb_out_ack);
      end
      c015_snapshot("trace_start");
    end
  end
  always @(c015_tb_req or c015_tb_ack or c015_src_req or c015_src_ack) c015_snapshot("source_edge");
  always @(c015_l1a_reqx or c015_l1a_ackx or c015_l1a_req or c015_l1a_ack or c015_l1a_done or c015_l1a_ppe or c015_l1a_outreq or c015_l1a_outack) c015_snapshot("l1a_edge");
  always @(c015_up_enq_req or c015_up_enq_ack or c015_up_deq_req or c015_up_deq_ack) c015_snapshot("up_fifo_edge");
  always @(c015_l2_reqx or c015_l2_ackx or c015_l2_req or c015_l2_ack or c015_l2_done or c015_l2_ppe or c015_l2_outreq or c015_l2_outack) c015_snapshot("l2_edge");
  always @(c015_down_enq_req or c015_down_enq_ack or c015_down_deq_req or c015_down_deq_ack) c015_snapshot("down_fifo_edge");
  always @(c015_l1b_reqx or c015_l1b_ackx or c015_l1b_en or c015_l1b_req or c015_l1b_ack or c015_l1b_done or c015_l1b_ppe or c015_l1b_l1d or c015_l1b_l1e or c015_l1b_l1q or c015_l1b_l5d or c015_l1b_l5e or c015_l1b_l5q or c015_l1b_v2d or c015_l1b_v2q or c015_l1b_cp or c015_l1b_ackcp or c015_l1b_ackq or c015_l1b_outreq or c015_l1b_outack) c015_snapshot("l1b_edge");
  always @(c015_sink_req or c015_sink_ack or c015_tb_out_req or c015_tb_out_ack) c015_snapshot("sink_edge");
  always @(c015_l1b_l5e) begin
    if (c015_l1b_l5e === 1'b0) begin
      c015_l1b_close_start_ps = $time;
      c015_l1b_close_width_ps = 0;
    end else if (c015_l1b_l5e === 1'b1 && c015_l1b_close_start_ps != 0) begin
      c015_l1b_close_width_ps = $time - c015_l1b_close_start_ps;
      c015_l1b_close_seq = c015_l1b_close_seq + 1;
      if (c015_trace_enable && c015_trace_fd != 0)
        $fdisplay(c015_trace_fd, "C015_CLOSE seq=%0d start_ps=%0d width_ps=%0d cp=%b ackq=%b", c015_l1b_close_seq, c015_l1b_close_start_ps, c015_l1b_close_width_ps, c015_l1b_cp, c015_l1b_ackq);
    end
  end
`endif
endmodule

module tb_noc16_async_boundary;
  noc16_async_boundary_core #(.STRUCTURAL_ENDPOINTS(0)) core();
endmodule

module tb_noc16_async_boundary_structural;
  noc16_async_boundary_core #(.STRUCTURAL_ENDPOINTS(1)) core();
endmodule

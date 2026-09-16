`timescale 1ns/1ps

// Clocked valid/ready 64-core quadtree boundary.
// Same DATE V3 .case format as tb_noc64_async_boundary; handshake is valid/ready.
// Tmax uses source header injection (`head_inject_req_ps`), not per-packet max latency.
// TOP_LANES=1 Thin (1,1); TOP_LANES=2 Fat 1-2-2-2; TOP_LANES=8 Fat 1-2-4-8.
// Traffic arrival is open-loop: the .case fixes when each flit reaches the
// source queue.  Valid/ready only drains that queue; it must never control
// whether a later packet is created.
module noc64_sync_boundary_core #(
  parameter integer NUM_CORES = 64,
  parameter integer TOP_LANES = 1
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = NUM_CORES + TOP_LANES;
  localparam integer MAX_INPUT_FLITS = 131072;
  localparam integer MAX_EXPECT_FLITS = 262144;
  localparam integer MAX_RX_PER_PORT = 8192;
  localparam integer MAX_PKT_SEQ = 262144;
  localparam integer STR_CHARS = 256;
  localparam integer MASK_W = 128;
  localparam [2:0] IDENTITY_MAGIC = 3'b101;

  initial begin
    if (NUM_CORES != 64) begin
      $display("TB_FATAL NUM_CORES must be 64, got %0d", NUM_CORES);
      $finish;
    end
    if ((TOP_LANES != 1) && (TOP_LANES != 2) && (TOP_LANES != 8) && (TOP_LANES != 16)) begin
      $display("TB_FATAL TOP_LANES must be 1, 2, 8, or 16 (PROP_temp B8), got %0d", TOP_LANES);
      $finish;
    end
  end

  reg clock;
  reg reset;
  reg [NUM_PORTS-1:0] tb_in_valid;
  wire [NUM_PORTS-1:0] tb_in_ready;
  reg [NUM_PORTS*FLIT_W-1:0] tb_in_data;
  wire [NUM_PORTS-1:0] tb_out_valid;
  reg [NUM_PORTS-1:0] tb_out_ready;
  wire [NUM_PORTS*FLIT_W-1:0] tb_out_data;

  wire [NUM_PORTS-1:0] noc_in_valid, noc_in_ready;
  wire [NUM_PORTS*FLIT_W-1:0] noc_in_data;
  wire [NUM_PORTS-1:0] noc_out_valid, noc_out_ready;
  wire [NUM_PORTS*FLIT_W-1:0] noc_out_data;

  assign noc_in_valid = tb_in_valid;
  assign noc_in_data = tb_in_data;
  assign tb_in_ready = noc_in_ready;
  assign tb_out_valid = noc_out_valid;
  assign tb_out_data = noc_out_data;
  assign noc_out_ready = tb_out_ready;

`ifdef CMR_SYNC64_TOP16
  sync_noc64_port_adapter_top16 noc (
    .clock(clock),
    .reset(reset),
    .in_valid(noc_in_valid),
    .in_ready(noc_in_ready),
    .in_data(noc_in_data),
    .out_valid(noc_out_valid),
    .out_ready(noc_out_ready),
    .out_data(noc_out_data)
  );
`elsif CMR_SYNC64_TOP8
  sync_noc64_port_adapter_top8 noc (
    .clock(clock),
    .reset(reset),
    .in_valid(noc_in_valid),
    .in_ready(noc_in_ready),
    .in_data(noc_in_data),
    .out_valid(noc_out_valid),
    .out_ready(noc_out_ready),
    .out_data(noc_out_data)
  );
`elsif CMR_SYNC64_TOP2
  sync_noc64_port_adapter_top2 noc (
    .clock(clock),
    .reset(reset),
    .in_valid(noc_in_valid),
    .in_ready(noc_in_ready),
    .in_data(noc_in_data),
    .out_valid(noc_out_valid),
    .out_ready(noc_out_ready),
    .out_data(noc_out_data)
  );
`else
  sync_noc64_port_adapter_top1 noc (
    .clock(clock),
    .reset(reset),
    .in_valid(noc_in_valid),
    .in_ready(noc_in_ready),
    .in_data(noc_in_data),
    .out_valid(noc_out_valid),
    .out_ready(noc_out_ready),
    .out_data(noc_out_data)
  );
`endif

  reg [NUM_PORTS-1:0] input_done;
  reg running, timed_out, finish_requested;

  integer reset_cycles, timeout_cycles;
  real clock_period_ns, case_tick_ns, rx_capture_ns, timeout_scale;
  real case_epoch_ns, timeout_ns, drain_ns;
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file, flit_latency_csv_file, v3_metrics_file;
  reg [STR_CHARS*8-1:0] case_name, case_group;
  reg [2047:0] dump_vcd;

  integer input_count, expected_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];
  longint input_offer_ps [0:MAX_INPUT_FLITS-1];
  longint input_req_ps [0:MAX_INPUT_FLITS-1];
  longint input_ack_ps [0:MAX_INPUT_FLITS-1];
  reg input_accepted [0:MAX_INPUT_FLITS-1];
  integer active_input [0:NUM_PORTS-1];
  integer port_first_input [0:NUM_PORTS-1];
  integer port_input_count [0:NUM_PORTS-1];
  integer port_arrived_count [0:NUM_PORTS-1];
  integer port_served_count [0:NUM_PORTS-1];
  integer source_queue_flits [0:NUM_PORTS-1];

  integer expected_port_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer expected_port_count [0:NUM_PORTS-1];
  integer expected_cursor [0:NUM_PORTS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [MASK_W-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];
  integer expected_input_index [0:MAX_EXPECT_FLITS-1];

  integer rx_count [0:NUM_PORTS-1];
  longint rx_time_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint rx_egress_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer rx_expected_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg [FLIT_W-1:0] rx_flit [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg rx_match [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint last_egress_ps [0:NUM_PORTS-1];
  longint packet_head_ack_ps [0:MAX_PKT_SEQ-1];
  longint packet_head_req_ps [0:MAX_PKT_SEQ-1];
  integer packet_event_id [0:MAX_PKT_SEQ-1];
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer delivered_packets, latency_count;
  longint latency_ps [0:MAX_EXPECT_FLITS-1];
  integer warmup_events, measurement_events;
  integer measurement_start_cycle, measurement_end_cycle;
  longint measurement_start_ps, measurement_end_ps;
  reg write_v3_metrics;
  reg dump_measurement_only;
  event rx_activity, source_arrival;
  reg case_has_identity;
  reg pending_head_valid [0:NUM_PORTS-1];
  reg [FLIT_W-1:0] pending_head_flit [0:NUM_PORTS-1];
  integer pending_head_slot [0:NUM_PORTS-1];

  function longint now_ps;
    begin
      now_ps = longint'($realtime * 1000.0 + 0.5);
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

  function automatic integer identity_pkt_seq;
    input [FLIT_W-1:0] flit;
    begin
      if (flit[27] || (flit[8:6] !== IDENTITY_MAGIC))
        identity_pkt_seq = -1;
      else
        identity_pkt_seq = flit[25:12];
    end
  endfunction

  task automatic score_rx_slot;
    input integer port;
    input integer slot;
    input integer exp_idx;
    begin
      rx_expected_index[port][slot] = exp_idx;
      rx_match[port][slot] = (exp_idx >= 0);
      if (exp_idx >= 0) expected_cursor[port] = expected_cursor[port] + 1;
      else unexpected_flits = unexpected_flits + 1;
    end
  endtask

  task automatic match_first_unseen;
    input integer port;
    input integer slot;
    input [FLIT_W-1:0] captured;
    integer scan, exp_idx;
    begin
      exp_idx = -1;
      for (scan = 0; scan < expected_count; scan = scan + 1)
        if ((exp_idx < 0) && !expected_seen[scan] && expected_mask[scan][port] &&
            (captured === expected_flit[scan])) begin
          exp_idx = scan;
          expected_seen[scan] = 1'b1;
        end
      score_rx_slot(port, slot, exp_idx);
    end
  endtask

  task automatic orphan_pending_head;
    input integer port;
    begin
      if (pending_head_valid[port]) begin
        score_rx_slot(port, pending_head_slot[port], -1);
        pending_head_valid[port] = 1'b0;
      end
    end
  endtask

  task automatic resolve_pending_head_fallback;
    input integer port;
    integer slot;
    begin
      if (pending_head_valid[port]) begin
        slot = pending_head_slot[port];
        pending_head_valid[port] = 1'b0;
        match_first_unseen(port, slot, pending_head_flit[port]);
      end
    end
  endtask

  task automatic bind_pending_head;
    input integer port;
    input integer pkt;
    integer scan, exp_idx, slot;
    reg [FLIT_W-1:0] head_flit;
    begin
      if (pending_head_valid[port]) begin
        slot = pending_head_slot[port];
        head_flit = pending_head_flit[port];
        pending_head_valid[port] = 1'b0;
        exp_idx = -1;
        for (scan = 0; scan < expected_count; scan = scan + 1)
          if ((exp_idx < 0) && !expected_seen[scan] && expected_mask[scan][port] &&
              (expected_pkt_seq[scan] == pkt) && expected_flit[scan][27])
            exp_idx = scan;
        if ((exp_idx >= 0) && (head_flit === expected_flit[exp_idx])) begin
          expected_seen[exp_idx] = 1'b1;
          score_rx_slot(port, slot, exp_idx);
        end else
          score_rx_slot(port, slot, -1);
      end
    end
  endtask

  task automatic release_pending_head;
    input integer port;
    begin
      if (pending_head_valid[port]) begin
        if (case_has_identity) orphan_pending_head(port);
        else resolve_pending_head_fallback(port);
      end
    end
  endtask

  task automatic flush_pending_heads;
    integer p;
    begin
      for (p = 0; p < NUM_PORTS; p = p + 1) release_pending_head(p);
    end
  endtask

  task automatic parse_case;
    integer fd, n, p, cyc, pkt, idx, line_no;
    reg [STR_CHARS*8-1:0] line, tag, word;
    reg [MASK_W-1:0] mask_word;
    reg [FLIT_W-1:0] flit;
    begin
      input_count = 0; expected_count = 0;
      reset_cycles = 32; timeout_cycles = 5000000;
      warmup_events = 0; measurement_events = 0;
      case_name = ""; case_group = "";
      case_has_identity = 1'b0;
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        expected_port_count[p] = 0; expected_cursor[p] = 0; rx_count[p] = 0;
        last_egress_ps[p] = -1; active_input[p] = -1;
        port_first_input[p] = -1; port_input_count[p] = 0;
        port_arrived_count[p] = 0; port_served_count[p] = 0;
        source_queue_flits[p] = 0;
        pending_head_valid[p] = 1'b0;
        pending_head_flit[p] = {FLIT_W{1'b0}};
        pending_head_slot[p] = -1;
      end
      for (idx = 0; idx < MAX_PKT_SEQ; idx = idx + 1) begin
        packet_head_ack_ps[idx] = -1;
        packet_head_req_ps[idx] = -1;
        packet_event_id[idx] = -1;
      end
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
            else if (tag == "meta") begin
              n = $sscanf(line, "%s %s %d", tag, word, cyc);
              if (word == "warmup_original_events") warmup_events = cyc;
              else if (word == "measurement_original_events") measurement_events = cyc;
            end else if (tag == "event_map") begin
              n = $sscanf(line, "%s %d %d", tag, pkt, cyc);
              if (n != 3 || pkt < 0 || pkt >= MAX_PKT_SEQ) begin
                $display("TB_FATAL malformed event_map at line %0d", line_no); $finish;
              end
              packet_event_id[pkt] = cyc;
            end else if (tag == "input") begin
              n = $sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt, flit);
              if (n != 5 || p < 0 || p >= NUM_PORTS || input_count >= MAX_INPUT_FLITS) begin
                $display("TB_FATAL malformed input at line %0d", line_no); $finish;
              end
              input_cycle[input_count] = cyc; input_port[input_count] = p;
              input_pkt_seq[input_count] = pkt; input_flit[input_count] = flit;
              if (port_first_input[p] < 0) port_first_input[p] = input_count;
              else if (input_count != port_first_input[p] + port_input_count[p]) begin
                $display("TB_FATAL inputs must be grouped by port; p=%0d line=%0d", p, line_no); $finish;
              end
              port_input_count[p] = port_input_count[p] + 1;
              input_offer_ps[input_count] = -1; input_req_ps[input_count] = -1;
              input_ack_ps[input_count] = -1; input_accepted[input_count] = 1'b0;
              input_count = input_count + 1;
            end else if (tag == "expect") begin
              n = $sscanf(line, "%s %h %d %d %h", tag, mask_word, pkt, cyc, flit);
              if (n != 5 || expected_count >= MAX_EXPECT_FLITS) begin
                $display("TB_FATAL malformed expect at line %0d", line_no); $finish;
              end
              expected_mask[expected_count] = mask_word[MASK_W-1:0];
              expected_pkt_seq[expected_count] = pkt; expected_is_tail[expected_count] = cyc[0];
              expected_flit[expected_count] = flit; expected_seen[expected_count] = 1'b0;
              if (!flit[27] && (flit[8:6] === IDENTITY_MAGIC)) case_has_identity = 1'b1;
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
      measurement_start_cycle = -1; measurement_end_cycle = -1;
      for (idx = 0; idx < input_count; idx = idx + 1)
        if (input_flit[idx][27] &&
            (packet_event_id[input_pkt_seq[idx]] < 0 ||
             packet_event_id[input_pkt_seq[idx]] >= warmup_events)) begin
          if (measurement_start_cycle < 0 || input_cycle[idx] < measurement_start_cycle)
            measurement_start_cycle = input_cycle[idx];
          if (measurement_end_cycle < input_cycle[idx] + 1)
            measurement_end_cycle = input_cycle[idx] + 1;
        end
      if (measurement_start_cycle < 0 || measurement_end_cycle <= measurement_start_cycle) begin
        $display("TB_FATAL missing measurement packet window"); $finish;
      end
      for (idx = 0; idx < expected_count; idx = idx + 1) begin
        expected_input_index[idx] = -1;
        for (n = 0; n < input_count; n = n + 1)
          if ((expected_input_index[idx] < 0) &&
              (input_pkt_seq[n] == expected_pkt_seq[idx]) &&
              (input_flit[n] === expected_flit[idx]))
            expected_input_index[idx] = n;
        if (expected_input_index[idx] < 0) begin
          $display("TB_FATAL expected/source join failed pkt=%0d flit=%h",
                   expected_pkt_seq[idx], expected_flit[idx]);
          $finish;
        end
      end
    end
  endtask

  // An arrival is recorded at its case time even if the DUT is stalled.  This
  // is deliberately independent of tb_in_ready: it is the open-loop offered
  // load used by the asynchronous boundary TB as well.
  task automatic arrive_port(input integer port);
    integer i;
    real due_ns;
    begin
      wait (running);
      for (i = port_first_input[port];
           i < port_first_input[port] + port_input_count[port]; i = i + 1) begin
        due_ns = case_epoch_ns + input_cycle[i] * case_tick_ns;
        while ($realtime < due_ns) @(posedge clock);
        input_offer_ps[i] = longint'(due_ns * 1000.0 + 0.5);
        port_arrived_count[port] = port_arrived_count[port] + 1;
        source_queue_flits[port] = source_queue_flits[port] + 1;
        -> source_arrival;
      end
    end
  endtask

  // The service process is the sole queue consumer.  Ready may delay a flit,
  // but cannot suppress or resample any case arrival.  Consecutive queued
  // flits keep valid asserted across transfers, so a ready-high DUT receives
  // the five flits of an ASAP packet on consecutive clock edges.
  task automatic service_port(input integer port);
    integer i;
    integer flit_presented;
    begin
      wait (running);
      flit_presented = 0;
      while (port_served_count[port] < port_input_count[port]) begin
        wait (source_queue_flits[port] > 0);
        if (!flit_presented) begin
          i = port_first_input[port] + port_served_count[port];
          @(negedge clock);
          active_input[port] = i;
          tb_in_data[port*FLIT_W +: FLIT_W] = input_flit[i];
          tb_in_valid[port] = 1'b1;
          flit_presented = 1;
        end
        @(posedge clock);
        while (!(tb_in_valid[port] === 1'b1 && tb_in_ready[port] === 1'b1)) @(posedge clock);
        input_req_ps[i] = now_ps();
        input_ack_ps[i] = now_ps();
        input_accepted[i] = 1'b1;
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PKT_SEQ) begin
          packet_head_req_ps[input_pkt_seq[i]] = input_req_ps[i];
          packet_head_ack_ps[input_pkt_seq[i]] = input_ack_ps[i];
        end
        source_queue_flits[port] = source_queue_flits[port] - 1;
        port_served_count[port] = port_served_count[port] + 1;
        @(negedge clock);
        if ((port_served_count[port] < port_input_count[port]) &&
            (source_queue_flits[port] > 0)) begin
          i = port_first_input[port] + port_served_count[port];
          active_input[port] = i;
          tb_in_data[port*FLIT_W +: FLIT_W] = input_flit[i];
          tb_in_valid[port] = 1'b1;
          flit_presented = 1;
        end else begin
          tb_in_valid[port] = 1'b0;
          active_input[port] = -1;
          flit_presented = 0;
        end
      end
      input_done[port] = 1'b1;
    end
  endtask

  task automatic capture_rx(input integer port);
    integer slot, pkt;
    reg [FLIT_W-1:0] captured;
    begin
      captured = tb_out_data[port*FLIT_W +: FLIT_W];
      slot = rx_count[port];
      if (slot >= MAX_RX_PER_PORT) begin $display("TB_FATAL RX overflow port=%0d", port); $finish; end
      rx_time_ps[port][slot] = now_ps();
      rx_egress_ps[port][slot] = last_egress_ps[port];
      rx_flit[port][slot] = captured;
      rx_expected_index[port][slot] = -1;
      rx_match[port][slot] = 1'b0;
      if (captured[27]) begin
        release_pending_head(port);
        pending_head_valid[port] = 1'b1;
        pending_head_flit[port] = captured;
        pending_head_slot[port] = slot;
      end else begin
        pkt = identity_pkt_seq(captured);
        if (pkt >= 0) begin
          match_first_unseen(port, slot, captured);
          bind_pending_head(port, pkt);
        end else begin
          release_pending_head(port);
          match_first_unseen(port, slot, captured);
        end
      end
      rx_count[port] = slot + 1;
      -> rx_activity;
    end
  endtask

  task automatic write_results;
    integer p, s, i, j, tx_index, fd_summary, fd_events, fd_latency, fd_flit, fd_v3;
    integer rank95, rank99, packet, injected_packets;
    longint tmp, max_lat, p95_lat, p99_lat, lat;
    real lat_sum, avg_lat_ns, elapsed_ns, throughput;
    reg pass_ok;
    begin
      flush_pending_heads();
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
      $fwrite(fd_latency, "port,pkt_seq,original_event_id,tail_flit,head_inject_req_ps,head_ingress_ack_ps,tail_egress_req_ps,tail_capture_ps,per_dest_latency_ns,tmax_component_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s] && expected_is_tail[rx_expected_index[p][s]]) begin
        i = rx_expected_index[p][s]; packet = expected_pkt_seq[i];
        $fwrite(fd_latency, "%0d,%0d,%0d,%h,%0d,%0d,%0d,%0d,%f,%f\n", p, packet, packet_event_id[packet], rx_flit[p][s], packet_head_req_ps[packet], packet_head_ack_ps[packet], rx_egress_ps[p][s], rx_time_ps[p][s], (rx_egress_ps[p][s]-packet_head_ack_ps[packet])/1000.0, (rx_egress_ps[p][s]-packet_head_req_ps[packet])/1000.0);
      end
      $fclose(fd_latency);
      fd_flit = $fopen(flit_latency_csv_file, "w");
      $fwrite(fd_flit, "port,pkt_seq,flit,offer_ps,egress_ps,lat_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1)
        for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s]) begin
          i = rx_expected_index[p][s];
          tx_index = expected_input_index[i];
          if (tx_index >= 0 && input_offer_ps[tx_index] >= 0)
            $fwrite(fd_flit, "%0d,%0d,%h,%0d,%0d,%f\n", p,
                    expected_pkt_seq[i], rx_flit[p][s], input_offer_ps[tx_index],
                    rx_egress_ps[p][s],
                    (rx_egress_ps[p][s]-input_offer_ps[tx_index])/1000.0);
        end
      $fclose(fd_flit);
      if (write_v3_metrics) begin
        fd_v3 = $fopen(v3_metrics_file, "w");
        $fwrite(fd_v3, "drainable,timeout,missing_flits,unexpected_flits,injected_flits,delivered_flits,inflight_end,warmup_original_events,measurement_original_events,errors,backlog_growth,pass_fail\n");
        $fwrite(fd_v3, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0s\n",
                pass_ok, timed_out, missing_flits, unexpected_flits, injected_flits, delivered_flits,
                missing_flits, warmup_events, measurement_events,
                missing_flits + unexpected_flits + timed_out,
                timed_out && (missing_flits > 0),
                pass_ok ? "PASS" : "FAIL");
        $fclose(fd_v3);
      end
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d injection_model=open_loop_case_queue elapsed_ns=%0.3f flits_per_ns=%0.6f", pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, elapsed_ns, elapsed_ns > 0.0 ? (delivered_flits / elapsed_ns) : 0.0);
      finish_requested = 1'b1;
      #1 $finish;
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_boundary
      always @(posedge clock) begin
        if (running && tb_out_valid[gp] === 1'b1 && tb_out_ready[gp] === 1'b1)
          last_egress_ps[gp] = now_ps();
      end
      always @(posedge clock) begin
        if (!reset && running && tb_out_valid[gp] === 1'b1 && tb_out_ready[gp] === 1'b1) begin
          if (^tb_out_data[gp*FLIT_W +: FLIT_W] === 1'bx)
            $display("TB_PROTOCOL_X port=%0d t=%0t valid=%b ready=%b data=%h",
                     gp, $time, tb_out_valid[gp], tb_out_ready[gp],
                     tb_out_data[gp*FLIT_W +: FLIT_W]);
          capture_rx(gp);
        end
      end
      initial arrive_port(gp);
      initial service_port(gp);
    end
  endgenerate

  initial begin
    clock_period_ns = 1.0;
    if ($value$plusargs("CLOCK_PERIOD_NS=%f", clock_period_ns)) ;
    if (clock_period_ns <= 0.0) begin
      $display("TB_FATAL CLOCK_PERIOD_NS must be positive");
      $finish;
    end
    clock = 1'b0;
    forever #(clock_period_ns / 2.0) clock = ~clock;
  end

  initial begin
    case_file = ""; csv_file = "sync_noc64_summary.csv"; event_csv_file = "sync_noc64_events.csv"; latency_csv_file = "sync_noc64_latency.csv"; flit_latency_csv_file = "sync_noc64_flit_latency.csv";
    v3_metrics_file = ""; write_v3_metrics = 1'b0;
    case_tick_ns = 20.0; rx_capture_ns = 0.0;
    timeout_scale = 1.0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("FLIT_LATENCY_CSV=%s", flit_latency_csv_file)) ;
    if ($value$plusargs("V3_METRICS_CSV=%s", v3_metrics_file)) write_v3_metrics = 1'b1;
    if ($value$plusargs("CLOCK_PERIOD_NS=%f", clock_period_ns)) ;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    dump_measurement_only = $test$plusargs("DUMP_MEASUREMENT_ONLY");
    if ($value$plusargs("DUMP_VCD=%s", dump_vcd)) begin
      $dumpfile(dump_vcd);
      $dumpvars(0, noc64_sync_boundary_core);
      if (dump_measurement_only) $dumpoff;
    end
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    if (clock_period_ns <= 0.0) begin $display("TB_FATAL CLOCK_PERIOD_NS must be positive"); $finish; end
    $display("TB_INFO NUM_CORES=%0d TOP_LANES=%0d NUM_PORTS=%0d CLOCK_PERIOD_NS=%0.3f CASE_TICK_NS=%0.3f RX_CAPTURE_NS=%0.3f INJECTION_MODEL=open_loop_case_queue", NUM_CORES, TOP_LANES, NUM_PORTS, clock_period_ns, case_tick_ns, rx_capture_ns);
    parse_case();
    reset = 1'b1; tb_in_valid = '0; tb_in_data = '0; tb_out_ready = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    repeat (reset_cycles) @(posedge clock);
    reset = 1'b0;
    tb_out_ready = {NUM_PORTS{1'b1}};
    repeat (16) @(posedge clock);
    case_epoch_ns = $realtime;
    measurement_start_ps = longint'((case_epoch_ns + measurement_start_cycle * case_tick_ns) * 1000.0 + 0.5);
    measurement_end_ps = longint'((case_epoch_ns + measurement_end_cycle * case_tick_ns) * 1000.0 + 0.5);
    $display("TB_METRICS_V2 window_ps=%0d:%0d warmup_events=%0d measurement_events=%0d",
             measurement_start_ps, measurement_end_ps, warmup_events, measurement_events);
    if (dump_measurement_only && (dump_vcd != "")) begin
      fork
        begin : dump_measurement_window_only
          #(measurement_start_cycle * case_tick_ns);
          $dumpon;
          #((measurement_end_cycle - measurement_start_cycle) * case_tick_ns);
          $dumpoff;
        end
      join_none
    end
    timeout_ns = timeout_cycles * case_tick_ns * timeout_scale;
    drain_ns = 1024.0 * case_tick_ns;
    running = 1'b1;
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
endmodule

module tb_noc64_sync_boundary;
`ifdef CMR_SYNC64_TOP8
  noc64_sync_boundary_core #(.NUM_CORES(64), .TOP_LANES(8)) core();
`elsif CMR_SYNC64_TOP2
  noc64_sync_boundary_core #(.NUM_CORES(64), .TOP_LANES(2)) core();
`else
  noc64_sync_boundary_core #(.NUM_CORES(64), .TOP_LANES(1)) core();
`endif
endmodule

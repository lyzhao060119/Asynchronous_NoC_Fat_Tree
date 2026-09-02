`timescale 1ns/1ps

// 64-core boundary harness extracted from tb_noc16_async_boundary.
// NUM_CORES=64; TOP_LANES is 8 (Fat 1-2-4-8), 2 (Fat 1-2-2-2), 1 (Thin), or 0 (8x8 mesh).
module noc64_async_boundary_core #(
  parameter integer NUM_CORES = 64,
  parameter integer TOP_LANES = 8,
  parameter integer STRUCTURAL_ENDPOINTS = 0,
  parameter integer ROBUST_DIRECT_HANDSHAKE = 1
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = NUM_CORES + TOP_LANES;
  localparam integer MAX_INPUT_FLITS = 131072;
  localparam integer MAX_EXPECT_FLITS = 262144;
  localparam integer MAX_RX_PER_PORT = 8192;
  localparam integer MAX_PKT_SEQ = 262144;
  localparam integer STR_CHARS = 256;
  localparam integer MASK_W = 128;

  initial begin
    if (!((NUM_CORES == 64) || ((NUM_CORES == 16) && (TOP_LANES == 0)))) begin
      $display("TB_FATAL NUM_CORES must be 64, or 16 with TOP_LANES=0, got cores=%0d top=%0d",
               NUM_CORES, TOP_LANES);
      $finish;
    end
    if ((TOP_LANES != 8) && (TOP_LANES != 2) && (TOP_LANES != 1) && (TOP_LANES != 0)) begin
      $display("TB_FATAL TOP_LANES must be 8, 2, 1, or 0, got %0d", TOP_LANES);
      $finish;
    end
  end

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
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file, v3_metrics_file;
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
  reg [MASK_W-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
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
  integer packet_head_req_ps [0:MAX_PKT_SEQ-1];
  integer packet_event_id [0:MAX_PKT_SEQ-1];
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer delivered_packets, latency_count;
  integer latency_ps [0:MAX_EXPECT_FLITS-1];
  integer warmup_events, measurement_events;
  reg write_v3_metrics;
  reg csv_dumped;
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
      initial begin
        $display("TB_FATAL STRUCTURAL_ENDPOINTS not supported on NoC64 yet");
        $finish;
      end
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
    end else if (TOP_LANES == 8) begin : g_behavioral_noc
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_noc64_port_adapter_top8 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end else if (TOP_LANES == 2) begin : g_behavioral_noc_1222
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_noc64_port_adapter_top2 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end else if (TOP_LANES == 1) begin : g_behavioral_noc_thin
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_noc64_port_adapter_top1 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end else if (NUM_CORES == 16) begin : g_behavioral_noc_mesh16
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_noc16_port_adapter_top0 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end else begin : g_behavioral_noc_mesh
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_noc64_port_adapter_top0 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
    end
  endgenerate

  task automatic parse_case;
    integer fd, n, p, cyc, pkt, idx, line_no;
    reg [STR_CHARS*8-1:0] line, tag, word;
    reg [MASK_W-1:0] mask_word;
    reg [FLIT_W-1:0] flit;
    begin
      input_count = 0; expected_count = 0;
      reset_cycles = 10; timeout_cycles = 5000000;
      warmup_events = 0; measurement_events = 0;
      case_name = ""; case_group = "";
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        expected_port_count[p] = 0; expected_cursor[p] = 0; rx_count[p] = 0;
        last_egress_ps[p] = -1; active_input[p] = -1;
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
      wait (running);
      for (i = 0; i < input_count; i = i + 1) if (input_port[i] == port) begin
        if (!inject_max_rate) begin
          due_ns = case_epoch_ns + input_cycle[i] * case_tick_ns;
          if ($realtime < due_ns) #(due_ns - $realtime);
          input_offer_ps[i] = $rtoi(due_ns * 1000.0 + 0.5);
        end
        wait ((noc_in_req[port] === noc_in_ack[port]) && (tb_in_req[port] === tb_in_ack[port]));
        if (inject_max_rate) input_offer_ps[i] = now_ps();
        tb_in_data[port*FLIT_W +: FLIT_W] = input_flit[i];
        #(tx_setup_ns);
        active_input[port] = i;
        old_noc_req = noc_in_req[port];
        tb_in_req[port] = ~tb_in_req[port];
        if (ROBUST_DIRECT_HANDSHAKE != 0) begin
          input_req_ps[i] = now_ps();
          wait (tb_in_req[port] === tb_in_ack[port]);
        end else begin
          wait (noc_in_req[port] !== old_noc_req);
          input_req_ps[i] = now_ps();
          wait (noc_in_req[port] === noc_in_ack[port]);
        end
        input_ack_ps[i] = now_ps();
        input_accepted[i] = 1'b1;
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PKT_SEQ) begin
          packet_head_req_ps[input_pkt_seq[i]] = input_req_ps[i];
          packet_head_ack_ps[input_pkt_seq[i]] = input_ack_ps[i];
        end
        active_input[port] = -1;
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
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  task automatic dump_csv_results;
    integer p, s, i, j, tmp, fd_summary, fd_events, fd_latency, fd_v3;
    integer lat_sum, max_lat, p95_lat, p99_lat, rank95, rank99, packet, lat, injected_packets;
    real avg_lat_ns, elapsed_ns, throughput;
    reg pass_ok;
    begin
      if (csv_dumped) disable dump_csv_results;
      csv_dumped = 1'b1;
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
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d inject_max_rate=%0d elapsed_ns=%0.3f flits_per_ns=%0.6f", pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, inject_max_rate, elapsed_ns, elapsed_ns > 0.0 ? (delivered_flits / elapsed_ns) : 0.0);
    end
  endtask

  task automatic write_results;
    begin
      dump_csv_results();
      finish_requested = 1'b1;
      #1 $finish;
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_boundary_monitors
      always @(noc_out_req[gp]) if (running && noc_out_req[gp] !== noc_out_ack[gp]) last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
      initial drive_port(gp);
    end
  endgenerate

  initial begin
    case_file = ""; csv_file = "async_noc64_summary.csv"; event_csv_file = "async_noc64_events.csv"; latency_csv_file = "async_noc64_latency.csv";
    v3_metrics_file = ""; write_v3_metrics = 1'b0;
    case_tick_ns = 20.0; tx_setup_ns = 0.05; rx_capture_ns = 0.05;
    ack_to_next_req_guard_ns = 0.20; timeout_scale = 1.0; inject_max_rate = 0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("V3_METRICS_CSV=%s", v3_metrics_file)) write_v3_metrics = 1'b1;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    if ($test$plusargs("INJECT_MAX_RATE")) inject_max_rate = 1;
    if ($value$plusargs("DUMP_VCD=%s", dump_vcd)) begin $dumpfile(dump_vcd); $dumpvars(0, noc64_async_boundary_core); end
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    $display("TB_INFO NUM_CORES=%0d TOP_LANES=%0d NUM_PORTS=%0d ACK_TO_NEXT_REQ_GUARD_NS=%0.3f INJECT_MAX_RATE=%0d CASE_TICK_NS=%0.3f RX_CAPTURE_NS=%0.3f", NUM_CORES, TOP_LANES, NUM_PORTS, ack_to_next_req_guard_ns, inject_max_rate, case_tick_ns, rx_capture_ns);
    parse_case();
    reset = 1'b1; tb_in_req = '0; tb_in_data = '0; tb_out_ack = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    csv_dumped = 1'b0;
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
    case_epoch_ns = $realtime;
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

`ifndef CMR_NOC64_MESH
`ifndef CMR_MESH16
module tb_noc64_async_boundary;
  noc64_async_boundary_core #(.NUM_CORES(64), .TOP_LANES(8), .ROBUST_DIRECT_HANDSHAKE(1)) core();
endmodule

module tb_noc64_async_boundary_1222;
  noc64_async_boundary_core #(.NUM_CORES(64), .TOP_LANES(2), .ROBUST_DIRECT_HANDSHAKE(1)) core();
endmodule

module tb_noc64_async_boundary_thin;
  noc64_async_boundary_core #(.NUM_CORES(64), .TOP_LANES(1), .ROBUST_DIRECT_HANDSHAKE(1)) core();
endmodule
`endif
`endif

`ifdef CMR_NOC64_MESH
module tb_noc64_async_boundary_mesh;
  noc64_async_boundary_core #(.NUM_CORES(64), .TOP_LANES(0), .ROBUST_DIRECT_HANDSHAKE(1)) core();
endmodule
`endif

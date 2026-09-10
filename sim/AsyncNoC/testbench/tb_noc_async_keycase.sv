`timescale 1ns/1ps

// Unified dest-list scoreboard for 256/1024-node core-only asynchronous networks.
// Hierarchical 64-node networks with exposed top ports keep the 64-node testbench.
// Maximum-delay mode must not be compiled with +notimingcheck.

module noc_async_keycase_core #(
  parameter integer NUM_CORES = 256,
  parameter integer ROBUST_DIRECT_HANDSHAKE = 1
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = NUM_CORES;
  localparam integer MAX_PACKETS = 16384;
  localparam integer MAX_INPUT_FLITS = MAX_PACKETS * 5;
  localparam integer MAX_RX_PER_PORT = (NUM_CORES <= 256) ? 1024 : 512;
  localparam integer STR_CHARS = 256;

  initial begin
    if ((NUM_CORES != 256) && (NUM_CORES != 1024)) begin
      $display("TB_FATAL NUM_CORES must be 256 or 1024, got %0d", NUM_CORES);
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

  assign noc_in_req = tb_in_req;
  assign noc_in_data = tb_in_data;
  assign tb_in_ack = noc_in_ack;
  assign tb_out_req = noc_out_req;
  assign tb_out_data = noc_out_data;
  assign noc_out_ack = tb_out_ack;

`ifdef CMR_NOC_FM
  `ifdef CMR_NOC_1024
    async_noc_port_adapter_fm_1024 noc (
      .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
      .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
    );
  `else
    async_noc_port_adapter_fm_256 noc (
      .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
      .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
    );
  `endif
`else
  `ifdef CMR_NOC_1024
    async_noc_port_adapter_prop_1024 noc (
      .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
      .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
    );
  `else
    async_noc_port_adapter_prop_256 noc (
      .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
      .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
    );
  `endif
`endif

  reg [NUM_PORTS-1:0] input_done;
  reg running, timed_out, finish_requested, write_v3_metrics, x_failed;
  integer reset_cycles, timeout_cycles, inject_max_rate;
  integer warmup_events, measurement_events;
  real case_tick_ns, tx_setup_ns, rx_capture_ns, ack_to_next_req_guard_ns, timeout_scale;
  real case_epoch_ns, timeout_ns, drain_ns, stall_timeout_ns, hard_timeout_ns;
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file, v3_metrics_file;
  reg [STR_CHARS*8-1:0] case_name, case_group;

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

  integer expected_pkt_seq [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg expected_is_tail [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg [FLIT_W-1:0] expected_flit [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg expected_seen [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer expected_port_count [0:NUM_PORTS-1];
  integer expected_matched [0:NUM_PORTS-1];

  integer rx_count [0:NUM_PORTS-1];
  longint rx_time_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint rx_egress_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer rx_pkt_seq [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg rx_is_tail [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg [FLIT_W-1:0] rx_flit [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg rx_match [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint last_egress_ps [0:NUM_PORTS-1];
  longint packet_head_ack_ps [0:MAX_PACKETS-1];
  longint packet_head_req_ps [0:MAX_PACKETS-1];
  integer packet_event_id [0:MAX_PACKETS-1];
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer delivered_packets, latency_count;
  longint latency_ps [0:MAX_INPUT_FLITS-1];
  reg csv_dumped;
  event rx_activity;

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

  task automatic parse_case;
    integer fd, n, p, cyc, pkt, idx, ndest, dest, is_tail, line_no;
    reg [STR_CHARS*8-1:0] line, tag, word;
    reg [FLIT_W-1:0] flit;
    begin
      input_count = 0; expected_count = 0;
      reset_cycles = 10; timeout_cycles = 5000000;
      warmup_events = 0; measurement_events = 0;
      case_name = ""; case_group = "";
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        expected_port_count[p] = 0; expected_matched[p] = 0; rx_count[p] = 0;
        last_egress_ps[p] = -1; active_input[p] = -1;
      end
      for (idx = 0; idx < MAX_PACKETS; idx = idx + 1) begin
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
              if (n != 3 || pkt < 0 || pkt >= MAX_PACKETS) begin
                $display("TB_FATAL malformed event_map at line %0d", line_no); $finish;
              end
              packet_event_id[pkt] = cyc;
            end else if (tag == "packet") begin
              n = $sscanf(line, "%s %d %d %d", tag, pkt, p, ndest);
              if (n < 4) begin $display("TB_FATAL malformed packet at line %0d", line_no); $finish; end
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
            end else if (tag == "expect_port") begin
              n = $sscanf(line, "%s %d %d %d %h", tag, p, pkt, is_tail, flit);
              if (n != 5 || p < 0 || p >= NUM_PORTS || expected_port_count[p] >= MAX_RX_PER_PORT) begin
                $display("TB_FATAL malformed expect_port at line %0d", line_no); $finish;
              end
              idx = expected_port_count[p];
              expected_pkt_seq[p][idx] = pkt;
              expected_is_tail[p][idx] = is_tail[0];
              expected_flit[p][idx] = flit;
              expected_seen[p][idx] = 1'b0;
              expected_port_count[p] = idx + 1;
              expected_count = expected_count + 1;
            end
          end
        end
      end
      $fclose(fd);
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
          input_offer_ps[i] = longint'(due_ns * 1000.0 + 0.5);
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
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PACKETS) begin
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
    integer slot, scan;
    reg found;
    reg [FLIT_W-1:0] captured;
    begin
      forever begin
        wait (running && (tb_out_req[port] !== tb_out_ack[port]));
        #(rx_capture_ns);
        captured = tb_out_data[port*FLIT_W +: FLIT_W];
        if (^captured === 1'bx) begin
          $display("TB_X_FAIL data port=%0d t=%0t", port, $time);
          x_failed = 1'b1;
        end
        slot = rx_count[port];
        if (slot >= MAX_RX_PER_PORT) begin $display("TB_FATAL RX overflow port=%0d", port); $finish; end
        rx_time_ps[port][slot] = now_ps();
        rx_egress_ps[port][slot] = last_egress_ps[port];
        rx_flit[port][slot] = captured;
        found = 1'b0;
        for (scan = 0; scan < expected_port_count[port]; scan = scan + 1)
          if (!found && !expected_seen[port][scan] && captured === expected_flit[port][scan]) begin
            found = 1'b1;
            expected_seen[port][scan] = 1'b1;
            rx_match[port][slot] = 1'b1;
            rx_pkt_seq[port][slot] = expected_pkt_seq[port][scan];
            rx_is_tail[port][slot] = expected_is_tail[port][scan];
            expected_matched[port] = expected_matched[port] + 1;
          end
        if (!found) begin
          rx_match[port][slot] = 1'b0;
          rx_pkt_seq[port][slot] = -1;
          rx_is_tail[port][slot] = 1'b0;
          unexpected_flits = unexpected_flits + 1;
        end
        rx_count[port] = slot + 1;
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  task automatic write_results;
    integer p, s, i, j, fd_summary, fd_events, fd_latency, fd_v3;
    integer packet, injected_packets, unmatched, rank95, rank99;
    longint tmp, max_lat, p95_lat, p99_lat, lat;
    real lat_sum, avg_lat_ns, elapsed_ns, throughput;
    reg pass_ok, drainable, backlog_growth;
    begin
      if (csv_dumped) disable write_results;
      csv_dumped = 1'b1;
      injected_flits = 0; injected_packets = 0; missing_flits = 0; delivered_flits = total_rx();
      delivered_packets = 0; latency_count = 0; lat_sum = 0; max_lat = 0;
      for (i = 0; i < input_count; i = i + 1) if (input_accepted[i]) begin
        injected_flits = injected_flits + 1;
        if (input_flit[i][27]) injected_packets = injected_packets + 1;
      end
      unmatched = 0;
      for (p = 0; p < NUM_PORTS; p = p + 1)
        unmatched = unmatched + (expected_port_count[p] - expected_matched[p]);
      missing_flits = unmatched;
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        if (rx_match[p][s] && rx_is_tail[p][s]) begin
          packet = rx_pkt_seq[p][s];
          if (packet >= 0 && packet < MAX_PACKETS && packet_head_ack_ps[packet] >= 0 && rx_egress_ps[p][s] >= 0) begin
            lat = rx_egress_ps[p][s] - packet_head_ack_ps[packet];
            if (latency_count < MAX_INPUT_FLITS) begin
              latency_ps[latency_count] = lat;
              latency_count = latency_count + 1;
            end
            lat_sum = lat_sum + lat;
            if (lat > max_lat) max_lat = lat;
            delivered_packets = delivered_packets + 1;
          end
        end
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
      drainable = !timed_out && !x_failed && (injected_flits == input_count) && (missing_flits == 0) && (unexpected_flits == 0);
      backlog_growth = timed_out && (missing_flits > 0);
      pass_ok = drainable;
      for (p = 0; p < NUM_PORTS; p = p + 1)
        if (expected_port_count[p] != expected_matched[p])
          $display("TB_MISSING_PORT port=%0d matched=%0d expected=%0d rx=%0d",
                   p, expected_matched[p], expected_port_count[p], rx_count[p]);

      fd_summary = $fopen(csv_file, "w");
      $fwrite(fd_summary, "group,case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,rx_overflow,measure_cycles,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      $fwrite(fd_summary, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0,%0d,%f,%f,%f,%f,%f,%0s\n",
              case_group, case_name, injected_packets, delivered_packets, injected_flits, delivered_flits, missing_flits, unexpected_flits,
              timed_out, $rtoi(elapsed_ns / case_tick_ns), throughput, avg_lat_ns, max_lat / 1000.0, p95_lat / 1000.0, p99_lat / 1000.0,
              pass_ok ? "PASS" : "FAIL");
      $fclose(fd_summary);

      fd_events = $fopen(event_csv_file, "w");
      $fwrite(fd_events, "kind,port,pkt_seq,flit,offer_ps,req_ps,ack_ps,egress_req_ps,capture_ps,matched\n");
      for (i = 0; i < input_count; i = i + 1)
        $fwrite(fd_events, "TX,%0d,%0d,%h,%0d,%0d,%0d,-1,-1,%0d\n", input_port[i], input_pkt_seq[i], input_flit[i], input_offer_ps[i], input_req_ps[i], input_ack_ps[i], input_accepted[i]);
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        $fwrite(fd_events, "RX,%0d,%0d,%h,-1,-1,-1,%0d,%0d,%0d\n", p, rx_pkt_seq[p][s], rx_flit[p][s], rx_egress_ps[p][s], rx_time_ps[p][s], rx_match[p][s]);
      $fclose(fd_events);

      fd_latency = $fopen(latency_csv_file, "w");
      $fwrite(fd_latency, "port,pkt_seq,original_event_id,tail_flit,head_inject_req_ps,head_ingress_ack_ps,tail_egress_req_ps,tail_capture_ps,per_dest_latency_ns,tmax_component_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        if (rx_match[p][s] && rx_is_tail[p][s]) begin
          packet = rx_pkt_seq[p][s];
          $fwrite(fd_latency, "%0d,%0d,%0d,%h,%0d,%0d,%0d,%0d,%f,%f\n", p, packet, packet_event_id[packet], rx_flit[p][s],
                  packet_head_req_ps[packet], packet_head_ack_ps[packet], rx_egress_ps[p][s], rx_time_ps[p][s],
                  (rx_egress_ps[p][s]-packet_head_ack_ps[packet])/1000.0,
                  (rx_egress_ps[p][s]-packet_head_req_ps[packet])/1000.0);
        end
      $fclose(fd_latency);

      if (write_v3_metrics) begin
        fd_v3 = $fopen(v3_metrics_file, "w");
        $fwrite(fd_v3, "drainable,timeout,missing_flits,unexpected_flits,injected_flits,delivered_flits,inflight_end,warmup_original_events,measurement_original_events,errors,backlog_growth,pass_fail\n");
        $fwrite(fd_v3, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0s\n",
                drainable, timed_out, missing_flits, unexpected_flits, injected_flits, delivered_flits,
                missing_flits, warmup_events, measurement_events,
                missing_flits + unexpected_flits + timed_out + x_failed, backlog_growth, pass_ok ? "PASS" : "FAIL");
        $fclose(fd_v3);
      end
      if (x_failed) $display("TB_X_FAIL handshake_or_data");
`ifdef CMR_NOC_FM
`ifdef CMR_NOC_256
      dump_mesh256_path_counts();
`endif
`endif
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d drainable=%0d",
               pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, drainable);
      finish_requested = 1'b1;
      #1 $finish;
    end
  endtask

`ifdef CMR_NOC_FM
`ifdef CMR_NOC_256
  // Path probe for FM256 77->189 (column 13 north chain).
  integer hop_pe77_tx, hop_pe189_rx;
  integer hop_13_4_li, hop_13_4_no, hop_13_4_eo, hop_13_4_wo;
  integer hop_13_5_si, hop_13_5_no, hop_13_6_si, hop_13_6_no;
  integer hop_13_7_si, hop_13_7_no, hop_13_8_si, hop_13_8_no;
  integer hop_13_9_si, hop_13_9_no, hop_13_10_si, hop_13_10_no;
  integer hop_13_11_si, hop_13_11_lo;

  `define TB_MESH256_HOP(req, ack, flit, nm, cnt) \
    always @(req) begin \
      if (running && $test$plusargs("MESH256_PATH_PROBE")) begin \
        cnt = cnt + 1; \
        $display("TB_HOP t=%0t link=%s n=%0d req=%b ack=%b ht=%0d flit=%h", \
                 $time, nm, cnt, req, ack, flit[27], flit); \
      end \
    end

  always @(tb_in_req[77]) begin
    if (running && $test$plusargs("MESH256_PATH_PROBE") && tb_in_req[77]) begin
      hop_pe77_tx = hop_pe77_tx + 1;
      $display("TB_HOP t=%0t link=PE77.tx n=%0d req=%b ack=%b flit=%h",
               $time, hop_pe77_tx, tb_in_req[77], tb_in_ack[77], tb_in_data[77*FLIT_W +: FLIT_W]);
    end
  end
  always @(noc_out_req[189]) begin
    if (running && $test$plusargs("MESH256_PATH_PROBE") && noc_out_req[189]) begin
      hop_pe189_rx = hop_pe189_rx + 1;
      $display("TB_HOP t=%0t link=PE189.rx n=%0d req=%b ack=%b flit=%h",
               $time, hop_pe189_rx, noc_out_req[189], noc_out_ack[189], noc_out_data[189*FLIT_W +: FLIT_W]);
    end
  end

  `TB_MESH256_HOP(noc.dut.meshR_13_4.io_inputs_parent_0_HS_Req,
                  noc.dut.meshR_13_4.io_inputs_parent_0_HS_Ack,
                  noc.dut.meshR_13_4.io_inputs_parent_0_Data_flit,
                  "meshR_13_4.local_in", hop_13_4_li)
  `TB_MESH256_HOP(noc.dut.meshR_13_4.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_4.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_4.io_outputs_child_3_0_Data_flit,
                  "meshR_13_4.north_out", hop_13_4_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_4.io_outputs_child_0_0_HS_Req,
                  noc.dut.meshR_13_4.io_outputs_child_0_0_HS_Ack,
                  noc.dut.meshR_13_4.io_outputs_child_0_0_Data_flit,
                  "meshR_13_4.west_out", hop_13_4_wo)
  `TB_MESH256_HOP(noc.dut.meshR_13_4.io_outputs_child_2_0_HS_Req,
                  noc.dut.meshR_13_4.io_outputs_child_2_0_HS_Ack,
                  noc.dut.meshR_13_4.io_outputs_child_2_0_Data_flit,
                  "meshR_13_4.east_out", hop_13_4_eo)

  `TB_MESH256_HOP(noc.dut.meshR_13_5.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_5.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_5.io_inputs_child_1_0_Data_flit,
                  "meshR_13_5.south_in", hop_13_5_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_5.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_5.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_5.io_outputs_child_3_0_Data_flit,
                  "meshR_13_5.north_out", hop_13_5_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_6.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_6.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_6.io_inputs_child_1_0_Data_flit,
                  "meshR_13_6.south_in", hop_13_6_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_6.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_6.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_6.io_outputs_child_3_0_Data_flit,
                  "meshR_13_6.north_out", hop_13_6_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_7.io_inputs_child_1_0_Data_flit,
                  "meshR_13_7.south_in", hop_13_7_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_7.io_outputs_child_3_0_Data_flit,
                  "meshR_13_7.north_out", hop_13_7_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_8.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_8.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_8.io_inputs_child_1_0_Data_flit,
                  "meshR_13_8.south_in", hop_13_8_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_8.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_8.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_8.io_outputs_child_3_0_Data_flit,
                  "meshR_13_8.north_out", hop_13_8_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_9.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_9.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_9.io_inputs_child_1_0_Data_flit,
                  "meshR_13_9.south_in", hop_13_9_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_9.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_9.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_9.io_outputs_child_3_0_Data_flit,
                  "meshR_13_9.north_out", hop_13_9_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_10.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_10.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_10.io_inputs_child_1_0_Data_flit,
                  "meshR_13_10.south_in", hop_13_10_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_10.io_outputs_child_3_0_HS_Req,
                  noc.dut.meshR_13_10.io_outputs_child_3_0_HS_Ack,
                  noc.dut.meshR_13_10.io_outputs_child_3_0_Data_flit,
                  "meshR_13_10.north_out", hop_13_10_no)
  `TB_MESH256_HOP(noc.dut.meshR_13_11.io_inputs_child_1_0_HS_Req,
                  noc.dut.meshR_13_11.io_inputs_child_1_0_HS_Ack,
                  noc.dut.meshR_13_11.io_inputs_child_1_0_Data_flit,
                  "meshR_13_11.south_in", hop_13_11_si)
  `TB_MESH256_HOP(noc.dut.meshR_13_11.io_outputs_parent_0_HS_Req,
                  noc.dut.meshR_13_11.io_outputs_parent_0_HS_Ack,
                  noc.dut.meshR_13_11.io_outputs_parent_0_Data_flit,
                  "meshR_13_11.local_out", hop_13_11_lo)

  // Focused meshR_13_7 port watch (200-350 us window) for bodytag debug runs.
  `define TB_R137_FOCUS(linkname, req, ack, flit) \
    always @(req or ack) begin \
      if (running && $test$plusargs("MESH256_R137_FOCUS") \
          && ($time >= 200000) && ($time <= 350000)) begin \
        $display("TB_R137 t=%0t link=%s req=%b ack=%b ht=%b tl=%b flit=%h", \
                 $time, linkname, req, ack, flit[27], flit[26], flit); \
      end \
    end

  `TB_R137_FOCUS("r137.local_in", noc.dut.meshR_13_7.io_inputs_parent_0_HS_Req,
                 noc.dut.meshR_13_7.io_inputs_parent_0_HS_Ack,
                 noc.dut.meshR_13_7.io_inputs_parent_0_Data_flit)
  `TB_R137_FOCUS("r137.west_in", noc.dut.meshR_13_7.io_inputs_child_0_0_HS_Req,
                 noc.dut.meshR_13_7.io_inputs_child_0_0_HS_Ack,
                 noc.dut.meshR_13_7.io_inputs_child_0_0_Data_flit)
  `TB_R137_FOCUS("r137.south_in", noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Req,
                 noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Ack,
                 noc.dut.meshR_13_7.io_inputs_child_1_0_Data_flit)
  `TB_R137_FOCUS("r137.east_in", noc.dut.meshR_13_7.io_inputs_child_2_0_HS_Req,
                 noc.dut.meshR_13_7.io_inputs_child_2_0_HS_Ack,
                 noc.dut.meshR_13_7.io_inputs_child_2_0_Data_flit)
  `TB_R137_FOCUS("r137.local_out", noc.dut.meshR_13_7.io_outputs_parent_0_HS_Req,
                 noc.dut.meshR_13_7.io_outputs_parent_0_HS_Ack,
                 noc.dut.meshR_13_7.io_outputs_parent_0_Data_flit)
  `TB_R137_FOCUS("r137.west_out", noc.dut.meshR_13_7.io_outputs_child_0_0_HS_Req,
                 noc.dut.meshR_13_7.io_outputs_child_0_0_HS_Ack,
                 noc.dut.meshR_13_7.io_outputs_child_0_0_Data_flit)
  `TB_R137_FOCUS("r137.south_out", noc.dut.meshR_13_7.io_outputs_child_1_0_HS_Req,
                 noc.dut.meshR_13_7.io_outputs_child_1_0_HS_Ack,
                 noc.dut.meshR_13_7.io_outputs_child_1_0_Data_flit)
  `TB_R137_FOCUS("r137.east_out", noc.dut.meshR_13_7.io_outputs_child_2_0_HS_Req,
                 noc.dut.meshR_13_7.io_outputs_child_2_0_HS_Ack,
                 noc.dut.meshR_13_7.io_outputs_child_2_0_Data_flit)
  `TB_R137_FOCUS("r137.north_out", noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Req,
                 noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Ack,
                 noc.dut.meshR_13_7.io_outputs_child_3_0_Data_flit)
  `TB_R137_FOCUS("r136.north_in", noc.dut.meshR_13_6.io_outputs_child_3_0_HS_Req,
                 noc.dut.meshR_13_6.io_outputs_child_3_0_HS_Ack,
                 noc.dut.meshR_13_6.io_outputs_child_3_0_Data_flit)

  // meshR_13_7 internal probe: south IPM (InputPortModules_1) -> north OPM (OutputPortModules_3).
  // South branch 2 = North; south is OPM source index 1 on OutputPortModules_3.
  `define R137_INT noc.dut.meshR_13_7
  `define R137_SIPM `R137_INT.InputPortModules_1
  `define R137_NOPM `R137_INT.OutputPortModules_3
  `define R137_SBUF `R137_SIPM.Buffer
  `define R137_SRCU `R137_SIPM.RouteComputationUnit

  task automatic r137_internal_dump(input string tag);
    begin
      if (running && $test$plusargs("MESH256_R137_INTERNAL")
          && ($time >= 200000) && ($time <= 350000)) begin
        $display(
          "TB_R137_INT t=%0t tag=%s si_req=%b si_ack=%b flit=%h mat=%b%b%b%b rsel=%b%b%b%b ppe=%b%b%b%b ro=%b%b%b%b ai=%b%b%b%b wp=%b%b%b%b%b full=%b%b%b%b%b ceN=%b%b%b%b%b ppeN=%b grantN=%b nopm_req=%b nopm_ack=%b nopm_out=%h link_no_req=%b link_no_ack=%b",
          $time, tag,
          `R137_SIPM.io_Reqin, `R137_SIPM.io_Ackout, `R137_SIPM.io_Datain_flit,
          `R137_SRCU.io_Mat_3, `R137_SRCU.io_Mat_2, `R137_SRCU.io_Mat_1, `R137_SRCU.io_Mat_0,
          `R137_SRCU.io_RouteSel_3, `R137_SRCU.io_RouteSel_2, `R137_SRCU.io_RouteSel_1, `R137_SRCU.io_RouteSel_0,
          `R137_SIPM.io_PathEnabled_3, `R137_SIPM.io_PathEnabled_2, `R137_SIPM.io_PathEnabled_1, `R137_SIPM.io_PathEnabled_0,
          `R137_SIPM.io_Reqout_3, `R137_SIPM.io_Reqout_2, `R137_SIPM.io_Reqout_1, `R137_SIPM.io_Reqout_0,
          `R137_SIPM.io_Ackin_3, `R137_SIPM.io_Ackin_2, `R137_SIPM.io_Ackin_1, `R137_SIPM.io_Ackin_0,
          `R137_SBUF.WriteInterface_io_WritePointer_4, `R137_SBUF.WriteInterface_io_WritePointer_3,
          `R137_SBUF.WriteInterface_io_WritePointer_2, `R137_SBUF.WriteInterface_io_WritePointer_1,
          `R137_SBUF.WriteInterface_io_WritePointer_0,
          `R137_SBUF.WriteInterface_io_CellFull_4, `R137_SBUF.WriteInterface_io_CellFull_3,
          `R137_SBUF.WriteInterface_io_CellFull_2, `R137_SBUF.WriteInterface_io_CellFull_1,
          `R137_SBUF.WriteInterface_io_CellFull_0,
          `R137_SBUF.ReadInterface_2_io_CellEmpty_4, `R137_SBUF.ReadInterface_2_io_CellEmpty_3,
          `R137_SBUF.ReadInterface_2_io_CellEmpty_2, `R137_SBUF.ReadInterface_2_io_CellEmpty_1,
          `R137_SBUF.ReadInterface_2_io_CellEmpty_0,
          `R137_NOPM.io_PktPathEnable_1, `R137_NOPM.io_Grant_1,
          `R137_NOPM.io_Reqout, `R137_NOPM.io_Ackin, `R137_NOPM.io_Dataout_flit,
          noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Req,
          noc.dut.meshR_13_7.io_outputs_child_3_0_HS_Ack);
      end
    end
  endtask

  // Sample when south link toggles (known-good boundary trigger).
  always @(noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Req or
           noc.dut.meshR_13_7.io_inputs_child_1_0_HS_Ack or
           noc.dut.meshR_13_7.io_inputs_child_1_0_Data_flit) begin
    if (running && $test$plusargs("MESH256_R137_INTERNAL"))
      r137_internal_dump("link");
  end

  initial begin
    if ($test$plusargs("MESH256_R137_INTERNAL")) begin
      wait(running);
      #200000;
      while ($time <= 350000) begin
        r137_internal_dump("poll");
        #500;
      end
    end
  end

  always @(`R137_SIPM.io_Reqin or `R137_SIPM.io_Ackout or
           `R137_SRCU.io_Mat_2 or `R137_SRCU.io_RouteSel_2 or
           `R137_SIPM.io_PathEnabled_2 or `R137_SIPM.io_Reqout_2 or `R137_SIPM.io_Ackin_2 or
           `R137_NOPM.io_Grant_1 or `R137_NOPM.io_PktPathEnable_1 or
           `R137_NOPM.io_Reqout or `R137_NOPM.io_Ackin or
           `R137_SBUF.WriteInterface_io_CellFull_0 or
           `R137_SBUF.WriteInterface_io_CellFull_1 or
           `R137_SBUF.WriteInterface_io_CellFull_2 or
           `R137_SBUF.WriteInterface_io_CellFull_3 or
           `R137_SBUF.WriteInterface_io_CellFull_4) begin
    r137_internal_dump("event");
  end

  task automatic dump_mesh256_path_counts;
    begin
      if ($test$plusargs("MESH256_PATH_PROBE"))
        $display("TB_HOP_COUNTS pe77=%0d pe189=%0d r134_li=%0d no=%0d wo=%0d eo=%0d r135_si=%0d no=%0d r136_si=%0d no=%0d r137_si=%0d no=%0d r138_si=%0d no=%0d r139_si=%0d no=%0d r1310_si=%0d no=%0d r1311_si=%0d lo=%0d",
                 hop_pe77_tx, hop_pe189_rx,
                 hop_13_4_li, hop_13_4_no, hop_13_4_wo, hop_13_4_eo,
                 hop_13_5_si, hop_13_5_no, hop_13_6_si, hop_13_6_no,
                 hop_13_7_si, hop_13_7_no, hop_13_8_si, hop_13_8_no,
                 hop_13_9_si, hop_13_9_no, hop_13_10_si, hop_13_10_no,
                 hop_13_11_si, hop_13_11_lo);
    end
  endtask
`endif
`endif

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_boundary_monitors
      always @(noc_out_req[gp]) if (running && noc_out_req[gp] !== noc_out_ack[gp]) last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
      initial drive_port(gp);
    end
  endgenerate

  always @* begin
    if (running && ((^tb_in_req === 1'bx) || (^tb_in_ack === 1'bx) || (^tb_out_req === 1'bx) || (^tb_out_ack === 1'bx))) begin
      $display("TB_X_FAIL handshake t=%0t", $time);
      x_failed = 1'b1;
    end
  end

  initial begin
    case_file = ""; csv_file = "async_noc_summary.csv"; event_csv_file = "async_noc_events.csv";
    latency_csv_file = "async_noc_latency.csv"; v3_metrics_file = "";
    case_tick_ns = 20.0; tx_setup_ns = 0.05; rx_capture_ns = 0.05;
    ack_to_next_req_guard_ns = 0.20; timeout_scale = 1.0; inject_max_rate = 0; write_v3_metrics = 0;
    stall_timeout_ns = 0.0; hard_timeout_ns = 0.0;
    x_failed = 1'b0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("V3_METRICS_CSV=%s", v3_metrics_file)) write_v3_metrics = 1;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    if ($value$plusargs("STALL_TIMEOUT_NS=%f", stall_timeout_ns)) ;
    if ($value$plusargs("HARD_TIMEOUT_NS=%f", hard_timeout_ns)) ;
    if ($test$plusargs("INJECT_MAX_RATE")) inject_max_rate = 1;
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    $display("TB_INFO NUM_CORES=%0d KEYCASE async-only ACK_TO_NEXT_REQ_GUARD_NS=%0.3f INJECT_MAX_RATE=%0d CASE_TICK_NS=%0.3f RX_CAPTURE_NS=%0.3f", NUM_CORES, ack_to_next_req_guard_ns, inject_max_rate, case_tick_ns, rx_capture_ns);
    parse_case();
    reset = 1'b1; tb_in_req = '0; tb_in_data = '0; tb_out_ack = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    csv_dumped = 1'b0; delivered_packets = 0; latency_count = 0;
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
    case_epoch_ns = $realtime;
    timeout_ns = timeout_cycles * case_tick_ns * timeout_scale;
    if (stall_timeout_ns > timeout_ns) timeout_ns = stall_timeout_ns;
    if (hard_timeout_ns > timeout_ns) timeout_ns = hard_timeout_ns;
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

module tb_noc_async_keycase;
`ifdef CMR_NOC_1024
  localparam integer NUM_CORES = 1024;
`else
  localparam integer NUM_CORES = 256;
`endif
  noc_async_keycase_core #(.NUM_CORES(NUM_CORES), .ROBUST_DIRECT_HANDSHAKE(1)) core();
endmodule

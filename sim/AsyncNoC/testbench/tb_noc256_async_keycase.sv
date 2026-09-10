`timescale 1ns/1ps

// Lightweight 256-node async key-case TB.  Dest-list scoreboard, no 256-bit
// expect masks and no 1024-style per-port 8k arrays.  Async only.
module noc256_async_keycase_core #(
  parameter integer NUM_CORES = 256,
  parameter integer ROBUST_DIRECT_HANDSHAKE = 1
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = NUM_CORES;
  localparam integer MAX_INPUT_FLITS = 81920;
  localparam integer MAX_PACKETS = 16384;
  localparam integer MAX_RX_PER_PORT = 1024;
  localparam integer STR_CHARS = 256;

  initial begin
    if (NUM_CORES != 256) begin
      $display("TB_FATAL NUM_CORES must be 256, got %0d", NUM_CORES);
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

`ifdef CMR_NOC256_FM
  async_noc256_port_adapter_fm noc (
    .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
    .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
  );
`else
  async_noc256_port_adapter_prop noc (
    .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
    .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
  );
`endif

  reg [NUM_PORTS-1:0] input_done;
  reg running, timed_out, finish_requested, write_v3_metrics;
  integer reset_cycles, timeout_cycles, inject_max_rate;
  integer warmup_events, measurement_events;
  real case_tick_ns, tx_setup_ns, rx_capture_ns, ack_to_next_req_guard_ns, timeout_scale;
  real case_epoch_ns, timeout_ns, drain_ns;
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file, v3_metrics_file;
  reg [2047:0] dump_vcd;
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
  longint packet_offer_ps [0:MAX_PACKETS-1];
  integer packet_event_id [0:MAX_PACKETS-1];
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer latency_count;
  longint latency_ps [0:MAX_INPUT_FLITS-1];
  integer port_first_input [0:NUM_PORTS-1];
  integer port_input_count [0:NUM_PORTS-1];
  integer port_arrived_count [0:NUM_PORTS-1];
  integer port_served_count [0:NUM_PORTS-1];
  integer source_queue_flits [0:NUM_PORTS-1];
  integer measurement_start_cycle, measurement_end_cycle;
  integer measurement_backlog_snapshot;
  longint measurement_start_ps, measurement_end_ps;
  event rx_activity, source_arrival;

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
      reset_cycles = 10; timeout_cycles = 2000000;
      warmup_events = 0; measurement_events = 0;
      case_name = ""; case_group = "";
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        expected_port_count[p] = 0; expected_matched[p] = 0; rx_count[p] = 0;
        last_egress_ps[p] = -1; active_input[p] = -1;
        port_first_input[p] = -1; port_input_count[p] = 0;
        port_arrived_count[p] = 0; port_served_count[p] = 0; source_queue_flits[p] = 0;
      end
      for (idx = 0; idx < MAX_PACKETS; idx = idx + 1) begin
        packet_head_ack_ps[idx] = -1;
        packet_head_req_ps[idx] = -1;
        packet_offer_ps[idx] = -1;
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
              if (port_first_input[p] < 0) port_first_input[p] = input_count;
              else if (input_count != port_first_input[p] + port_input_count[p]) begin
                $display("TB_FATAL inputs must be grouped by port; p=%0d line=%0d", p, line_no); $finish;
              end
              port_input_count[p] = port_input_count[p] + 1;
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
      measurement_start_cycle = -1; measurement_end_cycle = -1;
      for (idx = 0; idx < input_count; idx = idx + 1)
        if (input_flit[idx][27] && (packet_event_id[input_pkt_seq[idx]] < 0 || packet_event_id[input_pkt_seq[idx]] >= warmup_events)) begin
          if (measurement_start_cycle < 0 || input_cycle[idx] < measurement_start_cycle)
            measurement_start_cycle = input_cycle[idx];
          if (measurement_end_cycle < input_cycle[idx] + 1)
            measurement_end_cycle = input_cycle[idx] + 1;
        end
      if (measurement_start_cycle < 0 || measurement_end_cycle <= measurement_start_cycle) begin
        $display("TB_FATAL missing measurement packet window"); $finish;
      end
    end
  endtask

  task automatic arrive_port(input integer port);
    integer i;
    real due_ns;
    begin
      wait (running);
      for (i = port_first_input[port];
           i < port_first_input[port] + port_input_count[port]; i = i + 1) begin
        due_ns = case_epoch_ns + input_cycle[i] * case_tick_ns;
        if (!inject_max_rate && $realtime < due_ns) #(due_ns - $realtime);
        input_offer_ps[i] = inject_max_rate ? now_ps() : longint'(due_ns * 1000.0 + 0.5);
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PACKETS)
          packet_offer_ps[input_pkt_seq[i]] = input_offer_ps[i];
        port_arrived_count[port] = port_arrived_count[port] + 1;
        source_queue_flits[port] = source_queue_flits[port] + 1;
        -> source_arrival;
      end
    end
  endtask

  task automatic service_port(input integer port);
    integer i;
    reg old_noc_req;
    begin
      wait (running);
      while (port_served_count[port] < port_input_count[port]) begin
        wait (source_queue_flits[port] > 0);
        i = port_first_input[port] + port_served_count[port];
        wait ((noc_in_req[port] === noc_in_ack[port]) && (tb_in_req[port] === tb_in_ack[port]));
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
        source_queue_flits[port] = source_queue_flits[port] - 1;
        port_served_count[port] = port_served_count[port] + 1;
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
    integer packet, injected_packets, unmatched, rank50, rank95, rank99;
    integer measurement_offered_flits, measurement_delivered_flits, measurement_delivered_copies, measurement_backlog_flits;
    longint tmp, lat, p50_lat, p95_lat, p99_lat, max_lat;
    real lat_sum, offer_tail_mean_ns, window_ns, offered_throughput, delivered_throughput;
    reg pass_ok, drainable, backlog_growth;
    begin
      injected_flits = 0; injected_packets = 0; missing_flits = 0; delivered_flits = total_rx();
      latency_count = 0; lat_sum = 0.0; max_lat = 0;
      measurement_offered_flits = 0; measurement_delivered_flits = 0; measurement_delivered_copies = 0;
      measurement_backlog_flits = measurement_backlog_snapshot;
      for (i = 0; i < input_count; i = i + 1) if (input_accepted[i]) begin
        injected_flits = injected_flits + 1;
        if (input_flit[i][27]) injected_packets = injected_packets + 1;
      end
      for (i = 0; i < input_count; i = i + 1)
        if ((packet_event_id[input_pkt_seq[i]] < 0 || packet_event_id[input_pkt_seq[i]] >= warmup_events) &&
            input_offer_ps[i] >= measurement_start_ps && input_offer_ps[i] < measurement_end_ps) begin
          measurement_offered_flits = measurement_offered_flits + 1;
        end
      unmatched = 0;
      for (p = 0; p < NUM_PORTS; p = p + 1)
        unmatched = unmatched + (expected_port_count[p] - expected_matched[p]);
      missing_flits = unmatched;
      drainable = !timed_out && (injected_flits == input_count) && (missing_flits == 0) && (unexpected_flits == 0);
      backlog_growth = timed_out && (missing_flits > 0);
      pass_ok = drainable;
      for (p = 0; p < NUM_PORTS; p = p + 1)
        for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s]) begin
          packet = rx_pkt_seq[p][s];
          if ((packet_event_id[packet] < 0 || packet_event_id[packet] >= warmup_events) &&
              rx_egress_ps[p][s] >= measurement_start_ps && rx_egress_ps[p][s] < measurement_end_ps) begin
            measurement_delivered_flits = measurement_delivered_flits + 1;
            if (rx_is_tail[p][s]) measurement_delivered_copies = measurement_delivered_copies + 1;
          end
          if (rx_is_tail[p][s] && (packet_event_id[packet] < 0 || packet_event_id[packet] >= warmup_events) &&
              packet_offer_ps[packet] >= measurement_start_ps && packet_offer_ps[packet] < measurement_end_ps &&
              rx_egress_ps[p][s] >= measurement_start_ps && rx_egress_ps[p][s] < measurement_end_ps) begin
            lat = rx_egress_ps[p][s] - packet_offer_ps[packet];
            latency_ps[latency_count] = lat; latency_count = latency_count + 1;
            lat_sum = lat_sum + lat; if (lat > max_lat) max_lat = lat;
          end
        end
      for (i = 0; i < latency_count; i = i + 1) for (j = i + 1; j < latency_count; j = j + 1)
        if (latency_ps[j] < latency_ps[i]) begin tmp = latency_ps[i]; latency_ps[i] = latency_ps[j]; latency_ps[j] = tmp; end
      if (latency_count > 0) begin
        rank50 = (50 * latency_count + 99) / 100; if (rank50 > latency_count) rank50 = latency_count;
        rank95 = (95 * latency_count + 99) / 100; if (rank95 > latency_count) rank95 = latency_count;
        rank99 = (99 * latency_count + 99) / 100; if (rank99 > latency_count) rank99 = latency_count;
        p50_lat = latency_ps[rank50-1]; p95_lat = latency_ps[rank95-1]; p99_lat = latency_ps[rank99-1];
      end else begin p50_lat = 0; p95_lat = 0; p99_lat = 0; end
      offer_tail_mean_ns = latency_count ? (lat_sum / latency_count / 1000.0) : 0.0;
      window_ns = (measurement_end_ps - measurement_start_ps) / 1000.0;
      offered_throughput = window_ns > 0.0 ? measurement_offered_flits / window_ns : 0.0;
      delivered_throughput = window_ns > 0.0 ? measurement_delivered_flits / window_ns : 0.0;
      // V2 saturation evidence is work outstanding at the measurement boundary,
      // rather than the old timeout-derived proxy.
      backlog_growth = measurement_backlog_flits > 0;
      for (p = 0; p < NUM_PORTS; p = p + 1)
        if (expected_port_count[p] != expected_matched[p])
          $display("TB_MISSING_PORT port=%0d matched=%0d expected=%0d rx=%0d",
                   p, expected_matched[p], expected_port_count[p], rx_count[p]);

      fd_summary = $fopen(csv_file, "w");
      $fwrite(fd_summary, "group,case_name,injected_packets,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,warmup_original_events,measurement_original_events,measurement_start_ps,measurement_end_ps,measurement_offered_flits,measurement_delivered_flits,measurement_delivered_copies,measurement_backlog_flits,offered_throughput_flit_ns,delivered_throughput_flit_ns,offer_to_tail_mean_ns,offer_to_tail_p50_ns,offer_to_tail_p95_ns,offer_to_tail_p99_ns,offer_to_tail_max_ns,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,drainable,backlog_growth,pass_fail\n");
      $fwrite(fd_summary, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%0d,%0d,%0s\n",
              case_group, case_name, injected_packets, delivered_flits, missing_flits, unexpected_flits,
              timed_out, warmup_events, measurement_events, measurement_start_ps, measurement_end_ps,
              measurement_offered_flits, measurement_delivered_flits, measurement_delivered_copies, measurement_backlog_flits,
              offered_throughput, delivered_throughput, offer_tail_mean_ns, p50_lat/1000.0, p95_lat/1000.0, p99_lat/1000.0, max_lat/1000.0,
              delivered_throughput, offer_tail_mean_ns, max_lat/1000.0, p95_lat/1000.0, p99_lat/1000.0,
              drainable, backlog_growth, pass_ok ? "PASS" : "FAIL");
      $fclose(fd_summary);

      fd_events = $fopen(event_csv_file, "w");
      $fwrite(fd_events, "kind,port,pkt_seq,flit,offer_ps,req_ps,ack_ps,egress_req_ps,capture_ps,matched\n");
      for (i = 0; i < input_count; i = i + 1)
        $fwrite(fd_events, "TX,%0d,%0d,%h,%0d,%0d,%0d,-1,-1,%0d\n", input_port[i], input_pkt_seq[i], input_flit[i], input_offer_ps[i], input_req_ps[i], input_ack_ps[i], input_accepted[i]);
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        $fwrite(fd_events, "RX,%0d,%0d,%h,-1,-1,-1,%0d,%0d,%0d\n", p, rx_pkt_seq[p][s], rx_flit[p][s], rx_egress_ps[p][s], rx_time_ps[p][s], rx_match[p][s]);
      $fclose(fd_events);

      fd_latency = $fopen(latency_csv_file, "w");
      $fwrite(fd_latency, "port,pkt_seq,original_event_id,tail_flit,head_offer_ps,head_inject_req_ps,head_ingress_ack_ps,tail_egress_req_ps,tail_capture_ps,offer_to_tail_ns,ingress_service_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        if (rx_match[p][s] && rx_is_tail[p][s]) begin
          packet = rx_pkt_seq[p][s];
        $fwrite(fd_latency, "%0d,%0d,%0d,%h,%0d,%0d,%0d,%0d,%0d,%f,%f\n", p, packet, packet_event_id[packet], rx_flit[p][s],
                  packet_offer_ps[packet], packet_head_req_ps[packet], packet_head_ack_ps[packet], rx_egress_ps[p][s], rx_time_ps[p][s],
                  (rx_egress_ps[p][s]-packet_offer_ps[packet])/1000.0,
                  (rx_egress_ps[p][s]-packet_head_ack_ps[packet])/1000.0);
        end
      $fclose(fd_latency);

      if (write_v3_metrics) begin
        fd_v3 = $fopen(v3_metrics_file, "w");
        $fwrite(fd_v3, "drainable,timeout,missing_flits,unexpected_flits,injected_flits,delivered_flits,inflight_end,warmup_original_events,measurement_original_events,errors,backlog_growth,pass_fail\n");
        $fwrite(fd_v3, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0s\n",
                drainable, timed_out, missing_flits, unexpected_flits, injected_flits, delivered_flits,
                missing_flits, warmup_events, measurement_events,
                missing_flits + unexpected_flits + timed_out, backlog_growth, pass_ok ? "PASS" : "FAIL");
        $fclose(fd_v3);
      end
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d metrics_v2 offered=%0.6f delivered_rate=%0.6f backlog=%0d offer_tail_mean_ns=%0.3f",
               pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out,
               offered_throughput, delivered_throughput, measurement_backlog_flits, offer_tail_mean_ns);
      finish_requested = 1'b1;
      #1 $finish;
    end
  endtask

  genvar gp;
  generate
    for (gp = 0; gp < NUM_PORTS; gp = gp + 1) begin : g_boundary_monitors
      always @(noc_out_req[gp]) if (running && noc_out_req[gp] !== noc_out_ack[gp]) last_egress_ps[gp] = now_ps();
      initial receive_port(gp);
      initial arrive_port(gp);
      initial service_port(gp);
    end
  endgenerate

  initial begin
    case_file = ""; csv_file = "async_noc256_summary.csv"; event_csv_file = "async_noc256_events.csv";
    latency_csv_file = "async_noc256_latency.csv"; v3_metrics_file = ""; dump_vcd = "";
    case_tick_ns = 20.0; tx_setup_ns = 0.05; rx_capture_ns = 0.05;
    ack_to_next_req_guard_ns = 0.20; timeout_scale = 1.0; inject_max_rate = 0; write_v3_metrics = 0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("V3_METRICS_CSV=%s", v3_metrics_file)) write_v3_metrics = 1;
    if ($value$plusargs("DUMP_VCD=%s", dump_vcd)) begin $dumpfile(dump_vcd); $dumpvars(0, noc); end
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    if ($test$plusargs("INJECT_MAX_RATE")) inject_max_rate = 1;
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    $display("TB_INFO NUM_CORES=%0d KEYCASE async-only", NUM_CORES);
    parse_case();
    reset = 1'b1; tb_in_req = '0; tb_in_data = '0; tb_out_ack = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    measurement_backlog_snapshot = 0;
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
    case_epoch_ns = $realtime;
    measurement_start_ps = longint'((case_epoch_ns + measurement_start_cycle * case_tick_ns) * 1000.0 + 0.5);
    measurement_end_ps = longint'((case_epoch_ns + measurement_end_cycle * case_tick_ns) * 1000.0 + 0.5);
    $display("TB_METRICS_V2 window_ps=%0d:%0d warmup_events=%0d measurement_events=%0d",
             measurement_start_ps, measurement_end_ps, warmup_events, measurement_events);
    timeout_ns = timeout_cycles * case_tick_ns * timeout_scale;
    drain_ns = 1024.0 * case_tick_ns;
    running = 1'b1;
    // Do not fold an in-DUT handshake into source backlog: snapshot the
    // lossless source queues exactly at the measurement-window boundary.
    fork
      begin : snapshot_measurement_source_backlog
        integer snapshot_port;
        #(measurement_end_cycle * case_tick_ns);
        measurement_backlog_snapshot = 0;
        for (snapshot_port = 0; snapshot_port < NUM_PORTS; snapshot_port = snapshot_port + 1)
          measurement_backlog_snapshot = measurement_backlog_snapshot + source_queue_flits[snapshot_port];
      end
    join_none
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

module tb_noc256_async_keycase;
  noc256_async_keycase_core #(.NUM_CORES(256), .ROBUST_DIRECT_HANDSHAKE(1)) core();
`ifndef CMR_NOC256_FM
  // L3(0,0) parent ingress is q64_0_0 top_input (from TopMesh local).
  // Child dir 1 / L2(1,0) parent is the unique KEY-256 descent.
  always @(core.noc.dut.q64_0_0_io_top_input_0_HS_Req or
           core.noc.dut.q64_0_0_io_top_input_1_HS_Req or
           core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_HS_Req or
           core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_HS_Req or
           core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_0_HS_Req or
           core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_1_HS_Req) begin
    if (core.running && $test$plusargs("L3_PROBE"))
      $display("TB_L3_00 t=%0t par0=%b/%h par1=%b/%h ch1_0=%b/%h ch1_1=%b/%h l2_p0=%b l2_p1=%b",
               $time,
               core.noc.dut.q64_0_0_io_top_input_0_HS_Req,
               core.noc.dut.q64_0_0_io_top_input_0_Data_flit,
               core.noc.dut.q64_0_0_io_top_input_1_HS_Req,
               core.noc.dut.q64_0_0_io_top_input_1_Data_flit,
               core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_HS_Req,
               core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_Data_flit,
               core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_HS_Req,
               core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_Data_flit,
               core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_0_HS_Req,
               core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_1_HS_Req);
  end

  // Hop-chain on pkt13/pkt15 shared path.  Print on Req toggle only.
`define TB_HOP_MON(req, ack, flit, nm) \
  always @(req) begin \
    if (core.running && $test$plusargs("HOP_PROBE")) \
      $display("TB_HOP t=%0t link=%s req=%b ack=%b ht=%0d%0d flit=%h", \
               $time, nm, req, ack, flit[27], flit[26], flit); \
  end

  `TB_HOP_MON(core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_0_HS_Req,
              core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_0_HS_Ack,
              core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_0_Data_flit,
              "q64_1_1.L2_2_2.parent0_out")
  `TB_HOP_MON(core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_1_HS_Req,
              core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_1_HS_Ack,
              core.noc.dut.q64_1_1.routersL2_0_0_io_outputs_parent_1_Data_flit,
              "q64_1_1.L2_2_2.parent1_out")
  `TB_HOP_MON(core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_0_HS_Req,
              core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_0_HS_Ack,
              core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_0_Data_flit,
              "q64_1_1.L3.child3_0_in")
  `TB_HOP_MON(core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_1_HS_Req,
              core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_1_HS_Ack,
              core.noc.dut.q64_1_1.routerL3_io_inputs_child_3_1_Data_flit,
              "q64_1_1.L3.child3_1_in")
  `TB_HOP_MON(core.noc.dut.q64_1_1.routerL3_io_outputs_parent_0_HS_Req,
              core.noc.dut.q64_1_1.routerL3_io_outputs_parent_0_HS_Ack,
              core.noc.dut.q64_1_1.routerL3_io_outputs_parent_0_Data_flit,
              "q64_1_1.L3.parent0_out")
  `TB_HOP_MON(core.noc.dut.q64_1_1.routerL3_io_outputs_parent_1_HS_Req,
              core.noc.dut.q64_1_1.routerL3_io_outputs_parent_1_HS_Ack,
              core.noc.dut.q64_1_1.routerL3_io_outputs_parent_1_Data_flit,
              "q64_1_1.L3.parent1_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_0_HS_Req,
              core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_0_Data_flit,
              "topMesh_1_1.local0_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_1_HS_Req,
              core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_1_1_io_inputs_parent_1_Data_flit,
              "topMesh_1_1.local1_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_0_HS_Req,
              core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_0_Data_flit,
              "topMesh_1_1.west0_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_1_HS_Req,
              core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_1_1_io_outputs_child_0_1_Data_flit,
              "topMesh_1_1.west1_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_0_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_0_Data_flit,
              "topMesh_0_1.east0_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_1_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_inputs_child_2_1_Data_flit,
              "topMesh_0_1.east1_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_0_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_0_Data_flit,
              "topMesh_0_1.south0_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_1_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_child_1_1_Data_flit,
              "topMesh_0_1.south1_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_0_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_0_Data_flit,
              "topMesh_0_1.local0_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_1_HS_Req,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_1_io_outputs_parent_1_Data_flit,
              "topMesh_0_1.local1_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_0_HS_Req,
              core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_0_Data_flit,
              "topMesh_0_0.north0_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_1_HS_Req,
              core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_0_io_inputs_child_3_1_Data_flit,
              "topMesh_0_0.north1_in")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_0_HS_Req,
              core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_0_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_0_Data_flit,
              "topMesh_0_0.local0_out")
  `TB_HOP_MON(core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_1_HS_Req,
              core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_1_HS_Ack,
              core.noc.dut.topMesh.topMesh_0_0_io_outputs_parent_1_Data_flit,
              "topMesh_0_0.local1_out")
  `TB_HOP_MON(core.noc.dut.q64_0_0_io_top_input_0_HS_Req,
              core.noc.dut.q64_0_0_io_top_input_0_HS_Ack,
              core.noc.dut.q64_0_0_io_top_input_0_Data_flit,
              "q64_0_0.L3.parent0_in")
  `TB_HOP_MON(core.noc.dut.q64_0_0_io_top_input_1_HS_Req,
              core.noc.dut.q64_0_0_io_top_input_1_HS_Ack,
              core.noc.dut.q64_0_0_io_top_input_1_Data_flit,
              "q64_0_0.L3.parent1_in")
  `TB_HOP_MON(core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_HS_Req,
              core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_HS_Ack,
              core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_0_Data_flit,
              "q64_0_0.L3.child1_0_out")
  `TB_HOP_MON(core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_HS_Req,
              core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_HS_Ack,
              core.noc.dut.q64_0_0.routerL3_io_outputs_child_1_1_Data_flit,
              "q64_0_0.L3.child1_1_out")
  `TB_HOP_MON(core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_0_HS_Req,
              core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_0_HS_Ack,
              core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_0_Data_flit,
              "q64_0_0.L2_1_0.parent0_in")
  `TB_HOP_MON(core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_1_HS_Req,
              core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_1_HS_Ack,
              core.noc.dut.q64_0_0.routersL2_1_0_io_inputs_parent_1_Data_flit,
              "q64_0_0.L2_1_0.parent1_in")
  `TB_HOP_MON(core.noc.dut.q64_0_1_io_top_input_0_HS_Req,
              core.noc.dut.q64_0_1_io_top_input_0_HS_Ack,
              core.noc.dut.q64_0_1_io_top_input_0_Data_flit,
              "q64_0_1.L3.parent0_in")
  `TB_HOP_MON(core.noc.dut.q64_0_1_io_top_input_1_HS_Req,
              core.noc.dut.q64_0_1_io_top_input_1_HS_Ack,
              core.noc.dut.q64_0_1_io_top_input_1_Data_flit,
              "q64_0_1.L3.parent1_in")
`undef TB_HOP_MON

  initial begin : scoped_vcd
    reg [8*256-1:0] dump_vcd;
    dump_vcd = "";
    // Keep narrow debugging traces opt-in.  The power flow uses DUMP_VCD in
    // the core above, whose scope is the complete DUT hierarchy.
    if ($value$plusargs("DUMP_SCOPED_VCD=%s", dump_vcd)) begin
      $dumpfile(dump_vcd);
      $dumpvars(1, core.noc.dut.q64_1_1.routerL3);
      $dumpvars(1, core.noc.dut.q64_1_1.routersL2_0_0);
      $dumpvars(1, core.noc.dut.topMesh.topMesh_1_1);
      $dumpvars(1, core.noc.dut.topMesh.topMesh_0_1);
      $dumpvars(1, core.noc.dut.q64_0_0.routerL3);
      $display("TB_INFO DUMP_SCOPED_VCD %0s", dump_vcd);
    end
  end
`endif
endmodule

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
  // F8 multicast expands 11,000 source packets into 440,000 matched egress
  // flits, so the old 262k scoreboard capacity is insufficient.
  localparam integer MAX_EXPECT_FLITS = 524288;
  // Per-destination expect/RX queue. F8 mean is ~6.9k flits/port, but UR
  // hotspots exceeded 8192 (TB_FATAL p=27/p=35). Worst case one dest is in
  // every packet: 11,000 * 5 = 55,000 flits.
  localparam integer MAX_RX_PER_PORT = 65536;
  localparam integer MAX_PKT_SEQ = 262144;
  localparam integer STR_CHARS = 256;
  localparam integer MASK_W = 128;
  // Body/tail identity payload from date_v3.materialize_case.make_flit:
  // [25:12] pkt_seq, [11:9] flit_index, [8:6] 3'b101.  Head keeps AABB and is
  // not unique, so it must not be scored with first-unseen bit matching.
  localparam [2:0] IDENTITY_MAGIC = 3'b101;

  initial begin
    if (!((NUM_CORES == 64) || ((NUM_CORES == 16) && (TOP_LANES == 0)))) begin
      $display("TB_FATAL NUM_CORES must be 64, or 16 with TOP_LANES=0, got cores=%0d top=%0d",
               NUM_CORES, TOP_LANES);
      $finish;
    end
    if ((TOP_LANES != 16) && (TOP_LANES != 8) && (TOP_LANES != 2) && (TOP_LANES != 1) && (TOP_LANES != 0)) begin
      $display("TB_FATAL TOP_LANES must be 16, 8, 2, 1, or 0, got %0d", TOP_LANES);
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
  reg [STR_CHARS*8-1:0] case_file, csv_file, event_csv_file, latency_csv_file, flit_latency_csv_file, v3_metrics_file, missing_csv_file;
  reg [STR_CHARS*8-1:0] case_name, case_group;
  reg [2047:0] dump_vcd;
  reg dump_measurement_only;

  integer input_count, expected_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  integer input_case_line [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];
  longint input_offer_ps [0:MAX_INPUT_FLITS-1];
  longint input_req_ps [0:MAX_INPUT_FLITS-1];
  longint input_ack_ps [0:MAX_INPUT_FLITS-1];
  reg input_accepted [0:MAX_INPUT_FLITS-1];
  integer active_input [0:NUM_PORTS-1];

  integer expected_port_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer expected_port_count [0:NUM_PORTS-1];
  integer expected_cursor [0:NUM_PORTS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  integer expected_case_line [0:MAX_EXPECT_FLITS-1];
  integer expected_input_index [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [MASK_W-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];

  integer rx_count [0:NUM_PORTS-1];
  longint rx_time_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint rx_egress_ps [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  integer rx_expected_index [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg [FLIT_W-1:0] rx_flit [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  reg rx_match [0:NUM_PORTS-1][0:MAX_RX_PER_PORT-1];
  longint last_egress_ps [0:NUM_PORTS-1];
  longint packet_head_ack_ps [0:MAX_PKT_SEQ-1];
  longint packet_head_req_ps [0:MAX_PKT_SEQ-1];
  longint packet_offer_ps [0:MAX_PKT_SEQ-1];
  integer packet_event_id [0:MAX_PKT_SEQ-1];
  integer packet_source_port [0:MAX_PKT_SEQ-1];
  integer packet_head_input_index [0:MAX_PKT_SEQ-1];
  integer packet_head_cycle [0:MAX_PKT_SEQ-1];
  integer port_first_input [0:NUM_PORTS-1];
  integer port_input_count [0:NUM_PORTS-1];
  integer port_arrived_count [0:NUM_PORTS-1];
  integer port_served_count [0:NUM_PORTS-1];
  integer source_queue_flits [0:NUM_PORTS-1];
  integer measurement_start_cycle, measurement_end_cycle;
  integer measurement_backlog_snapshot;
  longint measurement_start_ps, measurement_end_ps;
  integer unexpected_flits, missing_flits, injected_flits, delivered_flits;
  integer delivered_packets, latency_count;
  localparam integer LAT_HIST_BINS = 20000;
  localparam integer LAT_HIST_PS = 100;
  integer flit_lat_hist [0:LAT_HIST_BINS-1];
  integer packet_lat_hist [0:LAT_HIST_BINS-1];
  integer warmup_events, measurement_events;
  reg write_v3_metrics;
  reg csv_dumped;
  event rx_activity, source_arrival;
  // Wormhole: one in-flight packet per dest.  Hold the unmatched Head until
  // the following identity body/tail names pkt_seq, then bind that Head.
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
    end else if (TOP_LANES == 16) begin : g_behavioral_noc_prop_temp
      assign noc_in_req = tb_in_req;
      assign noc_in_data = tb_in_data;
      assign tb_in_ack = noc_in_ack;
      assign tb_out_req = noc_out_req;
      assign tb_out_data = noc_out_data;
      assign noc_out_ack = tb_out_ack;
      async_prop_temp64_port_adapter_top16 noc (
        .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
        .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
      );
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
      // Controlled FM64 reverse-path probe for pkt270: Core37=(5,4) to
      // Core18=(2,2).  Dump complete selected router scopes so IPM/OPM
      // handshake state is available without producing a whole-mesh VCD.
      initial if ($test$plusargs("DUMP_MESH_PATH")) begin
        #0;
        $dumpvars(0, noc.dut.meshR_5_4, noc.dut.meshR_4_4,
                     noc.dut.meshR_3_4, noc.dut.meshR_2_4,
                     noc.dut.meshR_2_3, noc.dut.meshR_2_2);
      end
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
        packet_offer_ps[idx] = -1;
        packet_event_id[idx] = -1;
        packet_source_port[idx] = -1;
        packet_head_input_index[idx] = -1;
        packet_head_cycle[idx] = -1;
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
              input_case_line[input_count] = line_no;
              if (flit[27]) begin
                packet_source_port[pkt] = p;
                packet_head_input_index[pkt] = input_count;
                packet_head_cycle[pkt] = cyc;
              end
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
              expected_case_line[expected_count] = line_no;
              expected_input_index[expected_count] = -1;
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
        if (input_flit[idx][27] && (packet_event_id[input_pkt_seq[idx]] < 0 || packet_event_id[input_pkt_seq[idx]] >= warmup_events)) begin
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
          if ((input_pkt_seq[n] == expected_pkt_seq[idx]) && (input_flit[n] === expected_flit[idx])) begin
            expected_input_index[idx] = n;
            n = input_count;
          end
        if ((expected_input_index[idx] < 0) && expected_flit[idx][27])
          expected_input_index[idx] = packet_head_input_index[expected_pkt_seq[idx]];
        if (expected_input_index[idx] < 0) begin
          $display("TB_FATAL unmatched expect pkt=%0d line=%0d flit=%h",
                   expected_pkt_seq[idx], expected_case_line[idx], expected_flit[idx]);
          $finish;
        end
      end
    end
  endtask

  // Arrival is open-loop: a due flit is queued even while the DUT applies
  // backpressure.  Service below is the only process allowed to consume it.
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
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PKT_SEQ)
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
        if (input_flit[i][27] && input_pkt_seq[i] >= 0 && input_pkt_seq[i] < MAX_PKT_SEQ) begin
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
    integer slot, pkt;
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
        rx_expected_index[port][slot] = -1;
        rx_match[port][slot] = 1'b0;
        // Concurrent sources share an output, so arrival order is not the case
        // order.  Body/tail carry a unique pkt_seq.  Head is AABB-only and is
        // held until the next identity flit on this port names the packet.
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
        tb_out_ack[port] = tb_out_req[port];
        -> rx_activity;
      end
    end
  endtask

  // Fail-fast diagnostics must come from the scoreboard, not a VCD alias.
  // Emit every expected egress copy which has not been consumed.  The rows
  // are ordered by source injection cycle, packet sequence, destination and
  // original case line, so row zero is the packet to trace first.
  task automatic dump_missing_expected;
    integer fd, i, p, rank, missing_count, best, best_dest, dest;
    integer last_cycle, last_pkt, last_dest, last_line;
    integer best_cycle, best_pkt, best_line, packet_slot;
    integer src, event_id, head_idx;
    reg [FLIT_W-1:0] packet_flit0, packet_flit1, packet_flit2, packet_flit3, packet_flit4;
    begin
      flush_pending_heads();
      missing_count = 0;
      for (i = 0; i < expected_count; i = i + 1)
        if (!expected_seen[i]) missing_count = missing_count + 1;
      fd = $fopen(missing_csv_file, "w");
      if (fd == 0) begin
        $display("TB_MISSING_EXPORT_FAIL cannot open %0s", missing_csv_file);
        disable dump_missing_expected;
      end
      $fwrite(fd, "rank,injection_cycle,pkt_seq,event_id,src_core,dst_core,expected_case_line,head,tail,flit,head_offer_ps,head_req_ps,head_ack_ps,pkt_flit0,pkt_flit1,pkt_flit2,pkt_flit3,pkt_flit4\n");
      last_cycle = -1; last_pkt = -1; last_dest = -1; last_line = -1;
      for (rank = 0; rank < missing_count; rank = rank + 1) begin
        best = -1; best_dest = -1;
        for (i = 0; i < expected_count; i = i + 1) if (!expected_seen[i]) begin
          dest = -1;
          for (p = 0; p < NUM_PORTS; p = p + 1)
            if (expected_mask[i][p]) dest = p;
          if (dest < 0) begin
            $display("TB_MISSING_EXPORT_FAIL missing destination expected_idx=%0d", i);
          end else if ((packet_head_cycle[expected_pkt_seq[i]] > last_cycle) ||
                       ((packet_head_cycle[expected_pkt_seq[i]] == last_cycle) && (expected_pkt_seq[i] > last_pkt)) ||
                       ((packet_head_cycle[expected_pkt_seq[i]] == last_cycle) && (expected_pkt_seq[i] == last_pkt) && (dest > last_dest)) ||
                       ((packet_head_cycle[expected_pkt_seq[i]] == last_cycle) && (expected_pkt_seq[i] == last_pkt) && (dest == last_dest) && (expected_case_line[i] > last_line))) begin
            if ((best < 0) || (packet_head_cycle[expected_pkt_seq[i]] < best_cycle) ||
                ((packet_head_cycle[expected_pkt_seq[i]] == best_cycle) && (expected_pkt_seq[i] < best_pkt)) ||
                ((packet_head_cycle[expected_pkt_seq[i]] == best_cycle) && (expected_pkt_seq[i] == best_pkt) && (dest < best_dest)) ||
                ((packet_head_cycle[expected_pkt_seq[i]] == best_cycle) && (expected_pkt_seq[i] == best_pkt) && (dest == best_dest) && (expected_case_line[i] < best_line))) begin
              best = i; best_dest = dest; best_cycle = packet_head_cycle[expected_pkt_seq[i]];
              best_pkt = expected_pkt_seq[i]; best_line = expected_case_line[i];
            end
          end
        end
        if (best < 0) begin
          $display("TB_MISSING_EXPORT_FAIL sort exhausted rank=%0d count=%0d", rank, missing_count);
          disable dump_missing_expected;
        end
        packet_flit0 = 'x; packet_flit1 = 'x; packet_flit2 = 'x; packet_flit3 = 'x; packet_flit4 = 'x;
        packet_slot = 0;
        for (i = 0; i < input_count; i = i + 1) if (input_pkt_seq[i] == best_pkt) begin
          case (packet_slot)
            0: packet_flit0 = input_flit[i]; 1: packet_flit1 = input_flit[i];
            2: packet_flit2 = input_flit[i]; 3: packet_flit3 = input_flit[i];
            4: packet_flit4 = input_flit[i];
          endcase
          packet_slot = packet_slot + 1;
        end
        src = packet_source_port[best_pkt]; event_id = packet_event_id[best_pkt]; head_idx = packet_head_input_index[best_pkt];
        $fwrite(fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%h,%0d,%0d,%0d,%h,%h,%h,%h,%h\n",
                rank, best_cycle, best_pkt, event_id, src, best_dest, best_line,
                expected_flit[best][27], expected_is_tail[best], expected_flit[best],
                head_idx >= 0 ? input_offer_ps[head_idx] : -1,
                head_idx >= 0 ? input_req_ps[head_idx] : -1,
                head_idx >= 0 ? input_ack_ps[head_idx] : -1,
                packet_flit0, packet_flit1, packet_flit2, packet_flit3, packet_flit4);
        last_cycle = best_cycle; last_pkt = best_pkt; last_dest = best_dest; last_line = best_line;
      end
      $fclose(fd);
      $display("TB_MISSING_EXPECTED count=%0d file=%0s", missing_count, missing_csv_file);
    end
  endtask

  task automatic dump_csv_results;
    integer p, s, i, fd_summary, fd_events, fd_latency, fd_flit, fd_v3;
    integer packet, injected_packets, tx_index, hist_bin, seen, rank50, rank95, rank99;
    integer flit_p50_set, flit_p95_set, flit_p99_set, packet_p50_set, packet_p95_set, packet_p99_set;
    integer measurement_offered_flits, measurement_delivered_flits, measurement_delivered_copies, measurement_backlog_flits;
    integer flit_latency_count, packet_latency_count;
    longint lat, flit_max_lat, packet_max_lat, flit_p50, flit_p95, flit_p99, packet_p50, packet_p95, packet_p99;
    real flit_lat_sum, packet_lat_sum, flit_avg_ns, packet_avg_ns, window_ns, window_s;
    real offered_mflit_port_s, delivered_mflit_port_s;
    reg pass_ok;
    begin
      if (csv_dumped) disable dump_csv_results;
      flush_pending_heads();
      csv_dumped = 1'b1;
      injected_flits = 0; injected_packets = 0; missing_flits = 0; delivered_flits = total_rx();
      measurement_offered_flits = 0; measurement_delivered_flits = 0; measurement_delivered_copies = 0;
      measurement_backlog_flits = measurement_backlog_snapshot;
      delivered_packets = 0; latency_count = 0;
      flit_latency_count = 0; packet_latency_count = 0;
      flit_lat_sum = 0; packet_lat_sum = 0; flit_max_lat = 0; packet_max_lat = 0;
      for (i = 0; i < LAT_HIST_BINS; i = i + 1) begin
        flit_lat_hist[i] = 0;
        packet_lat_hist[i] = 0;
      end
      for (i = 0; i < input_count; i = i + 1) if (input_accepted[i]) begin
        injected_flits = injected_flits + 1;
        if (input_flit[i][27]) injected_packets = injected_packets + 1;
      end
      for (i = 0; i < input_count; i = i + 1)
        if ((packet_event_id[input_pkt_seq[i]] < 0 || packet_event_id[input_pkt_seq[i]] >= warmup_events) &&
            input_offer_ps[i] >= measurement_start_ps && input_offer_ps[i] < measurement_end_ps) begin
          measurement_offered_flits = measurement_offered_flits + 1;
        end
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s]) begin
          i = rx_expected_index[p][s];
          tx_index = expected_input_index[i];
          if ((packet_event_id[expected_pkt_seq[i]] < 0 || packet_event_id[expected_pkt_seq[i]] >= warmup_events) &&
              rx_egress_ps[p][s] >= measurement_start_ps && rx_egress_ps[p][s] < measurement_end_ps) begin
            measurement_delivered_flits = measurement_delivered_flits + 1;
            if (expected_is_tail[i]) measurement_delivered_copies = measurement_delivered_copies + 1;
          end
          if (tx_index >= 0 && input_offer_ps[tx_index] >= 0 &&
              (packet_event_id[expected_pkt_seq[i]] < 0 || packet_event_id[expected_pkt_seq[i]] >= warmup_events) &&
              input_offer_ps[tx_index] >= measurement_start_ps && input_offer_ps[tx_index] < measurement_end_ps &&
              rx_egress_ps[p][s] >= measurement_start_ps && rx_egress_ps[p][s] < measurement_end_ps) begin
            lat = rx_egress_ps[p][s] - input_offer_ps[tx_index];
            flit_lat_sum = flit_lat_sum + lat;
            if (lat > flit_max_lat) flit_max_lat = lat;
            hist_bin = (lat <= 0) ? 0 : (lat / LAT_HIST_PS);
            if (hist_bin < 0) hist_bin = 0;
            if (hist_bin >= LAT_HIST_BINS) hist_bin = LAT_HIST_BINS - 1;
            flit_lat_hist[hist_bin] = flit_lat_hist[hist_bin] + 1;
            flit_latency_count = flit_latency_count + 1;
          end
          if (expected_is_tail[i]) begin
            packet = expected_pkt_seq[i];
            if (packet >= 0 && packet < MAX_PKT_SEQ && packet_offer_ps[packet] >= 0 &&
                (packet_event_id[packet] < 0 || packet_event_id[packet] >= warmup_events) &&
                packet_offer_ps[packet] >= measurement_start_ps && packet_offer_ps[packet] < measurement_end_ps &&
                rx_egress_ps[p][s] >= measurement_start_ps && rx_egress_ps[p][s] < measurement_end_ps) begin
              lat = rx_egress_ps[p][s] - packet_offer_ps[packet];
              packet_lat_sum = packet_lat_sum + lat;
              if (lat > packet_max_lat) packet_max_lat = lat;
              hist_bin = (lat <= 0) ? 0 : (lat / LAT_HIST_PS);
              if (hist_bin < 0) hist_bin = 0;
              if (hist_bin >= LAT_HIST_BINS) hist_bin = LAT_HIST_BINS - 1;
              packet_lat_hist[hist_bin] = packet_lat_hist[hist_bin] + 1;
              packet_latency_count = packet_latency_count + 1;
              delivered_packets = delivered_packets + 1;
            end
          end
        end
      end
      for (i = 0; i < expected_count; i = i + 1) if (!expected_seen[i]) missing_flits = missing_flits + 1;
      latency_count = flit_latency_count;
      flit_p50 = 0; flit_p95 = 0; flit_p99 = 0; packet_p50 = 0; packet_p95 = 0; packet_p99 = 0;
      flit_p50_set = 0; flit_p95_set = 0; flit_p99_set = 0;
      packet_p50_set = 0; packet_p95_set = 0; packet_p99_set = 0;
      if (flit_latency_count > 0) begin
        rank50 = (50 * flit_latency_count + 99) / 100; if (rank50 > flit_latency_count) rank50 = flit_latency_count;
        rank95 = (95 * flit_latency_count + 99) / 100; if (rank95 > flit_latency_count) rank95 = flit_latency_count;
        rank99 = (99 * flit_latency_count + 99) / 100; if (rank99 > flit_latency_count) rank99 = flit_latency_count;
        seen = 0;
        for (i = 0; i < LAT_HIST_BINS; i = i + 1) begin
          seen = seen + flit_lat_hist[i];
          if (!flit_p50_set && (seen >= rank50)) begin flit_p50 = i * LAT_HIST_PS; flit_p50_set = 1; end
          if (!flit_p95_set && (seen >= rank95)) begin flit_p95 = i * LAT_HIST_PS; flit_p95_set = 1; end
          if (!flit_p99_set && (seen >= rank99)) begin flit_p99 = i * LAT_HIST_PS; flit_p99_set = 1; end
        end
      end
      if (packet_latency_count > 0) begin
        rank50 = (50 * packet_latency_count + 99) / 100; if (rank50 > packet_latency_count) rank50 = packet_latency_count;
        rank95 = (95 * packet_latency_count + 99) / 100; if (rank95 > packet_latency_count) rank95 = packet_latency_count;
        rank99 = (99 * packet_latency_count + 99) / 100; if (rank99 > packet_latency_count) rank99 = packet_latency_count;
        seen = 0;
        for (i = 0; i < LAT_HIST_BINS; i = i + 1) begin
          seen = seen + packet_lat_hist[i];
          if (!packet_p50_set && (seen >= rank50)) begin packet_p50 = i * LAT_HIST_PS; packet_p50_set = 1; end
          if (!packet_p95_set && (seen >= rank95)) begin packet_p95 = i * LAT_HIST_PS; packet_p95_set = 1; end
          if (!packet_p99_set && (seen >= rank99)) begin packet_p99 = i * LAT_HIST_PS; packet_p99_set = 1; end
        end
      end
      flit_avg_ns = flit_latency_count ? (flit_lat_sum * 1.0 / flit_latency_count / 1000.0) : 0.0;
      packet_avg_ns = packet_latency_count ? (packet_lat_sum * 1.0 / packet_latency_count / 1000.0) : 0.0;
      window_ns = (measurement_end_ps - measurement_start_ps) / 1000.0;
      window_s = window_ns * 1.0e-9;
      offered_mflit_port_s = window_s > 0.0 ? (measurement_offered_flits / window_s / NUM_CORES / 1.0e6) : 0.0;
      delivered_mflit_port_s = window_s > 0.0 ? (measurement_delivered_flits / window_s / NUM_CORES / 1.0e6) : 0.0;
      pass_ok = !timed_out && (injected_flits == input_count) && (missing_flits == 0) && (unexpected_flits == 0);

      fd_summary = $fopen(csv_file, "w");
      $fwrite(fd_summary, "group,case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,warmup_original_events,measurement_original_events,measurement_start_ps,measurement_end_ps,measurement_offered_flits,measurement_delivered_flits,measurement_delivered_copies,measurement_backlog_flits,offered_mflit_port_s,delivered_mflit_port_s,flit_lat_mean_ns,flit_lat_p50_ns,flit_lat_max_ns,flit_lat_p95_ns,flit_lat_p99_ns,offer_to_tail_mean_ns,offer_to_tail_p50_ns,offer_to_tail_max_ns,offer_to_tail_p95_ns,offer_to_tail_p99_ns,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      $fwrite(fd_summary, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%0s\n", case_group, case_name, injected_packets, delivered_packets, injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, warmup_events, measurement_events, measurement_start_ps, measurement_end_ps, measurement_offered_flits, measurement_delivered_flits, measurement_delivered_copies, measurement_backlog_flits, offered_mflit_port_s, delivered_mflit_port_s, flit_avg_ns, flit_p50/1000.0, flit_max_lat/1000.0, flit_p95/1000.0, flit_p99/1000.0, packet_avg_ns, packet_p50/1000.0, packet_max_lat/1000.0, packet_p95/1000.0, packet_p99/1000.0, delivered_mflit_port_s, packet_avg_ns, packet_max_lat/1000.0, packet_p95/1000.0, packet_p99/1000.0, pass_ok ? "PASS" : "FAIL");
      $fclose(fd_summary);

      fd_events = $fopen(event_csv_file, "w");
      $fwrite(fd_events, "kind,port,pkt_seq,flit,offer_ps,req_ps,ack_ps,egress_req_ps,capture_ps,matched\n");
      for (i = 0; i < input_count; i = i + 1)
        $fwrite(fd_events, "TX,%0d,%0d,%h,%0d,%0d,%0d,-1,-1,%0d\n", input_port[i], input_pkt_seq[i], input_flit[i], input_offer_ps[i], input_req_ps[i], input_ack_ps[i], input_accepted[i]);
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1)
        $fwrite(fd_events, "RX,%0d,%0d,%h,-1,-1,-1,%0d,%0d,%0d\n", p, rx_expected_index[p][s] >= 0 ? expected_pkt_seq[rx_expected_index[p][s]] : -1, rx_flit[p][s], rx_egress_ps[p][s], rx_time_ps[p][s], rx_match[p][s]);
      $fclose(fd_events);

      fd_latency = $fopen(latency_csv_file, "w");
      $fwrite(fd_latency, "port,pkt_seq,original_event_id,tail_flit,head_offer_ps,head_inject_req_ps,head_ingress_ack_ps,tail_egress_req_ps,tail_capture_ps,offer_to_tail_ns,ingress_service_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s] && expected_is_tail[rx_expected_index[p][s]]) begin
        i = rx_expected_index[p][s]; packet = expected_pkt_seq[i];
        $fwrite(fd_latency, "%0d,%0d,%0d,%h,%0d,%0d,%0d,%0d,%0d,%f,%f\n", p, packet, packet_event_id[packet], rx_flit[p][s], packet_offer_ps[packet], packet_head_req_ps[packet], packet_head_ack_ps[packet], rx_egress_ps[p][s], rx_time_ps[p][s], (rx_egress_ps[p][s]-packet_offer_ps[packet])/1000.0, (rx_egress_ps[p][s]-packet_head_ack_ps[packet])/1000.0);
      end
      $fclose(fd_latency);

      fd_flit = $fopen(flit_latency_csv_file, "w");
      $fwrite(fd_flit, "port,pkt_seq,flit,offer_ps,egress_ps,lat_ns\n");
      for (p = 0; p < NUM_PORTS; p = p + 1) for (s = 0; s < rx_count[p]; s = s + 1) if (rx_match[p][s]) begin
        i = rx_expected_index[p][s]; tx_index = expected_input_index[i];
        if (tx_index >= 0 && input_offer_ps[tx_index] >= 0)
          $fwrite(fd_flit, "%0d,%0d,%h,%0d,%0d,%f\n", p, expected_pkt_seq[i], rx_flit[p][s], input_offer_ps[tx_index], rx_egress_ps[p][s], (rx_egress_ps[p][s]-input_offer_ps[tx_index])/1000.0);
      end
      $fclose(fd_flit);
      if (write_v3_metrics) begin
        fd_v3 = $fopen(v3_metrics_file, "w");
        $fwrite(fd_v3, "drainable,timeout,missing_flits,unexpected_flits,injected_flits,delivered_flits,inflight_end,warmup_original_events,measurement_original_events,errors,backlog_growth,pass_fail\n");
        $fwrite(fd_v3, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0s\n",
                pass_ok, timed_out, missing_flits, unexpected_flits, injected_flits, delivered_flits,
                missing_flits, warmup_events, measurement_events,
                missing_flits + unexpected_flits + timed_out,
                measurement_backlog_flits > 0,
                pass_ok ? "PASS" : "FAIL");
        $fclose(fd_v3);
      end
      $display("TB_RESULT %0s injected=%0d delivered=%0d missing=%0d unexpected=%0d timeout=%0d metrics_v2 offered=%0.6f delivered_rate=%0.6f backlog=%0d flit_lat_mean_ns=%0.3f", pass_ok ? "PASS" : "FAIL", injected_flits, delivered_flits, missing_flits, unexpected_flits, timed_out, offered_mflit_port_s, delivered_mflit_port_s, measurement_backlog_flits, flit_avg_ns);
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
      initial arrive_port(gp);
      initial service_port(gp);
    end
  endgenerate

  initial begin
`ifdef CMR_LOCAL_MESH64_HEADONLY_CASE
    case_file = "sim/CMR/testbench/DBG-64_fm64_6to44_body0.case";
`else
    case_file = "";
`endif
    csv_file = "async_noc64_summary.csv"; event_csv_file = "async_noc64_events.csv"; latency_csv_file = "async_noc64_latency.csv";
    flit_latency_csv_file = "async_noc64_flit_latency.csv";
    missing_csv_file = "async_noc64_missing_expected.csv";
    v3_metrics_file = ""; write_v3_metrics = 1'b0;
    case_tick_ns = 20.0; tx_setup_ns = 0.05; rx_capture_ns = 0.05;
    ack_to_next_req_guard_ns = 0.20; timeout_scale = 1.0; inject_max_rate = 0;
    if ($value$plusargs("CASE_FILE=%s", case_file)) ;
    if ($value$plusargs("RESULT_CSV=%s", csv_file)) ;
    if ($value$plusargs("EVENT_CSV=%s", event_csv_file)) ;
    if ($value$plusargs("LATENCY_CSV=%s", latency_csv_file)) ;
    if ($value$plusargs("FLIT_LATENCY_CSV=%s", flit_latency_csv_file)) ;
    if ($value$plusargs("MISSING_CSV=%s", missing_csv_file)) ;
    if ($value$plusargs("V3_METRICS_CSV=%s", v3_metrics_file)) write_v3_metrics = 1'b1;
    if ($value$plusargs("CASE_TICK_NS=%f", case_tick_ns)) ;
    if ($value$plusargs("TX_SETUP_NS=%f", tx_setup_ns)) ;
    if ($value$plusargs("RX_CAPTURE_NS=%f", rx_capture_ns)) ;
    if ($value$plusargs("ACK_TO_NEXT_REQ_GUARD_NS=%f", ack_to_next_req_guard_ns)) ;
    if ($value$plusargs("TIMEOUT_SCALE=%f", timeout_scale)) ;
    if ($test$plusargs("INJECT_MAX_RATE")) inject_max_rate = 1;
    // An egress-only dump is intentionally small enough for a whole-network
    // failure replay.  It preserves every boundary Req/Ack/Data handshake,
    // including the port selected by the probe, without dumping all routers.
    dump_measurement_only = $test$plusargs("DUMP_MEASUREMENT_ONLY");
    if ($value$plusargs("DUMP_VCD=%s", dump_vcd)) begin
      $dumpfile(dump_vcd);
      if ($test$plusargs("DUMP_EGRESS_ONLY"))
        $dumpvars(0, tb_out_req, tb_out_ack, tb_out_data);
      else
        $dumpvars(0, noc64_async_boundary_core);
      // Keep VCD declaration/header complete, but suppress warm-up and drain
      // activity when this run is dedicated to time-based PT-PX analysis.
      if (dump_measurement_only) $dumpoff;
    end
    if (case_file == "") begin $display("TB_FATAL +CASE_FILE=<case> is required"); $finish; end
    $display("TB_INFO NUM_CORES=%0d TOP_LANES=%0d NUM_PORTS=%0d ACK_TO_NEXT_REQ_GUARD_NS=%0.3f INJECT_MAX_RATE=%0d CASE_TICK_NS=%0.3f RX_CAPTURE_NS=%0.3f", NUM_CORES, TOP_LANES, NUM_PORTS, ack_to_next_req_guard_ns, inject_max_rate, case_tick_ns, rx_capture_ns);
    parse_case();
    $display("TB_INFO CASE_HAS_IDENTITY=%0d expected=%0d", case_has_identity, expected_count);
    reset = 1'b1; tb_in_req = '0; tb_in_data = '0; tb_out_ack = '0; input_done = '0;
    running = 1'b0; timed_out = 1'b0; finish_requested = 1'b0; unexpected_flits = 0;
    measurement_backlog_snapshot = 0;
    csv_dumped = 1'b0;
    #(reset_cycles * case_tick_ns);
    reset = 1'b0;
    #10.0;
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
    // Snapshot only the explicit source queues at the boundary.  A flit already
    // handed to the DUT is not source backlog, even if its ACK arrives later.
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

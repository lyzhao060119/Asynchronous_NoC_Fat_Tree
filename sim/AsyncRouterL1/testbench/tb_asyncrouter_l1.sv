`timescale 1ns/1ps

module tb_asyncrouter_l1;
  localparam FLIT_W = 28;
  localparam NUM_PORTS = 6;
  localparam MAX_INPUT_FLITS = 8192;
  localparam MAX_EXPECT_FLITS = 32768;
  localparam MAX_PKT_SEQ = 65536;
  localparam STR_CHARS = 256;
  localparam CLK_HALF_PERIOD_NS = 5;

  localparam P_CHILD0 = 0;
  localparam P_CHILD1 = 1;
  localparam P_CHILD2 = 2;
  localparam P_CHILD3 = 3;
  localparam P_PARENT0 = 4;
  localparam P_PARENT1 = 5;

  reg clock = 1'b0;
  reg reset;

  reg  [NUM_PORTS-1:0] in_req;
  wire [NUM_PORTS-1:0] in_ack;
  reg  [FLIT_W-1:0] in_data [0:NUM_PORTS-1];

  wire [NUM_PORTS-1:0] out_req;
  reg  [NUM_PORTS-1:0] out_ack;
  wire [FLIT_W-1:0] out_data [0:NUM_PORTS-1];

  integer cycle_count;
  integer reset_cycles, timeout_cycles, out_ack_delay_cycles;
  integer timeout_scale;
  reg [STR_CHARS*8-1:0] case_file, case_name, csv_file;

  integer input_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];

  integer expected_count;
  reg [NUM_PORTS-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];

  integer packet_head_cycle [0:MAX_PKT_SEQ-1];
  integer latency_samples [0:MAX_EXPECT_FLITS-1];
  integer latency_count;

  integer injected_flits, delivered_flits, unexpected_flits;
  integer injected_packets, delivered_packets;
  integer timeout_hit;
  integer test_done;
  integer ack_countdown [0:NUM_PORTS-1];
  reg accept_pending [0:NUM_PORTS-1];
  reg debug_probe_enable;

  initial forever #CLK_HALF_PERIOD_NS clock = ~clock;

  always @(posedge clock) begin
    cycle_count <= reset ? 0 : cycle_count + 1;
  end

  function is_blank_or_comment;
    input [STR_CHARS*8-1:0] line;
    reg [STR_CHARS*8-1:0] tag;
    begin
      tag = "";
      is_blank_or_comment = (($sscanf(line, "%s", tag) != 1) || (tag == "#"));
    end
  endfunction

  task automatic load_case;
    integer fd, n, line_no;
    integer cyc, p, pkt_seq, tmp;
    reg [31:0] mask;
    reg [FLIT_W-1:0] flit;
    reg [STR_CHARS*8-1:0] line, tag, name;
    begin
      reset_cycles = 10;
      timeout_cycles = 2000;
      out_ack_delay_cycles = 0;
      input_count = 0;
      expected_count = 0;
      case_name = "unnamed";

      if (!$value$plusargs("CASE=%s", case_file))
        case_file = "testbench/cases/current.case";
      if (!$value$plusargs("CSV=%s", csv_file))
        csv_file = "summary/summary.csv";

      fd = $fopen(case_file, "r");
      if (fd == 0) begin
        $display("TB_FATAL cannot open CASE file: %0s", case_file);
        $finish;
      end

      line_no = 0;
      while (!$feof(fd)) begin
        line = "";
        n = $fgets(line, fd);
        line_no = line_no + 1;

        if (!is_blank_or_comment(line)) begin
          tag = "";
          n = $sscanf(line, "%s", tag);

          if (tag == "case") begin
            if ($sscanf(line, "%s %s", tag, name) != 2) begin
              $display("TB_FATAL malformed case at line %0d", line_no);
              $finish;
            end
            case_name = name;
          end else if (tag == "timeout_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed timeout_cycles at line %0d", line_no);
              $finish;
            end
            timeout_cycles = tmp;
          end else if (tag == "reset_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed reset_cycles at line %0d", line_no);
              $finish;
            end
            reset_cycles = tmp;
          end else if (tag == "out_ack_delay_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed out_ack_delay_cycles at line %0d", line_no);
              $finish;
            end
            out_ack_delay_cycles = tmp;
          end else if (tag == "input") begin
            if ($sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt_seq, flit) != 5) begin
              $display("TB_FATAL malformed input at line %0d", line_no);
              $finish;
            end
            if ((input_count >= MAX_INPUT_FLITS) || (p < 0) || (p >= NUM_PORTS) || (pkt_seq < 0) || (pkt_seq >= MAX_PKT_SEQ)) begin
              $display("TB_FATAL invalid input values at line %0d", line_no);
              $finish;
            end
            input_cycle[input_count] = cyc;
            input_port[input_count] = p;
            input_pkt_seq[input_count] = pkt_seq;
            input_flit[input_count] = flit;
            input_count = input_count + 1;
          end else if (tag == "expect") begin
            if ($sscanf(line, "%s %h %d %d %h", tag, mask, pkt_seq, tmp, flit) != 5) begin
              $display("TB_FATAL malformed expect at line %0d", line_no);
              $finish;
            end
            if ((expected_count >= MAX_EXPECT_FLITS) || (mask[NUM_PORTS-1:0] == 0) || (mask[31:NUM_PORTS] != 0) ||
                (pkt_seq < 0) || (pkt_seq >= MAX_PKT_SEQ) || ((tmp != 0) && (tmp != 1))) begin
              $display("TB_FATAL invalid expect values at line %0d", line_no);
              $finish;
            end
            expected_mask[expected_count] = mask[NUM_PORTS-1:0];
            expected_pkt_seq[expected_count] = pkt_seq;
            expected_is_tail[expected_count] = (tmp == 1);
            expected_flit[expected_count] = flit;
            expected_seen[expected_count] = 1'b0;
            expected_count = expected_count + 1;
          end else begin
            $display("TB_FATAL unknown tag '%0s' at line %0d", tag, line_no);
            $finish;
          end
        end
      end
      $fclose(fd);

      timeout_scale = 1;
      if ($value$plusargs("TIMEOUT_SCALE=%d", timeout_scale) && (timeout_scale > 1))
        timeout_cycles = timeout_cycles * timeout_scale;
    end
  endtask

  task automatic drive_port;
    input integer p;
    integer i;
    integer next_i;
    integer pkt_seq;
    begin
      wait (!reset);
      @(negedge clock);
      in_req[p] = 1'b0;
      in_data[p] = {FLIT_W{1'b0}};

      i = 0;
      while (i < input_count) begin
        while ((i < input_count) && (input_port[i] != p)) i = i + 1;
        if (i < input_count) begin
          while (cycle_count < input_cycle[i]) @(posedge clock);

          while (in_req[p] !== in_ack[p]) @(posedge clock);
          in_data[p] = input_flit[i];
          in_req[p] = ~in_req[p];

          while (in_req[p] !== in_ack[p]) @(posedge clock);
          injected_flits = injected_flits + 1;
          if (input_flit[i][27]) begin
            pkt_seq = input_pkt_seq[i];
            injected_packets = injected_packets + 1;
            if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && (packet_head_cycle[pkt_seq] < 0))
              packet_head_cycle[pkt_seq] = cycle_count;
          end

          next_i = i + 1;
          while ((next_i < input_count) && (input_port[next_i] != p)) next_i = next_i + 1;
          i = next_i;
        end
      end
    end
  endtask

  task automatic sample_output;
    input integer p;
    integer i, pkt_seq, lat;
    reg found;
    reg [NUM_PORTS-1:0] port_bit;
    begin
      found = 1'b0;
      port_bit = 0;
      port_bit[p] = 1'b1;
      for (i = 0; i < expected_count; i = i + 1) begin
        if (!found && !expected_seen[i] && ((expected_mask[i] & port_bit) != 0) && (expected_flit[i] === out_data[p])) begin
          expected_seen[i] = 1'b1;
          delivered_flits = delivered_flits + 1;
          found = 1'b1;
          if (expected_is_tail[i]) begin
            pkt_seq = expected_pkt_seq[i];
            delivered_packets = delivered_packets + 1;
            if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && (packet_head_cycle[pkt_seq] >= 0)) begin
              lat = cycle_count - packet_head_cycle[pkt_seq];
              if (latency_count < MAX_EXPECT_FLITS) begin
                latency_samples[latency_count] = lat;
                latency_count = latency_count + 1;
              end
            end
          end
        end
      end
      if (!found) unexpected_flits = unexpected_flits + 1;
    end
  endtask

  task automatic write_csv_and_finish;
    integer i, j, t;
    integer missing, lat_sum, max_lat, rank95, rank99, p95_lat, p99_lat;
    integer fd_csv;
    integer csv_pos;
    reg write_header;
    reg pass_ok;
    reg [31:0] pass_text;
    real avg_lat;
    real throughput;
    begin
      if (test_done != 0) begin
        forever @(posedge clock);
      end
      test_done = 1;

      missing = 0;
      for (i = 0; i < expected_count; i = i + 1)
        if (!expected_seen[i]) missing = missing + 1;

      lat_sum = 0;
      max_lat = 0;
      for (i = 0; i < latency_count; i = i + 1) begin
        lat_sum = lat_sum + latency_samples[i];
        if (latency_samples[i] > max_lat) max_lat = latency_samples[i];
      end

      for (i = 0; i < latency_count; i = i + 1) begin
        for (j = i + 1; j < latency_count; j = j + 1) begin
          if (latency_samples[j] < latency_samples[i]) begin
            t = latency_samples[i];
            latency_samples[i] = latency_samples[j];
            latency_samples[j] = t;
          end
        end
      end

      if (latency_count > 0) begin
        rank95 = (95 * latency_count + 99) / 100;
        rank99 = (99 * latency_count + 99) / 100;
        if (rank95 < 1) rank95 = 1;
        if (rank99 < 1) rank99 = 1;
        if (rank95 > latency_count) rank95 = latency_count;
        if (rank99 > latency_count) rank99 = latency_count;
        p95_lat = latency_samples[rank95 - 1];
        p99_lat = latency_samples[rank99 - 1];
        avg_lat = lat_sum * 1.0 / latency_count;
      end else begin
        p95_lat = 0;
        p99_lat = 0;
        avg_lat = 0.0;
      end

      throughput = (cycle_count > 0) ? (delivered_flits * 1.0 / cycle_count) : 0.0;
      pass_ok = (timeout_hit == 0) && (unexpected_flits == 0) && (missing == 0) && (injected_flits == input_count);
      pass_text = pass_ok ? "PASS" : "FAIL";

      fd_csv = $fopen(csv_file, "a+");
      if (fd_csv == 0) begin
        $display("TB_FATAL cannot open CSV file: %0s", csv_file);
        $finish;
      end
      csv_pos = $fseek(fd_csv, 0, 2);
      csv_pos = $ftell(fd_csv);
      write_header = (csv_pos == 0);
      if (write_header) begin
        $fwrite(fd_csv, "case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,measure_cycles,delivered_throughput,avg_packet_latency_cycles,max_packet_latency_cycles,p95_latency_cycles,p99_latency_cycles,pass_fail\n");
      end
      $fwrite(
        fd_csv,
        "%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.6f,%0d,%0d,%0d,%0s\n",
        case_name,
        injected_packets,
        delivered_packets,
        injected_flits,
        delivered_flits,
        missing,
        unexpected_flits,
        timeout_hit,
        cycle_count,
        throughput,
        avg_lat,
        max_lat,
        p95_lat,
        p99_lat,
        pass_text
      );
      $fclose(fd_csv);

      $display(
        "TB_RESULT %0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d unexpected=%0d missing=%0d timeout=%0d",
        pass_text,
        case_name,
        injected_flits,
        delivered_flits,
        delivered_packets,
        unexpected_flits,
        missing,
        timeout_hit
      );
      $finish;
    end
  endtask

  always @(posedge clock) begin : output_ack_proc
    integer p;
    if (reset) begin
      out_ack <= 0;
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        ack_countdown[p] <= -1;
        accept_pending[p] <= 1'b0;
      end
    end else begin
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        if (accept_pending[p]) begin
          if (ack_countdown[p] == 0) begin
            sample_output(p);
            out_ack[p] <= ~out_ack[p];
            accept_pending[p] <= 1'b0;
            ack_countdown[p] <= -1;
          end else if (ack_countdown[p] > 0) begin
            ack_countdown[p] <= ack_countdown[p] - 1;
          end
        end else if (out_req[p] !== out_ack[p]) begin
          if (out_ack_delay_cycles == 0) begin
            sample_output(p);
            out_ack[p] <= ~out_ack[p];
          end else begin
            accept_pending[p] <= 1'b1;
            ack_countdown[p] <= out_ack_delay_cycles;
          end
        end
      end
    end
  end

  initial begin : main_proc
    integer p, i, drain_cycle;
    reset = 1'b1;
    in_req = 0;
    out_ack = 0;
    cycle_count = 0;
    injected_flits = 0;
    delivered_flits = 0;
    unexpected_flits = 0;
    injected_packets = 0;
    delivered_packets = 0;
    latency_count = 0;
    timeout_hit = 0;
    test_done = 0;
    debug_probe_enable = 1'b0;
    if ($test$plusargs("DEBUG_FANIN") || $test$plusargs("DEBUG_PROBE")) debug_probe_enable = 1'b1;

    for (p = 0; p < NUM_PORTS; p = p + 1) begin
      in_data[p] = 0;
      ack_countdown[p] = -1;
      accept_pending[p] = 1'b0;
    end
    for (i = 0; i < MAX_EXPECT_FLITS; i = i + 1) expected_seen[i] = 1'b0;
    for (i = 0; i < MAX_PKT_SEQ; i = i + 1) packet_head_cycle[i] = -1;

    load_case();

    repeat (reset_cycles) @(posedge clock);
    reset = 1'b0;

    fork
      begin
        fork
          drive_port(P_CHILD0);
          drive_port(P_CHILD1);
          drive_port(P_CHILD2);
          drive_port(P_CHILD3);
          drive_port(P_PARENT0);
          drive_port(P_PARENT1);
        join

        drain_cycle = 0;
        while ((delivered_flits < expected_count) && (drain_cycle < timeout_cycles) && (test_done == 0)) begin
          @(posedge clock);
          drain_cycle = drain_cycle + 1;
        end
        if ((delivered_flits < expected_count) && (test_done == 0)) timeout_hit = 1;

        if (test_done == 0) write_csv_and_finish();
      end

      begin
        repeat (timeout_cycles) @(posedge clock);
        if (test_done == 0) begin
          timeout_hit = 1;
          $display("TB_TIMEOUT case=%0s timeout_cycles=%0d injected_flits=%0d delivered_flits=%0d expected_flits=%0d", case_name, timeout_cycles, injected_flits, delivered_flits, expected_count);
          write_csv_and_finish();
        end
      end
    join
  end

  RouterL1 dut (
    .clock                          (clock),
    .reset                          (reset),
    .io_inputs_child_0_0_HS_Req     (in_req[P_CHILD0]),
    .io_inputs_child_0_0_HS_Ack     (in_ack[P_CHILD0]),
    .io_inputs_child_0_0_Data_flit  (in_data[P_CHILD0]),
    .io_inputs_child_1_0_HS_Req     (in_req[P_CHILD1]),
    .io_inputs_child_1_0_HS_Ack     (in_ack[P_CHILD1]),
    .io_inputs_child_1_0_Data_flit  (in_data[P_CHILD1]),
    .io_inputs_child_2_0_HS_Req     (in_req[P_CHILD2]),
    .io_inputs_child_2_0_HS_Ack     (in_ack[P_CHILD2]),
    .io_inputs_child_2_0_Data_flit  (in_data[P_CHILD2]),
    .io_inputs_child_3_0_HS_Req     (in_req[P_CHILD3]),
    .io_inputs_child_3_0_HS_Ack     (in_ack[P_CHILD3]),
    .io_inputs_child_3_0_Data_flit  (in_data[P_CHILD3]),
    .io_inputs_parent_0_HS_Req      (in_req[P_PARENT0]),
    .io_inputs_parent_0_HS_Ack      (in_ack[P_PARENT0]),
    .io_inputs_parent_0_Data_flit   (in_data[P_PARENT0]),
    .io_inputs_parent_1_HS_Req      (in_req[P_PARENT1]),
    .io_inputs_parent_1_HS_Ack      (in_ack[P_PARENT1]),
    .io_inputs_parent_1_Data_flit   (in_data[P_PARENT1]),
    .io_outputs_child_0_0_HS_Req    (out_req[P_CHILD0]),
    .io_outputs_child_0_0_HS_Ack    (out_ack[P_CHILD0]),
    .io_outputs_child_0_0_Data_flit (out_data[P_CHILD0]),
    .io_outputs_child_1_0_HS_Req    (out_req[P_CHILD1]),
    .io_outputs_child_1_0_HS_Ack    (out_ack[P_CHILD1]),
    .io_outputs_child_1_0_Data_flit (out_data[P_CHILD1]),
    .io_outputs_child_2_0_HS_Req    (out_req[P_CHILD2]),
    .io_outputs_child_2_0_HS_Ack    (out_ack[P_CHILD2]),
    .io_outputs_child_2_0_Data_flit (out_data[P_CHILD2]),
    .io_outputs_child_3_0_HS_Req    (out_req[P_CHILD3]),
    .io_outputs_child_3_0_HS_Ack    (out_ack[P_CHILD3]),
    .io_outputs_child_3_0_Data_flit (out_data[P_CHILD3]),
    .io_outputs_parent_0_HS_Req     (out_req[P_PARENT0]),
    .io_outputs_parent_0_HS_Ack     (out_ack[P_PARENT0]),
    .io_outputs_parent_0_Data_flit  (out_data[P_PARENT0]),
    .io_outputs_parent_1_HS_Req     (out_req[P_PARENT1]),
    .io_outputs_parent_1_HS_Ack     (out_ack[P_PARENT1]),
    .io_outputs_parent_1_Data_flit  (out_data[P_PARENT1])
  );

  // #region agent log — DUT hierarchical probes (session 93667c)
  wire [5:0] probe_in_valid = {
    dut.ipm.inputPorts_5.io_inValid,
    dut.ipm.inputPorts_4.io_inValid,
    dut.ipm.inputPorts_3.io_inValid,
    dut.ipm.inputPorts_2.io_inValid,
    dut.ipm.inputPorts_1.io_inValid,
    dut.ipm.inputPorts_0.io_inValid
  };
  wire [5:0] probe_is_head = {
    dut.ipm.inputPorts_5.io_isHead,
    dut.ipm.inputPorts_4.io_isHead,
    dut.ipm.inputPorts_3.io_isHead,
    dut.ipm.inputPorts_2.io_isHead,
    dut.ipm.inputPorts_1.io_isHead,
    dut.ipm.inputPorts_0.io_isHead
  };
  wire [5:0] probe_head_alloc_ok = {
    dut.ipm.control.laneReservation.io_headAllocOk_5,
    dut.ipm.control.laneReservation.io_headAllocOk_4,
    dut.ipm.control.laneReservation.io_headAllocOk_3,
    dut.ipm.control.laneReservation.io_headAllocOk_2,
    dut.ipm.control.laneReservation.io_headAllocOk_1,
    dut.ipm.control.laneReservation.io_headAllocOk_0
  };
  wire [5:0] probe_elig_any = {
    |{dut.ipm.control.io_destMask_5_0, dut.ipm.control.io_destMask_5_1,
      dut.ipm.control.io_destMask_5_2, dut.ipm.control.io_destMask_5_3},
    |{dut.ipm.control.io_destMask_4_0, dut.ipm.control.io_destMask_4_1,
      dut.ipm.control.io_destMask_4_2, dut.ipm.control.io_destMask_4_3},
    |{dut.ipm.control.io_destMask_3_0, dut.ipm.control.io_destMask_3_1,
      dut.ipm.control.io_destMask_3_2, dut.ipm.control.io_destMask_3_3,
      dut.ipm.control.io_destMask_3_4, dut.ipm.control.io_destMask_3_5},
    |{dut.ipm.control.io_destMask_2_0, dut.ipm.control.io_destMask_2_1,
      dut.ipm.control.io_destMask_2_2, dut.ipm.control.io_destMask_2_3,
      dut.ipm.control.io_destMask_2_4, dut.ipm.control.io_destMask_2_5},
    |{dut.ipm.control.io_destMask_1_0, dut.ipm.control.io_destMask_1_1,
      dut.ipm.control.io_destMask_1_2, dut.ipm.control.io_destMask_1_3,
      dut.ipm.control.io_destMask_1_4, dut.ipm.control.io_destMask_1_5},
    |{dut.ipm.control.io_destMask_0_0, dut.ipm.control.io_destMask_0_1,
      dut.ipm.control.io_destMask_0_2, dut.ipm.control.io_destMask_0_3,
      dut.ipm.control.io_destMask_0_4, dut.ipm.control.io_destMask_0_5}
  };
  wire [5:0] probe_h6_none = {
    dut.opm.io_holder_5 == 3'd6,
    dut.opm.io_holder_4 == 3'd6,
    dut.opm.io_holder_3 == 3'd6,
    dut.opm.io_holder_2 == 3'd6,
    dut.opm.io_holder_1 == 3'd6,
    dut.opm.io_holder_0 == 3'd6
  };
  wire [3:0] probe_op4_fv = {
    dut.opm.outputPorts_4.requestSelector.arbiter.selector.fullVec_3,
    dut.opm.outputPorts_4.requestSelector.arbiter.selector.fullVec_2,
    dut.opm.outputPorts_4.requestSelector.arbiter.selector.fullVec_1,
    dut.opm.outputPorts_4.requestSelector.arbiter.selector.fullVec_0
  };
  wire [3:0] probe_op5_fv = {
    dut.opm.outputPorts_5.requestSelector.arbiter.selector.fullVec_3,
    dut.opm.outputPorts_5.requestSelector.arbiter.selector.fullVec_2,
    dut.opm.outputPorts_5.requestSelector.arbiter.selector.fullVec_1,
    dut.opm.outputPorts_5.requestSelector.arbiter.selector.fullVec_0
  };

  fanin_debug_probe u_debug_probe (
    .clk                 (clock),
    .rst                 (reset),
    .enable              (debug_probe_enable),
    .cycle_count         (cycle_count),
    .tb_in_req           (in_req),
    .tb_in_ack           (in_ack),
    .tb_out_req          (out_req),
    .tb_out_ack          (out_ack),
    .in_valid            (probe_in_valid[3:0]),
    .is_head             (probe_is_head[3:0]),
    .head_alloc_ok       (probe_head_alloc_ok[3:0]),
    .route_parent        (4'b0),
    .elig_dm_p0          (probe_elig_any[3:0]),
    .elig_dm_p1          (4'b0),
    .fork_p0_full        (4'b0),
    .fork_p1_full        (4'b0),
    .holder_p0           (dut.opm.io_holder_4),
    .holder_p1           (dut.opm.io_holder_5),
    .edge_p0_full        (8'b0),
    .edge_p1_full        (8'b0),
    .op4_in_full         (4'b0),
    .op4_fv              (probe_op4_fv),
    .op4_ov              (dut.opm.outputPorts_4.requestSelector.arbiter.selector.outValid_2),
    .op4_or              (dut.opm.outputPorts_4.requestSelector.arbiter.selector.outReady_2),
    .op4_start           (dut.opm.outputPorts_4.requestSelector.arbiter.selector.acg_Start),
    .op4_oreq            (dut.opm.outputPorts_4.requestSelector.arbiter.selector.io_outReq),
    .op4_oack            (dut.opm.outputPorts_4.requestSelector.arbiter.selector.io_outAck),
    .op5_in_full         (4'b0),
    .op5_fv              (probe_op5_fv),
    .op5_ov              (dut.opm.outputPorts_5.requestSelector.arbiter.selector.outValid_2),
    .op5_or              (dut.opm.outputPorts_5.requestSelector.arbiter.selector.outReady_2),
    .op5_start           (dut.opm.outputPorts_5.requestSelector.arbiter.selector.acg_Start),
    .op5_oreq            (dut.opm.outputPorts_5.requestSelector.arbiter.selector.io_outReq),
    .op5_oack            (dut.opm.outputPorts_5.requestSelector.arbiter.selector.io_outAck),
    .iv6                 (probe_in_valid),
    .ih6                 (probe_is_head),
    .ha6                 (probe_head_alloc_ok),
    .ed6                 (probe_elig_any),
    .h6                  (probe_h6_none),
    .inj                 (injected_flits),
    .del                 (delivered_flits)
  );
  // #endregion
endmodule

`timescale 1ns/1ps
// No-SDF gate-level functional TB for RouterL1.
// Case protocol matches local tb_asyncrouter_l1 (load/inject/expect/CSV/TB_RESULT).
// No hierarchical probes. No fork / task automatic (VCS Pass2 safety).
// Injection is sequential in cycle order (smoke/e1 cases are non-overlapping).
module tb_gls_routerl1_func;
  localparam FLIT_W = 28;
  localparam NUM_PORTS = 6;
  localparam MAX_INPUT_FLITS = 8192;
  localparam MAX_EXPECT_FLITS = 32768;
  localparam MAX_PKT_SEQ = 65536;
  localparam STR_CHARS = 256;
  localparam CLK_HALF_PERIOD_NS = 5;

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
  integer req_stable [0:NUM_PORTS-1];
  reg [FLIT_W-1:0] req_data_seen [0:NUM_PORTS-1];
  // Gate+SDF: req can lead data; wait until both are stable (bundled-data).
  localparam REQ_STABLE_CYCLES = 5;

  integer output_enable;
  integer gls_probe_enable;
  real t_src_req;
  real t_dst_req;
  integer e2e_done;
  integer e2e_src_set;
  // DUT-boundary Head E2E probe (same semantics as NoC16 E2E_EDGE_PROBE).
  integer e2e_edge_probe;
  integer e2e_src_port;
  integer e2e_dst_port;
  integer e2e_probe_flit_set;
  reg [FLIT_W-1:0] e2e_probe_flit;
  real t_edge_in_req;
  real t_edge_out_req;
  real t_edge_out_valid;
  integer edge_in_req_seen;
  integer edge_out_req_seen;
  integer edge_out_valid_seen;

`ifdef GLS_GATE_PROBE
  reg [5:0]  probe_prev_holder;
  reg [15:0] probe_prev_edge_req;
  reg [15:0] probe_prev_edge_ack;
  reg [5:0]  probe_prev_dmask0;
  reg [5:0]  probe_prev_dmask3;
  reg [3:0]  probe_prev_dmask4;

  function [5:0] probe_dmask0;
    begin
      probe_dmask0 = {
        dut.ipm.control_io_destMask_0_5,
        dut.ipm.control_io_destMask_0_4,
        dut.ipm.control_io_destMask_0_3,
        dut.ipm.control_io_destMask_0_2,
        dut.ipm.control_io_destMask_0_1,
        dut.ipm.control_io_destMask_0_0
      };
    end
  endfunction

  function [5:0] probe_dmask3;
    begin
      probe_dmask3 = {
        dut.ipm.control_io_destMask_3_5,
        dut.ipm.control_io_destMask_3_4,
        dut.ipm.control_io_destMask_3_3,
        dut.ipm.control_io_destMask_3_2,
        dut.ipm.control_io_destMask_3_1,
        dut.ipm.control_io_destMask_3_0
      };
    end
  endfunction

  function [3:0] probe_dmask4;
    begin
      probe_dmask4 = {
        dut.ipm.control_io_destMask_4_3,
        dut.ipm.control_io_destMask_4_2,
        dut.ipm.control_io_destMask_4_1,
        dut.ipm.control_io_destMask_4_0
      };
    end
  endfunction

  function [5:0] probe_holder;
    begin
      probe_holder = {
        dut.opm_io_holder_5[2:0] != 3'd6,
        dut.opm_io_holder_4[2:0] != 3'd6,
        dut.opm_io_holder_3[2:0] != 3'd6,
        dut.opm_io_holder_2[2:0] != 3'd6,
        dut.opm_io_holder_1[2:0] != 3'd6,
        dut.opm_io_holder_0[2:0] != 3'd6
      };
    end
  endfunction

  function [15:0] probe_edge_req;
    begin
      probe_edge_req = {
        dut.ipm_io_toOpm_27_HS_Req,
        dut.ipm_io_toOpm_26_HS_Req,
        dut.ipm_io_toOpm_25_HS_Req,
        dut.ipm_io_toOpm_24_HS_Req,
        dut.ipm_io_toOpm_23_HS_Req,
        dut.ipm_io_toOpm_22_HS_Req,
        dut.ipm_io_toOpm_21_HS_Req,
        dut.ipm_io_toOpm_20_HS_Req,
        dut.ipm_io_toOpm_19_HS_Req,
        dut.ipm_io_toOpm_18_HS_Req,
        dut.ipm_io_toOpm_5_HS_Req,
        dut.ipm_io_toOpm_4_HS_Req,
        dut.ipm_io_toOpm_3_HS_Req,
        dut.ipm_io_toOpm_2_HS_Req,
        dut.ipm_io_toOpm_1_HS_Req,
        dut.ipm_io_toOpm_0_HS_Req
      };
    end
  endfunction

  function [15:0] probe_edge_ack;
    begin
      probe_edge_ack = {
        dut.opm_io_fromIpm_27_HS_Ack,
        dut.opm_io_fromIpm_26_HS_Ack,
        dut.opm_io_fromIpm_25_HS_Ack,
        dut.opm_io_fromIpm_24_HS_Ack,
        dut.opm_io_fromIpm_23_HS_Ack,
        dut.opm_io_fromIpm_22_HS_Ack,
        dut.opm_io_fromIpm_21_HS_Ack,
        dut.opm_io_fromIpm_20_HS_Ack,
        dut.opm_io_fromIpm_19_HS_Ack,
        dut.opm_io_fromIpm_18_HS_Ack,
        dut.opm_io_fromIpm_5_HS_Ack,
        dut.opm_io_fromIpm_4_HS_Ack,
        dut.opm_io_fromIpm_3_HS_Ack,
        dut.opm_io_fromIpm_2_HS_Ack,
        dut.opm_io_fromIpm_1_HS_Ack,
        dut.opm_io_fromIpm_0_HS_Ack
      };
    end
  endfunction

  task probe_print_input;
    input integer p;
    input [27:0] flit;
    input [5:0] dmask;
    input [5:0] c0mask;
    input [5:0] c1mask;
    input [1:0] rx;
    input [1:0] rxid0;
    input [1:0] rxid1;
    begin
      if (gls_probe_enable) begin
        $display("GLS_PROBE_IN cyc=%0d t=%0t p=%0d flit=%h H=%0b T=%0b dmask=%b ctx0=%b ctx1=%b rx=%b rxid0=%0d rxid1=%0d holder=%b",
                 cycle_count, $time, p, flit, flit[27], flit[26], dmask,
                 c0mask, c1mask, rx, rxid0, rxid1, probe_holder());
      end
    end
  endtask
`endif

  initial forever #CLK_HALF_PERIOD_NS clock = ~clock;

  always @(posedge clock) begin
    if (reset) cycle_count <= 0;
    else cycle_count <= cycle_count + 1;
  end

  function is_blank_or_comment;
    input [STR_CHARS*8-1:0] line;
    reg [STR_CHARS*8-1:0] tag;
    begin
      tag = "";
      is_blank_or_comment = (($sscanf(line, "%s", tag) != 1) || (tag == "#"));
    end
  endfunction

  task load_case;
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
        case_file = "cases/smoke_directed.case";
      if (!$value$plusargs("CSV=%s", csv_file))
        csv_file = "summary/routerl1_func.csv";

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

      $display("TB_INFO case=%0s inputs=%0d expects=%0d timeout=%0d",
               case_name, input_count, expected_count, timeout_cycles);
    end
  endtask

  task sample_output;
    input integer p;
    integer i, pkt_seq, lat;
    reg found;
    reg [NUM_PORTS-1:0] port_bit;
    begin
      found = 1'b0;
      port_bit = 0;
      port_bit[p] = 1'b1;
      for (i = 0; i < expected_count; i = i + 1) begin
        if (!found && !expected_seen[i] && ((expected_mask[i] & port_bit) != 0) &&
            (expected_flit[i] === out_data[p])) begin
          expected_seen[i] = 1'b1;
          delivered_flits = delivered_flits + 1;
          found = 1'b1;
          $display("TB_MATCH cyc=%0d port=%0d flit=%h expect_idx=%0d",
                   cycle_count, p, out_data[p], i);
          if ((e2e_done == 0) && out_data[p][27]) begin
            t_dst_req = $realtime;
            e2e_done = 1;
            $display("E2E_NS=%.3f T_router=%.3f src_req=%.3f dst_req=%.3f",
                     t_dst_req - t_src_req, t_dst_req - t_src_req, t_src_req, t_dst_req);
          end
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
      if (!found) begin
        unexpected_flits = unexpected_flits + 1;
        $display("TB_UNEXPECT cyc=%0d port=%0d flit=%h req=%b ack=%b",
                 cycle_count, p, out_data[p], out_req[p], out_ack[p]);
      end
    end
  endtask

  function integer is_probe_flit;
    input [FLIT_W-1:0] data;
    begin
      is_probe_flit = (e2e_probe_flit_set != 0) && (data == e2e_probe_flit);
    end
  endfunction

  function real since_edge_in;
    input real t;
    begin
      since_edge_in = t - t_edge_in_req;
    end
  endfunction

  task maybe_note_input_edge;
    input integer port_id;
    begin
      if ((e2e_edge_probe != 0) && (edge_in_req_seen == 0) &&
          (port_id == e2e_src_port) && (is_probe_flit(in_data[port_id]) != 0)) begin
        t_edge_in_req = $realtime;
        edge_in_req_seen = 1;
        $display("E2E_PROBE_POINT name=top_input_req port=%0d t=%.3f flit=%h",
                 port_id, t_edge_in_req, in_data[port_id]);
      end
    end
  endtask

  task maybe_note_output_req_edge;
    input integer port_id;
    begin
      if ((e2e_edge_probe != 0) && (edge_in_req_seen != 0) &&
          (edge_out_req_seen == 0) && (port_id == e2e_dst_port) &&
          (out_req[port_id] !== out_ack[port_id]) && (is_probe_flit(out_data[port_id]) != 0)) begin
        t_edge_out_req = $realtime;
        edge_out_req_seen = 1;
        $display("E2E_PROBE_POINT name=top_output_req port=%0d t=%.3f delta=%.3f flit=%h",
                 port_id, t_edge_out_req, since_edge_in(t_edge_out_req), out_data[port_id]);
      end
    end
  endtask

  task maybe_note_output_valid;
    input integer port_id;
    begin
      if ((e2e_edge_probe != 0) && (edge_in_req_seen != 0) &&
          (edge_out_valid_seen == 0) && (port_id == e2e_dst_port) &&
          (out_req[port_id] !== out_ack[port_id]) && (is_probe_flit(out_data[port_id]) != 0)) begin
        t_edge_out_valid = $realtime;
        edge_out_valid_seen = 1;
        $display("E2E_PROBE_POINT name=top_output_valid port=%0d t=%.3f delta=%.3f flit=%h",
                 port_id, t_edge_out_valid, since_edge_in(t_edge_out_valid), out_data[port_id]);
      end
    end
  endtask

  task print_e2e_probe_summary;
    begin
      if (e2e_edge_probe != 0) begin
        if ((edge_in_req_seen != 0) && (edge_out_req_seen != 0))
          $display("E2E_EDGE_REQ_NS=%.3f src_edge=%.3f dst_req_edge=%.3f",
                   t_edge_out_req - t_edge_in_req, t_edge_in_req, t_edge_out_req);
        else
          $display("E2E_EDGE_REQ_NS=NA src_seen=%0d dst_req_seen=%0d",
                   edge_in_req_seen, edge_out_req_seen);

        if ((edge_in_req_seen != 0) && (edge_out_valid_seen != 0))
          $display("E2E_EDGE_VALID_NS=%.3f src_edge=%.3f dst_valid=%.3f",
                   t_edge_out_valid - t_edge_in_req, t_edge_in_req, t_edge_out_valid);
        else
          $display("E2E_EDGE_VALID_NS=NA src_seen=%0d dst_valid_seen=%0d",
                   edge_in_req_seen, edge_out_valid_seen);

        if (e2e_done != 0) begin
          $display("E2E_WRAPPED_NS=%.3f src_wrapped=%.3f dst_wrapped=%.3f",
                   t_dst_req - t_src_req, t_src_req, t_dst_req);
          if ((edge_in_req_seen != 0) && (edge_out_valid_seen != 0))
            $display("E2E_WRAPPER_OVERHEAD_NS=%.3f",
                     (t_dst_req - t_src_req) - (t_edge_out_valid - t_edge_in_req));
        end else begin
          $display("E2E_WRAPPED_NS=NA");
        end
      end
    end
  endtask

  genvar mon_port;
  generate
    for (mon_port = 0; mon_port < NUM_PORTS; mon_port = mon_port + 1) begin : gen_e2e_edge_mon
      always @(in_req[mon_port]) begin
        if (!reset) maybe_note_input_edge(mon_port);
      end
      always @(out_req[mon_port]) begin
        if (!reset) maybe_note_output_req_edge(mon_port);
      end
      always @(out_req[mon_port] or out_ack[mon_port] or out_data[mon_port]) begin
        if (!reset) maybe_note_output_valid(mon_port);
      end
    end
  endgenerate

  task write_csv_and_finish;
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
      pass_ok = (timeout_hit == 0) && (unexpected_flits == 0) && (missing == 0) &&
                (injected_flits == input_count);
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
        case_name, injected_packets, delivered_packets, injected_flits, delivered_flits,
        missing, unexpected_flits, timeout_hit, cycle_count, throughput, avg_lat,
        max_lat, p95_lat, p99_lat, pass_text
      );
      $fclose(fd_csv);

      $display(
        "TB_RESULT %0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d unexpected=%0d missing=%0d timeout=%0d",
        pass_text, case_name, injected_flits, delivered_flits, delivered_packets,
        unexpected_flits, missing, timeout_hit
      );
      if (e2e_done != 0)
        $display("E2E_NS=%.3f T_router=%.3f src_req=%.3f dst_req=%.3f",
                 t_dst_req - t_src_req, t_dst_req - t_src_req, t_src_req, t_dst_req);
      print_e2e_probe_summary();
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
        req_stable[p] <= 0;
        req_data_seen[p] <= {FLIT_W{1'bx}};
      end
    end else if (output_enable) begin
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        if (accept_pending[p]) begin
          if (ack_countdown[p] == 0) begin
            sample_output(p);
            out_ack[p] <= ~out_ack[p];
            accept_pending[p] <= 1'b0;
            ack_countdown[p] <= -1;
            req_stable[p] <= 0;
          end else if (ack_countdown[p] > 0) begin
            ack_countdown[p] <= ack_countdown[p] - 1;
          end
        end else if (out_req[p] !== out_ack[p]) begin
          // Wait for req+data to stay pending/stable so SDF bundled-data settles.
          if (out_data[p] !== req_data_seen[p]) begin
            req_data_seen[p] <= out_data[p];
            req_stable[p] <= 0;
          end else if (req_stable[p] + 1 >= REQ_STABLE_CYCLES) begin
            if (out_ack_delay_cycles == 0) begin
              sample_output(p);
              out_ack[p] <= ~out_ack[p];
              req_stable[p] <= 0;
            end else begin
              accept_pending[p] <= 1'b1;
              ack_countdown[p] <= out_ack_delay_cycles;
              req_stable[p] <= 0;
            end
          end else begin
            req_stable[p] <= req_stable[p] + 1;
          end
        end else begin
          req_stable[p] <= 0;
          req_data_seen[p] <= out_data[p];
        end
      end
    end
  end

`ifdef GLS_GATE_PROBE
  always @(posedge clock) begin : gls_probe_sample_proc
    if (reset) begin
      probe_prev_holder <= 0;
      probe_prev_edge_req <= 0;
      probe_prev_edge_ack <= 0;
      probe_prev_dmask0 <= 0;
      probe_prev_dmask3 <= 0;
      probe_prev_dmask4 <= 0;
    end else if (gls_probe_enable) begin
      if ((probe_holder() !== probe_prev_holder) ||
          (probe_edge_req() !== probe_prev_edge_req) ||
          (probe_edge_ack() !== probe_prev_edge_ack) ||
          (probe_dmask0() !== probe_prev_dmask0) ||
          (probe_dmask3() !== probe_prev_dmask3) ||
          (probe_dmask4() !== probe_prev_dmask4)) begin
        $display("GLS_PROBE_STATE cyc=%0d t=%0t holder=%b dmask0=%b dmask3=%b dmask4=%b edge_req=%h edge_ack=%h out_req=%b out_ack=%b",
                 cycle_count, $time, probe_holder(), probe_dmask0(),
                 probe_dmask3(), probe_dmask4(), probe_edge_req(),
                 probe_edge_ack(), out_req, out_ack);
      end
      probe_prev_holder <= probe_holder();
      probe_prev_edge_req <= probe_edge_req();
      probe_prev_edge_ack <= probe_edge_ack();
      probe_prev_dmask0 <= probe_dmask0();
      probe_prev_dmask3 <= probe_dmask3();
      probe_prev_dmask4 <= probe_dmask4();
    end
  end

  always @(posedge dut.ipm.inputPorts_0_datapath_io_launch) begin
    probe_print_input(
      0,
      dut.ipm.inputPorts_0_datapath_selector_outBuffer_io_inData_flit,
      probe_dmask0(),
      6'b0,
      6'b0,
      {
        dut.ipm.inputPorts_0_datapath_buffer_rxActive_1,
        dut.ipm.inputPorts_0_datapath_buffer_rxActive_0
      },
      dut.ipm.inputPorts_0_datapath_buffer_rxId_0,
      dut.ipm.inputPorts_0_datapath_buffer_rxId_1
    );
  end

  always @(in_req[0] or in_ack[0]) begin
    if (gls_probe_enable) begin
      $display("GLS_PROBE_EXT0 cyc=%0d t=%0t req=%0b ack=%0b data=%h H=%0b T=%0b rx=%b rxid0=%0d rxid1=%0d vcReq=%b vcAck=%b selAck=%b selOutReq=%0b reqGenAck=%0b dmask=%b holder=%b",
               cycle_count, $time, in_req[0], in_ack[0], in_data[0], in_data[0][27], in_data[0][26],
               {dut.ipm.inputPorts_0_datapath_buffer_rxActive_1, dut.ipm.inputPorts_0_datapath_buffer_rxActive_0},
               dut.ipm.inputPorts_0_datapath_buffer_rxId_0,
               dut.ipm.inputPorts_0_datapath_buffer_rxId_1,
               {dut.ipm.inputPorts_0_datapath_buffer_io_out_1_HS_Req, dut.ipm.inputPorts_0_datapath_buffer_io_out_0_HS_Req},
               {dut.ipm.inputPorts_0_datapath_buffer_buffers_1_io_in_HS_Ack, dut.ipm.inputPorts_0_datapath_buffer_buffers_0_io_in_HS_Ack},
               {dut.ipm.inputPorts_0_datapath_selector_io_in_1_HS_Ack, dut.ipm.inputPorts_0_datapath_selector_io_in_0_HS_Ack},
               dut.ipm.inputPorts_0_datapath_selector_io_out_HS_Req,
               dut.ipm.inputPorts_0_datapath_requestGen_io_in_HS_Ack,
               probe_dmask0(), probe_holder());
    end
  end

  always @(dut.ipm.inputPorts_0_datapath_buffer_demux_io_launch_clock) begin
    if (gls_probe_enable) begin
      $display("GLS_PROBE_DEMUX0 cyc=%0d t=%0t data=%h H=%0b T=%0b rx=%b rxid0=%0d rxid1=%0d demuxClk=%0b demuxReq=%b vcAck=%b dmask=%b",
               cycle_count, $time, in_data[0], in_data[0][27], in_data[0][26],
               {dut.ipm.inputPorts_0_datapath_buffer_rxActive_1, dut.ipm.inputPorts_0_datapath_buffer_rxActive_0},
               dut.ipm.inputPorts_0_datapath_buffer_rxId_0,
               dut.ipm.inputPorts_0_datapath_buffer_rxId_1,
               dut.ipm.inputPorts_0_datapath_buffer_demux_io_launch_clock,
               {dut.ipm.inputPorts_0_datapath_buffer_demux_io_out_1_HS_Req, dut.ipm.inputPorts_0_datapath_buffer_demux_io_out_0_HS_Req},
               {dut.ipm.inputPorts_0_datapath_buffer_buffers_1_io_in_HS_Ack, dut.ipm.inputPorts_0_datapath_buffer_buffers_0_io_in_HS_Ack},
               probe_dmask0());
    end
  end

  always @(dut.ipm.inputPorts_0_datapath_selector_io_fire_clock) begin
    if (gls_probe_enable) begin
      $display("GLS_PROBE_SELECTOR0 cyc=%0d t=%0t fireClk=%0b vcReq=%b selAck=%b outReq=%0b reqGenAck=%0b vc0=%h vc1=%h dmask=%b holder=%b",
               cycle_count, $time,
               dut.ipm.inputPorts_0_datapath_selector_io_fire_clock,
               {dut.ipm.inputPorts_0_datapath_buffer_io_out_1_HS_Req, dut.ipm.inputPorts_0_datapath_buffer_io_out_0_HS_Req},
               {dut.ipm.inputPorts_0_datapath_selector_io_in_1_HS_Ack, dut.ipm.inputPorts_0_datapath_selector_io_in_0_HS_Ack},
               dut.ipm.inputPorts_0_datapath_selector_io_out_HS_Req,
               dut.ipm.inputPorts_0_datapath_requestGen_io_in_HS_Ack,
               dut.ipm.inputPorts_0_datapath_buffer_io_out_0_Data_flit,
               dut.ipm.inputPorts_0_datapath_buffer_io_out_1_Data_flit,
               probe_dmask0(), probe_holder());
    end
  end

  always @(posedge dut.ipm.inputPorts_3_datapath_io_launch) begin
    probe_print_input(
      3,
      dut.ipm.inputPorts_3_datapath_selector_outBuffer_io_inData_flit,
      probe_dmask3(),
      6'b0,
      6'b0,
      {
        dut.ipm.inputPorts_3_datapath_buffer_rxActive_1,
        dut.ipm.inputPorts_3_datapath_buffer_rxActive_0
      },
      dut.ipm.inputPorts_3_datapath_buffer_rxId_0,
      dut.ipm.inputPorts_3_datapath_buffer_rxId_1
    );
  end

  always @(posedge dut.ipm.inputPorts_4_datapath_io_launch) begin
    probe_print_input(
      4,
      dut.ipm.inputPorts_4_datapath_selector_outBuffer_io_inData_flit,
      {2'b00, probe_dmask4()},
      6'b0,
      6'b0,
      {
        dut.ipm.inputPorts_4_datapath_buffer_rxActive_1,
        dut.ipm.inputPorts_4_datapath_buffer_rxActive_0
      },
      dut.ipm.inputPorts_4_datapath_buffer_rxId_0,
      dut.ipm.inputPorts_4_datapath_buffer_rxId_1
    );
  end

  always @(posedge dut.opm.outputPorts_0_requestSelector_io_fireClock)
    if (gls_probe_enable) $display("GLS_PROBE_OPM_FIRE cyc=%0d t=%0t out=0 holder0=%0d req=%0b ack=%0b data=%h", cycle_count, $time, dut.opm_io_holder_0, out_req[0], out_ack[0], out_data[0]);
  always @(posedge dut.opm.outputPorts_3_requestSelector_io_fireClock)
    if (gls_probe_enable) $display("GLS_PROBE_OPM_FIRE cyc=%0d t=%0t out=3 holder3=%0d req=%0b ack=%0b data=%h", cycle_count, $time, dut.opm_io_holder_3, out_req[3], out_ack[3], out_data[3]);
  always @(posedge dut.opm.outputPorts_4_requestSelector_io_fireClock)
    if (gls_probe_enable) $display("GLS_PROBE_OPM_FIRE cyc=%0d t=%0t out=4 holder4=%0d req=%0b ack=%0b data=%h", cycle_count, $time, dut.opm_io_holder_4, out_req[4], out_ack[4], out_data[4]);

  // Pulse-width monitors for 1x DEL250 experiment (ns via $realtime).
  realtime pw_demux_last = 0;
  realtime pw_sel_last = 0;
  realtime pw_opm4_last = 0;
  reg pw_demux_lvl = 1'bx;
  reg pw_sel_lvl = 1'bx;
  reg pw_opm4_lvl = 1'bx;

  always @(dut.ipm.inputPorts_0_datapath_buffer_demux_io_launch_clock) begin
    if (gls_probe_enable && !reset) begin
      if (pw_demux_lvl !== 1'bx) begin
        if (pw_demux_lvl === 1'b1)
          $display("GLS_PW name=demux0_launchClk high_ns=%.4f t=%0t", $realtime - pw_demux_last, $time);
        else
          $display("GLS_PW name=demux0_launchClk low_ns=%.4f t=%0t", $realtime - pw_demux_last, $time);
      end
      pw_demux_lvl = dut.ipm.inputPorts_0_datapath_buffer_demux_io_launch_clock;
      pw_demux_last = $realtime;
    end
  end

  always @(dut.ipm.inputPorts_0_datapath_selector_io_fire_clock) begin
    if (gls_probe_enable && !reset) begin
      if (pw_sel_lvl !== 1'bx) begin
        if (pw_sel_lvl === 1'b1)
          $display("GLS_PW name=sel0_fireClk high_ns=%.4f t=%0t", $realtime - pw_sel_last, $time);
        else
          $display("GLS_PW name=sel0_fireClk low_ns=%.4f t=%0t", $realtime - pw_sel_last, $time);
      end
      pw_sel_lvl = dut.ipm.inputPorts_0_datapath_selector_io_fire_clock;
      pw_sel_last = $realtime;
    end
  end

  always @(dut.opm.outputPorts_4_requestSelector_io_fireClock) begin
    if (gls_probe_enable && !reset) begin
      if (pw_opm4_lvl !== 1'bx) begin
        if (pw_opm4_lvl === 1'b1)
          $display("GLS_PW name=opm4_fireClk high_ns=%.4f t=%0t", $realtime - pw_opm4_last, $time);
        else
          $display("GLS_PW name=opm4_fireClk low_ns=%.4f t=%0t", $realtime - pw_opm4_last, $time);
      end
      pw_opm4_lvl = dut.opm.outputPorts_4_requestSelector_io_fireClock;
      pw_opm4_last = $realtime;
    end
  end
`endif

  initial begin : main_proc
    integer p, i, drain_cycle, inj, wait_guard;
    integer sorted_idx [0:MAX_INPUT_FLITS-1];
    integer tmp_i, a, b;
    integer inject_base;
    reset = 1'b1;
    output_enable = 0;
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
    e2e_done = 0;
    e2e_src_set = 0;
    t_src_req = 0.0;
    t_dst_req = 0.0;
    e2e_edge_probe = 0;
    e2e_src_port = 0;
    e2e_dst_port = 4;
    e2e_probe_flit_set = 0;
    e2e_probe_flit = {FLIT_W{1'b0}};
    edge_in_req_seen = 0;
    edge_out_req_seen = 0;
    edge_out_valid_seen = 0;
    t_edge_in_req = 0.0;
    t_edge_out_req = 0.0;
    t_edge_out_valid = 0.0;
    gls_probe_enable = 0;
    if ($value$plusargs("GLS_PROBE=%d", gls_probe_enable) && gls_probe_enable)
      $display("TB_INFO GLS gate probe enabled");
    void'($value$plusargs("E2E_EDGE_PROBE=%d", e2e_edge_probe));
    void'($value$plusargs("E2E_SRC_PORT=%d", e2e_src_port));
    void'($value$plusargs("E2E_DST_PORT=%d", e2e_dst_port));
    // SDF annotate (if any) is done by companion sdf_boot module from run_gls_smoke.sh

    for (p = 0; p < NUM_PORTS; p = p + 1) begin
      in_data[p] = 0;
      ack_countdown[p] = -1;
      accept_pending[p] = 1'b0;
      req_stable[p] = 0;
    end
    for (i = 0; i < MAX_EXPECT_FLITS; i = i + 1) expected_seen[i] = 1'b0;
    for (i = 0; i < MAX_PKT_SEQ; i = i + 1) packet_head_cycle[i] = -1;

    load_case();
    if (e2e_edge_probe != 0) begin
      for (i = 0; i < input_count; i = i + 1) begin
        if ((e2e_probe_flit_set == 0) && (input_port[i] == e2e_src_port) &&
            input_flit[i][27]) begin
          e2e_probe_flit = input_flit[i];
          e2e_probe_flit_set = 1;
        end
      end
      $display("TB_INFO E2E_EDGE_PROBE enabled src=%0d dst=%0d flit_set=%0d flit=%h",
               e2e_src_port, e2e_dst_port, e2e_probe_flit_set, e2e_probe_flit);
    end

    // sort inputs by cycle (stable enough for smoke)
    for (i = 0; i < input_count; i = i + 1) sorted_idx[i] = i;
    for (a = 0; a < input_count; a = a + 1) begin
      for (b = a + 1; b < input_count; b = b + 1) begin
        if (input_cycle[sorted_idx[b]] < input_cycle[sorted_idx[a]]) begin
          tmp_i = sorted_idx[a];
          sorted_idx[a] = sorted_idx[b];
          sorted_idx[b] = tmp_i;
        end
      end
    end

    repeat (reset_cycles) @(posedge clock);
    reset = 1'b0;
    // Absorb gate-level handshake glitches after reset (align ack to req, no sample)
    repeat (100) begin
      @(posedge clock);
      out_ack <= out_req;
    end
    output_enable = 1;
    @(posedge clock);
    inject_base = cycle_count;

    for (inj = 0; inj < input_count; inj = inj + 1) begin
      i = sorted_idx[inj];
      p = input_port[i];
      // relative schedule from start of inject window
      while ((cycle_count - inject_base) < input_cycle[i]) @(posedge clock);

      wait_guard = 0;
      while (in_req[p] !== in_ack[p]) begin
        @(posedge clock);
        wait_guard = wait_guard + 1;
        if (wait_guard > timeout_cycles) begin
          $display("TB_FATAL inject wait-empty timeout port=%0d idx=%0d", p, i);
          timeout_hit = 1;
          write_csv_and_finish();
        end
      end

      in_data[p] = input_flit[i];
      #1;
      in_req[p] = ~in_req[p];
      $display("TB_INJECT cyc=%0d port=%0d flit=%h pkt=%0d",
               cycle_count, p, input_flit[i], input_pkt_seq[i]);
      if (input_flit[i][27] && (e2e_src_set == 0)) begin
        t_src_req = $realtime;
        e2e_src_set = 1;
      end

      wait_guard = 0;
      while (in_req[p] !== in_ack[p]) begin
        @(posedge clock);
        wait_guard = wait_guard + 1;
        if (wait_guard > timeout_cycles) begin
          $display("TB_FATAL inject wait-ack timeout port=%0d idx=%0d", p, i);
          timeout_hit = 1;
          write_csv_and_finish();
        end
      end

      injected_flits = injected_flits + 1;
      if (input_flit[i][27]) begin
        injected_packets = injected_packets + 1;
        if ((input_pkt_seq[i] >= 0) && (input_pkt_seq[i] < MAX_PKT_SEQ) &&
            (packet_head_cycle[input_pkt_seq[i]] < 0))
          packet_head_cycle[input_pkt_seq[i]] = cycle_count;
      end
    end

    drain_cycle = 0;
    while ((delivered_flits < expected_count) && (drain_cycle < timeout_cycles) &&
           (test_done == 0)) begin
      @(posedge clock);
      drain_cycle = drain_cycle + 1;
    end
    if ((delivered_flits < expected_count) && (test_done == 0)) begin
      timeout_hit = 1;
      $display("TB_TIMEOUT case=%0s timeout_cycles=%0d injected_flits=%0d delivered_flits=%0d expected_flits=%0d",
               case_name, timeout_cycles, injected_flits, delivered_flits, expected_count);
    end
    if (test_done == 0) write_csv_and_finish();
  end

  RouterL1 dut (
    .clock                          (clock),
    .reset                          (reset),
    .io_inputs_child_0_0_HS_Req     (in_req[0]),
    .io_inputs_child_0_0_HS_Ack     (in_ack[0]),
    .io_inputs_child_0_0_Data_flit  (in_data[0]),
    .io_inputs_child_1_0_HS_Req     (in_req[1]),
    .io_inputs_child_1_0_HS_Ack     (in_ack[1]),
    .io_inputs_child_1_0_Data_flit  (in_data[1]),
    .io_inputs_child_2_0_HS_Req     (in_req[2]),
    .io_inputs_child_2_0_HS_Ack     (in_ack[2]),
    .io_inputs_child_2_0_Data_flit  (in_data[2]),
    .io_inputs_child_3_0_HS_Req     (in_req[3]),
    .io_inputs_child_3_0_HS_Ack     (in_ack[3]),
    .io_inputs_child_3_0_Data_flit  (in_data[3]),
    .io_inputs_parent_0_HS_Req      (in_req[4]),
    .io_inputs_parent_0_HS_Ack      (in_ack[4]),
    .io_inputs_parent_0_Data_flit   (in_data[4]),
    .io_inputs_parent_1_HS_Req      (in_req[5]),
    .io_inputs_parent_1_HS_Ack      (in_ack[5]),
    .io_inputs_parent_1_Data_flit   (in_data[5]),
    .io_outputs_child_0_0_HS_Req    (out_req[0]),
    .io_outputs_child_0_0_HS_Ack    (out_ack[0]),
    .io_outputs_child_0_0_Data_flit (out_data[0]),
    .io_outputs_child_1_0_HS_Req    (out_req[1]),
    .io_outputs_child_1_0_HS_Ack    (out_ack[1]),
    .io_outputs_child_1_0_Data_flit (out_data[1]),
    .io_outputs_child_2_0_HS_Req    (out_req[2]),
    .io_outputs_child_2_0_HS_Ack    (out_ack[2]),
    .io_outputs_child_2_0_Data_flit (out_data[2]),
    .io_outputs_child_3_0_HS_Req    (out_req[3]),
    .io_outputs_child_3_0_HS_Ack    (out_ack[3]),
    .io_outputs_child_3_0_Data_flit (out_data[3]),
    .io_outputs_parent_0_HS_Req     (out_req[4]),
    .io_outputs_parent_0_HS_Ack     (out_ack[4]),
    .io_outputs_parent_0_Data_flit  (out_data[4]),
    .io_outputs_parent_1_HS_Req     (out_req[5]),
    .io_outputs_parent_1_HS_Ack     (out_ack[5]),
    .io_outputs_parent_1_Data_flit  (out_data[5])
  );
endmodule

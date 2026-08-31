`default_nettype none
`timescale 1ns/1ps
// No-SDF gate-level functional TB for NoC_16nodes.
// Case protocol matches sim/AsyncNoC/testbench/tb_noc16_async.sv.
// NoC16 GLS TB. Supports +CASE= / +CASE_FILE= / +CSV= / +DUMP_VCD=.
// Optional +E2E_EDGE_PROBE=1 measures DUT boundary edges without wrapper quantization.
module tb_gls_noc16_func;
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = 20;
  localparam integer MAX_INPUT_FLITS = 131072;
  localparam integer MAX_EXPECT_FLITS = 262144;
  localparam integer MAX_RX_FLITS = NUM_PORTS * 8192;
  localparam integer MAX_PKT_SEQ = 262144;
  localparam integer RESET_CYCLES = 20;
  localparam integer RUN_TIMEOUT_CYCLES = 5000000;
  localparam real CLOCK_PERIOD_NS = 10.0;

  reg clock;
  reg reset;

  wire in_req [0:NUM_PORTS-1];
  wire in_ack [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] in_data [0:NUM_PORTS-1];
  wire out_req [0:NUM_PORTS-1];
  wire out_ack [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] out_data [0:NUM_PORTS-1];

  reg send_pulse [0:NUM_PORTS-1];
  reg [FLIT_W-1:0] send_data [0:NUM_PORTS-1];
  wire sender_busy [0:NUM_PORTS-1];
  wire got_pulse [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] got_data [0:NUM_PORTS-1];
  reg port_issued [0:NUM_PORTS-1];

  NoC_16nodes dut (
    .clock(clock),
    .reset(reset),
    .io_core_inputs_0_HS_Req(in_req[0]),
    .io_core_inputs_0_HS_Ack(in_ack[0]),
    .io_core_inputs_0_Data_flit(in_data[0]),
    .io_core_inputs_1_HS_Req(in_req[1]),
    .io_core_inputs_1_HS_Ack(in_ack[1]),
    .io_core_inputs_1_Data_flit(in_data[1]),
    .io_core_inputs_2_HS_Req(in_req[2]),
    .io_core_inputs_2_HS_Ack(in_ack[2]),
    .io_core_inputs_2_Data_flit(in_data[2]),
    .io_core_inputs_3_HS_Req(in_req[3]),
    .io_core_inputs_3_HS_Ack(in_ack[3]),
    .io_core_inputs_3_Data_flit(in_data[3]),
    .io_core_inputs_4_HS_Req(in_req[4]),
    .io_core_inputs_4_HS_Ack(in_ack[4]),
    .io_core_inputs_4_Data_flit(in_data[4]),
    .io_core_inputs_5_HS_Req(in_req[5]),
    .io_core_inputs_5_HS_Ack(in_ack[5]),
    .io_core_inputs_5_Data_flit(in_data[5]),
    .io_core_inputs_6_HS_Req(in_req[6]),
    .io_core_inputs_6_HS_Ack(in_ack[6]),
    .io_core_inputs_6_Data_flit(in_data[6]),
    .io_core_inputs_7_HS_Req(in_req[7]),
    .io_core_inputs_7_HS_Ack(in_ack[7]),
    .io_core_inputs_7_Data_flit(in_data[7]),
    .io_core_inputs_8_HS_Req(in_req[8]),
    .io_core_inputs_8_HS_Ack(in_ack[8]),
    .io_core_inputs_8_Data_flit(in_data[8]),
    .io_core_inputs_9_HS_Req(in_req[9]),
    .io_core_inputs_9_HS_Ack(in_ack[9]),
    .io_core_inputs_9_Data_flit(in_data[9]),
    .io_core_inputs_10_HS_Req(in_req[10]),
    .io_core_inputs_10_HS_Ack(in_ack[10]),
    .io_core_inputs_10_Data_flit(in_data[10]),
    .io_core_inputs_11_HS_Req(in_req[11]),
    .io_core_inputs_11_HS_Ack(in_ack[11]),
    .io_core_inputs_11_Data_flit(in_data[11]),
    .io_core_inputs_12_HS_Req(in_req[12]),
    .io_core_inputs_12_HS_Ack(in_ack[12]),
    .io_core_inputs_12_Data_flit(in_data[12]),
    .io_core_inputs_13_HS_Req(in_req[13]),
    .io_core_inputs_13_HS_Ack(in_ack[13]),
    .io_core_inputs_13_Data_flit(in_data[13]),
    .io_core_inputs_14_HS_Req(in_req[14]),
    .io_core_inputs_14_HS_Ack(in_ack[14]),
    .io_core_inputs_14_Data_flit(in_data[14]),
    .io_core_inputs_15_HS_Req(in_req[15]),
    .io_core_inputs_15_HS_Ack(in_ack[15]),
    .io_core_inputs_15_Data_flit(in_data[15]),
    .io_top_input_0_HS_Req(in_req[16]),
    .io_top_input_0_HS_Ack(in_ack[16]),
    .io_top_input_0_Data_flit(in_data[16]),
    .io_top_input_1_HS_Req(in_req[17]),
    .io_top_input_1_HS_Ack(in_ack[17]),
    .io_top_input_1_Data_flit(in_data[17]),
    .io_top_input_2_HS_Req(in_req[18]),
    .io_top_input_2_HS_Ack(in_ack[18]),
    .io_top_input_2_Data_flit(in_data[18]),
    .io_top_input_3_HS_Req(in_req[19]),
    .io_top_input_3_HS_Ack(in_ack[19]),
    .io_top_input_3_Data_flit(in_data[19]),
    .io_top_output_0_HS_Req(out_req[16]),
    .io_top_output_0_HS_Ack(out_ack[16]),
    .io_top_output_0_Data_flit(out_data[16]),
    .io_top_output_1_HS_Req(out_req[17]),
    .io_top_output_1_HS_Ack(out_ack[17]),
    .io_top_output_1_Data_flit(out_data[17]),
    .io_top_output_2_HS_Req(out_req[18]),
    .io_top_output_2_HS_Ack(out_ack[18]),
    .io_top_output_2_Data_flit(out_data[18]),
    .io_top_output_3_HS_Req(out_req[19]),
    .io_top_output_3_HS_Ack(out_ack[19]),
    .io_top_output_3_Data_flit(out_data[19]),
    .io_core_outputs_0_HS_Req(out_req[0]),
    .io_core_outputs_0_HS_Ack(out_ack[0]),
    .io_core_outputs_0_Data_flit(out_data[0]),
    .io_core_outputs_1_HS_Req(out_req[1]),
    .io_core_outputs_1_HS_Ack(out_ack[1]),
    .io_core_outputs_1_Data_flit(out_data[1]),
    .io_core_outputs_2_HS_Req(out_req[2]),
    .io_core_outputs_2_HS_Ack(out_ack[2]),
    .io_core_outputs_2_Data_flit(out_data[2]),
    .io_core_outputs_3_HS_Req(out_req[3]),
    .io_core_outputs_3_HS_Ack(out_ack[3]),
    .io_core_outputs_3_Data_flit(out_data[3]),
    .io_core_outputs_4_HS_Req(out_req[4]),
    .io_core_outputs_4_HS_Ack(out_ack[4]),
    .io_core_outputs_4_Data_flit(out_data[4]),
    .io_core_outputs_5_HS_Req(out_req[5]),
    .io_core_outputs_5_HS_Ack(out_ack[5]),
    .io_core_outputs_5_Data_flit(out_data[5]),
    .io_core_outputs_6_HS_Req(out_req[6]),
    .io_core_outputs_6_HS_Ack(out_ack[6]),
    .io_core_outputs_6_Data_flit(out_data[6]),
    .io_core_outputs_7_HS_Req(out_req[7]),
    .io_core_outputs_7_HS_Ack(out_ack[7]),
    .io_core_outputs_7_Data_flit(out_data[7]),
    .io_core_outputs_8_HS_Req(out_req[8]),
    .io_core_outputs_8_HS_Ack(out_ack[8]),
    .io_core_outputs_8_Data_flit(out_data[8]),
    .io_core_outputs_9_HS_Req(out_req[9]),
    .io_core_outputs_9_HS_Ack(out_ack[9]),
    .io_core_outputs_9_Data_flit(out_data[9]),
    .io_core_outputs_10_HS_Req(out_req[10]),
    .io_core_outputs_10_HS_Ack(out_ack[10]),
    .io_core_outputs_10_Data_flit(out_data[10]),
    .io_core_outputs_11_HS_Req(out_req[11]),
    .io_core_outputs_11_HS_Ack(out_ack[11]),
    .io_core_outputs_11_Data_flit(out_data[11]),
    .io_core_outputs_12_HS_Req(out_req[12]),
    .io_core_outputs_12_HS_Ack(out_ack[12]),
    .io_core_outputs_12_Data_flit(out_data[12]),
    .io_core_outputs_13_HS_Req(out_req[13]),
    .io_core_outputs_13_HS_Ack(out_ack[13]),
    .io_core_outputs_13_Data_flit(out_data[13]),
    .io_core_outputs_14_HS_Req(out_req[14]),
    .io_core_outputs_14_HS_Ack(out_ack[14]),
    .io_core_outputs_14_Data_flit(out_data[14]),
    .io_core_outputs_15_HS_Req(out_req[15]),
    .io_core_outputs_15_HS_Ack(out_ack[15]),
    .io_core_outputs_15_Data_flit(out_data[15])
  );

  genvar pj;
  generate
    for (pj = 0; pj < NUM_PORTS; pj = pj + 1) begin : gen_ports
      async_hs_sender #(.FLIT_W(FLIT_W)) u_sender (
        .clk(clock),
        .rst(reset),
        .req(in_req[pj]),
        .ack(in_ack[pj]),
        .data(in_data[pj]),
        .send_pulse(send_pulse[pj]),
        .send_data(send_data[pj]),
        .busy(sender_busy[pj])
      );
      async_hs_receiver #(.FLIT_W(FLIT_W)) u_receiver (
        .clk(clock),
        .rst(reset),
        .req(out_req[pj]),
        .ack(out_ack[pj]),
        .data(out_data[pj]),
        .got_pulse(got_pulse[pj]),
        .got_data(got_data[pj])
      );
    end
  endgenerate

  integer input_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];
  reg input_sent [0:MAX_INPUT_FLITS-1];

  integer expected_count;
  reg [NUM_PORTS-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];

  integer rx_count;
  integer rx_port [0:MAX_RX_FLITS-1];
  reg [FLIT_W-1:0] rx_flit [0:MAX_RX_FLITS-1];
  integer rx_cycle [0:MAX_RX_FLITS-1];

  integer packet_head_cycle [0:MAX_PKT_SEQ-1];
  integer latency_samples [0:MAX_EXPECT_FLITS-1];

  reg [1023:0] case_file;
  reg [1023:0] csv_file;
  reg [1023:0] dump_vcd_file;
  reg [1023:0] case_name;
  reg [1023:0] case_group;
  integer cycle_counter;
  integer inject_idx;
  integer pass_count;
  integer fail_count;
  integer unexpected_count;
  integer injected_flits;
  integer delivered_flits;
  integer injected_packets;
  integer delivered_packets;
  integer latency_count;
  integer timeout_hit;
  integer rx_overflow;
  integer i;
  integer p;
  integer e;
  integer matched;
  integer final_cycle;
  integer case_timeout;
  integer timeout_scale;
  integer drain_limit;
  integer stall_probe;
  integer stall_window_cycles;
  integer stall_window_count;
  integer stall_prev_injected;
  integer stall_prev_rx;
  integer stall_quiet_windows;
  real t_src_req;
  real t_dst_req;
  integer e2e_done;
  integer e2e_src_set;
  integer dump_vcd_enable;
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

`ifdef NOC16_ROUTE_PROBE
  real t_seg_l1_src_parent_0;
  real t_seg_l1_src_parent_1;
  real t_seg_l2_in_child_3_0;
  real t_seg_l2_in_child_3_1;
  real t_seg_l2_out_child_0_0;
  real t_seg_l2_out_child_0_1;
  real t_seg_l1_dst_parent_0;
  real t_seg_l1_dst_parent_1;
  real t_seg_l1_dst_child_0;
  integer seg_l1_src_parent_0_seen;
  integer seg_l1_src_parent_1_seen;
  integer seg_l2_in_child_3_0_seen;
  integer seg_l2_in_child_3_1_seen;
  integer seg_l2_out_child_0_0_seen;
  integer seg_l2_out_child_0_1_seen;
  integer seg_l1_dst_parent_0_seen;
  integer seg_l1_dst_parent_1_seen;
  integer seg_l1_dst_child_0_seen;
`endif

  initial clock = 1'b0;
  always #5 clock = ~clock;

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

`ifdef NOC16_ROUTE_PROBE
  task maybe_note_segment;
    input [1023:0] name;
    input integer seen;
    input [FLIT_W-1:0] data;
    begin
      if ((e2e_edge_probe != 0) && (edge_in_req_seen != 0) &&
          (seen == 0) && (is_probe_flit(data) != 0)) begin
        $display("E2E_SEG name=%0s t=%.3f delta=%.3f flit=%h",
                 name, $realtime, since_edge_in($realtime), data);
      end
    end
  endtask

  always @(dut.routerl1_0_0_io_outputs_parent_0_HS_Req or dut.routerl1_0_0_io_outputs_parent_0_Data_flit) begin
    if (!reset && (dut.routerl1_0_0_io_outputs_parent_0_HS_Req !== dut.routerl1_0_0_io_outputs_parent_0_HS_Ack)) begin
      maybe_note_segment("l1_src.outputs.parent_0", seg_l1_src_parent_0_seen, dut.routerl1_0_0_io_outputs_parent_0_Data_flit);
      if ((seg_l1_src_parent_0_seen == 0) && (is_probe_flit(dut.routerl1_0_0_io_outputs_parent_0_Data_flit) != 0)) begin
        t_seg_l1_src_parent_0 = $realtime; seg_l1_src_parent_0_seen = 1;
      end
    end
  end

  always @(dut.routerl1_0_0_io_outputs_parent_1_HS_Req or dut.routerl1_0_0_io_outputs_parent_1_Data_flit) begin
    if (!reset && (dut.routerl1_0_0_io_outputs_parent_1_HS_Req !== dut.routerl1_0_0_io_outputs_parent_1_HS_Ack)) begin
      maybe_note_segment("l1_src.outputs.parent_1", seg_l1_src_parent_1_seen, dut.routerl1_0_0_io_outputs_parent_1_Data_flit);
      if ((seg_l1_src_parent_1_seen == 0) && (is_probe_flit(dut.routerl1_0_0_io_outputs_parent_1_Data_flit) != 0)) begin
        t_seg_l1_src_parent_1 = $realtime; seg_l1_src_parent_1_seen = 1;
      end
    end
  end

  always @(dut.routerl2_io_inputs_child_3_0_HS_Req or dut.routerl2_io_inputs_child_3_0_Data_flit) begin
    if (!reset && (dut.routerl2_io_inputs_child_3_0_HS_Req !== dut.routerl2_io_inputs_child_3_0_HS_Ack)) begin
      maybe_note_segment("l2.inputs.child_3_0", seg_l2_in_child_3_0_seen, dut.routerl2_io_inputs_child_3_0_Data_flit);
      if ((seg_l2_in_child_3_0_seen == 0) && (is_probe_flit(dut.routerl2_io_inputs_child_3_0_Data_flit) != 0)) begin
        t_seg_l2_in_child_3_0 = $realtime; seg_l2_in_child_3_0_seen = 1;
      end
    end
  end

  always @(dut.routerl2_io_inputs_child_3_1_HS_Req or dut.routerl2_io_inputs_child_3_1_Data_flit) begin
    if (!reset && (dut.routerl2_io_inputs_child_3_1_HS_Req !== dut.routerl2_io_inputs_child_3_1_HS_Ack)) begin
      maybe_note_segment("l2.inputs.child_3_1", seg_l2_in_child_3_1_seen, dut.routerl2_io_inputs_child_3_1_Data_flit);
      if ((seg_l2_in_child_3_1_seen == 0) && (is_probe_flit(dut.routerl2_io_inputs_child_3_1_Data_flit) != 0)) begin
        t_seg_l2_in_child_3_1 = $realtime; seg_l2_in_child_3_1_seen = 1;
      end
    end
  end

  always @(dut.routerl2_io_outputs_child_0_0_HS_Req or dut.routerl2_io_outputs_child_0_0_Data_flit) begin
    if (!reset && (dut.routerl2_io_outputs_child_0_0_HS_Req !== dut.routerl2_io_outputs_child_0_0_HS_Ack)) begin
      maybe_note_segment("l2.outputs.child_0_0", seg_l2_out_child_0_0_seen, dut.routerl2_io_outputs_child_0_0_Data_flit);
      if ((seg_l2_out_child_0_0_seen == 0) && (is_probe_flit(dut.routerl2_io_outputs_child_0_0_Data_flit) != 0)) begin
        t_seg_l2_out_child_0_0 = $realtime; seg_l2_out_child_0_0_seen = 1;
      end
    end
  end

  always @(dut.routerl2_io_outputs_child_0_1_HS_Req or dut.routerl2_io_outputs_child_0_1_Data_flit) begin
    if (!reset && (dut.routerl2_io_outputs_child_0_1_HS_Req !== dut.routerl2_io_outputs_child_0_1_HS_Ack)) begin
      maybe_note_segment("l2.outputs.child_0_1", seg_l2_out_child_0_1_seen, dut.routerl2_io_outputs_child_0_1_Data_flit);
      if ((seg_l2_out_child_0_1_seen == 0) && (is_probe_flit(dut.routerl2_io_outputs_child_0_1_Data_flit) != 0)) begin
        t_seg_l2_out_child_0_1 = $realtime; seg_l2_out_child_0_1_seen = 1;
      end
    end
  end

  always @(dut.routerl1_1_1_io_inputs_parent_0_HS_Req or dut.routerl1_1_1_io_inputs_parent_0_Data_flit) begin
    if (!reset && (dut.routerl1_1_1_io_inputs_parent_0_HS_Req !== dut.routerl1_1_1_io_inputs_parent_0_HS_Ack)) begin
      maybe_note_segment("l1_dst.inputs.parent_0", seg_l1_dst_parent_0_seen, dut.routerl1_1_1_io_inputs_parent_0_Data_flit);
      if ((seg_l1_dst_parent_0_seen == 0) && (is_probe_flit(dut.routerl1_1_1_io_inputs_parent_0_Data_flit) != 0)) begin
        t_seg_l1_dst_parent_0 = $realtime; seg_l1_dst_parent_0_seen = 1;
      end
    end
  end

  always @(dut.routerl1_1_1_io_inputs_parent_1_HS_Req or dut.routerl1_1_1_io_inputs_parent_1_Data_flit) begin
    if (!reset && (dut.routerl1_1_1_io_inputs_parent_1_HS_Req !== dut.routerl1_1_1_io_inputs_parent_1_HS_Ack)) begin
      maybe_note_segment("l1_dst.inputs.parent_1", seg_l1_dst_parent_1_seen, dut.routerl1_1_1_io_inputs_parent_1_Data_flit);
      if ((seg_l1_dst_parent_1_seen == 0) && (is_probe_flit(dut.routerl1_1_1_io_inputs_parent_1_Data_flit) != 0)) begin
        t_seg_l1_dst_parent_1 = $realtime; seg_l1_dst_parent_1_seen = 1;
      end
    end
  end

  always @(dut.routerl1_1_1_io_outputs_child_0_0_HS_Req or dut.routerl1_1_1_io_outputs_child_0_0_Data_flit) begin
    if (!reset && (dut.routerl1_1_1_io_outputs_child_0_0_HS_Req !== dut.routerl1_1_1_io_outputs_child_0_0_HS_Ack)) begin
      maybe_note_segment("l1_dst.outputs.child_0_0", seg_l1_dst_child_0_seen, dut.routerl1_1_1_io_outputs_child_0_0_Data_flit);
      if ((seg_l1_dst_child_0_seen == 0) && (is_probe_flit(dut.routerl1_1_1_io_outputs_child_0_0_Data_flit) != 0)) begin
        t_seg_l1_dst_child_0 = $realtime; seg_l1_dst_child_0_seen = 1;
      end
    end
  end
`endif

  task load_case;
    input [1023:0] path;
    integer fd;
    integer line_no;
    integer tmp;
    reg [1023:0] line;
    reg [1023:0] tag;
    integer cyc;
    integer pkt_seq;
    reg [FLIT_W-1:0] flit;
    reg [31:0] mask;
    begin
      input_count = 0;
      expected_count = 0;
      case_name = "unnamed";
      case_group = "misc";
      case_timeout = RUN_TIMEOUT_CYCLES;
      fd = $fopen(path, "r");
      if (fd == 0) begin
        $display("TB_FATAL cannot open case file: %0s", path);
        $finish;
      end
      line_no = 0;
      while (!$feof(fd)) begin
        if ($fgets(line, fd) != 0) begin
          line_no = line_no + 1;
          if ($sscanf(line, "%s", tag) != 1) begin
          end else if (tag == "#") begin
          end else if (tag == "case") begin
            if ($sscanf(line, "%s %s", tag, case_name) != 2) begin
              $display("TB_FATAL malformed case at line %0d", line_no);
              $finish;
            end
          end else if (tag == "group") begin
            if ($sscanf(line, "%s %s", tag, case_group) != 2) begin
              $display("TB_FATAL malformed group at line %0d", line_no);
              $finish;
            end
          end else if (tag == "timeout_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) == 2) case_timeout = tmp;
          end else if (tag == "reset_cycles") begin
            // accepted, RESET_CYCLES localparam used for reset length
          end else if (tag == "out_ack_delay_cycles") begin
          end else if (tag == "event_map") begin
          end else if (tag == "input") begin
            if ($sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt_seq, flit) != 5) begin
              $display("TB_FATAL malformed input at line %0d", line_no);
              $finish;
            end
            if ((input_count >= MAX_INPUT_FLITS) || (p < 0) || (p >= NUM_PORTS)) begin
              $display("TB_FATAL bad input at line %0d input_count=%0d port=%0d", line_no, input_count, p);
              $finish;
            end
            if (p >= 16) begin
              $display("TB_FATAL NoC16 Stage1 GLS case uses top input port %0d at line %0d", p, line_no);
              $finish;
            end
            input_cycle[input_count] = cyc;
            input_port[input_count] = p;
            input_pkt_seq[input_count] = pkt_seq;
            input_flit[input_count] = flit;
            input_sent[input_count] = 1'b0;
            input_count = input_count + 1;
          end else if (tag == "expect") begin
            if ($sscanf(line, "%s %h %d %d %h", tag, mask, pkt_seq, tmp, flit) != 5) begin
              $display("TB_FATAL malformed expect at line %0d", line_no);
              $finish;
            end
            if ((expected_count >= MAX_EXPECT_FLITS) || (mask[NUM_PORTS-1:0] == 0) || (mask[31:NUM_PORTS] != 0)) begin
              $display("TB_FATAL bad expect at line %0d expected_count=%0d mask=%h", line_no, expected_count, mask);
              $finish;
            end
            if (mask[19:16] != 0) begin
              $display("TB_FATAL NoC16 Stage1 GLS case expects top output mask=%h at line %0d", mask, line_no);
              $finish;
            end
            expected_mask[expected_count] = mask[NUM_PORTS-1:0];
            expected_pkt_seq[expected_count] = pkt_seq;
            expected_is_tail[expected_count] = (tmp == 1);
            expected_flit[expected_count] = flit;
            expected_seen[expected_count] = 1'b0;
            expected_count = expected_count + 1;
          end
        end
      end
      $fclose(fd);
      timeout_scale = 1;
      if ($value$plusargs("TIMEOUT_SCALE=%d", timeout_scale) && (timeout_scale > 1))
        case_timeout = case_timeout * timeout_scale;
      $display("TB_INFO loaded case %0s inputs=%0d expects=%0d timeout=%0d",
               path, input_count, expected_count, case_timeout);
    end
  endtask

  task analyze_results;
    integer ri;
    integer ej;
    integer pkt_seq;
    integer lat;
    reg found;
    reg [NUM_PORTS-1:0] port_bit;
    begin
      for (ej = 0; ej < expected_count; ej = ej + 1) expected_seen[ej] = 1'b0;
      pass_count = 0;
      fail_count = 0;
      unexpected_count = 0;
      delivered_packets = 0;
      latency_count = 0;

      for (ri = 0; ri < rx_count; ri = ri + 1) begin
        found = 1'b0;
        port_bit = {NUM_PORTS{1'b0}};
        port_bit[rx_port[ri]] = 1'b1;
        for (ej = 0; ej < expected_count; ej = ej + 1) begin
          if (!found && !expected_seen[ej] && ((expected_mask[ej] & port_bit) != 0) &&
              (expected_flit[ej] == rx_flit[ri])) begin
            expected_seen[ej] = 1'b1;
            found = 1'b1;
            pass_count = pass_count + 1;
            if (expected_is_tail[ej]) begin
              delivered_packets = delivered_packets + 1;
              pkt_seq = expected_pkt_seq[ej];
              if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && (packet_head_cycle[pkt_seq] >= 0)) begin
                lat = rx_cycle[ri] - packet_head_cycle[pkt_seq];
                if ((lat >= 0) && (latency_count < MAX_EXPECT_FLITS)) begin
                  latency_samples[latency_count] = lat;
                  latency_count = latency_count + 1;
                end
              end
            end
          end
        end
        if (!found) unexpected_count = unexpected_count + 1;
      end

      for (ej = 0; ej < expected_count; ej = ej + 1)
        if (!expected_seen[ej]) fail_count = fail_count + 1;
    end
  endtask

  task write_result_csv_and_finish;
    integer fd_csv;
    integer csv_pos;
    integer rank95;
    integer rank99;
    integer lat_sum;
    integer max_lat;
    integer p95_lat;
    integer p99_lat;
    integer t;
    integer j;
    real avg_lat_ns;
    real max_lat_ns;
    real p95_lat_ns;
    real p99_lat_ns;
    real delivered_throughput;
    reg write_header;
    reg pass_ok;
    reg [31:0] pass_text;
    begin
      analyze_results();
      fd_csv = $fopen(csv_file, "a+");
      if (fd_csv == 0) begin
        $display("TB_FATAL cannot open CSV file: %0s", csv_file);
        $finish;
      end

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
        rank95 = (latency_count * 95 + 99) / 100;
        rank99 = (latency_count * 99 + 99) / 100;
        if (rank95 < 1) rank95 = 1;
        if (rank99 < 1) rank99 = 1;
        if (rank95 > latency_count) rank95 = latency_count;
        if (rank99 > latency_count) rank99 = latency_count;
        p95_lat = latency_samples[rank95 - 1];
        p99_lat = latency_samples[rank99 - 1];
        avg_lat_ns = (lat_sum * CLOCK_PERIOD_NS) / latency_count;
        max_lat_ns = max_lat * CLOCK_PERIOD_NS;
        p95_lat_ns = p95_lat * CLOCK_PERIOD_NS;
        p99_lat_ns = p99_lat * CLOCK_PERIOD_NS;
      end else begin
        avg_lat_ns = 0.0;
        max_lat_ns = 0.0;
        p95_lat_ns = 0.0;
        p99_lat_ns = 0.0;
      end
      if (final_cycle > 0) delivered_throughput = (delivered_flits * 1.0) / final_cycle;
      else delivered_throughput = 0.0;
      pass_ok = (fail_count == 0) && (unexpected_count == 0) && (timeout_hit == 0) &&
                (rx_overflow == 0) && (injected_flits == input_count);
      pass_text = pass_ok ? "PASS" : "FAIL";

      csv_pos = $fseek(fd_csv, 0, 2);
      csv_pos = $ftell(fd_csv);
      write_header = (csv_pos == 0);
      if (write_header) begin
        $fwrite(fd_csv, "group,case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,rx_overflow,measure_cycles,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      end

      $fwrite(fd_csv, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.3f,%0.3f,%0.3f,%0.3f,%0s\n",
              case_group, case_name, injected_packets, delivered_packets,
              injected_flits, delivered_flits, fail_count, unexpected_count,
              timeout_hit, rx_overflow, final_cycle, delivered_throughput,
              avg_lat_ns, max_lat_ns, p95_lat_ns, p99_lat_ns,
              pass_text);

      if (pass_ok) begin
        $display("TB_RESULT PASS group=%0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d avg_lat_ns=%0.3f p95_ns=%0.3f p99_ns=%0.3f missing=%0d unexpected=%0d timeout=%0d rx_overflow=%0d",
                 case_group, case_name, injected_flits, delivered_flits,
                 delivered_packets, avg_lat_ns, p95_lat_ns, p99_lat_ns,
                 fail_count, unexpected_count, timeout_hit, rx_overflow);
        if (e2e_done != 0)
          $display("E2E_NS=%.3f T_noc=%.3f src_req=%.3f dst_req=%.3f",
                   t_dst_req - t_src_req, t_dst_req - t_src_req, t_src_req, t_dst_req);
        print_e2e_probe_summary();
      end else begin
        $display("TB_RESULT FAIL group=%0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d avg_lat_ns=%0.3f p95_ns=%0.3f p99_ns=%0.3f missing=%0d unexpected=%0d timeout=%0d rx_overflow=%0d",
                 case_group, case_name, injected_flits, delivered_flits,
                 delivered_packets, avg_lat_ns, p95_lat_ns, p99_lat_ns,
                 fail_count, unexpected_count, timeout_hit, rx_overflow);
      end
      $fclose(fd_csv);
      $finish;
    end
  endtask

  task capture_outputs;
    integer cp;
    begin
      for (cp = 0; cp < NUM_PORTS; cp = cp + 1) begin
        if (got_pulse[cp]) begin
          delivered_flits = delivered_flits + 1;
          if (rx_count < MAX_RX_FLITS) begin
            rx_port[rx_count] = cp;
            rx_flit[rx_count] = got_data[cp];
            rx_cycle[rx_count] = cycle_counter;
            rx_count = rx_count + 1;
            if ((dump_vcd_enable != 0) && (rx_count >= expected_count)) begin
              $dumpoff;
              dump_vcd_enable = 0;
              $display("TB_INFO DUMP_VCD_OFF t=%.3f rx=%0d", $realtime, rx_count);
            end
          end else begin
            rx_overflow = 1;
          end
          if ((e2e_done == 0) && got_data[cp][27] && (e2e_src_set != 0)) begin
            t_dst_req = $realtime;
            e2e_done = 1;
            $display("E2E_NS=%.3f T_noc=%.3f src_req=%.3f dst_req=%.3f",
                     t_dst_req - t_src_req, t_dst_req - t_src_req, t_src_req, t_dst_req);
          end
        end
      end
    end
  endtask

  task dump_router_summary;
    input [127:0] name;
    input [4:0] input_valid;
    input [4:0] output_valid;
    input [4:0] context_active;
    input [4:0] winner;
    input [4:0] commit;
    input [4:0] commit_ready;
    input commit_raw;
    input global_commit_event;
    input [4:0] commit_conflict;
    input [4:0] granted_all;
    input [4:0] input_slot_req;
    input [4:0] input_slot_ack;
    input [4:0] output_slot_req;
    input [4:0] output_slot_ack;
    begin
      $display("DBG_ROUTER name=%0s summary inputValid=%b outputValid=%b contextActive=%b winner=%b commit=%b commitReady=%b commitRaw=%b globalCommitEvent=%b commitConflict=%b grantedAll=%b inputSlotReq=%b inputSlotAck=%b outputSlotReq=%b outputSlotAck=%b",
               name, input_valid, output_valid, context_active, winner, commit,
               commit_ready, commit_raw, global_commit_event, commit_conflict,
               granted_all, input_slot_req, input_slot_ack, output_slot_req,
               output_slot_ack);
    end
  endtask

  task dump_router_port;
    input [127:0] name;
    input integer port_id;
    input [4:0] request_mask;
    input [2:0] output_holder;
    input [4:0] output_winner;
    begin
      $display("DBG_ROUTER name=%0s port=%0d requestMask=%b outputHolder=%0d outputWinner=%b",
               name, port_id, request_mask, output_holder, output_winner);
    end
  endtask

  task dump_top_port_snapshot;
    integer dp;
    begin
      for (dp = 0; dp < NUM_PORTS; dp = dp + 1) begin
        $display("DBG_PORT kind=input port=%0d sender_busy=%b req=%b ack=%b valid=%b data=%h",
                 dp, sender_busy[dp], in_req[dp], in_ack[dp], in_req[dp] ^ in_ack[dp], in_data[dp]);
      end
      for (dp = 0; dp < NUM_PORTS; dp = dp + 1) begin
        $display("DBG_PORT kind=output port=%0d req=%b ack=%b valid=%b data=%h",
                 dp, out_req[dp], out_ack[dp], out_req[dp] ^ out_ack[dp], out_data[dp]);
      end
    end
  endtask

`ifdef NOC16_STAGE1_STALL_PROBE
  task dump_stage1_router_debug;
    begin
      dump_router_summary("l1_0_0", dut.io_debug_l1InputValid_0, dut.io_debug_l1OutputValid_0,
                          dut.io_debug_l1ContextActive_0, dut.io_debug_l1Winner_0,
                          dut.io_debug_l1Commit_0, dut.io_debug_l1CommitReady_0,
                          dut.io_debug_l1CommitRaw_0, dut.io_debug_l1GlobalCommitEvent_0,
                          dut.io_debug_l1CommitConflict_0, dut.io_debug_l1GrantedAll_0,
                          dut.io_debug_l1InputSlotReq_0, dut.io_debug_l1InputSlotAck_0,
                          dut.io_debug_l1OutputSlotReq_0, dut.io_debug_l1OutputSlotAck_0);
      dump_router_summary("l1_0_1", dut.io_debug_l1InputValid_1, dut.io_debug_l1OutputValid_1,
                          dut.io_debug_l1ContextActive_1, dut.io_debug_l1Winner_1,
                          dut.io_debug_l1Commit_1, dut.io_debug_l1CommitReady_1,
                          dut.io_debug_l1CommitRaw_1, dut.io_debug_l1GlobalCommitEvent_1,
                          dut.io_debug_l1CommitConflict_1, dut.io_debug_l1GrantedAll_1,
                          dut.io_debug_l1InputSlotReq_1, dut.io_debug_l1InputSlotAck_1,
                          dut.io_debug_l1OutputSlotReq_1, dut.io_debug_l1OutputSlotAck_1);
      dump_router_summary("l1_1_0", dut.io_debug_l1InputValid_2, dut.io_debug_l1OutputValid_2,
                          dut.io_debug_l1ContextActive_2, dut.io_debug_l1Winner_2,
                          dut.io_debug_l1Commit_2, dut.io_debug_l1CommitReady_2,
                          dut.io_debug_l1CommitRaw_2, dut.io_debug_l1GlobalCommitEvent_2,
                          dut.io_debug_l1CommitConflict_2, dut.io_debug_l1GrantedAll_2,
                          dut.io_debug_l1InputSlotReq_2, dut.io_debug_l1InputSlotAck_2,
                          dut.io_debug_l1OutputSlotReq_2, dut.io_debug_l1OutputSlotAck_2);
      dump_router_summary("l1_1_1", dut.io_debug_l1InputValid_3, dut.io_debug_l1OutputValid_3,
                          dut.io_debug_l1ContextActive_3, dut.io_debug_l1Winner_3,
                          dut.io_debug_l1Commit_3, dut.io_debug_l1CommitReady_3,
                          dut.io_debug_l1CommitRaw_3, dut.io_debug_l1GlobalCommitEvent_3,
                          dut.io_debug_l1CommitConflict_3, dut.io_debug_l1GrantedAll_3,
                          dut.io_debug_l1InputSlotReq_3, dut.io_debug_l1InputSlotAck_3,
                          dut.io_debug_l1OutputSlotReq_3, dut.io_debug_l1OutputSlotAck_3);
      dump_router_summary("l2", dut.io_debug_l2InputValid, dut.io_debug_l2OutputValid,
                          dut.io_debug_l2ContextActive, dut.io_debug_l2Winner,
                          dut.io_debug_l2Commit, dut.io_debug_l2CommitReady,
                          dut.io_debug_l2CommitRaw, dut.io_debug_l2GlobalCommitEvent,
                          dut.io_debug_l2CommitConflict, dut.io_debug_l2GrantedAll,
                          dut.io_debug_l2InputSlotReq, dut.io_debug_l2InputSlotAck,
                          dut.io_debug_l2OutputSlotReq, dut.io_debug_l2OutputSlotAck);

      dump_router_port("l1_0_0", 0, dut.io_debug_l1RequestMask_0_0, dut.io_debug_l1OutputHolder_0_0, dut.io_debug_l1OutputWinner_0_0);
      dump_router_port("l1_0_0", 1, dut.io_debug_l1RequestMask_0_1, dut.io_debug_l1OutputHolder_0_1, dut.io_debug_l1OutputWinner_0_1);
      dump_router_port("l1_0_0", 2, dut.io_debug_l1RequestMask_0_2, dut.io_debug_l1OutputHolder_0_2, dut.io_debug_l1OutputWinner_0_2);
      dump_router_port("l1_0_0", 3, dut.io_debug_l1RequestMask_0_3, dut.io_debug_l1OutputHolder_0_3, dut.io_debug_l1OutputWinner_0_3);
      dump_router_port("l1_0_0", 4, dut.io_debug_l1RequestMask_0_4, dut.io_debug_l1OutputHolder_0_4, dut.io_debug_l1OutputWinner_0_4);
      dump_router_port("l1_0_1", 0, dut.io_debug_l1RequestMask_1_0, dut.io_debug_l1OutputHolder_1_0, dut.io_debug_l1OutputWinner_1_0);
      dump_router_port("l1_0_1", 1, dut.io_debug_l1RequestMask_1_1, dut.io_debug_l1OutputHolder_1_1, dut.io_debug_l1OutputWinner_1_1);
      dump_router_port("l1_0_1", 2, dut.io_debug_l1RequestMask_1_2, dut.io_debug_l1OutputHolder_1_2, dut.io_debug_l1OutputWinner_1_2);
      dump_router_port("l1_0_1", 3, dut.io_debug_l1RequestMask_1_3, dut.io_debug_l1OutputHolder_1_3, dut.io_debug_l1OutputWinner_1_3);
      dump_router_port("l1_0_1", 4, dut.io_debug_l1RequestMask_1_4, dut.io_debug_l1OutputHolder_1_4, dut.io_debug_l1OutputWinner_1_4);
      dump_router_port("l1_1_0", 0, dut.io_debug_l1RequestMask_2_0, dut.io_debug_l1OutputHolder_2_0, dut.io_debug_l1OutputWinner_2_0);
      dump_router_port("l1_1_0", 1, dut.io_debug_l1RequestMask_2_1, dut.io_debug_l1OutputHolder_2_1, dut.io_debug_l1OutputWinner_2_1);
      dump_router_port("l1_1_0", 2, dut.io_debug_l1RequestMask_2_2, dut.io_debug_l1OutputHolder_2_2, dut.io_debug_l1OutputWinner_2_2);
      dump_router_port("l1_1_0", 3, dut.io_debug_l1RequestMask_2_3, dut.io_debug_l1OutputHolder_2_3, dut.io_debug_l1OutputWinner_2_3);
      dump_router_port("l1_1_0", 4, dut.io_debug_l1RequestMask_2_4, dut.io_debug_l1OutputHolder_2_4, dut.io_debug_l1OutputWinner_2_4);
      dump_router_port("l1_1_1", 0, dut.io_debug_l1RequestMask_3_0, dut.io_debug_l1OutputHolder_3_0, dut.io_debug_l1OutputWinner_3_0);
      dump_router_port("l1_1_1", 1, dut.io_debug_l1RequestMask_3_1, dut.io_debug_l1OutputHolder_3_1, dut.io_debug_l1OutputWinner_3_1);
      dump_router_port("l1_1_1", 2, dut.io_debug_l1RequestMask_3_2, dut.io_debug_l1OutputHolder_3_2, dut.io_debug_l1OutputWinner_3_2);
      dump_router_port("l1_1_1", 3, dut.io_debug_l1RequestMask_3_3, dut.io_debug_l1OutputHolder_3_3, dut.io_debug_l1OutputWinner_3_3);
      dump_router_port("l1_1_1", 4, dut.io_debug_l1RequestMask_3_4, dut.io_debug_l1OutputHolder_3_4, dut.io_debug_l1OutputWinner_3_4);
      dump_router_port("l2", 0, dut.io_debug_l2RequestMask_0, dut.io_debug_l2OutputHolder_0, dut.io_debug_l2OutputWinner_0);
      dump_router_port("l2", 1, dut.io_debug_l2RequestMask_1, dut.io_debug_l2OutputHolder_1, dut.io_debug_l2OutputWinner_1);
      dump_router_port("l2", 2, dut.io_debug_l2RequestMask_2, dut.io_debug_l2OutputHolder_2, dut.io_debug_l2OutputWinner_2);
      dump_router_port("l2", 3, dut.io_debug_l2RequestMask_3, dut.io_debug_l2OutputHolder_3, dut.io_debug_l2OutputWinner_3);
      dump_router_port("l2", 4, dut.io_debug_l2RequestMask_4, dut.io_debug_l2OutputHolder_4, dut.io_debug_l2OutputWinner_4);
    end
  endtask

  task dump_stage1_link_debug;
    begin
      $display("DBG_LINK name=l1_parent_out0 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL1ParentOutReq_0, dut.io_debug_linkL1ParentOutAck_0,
               dut.io_debug_linkL1ParentOutReq_0 ^ dut.io_debug_linkL1ParentOutAck_0,
               dut.io_debug_linkL1ParentOutData_0);
      $display("DBG_LINK name=l1_parent_out1 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL1ParentOutReq_1, dut.io_debug_linkL1ParentOutAck_1,
               dut.io_debug_linkL1ParentOutReq_1 ^ dut.io_debug_linkL1ParentOutAck_1,
               dut.io_debug_linkL1ParentOutData_1);
      $display("DBG_LINK name=l1_parent_out2 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL1ParentOutReq_2, dut.io_debug_linkL1ParentOutAck_2,
               dut.io_debug_linkL1ParentOutReq_2 ^ dut.io_debug_linkL1ParentOutAck_2,
               dut.io_debug_linkL1ParentOutData_2);
      $display("DBG_LINK name=l1_parent_out3 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL1ParentOutReq_3, dut.io_debug_linkL1ParentOutAck_3,
               dut.io_debug_linkL1ParentOutReq_3 ^ dut.io_debug_linkL1ParentOutAck_3,
               dut.io_debug_linkL1ParentOutData_3);
      $display("DBG_LINK name=l2_child_out0 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ChildOutReq_0, dut.io_debug_linkL2ChildOutAck_0,
               dut.io_debug_linkL2ChildOutReq_0 ^ dut.io_debug_linkL2ChildOutAck_0,
               dut.io_debug_linkL2ChildOutData_0);
      $display("DBG_LINK name=l2_child_out1 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ChildOutReq_1, dut.io_debug_linkL2ChildOutAck_1,
               dut.io_debug_linkL2ChildOutReq_1 ^ dut.io_debug_linkL2ChildOutAck_1,
               dut.io_debug_linkL2ChildOutData_1);
      $display("DBG_LINK name=l2_child_out2 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ChildOutReq_2, dut.io_debug_linkL2ChildOutAck_2,
               dut.io_debug_linkL2ChildOutReq_2 ^ dut.io_debug_linkL2ChildOutAck_2,
               dut.io_debug_linkL2ChildOutData_2);
      $display("DBG_LINK name=l2_child_out3 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ChildOutReq_3, dut.io_debug_linkL2ChildOutAck_3,
               dut.io_debug_linkL2ChildOutReq_3 ^ dut.io_debug_linkL2ChildOutAck_3,
               dut.io_debug_linkL2ChildOutData_3);
      $display("DBG_LINK name=l2_parent_in0 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ParentInReq, dut.io_debug_linkL2ParentInAck,
               dut.io_debug_linkL2ParentInReq ^ dut.io_debug_linkL2ParentInAck,
               dut.io_debug_linkL2ParentInData);
      $display("DBG_LINK name=l2_parent_out0 req=%b ack=%b valid=%b data=%h",
               dut.io_debug_linkL2ParentOutReq, dut.io_debug_linkL2ParentOutAck,
               dut.io_debug_linkL2ParentOutReq ^ dut.io_debug_linkL2ParentOutAck,
               dut.io_debug_linkL2ParentOutData);
    end
  endtask
`endif

  task dump_stall_snapshot;
    input [127:0] phase;
    integer si;
    integer first_pending;
    begin
      first_pending = -1;
      for (si = 0; si < input_count; si = si + 1) begin
        if ((first_pending < 0) && !input_sent[si]) first_pending = si;
      end
      $display("TB_STALL_SNAPSHOT phase=%0s cycle=%0d injected=%0d/%0d rx=%0d/%0d first_pending=%0d",
               phase, cycle_counter, injected_flits, input_count, rx_count, expected_count, first_pending);
      if (first_pending >= 0) begin
        $display("TB_STALL_PENDING idx=%0d cycle=%0d port=%0d pkt_seq=%0d flit=%h sender_busy=%b in_req=%b in_ack=%b",
                 first_pending, input_cycle[first_pending], input_port[first_pending],
                 input_pkt_seq[first_pending], input_flit[first_pending],
                 sender_busy[input_port[first_pending]], in_req[input_port[first_pending]],
                 in_ack[input_port[first_pending]]);
      end
      dump_top_port_snapshot();
`ifdef NOC16_STAGE1_STALL_PROBE
      dump_stage1_router_debug();
      dump_stage1_link_debug();
`endif
    end
  endtask

  task check_stall_progress;
    input [127:0] phase;
    begin
      if (stall_probe != 0) begin
        if ((cycle_counter % stall_window_cycles) == 0) begin
          if ((injected_flits == stall_prev_injected) && (rx_count == stall_prev_rx))
            stall_quiet_windows = stall_quiet_windows + 1;
          else
            stall_quiet_windows = 0;
          stall_prev_injected = injected_flits;
          stall_prev_rx = rx_count;
          if (stall_quiet_windows >= stall_window_count) begin
            timeout_hit = 1;
            final_cycle = cycle_counter;
            dump_stall_snapshot(phase);
            write_result_csv_and_finish();
          end
        end
      end
    end
  endtask

  initial begin
    case_file = "";
    csv_file = "";
    dump_vcd_file = "";
    e2e_done = 0;
    e2e_src_set = 0;
    dump_vcd_enable = 0;
    e2e_edge_probe = 0;
    e2e_src_port = 0;
    e2e_dst_port = 15;
    e2e_probe_flit_set = 0;
    e2e_probe_flit = {FLIT_W{1'b0}};
    edge_in_req_seen = 0;
    edge_out_req_seen = 0;
    edge_out_valid_seen = 0;
    stall_probe = 0;
    stall_window_cycles = 10000;
    stall_window_count = 3;
    stall_prev_injected = -1;
    stall_prev_rx = -1;
    stall_quiet_windows = 0;
    t_src_req = 0.0;
    t_dst_req = 0.0;
    t_edge_in_req = 0.0;
    t_edge_out_req = 0.0;
    t_edge_out_valid = 0.0;
`ifdef NOC16_ROUTE_PROBE
    seg_l1_src_parent_0_seen = 0;
    seg_l1_src_parent_1_seen = 0;
    seg_l2_in_child_3_0_seen = 0;
    seg_l2_in_child_3_1_seen = 0;
    seg_l2_out_child_0_0_seen = 0;
    seg_l2_out_child_0_1_seen = 0;
    seg_l1_dst_parent_0_seen = 0;
    seg_l1_dst_parent_1_seen = 0;
    seg_l1_dst_child_0_seen = 0;
`endif
    void'($value$plusargs("CASE=%s", case_file));
    if (case_file == "") void'($value$plusargs("CASE_FILE=%s", case_file));
    void'($value$plusargs("CSV=%s", csv_file));
    void'($value$plusargs("DUMP_VCD=%s", dump_vcd_file));
    void'($value$plusargs("E2E_EDGE_PROBE=%d", e2e_edge_probe));
    void'($value$plusargs("E2E_SRC_PORT=%d", e2e_src_port));
    void'($value$plusargs("E2E_DST_PORT=%d", e2e_dst_port));
    void'($value$plusargs("STALL_PROBE=%d", stall_probe));
    void'($value$plusargs("STALL_WINDOW_CYCLES=%d", stall_window_cycles));
    void'($value$plusargs("STALL_WINDOW_COUNT=%d", stall_window_count));
    if (stall_window_cycles < 1) stall_window_cycles = 10000;
    if (stall_window_count < 1) stall_window_count = 3;
    if (case_file == "") case_file = "cases/noc16_00_to_33_3flit_smoke.case";
    if (csv_file == "") csv_file = "summary/noc16_func.csv";
    if (dump_vcd_file != "") begin
      $dumpfile(dump_vcd_file);
      $dumpvars(0, dut);
      dump_vcd_enable = 1;
      $display("TB_INFO DUMP_VCD %0s scope=tb_gls_noc16_func.dut", dump_vcd_file);
    end
    // SDF annotate (if any) is done by companion sdf_boot from run_gls_smoke.sh
    load_case(case_file);
    if (e2e_edge_probe != 0) begin
      for (i = 0; i < input_count; i = i + 1) begin
        if ((e2e_probe_flit_set == 0) && (input_port[i] == e2e_src_port) && input_flit[i][27]) begin
          e2e_probe_flit = input_flit[i];
          e2e_probe_flit_set = 1;
        end
      end
      $display("TB_INFO E2E_EDGE_PROBE enabled src=%0d dst=%0d flit_set=%0d flit=%h",
               e2e_src_port, e2e_dst_port, e2e_probe_flit_set, e2e_probe_flit);
    end

    reset = 1'b1;
    inject_idx = 0;
    rx_count = 0;
    cycle_counter = 0;
    injected_flits = 0;
    delivered_flits = 0;
    injected_packets = 0;
    delivered_packets = 0;
    latency_count = 0;
    timeout_hit = 0;
    rx_overflow = 0;
    final_cycle = 0;
    for (i = 0; i < MAX_PKT_SEQ; i = i + 1) packet_head_cycle[i] = -1;
    for (i = 0; i < input_count; i = i + 1) begin
      input_sent[i] = 1'b0;
      if (input_flit[i][27]) injected_packets = injected_packets + 1;
    end
    for (i = 0; i < NUM_PORTS; i = i + 1) begin
      send_pulse[i] = 1'b0;
      send_data[i] = {FLIT_W{1'b0}};
      port_issued[i] = 1'b0;
    end
    repeat (RESET_CYCLES) @(posedge clock);
    reset = 1'b0;

    // Inject then drain (no fork — VCS Pass2 safety)
    while (injected_flits < input_count) begin
      @(posedge clock);
      capture_outputs();
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        send_pulse[p] = 1'b0;
        port_issued[p] = 1'b0;
      end
      for (i = 0; i < input_count; i = i + 1) begin
        p = input_port[i];
        if (!input_sent[i] && (input_cycle[i] <= cycle_counter) &&
            !port_issued[p] && !sender_busy[p]) begin
          send_data[p] = input_flit[i];
          send_pulse[p] = 1'b1;
          port_issued[p] = 1'b1;
          input_sent[i] = 1'b1;
          injected_flits = injected_flits + 1;
          if (input_flit[i][27] && (input_pkt_seq[i] >= 0) && (input_pkt_seq[i] < MAX_PKT_SEQ))
            packet_head_cycle[input_pkt_seq[i]] = cycle_counter;
          if (input_flit[i][27] && (e2e_src_set == 0)) begin
            t_src_req = $realtime;
            e2e_src_set = 1;
          end
        end
      end
      cycle_counter = cycle_counter + 1;
      if ((cycle_counter % 10000) == 0)
        $display("TB_PROGRESS phase=inject cycle=%0d injected=%0d/%0d rx=%0d/%0d",
                 cycle_counter, injected_flits, input_count, rx_count, expected_count);
      check_stall_progress("inject");
      if (cycle_counter > RUN_TIMEOUT_CYCLES) begin
        timeout_hit = 1;
        $display("TB_TIMEOUT inject timeout cycle=%0d injected=%0d inputs=%0d",
                 cycle_counter, injected_flits, input_count);
        final_cycle = cycle_counter;
        write_result_csv_and_finish();
      end
    end

    drain_limit = case_timeout;
    if (drain_limit < 2000) drain_limit = 2000;
    for (i = 0; i < drain_limit; i = i + 1) begin
      @(posedge clock);
      capture_outputs();
      cycle_counter = cycle_counter + 1;
      if ((cycle_counter % 10000) == 0)
        $display("TB_PROGRESS phase=drain cycle=%0d injected=%0d/%0d rx=%0d/%0d",
                 cycle_counter, injected_flits, input_count, rx_count, expected_count);
      check_stall_progress("drain");
      if (rx_count >= expected_count) i = drain_limit;
    end

    final_cycle = cycle_counter;
    write_result_csv_and_finish();
  end
endmodule

`default_nettype wire

`timescale 1ns/1ps

// Read-only hop probe for TAB head 800800b (dest (2,0) = core 2).
// Binds only flattened NoC_16nodes nets that survive this frozen netlist.
// Handshake pairs are split by DC: L1 parent Req vs upward enq Ack, L2 child
// Ack vs upward deq Req, L2 child Req vs downward enq Ack, downward deq Req
// vs L1 parent Ack.  No RCU / Adapter / Mutex pins.
module tb_cmr_fat_tree_800800b_hop_probe;
  localparam [27:0] TARGET_HEAD = 28'h800800b;
  localparam integer DEPTH = 256;
  localparam [7:0] ST_INJ = 1, ST_L1_UP = 2, ST_L2_IN = 3,
                   ST_L2_OUT = 4, ST_DOWN = 5, ST_L1_PIN = 6, ST_EJECT = 7;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire [15:0] inj_req = {
    `DUT.io_core_inputs_15_HS_Req, `DUT.io_core_inputs_14_HS_Req,
    `DUT.io_core_inputs_13_HS_Req, `DUT.io_core_inputs_12_HS_Req,
    `DUT.io_core_inputs_11_HS_Req, `DUT.io_core_inputs_10_HS_Req,
    `DUT.io_core_inputs_9_HS_Req,  `DUT.io_core_inputs_8_HS_Req,
    `DUT.io_core_inputs_7_HS_Req,  `DUT.io_core_inputs_6_HS_Req,
    `DUT.io_core_inputs_5_HS_Req,  `DUT.io_core_inputs_4_HS_Req,
    `DUT.io_core_inputs_3_HS_Req,  `DUT.io_core_inputs_2_HS_Req,
    `DUT.io_core_inputs_1_HS_Req,  `DUT.io_core_inputs_0_HS_Req
  };
  wire [15:0] inj_ack = {
    `DUT.io_core_inputs_15_HS_Ack, `DUT.io_core_inputs_14_HS_Ack,
    `DUT.io_core_inputs_13_HS_Ack, `DUT.io_core_inputs_12_HS_Ack,
    `DUT.io_core_inputs_11_HS_Ack, `DUT.io_core_inputs_10_HS_Ack,
    `DUT.io_core_inputs_9_HS_Ack,  `DUT.io_core_inputs_8_HS_Ack,
    `DUT.io_core_inputs_7_HS_Ack,  `DUT.io_core_inputs_6_HS_Ack,
    `DUT.io_core_inputs_5_HS_Ack,  `DUT.io_core_inputs_4_HS_Ack,
    `DUT.io_core_inputs_3_HS_Ack,  `DUT.io_core_inputs_2_HS_Ack,
    `DUT.io_core_inputs_1_HS_Ack,  `DUT.io_core_inputs_0_HS_Ack
  };
  wire [447:0] inj_data = {
    `DUT.io_core_inputs_15_Data_flit, `DUT.io_core_inputs_14_Data_flit,
    `DUT.io_core_inputs_13_Data_flit, `DUT.io_core_inputs_12_Data_flit,
    `DUT.io_core_inputs_11_Data_flit, `DUT.io_core_inputs_10_Data_flit,
    `DUT.io_core_inputs_9_Data_flit,  `DUT.io_core_inputs_8_Data_flit,
    `DUT.io_core_inputs_7_Data_flit,  `DUT.io_core_inputs_6_Data_flit,
    `DUT.io_core_inputs_5_Data_flit,  `DUT.io_core_inputs_4_Data_flit,
    `DUT.io_core_inputs_3_Data_flit,  `DUT.io_core_inputs_2_Data_flit,
    `DUT.io_core_inputs_1_Data_flit,  `DUT.io_core_inputs_0_Data_flit
  };

  wire [15:0] eject_req = {
    `DUT.io_core_outputs_15_HS_Req, `DUT.io_core_outputs_14_HS_Req,
    `DUT.io_core_outputs_13_HS_Req, `DUT.io_core_outputs_12_HS_Req,
    `DUT.io_core_outputs_11_HS_Req, `DUT.io_core_outputs_10_HS_Req,
    `DUT.io_core_outputs_9_HS_Req,  `DUT.io_core_outputs_8_HS_Req,
    `DUT.io_core_outputs_7_HS_Req,  `DUT.io_core_outputs_6_HS_Req,
    `DUT.io_core_outputs_5_HS_Req,  `DUT.io_core_outputs_4_HS_Req,
    `DUT.io_core_outputs_3_HS_Req,  `DUT.io_core_outputs_2_HS_Req,
    `DUT.io_core_outputs_1_HS_Req,  `DUT.io_core_outputs_0_HS_Req
  };
  wire [15:0] eject_ack = {
    `DUT.io_core_outputs_15_HS_Ack, `DUT.io_core_outputs_14_HS_Ack,
    `DUT.io_core_outputs_13_HS_Ack, `DUT.io_core_outputs_12_HS_Ack,
    `DUT.io_core_outputs_11_HS_Ack, `DUT.io_core_outputs_10_HS_Ack,
    `DUT.io_core_outputs_9_HS_Ack,  `DUT.io_core_outputs_8_HS_Ack,
    `DUT.io_core_outputs_7_HS_Ack,  `DUT.io_core_outputs_6_HS_Ack,
    `DUT.io_core_outputs_5_HS_Ack,  `DUT.io_core_outputs_4_HS_Ack,
    `DUT.io_core_outputs_3_HS_Ack,  `DUT.io_core_outputs_2_HS_Ack,
    `DUT.io_core_outputs_1_HS_Ack,  `DUT.io_core_outputs_0_HS_Ack
  };
  wire [447:0] eject_data = {
    `DUT.io_core_outputs_15_Data_flit, `DUT.io_core_outputs_14_Data_flit,
    `DUT.io_core_outputs_13_Data_flit, `DUT.io_core_outputs_12_Data_flit,
    `DUT.io_core_outputs_11_Data_flit, `DUT.io_core_outputs_10_Data_flit,
    `DUT.io_core_outputs_9_Data_flit,  `DUT.io_core_outputs_8_Data_flit,
    `DUT.io_core_outputs_7_Data_flit,  `DUT.io_core_outputs_6_Data_flit,
    `DUT.io_core_outputs_5_Data_flit,  `DUT.io_core_outputs_4_Data_flit,
    `DUT.io_core_outputs_3_Data_flit,  `DUT.io_core_outputs_2_Data_flit,
    `DUT.io_core_outputs_1_Data_flit,  `DUT.io_core_outputs_0_Data_flit
  };

  // Packed dir*2+lane.  dir0 L1(1,1) upward/downward; dir1 L1(1,0) _2/_3;
  // dir2 L1(0,1) _4/_5; dir3 L1(0,0) _6/_7.
  wire [7:0] l1_up_req = {
    `DUT.routerL1_0_0_io_outputs_parent_1_HS_Req,
    `DUT.routerL1_0_0_io_outputs_parent_0_HS_Req,
    `DUT.routerL1_0_1_io_outputs_parent_1_HS_Req,
    `DUT.routerL1_0_1_io_outputs_parent_0_HS_Req,
    `DUT.routerL1_1_0_io_outputs_parent_1_HS_Req,
    `DUT.routerL1_1_0_io_outputs_parent_0_HS_Req,
    `DUT.routerL1_1_1_io_outputs_parent_1_HS_Req,
    `DUT.routerL1_1_1_io_outputs_parent_0_HS_Req
  };
  wire [7:0] l1_up_ack = {
    `DUT.upward_7_io_enq_HS_Ack, `DUT.upward_6_io_enq_HS_Ack,
    `DUT.upward_5_io_enq_HS_Ack, `DUT.upward_4_io_enq_HS_Ack,
    `DUT.upward_3_io_enq_HS_Ack, `DUT.upward_2_io_enq_HS_Ack,
    `DUT.upward_1_io_enq_HS_Ack, `DUT.upward_io_enq_HS_Ack
  };
  wire [223:0] l1_up_data = {
    `DUT.routerL1_0_0_io_outputs_parent_1_Data_flit,
    `DUT.routerL1_0_0_io_outputs_parent_0_Data_flit,
    `DUT.routerL1_0_1_io_outputs_parent_1_Data_flit,
    `DUT.routerL1_0_1_io_outputs_parent_0_Data_flit,
    `DUT.routerL1_1_0_io_outputs_parent_1_Data_flit,
    `DUT.routerL1_1_0_io_outputs_parent_0_Data_flit,
    `DUT.routerL1_1_1_io_outputs_parent_1_Data_flit,
    `DUT.routerL1_1_1_io_outputs_parent_0_Data_flit
  };

  wire [7:0] l2_in_req = {
    `DUT.upward_7_io_deq_HS_Req, `DUT.upward_6_io_deq_HS_Req,
    `DUT.upward_5_io_deq_HS_Req, `DUT.upward_4_io_deq_HS_Req,
    `DUT.upward_3_io_deq_HS_Req, `DUT.upward_2_io_deq_HS_Req,
    `DUT.upward_1_io_deq_HS_Req, `DUT.upward_io_deq_HS_Req
  };
  wire [7:0] l2_in_ack = {
    `DUT.routerL2_io_inputs_child_3_1_HS_Ack,
    `DUT.routerL2_io_inputs_child_3_0_HS_Ack,
    `DUT.routerL2_io_inputs_child_2_1_HS_Ack,
    `DUT.routerL2_io_inputs_child_2_0_HS_Ack,
    `DUT.routerL2_io_inputs_child_1_1_HS_Ack,
    `DUT.routerL2_io_inputs_child_1_0_HS_Ack,
    `DUT.routerL2_io_inputs_child_0_1_HS_Ack,
    `DUT.routerL2_io_inputs_child_0_0_HS_Ack
  };
  wire [223:0] l2_in_data = {
    `DUT.upward_7_io_deq_Data_flit, `DUT.upward_6_io_deq_Data_flit,
    `DUT.upward_5_io_deq_Data_flit, `DUT.upward_4_io_deq_Data_flit,
    `DUT.upward_3_io_deq_Data_flit, `DUT.upward_2_io_deq_Data_flit,
    `DUT.upward_1_io_deq_Data_flit, `DUT.upward_io_deq_Data_flit
  };

  wire [7:0] l2_out_req = {
    `DUT.routerL2_io_outputs_child_3_1_HS_Req,
    `DUT.routerL2_io_outputs_child_3_0_HS_Req,
    `DUT.routerL2_io_outputs_child_2_1_HS_Req,
    `DUT.routerL2_io_outputs_child_2_0_HS_Req,
    `DUT.routerL2_io_outputs_child_1_1_HS_Req,
    `DUT.routerL2_io_outputs_child_1_0_HS_Req,
    `DUT.routerL2_io_outputs_child_0_1_HS_Req,
    `DUT.routerL2_io_outputs_child_0_0_HS_Req
  };
  wire [7:0] l2_out_ack = {
    `DUT.downward_7_io_enq_HS_Ack, `DUT.downward_6_io_enq_HS_Ack,
    `DUT.downward_5_io_enq_HS_Ack, `DUT.downward_4_io_enq_HS_Ack,
    `DUT.downward_3_io_enq_HS_Ack, `DUT.downward_2_io_enq_HS_Ack,
    `DUT.downward_1_io_enq_HS_Ack, `DUT.downward_io_enq_HS_Ack
  };
  wire [223:0] l2_out_data = {
    `DUT.routerL2_io_outputs_child_3_1_Data_flit,
    `DUT.routerL2_io_outputs_child_3_0_Data_flit,
    `DUT.routerL2_io_outputs_child_2_1_Data_flit,
    `DUT.routerL2_io_outputs_child_2_0_Data_flit,
    `DUT.routerL2_io_outputs_child_1_1_Data_flit,
    `DUT.routerL2_io_outputs_child_1_0_Data_flit,
    `DUT.routerL2_io_outputs_child_0_1_Data_flit,
    `DUT.routerL2_io_outputs_child_0_0_Data_flit
  };

  wire [7:0] down_req = {
    `DUT.downward_7_io_deq_HS_Req, `DUT.downward_6_io_deq_HS_Req,
    `DUT.downward_5_io_deq_HS_Req, `DUT.downward_4_io_deq_HS_Req,
    `DUT.downward_3_io_deq_HS_Req, `DUT.downward_2_io_deq_HS_Req,
    `DUT.downward_1_io_deq_HS_Req, `DUT.downward_io_deq_HS_Req
  };
  wire [7:0] l1_pin_ack = {
    `DUT.routerL1_0_0_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_0_0_io_inputs_parent_0_HS_Ack,
    `DUT.routerL1_0_1_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_0_1_io_inputs_parent_0_HS_Ack,
    `DUT.routerL1_1_0_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_1_0_io_inputs_parent_0_HS_Ack,
    `DUT.routerL1_1_1_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_1_1_io_inputs_parent_0_HS_Ack
  };
  wire [223:0] down_data = {
    `DUT.downward_7_io_deq_Data_flit, `DUT.downward_6_io_deq_Data_flit,
    `DUT.downward_5_io_deq_Data_flit, `DUT.downward_4_io_deq_Data_flit,
    `DUT.downward_3_io_deq_Data_flit, `DUT.downward_2_io_deq_Data_flit,
    `DUT.downward_1_io_deq_Data_flit, `DUT.downward_io_deq_Data_flit
  };

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  realtime event_time [0:DEPTH-1];
  reg [7:0] event_site [0:DEPTH-1];
  integer event_aux [0:DEPTH-1];
  reg [15:0] inj_seen;
  reg [7:0] l1_up_seen;
  reg [7:0] l2_in_seen;
  reg [7:0] l2_out_seen;
  reg [7:0] down_seen;
  reg [15:0] eject_seen;

  function automatic is_offer;
    input req;
    input ack;
    input [27:0] data;
    begin
      is_offer = ((req === 1'b0) || (req === 1'b1)) &&
                 ((ack === 1'b0) || (ack === 1'b1)) &&
                 (req !== ack) && (data === TARGET_HEAD);
    end
  endfunction

  task automatic record_hop;
    input [7:0] site;
    input integer aux;
    integer slot;
    integer hop_lane;
    integer hop_dir;
    integer l1_x;
    integer l1_y;
    begin
      slot = next_slot;
      event_time[slot] = $realtime;
      event_site[slot] = site;
      event_aux[slot] = aux;
      next_slot = (next_slot + 1) % DEPTH;
      count = (count < DEPTH) ? count + 1 : DEPTH;
      total = total + 1;
      hop_lane = aux & 1;
      hop_dir = aux >> 1;
      l1_x = ((~hop_dir) >> 1) & 1;
      l1_y = (~hop_dir) & 1;
      if (site == ST_INJ)
        $display("CMR_HOP t_ns=%0.3f site=INJ core=%0d", $realtime, aux);
      else if (site == ST_EJECT)
        $display("CMR_HOP t_ns=%0.3f site=EJECT core=%0d", $realtime, aux);
      else if (site == ST_L1_UP)
        $display("CMR_HOP t_ns=%0.3f site=L1_UP L1(%0d,%0d) lane=%0d dir=%0d",
                 $realtime, l1_x, l1_y, hop_lane, hop_dir);
      else if (site == ST_L2_IN)
        $display("CMR_HOP t_ns=%0.3f site=L2_IN dir=%0d lane=%0d",
                 $realtime, hop_dir, hop_lane);
      else if (site == ST_L2_OUT)
        $display("CMR_HOP t_ns=%0.3f site=L2_OUT dir=%0d lane=%0d",
                 $realtime, hop_dir, hop_lane);
      else
        $display("CMR_HOP t_ns=%0.3f site=DOWN_FIFO/L1_PIN dir=%0d lane=%0d L1(%0d,%0d)",
                 $realtime, hop_dir, hop_lane, l1_x, l1_y);
    end
  endtask

  initial begin
    next_slot = 0;
    count = 0;
    total = 0;
    inj_seen = 16'b0;
    l1_up_seen = 8'b0;
    l2_in_seen = 8'b0;
    l2_out_seen = 8'b0;
    down_seen = 8'b0;
    eject_seen = 16'b0;
    $display("CMR_HOP_MAP dest_head=800800b dest_core=2 legal_L1=L1(1,0) legal_L2_child_dir=1");
    $display("CMR_HOP_MAP observed_core=8 illegal_L1=L1(0,1) illegal_L2_child_dir=2");
  end

  always @(inj_req or inj_ack or inj_data) begin : hop_inj
    integer i;
    for (i = 0; i < 16; i = i + 1) begin
      if (is_offer(inj_req[i], inj_ack[i], inj_data[i*28 +: 28])) begin
        if (!inj_seen[i]) record_hop(ST_INJ, i);
        inj_seen[i] = 1'b1;
      end else
        inj_seen[i] = 1'b0;
    end
  end

  always @(l1_up_req or l1_up_ack or l1_up_data) begin : hop_l1_up
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      if (is_offer(l1_up_req[i], l1_up_ack[i], l1_up_data[i*28 +: 28])) begin
        if (!l1_up_seen[i]) record_hop(ST_L1_UP, i);
        l1_up_seen[i] = 1'b1;
      end else
        l1_up_seen[i] = 1'b0;
    end
  end

  always @(l2_in_req or l2_in_ack or l2_in_data) begin : hop_l2_in
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      if (is_offer(l2_in_req[i], l2_in_ack[i], l2_in_data[i*28 +: 28])) begin
        if (!l2_in_seen[i]) record_hop(ST_L2_IN, i);
        l2_in_seen[i] = 1'b1;
      end else
        l2_in_seen[i] = 1'b0;
    end
  end

  always @(l2_out_req or l2_out_ack or l2_out_data) begin : hop_l2_out
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      if (is_offer(l2_out_req[i], l2_out_ack[i], l2_out_data[i*28 +: 28])) begin
        if (!l2_out_seen[i]) record_hop(ST_L2_OUT, i);
        l2_out_seen[i] = 1'b1;
      end else
        l2_out_seen[i] = 1'b0;
    end
  end

  always @(down_req or l1_pin_ack or down_data) begin : hop_down
    integer i;
    for (i = 0; i < 8; i = i + 1) begin
      if (is_offer(down_req[i], l1_pin_ack[i], down_data[i*28 +: 28])) begin
        if (!down_seen[i]) record_hop(ST_DOWN, i);
        down_seen[i] = 1'b1;
      end else
        down_seen[i] = 1'b0;
    end
  end

  always @(eject_req or eject_ack or eject_data) begin : hop_eject
    integer i;
    for (i = 0; i < 16; i = i + 1) begin
      if (is_offer(eject_req[i], eject_ack[i], eject_data[i*28 +: 28])) begin
        if (!eject_seen[i]) record_hop(ST_EJECT, i);
        eject_seen[i] = 1'b1;
      end else
        eject_seen[i] = 1'b0;
    end
  end

  always @(posedge trigger) begin
    $display("CMR_HOP_DUMP t_ns=%0.3f retained=%0d total=%0d",
             $realtime, count, total);
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      $display("CMR_HOP_RING seq=%0d t_ns=%0.3f site=%0d aux=%0d",
               total - count + dump_i, event_time[dump_slot],
               event_site[dump_slot], event_aux[dump_slot]);
    end
  end

`undef DUT
endmodule

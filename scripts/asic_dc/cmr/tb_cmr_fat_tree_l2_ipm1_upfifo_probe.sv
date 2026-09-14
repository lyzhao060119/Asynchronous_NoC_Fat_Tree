`timescale 1ns/1ps

// Read-only upward FIFO probe for L2 IPM1 (child dir0 lane1).
// Enq = L1(1,1) parent lane1 -> AsyncFifo upward_1.
// Deq = upward_1 -> L2 child dir0 lane1 (IPM1).
// Also logs sibling lane0 (upward) and the three ACG stages of upward_1.
module tb_cmr_fat_tree_l2_ipm1_upfifo_probe;
  localparam [27:0] PKT1_HEAD = 28'h8200202;
  localparam [27:0] PKT1_BODY = 28'h0200202;
  localparam [27:0] PKT1_TAIL = 28'h4200202;
  localparam [27:0] TARGET_HEAD = 28'h800800b;
  localparam integer DEPTH = 1024;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
`define FIFO `DUT.upward_1

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire enq1_req = `DUT.routerL1_1_1_io_outputs_parent_1_HS_Req;
  wire enq1_ack = `DUT.upward_1_io_enq_HS_Ack;
  wire [27:0] enq1_data = `DUT.routerL1_1_1_io_outputs_parent_1_Data_flit;
  wire deq1_req = `DUT.upward_1_io_deq_HS_Req;
  wire deq1_ack = `DUT.routerL2_io_inputs_child_0_1_HS_Ack;
  wire [27:0] deq1_data = `DUT.upward_1_io_deq_Data_flit;

  wire enq0_req = `DUT.routerL1_1_1_io_outputs_parent_0_HS_Req;
  wire enq0_ack = `DUT.upward_io_enq_HS_Ack;
  wire [27:0] enq0_data = `DUT.routerL1_1_1_io_outputs_parent_0_Data_flit;
  wire deq0_req = `DUT.upward_io_deq_HS_Req;
  wire deq0_ack = `DUT.routerL2_io_inputs_child_0_0_HS_Ack;
  wire [27:0] deq0_data = `DUT.upward_io_deq_Data_flit;

  wire s0_req = `FIFO.stages_0_io_out_HS_Req;
  wire s0_ack = `FIFO.stages_1_io_in_HS_Ack;
  wire [27:0] s0_data = `FIFO.stages_0_io_out_Data_flit;
  wire s1_req = `FIFO.stages_1_io_out_HS_Req;
  wire s1_ack = `FIFO.stages_2_io_in_HS_Ack;
  wire [27:0] s1_data = `FIFO.stages_1_io_out_Data_flit;

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  integer enq1_head_n;
  integer deq1_head_n;
  integer enq1_body_n;
  integer deq1_body_n;
  integer enq1_tail_n;
  integer deq1_tail_n;
  integer s0_head_n;
  integer s1_head_n;
  integer enq0_head_n;
  integer deq0_head_n;
  realtime event_time [0:DEPTH-1];
  reg [8*8-1:0] event_site [0:DEPTH-1];
  reg [27:0] event_data [0:DEPTH-1];
  reg event_req [0:DEPTH-1];
  reg event_ack [0:DEPTH-1];
  reg event_offer [0:DEPTH-1];
  reg [27:0] last_enq1;
  reg [27:0] last_deq1;
  reg [27:0] last_enq0;
  reg [27:0] last_deq0;
  reg [27:0] last_s0;
  reg [27:0] last_s1;
  reg last_enq1_req, last_enq1_ack;
  reg last_deq1_req, last_deq1_ack;
  reg last_enq0_req, last_enq0_ack;
  reg last_deq0_req, last_deq0_ack;
  reg last_s0_req, last_s0_ack;
  reg last_s1_req, last_s1_ack;

  function automatic offer;
    input req;
    input ack;
    begin
      offer = ((req === 1'b0) || (req === 1'b1)) &&
              ((ack === 1'b0) || (ack === 1'b1)) &&
              (req !== ack);
    end
  endfunction

  task automatic record;
    input [8*8-1:0] site;
    input req;
    input ack;
    input [27:0] data;
    integer slot;
    begin
      slot = next_slot;
      event_time[slot] = $realtime;
      event_site[slot] = site;
      event_req[slot] = req;
      event_ack[slot] = ack;
      event_data[slot] = data;
      event_offer[slot] = offer(req, ack);
      next_slot = (next_slot + 1) % DEPTH;
      count = (count < DEPTH) ? count + 1 : DEPTH;
      total = total + 1;
      $display("CMR_UPFIFO t_ns=%0.3f site=%0s r/a=%b/%b offer=%b ht=%b%b data=%h",
               $realtime, site, req, ack, offer(req, ack), data[27], data[26], data);
    end
  endtask

  task automatic note_data;
    input [27:0] prev;
    input [27:0] data;
    inout integer head_n;
    inout integer body_n;
    inout integer tail_n;
    begin
      if (data !== prev) begin
        if (data === PKT1_HEAD) head_n = head_n + 1;
        if (data === PKT1_BODY) body_n = body_n + 1;
        if (data === PKT1_TAIL) tail_n = tail_n + 1;
      end
    end
  endtask

  initial begin
    next_slot = 0; count = 0; total = 0;
    enq1_head_n = 0; deq1_head_n = 0; enq1_body_n = 0; deq1_body_n = 0;
    enq1_tail_n = 0; deq1_tail_n = 0; s0_head_n = 0; s1_head_n = 0;
    enq0_head_n = 0; deq0_head_n = 0;
    last_enq1 = 28'hx; last_deq1 = 28'hx; last_enq0 = 28'hx; last_deq0 = 28'hx;
    last_s0 = 28'hx; last_s1 = 28'hx;
    last_enq1_req = 1'bx; last_enq1_ack = 1'bx;
    last_deq1_req = 1'bx; last_deq1_ack = 1'bx;
    last_enq0_req = 1'bx; last_enq0_ack = 1'bx;
    last_deq0_req = 1'bx; last_deq0_ack = 1'bx;
    last_s0_req = 1'bx; last_s0_ack = 1'bx;
    last_s1_req = 1'bx; last_s1_ack = 1'bx;
    $display("CMR_UPFIFO_MAP upward_1=L1(1,1).parent1 -> L2.child0.lane1=IPM1");
    $display("CMR_UPFIFO_MAP upward=L1(1,1).parent0 -> L2.child0.lane0=IPM0");
    $display("CMR_UPFIFO_MAP watch head=%h body=%h tail=%h victim=%h",
             PKT1_HEAD, PKT1_BODY, PKT1_TAIL, TARGET_HEAD);
  end

  always @(enq1_req or enq1_ack or enq1_data) begin
    if ((enq1_req !== last_enq1_req) || (enq1_ack !== last_enq1_ack) ||
        (enq1_data !== last_enq1)) begin
      record("ENQ1", enq1_req, enq1_ack, enq1_data);
      note_data(last_enq1, enq1_data, enq1_head_n, enq1_body_n, enq1_tail_n);
      last_enq1 = enq1_data; last_enq1_req = enq1_req; last_enq1_ack = enq1_ack;
    end
  end

  always @(deq1_req or deq1_ack or deq1_data) begin
    if ((deq1_req !== last_deq1_req) || (deq1_ack !== last_deq1_ack) ||
        (deq1_data !== last_deq1)) begin
      record("DEQ1", deq1_req, deq1_ack, deq1_data);
      note_data(last_deq1, deq1_data, deq1_head_n, deq1_body_n, deq1_tail_n);
      last_deq1 = deq1_data; last_deq1_req = deq1_req; last_deq1_ack = deq1_ack;
    end
  end

  always @(enq0_req or enq0_ack or enq0_data) begin
    if ((enq0_req !== last_enq0_req) || (enq0_ack !== last_enq0_ack) ||
        (enq0_data !== last_enq0)) begin
      record("ENQ0", enq0_req, enq0_ack, enq0_data);
      if ((enq0_data !== last_enq0) && (enq0_data === PKT1_HEAD))
        enq0_head_n = enq0_head_n + 1;
      last_enq0 = enq0_data; last_enq0_req = enq0_req; last_enq0_ack = enq0_ack;
    end
  end

  always @(deq0_req or deq0_ack or deq0_data) begin
    if ((deq0_req !== last_deq0_req) || (deq0_ack !== last_deq0_ack) ||
        (deq0_data !== last_deq0)) begin
      record("DEQ0", deq0_req, deq0_ack, deq0_data);
      if ((deq0_data !== last_deq0) && (deq0_data === PKT1_HEAD))
        deq0_head_n = deq0_head_n + 1;
      last_deq0 = deq0_data; last_deq0_req = deq0_req; last_deq0_ack = deq0_ack;
    end
  end

  always @(s0_req or s0_ack or s0_data) begin
    if ((s0_req !== last_s0_req) || (s0_ack !== last_s0_ack) ||
        (s0_data !== last_s0)) begin
      record("S0", s0_req, s0_ack, s0_data);
      if ((s0_data !== last_s0) && (s0_data === PKT1_HEAD))
        s0_head_n = s0_head_n + 1;
      last_s0 = s0_data; last_s0_req = s0_req; last_s0_ack = s0_ack;
    end
  end

  always @(s1_req or s1_ack or s1_data) begin
    if ((s1_req !== last_s1_req) || (s1_ack !== last_s1_ack) ||
        (s1_data !== last_s1)) begin
      record("S1", s1_req, s1_ack, s1_data);
      if ((s1_data !== last_s1) && (s1_data === PKT1_HEAD))
        s1_head_n = s1_head_n + 1;
      last_s1 = s1_data; last_s1_req = s1_req; last_s1_ack = s1_ack;
    end
  end

  always @(posedge trigger) begin
    $display("CMR_UPFIFO_DUMP t_ns=%0.3f retained=%0d total=%0d",
             $realtime, count, total);
    $display("CMR_UPFIFO_COUNT ENQ1 head/body/tail=%0d/%0d/%0d DEQ1=%0d/%0d/%0d S0head=%0d S1head=%0d ENQ0head=%0d DEQ0head=%0d",
             enq1_head_n, enq1_body_n, enq1_tail_n,
             deq1_head_n, deq1_body_n, deq1_tail_n,
             s0_head_n, s1_head_n, enq0_head_n, deq0_head_n);
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      $display("CMR_UPFIFO_RING seq=%0d t_ns=%0.3f site=%0s r/a=%b/%b offer=%b ht=%b%b data=%h",
               total - count + dump_i, event_time[dump_slot], event_site[dump_slot],
               event_req[dump_slot], event_ack[dump_slot], event_offer[dump_slot],
               event_data[dump_slot][27], event_data[dump_slot][26],
               event_data[dump_slot]);
    end
  end

`undef FIFO
`undef DUT
endmodule

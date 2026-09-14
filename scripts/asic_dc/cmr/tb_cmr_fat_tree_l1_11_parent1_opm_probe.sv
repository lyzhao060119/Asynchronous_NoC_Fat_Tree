`timescale 1ns/1ps

// Read-only L1(1,1) parent lane1 OPM probe (OutputPortModules_5).
// That pin is the enqueue of upward_1, which feeds L2 child dir0 lane1.
// Question: does Head 8200202 leave with a real Req/Ack offer, or only as
// idle bundled-data while PPE/Grant already opened the mux?
module tb_cmr_fat_tree_l1_11_parent1_opm_probe;
  localparam [27:0] PKT1_HEAD = 28'h8200202;
  localparam [27:0] PKT1_BODY = 28'h0200202;
  localparam [27:0] PKT1_TAIL = 28'h4200202;
  localparam integer DEPTH = 2048;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
`define L1  `DUT.routerL1_1_1
`define OPM `L1.OutputPortModules_5
`define IPM0 `L1.InputPortModules_0
`define IPM1 `L1.InputPortModules_1
`define IPM2 `L1.InputPortModules_2
`define IPM3 `L1.InputPortModules_3
`define AR0 `IPM0.RouteComputationUnit.AddressRegister
`define AR1 `IPM1.RouteComputationUnit.AddressRegister
`define AR2 `IPM2.RouteComputationUnit.AddressRegister
`define AR3 `IPM3.RouteComputationUnit.AddressRegister
`define RCU0 `IPM0.RouteComputationUnit
`define RCU1 `IPM1.RouteComputationUnit
`define RCU2 `IPM2.RouteComputationUnit
`define RCU3 `IPM3.RouteComputationUnit

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire reqout = `DUT.routerL1_1_1_io_outputs_parent_1_HS_Req;
  wire ackin  = `DUT.upward_1_io_enq_HS_Ack;
  wire [27:0] dataout = `DUT.routerL1_1_1_io_outputs_parent_1_Data_flit;

  wire [3:0] ppe = {`L1.OutputPortModules_5_io_PktPathEnable_3,
                    `L1.OutputPortModules_5_io_PktPathEnable_2,
                    `L1.OutputPortModules_5_io_PktPathEnable_1,
                    `L1.OutputPortModules_5_io_PktPathEnable_0};
  wire [3:0] gnt = {`L1.OutputPortModules_5_io_Grant_3,
                    `L1.OutputPortModules_5_io_Grant_2,
                    `L1.OutputPortModules_5_io_Grant_1,
                    `L1.OutputPortModules_5_io_Grant_0};
  wire [3:0] tp  = {`L1.OutputPortModules_5_io_TailPassed_3,
                    `L1.OutputPortModules_5_io_TailPassed_2,
                    `L1.OutputPortModules_5_io_TailPassed_1,
                    `L1.OutputPortModules_5_io_TailPassed_0};
  wire [3:0] reqin = {`L1.adapter_3_Reqout[1], `L1.adapter_2_Reqout[1],
                     `L1.adapter_1_Reqout[1], `L1.adapter_Reqout[1]};
  wire [3:0] cmt  = {`L1.adapter_3_Commit[1], `L1.adapter_2_Commit[1],
                     `L1.adapter_1_Commit[1], `L1.adapter_Commit[1]};
  wire [3:0] lsel = {`L1.adapter_3_LaneSelect[1], `L1.adapter_2_LaneSelect[1],
                     `L1.adapter_1_LaneSelect[1], `L1.adapter_LaneSelect[1]};
  wire [3:0] mg = gnt & ~tp;

  wire [3:0] pe3 = {`L1.InputPortModules_3_io_PathEnabled_3,
                    `L1.InputPortModules_2_io_PathEnabled_3,
                    `L1.InputPortModules_1_io_PathEnabled_3,
                    `L1.InputPortModules_0_io_PathEnabled_3};
  wire [3:0] r3  = {`L1.InputPortModules_3_io_Reqout_3,
                    `L1.InputPortModules_2_io_Reqout_3,
                    `L1.InputPortModules_1_io_Reqout_3,
                    `L1.InputPortModules_0_io_Reqout_3};
  wire [27:0] d3_0 = `L1.InputPortModules_0_io_Dataout_3_flit;
  wire [27:0] d3_1 = `L1.InputPortModules_1_io_Dataout_3_flit;
  wire [27:0] d3_2 = `L1.InputPortModules_2_io_Dataout_3_flit;
  wire [27:0] d3_3 = `L1.InputPortModules_3_io_Dataout_3_flit;

  wire in0_req = `IPM0.io_Reqin;
  wire in1_req = `IPM1.io_Reqin;
  wire in2_req = `IPM2.io_Reqin;
  wire in3_req = `IPM3.io_Reqin;
  wire in0_ack = `IPM0.io_Ackout;
  wire in1_ack = `IPM1.io_Ackout;
  wire in2_ack = `IPM2.io_Ackout;
  wire in3_ack = `IPM3.io_Ackout;
  wire [27:0] in0_data = `IPM0.io_Datain_flit;
  wire [27:0] in1_data = `IPM1.io_Datain_flit;
  wire [27:0] in2_data = `IPM2.io_Datain_flit;
  wire [27:0] in3_data = `IPM3.io_Datain_flit;

  wire en0 = `AR0.En;
  wire en1 = `AR1.En;
  wire en2 = `AR2.En;
  wire en3 = `AR3.En;
  wire [23:0] dest0 = `AR0.dest;
  wire [23:0] dest1 = `AR1.dest;
  wire [23:0] dest2 = `AR2.dest;
  wire [23:0] dest3 = `AR3.dest;
  wire [3:0] rs0 = {`RCU0.io_RouteSel_3, `RCU0.io_RouteSel_2,
                    `RCU0.io_RouteSel_1, `RCU0.io_RouteSel_0};
  wire [3:0] rs1 = {`RCU1.io_RouteSel_3, `RCU1.io_RouteSel_2,
                    `RCU1.io_RouteSel_1, `RCU1.io_RouteSel_0};
  wire [3:0] rs2 = {`RCU2.io_RouteSel_3, `RCU2.io_RouteSel_2,
                    `RCU2.io_RouteSel_1, `RCU2.io_RouteSel_0};
  wire [3:0] rs3 = {`RCU3.io_RouteSel_3, `RCU3.io_RouteSel_2,
                    `RCU3.io_RouteSel_1, `RCU3.io_RouteSel_0};

  function automatic offer;
    input req;
    input ack;
    begin
      offer = ((req === 1'b0) || (req === 1'b1)) &&
              ((ack === 1'b0) || (ack === 1'b1)) &&
              (req !== ack);
    end
  endfunction

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  integer head_offer_n;
  integer head_idle_n;
  integer body_offer_n;
  integer tail_offer_n;
  integer second_head_idle;
  integer first_head_seen;
  realtime first_head_offer_ns;
  realtime second_head_idle_ns;
  realtime event_time [0:DEPTH-1];
  reg [27:0] event_data [0:DEPTH-1];
  reg event_req [0:DEPTH-1];
  reg event_ack [0:DEPTH-1];
  reg event_offer [0:DEPTH-1];
  reg [3:0] event_ppe [0:DEPTH-1];
  reg [3:0] event_gnt [0:DEPTH-1];
  reg [3:0] event_tp [0:DEPTH-1];
  reg [3:0] event_reqin [0:DEPTH-1];
  reg [3:0] event_cmt [0:DEPTH-1];
  reg [3:0] event_lsel [0:DEPTH-1];
  reg [3:0] event_pe3 [0:DEPTH-1];
  reg [3:0] event_r3 [0:DEPTH-1];
  reg [27:0] event_d3s [0:DEPTH-1][0:3];
  reg [3:0] event_en [0:DEPTH-1];
  reg [3:0] event_in_offer [0:DEPTH-1];
  reg [27:0] event_in [0:DEPTH-1][0:3];
  reg [3:0] event_rs [0:DEPTH-1][0:3];
  reg [23:0] event_dest [0:DEPTH-1][0:3];

  wire opm_offer = offer(reqout, ackin);
  wire [3:0] en = {en3, en2, en1, en0};
  wire [3:0] in_offer = {offer(in3_req, in3_ack), offer(in2_req, in2_ack),
                         offer(in1_req, in1_ack), offer(in0_req, in0_ack)};

  reg last_reqout, last_ackin;
  reg [27:0] last_dataout;
  reg [3:0] last_ppe, last_gnt, last_tp, last_reqin, last_cmt, last_lsel;
  reg [3:0] last_pe3, last_r3, last_en, last_in_offer;
  reg [27:0] last_d3_0, last_d3_1, last_d3_2, last_d3_3;
  reg [27:0] last_in0, last_in1, last_in2, last_in3;
  reg [3:0] last_rs0, last_rs1, last_rs2, last_rs3;

  task automatic emit;
    input string tag;
    begin
      $display("CMR_L1P1 t_ns=%0.3f %0s r/a=%b/%b offer=%b ht=%b%b data=%h ppe=%b gnt=%b tp=%b mg=%b reqin=%b cmt=%b lsel=%b",
               $realtime, tag, reqout, ackin, opm_offer, dataout[27], dataout[26],
               dataout, ppe, gnt, tp, mg, reqin, cmt, lsel);
      $display("CMR_L1IPM t_ns=%0.3f %0s pe3=%b r3=%b en=%b in_off=%b d3={%h,%h,%h,%h} in={%h,%h,%h,%h} dest={%h,%h,%h,%h} rs={%b,%b,%b,%b}",
               $realtime, tag, pe3, r3, en, in_offer,
               d3_3, d3_2, d3_1, d3_0, in3_data, in2_data, in1_data, in0_data,
               dest3, dest2, dest1, dest0, rs3, rs2, rs1, rs0);
    end
  endtask

  task automatic record;
    integer slot;
    begin
      slot = next_slot;
      event_time[slot] = $realtime;
      event_data[slot] = dataout;
      event_req[slot] = reqout;
      event_ack[slot] = ackin;
      event_offer[slot] = opm_offer;
      event_ppe[slot] = ppe;
      event_gnt[slot] = gnt;
      event_tp[slot] = tp;
      event_reqin[slot] = reqin;
      event_cmt[slot] = cmt;
      event_lsel[slot] = lsel;
      event_pe3[slot] = pe3;
      event_r3[slot] = r3;
      event_d3s[slot][0] = d3_0;
      event_d3s[slot][1] = d3_1;
      event_d3s[slot][2] = d3_2;
      event_d3s[slot][3] = d3_3;
      event_en[slot] = en;
      event_in_offer[slot] = in_offer;
      event_in[slot][0] = in0_data;
      event_in[slot][1] = in1_data;
      event_in[slot][2] = in2_data;
      event_in[slot][3] = in3_data;
      event_rs[slot][0] = rs0;
      event_rs[slot][1] = rs1;
      event_rs[slot][2] = rs2;
      event_rs[slot][3] = rs3;
      event_dest[slot][0] = dest0;
      event_dest[slot][1] = dest1;
      event_dest[slot][2] = dest2;
      event_dest[slot][3] = dest3;
      next_slot = (next_slot + 1) % DEPTH;
      count = (count < DEPTH) ? count + 1 : DEPTH;
      total = total + 1;
    end
  endtask

  task automatic note_head;
    begin
      if (dataout === PKT1_HEAD && dataout !== last_dataout) begin
        if (opm_offer) begin
          head_offer_n = head_offer_n + 1;
          if (!first_head_seen) begin
            first_head_seen = 1;
            first_head_offer_ns = $realtime;
          end
        end else begin
          head_idle_n = head_idle_n + 1;
          if (first_head_seen && !second_head_idle) begin
            second_head_idle = 1;
            second_head_idle_ns = $realtime;
          end
        end
      end
      if ((dataout === PKT1_BODY) && (dataout !== last_dataout) && opm_offer)
        body_offer_n = body_offer_n + 1;
      if ((dataout === PKT1_TAIL) && (dataout !== last_dataout) && opm_offer)
        tail_offer_n = tail_offer_n + 1;
    end
  endtask

  function automatic changed;
    input integer dummy;
    begin
      changed = (reqout !== last_reqout) || (ackin !== last_ackin) ||
                (dataout !== last_dataout) || (ppe !== last_ppe) ||
                (gnt !== last_gnt) || (tp !== last_tp) ||
                (reqin !== last_reqin) || (cmt !== last_cmt) ||
                (lsel !== last_lsel) || (pe3 !== last_pe3) ||
                (r3 !== last_r3) || (en !== last_en) ||
                (in_offer !== last_in_offer) ||
                (d3_0 !== last_d3_0) || (d3_1 !== last_d3_1) ||
                (d3_2 !== last_d3_2) || (d3_3 !== last_d3_3) ||
                (in0_data !== last_in0) || (in1_data !== last_in1) ||
                (in2_data !== last_in2) || (in3_data !== last_in3) ||
                (rs0 !== last_rs0) || (rs1 !== last_rs1) ||
                (rs2 !== last_rs2) || (rs3 !== last_rs3);
    end
  endfunction

  task automatic sample;
    begin
      if (changed(0)) begin
        note_head();
        record();
        if (($realtime >= 220.0 && $realtime <= 330.0) ||
            (dataout === PKT1_HEAD) || (dataout === PKT1_BODY) ||
            (dataout === PKT1_TAIL))
          emit("LIVE");
        last_reqout = reqout; last_ackin = ackin; last_dataout = dataout;
        last_ppe = ppe; last_gnt = gnt; last_tp = tp; last_reqin = reqin;
        last_cmt = cmt; last_lsel = lsel; last_pe3 = pe3; last_r3 = r3;
        last_en = en; last_in_offer = in_offer;
        last_d3_0 = d3_0; last_d3_1 = d3_1; last_d3_2 = d3_2; last_d3_3 = d3_3;
        last_in0 = in0_data; last_in1 = in1_data;
        last_in2 = in2_data; last_in3 = in3_data;
        last_rs0 = rs0; last_rs1 = rs1; last_rs2 = rs2; last_rs3 = rs3;
      end
    end
  endtask

  initial begin
    next_slot = 0; count = 0; total = 0;
    head_offer_n = 0; head_idle_n = 0; body_offer_n = 0; tail_offer_n = 0;
    second_head_idle = 0; first_head_seen = 0;
    first_head_offer_ns = 0; second_head_idle_ns = 0;
    last_reqout = 1'bx; last_ackin = 1'bx; last_dataout = 28'hx;
    last_ppe = 4'hx; last_gnt = 4'hx; last_tp = 4'hx; last_reqin = 4'hx;
    last_cmt = 4'hx; last_lsel = 4'hx; last_pe3 = 4'hx; last_r3 = 4'hx;
    last_en = 4'hx; last_in_offer = 4'hx;
    last_d3_0 = 28'hx; last_d3_1 = 28'hx; last_d3_2 = 28'hx; last_d3_3 = 28'hx;
    last_in0 = 28'hx; last_in1 = 28'hx; last_in2 = 28'hx; last_in3 = 28'hx;
    last_rs0 = 4'hx; last_rs1 = 4'hx; last_rs2 = 4'hx; last_rs3 = 4'hx;
    $display("CMR_L1P1_MAP L1(1,1).parent1=OutputPortModules_5 -> upward_1");
    $display("CMR_L1P1_MAP child IPM0/1/2/3 = cores 15/11/14/10, parent branch=3");
    $display("CMR_L1P1_MAP watch head=%h body=%h tail=%h",
             PKT1_HEAD, PKT1_BODY, PKT1_TAIL);
  end

  always @(reqout or ackin or dataout or ppe or gnt or tp or reqin or cmt or
           lsel or pe3 or r3 or en or in_offer or d3_0 or d3_1 or d3_2 or d3_3 or
           in0_data or in1_data or in2_data or in3_data or
           in0_req or in1_req or in2_req or in3_req or
           in0_ack or in1_ack or in2_ack or in3_ack or
           rs0 or rs1 or rs2 or rs3 or dest0 or dest1 or dest2 or dest3)
    sample();

  always @(posedge trigger) begin
    $display("CMR_L1P1_DUMP t_ns=%0.3f retained=%0d total=%0d",
             $realtime, count, total);
    $display("CMR_L1P1_COUNT head_offer=%0d head_idle=%0d body_offer=%0d tail_offer=%0d first_offer_ns=%0.3f second_idle_ns=%0.3f",
             head_offer_n, head_idle_n, body_offer_n, tail_offer_n,
             first_head_offer_ns, second_head_idle_ns);
    if (head_idle_n > 0)
      $display("CMR_L1P1_VERDICT header_not_issued idle_dataout_head=%0d (Req==Ack while Dataout=Head)",
               head_idle_n);
    else
      $display("CMR_L1P1_VERDICT header_issued_with_req head_offer=%0d",
               head_offer_n);
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      if ((event_time[dump_slot] >= 220.0 && event_time[dump_slot] <= 330.0) ||
          (event_data[dump_slot] === PKT1_HEAD) ||
          (event_data[dump_slot] === PKT1_BODY) ||
          (event_data[dump_slot] === PKT1_TAIL)) begin
        $display("CMR_L1P1_RING seq=%0d t_ns=%0.3f r/a=%b/%b offer=%b ht=%b%b data=%h ppe=%b gnt=%b tp=%b reqin=%b cmt=%b lsel=%b pe3=%b r3=%b en=%b in_off=%b d3={%h,%h,%h,%h}",
                 total - count + dump_i, event_time[dump_slot],
                 event_req[dump_slot], event_ack[dump_slot], event_offer[dump_slot],
                 event_data[dump_slot][27], event_data[dump_slot][26],
                 event_data[dump_slot], event_ppe[dump_slot], event_gnt[dump_slot],
                 event_tp[dump_slot], event_reqin[dump_slot], event_cmt[dump_slot],
                 event_lsel[dump_slot], event_pe3[dump_slot], event_r3[dump_slot],
                 event_en[dump_slot], event_in_offer[dump_slot],
                 event_d3s[dump_slot][3], event_d3s[dump_slot][2],
                 event_d3s[dump_slot][1], event_d3s[dump_slot][0]);
      end
    end
  end

`undef RCU3
`undef RCU2
`undef RCU1
`undef RCU0
`undef AR3
`undef AR2
`undef AR1
`undef AR0
`undef IPM3
`undef IPM2
`undef IPM1
`undef IPM0
`undef OPM
`undef L1
`undef DUT
endmodule

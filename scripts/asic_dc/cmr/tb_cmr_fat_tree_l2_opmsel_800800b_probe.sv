`timescale 1ns/1ps

// Full RCU/AddressRegister/OPMSelector probe for L2 IPM1.
// Dumps En, Req_pc, Req_rc, Ack_rc, Mat, RouteSel, TailPassed, PathEnabled.
module tb_cmr_fat_tree_l2_opmsel_800800b_probe;
  localparam [27:0] TARGET_HEAD = 28'h800800b;
  localparam [23:0] LEGAL_DEST = 24'h002002;
  localparam integer DEPTH = 1024;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
`define L2  `DUT.routerL2
`define IPM `L2.InputPortModules_1
`define RCU `IPM.RouteComputationUnit
`define AR  `RCU.AddressRegister
`define HP  `AR.HeadPredictorBlock
`define PS  `AR.PhaseSelectorBlock
`define SEL `RCU.Selector
`define RC  `RCU.RouteComputation
`define IA  `RC.InternalAck

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire sel_reset = `SEL.reset;
  wire en = `AR.En;
  wire req_pc = `PS.Req_pc;
  wire req_rc = `AR.Req_rc;
  wire ack_rc = `IA.Ack_rc;
  wire route_or = `IA.RouteSelected;
  wire hp_complete = `HP.complete;
  wire ps_complete = `PS.complete;
  wire ph_en = `PS.phEn;
  wire phase = `PS.phase;
  wire ar_reqin = `AR.Reqin;
  wire ar_ackout = `AR.Ackout;
  wire ar_head = `AR.Head;
  wire ar_tail = `AR.Tail;
  wire [23:0] dest = `AR.dest;
  wire [3:0] mat = {`RCU.io_Mat_3, `RCU.io_Mat_2, `RCU.io_Mat_1, `RCU.io_Mat_0};
  wire [3:0] rs = `SEL.RouteSel;
  wire [3:0] tp = `SEL.TailPassed;
  wire [3:0] pe = `SEL.PathEnabled;
  wire [3:0] ipm_tp = {`IPM.io_TailPassed_3, `IPM.io_TailPassed_2,
                       `IPM.io_TailPassed_1, `IPM.io_TailPassed_0};
  wire bundle = `RC.BundlingSignal;
  wire delay_z = `RC.MatchedDelay_Z;
  wire [27:0] ipm_data = `IPM.io_Datain_flit;
  wire ipm_req = `IPM.io_Reqin;
  wire ipm_ack = `IPM.io_Ackout;
  wire head = ipm_data[27];
  wire tail = ipm_data[26];
  wire offer = ((ipm_req === 1'b0) || (ipm_req === 1'b1)) &&
               ((ipm_ack === 1'b0) || (ipm_ack === 1'b1)) &&
               (ipm_req !== ipm_ack);

  wire [1:0] cmt_d1 = `L2.adapter_4.Commit;
  wire [1:0] cmt_d2 = `L2.adapter_5.Commit;
  wire [1:0] cmt_d3 = `L2.adapter_6.Commit;
  wire [1:0] otp_d1 = {`L2.OutputPortModules_3_io_TailPassed_1,
                       `L2.OutputPortModules_2_io_TailPassed_1};
  wire [1:0] otp_d2 = {`L2.OutputPortModules_5_io_TailPassed_1,
                       `L2.OutputPortModules_4_io_TailPassed_1};
  wire [1:0] otp_d3 = {`L2.OutputPortModules_7_io_TailPassed_1,
                       `L2.OutputPortModules_6_io_TailPassed_1};
  wire [1:0] gnt_d1 = {`L2.OutputPortModules_3_io_Grant_1,
                       `L2.OutputPortModules_2_io_Grant_1};
  wire [1:0] gnt_d2 = {`L2.OutputPortModules_5_io_Grant_1,
                       `L2.OutputPortModules_4_io_Grant_1};
  wire [1:0] gnt_d3 = {`L2.OutputPortModules_7_io_Grant_1,
                       `L2.OutputPortModules_6_io_Grant_1};
  wire [1:0] ppe_d1 = {`L2.OutputPortModules_3_io_PktPathEnable_1,
                       `L2.OutputPortModules_2_io_PktPathEnable_1};
  wire [1:0] ppe_d2 = {`L2.OutputPortModules_5_io_PktPathEnable_1,
                       `L2.OutputPortModules_4_io_PktPathEnable_1};
  wire [1:0] ppe_d3 = {`L2.OutputPortModules_7_io_PktPathEnable_1,
                       `L2.OutputPortModules_6_io_PktPathEnable_1};

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  integer b;
  integer armed;
  integer target_seen;
  realtime event_time [0:DEPTH-1];
  reg [255:0] event_snap [0:DEPTH-1];
  reg [255:0] last_snap;
  reg [3:0] prev_rs;
  reg [3:0] prev_tp;
  reg [3:0] prev_pe;
  integer set_n [0:3];
  integer clr_n [0:3];
  integer rs_n [0:3];
  integer tp_n [0:3];
  realtime first_set [0:3];
  realtime last_clr [0:3];
  realtime last_rs [0:3];
  realtime last_tp [0:3];
  reg [23:0] first_set_dest [0:3];
  reg [27:0] first_set_data [0:3];
  reg first_set_en [0:3];
  reg [3:0] first_set_mat [0:3];
  reg [3:0] first_set_rs [0:3];
  realtime leftover_at_target [0:3];

  wire [255:0] snap = {
    dest, mat, rs, tp, pe, ipm_tp,
    en, req_pc, req_rc, ack_rc, route_or,
    hp_complete, ps_complete, ph_en, phase,
    bundle, delay_z, head, tail, ipm_req, ipm_ack,
    ipm_data,
    cmt_d1, cmt_d2, cmt_d3,
    otp_d1, otp_d2, otp_d3,
    gnt_d1, gnt_d2, gnt_d3,
    ppe_d1, ppe_d2, ppe_d3
  };

  task automatic emit;
    input string tag;
    begin
      $display("CMR_AR t_ns=%0.3f %0s En=%b Req_pc=%b Req_rc=%b Ack_rc=%b delayz=%b bundle=%b routeOr=%b hp_c=%b ps_c=%b phEn=%b phase=%b ar_r/a=%b/%b ar_ht=%b%b",
               $realtime, tag, en, req_pc, req_rc, ack_rc, delay_z, bundle, route_or,
               hp_complete, ps_complete, ph_en, phase, ar_reqin, ar_ackout, ar_head, ar_tail);
      $display("CMR_RCU t_ns=%0.3f %0s dest=%h legal=%b mat=%b rs=%b tp=%b pe=%b ipm_tp=%b in_r/a=%b/%b ht=%b%b data=%h",
               $realtime, tag, dest, (dest === LEGAL_DEST), mat, rs, tp, pe, ipm_tp,
               ipm_req, ipm_ack, head, tail, ipm_data);
      $display("CMR_OPM t_ns=%0.3f %0s d1(cmt/otp/gnt/ppe)=%b/%b/%b/%b d2=%b/%b/%b/%b d3=%b/%b/%b/%b leftover=%b",
               $realtime, tag,
               cmt_d1, otp_d1, gnt_d1, ppe_d1,
               cmt_d2, otp_d2, gnt_d2, ppe_d2,
               cmt_d3, otp_d3, gnt_d3, ppe_d3,
               (|pe[3:1]));
    end
  endtask

  task automatic record;
    integer slot;
    begin
      slot = next_slot;
      event_time[slot] = $realtime;
      event_snap[slot] = snap;
      next_slot = (next_slot + 1) % DEPTH;
      count = (count < DEPTH) ? count + 1 : DEPTH;
      total = total + 1;
      last_snap = snap;
    end
  endtask

  task automatic note_edges;
    begin
      for (b = 0; b < 4; b = b + 1) begin
        if ((rs[b] === 1'b1) && (prev_rs[b] !== 1'b1)) begin
          rs_n[b] = rs_n[b] + 1;
          last_rs[b] = $realtime;
        end
        if ((tp[b] === 1'b1) && (prev_tp[b] !== 1'b1)) begin
          tp_n[b] = tp_n[b] + 1;
          last_tp[b] = $realtime;
        end
        if ((pe[b] === 1'b1) && (prev_pe[b] !== 1'b1)) begin
          set_n[b] = set_n[b] + 1;
          if (set_n[b] == 1) begin
            first_set[b] = $realtime;
            first_set_dest[b] = dest;
            first_set_data[b] = ipm_data;
            first_set_en[b] = en;
            first_set_mat[b] = mat;
            first_set_rs[b] = rs;
          end
        end
        if ((pe[b] === 1'b0) && (prev_pe[b] === 1'b1)) begin
          clr_n[b] = clr_n[b] + 1;
          last_clr[b] = $realtime;
        end
      end
      prev_rs = rs;
      prev_tp = tp;
      prev_pe = pe;
    end
  endtask

  initial begin
    next_slot = 0; count = 0; total = 0; armed = 0; target_seen = 0;
    last_snap = 256'bx;
    prev_rs = 4'b0; prev_tp = 4'b0; prev_pe = 4'b0;
    for (b = 0; b < 4; b = b + 1) begin
      set_n[b] = 0; clr_n[b] = 0; rs_n[b] = 0; tp_n[b] = 0;
      first_set[b] = 0; last_clr[b] = 0; last_rs[b] = 0; last_tp[b] = 0;
      first_set_dest[b] = 24'hx; first_set_data[b] = 28'hx;
      first_set_en[b] = 1'bx;
      first_set_mat[b] = 4'bx; first_set_rs[b] = 4'bx;
      leftover_at_target[b] = 0;
    end
    $display("CMR_OPMSEL_MAP IPM1=child_dir0_lane1 S=RouteSel R=TailPassed Q=PathEnabled");
    $display("CMR_OPMSEL_MAP b0=dir1/adapter_4 legal b1=dir2/adapter_5 illegal b2=dir3/adapter_6 b3=parent");
  end

  always @(sel_reset) begin
    if (sel_reset === 1'b1) begin
      armed = 0;
      prev_rs = 4'b0; prev_tp = 4'b0; prev_pe = 4'b0;
    end else if (sel_reset === 1'b0) begin
      armed = 1;
      emit("RESET_REL");
      record();
    end
  end

  always @(en or req_pc or req_rc or ack_rc or route_or or hp_complete or
           ps_complete or ph_en or phase or dest or mat or rs or tp or pe or
           bundle or delay_z or ipm_req or ipm_ack or ipm_data or otp_d1 or
           otp_d2 or otp_d3 or cmt_d1 or cmt_d2 or cmt_d3) begin
    if (armed) begin
      if (snap !== last_snap) begin
        record();
        note_edges();
        emit("CHG");
      end
      if (offer && (ipm_data === TARGET_HEAD) && !target_seen) begin
        target_seen = 1;
        for (b = 0; b < 4; b = b + 1)
          if (pe[b] === 1'b1) leftover_at_target[b] = $realtime;
        emit("HEAD");
      end
    end
  end

  always @(posedge trigger) begin
    emit("FAIL");
    $display("CMR_OPMSEL_DUMP t_ns=%0.3f retained=%0d total=%0d armed=%0d target=%0d En=%b Req_pc=%b Req_rc=%b Ack_rc=%b pe=%b rs=%b tp=%b",
             $realtime, count, total, armed, target_seen, en, req_pc, req_rc, ack_rc, pe, rs, tp);
    for (b = 0; b < 4; b = b + 1)
      $display("CMR_OPMSEL_HIST branch=%0d set_n=%0d first_set_ns=%0.3f first_dest=%h first_data=%h first_en=%b first_mat=%b first_rs=%b clr_n=%0d last_clr_ns=%0.3f rs_n=%0d last_rs_ns=%0.3f tp_n=%0d last_tp_ns=%0.3f pe_at_head=%b",
               b, set_n[b], first_set[b], first_set_dest[b], first_set_data[b],
               first_set_en[b], first_set_mat[b], first_set_rs[b], clr_n[b], last_clr[b],
               rs_n[b], last_rs[b], tp_n[b], last_tp[b],
               (leftover_at_target[b] != 0));
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      $display("CMR_OPMSEL_RING seq=%0d t_ns=%0.3f snap=%h",
               total - count + dump_i, event_time[dump_slot], event_snap[dump_slot]);
    end
  end

`undef IA
`undef RC
`undef SEL
`undef PS
`undef HP
`undef AR
`undef RCU
`undef IPM
`undef L2
`undef DUT
endmodule

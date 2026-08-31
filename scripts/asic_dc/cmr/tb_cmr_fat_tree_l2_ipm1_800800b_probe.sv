`timescale 1ns/1ps

// Read-only L2 internals for TAB head 800800b entering child dir0 lane1.
// IPM1 legal branches: 0=dir1 (core2), 1=dir2 (core8), 2=dir3, 3=parent.
// Fat-tree adapters: adapter_4=dir1, adapter_5=dir2, adapter_6=dir3.
module tb_cmr_fat_tree_l2_ipm1_800800b_probe;
  localparam [27:0] TARGET_HEAD = 28'h800800b;
  localparam [23:0] LEGAL_DEST = 24'h002002;
  localparam integer DEPTH = 256;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut
`define L2  `DUT.routerL2
`define IPM `L2.InputPortModules_1
`define RCU `IPM.RouteComputationUnit
`define RC  `RCU.RouteComputation

  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;

  wire ipm_req = `IPM.io_Reqin;
  wire ipm_ack = `IPM.io_Ackout;
  wire [27:0] ipm_data = `IPM.io_Datain_flit;
  wire req_rc = `RCU.AddressRegister_Req_rc;
  wire [23:0] dest = `RCU.AddressRegister_dest;
  wire [3:0] mat = {`RCU.io_Mat_3, `RCU.io_Mat_2, `RCU.io_Mat_1, `RCU.io_Mat_0};
  wire [3:0] routesel = {`RCU.io_RouteSel_3, `RCU.io_RouteSel_2,
                         `RCU.io_RouteSel_1, `RCU.io_RouteSel_0};
  wire [3:0] path = {`IPM.io_PathEnabled_3, `IPM.io_PathEnabled_2,
                     `IPM.io_PathEnabled_1, `IPM.io_PathEnabled_0};
  wire [3:0] reqout = {`IPM.io_Reqout_3, `IPM.io_Reqout_2,
                       `IPM.io_Reqout_1, `IPM.io_Reqout_0};
  wire bundle = `RC.BundlingSignal;
  wire delay_z = `RC.MatchedDelay_Z;
  wire ack_rc = `RC.InternalAck_Ack_rc;

  wire [1:0] sel_d1 = `L2.adapter_4.LaneSelect;
  wire [1:0] sel_d2 = `L2.adapter_5.LaneSelect;
  wire [1:0] sel_d3 = `L2.adapter_6.LaneSelect;
  wire [1:0] cmt_d1 = `L2.adapter_4.Commit;
  wire [1:0] cmt_d2 = `L2.adapter_5.Commit;
  wire [1:0] cmt_d3 = `L2.adapter_6.Commit;
  wire [1:0] arq_d1 = `L2.adapter_4.Reqout;
  wire [1:0] arq_d2 = `L2.adapter_5.Reqout;
  wire [1:0] arq_d3 = `L2.adapter_6.Reqout;
  wire [1:0] aack_d1 = `L2.adapter_4.Ackin;
  wire [1:0] aack_d2 = `L2.adapter_5.Ackin;
  wire [1:0] aack_d3 = `L2.adapter_6.Ackin;
  wire adp_ack_d1 = `L2.adapter_4.Ackout;
  wire adp_ack_d2 = `L2.adapter_5.Ackout;
  wire adp_ack_d3 = `L2.adapter_6.Ackout;

  // OPM source 1 is IPM1.  dir1=OPM2/3, dir2=OPM4/5, dir3=OPM6/7.
  wire [1:0] ppe_d1 = {`L2.OutputPortModules_3_io_PktPathEnable_1,
                       `L2.OutputPortModules_2_io_PktPathEnable_1};
  wire [1:0] ppe_d2 = {`L2.OutputPortModules_5_io_PktPathEnable_1,
                       `L2.OutputPortModules_4_io_PktPathEnable_1};
  wire [1:0] ppe_d3 = {`L2.OutputPortModules_7_io_PktPathEnable_1,
                       `L2.OutputPortModules_6_io_PktPathEnable_1};
  wire [1:0] gnt_d1 = {`L2.OutputPortModules_3_io_Grant_1,
                       `L2.OutputPortModules_2_io_Grant_1};
  wire [1:0] gnt_d2 = {`L2.OutputPortModules_5_io_Grant_1,
                       `L2.OutputPortModules_4_io_Grant_1};
  wire [1:0] gnt_d3 = {`L2.OutputPortModules_7_io_Grant_1,
                       `L2.OutputPortModules_6_io_Grant_1};

  wire offer = ((ipm_req === 1'b0) || (ipm_req === 1'b1)) &&
               ((ipm_ack === 1'b0) || (ipm_ack === 1'b1)) &&
               (ipm_req !== ipm_ack) && (ipm_data === TARGET_HEAD);

  integer next_slot;
  integer count;
  integer total;
  integer dump_i;
  integer dump_slot;
  reg live;
  realtime event_time [0:DEPTH-1];
  reg [127:0] event_snap [0:DEPTH-1];
  reg [127:0] last_snap;

  wire [127:0] snap = {
    dest, req_rc, bundle, delay_z, ack_rc,
    mat, routesel, path, reqout,
    sel_d1, sel_d2, sel_d3,
    cmt_d1, cmt_d2, cmt_d3,
    arq_d1, arq_d2, arq_d3,
    ppe_d1, ppe_d2, ppe_d3,
    gnt_d1, gnt_d2, gnt_d3,
    ipm_req, ipm_ack
  };

  task automatic emit;
    input string tag;
    begin
      $display("CMR_L2IPM1 t_ns=%0.3f %0s dest=%h legal=%b req_rc=%b mat=%b rs=%b path=%b reqout=%b bundle=%b delayz=%b ack_rc=%b in_r/a=%b/%b data=%h",
               $realtime, tag, dest, (dest === LEGAL_DEST), req_rc, mat, routesel, path, reqout,
               bundle, delay_z, ack_rc, ipm_req, ipm_ack, ipm_data);
      $display("CMR_L2IPM1_ADAPT t_ns=%0.3f d1(sel/cmt/req/ackin/ackout)=%b/%b/%b/%b/%b d2=%b/%b/%b/%b/%b d3=%b/%b/%b/%b/%b",
               $realtime,
               sel_d1, cmt_d1, arq_d1, aack_d1, adp_ack_d1,
               sel_d2, cmt_d2, arq_d2, aack_d2, adp_ack_d2,
               sel_d3, cmt_d3, arq_d3, aack_d3, adp_ack_d3);
      $display("CMR_L2IPM1_PPE t_ns=%0.3f d1_ppe/gnt[l1:0]=%b/%b d2=%b/%b d3=%b/%b extra_path=%b extra_ppe_d2=%b extra_ppe_d3=%b",
               $realtime, ppe_d1, gnt_d1, ppe_d2, gnt_d2, ppe_d3, gnt_d3,
               (|path[3:1]), (|ppe_d2), (|ppe_d3));
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

  initial begin
    next_slot = 0; count = 0; total = 0; live = 1'b0; last_snap = 128'bx;
    $display("CMR_L2IPM1_MAP IPM1=child_dir0_lane1 dest(2,0) legal_mat=0001 branch0=dir1 adapter_4");
    $display("CMR_L2IPM1_MAP illegal_dir2=branch1 adapter_5 dir3=branch2 adapter_6 parent=branch3");
  end

  always @(ipm_req or ipm_ack or ipm_data)
    if (offer && !live) begin
      live = 1'b1;
      record();
      emit("HEAD");
    end

  always @(snap)
    if (live && (snap !== last_snap)) begin
      record();
      emit("CHG");
    end

  always @(posedge trigger) begin
    emit("FAIL");
    $display("CMR_L2IPM1_DUMP t_ns=%0.3f retained=%0d total=%0d live=%b",
             $realtime, count, total, live);
    for (dump_i = 0; dump_i < count; dump_i = dump_i + 1) begin
      dump_slot = ((count == DEPTH) ? next_slot : 0) + dump_i;
      if (dump_slot >= DEPTH) dump_slot = dump_slot - DEPTH;
      $display("CMR_L2IPM1_RING seq=%0d t_ns=%0.3f snap=%h",
               total - count + dump_i, event_time[dump_slot], event_snap[dump_slot]);
    end
  end

`undef RC
`undef RCU
`undef IPM
`undef L2
`undef DUT
endmodule

`timescale 1ns/1ps

// Read-only snapshot at the first TAB unexpected flit.  It never drives the DUT.
// Cross-module names are limited to nets already proven on this frozen
// fat-tree netlist by tb_cmr_fat_tree_phase_probe.
module tb_cmr_fat_tree_unexpected_probe;
  wire trigger = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_trigger;
  integer diagnostic_port;
  integer snap_port;
  integer snap_dir;
  integer snap_lane;

`define DUT $root.tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut

  wire [15:0] core_out_req = {
    `DUT.io_core_outputs_15_HS_Req, `DUT.io_core_outputs_14_HS_Req,
    `DUT.io_core_outputs_13_HS_Req, `DUT.io_core_outputs_12_HS_Req,
    `DUT.io_core_outputs_11_HS_Req, `DUT.io_core_outputs_10_HS_Req,
    `DUT.io_core_outputs_9_HS_Req,  `DUT.io_core_outputs_8_HS_Req,
    `DUT.io_core_outputs_7_HS_Req,  `DUT.io_core_outputs_6_HS_Req,
    `DUT.io_core_outputs_5_HS_Req,  `DUT.io_core_outputs_4_HS_Req,
    `DUT.io_core_outputs_3_HS_Req,  `DUT.io_core_outputs_2_HS_Req,
    `DUT.io_core_outputs_1_HS_Req,  `DUT.io_core_outputs_0_HS_Req
  };
  wire [15:0] core_out_ack = {
    `DUT.io_core_outputs_15_HS_Ack, `DUT.io_core_outputs_14_HS_Ack,
    `DUT.io_core_outputs_13_HS_Ack, `DUT.io_core_outputs_12_HS_Ack,
    `DUT.io_core_outputs_11_HS_Ack, `DUT.io_core_outputs_10_HS_Ack,
    `DUT.io_core_outputs_9_HS_Ack,  `DUT.io_core_outputs_8_HS_Ack,
    `DUT.io_core_outputs_7_HS_Ack,  `DUT.io_core_outputs_6_HS_Ack,
    `DUT.io_core_outputs_5_HS_Ack,  `DUT.io_core_outputs_4_HS_Ack,
    `DUT.io_core_outputs_3_HS_Ack,  `DUT.io_core_outputs_2_HS_Ack,
    `DUT.io_core_outputs_1_HS_Ack,  `DUT.io_core_outputs_0_HS_Ack
  };
  wire [447:0] core_out_data = {
    `DUT.io_core_outputs_15_Data_flit, `DUT.io_core_outputs_14_Data_flit,
    `DUT.io_core_outputs_13_Data_flit, `DUT.io_core_outputs_12_Data_flit,
    `DUT.io_core_outputs_11_Data_flit, `DUT.io_core_outputs_10_Data_flit,
    `DUT.io_core_outputs_9_Data_flit,  `DUT.io_core_outputs_8_Data_flit,
    `DUT.io_core_outputs_7_Data_flit,  `DUT.io_core_outputs_6_Data_flit,
    `DUT.io_core_outputs_5_Data_flit,  `DUT.io_core_outputs_4_Data_flit,
    `DUT.io_core_outputs_3_Data_flit,  `DUT.io_core_outputs_2_Data_flit,
    `DUT.io_core_outputs_1_Data_flit,  `DUT.io_core_outputs_0_Data_flit
  };

  wire [1:0] l1_00_parent_ack = {
    `DUT.routerL1_0_0_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_0_0_io_inputs_parent_0_HS_Ack
  };
  wire [1:0] l1_10_parent_ack = {
    `DUT.routerL1_1_0_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_1_0_io_inputs_parent_0_HS_Ack
  };
  wire [1:0] l1_01_parent_ack = {
    `DUT.routerL1_0_1_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_0_1_io_inputs_parent_0_HS_Ack
  };
  wire [1:0] l1_11_parent_ack = {
    `DUT.routerL1_1_1_io_inputs_parent_1_HS_Ack,
    `DUT.routerL1_1_1_io_inputs_parent_0_HS_Ack
  };

  wire [7:0] l2_child_req = {
    `DUT.routerL2_io_outputs_child_3_1_HS_Req,
    `DUT.routerL2_io_outputs_child_3_0_HS_Req,
    `DUT.routerL2_io_outputs_child_2_1_HS_Req,
    `DUT.routerL2_io_outputs_child_2_0_HS_Req,
    `DUT.routerL2_io_outputs_child_1_1_HS_Req,
    `DUT.routerL2_io_outputs_child_1_0_HS_Req,
    `DUT.routerL2_io_outputs_child_0_1_HS_Req,
    `DUT.routerL2_io_outputs_child_0_0_HS_Req
  };

  // dir0 L1(1,1) downward/downward_1; dir1 L1(1,0) _2/_3;
  // dir2 L1(0,1) _4/_5; dir3 L1(0,0) _6/_7.
  wire [7:0] down_deq_req = {
    `DUT.downward_7_io_deq_HS_Req, `DUT.downward_6_io_deq_HS_Req,
    `DUT.downward_5_io_deq_HS_Req, `DUT.downward_4_io_deq_HS_Req,
    `DUT.downward_3_io_deq_HS_Req, `DUT.downward_2_io_deq_HS_Req,
    `DUT.downward_1_io_deq_HS_Req, `DUT.downward_io_deq_HS_Req
  };
  wire [223:0] down_deq_data = {
    `DUT.downward_7_io_deq_Data_flit, `DUT.downward_6_io_deq_Data_flit,
    `DUT.downward_5_io_deq_Data_flit, `DUT.downward_4_io_deq_Data_flit,
    `DUT.downward_3_io_deq_Data_flit, `DUT.downward_2_io_deq_Data_flit,
    `DUT.downward_1_io_deq_Data_flit, `DUT.downward_io_deq_Data_flit
  };

  always @(posedge trigger) begin
    diagnostic_port = $root.tb_cmr_noc16_async_boundary_failfast.diagnostic_port;
    $display("CMR_UNEX_SNAPSHOT t=%0t diagnostic_port=%0d", $time, diagnostic_port);
    $display("CMR_UNEX_MAP core0=L1_0_0.d3 core1=L1_0_0.d1 core4=L1_0_0.d2 core5=L1_0_0.d0");
    $display("CMR_UNEX_MAP core2=L1_1_0.d3 core3=L1_1_0.d1 core6=L1_1_0.d2 core7=L1_1_0.d0");
    $display("CMR_UNEX_MAP core8=L1_0_1.d3 core9=L1_0_1.d1 core12=L1_0_1.d2 core13=L1_0_1.d0");
    $display("CMR_UNEX_MAP core10=L1_1_1.d3 core11=L1_1_1.d1 core14=L1_1_1.d2 core15=L1_1_1.d0");
    $display("CMR_UNEX_MAP down_dir0=L1_1_1 down_dir1=L1_1_0 down_dir2=L1_0_1 down_dir3=L1_0_0");
    for (snap_port = 0; snap_port < 16; snap_port = snap_port + 1)
      $display("CMR_UNEX_CORE p=%0d req=%b ack=%b data=%h H/T=%b/%b highlight=%b",
               snap_port, core_out_req[snap_port], core_out_ack[snap_port],
               core_out_data[snap_port*28 +: 28],
               core_out_data[snap_port*28+27], core_out_data[snap_port*28+26],
               (snap_port == diagnostic_port));
    $display("CMR_UNEX_L1_PARENT_ACK L1_0_0=%b L1_1_0=%b L1_0_1=%b L1_1_1=%b",
             l1_00_parent_ack, l1_10_parent_ack, l1_01_parent_ack,
             l1_11_parent_ack);
    for (snap_dir = 0; snap_dir < 4; snap_dir = snap_dir + 1)
      for (snap_lane = 0; snap_lane < 2; snap_lane = snap_lane + 1)
        $display("CMR_UNEX_DOWN dir=%0d lane=%0d l2_req=%b deq_req=%b deq_data=%h H/T=%b/%b",
                 snap_dir, snap_lane,
                 l2_child_req[snap_dir*2+snap_lane],
                 down_deq_req[snap_dir*2+snap_lane],
                 down_deq_data[(snap_dir*2+snap_lane)*28 +: 28],
                 down_deq_data[(snap_dir*2+snap_lane)*28+27],
                 down_deq_data[(snap_dir*2+snap_lane)*28+26]);
  end

`undef DUT
endmodule

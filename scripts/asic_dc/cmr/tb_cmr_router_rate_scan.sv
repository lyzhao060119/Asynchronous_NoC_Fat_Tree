`timescale 1ns/1ps
// Geometry-generic, closed-loop rate stress.  Four child lane-0 sources send
// 5-flit unicast packets upward; F4 sends from parent lane-0 to all children.
// Packet-header waits are exponential (paper lambda = MFlit/s / 5 / 1e3).
// The five flits of a packet are offered one per CASE_TICK_NS; a later packet
// on the same port does not start until the previous Tail has been offered.
// A multicast copy may use either physical lane of its destination child,
// but it must stay on that lane for the packet lifetime.
module tb_cmr_router_rate_scan;
`ifdef GEOM_C4_P8
 localparam C=4; localparam P=8;
`elsif GEOM_C2_P4
 localparam C=2; localparam P=4;
`elsif GEOM_C1_P2
 localparam C=1; localparam P=2;
`elsif GEOM_C1_P1
 localparam C=1; localparam P=1;
`else
 localparam C=2; localparam P=2;
`endif
 localparam N=4*C+P, W=28, FLIT_W=28, PKTS=20, FLITS=5;
 reg reset=1, running=0; wire unused_clock=0;
 reg [N-1:0] tb_in_req='0, tb_out_ack='0; wire [N-1:0] tb_in_ack,tb_out_req;
 reg [N*W-1:0] tb_in_data='0; wire [N*W-1:0] tb_out_data;
`ifdef GEOM_C2_P2
 // Explicit post-netlist probes for the stable first-error path IPM4 -> OPM9.
 wire probe_ipm4_reqin = dut.InputPortModules_4.io_Reqin;
 wire probe_ipm4_ackout = dut.InputPortModules_4.io_Ackout;
 wire [27:0] probe_ipm4_datain = dut.InputPortModules_4.io_Datain_flit;
 wire [3:0] probe_ipm4_reqout = {dut.InputPortModules_4.io_Reqout_3,dut.InputPortModules_4.io_Reqout_2,dut.InputPortModules_4.io_Reqout_1,dut.InputPortModules_4.io_Reqout_0};
 wire [3:0] probe_ipm4_ackin = {dut.InputPortModules_4.io_Ackin_3,dut.InputPortModules_4.io_Ackin_2,dut.InputPortModules_4.io_Ackin_1,dut.InputPortModules_4.io_Ackin_0};
 wire [3:0] probe_ipm4_path = {dut.InputPortModules_4.io_PathEnabled_3,dut.InputPortModules_4.io_PathEnabled_2,dut.InputPortModules_4.io_PathEnabled_1,dut.InputPortModules_4.io_PathEnabled_0};
 wire [27:0] probe_ipm4_dout0 = dut.InputPortModules_4.io_Dataout_0_flit;
 wire [27:0] probe_ipm4_dout1 = dut.InputPortModules_4.io_Dataout_1_flit;
 wire [27:0] probe_ipm4_dout2 = dut.InputPortModules_4.io_Dataout_2_flit;
 wire [27:0] probe_ipm4_dout3 = dut.InputPortModules_4.io_Dataout_3_flit;
 // DEL150 first mismatch: source 3 is observed at parent egress OPM9.
 wire probe_ipm3_reqin = dut.InputPortModules_3.io_Reqin;
 wire probe_ipm3_ackout = dut.InputPortModules_3.io_Ackout;
 wire [27:0] probe_ipm3_datain = dut.InputPortModules_3.io_Datain_flit;
 wire [3:0] probe_ipm3_reqout = {dut.InputPortModules_3.io_Reqout_3,dut.InputPortModules_3.io_Reqout_2,dut.InputPortModules_3.io_Reqout_1,dut.InputPortModules_3.io_Reqout_0};
 wire [3:0] probe_ipm3_ackin = {dut.InputPortModules_3.io_Ackin_3,dut.InputPortModules_3.io_Ackin_2,dut.InputPortModules_3.io_Ackin_1,dut.InputPortModules_3.io_Ackin_0};
 wire [3:0] probe_ipm3_path = {dut.InputPortModules_3.io_PathEnabled_3,dut.InputPortModules_3.io_PathEnabled_2,dut.InputPortModules_3.io_PathEnabled_1,dut.InputPortModules_3.io_PathEnabled_0};
 wire [27:0] probe_ipm3_dout0 = dut.InputPortModules_3.io_Dataout_0_flit;
 wire [27:0] probe_ipm3_dout1 = dut.InputPortModules_3.io_Dataout_1_flit;
 wire [27:0] probe_ipm3_dout2 = dut.InputPortModules_3.io_Dataout_2_flit;
 wire [27:0] probe_ipm3_dout3 = dut.InputPortModules_3.io_Dataout_3_flit;
 wire [27:0] probe_buf3_slot0 = dut.InputPortModules_3.Buffer.StorageUnit_0.io_Dataout_flit;
 wire [27:0] probe_buf3_slot1 = dut.InputPortModules_3.Buffer.StorageUnit_1.io_Dataout_flit;
 wire [27:0] probe_buf3_slot2 = dut.InputPortModules_3.Buffer.StorageUnit_2.io_Dataout_flit;
 wire [27:0] probe_buf3_slot3 = dut.InputPortModules_3.Buffer.StorageUnit_3.io_Dataout_flit;
 wire [27:0] probe_buf3_slot4 = dut.InputPortModules_3.Buffer.StorageUnit_4.io_Dataout_flit;
 wire [4:0] probe_buf3_slot_en = {dut.InputPortModules_3.Buffer.StorageUnit_4.io_En,dut.InputPortModules_3.Buffer.StorageUnit_3.io_En,dut.InputPortModules_3.Buffer.StorageUnit_2.io_En,dut.InputPortModules_3.Buffer.StorageUnit_1.io_En,dut.InputPortModules_3.Buffer.StorageUnit_0.io_En};
 // Netlist mapping: OPM9 physical input6 is IPM6 output3 via adapter_27.
 wire probe_ipm6_reqin = dut.InputPortModules_6.io_Reqin;
 wire probe_ipm6_ackout = dut.InputPortModules_6.io_Ackout;
 wire [27:0] probe_ipm6_datain = dut.InputPortModules_6.io_Datain_flit;
 wire probe_ipm6_reqout3 = dut.InputPortModules_6.io_Reqout_3;
 wire probe_ipm6_ackin3 = dut.InputPortModules_6.io_Ackin_3;
 wire probe_ipm6_path3 = dut.InputPortModules_6.io_PathEnabled_3;
 wire [27:0] probe_ipm6_dataout3 = dut.InputPortModules_6.io_Dataout_3_flit;
 // Timeout path: top-level input port2 is IPM2.  Branches 0..3 map to
 // adapters 8..11.  OPMAckOut is the physical OPM Ackout vector presented
 // to each adapter; IPMAckIn is its returned branch acknowledgement.
 wire probe_ipm2_reqin = dut.InputPortModules_2.io_Reqin;
 wire probe_ipm2_ackout = dut.InputPortModules_2.io_Ackout;
 wire [3:0] probe_ipm2_reqout = {dut.InputPortModules_2.io_Reqout_3,dut.InputPortModules_2.io_Reqout_2,dut.InputPortModules_2.io_Reqout_1,dut.InputPortModules_2.io_Reqout_0};
 wire [3:0] probe_ipm2_ackin = {dut.InputPortModules_2.io_Ackin_3,dut.InputPortModules_2.io_Ackin_2,dut.InputPortModules_2.io_Ackin_1,dut.InputPortModules_2.io_Ackin_0};
 wire [3:0] probe_ipm2_path = {dut.InputPortModules_2.io_PathEnabled_3,dut.InputPortModules_2.io_PathEnabled_2,dut.InputPortModules_2.io_PathEnabled_1,dut.InputPortModules_2.io_PathEnabled_0};
 wire [1:0] probe_adapter8_opm_ackout = dut.adapter_8.OPMAckOut;
 wire       probe_adapter8_ipm_ackin = dut.adapter_8.IPMAckIn;
 wire [1:0] probe_adapter8_opm_reqin = dut.adapter_8.OPMReqIn;
 wire [1:0] probe_adapter9_opm_ackout = dut.adapter_9.OPMAckOut;
 wire       probe_adapter9_ipm_ackin = dut.adapter_9.IPMAckIn;
 wire [1:0] probe_adapter9_opm_reqin = dut.adapter_9.OPMReqIn;
 wire [1:0] probe_adapter10_opm_ackout = dut.adapter_10.OPMAckOut;
 wire       probe_adapter10_ipm_ackin = dut.adapter_10.IPMAckIn;
 wire [1:0] probe_adapter10_opm_reqin = dut.adapter_10.OPMReqIn;
 wire [1:0] probe_adapter11_opm_ackout = dut.adapter_11.OPMAckOut;
 wire       probe_adapter11_ipm_ackin = dut.adapter_11.IPMAckIn;
 wire [1:0] probe_adapter11_opm_reqin = dut.adapter_11.OPMReqIn;
 // IPM2 RCU probes for the stalled next-packet Header.  Keep the RCU's
 // external Mat/RouteSel plus AddressRegister and InternalAck phases.
 wire [3:0] probe_ipm2_mat = {dut.InputPortModules_2.RouteComputationUnit.io_Mat_3,dut.InputPortModules_2.RouteComputationUnit.io_Mat_2,dut.InputPortModules_2.RouteComputationUnit.io_Mat_1,dut.InputPortModules_2.RouteComputationUnit.io_Mat_0};
 wire [3:0] probe_ipm2_routesel = {dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_3,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_2,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_1,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_0};
 wire probe_ipm2_reqpc = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.PhaseSelectorBlock.Req_pc;
 wire probe_ipm2_reqrc = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Req_rc;
 wire probe_ipm2_ackrc = dut.InputPortModules_2.RouteComputationUnit.RouteComputation.InternalAck.Ack_rc;
 wire probe_ipm2_reqrc_delay = dut.InputPortModules_2.RouteComputationUnit.RouteComputation.BundlingSignal_MatchedDelay.Z;
 wire probe_ipm2_bundling = dut.InputPortModules_2.RouteComputationUnit.RouteComputation.BundlingSignal;
 // HeadPredictor race probe: observe its sampled Tail and completion clock,
 // together with the AddressRegister-side raw handshake/data qualifiers.
 wire probe_ipm2_ar_reqin = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Reqin;
 wire probe_ipm2_ar_ackout = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Ackout;
 wire probe_ipm2_ar_head = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Head;
 wire probe_ipm2_ar_tail = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Tail;
 // Adapter27 is the exact IPM6.branch3 -> OPM9.input6 path.  Capture both
 // SR latch state and the DFF Toggle enable so a Select glitch is observable.
 wire [1:0] probe_sel27_lane_empty = dut.selector_27.LaneIsEmpty;
 wire       probe_sel27_ppe = dut.selector_27.PPE;
 wire [1:0] probe_sel27_mutex_req = dut.selector_27.mutex_input_requests;
 wire [1:0] probe_sel27_mutex_grant = dut.selector_27.mutex_in.grant;
 wire [1:0] probe_sel27_s = dut.selector_27.mutex_input_requests;
 wire       probe_sel27_r = ~dut.selector_27.PPE;
 wire [1:0] probe_sel27_lane_select = dut.selector_27.LaneSelect;
 wire [1:0] probe_adapt27_lane_select = dut.adapter_27.LaneSelect;
 wire [1:0] probe_adapt27_ipm_reqout = dut.adapter_27.IPMReqOut;
 wire [1:0] probe_adapt27_opm_ackout = dut.adapter_27.OPMAckOut;
 wire [1:0] probe_adapt27_req_toggle_en = dut.adapter_27.OPMReqInFire;
 wire       probe_adapt27_ack_toggle_en = dut.adapter_27.IPMAckInFireChosen;
 wire [1:0] probe_adapt27_opm_reqin = dut.adapter_27.OPMReqIn;
 wire       probe_adapt27_ipm_ackin = dut.adapter_27.IPMAckIn;
wire [1:0] probe_adapt0_ls = dut.adapter.LaneSelect;
wire [1:0] probe_adapt0_opmack = dut.adapter.OPMAckOut;
wire [1:0] probe_adapt0_opmreq = dut.adapter.OPMReqIn;
wire probe_adapt0_rawen = dut.adapter.IPMAckInFireChosenRaw;
wire probe_adapt0_await = dut.adapter.AwaitAck;
wire probe_adapt0_en = dut.adapter.IPMAckInFireChosen;
wire probe_adapt0_ipmack = dut.adapter.IPMAckIn;
wire [1:0] probe_adapt0_ipmreq = dut.adapter.IPMReqOut;
 wire [27:0] probe_buf6_slot0 = dut.InputPortModules_6.Buffer.StorageUnit_0.io_Dataout_flit;
 wire [27:0] probe_buf6_slot1 = dut.InputPortModules_6.Buffer.StorageUnit_1.io_Dataout_flit;
 wire [27:0] probe_buf6_slot2 = dut.InputPortModules_6.Buffer.StorageUnit_2.io_Dataout_flit;
 wire [27:0] probe_buf6_slot3 = dut.InputPortModules_6.Buffer.StorageUnit_3.io_Dataout_flit;
 wire [27:0] probe_buf6_slot4 = dut.InputPortModules_6.Buffer.StorageUnit_4.io_Dataout_flit;
 wire [4:0] probe_buf6_slot_en = {dut.InputPortModules_6.Buffer.StorageUnit_4.io_En,dut.InputPortModules_6.Buffer.StorageUnit_3.io_En,dut.InputPortModules_6.Buffer.StorageUnit_2.io_En,dut.InputPortModules_6.Buffer.StorageUnit_1.io_En,dut.InputPortModules_6.Buffer.StorageUnit_0.io_En};
 wire [27:0] probe_buf4_slot0 = dut.InputPortModules_4.Buffer.StorageUnit_0.io_Dataout_flit;
 wire [27:0] probe_buf4_slot1 = dut.InputPortModules_4.Buffer.StorageUnit_1.io_Dataout_flit;
 wire [27:0] probe_buf4_slot2 = dut.InputPortModules_4.Buffer.StorageUnit_2.io_Dataout_flit;
 wire [27:0] probe_buf4_slot3 = dut.InputPortModules_4.Buffer.StorageUnit_3.io_Dataout_flit;
 wire [27:0] probe_buf4_slot4 = dut.InputPortModules_4.Buffer.StorageUnit_4.io_Dataout_flit;
 wire [4:0] probe_buf4_slot_en = {dut.InputPortModules_4.Buffer.StorageUnit_4.io_En,dut.InputPortModules_4.Buffer.StorageUnit_3.io_En,dut.InputPortModules_4.Buffer.StorageUnit_2.io_En,dut.InputPortModules_4.Buffer.StorageUnit_1.io_En,dut.InputPortModules_4.Buffer.StorageUnit_0.io_En};
 wire [27:0] probe_buf4_slot0_din = dut.InputPortModules_4.Buffer.StorageUnit_0.io_Datain_flit;
 wire probe_opm9_reqin4 = dut.OutputPortModules_9.io_Reqin_4;
 wire probe_opm9_ackout4 = dut.OutputPortModules_9.io_Ackout_4;
 wire probe_opm9_grant4 = dut.OutputPortModules_9.io_Grant_4;
 wire probe_opm9_ppe4 = dut.OutputPortModules_9.io_PktPathEnable_4;
 wire [27:0] probe_opm9_datain4 = dut.OutputPortModules_9.io_Datain_4_flit;
 wire probe_opm9_reqin3 = dut.OutputPortModules_9.io_Reqin_3;
 wire probe_opm9_ackout3 = dut.OutputPortModules_9.io_Ackout_3;
 wire probe_opm9_grant3 = dut.OutputPortModules_9.io_Grant_3;
 wire probe_opm9_ppe3 = dut.OutputPortModules_9.io_PktPathEnable_3;
 wire [27:0] probe_opm9_datain3 = dut.OutputPortModules_9.io_Datain_3_flit;
 // Full OPM9 input-side snapshot.  Mux index is independent of the packet
 // origin encoded in the payload, so inspect all eight physical inputs.
 wire [7:0] probe_opm9_reqin_all = {dut.OutputPortModules_9.io_Reqin_7,dut.OutputPortModules_9.io_Reqin_6,dut.OutputPortModules_9.io_Reqin_5,dut.OutputPortModules_9.io_Reqin_4,dut.OutputPortModules_9.io_Reqin_3,dut.OutputPortModules_9.io_Reqin_2,dut.OutputPortModules_9.io_Reqin_1,dut.OutputPortModules_9.io_Reqin_0};
 wire [7:0] probe_opm9_ackout_all = {dut.OutputPortModules_9.io_Ackout_7,dut.OutputPortModules_9.io_Ackout_6,dut.OutputPortModules_9.io_Ackout_5,dut.OutputPortModules_9.io_Ackout_4,dut.OutputPortModules_9.io_Ackout_3,dut.OutputPortModules_9.io_Ackout_2,dut.OutputPortModules_9.io_Ackout_1,dut.OutputPortModules_9.io_Ackout_0};
 wire [7:0] probe_opm9_grant_all = {dut.OutputPortModules_9.io_Grant_7,dut.OutputPortModules_9.io_Grant_6,dut.OutputPortModules_9.io_Grant_5,dut.OutputPortModules_9.io_Grant_4,dut.OutputPortModules_9.io_Grant_3,dut.OutputPortModules_9.io_Grant_2,dut.OutputPortModules_9.io_Grant_1,dut.OutputPortModules_9.io_Grant_0};
 wire [7:0] probe_opm9_ppe_all = {dut.OutputPortModules_9.io_PktPathEnable_7,dut.OutputPortModules_9.io_PktPathEnable_6,dut.OutputPortModules_9.io_PktPathEnable_5,dut.OutputPortModules_9.io_PktPathEnable_4,dut.OutputPortModules_9.io_PktPathEnable_3,dut.OutputPortModules_9.io_PktPathEnable_2,dut.OutputPortModules_9.io_PktPathEnable_1,dut.OutputPortModules_9.io_PktPathEnable_0};
 wire [27:0] probe_opm9_datain6 = dut.OutputPortModules_9.io_Datain_6_flit;
 wire [27:0] probe_opm9_datain7 = dut.OutputPortModules_9.io_Datain_7_flit;
 wire probe_opm9_reqout = dut.OutputPortModules_9.io_Reqout;
 wire probe_opm9_ackin = dut.OutputPortModules_9.io_Ackin;
 wire [27:0] probe_opm9_dataout = dut.OutputPortModules_9.io_Dataout_flit;
`endif
`ifdef GEOM_C1_P2
 // C1P2/M600 diagnostic cut: source-0 IPM and the parent-lane-1 OPM that
 // emitted the repeated Header.  Export the actual handshake boundary wires
 // so the SDF VCD is not interpreted through bit-blasted netlist aliases.
 wire probe_c1_ipm0_reqin = dut.InputPortModules_0.io_Reqin;
 wire probe_c1_ipm0_ackout = dut.InputPortModules_0.io_Ackout;
 wire [27:0] probe_c1_ipm0_datain = dut.InputPortModules_0.io_Datain_flit;
 wire [3:0] probe_c1_ipm0_reqout = {dut.InputPortModules_0.io_Reqout_3,dut.InputPortModules_0.io_Reqout_2,dut.InputPortModules_0.io_Reqout_1,dut.InputPortModules_0.io_Reqout_0};
 wire [3:0] probe_c1_ipm0_ackin = {dut.InputPortModules_0.io_Ackin_3,dut.InputPortModules_0.io_Ackin_2,dut.InputPortModules_0.io_Ackin_1,dut.InputPortModules_0.io_Ackin_0};
 wire [3:0] probe_c1_ipm0_path = {dut.InputPortModules_0.io_PathEnabled_3,dut.InputPortModules_0.io_PathEnabled_2,dut.InputPortModules_0.io_PathEnabled_1,dut.InputPortModules_0.io_PathEnabled_0};
 wire [27:0] probe_c1_ipm0_dataout0 = dut.InputPortModules_0.io_Dataout_0_flit;
 wire [27:0] probe_c1_ipm0_dataout1 = dut.InputPortModules_0.io_Dataout_1_flit;
 wire [27:0] probe_c1_ipm0_dataout2 = dut.InputPortModules_0.io_Dataout_2_flit;
 wire [27:0] probe_c1_ipm0_dataout3 = dut.InputPortModules_0.io_Dataout_3_flit;
 // Buffer-state cut for the M600 repeated-header localization.  These are
 // observation-only probes: they neither alter the frozen DUT nor its SDF.
 wire [4:0] probe_c1_ipm0_writeptr = {dut.InputPortModules_0.Buffer.WriteInterface.io_WritePointer_4,dut.InputPortModules_0.Buffer.WriteInterface.io_WritePointer_3,dut.InputPortModules_0.Buffer.WriteInterface.io_WritePointer_2,dut.InputPortModules_0.Buffer.WriteInterface.io_WritePointer_1,dut.InputPortModules_0.Buffer.WriteInterface.io_WritePointer_0};
 wire [4:0] probe_c1_ipm0_readptr3 = dut.InputPortModules_0.Buffer.ReadInterface_3.Counter_ReadPointer;
 wire probe_c1_ipm0_r3_reqx = dut.InputPortModules_0.Buffer.ReadInterface_3.Counter.ReqX;
 wire probe_c1_ipm0_r3_ackx = dut.InputPortModules_0.Buffer.ReadInterface_3.Counter.AckX;
 wire probe_c1_ipm0_r3_ps_reqx = dut.InputPortModules_0.Buffer.ReadInterface_3.PhaseSelector.ReqX;
 wire probe_c1_ipm0_r3_ps_ackin = dut.InputPortModules_0.Buffer.ReadInterface_3.PhaseSelector.Ackin;
 wire probe_c1_ipm0_r3_ps_reqout = dut.InputPortModules_0.Buffer.ReadInterface_3.PhaseSelector.Reqout;
`ifndef CMR_TB_NO_READREQOUT_GUARD
 // Present only in netlists synthesized after the ReadReqoutGuard experiment.
 // Keep the rate TB compatible with the older headwindow checkpoint as well.
`ifdef HAS_READREQOUT_GUARD
 wire probe_c1_ipm0_r3_guard_i = dut.InputPortModules_0.Buffer.ReadInterface_3.ReadReqoutGuard.I;
 wire probe_c1_ipm0_r3_guard_z = dut.InputPortModules_0.Buffer.ReadInterface_3.ReadReqoutGuard.Z;
`endif
`endif
 wire [4:0] probe_c1_ipm0_r3_cellreq = {dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_4.Req,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_3.Req,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_2.Req,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_1.Req,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_0.Req};
 wire [4:0] probe_c1_ipm0_r3_cellempty = {dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_4.CellEmpty,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_3.CellEmpty,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_2.CellEmpty,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_1.CellEmpty,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_0.CellEmpty};
 wire [4:0] probe_c1_ipm0_r3_cellfull = {dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_4.CellFull,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_3.CellFull,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_2.CellFull,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_1.CellFull,dut.InputPortModules_0.Buffer.ReadInterface_3.ControlUnit_0.CellFull};
 wire [27:0] probe_c1_ipm0_slot0 = dut.InputPortModules_0.Buffer.StorageUnit_0.io_Dataout_flit;
 wire [27:0] probe_c1_ipm0_slot1 = dut.InputPortModules_0.Buffer.StorageUnit_1.io_Dataout_flit;
 wire [27:0] probe_c1_ipm0_slot2 = dut.InputPortModules_0.Buffer.StorageUnit_2.io_Dataout_flit;
 wire [27:0] probe_c1_ipm0_slot3 = dut.InputPortModules_0.Buffer.StorageUnit_3.io_Dataout_flit;
 wire [27:0] probe_c1_ipm0_slot4 = dut.InputPortModules_0.Buffer.StorageUnit_4.io_Dataout_flit;
 wire [3:0] probe_c1_opm5_reqin = {dut.OutputPortModules_5.io_Reqin_3,dut.OutputPortModules_5.io_Reqin_2,dut.OutputPortModules_5.io_Reqin_1,dut.OutputPortModules_5.io_Reqin_0};
 wire [3:0] probe_c1_opm5_ackout = {dut.OutputPortModules_5.io_Ackout_3,dut.OutputPortModules_5.io_Ackout_2,dut.OutputPortModules_5.io_Ackout_1,dut.OutputPortModules_5.io_Ackout_0};
wire [3:0] probe_c1_opm5_grant = {dut.OutputPortModules_5.io_Grant_3,dut.OutputPortModules_5.io_Grant_2,dut.OutputPortModules_5.io_Grant_1,dut.OutputPortModules_5.io_Grant_0};
wire [3:0] probe_c1_opm5_ppe = {dut.OutputPortModules_5.io_PktPathEnable_3,dut.OutputPortModules_5.io_PktPathEnable_2,dut.OutputPortModules_5.io_PktPathEnable_1,dut.OutputPortModules_5.io_PktPathEnable_0};
wire [3:0] probe_c1_opm5_tailpassed = {dut.OutputPortModules_5.io_TailPassed_3,dut.OutputPortModules_5.io_TailPassed_2,dut.OutputPortModules_5.io_TailPassed_1,dut.OutputPortModules_5.io_TailPassed_0};
 wire [27:0] probe_c1_opm5_datain0 = dut.OutputPortModules_5.io_Datain_0_flit;
 wire [27:0] probe_c1_opm5_datain1 = dut.OutputPortModules_5.io_Datain_1_flit;
 wire [27:0] probe_c1_opm5_datain2 = dut.OutputPortModules_5.io_Datain_2_flit;
 wire [27:0] probe_c1_opm5_datain3 = dut.OutputPortModules_5.io_Datain_3_flit;
 wire probe_c1_opm5_reqout = dut.OutputPortModules_5.io_Reqout;
 wire probe_c1_opm5_ackin = dut.OutputPortModules_5.io_Ackin;
 wire [27:0] probe_c1_opm5_dataout = dut.OutputPortModules_5.io_Dataout_flit;
 // OPM input-0 capture and output-latch chain.  These prove whether an
 // input phase, its latch, or the output latch first changes.
wire probe_c1_opm5_l1_0_en = dut.OutputPortModules_5.L1_L4_0.en;
wire probe_c1_opm5_l1_0_d = dut.OutputPortModules_5.L1_L4_0.d;
wire probe_c1_opm5_l1_0_q = dut.OutputPortModules_5.L1_L4_0.q;
wire probe_c1_opm5_l1_1_en = dut.OutputPortModules_5.L1_L4_1.en;
wire probe_c1_opm5_l1_1_d = dut.OutputPortModules_5.L1_L4_1.d;
wire probe_c1_opm5_l1_1_q = dut.OutputPortModules_5.L1_L4_1.q;
wire probe_c1_opm5_l1_2_en = dut.OutputPortModules_5.L1_L4_2.en;
wire probe_c1_opm5_l1_2_d = dut.OutputPortModules_5.L1_L4_2.d;
wire probe_c1_opm5_l1_2_q = dut.OutputPortModules_5.L1_L4_2.q;
wire probe_c1_opm5_l1_3_en = dut.OutputPortModules_5.L1_L4_3.en;
wire probe_c1_opm5_l1_3_d = dut.OutputPortModules_5.L1_L4_3.d;
wire probe_c1_opm5_l1_3_q = dut.OutputPortModules_5.L1_L4_3.q;
 wire probe_c1_opm5_l5_en = dut.OutputPortModules_5.L5.en;
 wire probe_c1_opm5_l5_d = dut.OutputPortModules_5.L5.d;
 wire probe_c1_opm5_l5_q = dut.OutputPortModules_5.L5.q;
 wire probe_c1_opm5_datareg_en = dut.OutputPortModules_5.DataReg.en;
 wire [27:0] probe_c1_opm5_datareg_d = dut.OutputPortModules_5.DataReg.d;
 wire [27:0] probe_c1_opm5_datareg_q = dut.OutputPortModules_5.DataReg.q;
 // Baseline M100 first-error cut: src2 IPM -> child3 / parent.  IPM2 legal
 // branches are dir {0,1,3,4} = child0, child1, child3, parent.
 wire [3:0] probe_c1_ipm2_path = {dut.InputPortModules_2.io_PathEnabled_3,dut.InputPortModules_2.io_PathEnabled_2,dut.InputPortModules_2.io_PathEnabled_1,dut.InputPortModules_2.io_PathEnabled_0};
 wire [3:0] probe_c1_ipm2_mat = {dut.InputPortModules_2.RouteComputationUnit.io_Mat_3,dut.InputPortModules_2.RouteComputationUnit.io_Mat_2,dut.InputPortModules_2.RouteComputationUnit.io_Mat_1,dut.InputPortModules_2.RouteComputationUnit.io_Mat_0};
 wire [3:0] probe_c1_ipm2_routesel = {dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_3,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_2,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_1,dut.InputPortModules_2.RouteComputationUnit.io_RouteSel_0};
 wire [3:0] probe_c1_ipm2_reqout = {dut.InputPortModules_2.io_Reqout_3,dut.InputPortModules_2.io_Reqout_2,dut.InputPortModules_2.io_Reqout_1,dut.InputPortModules_2.io_Reqout_0};
 wire [3:0] probe_c1_ipm2_ackin = {dut.InputPortModules_2.io_Ackin_3,dut.InputPortModules_2.io_Ackin_2,dut.InputPortModules_2.io_Ackin_1,dut.InputPortModules_2.io_Ackin_0};
 wire probe_c1_ipm2_en = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.En;
 wire probe_c1_ipm2_head = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Head;
 wire probe_c1_ipm2_tail = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Tail;
 wire probe_c1_ipm2_reqin = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Reqin;
 wire probe_c1_ipm2_ackout = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Ackout;
 wire probe_c1_ipm2_complete = ~(probe_c1_ipm2_reqin ^ probe_c1_ipm2_ackout);
 wire [23:0] probe_c1_ipm2_dest = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.dest;
 wire probe_c1_ipm2_reqrc = dut.InputPortModules_2.RouteComputationUnit.AddressRegister.Req_rc;
 wire [27:0] probe_c1_ipm2_dout0 = dut.InputPortModules_2.io_Dataout_0_flit;
 wire [27:0] probe_c1_ipm2_dout1 = dut.InputPortModules_2.io_Dataout_1_flit;
 wire [27:0] probe_c1_ipm2_dout2 = dut.InputPortModules_2.io_Dataout_2_flit;
 wire [27:0] probe_c1_ipm2_dout3 = dut.InputPortModules_2.io_Dataout_3_flit;
 wire probe_c1_sel2_ppe = dut.selector_2.PPE;
 wire [1:0] probe_c1_sel2_empty = dut.selector_2.LaneIsEmpty;
 wire [1:0] probe_c1_sel2_ls = dut.selector_2.LaneSelect;
 wire [1:0] probe_c1_sel2_q = dut.selector_2.LaneSelect;
 wire [1:0] probe_c1_sel2_mutex_req = dut.selector_2.mutex_input_requests;
 wire [1:0] probe_c1_sel2_mutex_gnt = dut.selector_2.mutex_in.grant;
 wire [1:0] probe_c1_sel2_mutex_n_req = dut.selector_2.mutex_in.req;
 wire [1:0] probe_c1_sel2_mutex_n_gnt = dut.selector_2.mutex_in.grant;
 wire [1:0] probe_c1_sel2_s = dut.selector_2.mutex_input_requests;
 wire       probe_c1_sel2_r = ~dut.selector_2.PPE;
 wire [1:0] probe_c1_sel0_ls = dut.selector.LaneSelect;
 wire [1:0] probe_c1_sel1_ls = dut.selector_1.LaneSelect;
 wire [1:0] probe_c1_sel3_ls = dut.selector_3.LaneSelect;
 wire [4:0] probe_c1_opm3_ppe = {dut.OutputPortModules_3.io_PktPathEnable_4,dut.OutputPortModules_3.io_PktPathEnable_3,dut.OutputPortModules_3.io_PktPathEnable_2,dut.OutputPortModules_3.io_PktPathEnable_1,dut.OutputPortModules_3.io_PktPathEnable_0};
 wire [4:0] probe_c1_opm3_grant = {dut.OutputPortModules_3.io_Grant_4,dut.OutputPortModules_3.io_Grant_3,dut.OutputPortModules_3.io_Grant_2,dut.OutputPortModules_3.io_Grant_1,dut.OutputPortModules_3.io_Grant_0};
 wire [27:0] probe_c1_opm3_dataout = dut.OutputPortModules_3.io_Dataout_flit;
 wire probe_c1_opm3_reqout = dut.OutputPortModules_3.io_Reqout;
`endif
 integer rate=100, gap_ps, failures=0, sent=0, got=0, seed=202701, traffic_mc=0;
 integer src_seed[0:3];
 real lambda_pkt_ns, case_tick_ns, tx_setup_ns;
 integer first_mismatch_reported=0;
 integer expect_phase[0:3], expect_pkt[0:3], egress_seed[0:N-1];
 integer mc_active_lane[0:3];
 // Header retains the router's rectangle address encoding.  Body and Tail do
 // not consume that address field, so make their payload self-identifying:
 // [25:12] packet sequence (0..16383), [11:9] flit index, [8:6] tag magic,
 // [5] multicast flag, and [1:0] source.  This is diagnostic payload only;
 // it must be checked at every egress rather than inferred from a Header.
 function automatic [W-1:0] f(input bit h,input bit t,input integer src,input integer pkt,input integer flit,input bit mc);
   reg [W-1:0] d; begin
    // Tree: unicast (8,8) goes to parent; F4 [0,3]x[0,3] from parent hits
    // all four children.  Mesh DUT is elaborated at (4,4) so a local
    // unicast and an [0,7]x[0,7] F4 can expand in all four directions.
`ifdef CMR_TB_MESH_STIM
    if(mc) d={2'b0,6'd7,6'd7,6'd0,6'd0,pkt[1:0]};
    else d={2'b0,6'd4,6'd4,6'd4,6'd4,pkt[1:0]};
`else
    if(mc) d={2'b0,6'd3,6'd3,6'd0,6'd0,pkt[1:0]};
    else d={2'b0,6'd8,6'd8,6'd8,6'd8,pkt[1:0]};
    if(!mc) d[7:2]=6'd8+(pkt&7);
`endif
    if(!h) begin
      d[25:12]=pkt[13:0];
      d[11:9]=flit[2:0];
      d[8:6]=3'b101;
      d[5]=mc;
    end
    d[27]=h; d[26]=t; d[1:0]=src[1:0]; f=d;
   end
 endfunction
 task automatic bad(input string s); begin failures=failures+1; $display("TB_RESULT FAIL %s t=%0t",s,$time); end endtask
 // Paper header inter-arrival: Exp(lambda), lambda = MFlit/s / flits / 1e3
 // packets/ns.  Inverse-CDF with a portable ln; per-source LCG streams.
 function automatic integer seed_mix(input integer base, input integer part);
   seed_mix = (base * 1664525 + 1013904223 + part);
 endfunction
 function automatic real ln_pos(input real x);
   real y, z, z2, acc;
   integer k;
   begin
    y = x;
    if (y <= 0.0) y = 1.0e-12;
    k = 0;
    while (y > 1.5) begin y = y * 0.5; k = k + 1; end
    while (y < 0.75) begin y = y * 2.0; k = k - 1; end
    z = (y - 1.0) / (y + 1.0);
    z2 = z * z;
    acc = z;
    acc = acc + z * z2 / 3.0;
    acc = acc + z * z2 * z2 / 5.0;
    acc = acc + z * z2 * z2 * z2 / 7.0;
    acc = acc + z * z2 * z2 * z2 * z2 / 9.0;
    ln_pos = 2.0 * acc + real'(k) * 0.6931471805599453;
   end
 endfunction
 function automatic integer expo_gap_ps(inout integer rng);
   integer u;
   real gap_ns;
   begin
    u = ($random(rng) & 32'h7fffffff);
    if (u <= 0) u = 1;
    gap_ns = -ln_pos(real'(u) / 2147483648.0) / lambda_pkt_ns;
    expo_gap_ps = integer'(gap_ns * 1000.0 + 0.5);
    if (expo_gap_ps < 1) expo_gap_ps = 1;
   end
 endfunction
 task automatic send(input integer port,input integer src,input integer pkt,input bit mc);
  integer q; real due; begin
   due=$realtime;
   for(q=0;q<FLITS;q=q+1) begin
    if($realtime<due) #(due-$realtime);
    if(pkt==0) $display("TB_FLIT src=%0d pkt=%0d flit=%0d t=%0t",src,pkt,q,$time);
    tb_in_data[port*W+:W]=f(q==0,q==FLITS-1,src,pkt,q,mc);
    #(tx_setup_ns);
    tb_in_req[port]=~tb_in_req[port];
    wait(tb_in_req[port]===tb_in_ack[port]);
    due=due+case_tick_ns;
   end
  end
 endtask
 task automatic usrc(input integer src);
  integer k,g,rng; real next_header; begin
   rng=src_seed[src];
   next_header=$realtime;
   for(k=0;k<PKTS;k=k+1) begin
    g=expo_gap_ps(rng);
    next_header=next_header+real'(g)/1000.0;
    if (k < 3) $display("TB_GAP src=%0d pkt=%0d gap_ps=%0d due_ns=%0.3f now_ns=%0.3f", src, k, g, next_header, $realtime);
    if($realtime<next_header) #(next_header-$realtime);
    send(src*C,src,k,0); sent=sent+1;
   end
   src_seed[src]=rng;
  end
 endtask
 task automatic msrc;
  integer k,g,rng; real next_header; begin
   rng=src_seed[0];
   next_header=$realtime;
   for(k=0;k<PKTS;k=k+1) begin
    g=expo_gap_ps(rng);
    next_header=next_header+real'(g)/1000.0;
    if (k < 3) $display("TB_GAP src=parent pkt=%0d gap_ps=%0d due_ns=%0.3f now_ns=%0.3f", k, g, next_header, $realtime);
    if($realtime<next_header) #(next_header-$realtime);
    send(4*C,0,k,1); sent=sent+1;
   end
   src_seed[0]=rng;
  end
 endtask
 task automatic consume(input integer p);
  integer src,dst,lane,ph,pk,d,valid; reg [W-1:0] v; begin
   if(running && tb_out_req[p]!==tb_out_ack[p]) begin
    #1; v=tb_out_data[p*W+:W]; src=v[1:0]; valid=1;
    if(traffic_mc) begin
      // The egress port selects the logical destination child.  The payload
      // itself retains its original parent-source tag (zero), so do not use
      // dst as the expected source field.  Both child lanes are legal.
      dst=p/C; lane=p%C; src=0;
      if(p>=4*C) begin bad("multicast on parent output"); valid=0; end
      else begin
        ph=expect_phase[dst]; pk=expect_pkt[dst];
        if((ph==0 && mc_active_lane[dst]>=0) ||
           (ph!=0 && mc_active_lane[dst]!=lane)) begin
          bad("multicast duplicate or lane migration"); valid=0;
        end
      end
    end else begin ph=expect_phase[src]; pk=expect_pkt[src]; if(p<4*C) bad("unicast on child output"); end
    if(!valid) begin end
    else if(src<0||src>3) bad("bad source");
    else if(v!==f(ph==0,ph==4,src,pk,ph,traffic_mc)) begin
      if(!first_mismatch_reported) begin
        first_mismatch_reported=1;
        $display("TB_FIRST_MISMATCH port=%0d actual=%h expected=%h src=%0d pkt=%0d phase=%0d actual_h=%b actual_t=%b actual_tag_pkt=%0d actual_tag_flit=%0d actual_tag_magic=%b in_req=%b in_ack=%b out_req=%b out_ack=%b t=%0t",
          p,v,f(ph==0,ph==4,src,pk,ph,traffic_mc),src,pk,ph,v[27],v[26],v[25:12],v[11:9],v[8:6],tb_in_req,tb_in_ack,tb_out_req,tb_out_ack,$time);
`ifdef GEOM_C1_P2
        $display("PPE_SNAP ipm2_path=%b mat=%b rs=%b en=%b dest=%h reqrc=%b reqout=%b ackin=%b sel_ppe=%b sel_q=%b opm3_ppe=%b opm3_gnt=%b opm3_req=%b opm3_data=%h dout0=%h dout1=%h dout2=%h dout3=%h t=%0t",
          probe_c1_ipm2_path,probe_c1_ipm2_mat,probe_c1_ipm2_routesel,probe_c1_ipm2_en,probe_c1_ipm2_dest,probe_c1_ipm2_reqrc,probe_c1_ipm2_reqout,probe_c1_ipm2_ackin,probe_c1_sel2_ppe,probe_c1_sel2_q,probe_c1_opm3_ppe,probe_c1_opm3_grant,probe_c1_opm3_reqout,probe_c1_opm3_dataout,probe_c1_ipm2_dout0,probe_c1_ipm2_dout1,probe_c1_ipm2_dout2,probe_c1_ipm2_dout3,$time);
        $display("SEL_SNAP sel2_ppe=%b empty=%b ls=%b q=%b mreq=%b mgnt=%b nreq=%b ngnt=%b s=%b r=%b sel0_ls=%b sel1_ls=%b sel3_ls=%b t=%0t",
          probe_c1_sel2_ppe,probe_c1_sel2_empty,probe_c1_sel2_ls,probe_c1_sel2_q,probe_c1_sel2_mutex_req,probe_c1_sel2_mutex_gnt,probe_c1_sel2_mutex_n_req,probe_c1_sel2_mutex_n_gnt,probe_c1_sel2_s,probe_c1_sel2_r,probe_c1_sel0_ls,probe_c1_sel1_ls,probe_c1_sel3_ls,$time);
`endif
      end
      bad("data/order/duplicate mismatch");
    end else if(traffic_mc) begin
      if(ph==0) mc_active_lane[dst]=lane;
      expect_phase[dst]=ph+1; got=got+1;
      if(ph==4) begin expect_phase[dst]=0; expect_pkt[dst]=pk+1; mc_active_lane[dst]=-1; end
    end else begin expect_phase[src]=ph+1; got=got+1; if(ph==4) begin expect_phase[src]=0; expect_pkt[src]=pk+1; end end
    d=1+(($random(egress_seed[p])&32'h7fffffff)%7); #d; tb_out_ack[p]=tb_out_req[p];
   end
  end
 endtask
 genvar g; generate for(g=0;g<N;g=g+1) begin: MON always @(tb_out_req[g]) consume(g); end endgenerate
`ifdef GEOM_C4_P8
 CMRRouter dut (`include "async_ports_c4_p8.vi");
`elsif GEOM_C2_P4
 CMRRouter dut (`include "async_ports_c2_p4.vi");
`elsif GEOM_C1_P2
 CMRRouter dut (`include "async_ports_c1_p2.vi");
 always @(probe_c1_ipm2_en or probe_c1_ipm2_complete or probe_c1_ipm2_head
          or probe_c1_ipm2_tail or probe_c1_ipm2_reqin or probe_c1_ipm2_ackout) begin
  if (running && $time <= 230000)
    $display("EN_WAVE t=%0t en=%b cp=%b h=%b tl=%b req=%b ack=%b dest=%h mat=%b path=%b reqrc=%b",
      $time, probe_c1_ipm2_en, probe_c1_ipm2_complete, probe_c1_ipm2_head, probe_c1_ipm2_tail,
      probe_c1_ipm2_reqin, probe_c1_ipm2_ackout, probe_c1_ipm2_dest, probe_c1_ipm2_mat,
      probe_c1_ipm2_path, probe_c1_ipm2_reqrc);
 end
 always @(probe_c1_sel2_ppe or probe_c1_sel2_empty or probe_c1_sel2_ls
          or probe_c1_sel2_mutex_req or probe_c1_sel2_mutex_gnt
          or probe_c1_sel2_s or probe_c1_sel2_r) begin
  if (running) begin
    $display("SEL_WAVE t=%0t ppe=%b empty=%b ls=%b mreq=%b mgnt=%b s=%b r=%b",
      $time, probe_c1_sel2_ppe, probe_c1_sel2_empty, probe_c1_sel2_ls,
      probe_c1_sel2_mutex_req, probe_c1_sel2_mutex_gnt, probe_c1_sel2_s, probe_c1_sel2_r);
    if (^probe_c1_sel2_ls === 1'b0 && probe_c1_sel2_ls !== 2'b00)
      $display("SEL_DUAL t=%0t ppe=%b empty=%b ls=%b mreq=%b mgnt=%b s=%b r=%b",
        $time, probe_c1_sel2_ppe, probe_c1_sel2_empty, probe_c1_sel2_ls,
        probe_c1_sel2_mutex_req, probe_c1_sel2_mutex_gnt, probe_c1_sel2_s, probe_c1_sel2_r);
  end
 end
`elsif GEOM_C1_P1
 CMRRouter dut (`include "async_ports_c1_p1.vi");
`else
 CMRRouter dut (`include "async_ports_c2_p2.vi");
 always @(probe_adapt0_ls or probe_adapt0_opmack or probe_adapt0_opmreq
          or probe_adapt0_rawen or probe_adapt0_await or probe_adapt0_en
          or probe_adapt0_ipmack or probe_adapt0_ipmreq) begin
  if (running && $time >= 740 && $time <= 820)
    $display("ACK0_WAVE t=%0t ls=%b opmack=%b opmreq=%b raw=%b await=%b en=%b ipmack=%b ipmreq=%b",
      $time, probe_adapt0_ls, probe_adapt0_opmack, probe_adapt0_opmreq,
      probe_adapt0_rawen, probe_adapt0_await, probe_adapt0_en,
      probe_adapt0_ipmack, probe_adapt0_ipmreq);
 end
`endif
 initial begin : main
  integer i,limit; string mode,vcd;
  if($value$plusargs("RATE_MFLIT=%d",rate)); if($value$plusargs("TRAFFIC=%s",mode));
  traffic_mc=(mode=="F4"); if(rate<=0) $fatal(1,"bad RATE_MFLIT"); gap_ps=5000000/rate;
  lambda_pkt_ns=rate/real'(FLITS)/1000.0;
  case_tick_ns=1.0; tx_setup_ns=0.05;
  if($value$plusargs("CASE_TICK_NS=%f",case_tick_ns));
  if($value$plusargs("TX_SETUP_NS=%f",tx_setup_ns));
  if(case_tick_ns<=0.0) $fatal(1,"bad CASE_TICK_NS");
  for(i=0;i<4;i=i+1) src_seed[i]=seed_mix(seed,i);
  $display("TB_INFO inject=exponential_serialized offered=%0d MFlit_per_port_s mean_gap_ps=%0d lambda_pkt_ns=%0.6f case_tick_ns=%0.3f tx_setup_ns=%0.3f seed=%0d",
           rate,gap_ps,lambda_pkt_ns,case_tick_ns,tx_setup_ns,seed);
  for(i=0;i<N;i=i+1) egress_seed[i]=202701+i;
  for(i=0;i<4;i=i+1) begin expect_phase[i]=0;expect_pkt[i]=0;mc_active_lane[i]=-1;end
  if($value$plusargs("VCD=%s",vcd)) begin
    $dumpfile(vcd);
    $dumpvars(0,tb_cmr_router_rate_scan);
    // First-error path: child2/lane0 IPM to parent lane1 OPM.
`ifdef GEOM_C2_P2
    $dumpvars(0,dut.InputPortModules_4);
    $dumpvars(0,dut.InputPortModules_3);
    $dumpvars(0,dut.InputPortModules_6);
    $dumpvars(0,dut.InputPortModules_6);
    $dumpvars(0,dut.OutputPortModules_9);
`endif
  end
  #200 reset=0; #10 running=1;
  if(traffic_mc) msrc(); else fork usrc(0);usrc(1);usrc(2);usrc(3);join
  limit=0; while(got < (traffic_mc?4:4)*PKTS*FLITS && limit<1000000) begin #1;limit=limit+1;end
  if(sent!=(traffic_mc?1:4)*PKTS) bad("injected packet count");
  if(got!=(traffic_mc?4:4)*PKTS*FLITS) bad("delivered flit count");
  for(i=0;i<4;i=i+1) if(expect_pkt[i]!=PKTS||expect_phase[i]!=0) bad("per-copy/source completion");
  #20; if(tb_out_req!==tb_out_ack || $isunknown({tb_out_req,tb_in_ack})) bad("not idle or X");
  $display("TB_RATE traffic=%s inject=exponential_serialized offered=%0d MFlit_per_port_s injected_packets=%0d delivered_flits=%0d",mode,rate,sent,got);
  if(failures==0) $display("TB_RESULT PASS RATE_SCAN"); else $display("TB_RESULT FAIL RATE_SCAN failures=%0d",failures);
  $finish;
 end
 initial begin #2000000; $display("TB_RESULT FAIL timeout");$finish;end
endmodule

`timescale 1ns/1ps

// Simulation-only all-edge RTC fixture.  It discovers a one-point Head route
// using the PRS RTL itself, then measures an isolated H/B/T packet for every
// legal ingress/egress pair.  No internal signal controls source or receiver
// flow after discovery.
module tb_ultra_router_rtc_all_edges;
  reg clock = 0, reset = 1;
  reg [4:0] in_req = 0;
  wire [4:0] in_ack;
  reg [27:0] in_data [0:4];
  wire [4:0] out_req;
  reg [4:0] out_ack = 0;
  wire [27:0] out_data [0:4];
  wire [3:0] raw_rs [0:4];
  integer input_id, output_id, branch_id, x, y, i;
  integer found [0:4][0:4];
  reg [27:0] route_head [0:4][0:4];
  reg [27:0] expected_flit;
  real data_launch, req_launch, data_seen, reqout_seen;
  real data_change_time [0:4];
  // V2 bundled-data timing is local to an OPM capture.  These arrays are
  // simulation-only observations; they neither feed nor control the DUT.
  real v2_datax_change [0:4][0:3];
  real v2_d_change [0:4];
  real v2_e_fall [0:4];

  UltraRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(in_req[0]), .io_inputs_child_0_0_HS_Ack(in_ack[0]), .io_inputs_child_0_0_Data_flit(in_data[0]),
    .io_inputs_child_1_0_HS_Req(in_req[1]), .io_inputs_child_1_0_HS_Ack(in_ack[1]), .io_inputs_child_1_0_Data_flit(in_data[1]),
    .io_inputs_child_2_0_HS_Req(in_req[2]), .io_inputs_child_2_0_HS_Ack(in_ack[2]), .io_inputs_child_2_0_Data_flit(in_data[2]),
    .io_inputs_child_3_0_HS_Req(in_req[3]), .io_inputs_child_3_0_HS_Ack(in_ack[3]), .io_inputs_child_3_0_Data_flit(in_data[3]),
    .io_inputs_parent_0_HS_Req(in_req[4]), .io_inputs_parent_0_HS_Ack(in_ack[4]), .io_inputs_parent_0_Data_flit(in_data[4]),
    .io_outputs_child_0_0_HS_Req(out_req[0]), .io_outputs_child_0_0_HS_Ack(out_ack[0]), .io_outputs_child_0_0_Data_flit(out_data[0]),
    .io_outputs_child_1_0_HS_Req(out_req[1]), .io_outputs_child_1_0_HS_Ack(out_ack[1]), .io_outputs_child_1_0_Data_flit(out_data[1]),
    .io_outputs_child_2_0_HS_Req(out_req[2]), .io_outputs_child_2_0_HS_Ack(out_ack[2]), .io_outputs_child_2_0_Data_flit(out_data[2]),
    .io_outputs_child_3_0_HS_Req(out_req[3]), .io_outputs_child_3_0_HS_Ack(out_ack[3]), .io_outputs_child_3_0_Data_flit(out_data[3]),
    .io_outputs_parent_0_HS_Req(out_req[4]), .io_outputs_parent_0_HS_Ack(out_ack[4]), .io_outputs_parent_0_Data_flit(out_data[4])
  );

  assign raw_rs[0] = {dut.inputModules_0_io_RS_3,dut.inputModules_0_io_RS_2,dut.inputModules_0_io_RS_1,dut.inputModules_0_io_RS_0};
  assign raw_rs[1] = {dut.inputModules_1_io_RS_3,dut.inputModules_1_io_RS_2,dut.inputModules_1_io_RS_1,dut.inputModules_1_io_RS_0};
  assign raw_rs[2] = {dut.inputModules_2_io_RS_3,dut.inputModules_2_io_RS_2,dut.inputModules_2_io_RS_1,dut.inputModules_2_io_RS_0};
  assign raw_rs[3] = {dut.inputModules_3_io_RS_3,dut.inputModules_3_io_RS_2,dut.inputModules_3_io_RS_1,dut.inputModules_3_io_RS_0};
  assign raw_rs[4] = {dut.inputModules_4_io_RS_3,dut.inputModules_4_io_RS_2,dut.inputModules_4_io_RS_1,dut.inputModules_4_io_RS_0};

  always #5 clock = ~clock;
  always @(out_data[0]) data_change_time[0] = $realtime;
  always @(out_data[1]) data_change_time[1] = $realtime;
  always @(out_data[2]) data_change_time[2] = $realtime;
  always @(out_data[3]) data_change_time[3] = $realtime;
  always @(out_data[4]) data_change_time[4] = $realtime;

  // DataX arrival at every local source (ordered legal inputs) and the shared
  // V2 latch D/E events.  The D-to-E relation, not DataOut-to-ReqOut, is the
  // bundled-data RTC used for OPM_SYNTH closure.
  always @(dut.outputModules_0.io_DataX_0_flit) v2_datax_change[0][0]=$realtime;
  always @(dut.outputModules_0.io_DataX_1_flit) v2_datax_change[0][1]=$realtime;
  always @(dut.outputModules_0.io_DataX_2_flit) v2_datax_change[0][2]=$realtime;
  always @(dut.outputModules_0.io_DataX_3_flit) v2_datax_change[0][3]=$realtime;
  always @(dut.outputModules_1.io_DataX_0_flit) v2_datax_change[1][0]=$realtime;
  always @(dut.outputModules_1.io_DataX_1_flit) v2_datax_change[1][1]=$realtime;
  always @(dut.outputModules_1.io_DataX_2_flit) v2_datax_change[1][2]=$realtime;
  always @(dut.outputModules_1.io_DataX_3_flit) v2_datax_change[1][3]=$realtime;
  always @(dut.outputModules_2.io_DataX_0_flit) v2_datax_change[2][0]=$realtime;
  always @(dut.outputModules_2.io_DataX_1_flit) v2_datax_change[2][1]=$realtime;
  always @(dut.outputModules_2.io_DataX_2_flit) v2_datax_change[2][2]=$realtime;
  always @(dut.outputModules_2.io_DataX_3_flit) v2_datax_change[2][3]=$realtime;
  always @(dut.outputModules_3.io_DataX_0_flit) v2_datax_change[3][0]=$realtime;
  always @(dut.outputModules_3.io_DataX_1_flit) v2_datax_change[3][1]=$realtime;
  always @(dut.outputModules_3.io_DataX_2_flit) v2_datax_change[3][2]=$realtime;
  always @(dut.outputModules_3.io_DataX_3_flit) v2_datax_change[3][3]=$realtime;
  always @(dut.outputModules_4.io_DataX_0_flit) v2_datax_change[4][0]=$realtime;
  always @(dut.outputModules_4.io_DataX_1_flit) v2_datax_change[4][1]=$realtime;
  always @(dut.outputModules_4.io_DataX_2_flit) v2_datax_change[4][2]=$realtime;
  always @(dut.outputModules_4.io_DataX_3_flit) v2_datax_change[4][3]=$realtime;
  always @(dut.outputModules_0.dataOutLatch_d) v2_d_change[0]=$realtime;
  always @(dut.outputModules_1.dataOutLatch_d) v2_d_change[1]=$realtime;
  always @(dut.outputModules_2.dataOutLatch_d) v2_d_change[2]=$realtime;
  always @(dut.outputModules_3.dataOutLatch_d) v2_d_change[3]=$realtime;
  always @(dut.outputModules_4.dataOutLatch_d) v2_d_change[4]=$realtime;
`ifdef ULTRA_TRACE_SDF
  // DC flattens each OPM's common L5/data-latch enable to n70.  It is the
  // actual E net connected to both mapped latch cells (verified per netlist).
  always @(negedge dut.outputModules_0.n70) v2_e_fall[0]=$realtime;
  always @(negedge dut.outputModules_1.n70) v2_e_fall[1]=$realtime;
  always @(negedge dut.outputModules_2.n70) v2_e_fall[2]=$realtime;
  always @(negedge dut.outputModules_3.n70) v2_e_fall[3]=$realtime;
  always @(negedge dut.outputModules_4.n70) v2_e_fall[4]=$realtime;
`else
  always @(negedge dut.outputModules_0.dataOutLatch_en) v2_e_fall[0]=$realtime;
  always @(negedge dut.outputModules_1.dataOutLatch_en) v2_e_fall[1]=$realtime;
  always @(negedge dut.outputModules_2.dataOutLatch_en) v2_e_fall[2]=$realtime;
  always @(negedge dut.outputModules_3.dataOutLatch_en) v2_e_fall[3]=$realtime;
  always @(negedge dut.outputModules_4.dataOutLatch_en) v2_e_fall[4]=$realtime;
`endif

  function integer branch_for;
    input integer ingress;
    input integer egress;
    begin branch_for = (egress < ingress) ? egress : egress - 1; end
  endfunction
  // OPM local source ordering is legalInputPorts(output): all global inputs
  // except that output, in ascending order.  It is distinct from IPM RS
  // branch ordering (legal outputs excluding ingress).
  function integer local_source_for;
    input integer ingress;
    input integer egress;
    begin local_source_for = (ingress < egress) ? ingress : ingress - 1; end
  endfunction
  function [27:0] head_for_point;
    input integer px;
    input integer py;
    begin head_for_point = 28'h8000000 | (px << 2) | (py << 8) | (px << 14) | (py << 20); end
  endfunction
  task fail(input [8*120-1:0] why); begin
    $display("TB_RESULT FAIL rtc_all_edges reason=%0s in=%0d out=%0d t=%0t", why,input_id,output_id,$time);
    $fatal(1,"rtc_all_edges failed");
  end endtask
  task reset_dut; integer j; begin
    reset=1; in_req=0; out_ack=0;
    for(i=0;i<5;i=i+1) begin
      in_data[i]=0; data_change_time[i]=0.0; v2_d_change[i]=-1.0; v2_e_fall[i]=-1.0;
      for(j=0;j<4;j=j+1) v2_datax_change[i][j]=-1.0;
    end
    #20; reset=0; #10;
    if(in_ack !== 0 || out_req !== 0) fail("reset_boundary");
  end endtask
  task wait_in_idle(input integer p); integer n; begin
    n=0; while(in_ack[p] !== in_req[p] && n<5000) begin #0.05; n=n+1; end
    if(n==5000) fail("input_ack_timeout");
  end endtask
  task discover_edge(input integer ing, input integer egr); integer want, timeout; reg [27:0] h; begin
    want=branch_for(ing,egr); found[ing][egr]=0;
    for (x=0; x<32 && !found[ing][egr]; x=x+1) begin
      for (y=0; y<32 && !found[ing][egr]; y=y+1) begin
        reset_dut; h=head_for_point(x,y); in_data[ing]=h; #0.2; in_req[ing]=~in_req[ing];
        timeout=0; while(timeout<80 && raw_rs[ing]===0) begin #0.05; timeout=timeout+1; end
        if(raw_rs[ing] == (4'b0001 << want)) begin
          route_head[ing][egr]=h; found[ing][egr]=1;
          $display("RTC_ROUTE edge=I%0d_O%0d branch=%0d x=%0d y=%0d head=%h",ing,egr,want,x,y,h);
        end
      end
    end
    if(!found[ing][egr]) fail("route_discovery_missing");
  end endtask
  task send_and_receive(input integer ing, input integer egr, input [27:0] flit, input integer flit_id);
    integer n; integer local_source; real ctrl; real data_path; real visible;
    real local_data; real local_margin;
    begin
    local_source=local_source_for(ing,egr);
    v2_datax_change[egr][local_source]=-1.0; v2_d_change[egr]=-1.0; v2_e_fall[egr]=-1.0;
    // Clear before the new input data is written: Body/Tail data may traverse
    // transparent latches before its Req phase toggles.
    wait_in_idle(ing); in_data[ing]=flit; data_launch=$realtime; #0.2; in_req[ing]=~in_req[ing]; req_launch=$realtime;
    n=0; while(out_req[egr]===out_ack[egr] && n<100000) begin #0.05;n=n+1;end
    if(n==100000) fail("output_timeout");
    reqout_seen=$realtime; data_seen=data_change_time[egr];
    if(out_data[egr]!==flit) fail("output_data");
    ctrl=reqout_seen-req_launch; data_path=data_seen-data_launch; visible=data_seen-req_launch;
    $display("TB_RTC_SAMPLE rtc=OPM_V2_I%0d_O%0d edge=I%0d_O%0d phase=%0s flit=%0d datain_ns=%0.3f reqin_ns=%0.3f data_ns=%0.3f reqout_ns=%0.3f data_path_ns=%0.3f tdata_visible_ns=%0.3f tctrl_ns=%0.3f",
      ing,egr,ing,egr,in_req[ing]?"rise":"fall",flit_id,data_launch,req_launch,data_seen,reqout_seen,data_path,visible,ctrl);
    // ReqOut is Q of L5.  The shared V2 E is closed by the Q/Ack feedback and
    // therefore falls one physical feedback delay later; wait only to observe
    // that already-caused close event, never to control an acknowledgement.
    n=0; while(v2_e_fall[egr] < 0.0 && n<200) begin #0.005; n=n+1; end
    if(v2_datax_change[egr][local_source] < 0.0 || v2_d_change[egr] < 0.0 || v2_e_fall[egr] < 0.0)
      fail("v2_local_trace_missing");
    local_data=v2_d_change[egr]-v2_datax_change[egr][local_source];
    local_margin=v2_e_fall[egr]-v2_d_change[egr];
    $display("TB_V2_RTC_SAMPLE rtc=OPM_V2_LOCAL_I%0d_O%0d edge=I%0d_O%0d phase=%0s flit=%0d source=%0d datax_ns=%0.3f d_ns=%0.3f eclose_ns=%0.3f tdata_local_ns=%0.3f margin_de_ps=%0.3f reqout_ns=%0.3f",
      ing,egr,ing,egr,in_req[ing]?"rise":"fall",flit_id,local_source,
      v2_datax_change[egr][local_source],v2_d_change[egr],v2_e_fall[egr],local_data,local_margin*1000.0,reqout_seen);
    // Match the canonical boundary smoke: the receiver must leave enough
    // physical room for V2 close-event -> Ack/TP DFF propagation.
    #0.2; out_ack[egr]=out_req[egr]; wait_in_idle(ing); #1.0;
  end endtask

  initial begin
    for(input_id=0;input_id<5;input_id=input_id+1)
      for(output_id=0;output_id<5;output_id=output_id+1) begin found[input_id][output_id]=0; route_head[input_id][output_id]=0; end
    // Discover with the same PRS RTL used by the DUT; no route table is
    // hand-coded in this fixture.
    for(input_id=0;input_id<5;input_id=input_id+1)
      for(output_id=0;output_id<5;output_id=output_id+1)
        if(input_id!=output_id) discover_edge(input_id,output_id);
    for(input_id=0;input_id<5;input_id=input_id+1)
      for(output_id=0;output_id<5;output_id=output_id+1) if(input_id!=output_id) begin
        reset_dut;
        send_and_receive(input_id,output_id,route_head[input_id][output_id],0);
        send_and_receive(input_id,output_id,28'h0000000 | {22'b0,input_id[2:0],output_id[2:0]},1);
        send_and_receive(input_id,output_id,28'h4000000 | {22'b0,input_id[2:0],output_id[2:0]},2);
      end
    $display("TB_RESULT PASS rtc_all_edges routes=20 samples=60");
    $finish;
  end
  initial begin #2000000; fail("global_timeout"); end
endmodule

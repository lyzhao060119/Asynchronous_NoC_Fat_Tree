`timescale 1ns/1ps

// Regression for a packet-boundary history that a one-packet smoke cannot
// observe: two 5-flit (odd-toggle) packets from one child to the parent.
module tb_cmr_router_l1_phase_history;
  reg clock = 0, reset = 1;
  reg [5:0] Reqin = 0, Ackin = 0;
  reg [27:0] Datain [0:5];
  wire [5:0] Ackout, Reqout;
  wire [27:0] Dataout [0:5];
  integer failures = 0, flits_seen = 0, packet = 0, phase = 0, i;
  string vcd_file;

  CMRRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(Reqin[0]), .io_inputs_child_0_0_HS_Ack(Ackout[0]), .io_inputs_child_0_0_Data_flit(Datain[0]),
    .io_inputs_child_1_0_HS_Req(Reqin[1]), .io_inputs_child_1_0_HS_Ack(Ackout[1]), .io_inputs_child_1_0_Data_flit(Datain[1]),
    .io_inputs_child_2_0_HS_Req(Reqin[2]), .io_inputs_child_2_0_HS_Ack(Ackout[2]), .io_inputs_child_2_0_Data_flit(Datain[2]),
    .io_inputs_child_3_0_HS_Req(Reqin[3]), .io_inputs_child_3_0_HS_Ack(Ackout[3]), .io_inputs_child_3_0_Data_flit(Datain[3]),
    .io_inputs_parent_0_HS_Req(Reqin[4]), .io_inputs_parent_0_HS_Ack(Ackout[4]), .io_inputs_parent_0_Data_flit(Datain[4]),
    .io_inputs_parent_1_HS_Req(Reqin[5]), .io_inputs_parent_1_HS_Ack(Ackout[5]), .io_inputs_parent_1_Data_flit(Datain[5]),
    .io_outputs_child_0_0_HS_Req(Reqout[0]), .io_outputs_child_0_0_HS_Ack(Ackin[0]), .io_outputs_child_0_0_Data_flit(Dataout[0]),
    .io_outputs_child_1_0_HS_Req(Reqout[1]), .io_outputs_child_1_0_HS_Ack(Ackin[1]), .io_outputs_child_1_0_Data_flit(Dataout[1]),
    .io_outputs_child_2_0_HS_Req(Reqout[2]), .io_outputs_child_2_0_HS_Ack(Ackin[2]), .io_outputs_child_2_0_Data_flit(Dataout[2]),
    .io_outputs_child_3_0_HS_Req(Reqout[3]), .io_outputs_child_3_0_HS_Ack(Ackin[3]), .io_outputs_child_3_0_Data_flit(Dataout[3]),
    .io_outputs_parent_0_HS_Req(Reqout[4]), .io_outputs_parent_0_HS_Ack(Ackin[4]), .io_outputs_parent_0_Data_flit(Dataout[4]),
    .io_outputs_parent_1_HS_Req(Reqout[5]), .io_outputs_parent_1_HS_Ack(Ackin[5]), .io_outputs_parent_1_Data_flit(Dataout[5])
  );
  always #5 clock = ~clock;

  function automatic [27:0] flit(input bit head, input bit tail, input integer tag);
    reg [27:0] d;
    begin d = {2'b0,6'd8,6'd8,6'd8,6'd8,2'b0}; d[7:2]=6'd8+tag;
      d[27]=head; d[26]=tail; d[1:0]=0; flit=d; end
  endfunction
  task automatic check(input bit ok, input string msg);
    if (!ok) begin
      failures++;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b out=%b/%b", msg,$time,Reqin,Ackout,Reqout,Ackin);
    end
  endtask
  task automatic wait_input_ack;
    integer n; begin n=0; while(Ackout[0]!==Reqin[0] && n<20000) begin #1; n++; end
      check(Ackout[0]===Reqin[0],"input ack timeout"); end
  endtask
  task automatic send(input bit h,input bit t,input integer tag);
    begin Datain[0]=flit(h,t,tag); #1; Reqin[0]=~Reqin[0]; wait_input_ack(); end
  endtask
  task automatic send_packet(input integer tag);
    begin send(1,0,tag); send(0,0,tag); send(0,0,tag); send(0,0,tag); send(0,1,tag); end
  endtask
  task automatic consume_parent(input integer lane);
    begin if(!reset && Reqout[lane]!==Ackin[lane]) begin
      #1;
      $display("PHASE_HISTORY EGRESS t=%0t lane=%0d tag=%0d head=%b tail=%b expected_packet=%0d expected_phase=%0d",
        $time,lane,Dataout[lane][7:2],Dataout[lane][27],Dataout[lane][26],packet,phase);
      check(Dataout[lane][7:2]===6'd8+packet,"packet tag mismatch");
      check(Dataout[lane][27] === (phase==0),"head phase mismatch");
      check(Dataout[lane][26] === (phase==4),"tail phase mismatch");
      phase=phase+1; flits_seen=flits_seen+1;
      if(phase==5) begin phase=0; packet=packet+1; end
      #2; Ackin[lane]=Reqout[lane];
    end end
  endtask
  always @(Reqout[4]) consume_parent(4);
  always @(Reqout[5]) consume_parent(5);

  // Optional post-SDF probe.  Enable VCD capture with +VCD=<path>; dumping
  // the DUT hierarchy retains the synthesized IPM/Selector/Adapter/OPM pins
  // without relying on RTL-only top-level net names.
  initial begin
    if ($value$plusargs("VCD=%s", vcd_file)) begin
      $dumpfile(vcd_file);
      $dumpvars(0, tb_cmr_router_l1_phase_history);
    end
  end
  initial begin
    for(i=0;i<6;i=i+1) Datain[i]=0;
    #5; reset=0; #10;
    send_packet(0);
    #15;
    send_packet(1);
    i=0; while(flits_seen<10 && i<20000) begin #1; i=i+1; end
    check(flits_seen==10 && packet==2 && phase==0,"two packet delivery incomplete");
    #10; check(Reqout===Ackin && Ackout[0]===Reqin[0],"router did not return idle");
    if(failures==0) $display("TB_RESULT PASS CMR L1 phase-history two 5-flit packets");
    else $display("TB_RESULT FAIL CMR L1 phase-history failures=%0d",failures);
    $finish;
  end
  initial begin #50000; $display("TB_RESULT FAIL global_timeout"); $finish; end
endmodule

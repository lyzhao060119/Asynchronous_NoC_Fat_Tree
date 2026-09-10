`timescale 1ns/1ps

// Rate-configurable MFlit/s per active child input: 5-flit packets use a
// random inter-packet offer gap with the requested mean.  Four upward sources create real 2-lane
// contention; each egress copy is checked for source order, phase and data.
module tb_cmr_router_l1_random_100m;
  localparam integer ACTIVE_PORTS = 4;
  localparam integer PACKETS_PER_PORT = 20;
  localparam integer PACKET_FLITS = 5;
  reg clock = 0, reset = 1;
  reg [5:0] Reqin = 0, Ackin = 0;
  reg [27:0] Datain [0:5];
  wire [5:0] Ackout, Reqout;
  wire [27:0] Dataout [0:5];
  integer failures = 0, sent_packets = 0, received_packets = 0, received_flits = 0;
  integer recv_phase [0:3], recv_packet [0:3], first_offer_ns [0:3], last_offer_ns [0:3];
  localparam integer INITIAL_SEED = 202701;
  integer seed = INITIAL_SEED, index;
  integer target_rate_mflit = 100, mean_gap_ps;

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

  function automatic [27:0] flit(input bit head, input bit tail, input integer src, input integer pkt);
    reg [27:0] d;
    begin
      // Destinations 8..15 are outside this L1 subtree, hence unicast upward.
      d = {2'b0,6'd8,6'd8,6'd8,6'd8,2'b0};
      d[7:2] = 6'd8 + (pkt & 7);
      d[27] = head; d[26] = tail; d[1:0] = src[1:0]; flit = d;
    end
  endfunction
  task automatic check(input bit ok, input string msg);
    if (!ok) begin failures++; $display("TB_RESULT FAIL %s t=%0t in=%b/%b out=%b/%b",msg,$time,Reqin,Ackout,Reqout,Ackin); end
  endtask
  task automatic check_egress(input bit ok, input string msg, input integer lane,
                              input integer src, input integer expected_packet,
                              input integer expected_phase, input [27:0] actual);
    if (!ok) begin
      failures++;
      $display("TB_RESULT FAIL %s t=%0t lane=%0d src=%0d actual_tag=%0d expected_packet=%0d expected_phase=%0d actual_head=%b actual_tail=%b actual=%h",
               msg, $time, lane, src, actual[7:2], expected_packet, expected_phase,
               actual[27], actual[26], actual);
    end
  endtask
  task automatic wait_ack(input integer p);
    integer n; begin n=0; while(Ackout[p]!==Reqin[p] && n<100000) begin #1; n++; end
      check(Ackout[p]===Reqin[p],"ingress ack timeout"); end
  endtask
  task automatic send_flit(input integer p,input bit h,input bit t,input integer pkt);
    begin Datain[p]=flit(h,t,p,pkt); #1; Reqin[p]=~Reqin[p]; wait_ack(p); end
  endtask
  task automatic source(input integer p);
    integer pkt, gap_ps;
    begin
      for(pkt=0; pkt<PACKETS_PER_PORT; pkt=pkt+1) begin
        gap_ps=1 + (($random(seed) & 32'h7fffffff) % (2*mean_gap_ps-1));
        #(gap_ps * 1ps);
        if(pkt==0) first_offer_ns[p]=$time; last_offer_ns[p]=$time;
        send_flit(p,1,0,pkt);
        send_flit(p,0,0,pkt); send_flit(p,0,0,pkt); send_flit(p,0,0,pkt);
        send_flit(p,0,1,pkt); sent_packets=sent_packets+1;
      end
    end
  endtask
  task automatic consume_parent(input integer lane);
    integer src, phase, tag, delay_ns;
    begin
      if(!reset && Reqout[lane]!==Ackin[lane]) begin
        #1; src=Dataout[lane][1:0]; phase=recv_phase[src]; tag=Dataout[lane][7:2];
        check(src>=0 && src<ACTIVE_PORTS,"bad source tag");
        check_egress(tag==8+(recv_packet[src]&7), "packet tag/order mismatch", lane, src, recv_packet[src], phase, Dataout[lane]);
        check_egress(Dataout[lane][27] === (phase==0), "head phase mismatch", lane, src, recv_packet[src], phase, Dataout[lane]);
        check_egress(Dataout[lane][26] === (phase==4), "tail phase mismatch", lane, src, recv_packet[src], phase, Dataout[lane]);
        recv_phase[src]=phase+1; received_flits=received_flits+1;
        if(phase==4) begin recv_phase[src]=0; recv_packet[src]=recv_packet[src]+1; received_packets=received_packets+1; end
        delay_ns=1 + (($random(seed) & 32'h7fffffff) % 7); #delay_ns; Ackin[lane]=Reqout[lane];
      end
    end
  endtask
  always @(Reqout[4]) consume_parent(4);
  always @(Reqout[5]) consume_parent(5);

  initial begin
    if ($value$plusargs("RATE_MFLIT=%d", target_rate_mflit)) begin end
    if (target_rate_mflit <= 0) $fatal(1, "RATE_MFLIT must be positive");
    // Five flits at target_rate_mflit MFlit/s require this mean packet gap.
    mean_gap_ps = 5000000 / target_rate_mflit;
    for(index=0;index<6;index=index+1) Datain[index]=0;
    for(index=0;index<4;index=index+1) begin recv_phase[index]=0; recv_packet[index]=0; end
    #5; reset=0; #10;
    fork source(0); source(1); source(2); source(3); join
    index=0; while(received_packets < ACTIVE_PORTS*PACKETS_PER_PORT && index<200000) begin #1; index=index+1; end
    check(sent_packets==80,"source packet count mismatch");
    check(received_packets==80 && received_flits==400,"delivery count mismatch");
    for(index=0;index<4;index=index+1) check(recv_packet[index]==20 && recv_phase[index]==0,"per-source packet completion mismatch");
    #20; check(Reqout===Ackin && !$isunknown({Reqout,Ackout}),"router did not return idle or contains X");
    $display("TB_RATE offered=%0d MFlit_per_port_s active_ports=4 packets_per_port=20 injected_flits_per_port=100 mean_gap_ps=%0d seed=%0d",target_rate_mflit,mean_gap_ps,INITIAL_SEED);
    if(failures==0) $display("TB_RESULT PASS CMR L1 random %0dM unicast injected=%0d delivered=%0d",target_rate_mflit,sent_packets*5,received_flits);
    else $display("TB_RESULT FAIL CMR L1 random %0dM failures=%0d",target_rate_mflit,failures);
    $finish;
  end
  initial begin
    string vcd_path;
    if ($value$plusargs("VCD=%s", vcd_path)) begin
      $dumpfile(vcd_path);
      $dumpvars(0, tb_cmr_router_l1_random_100m);
    end
  end
  initial begin #300000; $display("TB_RESULT FAIL global_timeout"); $finish; end
endmodule

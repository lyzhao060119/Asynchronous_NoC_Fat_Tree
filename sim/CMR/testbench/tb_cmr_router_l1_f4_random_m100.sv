`timescale 1ns/1ps

// One parent source injects F4 packets to all four L1 child directions.
// Each child returns Ack with independent random delay; every delivered copy
// is checked for packet tag, flit order, data identity, and final idleness.
module tb_cmr_router_l1_f4_random_m100;
  localparam integer CHILD_PORTS = 4, PACKETS = 20, FLITS = 5;
  localparam integer INITIAL_SEED = 202701;
  reg clock = 0, reset = 1;
  reg [5:0] Reqin = 0, Ackin = 0;
  reg [27:0] Datain [0:5];
  wire [5:0] Ackout, Reqout;
  wire [27:0] Dataout [0:5];
  integer failures = 0, sent_packets = 0, delivered_flits = 0;
  integer recv_phase [0:3], recv_packet [0:3], egress_seed [0:3];
  integer seed = INITIAL_SEED, index, target_rate_mflit = 100, mean_gap_ps;

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

  // (x0,y0,x1,y1)=(0,0,1,1) selects all four child branches at L1.
  function automatic [27:0] flit(input bit head, input bit tail, input integer packet);
    reg [27:0] d;
    begin
      d = {2'b0, 6'd1, 6'd1, 6'd0, 6'd0, packet[1:0]};
      d[27] = head; d[26] = tail; flit = d;
    end
  endfunction
  task automatic check(input bit ok, input string text);
    if (!ok) begin failures++; $display("TB_RESULT FAIL %s t=%0t in=%b/%b out=%b/%b", text, $time, Reqin, Ackout, Reqout, Ackin); end
  endtask
  task automatic wait_ack_parent;
    integer n; begin n=0; while (Ackout[4] !== Reqin[4] && n<100000) begin #1; n++; end
      check(Ackout[4] === Reqin[4], "parent ingress ack timeout"); end
  endtask
  task automatic send_flit(input bit head, input bit tail, input integer packet);
    begin Datain[4] = flit(head, tail, packet); #1; Reqin[4] = ~Reqin[4]; wait_ack_parent(); end
  endtask
  task automatic source;
    integer packet, gap_ps;
    begin
      for (packet=0; packet<PACKETS; packet=packet+1) begin
        gap_ps = 1 + (($random(seed) & 32'h7fffffff) % (2*mean_gap_ps-1));
        #(gap_ps * 1ps);
        send_flit(1,0,packet); send_flit(0,0,packet); send_flit(0,0,packet);
        send_flit(0,0,packet); send_flit(0,1,packet); sent_packets = sent_packets + 1;
      end
    end
  endtask
  task automatic consume_child(input integer p);
    integer phase, packet, delay_ns;
    begin
      if (!reset && Reqout[p] !== Ackin[p]) begin
        #1; phase=recv_phase[p]; packet=recv_packet[p];
        check(Dataout[p] === flit(phase==0, phase==4, packet), "F4 copy data/tag/order mismatch");
        check(Dataout[p][27] === (phase==0), "F4 Head phase mismatch");
        check(Dataout[p][26] === (phase==4), "F4 Tail phase mismatch");
        recv_phase[p]=phase+1; delivered_flits=delivered_flits+1;
        if (phase==4) begin recv_phase[p]=0; recv_packet[p]=packet+1; end
        delay_ns=1+(($random(egress_seed[p]) & 32'h7fffffff)%7); #delay_ns; Ackin[p]=Reqout[p];
      end
    end
  endtask
  always @(Reqout[0]) consume_child(0);
  always @(Reqout[1]) consume_child(1);
  always @(Reqout[2]) consume_child(2);
  always @(Reqout[3]) consume_child(3);

  initial begin
    if ($value$plusargs("RATE_MFLIT=%d", target_rate_mflit)) begin end
    if (target_rate_mflit <= 0) $fatal(1, "RATE_MFLIT must be positive");
    mean_gap_ps=5000000/target_rate_mflit;
    for(index=0;index<6;index=index+1) Datain[index]=0;
    for(index=0;index<4;index=index+1) begin recv_phase[index]=0; recv_packet[index]=0; egress_seed[index]=INITIAL_SEED+index+1; end
    #5; reset=0; #10; source();
    index=0; while(delivered_flits < CHILD_PORTS*PACKETS*FLITS && index<300000) begin #1; index=index+1; end
    check(sent_packets==PACKETS, "F4 source packet count mismatch");
    check(delivered_flits==CHILD_PORTS*PACKETS*FLITS, "F4 delivered copy count mismatch");
    for(index=0;index<4;index=index+1) check(recv_packet[index]==PACKETS && recv_phase[index]==0, "F4 child copy incomplete");
    #20; check(Reqout===Ackin && !$isunknown({Reqout,Ackout}), "F4 Router did not return idle or contains X");
    $display("TB_RATE offered=%0d MFlit_per_port_s traffic=F4_original_event active_parent_ports=1 packets=20 delivered_copies=%0d mean_gap_ps=%0d seed=%0d", target_rate_mflit, delivered_flits, mean_gap_ps, INITIAL_SEED);
    if(failures==0) $display("TB_RESULT PASS CMR L1 F4 random %0dM original_events=%0d delivered_copies=%0d",target_rate_mflit,sent_packets,delivered_flits);
    else $display("TB_RESULT FAIL CMR L1 F4 random %0dM failures=%0d",target_rate_mflit,failures);
    $finish;
  end
  initial begin #500000; $display("TB_RESULT FAIL global_timeout"); $finish; end
endmodule

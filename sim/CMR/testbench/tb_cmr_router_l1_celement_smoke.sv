`timescale 1ns/1ps

// MAXIMUM-SDF smoke for the 1-child-lane -> 2-parent-lane Router using the
// sticky C-element selector.  This intentionally checks no re-selection
// policy: a lone upward packet keeps its chosen parent lane; parent ingress
// still replicates a multicast packet to all four child directions.
module tb_cmr_router_l1_celement_smoke;
  reg clock = 1'b0, reset = 1'b1;
  reg [5:0] Reqin = 6'b0, Ackin = 6'b0;
  reg [27:0] Datain [0:5];
  wire [5:0] Ackout, Reqout;
  wire [27:0] Dataout [0:5];
  integer failures = 0, index, selected;
  reg contention_monitor = 1'b0;
  integer contention_seen [0:3];
  integer contention_phase [0:3];
  integer contention_lane [0:3];
  integer contention_total;

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

  function automatic [27:0] flit(input bit h, input bit t, input [5:0] x0, input [5:0] y0, input [5:0] x1, input [5:0] y1, input [1:0] id);
    begin flit = {2'b0, y1, x1, y0, x0, 2'b0}; flit[27]=h; flit[26]=t; flit[1:0]=id; end
  endfunction
  task automatic check(input bit ok, input string text);
    if (!ok) begin failures++; $display("TB_RESULT FAIL %s t=%0t req=%b/%b out=%b/%b", text, $time, Reqin, Ackout, Reqout, Ackin); end
  endtask
  task automatic wait_ack(input integer p);
    integer n; begin n=0; while (Ackout[p] !== Reqin[p] && n<20000) begin #1; n++; end check(Ackout[p] === Reqin[p], "input ack timeout"); end
  endtask
  task automatic wait_req(input integer p);
    integer n; begin n=0; while (Reqout[p] === Ackin[p] && n<20000) begin #1; n++; end check(Reqout[p] !== Ackin[p], "output request timeout"); end
  endtask
  task automatic wait_parent;
    integer n; begin
      n=0; while (Reqout[4] === Ackin[4] && Reqout[5] === Ackin[5] && n<20000) begin #1; n++; end
      check(Reqout[4] !== Ackin[4] || Reqout[5] !== Ackin[5], "parent request timeout");
      selected = (Reqout[4] !== Ackin[4]) ? 4 : 5;
    end
  endtask
  task automatic send(input integer p, input [27:0] d);
    begin Datain[p]=d; #1; Reqin[p]=~Reqin[p]; end
  endtask
  task automatic accept(input integer p);
    begin wait_req(p); check(!$isunknown(Dataout[p]), "output data X/Z"); Ackin[p]=Reqout[p]; #3; end
  endtask
  task automatic reset_router;
    begin
      reset=1; contention_monitor=0; Reqin=0; Ackin=0;
      for(index=0;index<6;index++) Datain[index]=0;
      for(index=0;index<4;index++) begin contention_seen[index]=0; contention_phase[index]=0; contention_lane[index]=-1; end
      contention_total=0;
      #5; reset=0; #8; check(Ackout===0 && Reqout===0, "reset phase mismatch");
    end
  endtask

  task automatic consume_parent(input integer p);
    integer id; begin
      if (!reset && contention_monitor && Reqout[p] !== Ackin[p]) begin
        #1;
        id = Dataout[p][1:0];
        check(id >= 0 && id < 4, "contention output packet tag invalid");
        if (id >= 0 && id < 4) begin
          check(contention_phase[id] < 3, "contention duplicate flit");
          check(Dataout[p][27] === (contention_phase[id] == 0), "contention Head order mismatch");
          check(Dataout[p][26] === (contention_phase[id] == 2), "contention Tail order mismatch");
          if (contention_seen[id] == 0) contention_lane[id] = p;
          else check(contention_lane[id] == p, "packet migrated parent lane during contention");
          contention_seen[id] = contention_seen[id] + 1;
          contention_phase[id] = contention_phase[id] + 1;
          contention_total = contention_total + 1;
        end
        check(!$isunknown({Reqout[p], Ackout, Dataout[p]}), "contention transfer contains X/Z");
        // Asymmetric return timing forces independent lane release histories.
        #(p == 4 ? 2 : 7);
        Ackin[p] = Reqout[p];
      end
    end
  endtask

  always @(Reqout[4]) consume_parent(4);
  always @(Reqout[5]) consume_parent(5);

  task automatic drive_contender(input integer p, input [1:0] id, input integer skew_ns);
    begin
      #skew_ns;
      send(p, flit(1,0,8,8,8,8,id)); wait_ack(p);
      #(1 + p); send(p, flit(0,0,8,8,8,8,id)); wait_ack(p);
      #(3 + (p & 1)); send(p, flit(0,1,8,8,8,8,id)); wait_ack(p);
    end
  endtask

  task automatic asynchronous_contention;
    integer n; begin
      $display("CMR_ROUTER_CASE celement_async_four_input_contention");
      reset_router(); contention_monitor = 1'b1;
      // All packets are upward-bound.  The 0/2/5/11 ns offsets intentionally
      // exercise non-cycle-aligned arbitration and sticky losing requests.
      fork
        drive_contender(0, 2'd0, 0);
        drive_contender(1, 2'd1, 2);
        drive_contender(2, 2'd2, 5);
        drive_contender(3, 2'd3, 11);
      join
      n = 0;
      while (contention_total < 12 && n < 100000) begin #1; n = n + 1; end
      check(contention_total == 12, "contention did not deliver all twelve flits");
      for (n=0; n<4; n=n+1) begin
        check(contention_seen[n] == 3 && contention_phase[n] == 3, "contention packet incomplete");
        check(contention_lane[n] == 4 || contention_lane[n] == 5, "contention packet missing lane ownership");
      end
      #10; contention_monitor = 1'b0;
      check(Reqout === Ackin && !$isunknown({Reqout,Ackout}), "contention Router did not return idle");
    end
  endtask

  task automatic unicast_sticky_lane;
    begin
      $display("CMR_ROUTER_CASE celement_unicast_lane_hold"); reset_router();
      send(0, flit(1,0,8,8,8,8,2'b01)); wait_ack(0);
      wait_parent();
      check(Dataout[selected][1:0]===2'b01 && Dataout[selected][27:26]===2'b10, "unicast Head mismatch");
      Ackin[selected]=Reqout[selected]; #3;
      send(0, flit(0,0,8,8,8,8,2'b01)); wait_ack(0); wait_req(selected);
      check(Dataout[selected][1:0]===2'b01 && Dataout[selected][27:26]===2'b00, "Body migrated or corrupted"); Ackin[selected]=Reqout[selected]; #3;
      send(0, flit(0,1,8,8,8,8,2'b01)); wait_ack(0); wait_req(selected);
      check(Dataout[selected][1:0]===2'b01 && Dataout[selected][26], "Tail migrated or missing"); Ackin[selected]=Reqout[selected]; #8;
      check(Reqout===Ackin && !$isunknown({Reqout,Ackout}), "unicast did not return idle");
    end
  endtask

  task automatic parent_multicast;
    integer p; begin
      $display("CMR_ROUTER_CASE parent_multicast_f4"); reset_router();
      send(4, flit(1,0,0,0,1,1,2'b10)); wait_ack(4);
      for(p=0;p<4;p++) begin wait_req(p); check(Dataout[p][27:26]===2'b10, "multicast Head missing"); Ackin[p]=Reqout[p]; end #3;
      send(4, flit(0,0,0,0,1,1,2'b10)); wait_ack(4);
      for(p=0;p<4;p++) begin wait_req(p); check(Dataout[p][27:26]===2'b00, "multicast Body missing"); Ackin[p]=Reqout[p]; end #3;
      send(4, flit(0,1,0,0,1,1,2'b10)); wait_ack(4);
      for(p=0;p<4;p++) begin wait_req(p); check(Dataout[p][26], "multicast Tail missing"); Ackin[p]=Reqout[p]; end #8;
      check(Reqout===Ackin && !$isunknown({Reqout,Ackout}), "multicast did not return idle");
    end
  endtask

  initial begin unicast_sticky_lane(); asynchronous_contention(); parent_multicast(); if(failures==0) $display("TB_RESULT PASS CMR L1 C-element unicast+contention+multicast SDF smoke"); else $display("TB_RESULT FAIL CMR L1 C-element failures=%0d",failures); $finish; end
  initial begin #300000; $display("TB_RESULT FAIL global_timeout t=%0t",$time); $finish; end
endmodule

`timescale 1ns/1ps

module tb_cmr_router_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [4:0] Reqin = 5'b0;
  reg [27:0] Datain [0:4];
  wire [4:0] Ackout;
  wire [4:0] Reqout;
  reg [4:0] Ackin = 5'b0;
  wire [27:0] Dataout [0:4];
  wire [3:0] ParentGrant;
  wire [3:0] ParentPathEnabled;
  wire [3:0] ParentTailPassed;
  integer failures = 0;
  integer index;

  CMRRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(Reqin[0]),
    .io_inputs_child_0_0_HS_Ack(Ackout[0]),
    .io_inputs_child_0_0_Data_flit(Datain[0]),
    .io_inputs_child_1_0_HS_Req(Reqin[1]),
    .io_inputs_child_1_0_HS_Ack(Ackout[1]),
    .io_inputs_child_1_0_Data_flit(Datain[1]),
    .io_inputs_child_2_0_HS_Req(Reqin[2]),
    .io_inputs_child_2_0_HS_Ack(Ackout[2]),
    .io_inputs_child_2_0_Data_flit(Datain[2]),
    .io_inputs_child_3_0_HS_Req(Reqin[3]),
    .io_inputs_child_3_0_HS_Ack(Ackout[3]),
    .io_inputs_child_3_0_Data_flit(Datain[3]),
    .io_inputs_parent_0_HS_Req(Reqin[4]),
    .io_inputs_parent_0_HS_Ack(Ackout[4]),
    .io_inputs_parent_0_Data_flit(Datain[4]),
    .io_outputs_child_0_0_HS_Req(Reqout[0]),
    .io_outputs_child_0_0_HS_Ack(Ackin[0]),
    .io_outputs_child_0_0_Data_flit(Dataout[0]),
    .io_outputs_child_1_0_HS_Req(Reqout[1]),
    .io_outputs_child_1_0_HS_Ack(Ackin[1]),
    .io_outputs_child_1_0_Data_flit(Dataout[1]),
    .io_outputs_child_2_0_HS_Req(Reqout[2]),
    .io_outputs_child_2_0_HS_Ack(Ackin[2]),
    .io_outputs_child_2_0_Data_flit(Dataout[2]),
    .io_outputs_child_3_0_HS_Req(Reqout[3]),
    .io_outputs_child_3_0_HS_Ack(Ackin[3]),
    .io_outputs_child_3_0_Data_flit(Dataout[3]),
    .io_outputs_parent_0_HS_Req(Reqout[4]),
    .io_outputs_parent_0_HS_Ack(Ackin[4]),
    .io_outputs_parent_0_Data_flit(Dataout[4])
  );

  assign ParentGrant = {
    dut.OutputPortModules_4_io_Grant_3,
    dut.OutputPortModules_4_io_Grant_2,
    dut.OutputPortModules_4_io_Grant_1,
    dut.OutputPortModules_4_io_Grant_0
  };
  assign ParentPathEnabled = {
    dut.OutputPortModules_4_io_PktPathEnable_3,
    dut.OutputPortModules_4_io_PktPathEnable_2,
    dut.OutputPortModules_4_io_PktPathEnable_1,
    dut.OutputPortModules_4_io_PktPathEnable_0
  };
  assign ParentTailPassed = {
    dut.OutputPortModules_4_io_TailPassed_3,
    dut.OutputPortModules_4_io_TailPassed_2,
    dut.OutputPortModules_4_io_TailPassed_1,
    dut.OutputPortModules_4_io_TailPassed_0
  };

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head,
    input bit Tail,
    input [5:0] x0,
    input [5:0] y0,
    input [5:0] x1,
    input [5:0] y1,
    input [1:0] id
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head;
      make_flit[26] = Tail;
      make_flit[7:2] = x0;
      make_flit[13:8] = y0;
      make_flit[19:14] = x1;
      make_flit[25:20] = y1;
      make_flit[1:0] = id;
    end
  endfunction

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b out=%b/%b grant=%b ppe=%b tp=%b",
               message, $time, Reqin, Ackout, Reqout, Ackin, ParentGrant,
               ParentPathEnabled, ParentTailPassed);
    end
  endtask

  task automatic check_known;
    begin
      check(!$isunknown({Reqin, Ackout, Reqout, Ackin, ParentGrant}),
            "stable Router control contains X/Z");
      check($onehot0(ParentGrant), "parent OPM Grant is not one-hot-or-zero");
    end
  endtask

  task automatic wait_input_ack(input integer port);
    integer timeout;
    begin
      timeout = 0;
      while ((Ackout[port] !== Reqin[port]) && timeout < 80) begin
        #1; timeout = timeout + 1;
      end
      check(Ackout[port] === Reqin[port], "input acknowledgement timed out");
    end
  endtask

  task automatic wait_output_request(input integer port);
    integer timeout;
    begin
      timeout = 0;
      while ((Reqout[port] === Ackin[port]) && timeout < 80) begin
        #1; timeout = timeout + 1;
      end
      check(Reqout[port] !== Ackin[port], "output request timed out");
    end
  endtask

  task automatic acknowledge_output(input integer port);
    begin
      wait_output_request(port);
      Ackin[port] = Reqout[port];
      #3;
    end
  endtask

  task automatic send_flit(input integer port, input [27:0] flit);
    begin
      Datain[port] = flit;
      #1;
      Reqin[port] = ~Reqin[port];
    end
  endtask

  task automatic reset_router;
    begin
      reset = 1'b1;
      Reqin = 5'b0;
      Ackin = 5'b0;
      for (index = 0; index < 5; index = index + 1)
        Datain[index] = 28'b0;
      #5;
      reset = 1'b0;
      #5;
      check(Ackout === 5'b00000 && Reqout === 5'b00000,
            "Router reset handshake phase mismatch");
      check_known();
    end
  endtask

  task automatic test_parent_multicast;
    integer output_port;
    begin
      $display("CMR_ROUTER_CASE parent multicast/backpressure/no-U-turn");
      reset_router();

      // L1 parent ingress, rectangle (0,0)-(1,1), reaches all four children.
      send_flit(4, make_flit(1, 0, 0, 0, 1, 1, 2'b01));
      wait_input_ack(4);
      for (output_port = 0; output_port < 4; output_port = output_port + 1) begin
        wait_output_request(output_port);
        check(Dataout[output_port][27:26] === 2'b10,
              "multicast Head data mismatch");
      end
      check(Reqout[4] === Ackin[4], "parent ingress made a U-turn");

      // Hold child2's Head while the other branches consume Head and Body.
      acknowledge_output(0);
      acknowledge_output(1);
      acknowledge_output(3);
      send_flit(4, make_flit(0, 0, 0, 0, 1, 1, 2'b10));
      wait_input_ack(4);
      for (output_port = 0; output_port < 4; output_port = output_port + 1) begin
        if (output_port != 2) begin
          wait_output_request(output_port);
          check(Dataout[output_port][27:26] === 2'b00,
                "multicast Body data mismatch");
          acknowledge_output(output_port);
        end
      end
      check(Dataout[2][27:26] === 2'b10,
            "backpressured branch did not retain Head");

      send_flit(4, make_flit(0, 1, 0, 0, 1, 1, 2'b11));
      #5;
      check(Ackout[4] !== Reqin[4],
            "Tail crossed barrier while one multicast branch retained Head");

      // Fast branches accept Tail into their OPM output latch but child2 still
      // keeps the CMR Tail barrier closed.
      for (output_port = 0; output_port < 4; output_port = output_port + 1) begin
        if (output_port != 2) begin
          wait_output_request(output_port);
          check(Dataout[output_port][26] === 1'b1,
                "fast multicast branch did not reach Tail");
        end
      end
      check(Ackout[4] !== Reqin[4],
            "Tail acknowledged before slow branch caught up");

      acknowledge_output(2); // Head
      wait_output_request(2);
      check(Dataout[2][27:26] === 2'b00,
            "slow multicast branch did not expose Body");
      acknowledge_output(2); // Body
      wait_output_request(2);
      check(Dataout[2][26] === 1'b1,
            "slow multicast branch did not expose Tail");
      wait_input_ack(4);

      // Retire all Tail flits from the OPM output latches.
      for (output_port = 0; output_port < 4; output_port = output_port + 1)
        acknowledge_output(output_port);
      check(Reqout[4] === Ackin[4], "parent output changed during no-U-turn case");

      // Without reset, establish a new packet with a different route set.
      // Destination (1,0) maps only to physical child1 at L1 (0,0).
      send_flit(4, make_flit(1, 0, 1, 0, 1, 0, 2'b00));
      wait_input_ack(4);
      wait_output_request(1);
      check(Reqout[0] === Ackin[0] && Reqout[2] === Ackin[2] &&
            Reqout[3] === Ackin[3] && Reqout[4] === Ackin[4],
            "previous multicast PathEnabled polluted the next packet");
      acknowledge_output(1);
      send_flit(4, make_flit(0, 0, 1, 0, 1, 0, 2'b01));
      wait_input_ack(4);
      acknowledge_output(1);
      send_flit(4, make_flit(0, 1, 1, 0, 1, 0, 2'b10));
      wait_output_request(1);
      wait_input_ack(4);
      acknowledge_output(1);
      #3;
      check(Reqout === Ackin,
            "second packet did not retire all output requests");
      check_known();
    end
  endtask

  task automatic test_each_child_no_uturn;
    integer child;
    begin
      $display("CMR_ROUTER_CASE every child ingress to parent/no-U-turn");
      for (child = 0; child < 4; child = child + 1) begin
        reset_router();
        // Destination outside this L1 tree forces an upward copy.
        send_flit(child, make_flit(1, 0, 8, 8, 8, 8, child[1:0]));
        wait_input_ack(child);
        wait_output_request(4);
        check(Reqout[child] === Ackin[child],
              "child ingress requested its own child output");
        check(Dataout[4][1:0] === child[1:0],
              "parent output carried the wrong child input");
        acknowledge_output(4);

        send_flit(child, make_flit(0, 1, 8, 8, 8, 8, child[1:0]));
        wait_output_request(4);
        check(Reqout[child] === Ackin[child],
              "child Tail requested its own child output");
        wait_input_ack(child);
        acknowledge_output(4);
        check_known();
      end
    end
  endtask

  task automatic test_parent_contention;
    integer winner;
    integer loser;
    begin
      $display("CMR_ROUTER_CASE two child IPMs contend for parent OPM");
      reset_router();
      Datain[0] = make_flit(1, 0, 8, 8, 8, 8, 2'b01);
      Datain[1] = make_flit(1, 0, 8, 8, 8, 8, 2'b10);
      #1; Reqin[1:0] = ~Reqin[1:0];
      wait_input_ack(0);
      wait_input_ack(1);
      wait_output_request(4);
      #2;
      check($onehot(ParentGrant), "parent OPM did not resolve contention one-hot");
      winner = Dataout[4][1:0] == 2'b01 ? 0 : 1;
      loser = 1 - winner;
      check(Dataout[4][1:0] === (winner == 0 ? 2'b01 : 2'b10),
            "parent OPM selected unknown contender data");
      acknowledge_output(4); // winner Head

      // Keep the paper's explicit Head/Body/Tail packet sequence. Both Body
      // flits enter their independent CMR buffers, while only the owner may
      // advance through the contested OPM.
      send_flit(0, make_flit(0, 0, 8, 8, 8, 8, 2'b01));
      send_flit(1, make_flit(0, 0, 8, 8, 8, 8, 2'b10));
      wait_input_ack(0);
      wait_input_ack(1);
      wait_output_request(4);
      check(Dataout[4][1:0] === (winner == 0 ? 2'b01 : 2'b10) &&
            Dataout[4][27:26] === 2'b00,
            "winner Body did not follow its Head");
      acknowledge_output(4); // winner Body

      send_flit(0, make_flit(0, 1, 8, 8, 8, 8, 2'b01));
      send_flit(1, make_flit(0, 1, 8, 8, 8, 8, 2'b10));
      wait_output_request(4);
      check(Dataout[4][1:0] === (winner == 0 ? 2'b01 : 2'b10) &&
            Dataout[4][26] === 1'b1,
            "winner did not retain parent OPM through Tail");
      wait_input_ack(winner);
      check(Ackout[loser] !== Reqin[loser],
            "loser Tail acknowledged before acquiring parent OPM");
      acknowledge_output(4); // winner Tail

      wait_output_request(4);
      check(Dataout[4][1:0] === (loser == 0 ? 2'b01 : 2'b10) &&
            Dataout[4][27] === 1'b1,
            "waiting contender did not take parent OPM after winner Tail");
      acknowledge_output(4); // loser Head
      wait_output_request(4);
      check(Dataout[4][1:0] === (loser == 0 ? 2'b01 : 2'b10) &&
            Dataout[4][27:26] === 2'b00,
            "waiting contender Body did not follow its Head");
      acknowledge_output(4); // loser Body
      wait_output_request(4);
      check(Dataout[4][1:0] === (loser == 0 ? 2'b01 : 2'b10) &&
            Dataout[4][26] === 1'b1,
            "waiting contender Tail did not follow its Head");
      wait_input_ack(loser);
      acknowledge_output(4);
      #4;
      check(ParentGrant === 4'b0000,
            "parent OPM retained Grant after both packets");
      check_known();
    end
  endtask

  initial begin
    for (index = 0; index < 5; index = index + 1)
      Datain[index] = 28'b0;

    test_parent_multicast();
    test_each_child_no_uturn();
    test_parent_contention();

    if (failures == 0)
      $display("TB_RESULT PASS CMR five-port Router/no-U-turn smoke");
    else
      $display("TB_RESULT FAIL CMR Router failures=%0d", failures);
    $finish;
  end
endmodule

`timescale 1ns/1ps

// xsim-only replacement for the ASIC NAND used inside MullerC3.  It is part
// of the test environment, never the synthesized UltraRouter implementation.
`ifdef ULTRA_LOCAL_SIM
module ND2D1BWP12T30P140(input wire A1, input wire A2, output wire ZN);
  assign ZN = ~(A1 & A2);
endmodule
`endif

// Boundary-only UltraRouter smoke.  The source advances solely after the
// external two-phase acknowledgement returns: AckIn == ReqIn.
module tb_ultra_router_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [4:0] in_req = 5'b0;
  wire [4:0] in_ack;
  reg [27:0] in_data [0:4];
  wire [4:0] out_req;
  reg [4:0] out_ack = 5'b0;
  wire [27:0] out_data [0:4];
  integer i;

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

  always #5 clock = ~clock;

  task automatic fail(input [8*120-1:0] reason);
    begin
      $display("TB_RESULT FAIL %0s t=%0t in=%b/%b out=%b/%b", reason, $time, in_req, in_ack, out_req, out_ack);
      $finish(1);
    end
  endtask

  task automatic wait_input_ack(input integer port);
    integer timeout;
    begin
      timeout = 0;
      while (in_ack[port] !== in_req[port] && timeout < 1000) begin #1; timeout = timeout + 1; end
      if (timeout == 1000) fail("timeout waiting for AckIn");
    end
  endtask

  task automatic send_flit(input integer port, input [27:0] flit);
    begin
      // External bundled-data contract: source obtains the two-phase slot,
      // then makes Data stable before the request transition closes V1.
      wait_input_ack(port);
      in_data[port] = flit;
      #0.2;
      in_req[port] = ~in_req[port];
      wait_input_ack(port);
    end
  endtask

  task automatic receive_parent(input [27:0] expected);
    integer timeout;
    begin
      timeout = 0;
      while (out_req[4] === out_ack[4] && timeout < 2000) begin #1; timeout = timeout + 1; end
      if (timeout == 2000) fail("timeout waiting for parent ReqOut");
      if (out_data[4] !== expected) fail("parent bundled data mismatch");
      out_ack[4] = out_req[4];
      #1;
    end
  endtask

  initial begin
    for (i = 0; i < 5; i = i + 1) in_data[i] = 28'b0;
    // Hold reset from time zero while the surrounding reset protocol opens
    // every latch and presents zero at its D input.
    #20 reset = 1'b0;
    #2;
    if (in_ack !== 5'b0 || out_req !== 5'b0) fail("reset did not clear boundary phases");

    // child0 -> parent: Head, Body, Tail.  No internal probe participates.
    send_flit(0, 28'h8820820); receive_parent(28'h8820820);
    send_flit(0, 28'h0020820); receive_parent(28'h0020820);
    send_flit(0, 28'h4420820); receive_parent(28'h4420820);
    if (in_ack[0] !== in_req[0]) fail("Tail input handshake incomplete");
    $display("TB_RESULT PASS UltraRouter unicast3");
    $finish;
  end
endmodule

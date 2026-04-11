`timescale 1ns/1ps
`default_nettype tri0

module three_level_quadtree_tb;
  localparam int FLIT_W = 22;
  localparam int TIMEOUT_PS = 400000;

  logic clock;
  logic reset;

  logic              io_core_inputs_0_HS_Req;
  wire               io_core_inputs_0_HS_Ack;
  logic [FLIT_W-1:0] io_core_inputs_0_Data_flit;

  wire               io_core_outputs_63_HS_Req;
  logic              io_core_outputs_63_HS_Ack;
  wire [FLIT_W-1:0]  io_core_outputs_63_Data_flit;

  wire               io_top_output_0_HS_Req;
  logic              io_top_output_0_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_0_Data_flit;
  wire               io_top_output_1_HS_Req;
  logic              io_top_output_1_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_1_Data_flit;
  wire               io_top_output_2_HS_Req;
  logic              io_top_output_2_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_2_Data_flit;
  wire               io_top_output_3_HS_Req;
  logic              io_top_output_3_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_3_Data_flit;
  wire               io_top_output_4_HS_Req;
  logic              io_top_output_4_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_4_Data_flit;
  wire               io_top_output_5_HS_Req;
  logic              io_top_output_5_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_5_Data_flit;
  wire               io_top_output_6_HS_Req;
  logic              io_top_output_6_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_6_Data_flit;
  wire               io_top_output_7_HS_Req;
  logic              io_top_output_7_HS_Ack;
  wire [FLIT_W-1:0]  io_top_output_7_Data_flit;

  integer unexpected_top_flits;

  function automatic [FLIT_W-1:0] mk_flit_rect(
    input bit       isHead,
    input bit       isTail,
    input [3:0]     treeId,
    input [2:0]     xMin,
    input [2:0]     xMax,
    input [2:0]     yMin,
    input [2:0]     yMax,
    input [1:0]     pktId
  );
    mk_flit_rect = {
      isHead,             // [21]
      isTail,             // [20]
      treeId,             // [19:16]
      xMin,               // [15:13]
      xMax,               // [12:10]
      yMin,               // [9:7]
      yMax,               // [6:4]
      2'b00,              // [3:2] reserved
      pktId               // [1:0]
    };
  endfunction

  task automatic send_flit(input [FLIT_W-1:0] flit);
    time waited;
    begin
      io_core_inputs_0_Data_flit = flit;
      io_core_inputs_0_HS_Req = ~io_core_inputs_0_HS_Req;
      waited = 0;
      while (io_core_inputs_0_HS_Ack !== io_core_inputs_0_HS_Req) begin
        #1;
        waited += 1;
        if (waited >= TIMEOUT_PS) begin
          $fatal(1, "Timeout waiting input ack at t=%0t ps", $time);
        end
      end
    end
  endtask

  task automatic recv_flit(output [FLIT_W-1:0] flit);
    time waited;
    begin
      waited = 0;
      while (io_core_outputs_63_HS_Req === io_core_outputs_63_HS_Ack) begin
        #1;
        waited += 1;
        if (waited >= TIMEOUT_PS) begin
          $fatal(1, "Timeout waiting output req at t=%0t ps", $time);
        end
      end
      flit = io_core_outputs_63_Data_flit;
      io_core_outputs_63_HS_Ack = io_core_outputs_63_HS_Req;
    end
  endtask

  always @(io_top_output_0_HS_Req or reset) begin
    if (!reset && (io_top_output_0_HS_Req !== io_top_output_0_HS_Ack)) begin
      io_top_output_0_HS_Ack <= io_top_output_0_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_1_HS_Req or reset) begin
    if (!reset && (io_top_output_1_HS_Req !== io_top_output_1_HS_Ack)) begin
      io_top_output_1_HS_Ack <= io_top_output_1_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_2_HS_Req or reset) begin
    if (!reset && (io_top_output_2_HS_Req !== io_top_output_2_HS_Ack)) begin
      io_top_output_2_HS_Ack <= io_top_output_2_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_3_HS_Req or reset) begin
    if (!reset && (io_top_output_3_HS_Req !== io_top_output_3_HS_Ack)) begin
      io_top_output_3_HS_Ack <= io_top_output_3_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_4_HS_Req or reset) begin
    if (!reset && (io_top_output_4_HS_Req !== io_top_output_4_HS_Ack)) begin
      io_top_output_4_HS_Ack <= io_top_output_4_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_5_HS_Req or reset) begin
    if (!reset && (io_top_output_5_HS_Req !== io_top_output_5_HS_Ack)) begin
      io_top_output_5_HS_Ack <= io_top_output_5_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_6_HS_Req or reset) begin
    if (!reset && (io_top_output_6_HS_Req !== io_top_output_6_HS_Ack)) begin
      io_top_output_6_HS_Ack <= io_top_output_6_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end
  always @(io_top_output_7_HS_Req or reset) begin
    if (!reset && (io_top_output_7_HS_Req !== io_top_output_7_HS_Ack)) begin
      io_top_output_7_HS_Ack <= io_top_output_7_HS_Req;
      unexpected_top_flits = unexpected_top_flits + 1;
    end
  end

  three_level_quadtree dut (
    .clock(clock),
    .reset(reset),
    .io_core_inputs_0_HS_Req(io_core_inputs_0_HS_Req),
    .io_core_inputs_0_HS_Ack(io_core_inputs_0_HS_Ack),
    .io_core_inputs_0_Data_flit(io_core_inputs_0_Data_flit),
    .io_core_outputs_63_HS_Req(io_core_outputs_63_HS_Req),
    .io_core_outputs_63_HS_Ack(io_core_outputs_63_HS_Ack),
    .io_core_outputs_63_Data_flit(io_core_outputs_63_Data_flit),
    .io_top_output_0_HS_Req(io_top_output_0_HS_Req),
    .io_top_output_0_HS_Ack(io_top_output_0_HS_Ack),
    .io_top_output_0_Data_flit(io_top_output_0_Data_flit),
    .io_top_output_1_HS_Req(io_top_output_1_HS_Req),
    .io_top_output_1_HS_Ack(io_top_output_1_HS_Ack),
    .io_top_output_1_Data_flit(io_top_output_1_Data_flit),
    .io_top_output_2_HS_Req(io_top_output_2_HS_Req),
    .io_top_output_2_HS_Ack(io_top_output_2_HS_Ack),
    .io_top_output_2_Data_flit(io_top_output_2_Data_flit),
    .io_top_output_3_HS_Req(io_top_output_3_HS_Req),
    .io_top_output_3_HS_Ack(io_top_output_3_HS_Ack),
    .io_top_output_3_Data_flit(io_top_output_3_Data_flit),
    .io_top_output_4_HS_Req(io_top_output_4_HS_Req),
    .io_top_output_4_HS_Ack(io_top_output_4_HS_Ack),
    .io_top_output_4_Data_flit(io_top_output_4_Data_flit),
    .io_top_output_5_HS_Req(io_top_output_5_HS_Req),
    .io_top_output_5_HS_Ack(io_top_output_5_HS_Ack),
    .io_top_output_5_Data_flit(io_top_output_5_Data_flit),
    .io_top_output_6_HS_Req(io_top_output_6_HS_Req),
    .io_top_output_6_HS_Ack(io_top_output_6_HS_Ack),
    .io_top_output_6_Data_flit(io_top_output_6_Data_flit),
    .io_top_output_7_HS_Req(io_top_output_7_HS_Req),
    .io_top_output_7_HS_Ack(io_top_output_7_HS_Ack),
    .io_top_output_7_Data_flit(io_top_output_7_Data_flit)
  );

  initial begin
    clock = 1'b0;
    forever #5 clock = ~clock;
  end

  initial begin
    reg [FLIT_W-1:0] head_flit;
    reg [FLIT_W-1:0] body_flit;
    reg [FLIT_W-1:0] tail_flit;
    reg [FLIT_W-1:0] recv_head;
    reg [FLIT_W-1:0] recv_body;
    reg [FLIT_W-1:0] recv_tail;

    reset = 1'b1;
    io_core_inputs_0_HS_Req = 1'b0;
    io_core_inputs_0_Data_flit = '0;
    io_core_outputs_63_HS_Ack = 1'b0;
    io_top_output_0_HS_Ack = 1'b0;
    io_top_output_1_HS_Ack = 1'b0;
    io_top_output_2_HS_Ack = 1'b0;
    io_top_output_3_HS_Ack = 1'b0;
    io_top_output_4_HS_Ack = 1'b0;
    io_top_output_5_HS_Ack = 1'b0;
    io_top_output_6_HS_Ack = 1'b0;
    io_top_output_7_HS_Ack = 1'b0;
    unexpected_top_flits = 0;

    #20;
    reset = 1'b0;
    #10;

    // Unicast: core0 -> core63 in local tree 0, destination (x=7,y=7)
    head_flit = mk_flit_rect(1'b1, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    body_flit = mk_flit_rect(1'b0, 1'b0, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);
    tail_flit = mk_flit_rect(1'b0, 1'b1, 4'd0, 3'd7, 3'd7, 3'd7, 3'd7, 2'd1);

    fork
      begin
        send_flit(head_flit);
        send_flit(body_flit);
        send_flit(tail_flit);
      end
      begin
        recv_flit(recv_head);
        recv_flit(recv_body);
        recv_flit(recv_tail);
      end
    join

    if (recv_head !== head_flit) $fatal(1, "Head flit mismatch");
    if (recv_body !== body_flit) $fatal(1, "Body flit mismatch");
    if (recv_tail !== tail_flit) $fatal(1, "Tail flit mismatch");
    if (unexpected_top_flits != 0) $fatal(1, "Unexpected top traffic: %0d flits", unexpected_top_flits);

    $display("three_level_quadtree_tb PASSED");
    #20;
    $finish;
  end
endmodule

`default_nettype wire

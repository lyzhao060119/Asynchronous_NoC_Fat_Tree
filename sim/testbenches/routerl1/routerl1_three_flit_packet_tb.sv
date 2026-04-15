`timescale 1ns / 1ps

module routerl1_three_flit_packet_tb;
  localparam int FLIT_W = 28;
  logic clock;
  logic reset;

  logic        io_inputs_child_0_0_HS_Req;
  logic        io_inputs_child_0_0_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_child_0_0_Data_flit;
  logic        io_inputs_child_1_0_HS_Req;
  logic        io_inputs_child_1_0_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_child_1_0_Data_flit;
  logic        io_inputs_child_2_0_HS_Req;
  logic        io_inputs_child_2_0_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_child_2_0_Data_flit;
  logic        io_inputs_child_3_0_HS_Req;
  logic        io_inputs_child_3_0_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_child_3_0_Data_flit;
  logic        io_inputs_parent_0_HS_Req;
  logic        io_inputs_parent_0_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_parent_0_Data_flit;
  logic        io_inputs_parent_1_HS_Req;
  logic        io_inputs_parent_1_HS_Ack;
  logic [FLIT_W-1:0] io_inputs_parent_1_Data_flit;

  logic        io_outputs_child_0_0_HS_Req;
  logic        io_outputs_child_0_0_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_child_0_0_Data_flit;
  logic        io_outputs_child_1_0_HS_Req;
  logic        io_outputs_child_1_0_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_child_1_0_Data_flit;
  logic        io_outputs_child_2_0_HS_Req;
  logic        io_outputs_child_2_0_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_child_2_0_Data_flit;
  logic        io_outputs_child_3_0_HS_Req;
  logic        io_outputs_child_3_0_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_child_3_0_Data_flit;
  logic        io_outputs_parent_0_HS_Req;
  logic        io_outputs_parent_0_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_parent_0_Data_flit;
  logic        io_outputs_parent_1_HS_Req;
  logic        io_outputs_parent_1_HS_Ack;
  logic [FLIT_W-1:0] io_outputs_parent_1_Data_flit;

  function automatic [FLIT_W-1:0] mk_flit_rect(
    input bit isHead,
    input bit isTail,
    input [5:0] x0,
    input [5:0] y0,
    input [5:0] x1,
    input [5:0] y1,
    input [1:0] pktId
  );
    mk_flit_rect = {
      isHead,
      isTail,
      y1,
      x1,
      y0,
      x0,
      pktId
    };
  endfunction

  localparam logic [FLIT_W-1:0] HEAD_FLIT = mk_flit_rect(1'b1, 1'b0, 6'd0, 6'd0, 6'd1, 6'd1, 2'd1);
  localparam logic [FLIT_W-1:0] BODY_FLIT = mk_flit_rect(1'b0, 1'b0, 6'd0, 6'd0, 6'd1, 6'd1, 2'd1);
  localparam logic [FLIT_W-1:0] TAIL_FLIT = mk_flit_rect(1'b0, 1'b1, 6'd0, 6'd0, 6'd1, 6'd1, 2'd1);

  integer child_count_0;
  integer child_count_1;
  integer child_count_2;
  integer child_count_3;

  RouterL1 dut (.*);

  always #5 clock = ~clock;

  task automatic send_parent0(input logic [FLIT_W-1:0] flit);
    begin
      io_inputs_parent_0_Data_flit = flit;
      #1;
      io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
      $display("[%0t ns] inject parent0 flit=0x%07h req=%0b", $realtime, flit, io_inputs_parent_0_HS_Req);
      wait (io_inputs_parent_0_HS_Ack === io_inputs_parent_0_HS_Req);
      $display("[%0t ns] parent0 ack  =0x%07h ack=%0b", $realtime, flit, io_inputs_parent_0_HS_Ack);
      #1;
    end
  endtask

  initial begin
    clock = 1'b0;
    reset = 1'b1;

    io_inputs_child_0_0_HS_Req = 1'b0;
    io_inputs_child_0_0_Data_flit = '0;
    io_inputs_child_1_0_HS_Req = 1'b0;
    io_inputs_child_1_0_Data_flit = '0;
    io_inputs_child_2_0_HS_Req = 1'b0;
    io_inputs_child_2_0_Data_flit = '0;
    io_inputs_child_3_0_HS_Req = 1'b0;
    io_inputs_child_3_0_Data_flit = '0;
    io_inputs_parent_0_HS_Req = 1'b0;
    io_inputs_parent_0_Data_flit = '0;
    io_inputs_parent_1_HS_Req = 1'b0;
    io_inputs_parent_1_Data_flit = '0;

    io_outputs_child_0_0_HS_Ack = 1'b0;
    io_outputs_child_1_0_HS_Ack = 1'b0;
    io_outputs_child_2_0_HS_Ack = 1'b0;
    io_outputs_child_3_0_HS_Ack = 1'b0;
    io_outputs_parent_0_HS_Ack = 1'b0;
    io_outputs_parent_1_HS_Ack = 1'b0;

    child_count_0 = 0;
    child_count_1 = 0;
    child_count_2 = 0;
    child_count_3 = 0;

    #20;
    reset = 1'b0;
    $display("[%0t ns] reset released", $realtime);

    #20;
    send_parent0(HEAD_FLIT);
    send_parent0(BODY_FLIT);
    send_parent0(TAIL_FLIT);

    wait (child_count_0 == 3 && child_count_1 == 3 && child_count_2 == 3 && child_count_3 == 3);
    #20;
    $display("[%0t ns] child counts = %0d %0d %0d %0d", $realtime, child_count_0, child_count_1, child_count_2, child_count_3);
    $finish;
  end

  initial begin
    #2000;
    $fatal(1, "timeout waiting for RouterL1 multicast packet to drain");
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_child_0_0_HS_Req or io_outputs_child_0_0_HS_Ack);
      if ((io_outputs_child_0_0_HS_Req !== 1'bx) &&
          (io_outputs_child_0_0_HS_Ack !== 1'bx) &&
          (io_outputs_child_0_0_HS_Req != io_outputs_child_0_0_HS_Ack)) begin
        child_count_0 = child_count_0 + 1;
        $display("[%0t ns] child0 recv #%0d flit=0x%07h", $realtime, child_count_0, io_outputs_child_0_0_Data_flit);
        #2;
        io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Req;
        $display("[%0t ns] child0 ack  #%0d", $realtime, child_count_0);
        wait (io_outputs_child_0_0_HS_Req === io_outputs_child_0_0_HS_Ack);
      end
    end
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_child_1_0_HS_Req or io_outputs_child_1_0_HS_Ack);
      if ((io_outputs_child_1_0_HS_Req !== 1'bx) &&
          (io_outputs_child_1_0_HS_Ack !== 1'bx) &&
          (io_outputs_child_1_0_HS_Req != io_outputs_child_1_0_HS_Ack)) begin
        child_count_1 = child_count_1 + 1;
        $display("[%0t ns] child1 recv #%0d flit=0x%07h", $realtime, child_count_1, io_outputs_child_1_0_Data_flit);
        #4;
        io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Req;
        $display("[%0t ns] child1 ack  #%0d", $realtime, child_count_1);
        wait (io_outputs_child_1_0_HS_Req === io_outputs_child_1_0_HS_Ack);
      end
    end
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_child_2_0_HS_Req or io_outputs_child_2_0_HS_Ack);
      if ((io_outputs_child_2_0_HS_Req !== 1'bx) &&
          (io_outputs_child_2_0_HS_Ack !== 1'bx) &&
          (io_outputs_child_2_0_HS_Req != io_outputs_child_2_0_HS_Ack)) begin
        child_count_2 = child_count_2 + 1;
        $display("[%0t ns] child2 recv #%0d flit=0x%07h", $realtime, child_count_2, io_outputs_child_2_0_Data_flit);
        #6;
        io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Req;
        $display("[%0t ns] child2 ack  #%0d", $realtime, child_count_2);
        wait (io_outputs_child_2_0_HS_Req === io_outputs_child_2_0_HS_Ack);
      end
    end
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_child_3_0_HS_Req or io_outputs_child_3_0_HS_Ack);
      if ((io_outputs_child_3_0_HS_Req !== 1'bx) &&
          (io_outputs_child_3_0_HS_Ack !== 1'bx) &&
          (io_outputs_child_3_0_HS_Req != io_outputs_child_3_0_HS_Ack)) begin
        child_count_3 = child_count_3 + 1;
        $display("[%0t ns] child3 recv #%0d flit=0x%07h", $realtime, child_count_3, io_outputs_child_3_0_Data_flit);
        #8;
        io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Req;
        $display("[%0t ns] child3 ack  #%0d", $realtime, child_count_3);
        wait (io_outputs_child_3_0_HS_Req === io_outputs_child_3_0_HS_Ack);
      end
    end
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_parent_0_HS_Req or io_outputs_parent_0_HS_Ack);
      if ((io_outputs_parent_0_HS_Req !== 1'bx) &&
          (io_outputs_parent_0_HS_Ack !== 1'bx) &&
          (io_outputs_parent_0_HS_Req != io_outputs_parent_0_HS_Ack)) begin
        $fatal(1, "[%0t ns] unexpected parent0 output flit=0x%07h", $realtime, io_outputs_parent_0_Data_flit);
      end
    end
  end

  initial begin
    wait (reset === 1'b0);
    #1;
    forever begin
      @(io_outputs_parent_1_HS_Req or io_outputs_parent_1_HS_Ack);
      if ((io_outputs_parent_1_HS_Req !== 1'bx) &&
          (io_outputs_parent_1_HS_Ack !== 1'bx) &&
          (io_outputs_parent_1_HS_Req != io_outputs_parent_1_HS_Ack)) begin
        $fatal(1, "[%0t ns] unexpected parent1 output flit=0x%07h", $realtime, io_outputs_parent_1_Data_flit);
      end
    end
  end
endmodule

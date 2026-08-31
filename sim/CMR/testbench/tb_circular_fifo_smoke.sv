`timescale 1ns/1ps

// Functional smoke for the fixed Transition Fig. 6 ring: four physical
// control blocks, four usable flits, and a Gray-phase successor map.
module tb_circular_fifo_smoke;
  localparam FLIT_LENGTH = 28;
  localparam CAPACITY = 4;

  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg Ackin = 1'b0;
  reg [FLIT_LENGTH-1:0] Data_in = '0;
  wire Ackout, Reqout;
  wire [FLIT_LENGTH-1:0] Data_out;

  CircularFIFO #(.DEPTH(4), .FLIT_LENGTH(FLIT_LENGTH)) dut (
    .reset(reset), .Reqin(Reqin), .Ackin(Ackin), .Data_in(Data_in),
    .Ackout(Ackout), .Reqout(Reqout), .Data_out(Data_out)
  );

  integer failures = 0;
  integer rx_count = 0;

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t reqin=%b ackout=%b reqout=%b ackin=%b wp=%b rp=%b full=%b empty=%b req=%b",
               message, $time, Reqin, Ackout, Reqout, Ackin,
               dut.WritePointer, dut.ReadCounterPtr, dut.Full, dut.Empty, dut.CellReq);
    end
  endtask

  task automatic wait_write_done;
    integer n;
    begin
      for (n = 0; n < 100; n = n + 1) begin
        if (Reqin === Ackout) return;
        #1;
      end
      check(0, "upstream handshake timeout");
    end
  endtask

  task automatic wait_read_request;
    integer n;
    begin
      for (n = 0; n < 100; n = n + 1) begin
        if (Reqout !== Ackin) return;
        #1;
      end
      check(0, "downstream request timeout");
    end
  endtask

  task automatic write_flit(input [FLIT_LENGTH-1:0] data);
    begin
      Data_in = data;
      #1;
      Reqin = ~Reqin;
      wait_write_done();
      #1;
    end
  endtask

  task automatic read_flit(input [FLIT_LENGTH-1:0] expected);
    begin
      wait_read_request();
      check(Data_out === expected,
            $sformatf("data mismatch expected=%h got=%h", expected, Data_out));
      Ackin = Reqout;
      rx_count = rx_count + 1;
      #1;
    end
  endtask

  initial begin
    $display("TB_START transition_fig6_circular_fifo_smoke");
    #10 reset = 1'b0;
    #5;

    check({dut.Full, dut.Empty, dut.CellReq} === {4'b1100, 4'b1100, 4'b1100},
          "paper reset phase must be 0011 per Full/Empty/Req vector");
    check(dut.WritePointer === 4'b0001 && dut.ReadCounterPtr === 4'b0001,
          "pointers must reset at slot0");
    check(Reqin === Ackout && Reqout === Ackin, "channels not idle after reset");
    check(!$isunknown({Ackout, Reqout, Data_out}), "X/Z after reset");
    check(dut.En === 4'b0001, "after reset only the write-pointer slot may be transparent");

    // Single transfer validates WCB FullNext and RCB EmptyNext phase selects.
    write_flit(28'hA_000001);
    check(dut.WritePointer === 4'b0010, "write pointer must advance 0->1");
    check(dut.En === 4'b0010, "occupied FIFO: only the next write slot is transparent");
    begin
      logic [FLIT_LENGTH-1:0] held_out;
      logic [FLIT_LENGTH-1:0] slot2_before;
      logic [FLIT_LENGTH-1:0] slot3_before;
      held_out = Data_out;
      slot2_before = dut.SlotData[2];
      slot3_before = dut.SlotData[3];
      Data_in = 28'hF_BADBAD;
      #2;
      check(Data_out === held_out, "occupied FIFO Data_out followed Data_in");
      check(dut.SlotData[2] === slot2_before, "non-write empty slot2 followed Data_in");
      check(dut.SlotData[3] === slot3_before, "non-write empty slot3 followed Data_in");
      Data_in = 28'hA_000001;
    end
    read_flit(28'hA_000001);
    check(dut.ReadCounterPtr === 4'b0010, "read pointer must advance 0->1");

    // Re-align the paper ring before exercising full / recovery behavior.
    // The FIFO reset phase assumes both external two-phase channels reset low.
    Reqin = 1'b0;
    Ackin = 1'b0;
    Data_in = '0;
    reset = 1'b1;
    #10 reset = 1'b0;
    #5;
    write_flit(28'hB_000001);
    check(dut.WritePointer === 4'b0010, "write pointer 0->1 missing");
    write_flit(28'hB_000002);
    check(dut.WritePointer === 4'b0100, "write pointer 1->2 missing");
    write_flit(28'hB_000003);
    check(dut.WritePointer === 4'b1000, "write pointer 2->3 missing");
    write_flit(28'hB_000004);
    check(dut.WritePointer === 4'b0001, "write pointer 3->0 missing");
    check(dut.En === 4'b0000, "full FIFO must close every data latch");

    // A fifth offer must remain pending while all four physical slots hold data.
    Data_in = 28'hB_000005;
    #1 Reqin = ~Reqin;
    #20;
    check(Reqin !== Ackout, "fifth flit completed despite four-flit capacity");
    check(dut.WritePointer === 4'b0001, "write pointer moved while FIFO full");

    // A two-phase offer cannot be withdrawn. Keep the fifth request asserted,
    // free one position, and require the pending write to complete exactly once.
    read_flit(28'hB_000001);
    wait_write_done();
    #1;
    read_flit(28'hB_000002);
    read_flit(28'hB_000003);
    read_flit(28'hB_000004);
    read_flit(28'hB_000005);

    // Keep one producer and consumer active to cover pointer wrap and backpressure.
    fork
      begin : producer
        integer i;
        for (i = 1; i <= 12; i = i + 1)
          write_flit({4'hC, 24'(i)});
      end
      begin : consumer
        integer i;
        for (i = 1; i <= 12; i = i + 1)
          read_flit({4'hC, 24'(i)});
      end
    join

    #5;
    check(Reqin === Ackout && Reqout === Ackin, "channels not idle at end");
    check(!$isunknown({Ackout, Reqout, Data_out, dut.Full, dut.Empty, dut.CellReq}),
          "X/Z leaked to FIFO controls");
    if (failures == 0)
      $display("TB_RESULT PASS transition_fig6_circular_fifo_smoke rx=%0d", rx_count);
    else
      $display("TB_RESULT FAIL transition_fig6_circular_fifo_smoke failures=%0d rx=%0d", failures, rx_count);
    $finish;
  end

  initial begin
    #10000;
    $display("TB_RESULT FAIL timeout");
    $finish;
  end
endmodule

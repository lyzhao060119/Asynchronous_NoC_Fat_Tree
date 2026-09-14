`timescale 1ns/1ps

// Strict-SDF counterpart to tb_circular_fifo_smoke.  It intentionally checks
// the paper-visible control state at the gate-netlist hierarchy.
module tb_circular_fifo_gls;
  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg Ackin = 1'b0;
  reg [27:0] Data_in = '0;
  wire Ackout, Reqout;
  wire [27:0] Data_out;
  wire [3:0] DebugWritePointer, DebugReadPointer, DebugFull, DebugEmpty, DebugCellReq, DebugEn;
  // This is the mapped XNOR output driving every ReadCounter flip-flop CP.
  // It is observational only and deliberately names the post-DC instance.
  wire DebugReadCounterCP = dut.fifo.read_counter.n8;
  wire DebugReadCounterAckPin = dut.fifo.read_counter.U10.A1;
  wire DebugReadCounterReqPin = dut.fifo.read_counter.U10.A2;

  CircularFifoUnit dut (
    .reset(reset), .Reqin(Reqin), .Ackin(Ackin), .Data_in(Data_in),
    .Ackout(Ackout), .Reqout(Reqout), .Data_out(Data_out),
    .DebugWritePointer(DebugWritePointer), .DebugReadPointer(DebugReadPointer),
    .DebugFull(DebugFull), .DebugEmpty(DebugEmpty), .DebugCellReq(DebugCellReq), .DebugEn(DebugEn)
  );

  integer failures = 0;
  integer rx_count = 0;
  bit concurrent_trace = 0;
  bit first_read_mismatch = 0;

  // The gate netlist retains the four DLatchBank hierarchies.  VCD is the
  // lossless per-slot-data record; the text trace below records the control
  // state on every event during the only intentionally concurrent phase.
  initial begin
    $dumpfile("circular_fifo_unit.vcd");
    $dumpvars(0, dut.fifo);
  end

  task automatic trace_state(input string tag);
    begin
      $display("TCF_EVT t_ns=%0.3f tag=%s in=%b/%b out=%b/%b xnor_a1/a2/z=%b/%b/%b wp=%b rp=%b full=%b empty=%b req=%b en=%b din=%h dout=%h",
        $realtime, tag, Reqin, Ackout, Reqout, Ackin,
        DebugReadCounterAckPin, DebugReadCounterReqPin, DebugReadCounterCP,
        DebugWritePointer, DebugReadPointer, DebugFull, DebugEmpty,
        DebugCellReq, DebugEn, Data_in, Data_out);
    end
  endtask

  // #0 coalesces a delta-cycle burst into one causally readable snapshot.
  always @(Reqin or Ackout or Reqout or Ackin or DebugReadCounterAckPin or DebugReadCounterReqPin or DebugReadCounterCP or Data_in or Data_out or
           DebugWritePointer or DebugReadPointer or DebugFull or DebugEmpty or
           DebugCellReq or DebugEn) begin
    if (concurrent_trace) begin
      #0 trace_state("concurrent");
    end
  end

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TCF_FAIL t_ns=%0.3f %s in_r/a=%b/%b out_r/a=%b/%b wp=%b rp=%b full=%b empty=%b req=%b en=%b data=%h",
        $realtime, message, Reqin, Ackout, Reqout, Ackin,
        DebugWritePointer, DebugReadPointer, DebugFull, DebugEmpty, DebugCellReq, DebugEn, Data_out);
      if (!first_read_mismatch && message.substr(0, 8) == "TCF-RD-0") begin
        first_read_mismatch = 1;
        trace_state("FIRST_READ_MISMATCH");
      end
    end
  endtask

  task automatic no_x(input string where);
    check(!$isunknown({Ackout, Reqout, Data_out, DebugWritePointer,
      DebugReadPointer, DebugFull, DebugEmpty, DebugCellReq, DebugEn}), where);
  endtask

  task automatic wait_write_done;
    integer n;
    begin
      for (n = 0; n < 500; n = n + 1) begin
        if (Reqin === Ackout) return;
        #0.02;
      end
      check(0, "TCF-HS-01 upstream handshake timeout");
    end
  endtask

  task automatic wait_read_request;
    integer n;
    begin
      for (n = 0; n < 500; n = n + 1) begin
        if (Reqout !== Ackin) return;
        #0.02;
      end
      check(0, "TCF-HS-02 downstream request timeout");
    end
  endtask

  task automatic write_flit(input [27:0] data);
    begin
      Data_in = data;
      #1;
      Reqin = ~Reqin;
      wait_write_done();
      #1;
      no_x("X/Z after write");
    end
  endtask

  task automatic read_flit(input [27:0] expected);
    begin
      wait_read_request();
      check(Data_out === expected, $sformatf("TCF-RD-01 expected=%h got=%h", expected, Data_out));
      Ackin = Reqout;
      rx_count = rx_count + 1;
      #1;
      no_x("X/Z after read");
    end
  endtask

  initial begin
    $display("TCF_GLS_START circular_fifo_depth4");
    #10 reset = 1'b0;
    #1;
    check({DebugFull, DebugEmpty, DebugCellReq} === 12'b1100_1100_1100,
      "paper reset phase");
    check(DebugWritePointer === 4'b0001 && DebugReadPointer === 4'b0001,
      "pointer reset slot0");
    check(Reqin === Ackout && Reqout === Ackin, "channels idle after reset");
    no_x("X/Z after reset");

    write_flit(28'hA_000001);
    check(DebugWritePointer === 4'b0010, "write pointer 0->1");
    read_flit(28'hA_000001);
    check(DebugReadPointer === 4'b0010, "read pointer 0->1");

    // Reset the externally visible two-phase channels before the full test.
    Reqin = 1'b0; Ackin = 1'b0; Data_in = '0; reset = 1'b1;
    #10 reset = 1'b0;
    #1;
    write_flit(28'hB_000001);
    write_flit(28'hB_000002);
    write_flit(28'hB_000003);
    write_flit(28'hB_000004);
    check(DebugWritePointer === 4'b0001, "write pointer wrap 3->0");
    Data_in = 28'hB_000005;
    #1 Reqin = ~Reqin;
    #5;
    check(Reqin !== Ackout, "fifth write completed while full");
    check(DebugWritePointer === 4'b0001, "write pointer advanced while full");
    read_flit(28'hB_000001);
    wait_write_done();
    #1;
    read_flit(28'hB_000002);
    read_flit(28'hB_000003);
    read_flit(28'hB_000004);
    read_flit(28'hB_000005);

    concurrent_trace = 1;
    trace_state("CONCURRENT_BEGIN");
    fork
      begin : producer
        integer i;
        for (i = 1; i <= 12; i = i + 1) write_flit({4'hC, 24'(i)});
      end
      begin : consumer
        integer i;
        for (i = 1; i <= 12; i = i + 1) read_flit({4'hC, 24'(i)});
      end
    join
    trace_state("CONCURRENT_END");
    concurrent_trace = 0;
    #1;
    check(Reqin === Ackout && Reqout === Ackin, "channels idle at end");
    no_x("X/Z at end");
    if (failures == 0)
      $display("TCF_GLS_PASS rx=%0d", rx_count);
    else
      $display("TCF_GLS_FAIL failures=%0d rx=%0d", failures, rx_count);
    $finish;
  end

  initial begin
    #10000;
    $display("TCF_GLS_FAIL timeout");
    $finish;
  end
endmodule

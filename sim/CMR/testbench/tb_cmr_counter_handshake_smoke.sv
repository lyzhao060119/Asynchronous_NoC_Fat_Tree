`timescale 1ns / 1ps

module tb_cmr_counter_handshake_smoke;
  reg reset;
  reg Reqin;
  reg Ackout;
  reg ReqX;
  reg AckX;
  wire [4:0] WritePointer;
  wire [4:0] ReadPointer;

  WriteCounter write_counter (
    .reset(reset),
    .Reqin(Reqin),
    .Ackout(Ackout),
    .WritePointer(WritePointer)
  );

  ReadCounter read_counter (
    .reset(reset),
    .ReqX(ReqX),
    .AckX(AckX),
    .ReadPointer(ReadPointer)
  );

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      $display("TB_RESULT FAIL counter_handshake reason=%s t=%0t write=%b read=%b",
               message, $time, WritePointer, ReadPointer);
      $finish;
    end
  endtask

  initial begin
    reset = 1'b1;
    Reqin = 1'b0;
    Ackout = 1'b0;
    ReqX = 1'b0;
    AckX = 1'b0;
    #5;
    reset = 1'b0;
    #2;

    check(WritePointer === 5'b00001, "write reset pointer");
    check(ReadPointer === 5'b00001, "read reset pointer");

    // A request transition opens a transaction but must not advance either
    // pointer before the matching acknowledgement phase arrives.
    Reqin = 1'b1;
    ReqX = 1'b1;
    #2;
    check(WritePointer === 5'b00001, "write advanced on request only");
    check(ReadPointer === 5'b00001, "read advanced on request only");

    Ackout = 1'b1;
    AckX = 1'b1;
    #2;
    check(WritePointer === 5'b00010, "write did not advance on completed handshake");
    check(ReadPointer === 5'b00010, "read did not advance on completed handshake");

    // Exercise the falling phase of the two-phase protocol as well.
    Reqin = 1'b0;
    ReqX = 1'b0;
    #2;
    check(WritePointer === 5'b00010, "write advanced on falling request only");
    check(ReadPointer === 5'b00010, "read advanced on falling request only");

    Ackout = 1'b0;
    AckX = 1'b0;
    #2;
    check(WritePointer === 5'b00100, "write falling handshake did not advance");
    check(ReadPointer === 5'b00100, "read falling handshake did not advance");
    check($onehot(WritePointer) && $onehot(ReadPointer), "pointer is not one-hot");
    check(!$isunknown({WritePointer, ReadPointer}), "pointer contains X/Z");

    $display("TB_RESULT PASS CMR counter handshake smoke");
    $finish;
  end
endmodule

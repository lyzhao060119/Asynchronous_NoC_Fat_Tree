`timescale 1ns/1ps

module tb_write_interface_control_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg [4:0] CellEmpty [0:3];
  reg [4:0] Tail = 5'b00000;
  wire Ackout;
  wire [4:0] WritePointer;
  wire [4:0] CellFull;
  integer failures = 0;
  integer ack_transitions = 0;
  reg count_ack = 1'b0;

  WriteInterfaceControl dut (
    .clock(clock), .reset(reset), .io_Reqin(Reqin),
    .io_CellEmpty_0_0(CellEmpty[0][0]), .io_CellEmpty_0_1(CellEmpty[0][1]),
    .io_CellEmpty_0_2(CellEmpty[0][2]), .io_CellEmpty_0_3(CellEmpty[0][3]),
    .io_CellEmpty_0_4(CellEmpty[0][4]), .io_CellEmpty_1_0(CellEmpty[1][0]),
    .io_CellEmpty_1_1(CellEmpty[1][1]), .io_CellEmpty_1_2(CellEmpty[1][2]),
    .io_CellEmpty_1_3(CellEmpty[1][3]), .io_CellEmpty_1_4(CellEmpty[1][4]),
    .io_CellEmpty_2_0(CellEmpty[2][0]), .io_CellEmpty_2_1(CellEmpty[2][1]),
    .io_CellEmpty_2_2(CellEmpty[2][2]), .io_CellEmpty_2_3(CellEmpty[2][3]),
    .io_CellEmpty_2_4(CellEmpty[2][4]), .io_CellEmpty_3_0(CellEmpty[3][0]),
    .io_CellEmpty_3_1(CellEmpty[3][1]), .io_CellEmpty_3_2(CellEmpty[3][2]),
    .io_CellEmpty_3_3(CellEmpty[3][3]), .io_CellEmpty_3_4(CellEmpty[3][4]),
    .io_Tail_0(Tail[0]), .io_Tail_1(Tail[1]), .io_Tail_2(Tail[2]),
    .io_Tail_3(Tail[3]), .io_Tail_4(Tail[4]), .io_Ackout(Ackout),
    .io_WritePointer_0(WritePointer[0]), .io_WritePointer_1(WritePointer[1]),
    .io_WritePointer_2(WritePointer[2]), .io_WritePointer_3(WritePointer[3]),
    .io_WritePointer_4(WritePointer[4]), .io_CellFull_0(CellFull[0]),
    .io_CellFull_1(CellFull[1]), .io_CellFull_2(CellFull[2]),
    .io_CellFull_3(CellFull[3]), .io_CellFull_4(CellFull[4])
  );

  always @(Ackout) if (count_ack) ack_transitions = ack_transitions + 1;

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t req=%b ack=%b wp=%b full=%b",
               message, $time, Reqin, Ackout, WritePointer, CellFull);
    end
  endtask

  task automatic check_stable_known;
    check(!$isunknown({Ackout, WritePointer, CellFull}), "stable output contains X/Z");
    check($onehot(WritePointer), "WritePointer is not one-hot");
  endtask

  task automatic send_non_tail(input integer cell_index);
    reg [4:0] old_full;
    reg [4:0] expected_pointer;
    begin
      check(WritePointer === (5'b00001 << cell_index), "unexpected selected cell before write");
      Tail[cell_index] = 1'b0;
      #1;
      old_full = CellFull;
      Reqin = ~Reqin;
      #3;
      expected_pointer = 5'b00001 << ((cell_index + 1) % 5);
      check(CellFull === (old_full ^ (5'b00001 << cell_index)), "selected CellFull did not toggle alone");
      check(Ackout === Reqin, "non-Tail Ackout did not follow Reqin phase");
      check(WritePointer === expected_pointer, "WriteCounter did not advance once");
      check_stable_known();
      #3;
      check(WritePointer === expected_pointer, "pointer selection caused a phantom advance");
      check(Ackout === Reqin, "pointer selection caused a phantom Ackout");
    end
  endtask

  initial begin
    // Empty phases must match the alternating CellFull reset phases.
    CellEmpty[0] = 5'b01010;
    CellEmpty[1] = 5'b01010;
    CellEmpty[2] = 5'b01010;
    CellEmpty[3] = 5'b01010;
    #4;
    reset = 1'b0;
    #3;
    check(WritePointer === 5'b00001, "reset pointer is not cell zero");
    check(CellFull === 5'b01010, "CellFull reset phases are not 0,1,0,1,0");
    check(Ackout === 1'b0 && Reqin === 1'b0, "reset handshake phases do not agree");
    check_stable_known();
    count_ack = 1'b1;

    // Four immediate Head/Body writes exercise rising and falling phases.
    send_non_tail(0);
    send_non_tail(1);
    send_non_tail(2);
    send_non_tail(3);

    // The fifth flit is Tail. CellFull toggles immediately, but Ackout and
    // the pointer must wait until all four read-interface phases catch up.
    Tail[4] = 1'b1;
    #1;
    begin : tail_write
      reg [4:0] old_full;
      reg old_ack;
      old_full = CellFull;
      old_ack = Ackout;
      Reqin = ~Reqin;
      #3;
      check(CellFull === (old_full ^ 5'b10000), "Tail CellFull did not toggle immediately");
      check(Ackout === old_ack, "Tail acknowledged before any CellEmpty return");
      check(WritePointer === 5'b10000, "Tail advanced pointer before all reads");

      CellEmpty[0][4] = CellFull[4]; #2;
      check(Ackout === old_ack, "Tail acknowledged after only one read interface");
      CellEmpty[1][4] = CellFull[4]; #2;
      check(Ackout === old_ack, "Tail acknowledged after only two read interfaces");
      CellEmpty[2][4] = CellFull[4]; #2;
      check(Ackout === old_ack, "Tail acknowledged after only three read interfaces");
      CellEmpty[3][4] = CellFull[4]; #3;
      check(Ackout === Reqin, "Tail did not acknowledge after all four CellEmpty returns");
      check(WritePointer === 5'b00001, "Tail completion did not wrap pointer to cell zero");
      check_stable_known();
    end

    // First Head of the next packet verifies wraparound and the falling phase.
    send_non_tail(0);
    check(ack_transitions == 6, "Ackout did not transition exactly once per accepted flit");

    if (failures == 0)
      $display("TB_RESULT PASS CMR Fig7 Write Interface Control smoke");
    else
      $display("TB_RESULT FAIL CMR Fig7 Write Interface Control failures=%0d", failures);
    $finish;
  end
endmodule

`timescale 1ns/1ps

module tb_cmr_buffer_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg [27:0] Datain = 28'b0;
  reg [3:0] PathEnabled = 4'b0000;
  reg [3:0] Ackin = 4'b0000;
  wire Ackout;
  wire [3:0] Reqout;
  wire [27:0] Dataout [0:3];
  wire [4:0] WritePointer;
  wire [4:0] ReadPointer [0:3];
  wire [4:0] CellFull;
  wire [4:0] CellEmpty [0:3];
  integer failures = 0;

  CMRBuffer dut (
    .clock(clock), .reset(reset), .io_Reqin(Reqin), .io_Datain_flit(Datain),
    .io_Ackout(Ackout), .io_PathEnabled_0(PathEnabled[0]),
    .io_PathEnabled_1(PathEnabled[1]), .io_PathEnabled_2(PathEnabled[2]),
    .io_PathEnabled_3(PathEnabled[3]), .io_Ackin_0(Ackin[0]),
    .io_Ackin_1(Ackin[1]), .io_Ackin_2(Ackin[2]), .io_Ackin_3(Ackin[3]),
    .io_Reqout_0(Reqout[0]), .io_Reqout_1(Reqout[1]),
    .io_Reqout_2(Reqout[2]), .io_Reqout_3(Reqout[3]),
    .io_Dataout_0_flit(Dataout[0]), .io_Dataout_1_flit(Dataout[1]),
    .io_Dataout_2_flit(Dataout[2]), .io_Dataout_3_flit(Dataout[3])
  );

  assign WritePointer = {dut.io_WritePointer_4, dut.io_WritePointer_3,
                         dut.io_WritePointer_2, dut.io_WritePointer_1,
                         dut.io_WritePointer_0};
  assign CellFull = {dut.io_CellFull_4, dut.io_CellFull_3, dut.io_CellFull_2,
                     dut.io_CellFull_1, dut.io_CellFull_0};
  assign ReadPointer[0] = {dut.io_ReadPointer_0_4, dut.io_ReadPointer_0_3,
                           dut.io_ReadPointer_0_2, dut.io_ReadPointer_0_1,
                           dut.io_ReadPointer_0_0};
  assign ReadPointer[1] = {dut.io_ReadPointer_1_4, dut.io_ReadPointer_1_3,
                           dut.io_ReadPointer_1_2, dut.io_ReadPointer_1_1,
                           dut.io_ReadPointer_1_0};
  assign ReadPointer[2] = {dut.io_ReadPointer_2_4, dut.io_ReadPointer_2_3,
                           dut.io_ReadPointer_2_2, dut.io_ReadPointer_2_1,
                           dut.io_ReadPointer_2_0};
  assign ReadPointer[3] = {dut.io_ReadPointer_3_4, dut.io_ReadPointer_3_3,
                           dut.io_ReadPointer_3_2, dut.io_ReadPointer_3_1,
                           dut.io_ReadPointer_3_0};
  assign CellEmpty[0] = {dut.io_CellEmpty_0_4, dut.io_CellEmpty_0_3,
                         dut.io_CellEmpty_0_2, dut.io_CellEmpty_0_1,
                         dut.io_CellEmpty_0_0};
  assign CellEmpty[1] = {dut.io_CellEmpty_1_4, dut.io_CellEmpty_1_3,
                         dut.io_CellEmpty_1_2, dut.io_CellEmpty_1_1,
                         dut.io_CellEmpty_1_0};
  assign CellEmpty[2] = {dut.io_CellEmpty_2_4, dut.io_CellEmpty_2_3,
                         dut.io_CellEmpty_2_2, dut.io_CellEmpty_2_1,
                         dut.io_CellEmpty_2_0};
  assign CellEmpty[3] = {dut.io_CellEmpty_3_4, dut.io_CellEmpty_3_3,
                         dut.io_CellEmpty_3_2, dut.io_CellEmpty_3_1,
                         dut.io_CellEmpty_3_0};

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b outreq=%b ackin=%b wp=%b rp=%b,%b,%b,%b",
               message, $time, Reqin, Ackout, Reqout, Ackin, WritePointer,
               ReadPointer[0], ReadPointer[1], ReadPointer[2], ReadPointer[3]);
    end
  endtask

  task automatic check_known_onehot;
    check(!$isunknown({Ackout, Reqout, WritePointer, ReadPointer[0],
                       ReadPointer[1], ReadPointer[2], ReadPointer[3],
                       CellFull, CellEmpty[0], CellEmpty[1],
                       CellEmpty[2], CellEmpty[3]}), "stable control contains X/Z");
    check($onehot(WritePointer), "WritePointer is not one-hot");
    check($onehot(ReadPointer[0]) && $onehot(ReadPointer[1]) &&
          $onehot(ReadPointer[2]) && $onehot(ReadPointer[3]),
          "one or more ReadPointers are not one-hot");
  endtask

  task automatic downstream_ack(input integer branch_index);
    begin
      check(Reqout[branch_index] !== Ackin[branch_index], "downstream_ack called without pending request");
      Ackin[branch_index] = Reqout[branch_index];
      #4;
    end
  endtask

  localparam [27:0] HEAD = 28'h8000121;
  localparam [27:0] BODY = 28'h0000122;
  localparam [27:0] TAIL = 28'h4000123;

  initial begin
    #4;
    reset = 1'b0;
    PathEnabled = 4'b0101; // branches 0 and 2 correct; 1 and 3 speculative.
    #4;
    check(WritePointer === 5'b00001, "write pointer reset mismatch");
    check(ReadPointer[0] === 5'b00001 && ReadPointer[1] === 5'b00001 &&
          ReadPointer[2] === 5'b00001 && ReadPointer[3] === 5'b00001,
          "read pointers do not cold-start at cell zero");
    check(CellFull === 5'b01010, "CellFull reset phase mismatch");
    check(CellEmpty[0] === 5'b01010 && CellEmpty[1] === 5'b01010 &&
          CellEmpty[2] === 5'b01010 && CellEmpty[3] === 5'b01010,
          "CellEmpty reset phase mismatch");
    check_known_onehot();

    // Head is accepted by the writer immediately. Wrong branches cancel and
    // advance, while correct branches remain independently backpressured.
    Datain = HEAD; #2; Reqin = ~Reqin; #5;
    check(Ackout === Reqin, "Head was not acknowledged by write interface");
    check(Reqout[0] !== Ackin[0] && Reqout[2] !== Ackin[2],
          "correct Head copies are not pending");
    check(Reqout[1] === Ackin[1] && Reqout[3] === Ackin[3],
          "wrong Head copies were not canceled");
    check(ReadPointer[1] === 5'b00010 && ReadPointer[3] === 5'b00010,
          "wrong-path readers did not advance after Head cancellation");
    check(Dataout[0] === HEAD && Dataout[2] === HEAD, "Head datapath selection failed");

    downstream_ack(0);
    check(ReadPointer[0] === 5'b00010, "branch zero did not advance after Head Ackin");
    check(ReadPointer[2] === 5'b00001, "stalled branch two advanced without Ackin");

    // Branch zero can consume Body while branch two still holds Head.
    Datain = BODY; #2; Reqin = ~Reqin; #5;
    check(Ackout === Reqin, "Body was not acknowledged by write interface");
    check(Reqout[0] !== Ackin[0], "leading branch did not request Body");
    check(Dataout[0] === BODY, "leading branch did not select Body data");
    check(Reqout[2] !== Ackin[2] && Dataout[2] === HEAD,
          "stalled branch did not retain Head and request phase");
    downstream_ack(0);
    check(ReadPointer[0] === 5'b00100, "leading branch did not advance to Tail slot");
    downstream_ack(2);
    check(ReadPointer[2] === 5'b00010 && Reqout[2] !== Ackin[2],
          "lagging branch did not expose already-stored Body");
    check(Dataout[2] === BODY, "lagging branch Body data selection failed");

    // Tail write must not acknowledge upstream until every read interface,
    // including the lagging correct branch, returns CellEmpty for cell two.
    Datain = TAIL; #2; Reqin = ~Reqin; #5;
    check(Ackout !== Reqin, "Tail acknowledged before all read interfaces");
    check(Reqout[0] !== Ackin[0] && Dataout[0] === TAIL,
          "leading branch did not request Tail");
    check(ReadPointer[1] === 5'b01000 && ReadPointer[3] === 5'b01000,
          "wrong branches did not self-complete Tail");
    downstream_ack(0);
    check(Ackout !== Reqin, "Tail acknowledged while branch two still lagged");
    downstream_ack(2); // Body
    check(ReadPointer[2] === 5'b00100 && Reqout[2] !== Ackin[2],
          "lagging branch did not advance from Body to stored Tail");
    check(Dataout[2] === TAIL, "lagging branch Tail data selection failed");
    check(Ackout !== Reqin, "Tail acknowledged before lagging Tail Ackin");
    downstream_ack(2); // Tail
    #4;
    check(Ackout === Reqin, "Tail did not acknowledge after all four readers completed");
    check(WritePointer === 5'b01000, "write pointer did not advance after Tail barrier");
    check(ReadPointer[0] === 5'b01000 && ReadPointer[1] === 5'b01000 &&
          ReadPointer[2] === 5'b01000 && ReadPointer[3] === 5'b01000,
          "read pointers did not reconverge after packet Tail");
    check(CellEmpty[0][2] === CellFull[2] && CellEmpty[1][2] === CellFull[2] &&
          CellEmpty[2][2] === CellFull[2] && CellEmpty[3][2] === CellFull[2],
          "Tail CellEmpty phases did not all catch CellFull");
    check_known_onehot();

    if (failures == 0)
      $display("TB_RESULT PASS CMR Fig5/7/8 complete Buffer smoke");
    else
      $display("TB_RESULT FAIL CMR complete Buffer failures=%0d", failures);
    $finish;
  end
endmodule

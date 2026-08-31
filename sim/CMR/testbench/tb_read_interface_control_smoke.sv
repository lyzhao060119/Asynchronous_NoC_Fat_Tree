`timescale 1ns/1ps

module tb_read_interface_control_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [4:0] CellFull = 5'b01010;
  reg [27:0] Datain [0:4];
  reg [3:0] PathEnabled = 4'b0000;
  reg Ackin = 1'b0;
  wire Reqout;
  wire [27:0] Dataout;
  wire [4:0] ReadPointer;
  wire [4:0] CellEmpty;
  integer failures = 0;

  ReadInterfaceControl dut (
    .clock(clock), .reset(reset),
    .io_CellFull_0(CellFull[0]), .io_CellFull_1(CellFull[1]),
    .io_CellFull_2(CellFull[2]), .io_CellFull_3(CellFull[3]),
    .io_CellFull_4(CellFull[4]), .io_Datain_0_flit(Datain[0]),
    .io_Datain_1_flit(Datain[1]), .io_Datain_2_flit(Datain[2]),
    .io_Datain_3_flit(Datain[3]), .io_Datain_4_flit(Datain[4]),
    .io_PathEnabled_0(PathEnabled[0]), .io_PathEnabled_1(PathEnabled[1]),
    .io_PathEnabled_2(PathEnabled[2]), .io_PathEnabled_3(PathEnabled[3]),
    .io_Ackin(Ackin), .io_Reqout(Reqout), .io_Dataout_flit(Dataout),
    .io_ReadPointer_0(ReadPointer[0]), .io_ReadPointer_1(ReadPointer[1]),
    .io_ReadPointer_2(ReadPointer[2]), .io_ReadPointer_3(ReadPointer[3]),
    .io_ReadPointer_4(ReadPointer[4]), .io_CellEmpty_0(CellEmpty[0]),
    .io_CellEmpty_1(CellEmpty[1]), .io_CellEmpty_2(CellEmpty[2]),
    .io_CellEmpty_3(CellEmpty[3]), .io_CellEmpty_4(CellEmpty[4])
  );

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t req=%b ack=%b path=%b rp=%b empty=%b",
               message, $time, Reqout, Ackin, PathEnabled, ReadPointer, CellEmpty);
    end
  endtask

  task automatic check_known_onehot;
    check(!$isunknown({Reqout, Dataout, ReadPointer, CellEmpty}), "stable output contains X/Z");
    check($onehot(ReadPointer), "ReadPointer is not one-hot");
  endtask

  task automatic complete_correct(input integer selected_index);
    reg [4:0] old_empty;
    begin
      PathEnabled = 4'b0001;
      old_empty = CellEmpty;
      CellFull[selected_index] = ~CellFull[selected_index];
      #3;
      check(Reqout !== Ackin, "correct-path request was not held for Ackin");
      check(ReadPointer === (5'b00001 << selected_index), "correct-path pointer advanced early");
      check(Dataout === Datain[selected_index], "Dataout does not match selected cell");
      check(CellEmpty === old_empty, "CellEmpty changed before correct-path Ackin");
      #3;
      check(Reqout !== Ackin, "backpressure did not hold Reqout");
      check(Dataout === Datain[selected_index], "backpressure did not hold Dataout");
      Ackin = Reqout;
      #3;
      check(CellEmpty === (old_empty ^ (5'b00001 << selected_index)),
            "correct-path Ackin did not toggle selected CellEmpty");
      check_known_onehot();
    end
  endtask

  initial begin
    Datain[0] = 28'h0100001;
    Datain[1] = 28'h0200002;
    Datain[2] = 28'h0300003;
    Datain[3] = 28'h0400000;
    Datain[4] = 28'h0500001;
    #4;
    reset = 1'b0;
    #3;
    check(ReadPointer === 5'b00001, "cold-start ReadPointer is not cell zero");
    check(CellEmpty === 5'b01010, "CellEmpty reset phases are not 0,1,0,1,0");
    check(Reqout === 1'b0 && Ackin === 1'b0, "reset request phases do not agree");
    check(Dataout === Datain[0], "reset Dataout does not select cell zero");
    check_known_onehot();

    // Correct path on cell 0. Cell 1 becomes full before it is selected,
    // covering the Fig. 8 "CellFull already arrived" case.
    PathEnabled = 4'b0001;
    CellFull[0] = ~CellFull[0];
    #3;
    check(Reqout !== Ackin, "cell-zero correct request missing");
    check(Dataout === Datain[0], "cell-zero data selection failed");
    CellFull[1] = ~CellFull[1];
    #2;
    check(ReadPointer === 5'b00001, "prefilled next cell advanced current pointer");
    Ackin = Reqout;
    #3;
    check(ReadPointer === 5'b00010, "AckX did not advance to prefilled cell one");
    check(Reqout !== Ackin, "prefilled cell did not request on pointer selection");
    check(Dataout === Datain[1], "prefilled cell data was not selected");
    Ackin = Reqout;
    #3;
    check(ReadPointer === 5'b00100, "cell-one Ack did not advance to cell two");
    check(CellEmpty[1] === CellFull[1], "cell-one CellEmpty did not catch CellFull");

    // With no selected path, the speculative request must remain pending.
    PathEnabled = 4'b0000;
    CellFull[2] = ~CellFull[2];
    #3;
    check(Reqout !== Ackin, "all-zero PathEnabled silently discarded request");
    check(ReadPointer === 5'b00100, "all-zero PathEnabled advanced pointer");
    #3;
    check(Reqout !== Ackin, "all-zero PathEnabled did not remain blocked");

    // Enabling another path marks local branch zero incorrect. Reqout is
    // toggled back without Ackin and the read completes internally.
    begin : wrong_path
      reg old_ackin;
      old_ackin = Ackin;
      PathEnabled = 4'b0010;
      #4;
      check(Reqout === old_ackin, "wrong-path PhaseSelector did not cancel Reqout");
      check(Ackin === old_ackin, "wrong-path completion modified external Ackin");
      check(ReadPointer === 5'b01000, "wrong-path completion did not advance pointer");
      check(CellEmpty[2] === CellFull[2], "wrong-path completion did not toggle CellEmpty");
    end

    // Complete the remaining cells and wrap to cell zero.
    complete_correct(3);
    check(ReadPointer === 5'b10000, "cell three did not advance to cell four");
    complete_correct(4);
    check(ReadPointer === 5'b00001, "cell four did not wrap to cell zero");
    complete_correct(0);
    check(ReadPointer === 5'b00010, "post-wrap cell-zero read did not advance once");
    check_known_onehot();

    if (failures == 0)
      $display("TB_RESULT PASS CMR Fig8 Read Interface Control smoke");
    else
      $display("TB_RESULT FAIL CMR Fig8 Read Interface Control failures=%0d", failures);
    $finish;
  end
endmodule

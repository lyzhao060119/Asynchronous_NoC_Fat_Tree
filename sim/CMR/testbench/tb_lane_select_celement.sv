`timescale 1ns/1ps

module tb_lane_selector;
  reg reset=1'b1, active=1'b0;
  reg [1:0] empty2=2'b11;
  reg [3:0] empty4=4'b1111;
  reg [7:0] empty8=8'b11111111;
  wire [1:0] select2;
  wire [3:0] select4;
  wire [7:0] select8;
  integer failures=0;
  reg [1:0] held2;
  reg [3:0] held4;
  reg [7:0] held8;

  LaneSelector #(.LANES(2)) dut2(
    .reset(reset), .LaneIsEmpty(empty2), .PPE(active), .LaneSelect(select2));
  LaneSelector #(.LANES(4)) dut4(
    .reset(reset), .LaneIsEmpty(empty4), .PPE(active), .LaneSelect(select4));
  LaneSelector #(.LANES(8)) dut8(
    .reset(reset), .LaneIsEmpty(empty8), .PPE(active), .LaneSelect(select8));

  task check(input bit condition, input [8*48-1:0] text);
    if (!condition) begin
      failures=failures+1;
      $display("TB_RESULT FAIL %0s t=%0t select2=%b select4=%b select8=%b",text,$time,select2,select4,select8);
    end
  endtask

  initial begin
    $dumpfile("lane_select_celement.vcd");
    $dumpvars(0,tb_lane_selector);
    #2 reset=0; #1 active=1;
    #8;
    check(select2==2'b01 || select2==2'b10,"two-lane onehot admission");
    check(select4==4'b0001 || select4==4'b0010 || select4==4'b0100 || select4==4'b1000,
          "four-lane onehot admission");
    check(select8==8'b00000001 || select8==8'b00000010 || select8==8'b00000100 ||
          select8==8'b00001000 || select8==8'b00010000 || select8==8'b00100000 ||
          select8==8'b01000000 || select8==8'b10000000,"eight-lane onehot admission");
    held2=select2; held4=select4; held8=select8;

    // An OPM winner elsewhere makes every lane non-empty. This selector's
    // selected request must remain packet-lifetime sticky.
    empty2=0; empty4=0; empty8=0; #8;
    check(select2===held2,"two-lane holds selected loser request");
    check(select4===held4,"four-lane holds selected loser request");
    check(select8===held8,"eight-lane holds selected loser request");

    active=0; #8;
    check(select2===0 && select4===0 && select8===0,"packet completion releases selection");

    // A short Empty indication must still provide a full request-hold
    // interval to the mutex.  It is intentionally shorter than the local
    // functional DelayElement interval used by this test.
    empty2=0; active=1; #2;
    empty2=2'b01; #0.05;
    empty2=0; #0.40;
    check(select2==2'b01 || select2==2'b10,
          "short Empty pulse reaches mutex through ReqHold");
    held2=select2;
    #2;
    check(select2===held2,
          "Empty withdrawal does not replace selected lane");
    active=0; #2;
    check(select2===0,"short-pulse packet completion releases selection");

    empty2=2'b10; empty4=4'b1000; empty8=8'b01000000; active=1; #8;
    check(select2===2'b10,"two-lane re-admits current empty lane");
    check(select4===4'b1000,"four-lane re-admits current empty lane");
    check(select8===8'b01000000,"eight-lane re-admits current empty lane");
    active=0; #8;
    if(failures==0) $display("TB_RESULT PASS LaneSelector");
    else $display("TB_RESULT FAIL LaneSelector failures=%0d",failures);
    $finish;
  end
endmodule

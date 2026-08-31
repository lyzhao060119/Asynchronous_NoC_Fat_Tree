`timescale 1ns/1ps

module tb_async_arbiter_transaction_controller_smoke;
  reg reset=1, fire=0;
  reg [4:0] packet_present=0, packet_active=0, all_tail_passed=0, output_tail_busy=0;
  reg [2:0] owner0=3'd5, owner1=3'd5, owner2=3'd5, owner3=3'd5, owner4=3'd5;
  reg [4:0] mask0=0, mask1=0, mask2=0, mask3=0, mask4=0;
  wire tx_valid, tx_release;
  wire [4:0] tx_winner, tx_mask0, tx_mask1, tx_mask2, tx_mask3, tx_mask4;
  integer valid_rises=0;

  AsyncArbiterTransactionController #(
      .AnchorDelayValue(1), .AnchorDelayUnitPs(250),
      .RoundCloseDelayValue(1), .RoundCloseDelayUnitPs(250),
      .MembershipDelayValue(1), .MembershipDelayUnitPs(250),
      .FinalBuilderDelayValue(1), .FinalBuilderDelayUnitPs(250),
      .ReturnDelayValue(1), .ReturnDelayUnitPs(250)
  ) dut(
    .reset(reset), .fire(fire), .packet_present(packet_present), .packet_active(packet_active),
    .all_tail_passed(all_tail_passed), .output_tail_busy(output_tail_busy),
    .owner0(owner0), .owner1(owner1), .owner2(owner2), .owner3(owner3), .owner4(owner4),
    .mask0(mask0), .mask1(mask1), .mask2(mask2), .mask3(mask3), .mask4(mask4),
    .tx_valid(tx_valid), .tx_release(tx_release), .tx_winner(tx_winner),
    .tx_mask0(tx_mask0), .tx_mask1(tx_mask1), .tx_mask2(tx_mask2), .tx_mask3(tx_mask3), .tx_mask4(tx_mask4));

  always @(posedge tx_valid) valid_rises = valid_rises + 1;
  task fail(input [8*100-1:0] why); begin
    $display("TB_RESULT FAIL TransactionController %0s txv=%b winner=%b mask0=%b rises=%0d", why, tx_valid, tx_winner, tx_mask0, valid_rises);
    $fatal(1, "TransactionController smoke failed");
  end endtask

  initial begin
    #2; reset=0; #3;
    if(tx_valid!==1'b0 || tx_winner!==5'b0 || valid_rises!=0) fail("reset release remains idle");

    packet_present[0]=1; mask0=5'b10000;
    #8;
    if(!tx_valid || tx_release || tx_winner!==5'b00001 || tx_mask0!==5'b10000 || valid_rises!=1)
      fail("single admission transaction");

    // Model the active/owner bank update coincident with the one permitted
    // commit.  A second disjoint Head is already pending; it must not enter
    // until the four-phase RETURN has completely reopened the Mutex boundary.
    packet_present[1]=1; mask1=5'b00001;
    fire=1; packet_active[0]=1; owner4=3'd0; #0.2; fire=0; #0.05;
    if(tx_valid || valid_rises!=1) fail("fire prematurely rearms transaction");

    #5;
    if(!tx_valid || tx_release || tx_winner!==5'b00010 || tx_mask1!==5'b00001 || valid_rises!=2)
      fail("second admission after RETURN");
    fire=1; packet_active[1]=1; owner0=3'd1; #0.2; fire=0; #5;
    if(tx_valid || valid_rises!=2) fail("second fire completes one transaction");
    $display("TB_RESULT PASS AsyncArbiterTransactionController smoke");
    $finish;
  end
endmodule

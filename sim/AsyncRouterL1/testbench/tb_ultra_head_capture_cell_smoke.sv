`timescale 1ns/1ps

module tb_ultra_head_capture_cell_smoke;
  reg reset=1, local_head=0, release_commit=0;
  reg [4:0] local_mask=0;
  wire packet_present;
  wire [4:0] packet_mask;

  UltraHeadCaptureCell #(.DelayValue(1), .DelayUnitPs(250)) dut(
    .reset(reset), .local_head(local_head), .local_mask(local_mask),
    .release_commit(release_commit), .packet_present(packet_present),
    .packet_mask(packet_mask));

  task fail(input [8*100-1:0] why); begin
    $display("TB_RESULT FAIL HeadCapture %0s p=%b mask=%b", why, packet_present, packet_mask);
    $fatal(1, "HeadCapture smoke failed");
  end endtask

  initial begin
    // Reset explicitly opens both latches and writes zero.  Releasing reset
    // without a Head must not manufacture packetPresent.
    reset=1; local_head=0; local_mask=0; release_commit=0; #2;
    if(packet_present!==1'b0 || packet_mask!==5'b0) fail("during reset");
    reset=0; #2;
    if(packet_present!==1'b0 || packet_mask!==5'b0) fail("after reset release");

    // Mask is already stable before the delayed Head set event.
    local_mask=5'b10110; local_head=1; #1;
    if(packet_present!==1'b1 || packet_mask!==5'b10110) fail("head capture");
    local_head=0; local_mask=5'b00001; #1;
    if(packet_present!==1'b1 || packet_mask!==5'b10110) fail("head state hold");

    // Router protocol has already withdrawn raw RS before the Tail release.
    local_mask=5'b0; release_commit=1; #1; release_commit=0; #1;
    if(packet_present!==1'b0 || packet_mask!==5'b0) fail("release clear");
    $display("TB_RESULT PASS UltraHeadCaptureCell smoke");
    $finish;
  end
endmodule

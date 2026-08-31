`timescale 1ns / 1ps

// One input's Head request storage for AtomicMulticastArbiterV2.
// P and mask are protocol-controlled transparent latches, not event-clocked
// registers.  Head control is deliberately delayed relative to mask data so
// the mask latch closes only after the complete routed set is available.
module UltraHeadCaptureCell #(
    parameter DelayValue = 1,
    parameter DelayUnitPs = 250
) (
    input  wire       reset,
    input  wire       local_head,
    input  wire [4:0] local_mask,
    input  wire       release_commit,
    output wire       packet_present,
    output wire [4:0] packet_mask
);
    wire head_set;
    wire p_en;
    wire p_d;
    wire mask_en;
    wire [4:0] mask_d;

    DelayElement #(.DelayValue(DelayValue), .DelayUnitPs(DelayUnitPs)) head_margin (
        .I(local_head), .Z(head_set)
    );

    // Protocol-controlled latch state.  Keep Q asserted after head_set falls
    // while its enable path is still returning, but never write a default one
    // merely because reset is deasserted.
    assign p_en = head_set | release_commit;
    assign p_d  = release_commit ? 1'b0 :
                  (packet_present | head_set);
    DLatchBank #(.WIDTH(1)) present_latch (
        .reset(reset), .en(p_en), .d(p_d), .q(packet_present)
    );

    // While EMPTY, mask is transparent.  Once P is set it is held through
    // admission and the complete packet lifetime.  Release explicitly opens
    // the latch and writes zero; reset follows the same protocol.
    assign mask_en = ~packet_present | release_commit;
    assign mask_d  = release_commit ? 5'b0 : local_mask;
    DLatchBank #(.WIDTH(5)) mask_latch (
        .reset(reset), .en(mask_en), .d(mask_d), .q(packet_mask)
    );
endmodule

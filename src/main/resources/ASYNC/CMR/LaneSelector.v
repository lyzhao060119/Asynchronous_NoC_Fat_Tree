`timescale 1ns / 1ps

// DFF-based packet-lifetime request. Start sets Q.  PPE falling produces a
// finite configurable ClearPulse delay, so asynchronous clear is released before the
// following packet's Start event.
module LaneRequestDFF #(
    parameter REQUEST_DELAY_UNIT_PS = 50
) (
    input  wire reset,
    input  wire PPE,
    input  wire RawLaneIsEmpty,
    output wire ReqHold
);
    wire Start;
    wire PPEDelayed;
    wire Clear;

    assign Start = PPEDelayed & RawLaneIsEmpty;
    DelayElement #(
        .DelayValue(1),
        .DelayUnitPs(REQUEST_DELAY_UNIT_PS)
    ) ClearPulseDelay (
        .I(PPE),
        .Z(PPEDelayed)
    );
    assign Clear = reset | ~PPE;

`ifdef ASIC_T28
    wire ClearN;
    assign ClearN = ~Clear;
    DFCNQD1BWP12T30P140 ReqHoldDFF (
        .D(1'b1),
        .CP(Start),
        .CDN(ClearN),
        .Q(ReqHold)
    );
`else
    reg ReqHoldState;
    assign ReqHold = ReqHoldState;

    always @(posedge Start or posedge Clear) begin
        if (Clear)
            ReqHoldState <= 1'b0;
        else
            ReqHoldState <= 1'b1;
    end
`endif
endmodule

// Packet-lifetime lane select without an SR latch.  LaneIsEmpty immediately
// clocks a DFF request hold.  Once selected, LaneSelect feeds back into the
// Mutex request and remains active until PPE falls.
module LaneSelector #(
    parameter LANES = 2,
    parameter REQUEST_DELAY_UNIT_PS = 50
) (
    input wire reset,
    input wire [LANES-1:0] LaneIsEmpty,
    input wire PPE,
    output wire [LANES-1:0] LaneSelect
);
    wire [LANES-1:0] mutex_input_requests;
    wire [LANES-1:0] ReqHold;
    genvar i;
    generate for (i = 0; i < LANES; i = i + 1) begin : select_hold
        LaneRequestDFF #(
            .REQUEST_DELAY_UNIT_PS(REQUEST_DELAY_UNIT_PS)
        ) RequestHold (
            .reset(reset),
            .PPE(PPE),
            .RawLaneIsEmpty(LaneIsEmpty[i]),
            .ReqHold(ReqHold[i])
        );

        assign mutex_input_requests[i] =
            PPE & (ReqHold[i] | LaneSelect[i]);
    end endgenerate

    CMRMutexN #(.WIDTH(LANES)) mutex_in (
        .reset(reset),
        .req(mutex_input_requests),
        .grant(LaneSelect)
    );
endmodule

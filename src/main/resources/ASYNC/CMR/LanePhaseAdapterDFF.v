`timescale 1ns / 1ps

// One independent two-phase adapter per lane. The two Toggle Q outputs are
// the only signals presented to the OPM/IPM sides.
module LanePhaseAdapterDFF #(
    parameter LANES = 2
) (
    input  wire       reset,
    input  wire [LANES-1:0] LaneSelect,
    input  wire [LANES-1:0] IPMReqOut,
    input  wire [LANES-1:0] OPMAckOut,
    // One IPM branch has one acknowledgement phase, independent of its
    // selected physical lane.
    output wire             IPMAckIn,
    output wire [LANES-1:0] OPMReqIn
);
    wire [LANES-1:0] OPMReqInFire;
    wire [LANES-1:0] IPMAckInFire;
    wire IPMAckInFireChosenRaw;
    wire IPMAckInFireChosen;
    wire AwaitAck;

    // A request becomes eligible for IPM acknowledgement only after its
    // selected OPM lane has actually entered the Req != Ack phase.  This
    // leaves LaneSelect/Mux settling outside the Ack Toggle event path.
    //
    wire selected_mismatch;
    wire source_pending;
    assign selected_mismatch = |(LaneSelect & (OPMReqIn ^ OPMAckOut));
    assign source_pending = IPMReqOut[0] ^ IPMAckIn;

    LaneAdapterAwaitLatch AwaitAckLatch (
        .reset(reset),
        .S(selected_mismatch),
        .R(~source_pending),
        .Q(AwaitAck)
    );

    Mux1H #(.InputNum(LANES)) IPMAckInMux (
        .Select(LaneSelect),
        .Inputs(IPMAckInFire),
        .Out(IPMAckInFireChosenRaw)
    );
    assign IPMAckInFireChosen = AwaitAck & IPMAckInFireChosenRaw;
    Toggle #(.RESET_VALUE(1'b0)) IPMAckIn_reg (
        .reset(reset), .En(IPMAckInFireChosen), .Q(IPMAckIn)
    );
    genvar i;
    generate for (i = 0; i < LANES; i = i + 1) begin : lane
        assign OPMReqInFire[i] = LaneSelect[i] & (IPMReqOut[i] ^ IPMAckIn);

        assign IPMAckInFire[i] = ~(OPMAckOut[i] ^ OPMReqIn[i]);

        Toggle #(.RESET_VALUE(1'b0)) OPMReqIn_reg (
            .reset(reset), .En(OPMReqInFire[i]), .Q(OPMReqIn[i])
        );
    end endgenerate
endmodule

// One state bit for the adapter feedback path.  S and R are protocol
// complementary in normal operation: S records selected-lane mismatch and
// R clears the state once the IPM request/ack phases have caught up.
module LaneAdapterAwaitLatch (
    input  wire reset,
    input  wire S,
    input  wire R,
    output wire Q
);
`ifdef ASIC_T28
    wire clear_n = ~(reset | R);
    LHCNDQD1BWP12T30P140 await_latch (
        .D(1'b1), .E(S), .CDN(clear_n), .Q(Q)
    );
`else
    reg state;
    assign Q = state;
    always @(*) begin
        if (reset | R)
            state = 1'b0;
        else if (S)
            state = 1'b1;
    end
`endif
endmodule

// One-hot mux. Idle Select (all 0) drives Out=1; otherwise Out is the
// selected Inputs bit. Select is assumed one-hot.
module Mux1H #(
    parameter InputNum = 2
) (
    input wire [InputNum-1:0] Select,
    input wire [InputNum-1:0] Inputs,
    output wire Out
);
    assign Out = ~(|(Select & ~Inputs));
endmodule

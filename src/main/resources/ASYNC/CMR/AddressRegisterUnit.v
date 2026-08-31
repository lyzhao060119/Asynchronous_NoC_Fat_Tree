`timescale 1ns / 1ps

// Fig. 6 Address Register Unit. Latch Reg stores the corrected request phase
// beside the repository's 24-bit rectangle address field.
module AddressRegisterUnit #(
    parameter ADDRESS_WIDTH = 24
) (
    input  wire                     reset,
    input  wire                     Reqin,
    input  wire                     Ackout,
    input  wire                     Head,
    input  wire                     Tail,
    input  wire [ADDRESS_WIDTH-1:0] Address_field,
    output wire                     En,
    output wire                     Req_rc,
    output wire [ADDRESS_WIDTH-1:0] dest
);
    wire Req_pc;
    wire [ADDRESS_WIDTH:0] LatchD = {Req_pc, Address_field};
    wire [ADDRESS_WIDTH:0] LatchQ;

    // Fig. 6 handshake-complete detector, kept in the consumer rather than
    // hidden behind a one-expression wrapper.

    HeadPredictor HeadPredictorBlock (
        .reset(reset),
        .complete(~(Reqin ^ Ackout)),
        .Tail(Tail),
        .En(En)
    );

    PhaseSelector PhaseSelectorBlock (
        .reset(reset),
        .Reqin(Reqin),
        .complete(Reqin ^ Ackout),
        .Head(Head),
        .Req_pc(Req_pc)
    );

    DLatchBank #(.WIDTH(ADDRESS_WIDTH + 1)) LatchReg (
        .reset(reset),
        .en(En),
        .d(LatchD),
        .q(LatchQ)
    );

    assign Req_rc = LatchQ[ADDRESS_WIDTH];
    assign dest = LatchQ[ADDRESS_WIDTH-1:0];
endmodule

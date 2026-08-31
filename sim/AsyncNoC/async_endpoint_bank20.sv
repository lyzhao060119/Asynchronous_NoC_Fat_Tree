`timescale 1ns/1ps
`default_nettype none

// Transition-style boundary endpoint bank.  Each source and sink is a real
// two-phase Mousetrap stage; only the outermost producer/consumer is driven
// by the testbench.  This module is synthesizable as an independent SDF
// partition for strict gate-level runs.
module AsyncEndpointBank20 #(
  parameter integer FLIT_W = 28,
  parameter integer NUM_PORTS = 20
) (
  input  wire                         reset,
  input  wire [NUM_PORTS-1:0]         tb_in_req,
  output wire [NUM_PORTS-1:0]         tb_in_ack,
  input  wire [NUM_PORTS*FLIT_W-1:0]  tb_in_data,
  output wire [NUM_PORTS-1:0]         noc_in_req,
  input  wire [NUM_PORTS-1:0]         noc_in_ack,
  output wire [NUM_PORTS*FLIT_W-1:0]  noc_in_data,
  input  wire [NUM_PORTS-1:0]         noc_out_req,
  output wire [NUM_PORTS-1:0]         noc_out_ack,
  input  wire [NUM_PORTS*FLIT_W-1:0]  noc_out_data,
  output wire [NUM_PORTS-1:0]         tb_out_req,
  input  wire [NUM_PORTS-1:0]         tb_out_ack,
  output wire [NUM_PORTS*FLIT_W-1:0]  tb_out_data
);
  genvar p;
  generate
    for (p = 0; p < NUM_PORTS; p = p + 1) begin : endpoints
      wire source_ack_turnaround;
      // Do not reopen the source latch until the CMR receiver has had its
      // protected WP-01 handoff interval.  ReqX/DataOut remain held by the
      // closed Mousetrap throughout this interval.
      AsyncEndpointSourceTurnaroundDelay source_turnaround_delay (
        .I(noc_in_ack[p]), .Z(source_ack_turnaround)
      );
      // Upstream acknowledgement is the source stage's captured request.
      MousetrapStage #(.WIDTH(FLIT_W)) source (
        .reset(reset), .ReqIn(tb_in_req[p]), .DataIn(tb_in_data[p*FLIT_W +: FLIT_W]),
        .ReqX(noc_in_req[p]), .AckX(source_ack_turnaround), .DataOut(noc_in_data[p*FLIT_W +: FLIT_W]), .PRSReady(1'b0)
      );
      assign tb_in_ack[p] = noc_in_req[p];

      // The sink captures router output before acknowledging it.  The
      // consumer's AckX reopens the sink for the next flit.
      MousetrapStage #(.WIDTH(FLIT_W)) sink (
        .reset(reset), .ReqIn(noc_out_req[p]), .DataIn(noc_out_data[p*FLIT_W +: FLIT_W]),
        .ReqX(tb_out_req[p]), .AckX(tb_out_ack[p]), .DataOut(tb_out_data[p*FLIT_W +: FLIT_W]), .PRSReady(1'b0)
      );
      // Preserve a protected physical delay between sink capture and NoC Ack.
      AsyncEndpointAckDelay sink_ack_delay (
        .I(tb_out_req[p]), .Z(noc_out_ack[p])
      );
    end
  endgenerate
endmodule

`default_nettype wire

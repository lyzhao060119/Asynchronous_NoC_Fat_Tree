`timescale 1ns/1ps
`default_nettype none

// Single physical signoff boundary for the asynchronous NoC16 platform.
// It deliberately owns both endpoint Mousetrap banks and the generated NoC,
// so DC emits one namespace-consistent netlist and one SDF annotation target.
module AsyncNoC16BoundaryDUT #(
  parameter integer FLIT_W = 28,
  parameter integer NUM_PORTS = 20
) (
  input  wire                         reset,
  input  wire [NUM_PORTS-1:0]         tb_in_req,
  output wire [NUM_PORTS-1:0]         tb_in_ack,
  input  wire [NUM_PORTS*FLIT_W-1:0]  tb_in_data,
  output wire [NUM_PORTS-1:0]         tb_out_req,
  input  wire [NUM_PORTS-1:0]         tb_out_ack,
  output wire [NUM_PORTS*FLIT_W-1:0]  tb_out_data
);
  wire [NUM_PORTS-1:0]        noc_in_req, noc_in_ack;
  wire [NUM_PORTS*FLIT_W-1:0] noc_in_data;
  wire [NUM_PORTS-1:0]        noc_out_req, noc_out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] noc_out_data;

  AsyncEndpointBank20 #(.FLIT_W(FLIT_W), .NUM_PORTS(NUM_PORTS)) endpoints (
    .reset(reset), .tb_in_req(tb_in_req), .tb_in_ack(tb_in_ack), .tb_in_data(tb_in_data),
    .noc_in_req(noc_in_req), .noc_in_ack(noc_in_ack), .noc_in_data(noc_in_data),
    .noc_out_req(noc_out_req), .noc_out_ack(noc_out_ack), .noc_out_data(noc_out_data),
    .tb_out_req(tb_out_req), .tb_out_ack(tb_out_ack), .tb_out_data(tb_out_data)
  );

  async_noc16_port_adapter #(.FLIT_W(FLIT_W), .NUM_PORTS(NUM_PORTS)) noc (
    .reset(reset), .in_req(noc_in_req), .in_ack(noc_in_ack), .in_data(noc_in_data),
    .out_req(noc_out_req), .out_ack(noc_out_ack), .out_data(noc_out_data)
  );
endmodule

`default_nettype wire

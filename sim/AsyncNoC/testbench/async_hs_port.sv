`default_nettype none
`timescale 1ns/1ps

// Toggle two-phase handshake sender (testbench -> router input).
module async_hs_sender #(
  parameter integer FLIT_W = 28
)(
  input  wire              clk,
  input  wire              rst,
  output reg               req,
  input  wire              ack,
  output reg  [FLIT_W-1:0] data,
  input  wire              send_pulse,
  input  wire [FLIT_W-1:0] send_data,
  output reg               busy
);
  reg pending;
  reg launched;

  always @(posedge clk) begin
    if (rst) begin
      req <= 1'b0;
      data <= {FLIT_W{1'b0}};
      pending <= 1'b0;
      launched <= 1'b0;
      busy <= 1'b0;
    end else begin
      if (send_pulse && !busy) begin
        pending <= 1'b1;
        busy <= 1'b1;
        launched <= 1'b0;
      end

      if (pending) begin
        if (!launched && (req === ack)) begin
          data <= send_data;
          req <= ~req;
          launched <= 1'b1;
        end else if (launched && (req === ack)) begin
          pending <= 1'b0;
          busy <= 1'b0;
          launched <= 1'b0;
        end
      end
    end
  end
endmodule

// Toggle two-phase handshake receiver (router output -> testbench).
module async_hs_receiver #(
  parameter integer FLIT_W = 28
)(
  input  wire              clk,
  input  wire              rst,
  input  wire              req,
  output reg               ack,
  input  wire [FLIT_W-1:0] data,
  output reg               got_pulse,
  output reg  [FLIT_W-1:0] got_data
);
  reg awaiting_empty;

  always @(posedge clk) begin
    if (rst) begin
      ack <= 1'b0;
      got_pulse <= 1'b0;
      got_data <= {FLIT_W{1'b0}};
      awaiting_empty <= 1'b0;
    end else begin
      got_pulse <= 1'b0;
      if (!awaiting_empty && (req !== ack)) begin
        got_data <= data;
        got_pulse <= 1'b1;
        ack <= ~ack;
        awaiting_empty <= 1'b1;
      end else if (awaiting_empty && (req === ack)) begin
        awaiting_empty <= 1'b0;
      end
    end
  end
endmodule

`default_nettype wire

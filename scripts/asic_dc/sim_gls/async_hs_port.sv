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
  reg [FLIT_W-1:0] pending_data;

  always @(posedge clk) begin
    if (rst) begin
      req <= 1'b0;
      data <= {FLIT_W{1'b0}};
      pending_data <= {FLIT_W{1'b0}};
      pending <= 1'b0;
      launched <= 1'b0;
      busy <= 1'b0;
    end else begin
      if (send_pulse && !busy) begin
        pending <= 1'b1;
        pending_data <= send_data;
        busy <= 1'b1;
        launched <= 1'b0;
      end

      if (pending) begin
        if (!launched && (req === ack)) begin
          data <= pending_data;
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
  parameter integer FLIT_W = 28,
  parameter integer STABLE_CYCLES = 5
)(
  input  wire              clk,
  input  wire              rst,
  input  wire              req,
  output reg               ack,
  input  wire [FLIT_W-1:0] data,
  output reg               got_pulse,
  output reg  [FLIT_W-1:0] got_data
);
  integer stable;
  reg [FLIT_W-1:0] data_seen;

  always @(posedge clk) begin
    if (rst) begin
      ack <= 1'b0;
      got_pulse <= 1'b0;
      got_data <= {FLIT_W{1'b0}};
      stable <= 0;
      data_seen <= {FLIT_W{1'bx}};
    end else begin
      got_pulse <= 1'b0;
      if (req !== ack) begin
        // Bundled-data: req may lead; require data unchanged for STABLE_CYCLES.
        if (data !== data_seen) begin
          data_seen <= data;
          stable <= 0;
        end else if (stable + 1 >= STABLE_CYCLES) begin
          got_data <= data;
          got_pulse <= 1'b1;
          ack <= req;
          stable <= 0;
        end else begin
          stable <= stable + 1;
        end
      end else begin
        stable <= 0;
        data_seen <= data;
      end
    end
  end
endmodule

`default_nettype wire

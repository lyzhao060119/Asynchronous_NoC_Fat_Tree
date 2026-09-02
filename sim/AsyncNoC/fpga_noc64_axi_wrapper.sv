`timescale 1ns/1ps
`default_nettype none

// Compact AXI4-Lite control plane for the FPGA PROP64 NoC.
//
// The PS writes five-flit traffic descriptors into the per-core TX RAM and
// starts a run.  RX data stays in the PL: the wrapper acknowledges every
// completed flit and exposes aggregate/per-port counters and last-flit
// diagnostics.  This intentionally avoids a 64-port AXI streaming datapath
// and the large distributed RX memories used by the legacy NoC16 wrapper.
module fpga_noc64_axi_wrapper #(
  parameter integer AXI_ADDR_WIDTH = 16,
  parameter integer TX_DEPTH = 16
) (
  input  wire                      s_axi_aclk,
  input  wire                      s_axi_aresetn,
  input  wire [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
  input  wire                      s_axi_awvalid,
  output wire                      s_axi_awready,
  input  wire [31:0]               s_axi_wdata,
  input  wire [3:0]                s_axi_wstrb,
  input  wire                      s_axi_wvalid,
  output wire                      s_axi_wready,
  output reg  [1:0]                s_axi_bresp,
  output reg                       s_axi_bvalid,
  input  wire                      s_axi_bready,
  input  wire [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
  input  wire                      s_axi_arvalid,
  output wire                      s_axi_arready,
  output reg  [31:0]               s_axi_rdata,
  output reg  [1:0]                s_axi_rresp,
  output reg                       s_axi_rvalid,
  input  wire                      s_axi_rready,
  output wire                      irq
);
  localparam integer NUM_CORES = 64;
  localparam integer NUM_PORTS = 66;  // 64 cores + two PROP64 top ports
  localparam integer FLIT_W = 28;
  localparam integer PORT_W = 6;
  localparam integer TX_ADDR_W = (TX_DEPTH <= 2) ? 1 : $clog2(TX_DEPTH);
  localparam [7:0] TX_DEPTH_INFO = TX_DEPTH;

  localparam [15:0] REG_CTRL          = 16'h0000;
  localparam [15:0] REG_STATUS        = 16'h0004;
  localparam [15:0] REG_TIMEOUT       = 16'h0008;
  localparam [15:0] REG_DRAIN_CYCLES  = 16'h000c;
  localparam [15:0] REG_CYCLE         = 16'h0010;
  localparam [15:0] REG_INJECTED      = 16'h0014;
  localparam [15:0] REG_DELIVERED     = 16'h0018;
  localparam [15:0] REG_TOP_OUTPUTS   = 16'h001c;
  localparam [15:0] REG_IRQ_ENABLE    = 16'h0020;
  localparam [15:0] REG_INFO          = 16'h0024;
  localparam [15:0] REG_TX_COUNT_BASE = 16'h0040;
  localparam [15:0] REG_RX_COUNT_BASE = 16'h0140;
  localparam [15:0] REG_RX_LAST_BASE  = 16'h0240;
  localparam [15:0] TX_BASE           = 16'h1000;
  localparam [15:0] TX_PORT_STRIDE    = 16'h0100;

  // A descriptor is {valid, issue_cycle[23:0], flit[27:0]}.
  reg [52:0] tx_ram [0:NUM_CORES-1][0:TX_DEPTH-1];
  reg [31:0] tx_count [0:NUM_CORES-1];
  reg [31:0] tx_cursor [0:NUM_CORES-1];
  reg [31:0] rx_count [0:NUM_CORES-1];
  reg [27:0] rx_last_flit [0:NUM_CORES-1];

  reg [NUM_PORTS-1:0] in_req;
  wire [NUM_PORTS-1:0] in_ack;
  reg [NUM_PORTS-1:0] in_pending;
  reg [NUM_PORTS*FLIT_W-1:0] in_data;
  wire [NUM_PORTS-1:0] out_req;
  reg [NUM_PORTS-1:0] out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] out_data;

  reg aw_hold, w_hold;
  reg [AXI_ADDR_WIDTH-1:0] awaddr_hold;
  reg [31:0] wdata_hold;
  reg [3:0] wstrb_hold;
  reg running, done, timeout_hit, irq_enable;
  reg [31:0] timeout_cycles, drain_cycles, cycle_count, idle_count;
  reg [31:0] injected_flits, delivered_flits, unexpected_top_outputs;
  reg start_toggle, abort_toggle, start_seen, abort_seen;

  wire start_pulse = start_toggle != start_seen;
  wire abort_pulse = abort_toggle != abort_seen;
  wire [15:0] awaddr16 = awaddr_hold[15:0];
  wire [15:0] araddr16 = s_axi_araddr[15:0];
  wire wr_fire = aw_hold && w_hold && !s_axi_bvalid;
  wire [15:0] wr_rel = awaddr16 - TX_BASE;
  wire [15:0] rd_rel = araddr16 - TX_BASE;
  wire wr_is_tx = awaddr16 >= TX_BASE;
  wire rd_is_tx = araddr16 >= TX_BASE;
  wire [PORT_W-1:0] wr_port = wr_rel[13:8];
  wire [PORT_W-1:0] rd_port = rd_rel[13:8];
  wire [TX_ADDR_W-1:0] wr_entry = wr_rel[7:3];
  wire [TX_ADDR_W-1:0] rd_entry = rd_rel[7:3];
  wire wr_hi = wr_rel[2];
  wire rd_hi = rd_rel[2];

  assign s_axi_awready = !aw_hold && !s_axi_bvalid;
  assign s_axi_wready = !w_hold && !s_axi_bvalid;
  assign s_axi_arready = !s_axi_rvalid && !wr_fire;
  assign irq = done && irq_enable;

  function [31:0] apply_wstrb;
    input [31:0] old_value;
    input [31:0] new_value;
    input [3:0] strb;
    begin
      apply_wstrb = old_value;
      if (strb[0]) apply_wstrb[7:0] = new_value[7:0];
      if (strb[1]) apply_wstrb[15:8] = new_value[15:8];
      if (strb[2]) apply_wstrb[23:16] = new_value[23:16];
      if (strb[3]) apply_wstrb[31:24] = new_value[31:24];
    end
  endfunction

  always @(posedge s_axi_aclk) begin : axi_lite
    integer p;
    reg [31:0] value;
    begin
      if (!s_axi_aresetn) begin
        aw_hold <= 1'b0; w_hold <= 1'b0; s_axi_bvalid <= 1'b0;
        s_axi_bresp <= 2'b00; s_axi_rvalid <= 1'b0; s_axi_rresp <= 2'b00;
        s_axi_rdata <= 32'd0; start_toggle <= 1'b0; abort_toggle <= 1'b0;
        irq_enable <= 1'b0; timeout_cycles <= 32'd5000000;
        drain_cycles <= 32'd128;
        for (p = 0; p < NUM_CORES; p = p + 1) tx_count[p] <= 32'd0;
      end else begin
        if (s_axi_awvalid && s_axi_awready) begin
          aw_hold <= 1'b1; awaddr_hold <= s_axi_awaddr;
        end
        if (s_axi_wvalid && s_axi_wready) begin
          w_hold <= 1'b1; wdata_hold <= s_axi_wdata; wstrb_hold <= s_axi_wstrb;
        end
        if (wr_fire) begin
          aw_hold <= 1'b0; w_hold <= 1'b0; s_axi_bvalid <= 1'b1; s_axi_bresp <= 2'b00;
          if (wr_is_tx && (wr_port < NUM_CORES) && (wr_entry < TX_DEPTH)) begin
            if (wr_hi) begin
              if (wstrb_hold[0]) tx_ram[wr_port][wr_entry][35:28] <= wdata_hold[7:0];
              if (wstrb_hold[1]) tx_ram[wr_port][wr_entry][43:36] <= wdata_hold[15:8];
              if (wstrb_hold[2]) tx_ram[wr_port][wr_entry][51:44] <= wdata_hold[23:16];
              if (wstrb_hold[3]) tx_ram[wr_port][wr_entry][52] <= wdata_hold[24];
            end else begin
              if (wstrb_hold[0]) tx_ram[wr_port][wr_entry][7:0] <= wdata_hold[7:0];
              if (wstrb_hold[1]) tx_ram[wr_port][wr_entry][15:8] <= wdata_hold[15:8];
              if (wstrb_hold[2]) tx_ram[wr_port][wr_entry][23:16] <= wdata_hold[23:16];
              if (wstrb_hold[3]) tx_ram[wr_port][wr_entry][27:24] <= wdata_hold[27:24];
            end
          end else begin
            case (awaddr16)
              REG_CTRL: begin
                if (wdata_hold[0]) start_toggle <= ~start_toggle;
                if (wdata_hold[1]) abort_toggle <= ~abort_toggle;
              end
              REG_TIMEOUT: timeout_cycles <= apply_wstrb(timeout_cycles, wdata_hold, wstrb_hold);
              REG_DRAIN_CYCLES: drain_cycles <= apply_wstrb(drain_cycles, wdata_hold, wstrb_hold);
              REG_IRQ_ENABLE: begin
                value = apply_wstrb({31'd0, irq_enable}, wdata_hold, wstrb_hold);
                irq_enable <= value[0];
              end
              default: if ((awaddr16 >= REG_TX_COUNT_BASE) &&
                            (awaddr16 < REG_TX_COUNT_BASE + NUM_CORES*4)) begin
                p = (awaddr16 - REG_TX_COUNT_BASE) >> 2;
                value = apply_wstrb(tx_count[p], wdata_hold, wstrb_hold);
                tx_count[p] <= (value > TX_DEPTH) ? TX_DEPTH : value;
              end
            endcase
          end
        end
        if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;
        if (s_axi_arvalid && s_axi_arready) begin
          s_axi_rvalid <= 1'b1; s_axi_rresp <= 2'b00; s_axi_rdata <= 32'd0;
          if (rd_is_tx && (rd_port < NUM_CORES) && (rd_entry < TX_DEPTH)) begin
            s_axi_rdata <= rd_hi ? {7'd0, tx_ram[rd_port][rd_entry][52:28]} :
                                   {4'd0, tx_ram[rd_port][rd_entry][27:0]};
          end else begin
            case (araddr16)
              REG_STATUS: s_axi_rdata <= {26'd0, irq, unexpected_top_outputs != 0,
                                           timeout_hit, done, running};
              REG_TIMEOUT: s_axi_rdata <= timeout_cycles;
              REG_DRAIN_CYCLES: s_axi_rdata <= drain_cycles;
              REG_CYCLE: s_axi_rdata <= cycle_count;
              REG_INJECTED: s_axi_rdata <= injected_flits;
              REG_DELIVERED: s_axi_rdata <= delivered_flits;
              REG_TOP_OUTPUTS: s_axi_rdata <= unexpected_top_outputs;
              REG_IRQ_ENABLE: s_axi_rdata <= {31'd0, irq_enable};
              REG_INFO: s_axi_rdata <= {8'd66, 8'd64, 8'd28, TX_DEPTH_INFO};
              default: begin
                if ((araddr16 >= REG_TX_COUNT_BASE) && (araddr16 < REG_TX_COUNT_BASE + NUM_CORES*4)) begin
                  p = (araddr16 - REG_TX_COUNT_BASE) >> 2; s_axi_rdata <= tx_count[p];
                end else if ((araddr16 >= REG_RX_COUNT_BASE) && (araddr16 < REG_RX_COUNT_BASE + NUM_CORES*4)) begin
                  p = (araddr16 - REG_RX_COUNT_BASE) >> 2; s_axi_rdata <= rx_count[p];
                end else if ((araddr16 >= REG_RX_LAST_BASE) && (araddr16 < REG_RX_LAST_BASE + NUM_CORES*4)) begin
                  p = (araddr16 - REG_RX_LAST_BASE) >> 2; s_axi_rdata <= {4'd0, rx_last_flit[p]};
                end
              end
            endcase
          end
        end
        if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
      end
    end
  end

  always @(posedge s_axi_aclk) begin : traffic_engine
    integer p;
    integer delivered_now;
    integer injected_now;
    reg all_sent;
    reg [52:0] descriptor;
    begin
      if (!s_axi_aresetn) begin
        running <= 1'b0; done <= 1'b0; timeout_hit <= 1'b0;
        cycle_count <= 0; idle_count <= 0; injected_flits <= 0; delivered_flits <= 0;
        unexpected_top_outputs <= 0; in_req <= 0; in_pending <= 0; in_data <= 0; out_ack <= 0;
        start_seen <= 0; abort_seen <= 0;
        for (p = 0; p < NUM_CORES; p = p + 1) begin
          tx_cursor[p] <= 0; rx_count[p] <= 0; rx_last_flit[p] <= 0;
        end
      end else begin
        start_seen <= start_toggle; abort_seen <= abort_toggle;
        if (abort_pulse) begin
          running <= 1'b0; done <= 1'b1; in_pending <= 0;
        end else if (start_pulse) begin
          running <= 1'b1; done <= 1'b0; timeout_hit <= 1'b0; cycle_count <= 0; idle_count <= 0;
          injected_flits <= 0; delivered_flits <= 0; unexpected_top_outputs <= 0;
          in_req <= 0; in_pending <= 0; in_data <= 0; out_ack <= 0;
          for (p = 0; p < NUM_CORES; p = p + 1) begin
            tx_cursor[p] <= 0; rx_count[p] <= 0; rx_last_flit[p] <= 0;
          end
        end else if (running) begin
          cycle_count <= cycle_count + 1'b1;
          delivered_now = 0;
          injected_now = 0;
          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            if (out_req[p] != out_ack[p]) begin
              out_ack[p] <= out_req[p];
              delivered_now = delivered_now + 1;
              if (p < NUM_CORES) begin
                rx_count[p] <= rx_count[p] + 1'b1;
                rx_last_flit[p] <= out_data[p*FLIT_W +: FLIT_W];
              end else begin
                unexpected_top_outputs <= unexpected_top_outputs + 1'b1;
              end
            end
          end
          delivered_flits <= delivered_flits + delivered_now;
          for (p = 0; p < NUM_CORES; p = p + 1) begin
            if (in_pending[p] && (in_ack[p] == in_req[p])) begin
              in_pending[p] <= 1'b0;
              tx_cursor[p] <= tx_cursor[p] + 1'b1;
              injected_now = injected_now + 1;
            end else if (!in_pending[p] && (tx_cursor[p] < tx_count[p])) begin
              descriptor = tx_ram[p][tx_cursor[p][TX_ADDR_W-1:0]];
              if (descriptor[52] && (cycle_count >= descriptor[51:28])) begin
                in_data[p*FLIT_W +: FLIT_W] <= descriptor[27:0];
                in_req[p] <= ~in_req[p];
                in_pending[p] <= 1'b1;
              end
            end
          end
          injected_flits <= injected_flits + injected_now;
          all_sent = 1'b1;
          for (p = 0; p < NUM_CORES; p = p + 1)
            if ((tx_cursor[p] < tx_count[p]) || in_pending[p]) all_sent = 1'b0;
          if (all_sent && (out_req == out_ack)) begin
            idle_count <= idle_count + 1'b1;
            if (idle_count >= drain_cycles) begin running <= 1'b0; done <= 1'b1; end
          end else idle_count <= 0;
          if (cycle_count >= timeout_cycles) begin
            running <= 1'b0; done <= 1'b1; timeout_hit <= 1'b1; in_pending <= 0;
          end
        end
      end
    end
  end

  // The adapter preserves the generated NoC's flattened port naming.
  async_noc64_port_adapter_top2 #(.FLIT_W(FLIT_W), .NUM_PORTS(NUM_PORTS)) noc (
    .reset(~s_axi_aresetn), .in_req(in_req), .in_ack(in_ack), .in_data(in_data),
    .out_req(out_req), .out_ack(out_ack), .out_data(out_data)
  );
endmodule

`default_nettype wire

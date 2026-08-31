`timescale 1ns/1ps
`default_nettype none

// FIFO-backed AsyncRouterL1 AXI-Lite wrapper.
// AXI stays clocked; the RouterL1 boundary is driven with two-phase toggle
// Req/Ack handshakes for functional pre-simulation.

`define IN_DATA(P)  in_data[(P)*FLIT_W +: FLIT_W]
`define OUT_DATA(P) out_data[(P)*FLIT_W +: FLIT_W]

`define WRITE_TX_HALF(MEM) \
  begin \
    if (wr_stage_tx_hi) begin \
      if (wr_stage_strb[0]) MEM[wr_stage_tx_idx][35:28] <= wr_stage_data[7:0]; \
      if (wr_stage_strb[1]) MEM[wr_stage_tx_idx][43:36] <= wr_stage_data[15:8]; \
      if (wr_stage_strb[2]) MEM[wr_stage_tx_idx][51:44] <= wr_stage_data[23:16]; \
      if (wr_stage_strb[3]) MEM[wr_stage_tx_idx][52] <= wr_stage_data[31]; \
    end else begin \
      if (wr_stage_strb[0]) MEM[wr_stage_tx_idx][7:0]   <= wr_stage_data[7:0]; \
      if (wr_stage_strb[1]) MEM[wr_stage_tx_idx][15:8]  <= wr_stage_data[15:8]; \
      if (wr_stage_strb[2]) MEM[wr_stage_tx_idx][23:16] <= wr_stage_data[23:16]; \
      if (wr_stage_strb[3]) MEM[wr_stage_tx_idx][27:24] <= wr_stage_data[27:24]; \
    end \
  end

`define MARK_TX_ACCEPT(MEM) \
  begin \
    MEM[tx_cursor[p][TX_ADDR_W-1:0]][51:28] <= in_accept_time[p]; \
  end

`define CAPTURE_RX(P, MEM) \
  begin \
    if (rx_count_port[P] < RX_DEPTH) begin \
      MEM[rx_count_port[P][RX_ADDR_W-1:0]] <= {1'b1, 3'd``P, out_req_time[P], `OUT_DATA(P)}; \
      rx_count_port[P] <= rx_count_port[P] + 1'b1; \
    end else begin \
      rx_overflow <= 1'b1; \
    end \
  end

module async_routerl1_axi_bram_wrapper #(
  parameter integer AXI_ADDR_WIDTH = 17,
  parameter integer AXI_DATA_WIDTH = 32,
  parameter integer TX_DEPTH       = 24,
  parameter integer RX_DEPTH       = 66
)(
  input  wire                          s_axi_aclk,
  input  wire                          s_axi_aresetn,

  input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
  input  wire                          s_axi_awvalid,
  output wire                          s_axi_awready,
  input  wire [AXI_DATA_WIDTH-1:0]     s_axi_wdata,
  input  wire [AXI_DATA_WIDTH/8-1:0]   s_axi_wstrb,
  input  wire                          s_axi_wvalid,
  output wire                          s_axi_wready,
  output reg  [1:0]                    s_axi_bresp,
  output reg                           s_axi_bvalid,
  input  wire                          s_axi_bready,

  input  wire [AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
  input  wire                          s_axi_arvalid,
  output wire                          s_axi_arready,
  output reg  [AXI_DATA_WIDTH-1:0]     s_axi_rdata,
  output reg  [1:0]                    s_axi_rresp,
  output reg                           s_axi_rvalid,
  input  wire                          s_axi_rready,

  output wire                          irq
);
  localparam integer FLIT_W = 28;
  localparam integer NUM_PORTS = 6;
  localparam integer TX_ENTRY_W = 53;
  localparam integer RX_ENTRY_W = 56;
  localparam integer TX_ADDR_W = (TX_DEPTH <= 2) ? 1 : $clog2(TX_DEPTH);
  localparam integer RX_ADDR_W = (RX_DEPTH <= 2) ? 1 : $clog2(RX_DEPTH);

  localparam integer P_CHILD0  = 0;
  localparam integer P_CHILD1  = 1;
  localparam integer P_CHILD2  = 2;
  localparam integer P_CHILD3  = 3;
  localparam integer P_PARENT0 = 4;
  localparam integer P_PARENT1 = 5;

  localparam [31:0] TX_BASE_I     = 32'h0000_1000;
  localparam [31:0] RX_BASE_I     = 32'h0001_0000;
  localparam [31:0] PORT_STRIDE_I = 32'h0000_2000;
  localparam [31:0] TX_BYTES_I    = TX_DEPTH * 8;
  localparam [31:0] RX_BYTES_I    = RX_DEPTH * 8;

  localparam [7:0] REG_CTRL           = 8'h00;
  localparam [7:0] REG_STATUS         = 8'h04;
  localparam [7:0] REG_TIMEOUT        = 8'h08;
  localparam [7:0] REG_DRAIN_CYCLES   = 8'h0C;
  localparam [7:0] REG_CYCLE          = 8'h10;
  localparam [7:0] REG_RX_COUNT       = 8'h14;
  localparam [7:0] REG_INJECTED       = 8'h18;
  localparam [7:0] REG_DELIVERED      = 8'h1C;
  localparam [7:0] REG_IRQ_ENABLE     = 8'h20;
  localparam [7:0] REG_OUT_ACK_DELAY  = 8'h24;
  localparam [7:0] REG_INFO0          = 8'h28;
  localparam [7:0] REG_INFO1          = 8'h2C;
  localparam [7:0] REG_TX_COUNT_BASE  = 8'h40;
  localparam [7:0] REG_TX_CURSOR_BASE = 8'h60;
  localparam [7:0] REG_RX_COUNT_BASE  = 8'h80;

  localparam [15:0] TX_DEPTH_INFO = TX_DEPTH;
  localparam [15:0] RX_DEPTH_INFO = RX_DEPTH;

  reg  [NUM_PORTS-1:0]        in_req;
  wire [NUM_PORTS-1:0]        in_ack;
  reg  [NUM_PORTS-1:0]        in_pending;
  reg  [NUM_PORTS*FLIT_W-1:0] in_data;

  wire [NUM_PORTS-1:0]        out_req;
  reg  [NUM_PORTS-1:0]        out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] out_data;
  reg  [23:0]                 in_accept_time [0:NUM_PORTS-1];
  reg  [23:0]                 out_req_time [0:NUM_PORTS-1];

  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo0 [0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo1 [0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo2 [0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo3 [0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo4 [0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo5 [0:TX_DEPTH-1];

  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo0 [0:RX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo1 [0:RX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo2 [0:RX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo3 [0:RX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo4 [0:RX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo5 [0:RX_DEPTH-1];

  reg aw_hold;
  reg [AXI_ADDR_WIDTH-1:0] awaddr_hold;
  reg w_hold;
  reg [AXI_DATA_WIDTH-1:0] wdata_hold;
  reg [AXI_DATA_WIDTH/8-1:0] wstrb_hold;
  reg wr_stage_valid;
  reg wr_stage_is_tx;
  reg wr_stage_is_reg;
  reg [2:0] wr_stage_tx_port;
  reg [TX_ADDR_W-1:0] wr_stage_tx_idx;
  reg wr_stage_tx_hi;
  reg [7:0] wr_stage_reg_addr;
  reg [AXI_DATA_WIDTH-1:0] wr_stage_data;
  reg [AXI_DATA_WIDTH/8-1:0] wr_stage_strb;

  reg running;
  reg done;
  reg timeout_hit;
  reg rx_overflow;
  reg tx_invalid_entry_seen;
  reg irq_enable;

  reg [31:0] cfg_timeout_cycles;
  reg [31:0] cfg_drain_cycles;
  reg [31:0] cfg_out_ack_delay_cycles;
  reg [31:0] cfg_tx_count [0:NUM_PORTS-1];

  reg [31:0] cycle_counter;
  reg [31:0] tx_cursor [0:NUM_PORTS-1];
  reg [31:0] rx_count;
  reg [31:0] rx_count_port [0:NUM_PORTS-1];
  reg [31:0] injected_flits;
  reg [31:0] delivered_flits;
  reg [31:0] idle_counter;
  reg signed [31:0] ack_countdown [0:NUM_PORTS-1];

  reg start_cmd_toggle;
  reg abort_cmd_toggle;
  reg clear_rx_cmd_toggle;
  reg clear_done_cmd_toggle;
  reg start_cmd_seen;
  reg abort_cmd_seen;
  reg clear_rx_cmd_seen;
  reg clear_done_cmd_seen;

  wire start_cmd_pulse      = (start_cmd_toggle      != start_cmd_seen);
  wire abort_cmd_pulse      = (abort_cmd_toggle      != abort_cmd_seen);
  wire clear_rx_cmd_pulse   = (clear_rx_cmd_toggle   != clear_rx_cmd_seen);
  wire clear_done_cmd_pulse = (clear_done_cmd_toggle != clear_done_cmd_seen);

  wire [31:0] awaddr32 = {{(32-AXI_ADDR_WIDTH){1'b0}}, awaddr_hold[AXI_ADDR_WIDTH-1:2], 2'b00};
  wire [31:0] araddr32 = {{(32-AXI_ADDR_WIDTH){1'b0}}, s_axi_araddr[AXI_ADDR_WIDTH-1:2], 2'b00};

  wire write_fire = aw_hold && w_hold && !wr_stage_valid && !s_axi_bvalid;
  assign s_axi_awready = ~aw_hold && !wr_stage_valid && !s_axi_bvalid;
  assign s_axi_wready  = ~w_hold && !wr_stage_valid && !s_axi_bvalid;
  assign s_axi_arready = ~s_axi_rvalid && !write_fire && !wr_stage_valid;
  assign irq = irq_enable & done;

  wire wr_is_tx = (awaddr32 >= TX_BASE_I) && (awaddr32 < (TX_BASE_I + NUM_PORTS * PORT_STRIDE_I));
  wire [31:0] wr_tx_rel = awaddr32 - TX_BASE_I;
  wire [2:0] wr_tx_port = wr_tx_rel[15:13];
  wire [31:0] wr_tx_off = wr_tx_rel & (PORT_STRIDE_I - 1);
  wire [TX_ADDR_W-1:0] wr_tx_idx = wr_tx_off[3 +: TX_ADDR_W];
  wire wr_tx_hi = wr_tx_off[2];
  wire wr_tx_ok = wr_is_tx && (wr_tx_port < NUM_PORTS) && (wr_tx_off < TX_BYTES_I);

  wire ar_is_tx = (araddr32 >= TX_BASE_I) && (araddr32 < (TX_BASE_I + NUM_PORTS * PORT_STRIDE_I));
  wire [31:0] ar_tx_rel = araddr32 - TX_BASE_I;
  wire [2:0] ar_tx_port = ar_tx_rel[15:13];
  wire [31:0] ar_tx_off = ar_tx_rel & (PORT_STRIDE_I - 1);
  wire [TX_ADDR_W-1:0] ar_tx_idx = ar_tx_off[3 +: TX_ADDR_W];
  wire ar_tx_hi = ar_tx_off[2];
  wire ar_tx_ok = ar_is_tx && (ar_tx_port < NUM_PORTS) && (ar_tx_off < TX_BYTES_I);

  wire ar_is_rx = (araddr32 >= RX_BASE_I) && (araddr32 < (RX_BASE_I + NUM_PORTS * PORT_STRIDE_I));
  wire [31:0] ar_rx_rel = araddr32 - RX_BASE_I;
  wire [2:0] ar_rx_port = ar_rx_rel[15:13];
  wire [31:0] ar_rx_off = ar_rx_rel & (PORT_STRIDE_I - 1);
  wire [RX_ADDR_W-1:0] ar_rx_idx = ar_rx_off[3 +: RX_ADDR_W];
  wire ar_rx_hi = ar_rx_off[2];
  wire ar_rx_ok = ar_is_rx && (ar_rx_port < NUM_PORTS) && (ar_rx_off < RX_BYTES_I);

  function [31:0] apply_wstrb32;
    input [31:0] old_v;
    input [31:0] new_v;
    input [3:0]  wstrb;
    begin
      apply_wstrb32 = old_v;
      if (wstrb[0]) apply_wstrb32[7:0]   = new_v[7:0];
      if (wstrb[1]) apply_wstrb32[15:8]  = new_v[15:8];
      if (wstrb[2]) apply_wstrb32[23:16] = new_v[23:16];
      if (wstrb[3]) apply_wstrb32[31:24] = new_v[31:24];
    end
  endfunction

  function [23:0] sim_time_ticks;
    real ticks;
    begin
      // 0.1 ns ticks preserve the async #0.2 ns DelayElement behavior while
      // fitting current functional cases into the existing 24-bit metadata.
      ticks = ($realtime * 10.0) + 0.5;
      sim_time_ticks = $rtoi(ticks);
    end
  endfunction

  genvar ts_port;
  generate
    for (ts_port = 0; ts_port < NUM_PORTS; ts_port = ts_port + 1) begin : timestamp_events
      always @(in_ack[ts_port]) begin
        if (running && in_pending[ts_port] && (in_ack[ts_port] == in_req[ts_port])) begin
          in_accept_time[ts_port] = sim_time_ticks();
        end
      end

      always @(out_req[ts_port]) begin
        if (running && (out_req[ts_port] != out_ack[ts_port])) begin
          out_req_time[ts_port] = sim_time_ticks();
        end
      end
    end
  endgenerate

  always @(posedge s_axi_aclk) begin : axi_slave
    integer p;
    reg [31:0] tmp32;
    reg all_done_status;
    begin
      if (!s_axi_aresetn) begin
        aw_hold <= 1'b0;
        awaddr_hold <= {AXI_ADDR_WIDTH{1'b0}};
        w_hold <= 1'b0;
        wdata_hold <= {AXI_DATA_WIDTH{1'b0}};
        wstrb_hold <= {(AXI_DATA_WIDTH/8){1'b0}};
        wr_stage_valid <= 1'b0;
        wr_stage_is_tx <= 1'b0;
        wr_stage_is_reg <= 1'b0;
        wr_stage_tx_port <= 3'd0;
        wr_stage_tx_idx <= {TX_ADDR_W{1'b0}};
        wr_stage_tx_hi <= 1'b0;
        wr_stage_reg_addr <= 8'd0;
        wr_stage_data <= {AXI_DATA_WIDTH{1'b0}};
        wr_stage_strb <= {(AXI_DATA_WIDTH/8){1'b0}};
        s_axi_bvalid <= 1'b0;
        s_axi_bresp <= 2'b00;
        s_axi_rvalid <= 1'b0;
        s_axi_rresp <= 2'b00;
        s_axi_rdata <= {AXI_DATA_WIDTH{1'b0}};

        start_cmd_toggle <= 1'b0;
        abort_cmd_toggle <= 1'b0;
        clear_rx_cmd_toggle <= 1'b0;
        clear_done_cmd_toggle <= 1'b0;
        irq_enable <= 1'b0;
        cfg_timeout_cycles <= 32'd200000;
        cfg_drain_cycles <= 32'd256;
        cfg_out_ack_delay_cycles <= 32'd0;
        for (p = 0; p < NUM_PORTS; p = p + 1) cfg_tx_count[p] <= 32'd0;
      end else begin
        if (!aw_hold && s_axi_awvalid) begin
          aw_hold <= 1'b1;
          awaddr_hold <= s_axi_awaddr;
        end

        if (!w_hold && s_axi_wvalid) begin
          w_hold <= 1'b1;
          wdata_hold <= s_axi_wdata;
          wstrb_hold <= s_axi_wstrb;
        end

        if (write_fire) begin
          wr_stage_valid <= 1'b1;
          wr_stage_is_tx <= wr_tx_ok;
          wr_stage_is_reg <= (awaddr32 < TX_BASE_I);
          wr_stage_tx_port <= wr_tx_port;
          wr_stage_tx_idx <= wr_tx_idx;
          wr_stage_tx_hi <= wr_tx_hi;
          wr_stage_reg_addr <= awaddr32[7:0];
          wr_stage_data <= wdata_hold;
          wr_stage_strb <= wstrb_hold;
          aw_hold <= 1'b0;
          w_hold <= 1'b0;
        end

        if (wr_stage_valid) begin
          s_axi_bvalid <= 1'b1;
          s_axi_bresp <= 2'b00;

          if (wr_stage_is_tx) begin
            case (wr_stage_tx_port)
              3'd0: `WRITE_TX_HALF(tx_fifo0)
              3'd1: `WRITE_TX_HALF(tx_fifo1)
              3'd2: `WRITE_TX_HALF(tx_fifo2)
              3'd3: `WRITE_TX_HALF(tx_fifo3)
              3'd4: `WRITE_TX_HALF(tx_fifo4)
              3'd5: `WRITE_TX_HALF(tx_fifo5)
              default: begin end
            endcase
          end else if (wr_stage_is_reg) begin
            case (wr_stage_reg_addr)
              REG_CTRL: begin
                if (wr_stage_data[0]) start_cmd_toggle <= ~start_cmd_toggle;
                if (wr_stage_data[1]) abort_cmd_toggle <= ~abort_cmd_toggle;
                if (wr_stage_data[2]) clear_rx_cmd_toggle <= ~clear_rx_cmd_toggle;
                if (wr_stage_data[3]) clear_done_cmd_toggle <= ~clear_done_cmd_toggle;
              end
              REG_TIMEOUT: cfg_timeout_cycles <= apply_wstrb32(cfg_timeout_cycles, wr_stage_data, wr_stage_strb);
              REG_DRAIN_CYCLES: cfg_drain_cycles <= apply_wstrb32(cfg_drain_cycles, wr_stage_data, wr_stage_strb);
              REG_IRQ_ENABLE: begin
                tmp32 = apply_wstrb32({31'd0, irq_enable}, wr_stage_data, wr_stage_strb);
                irq_enable <= tmp32[0];
              end
              REG_OUT_ACK_DELAY: cfg_out_ack_delay_cycles <= apply_wstrb32(cfg_out_ack_delay_cycles, wr_stage_data, wr_stage_strb);
              default: begin
                if ((wr_stage_reg_addr >= REG_TX_COUNT_BASE) &&
                    (wr_stage_reg_addr < (REG_TX_COUNT_BASE + NUM_PORTS*4))) begin
                  p = (wr_stage_reg_addr - REG_TX_COUNT_BASE) >> 2;
                  tmp32 = apply_wstrb32(cfg_tx_count[p], wr_stage_data, wr_stage_strb);
                  cfg_tx_count[p] <= (tmp32 > TX_DEPTH) ? TX_DEPTH : tmp32;
                end
              end
            endcase
          end

          wr_stage_valid <= 1'b0;
        end

        if (s_axi_bvalid && s_axi_bready) s_axi_bvalid <= 1'b0;

        if (s_axi_rvalid && s_axi_rready) begin
          s_axi_rvalid <= 1'b0;
        end

        if (s_axi_arvalid && s_axi_arready) begin
          s_axi_rvalid <= 1'b1;
          s_axi_rresp <= 2'b00;
          s_axi_rdata <= 32'd0;

          if (ar_tx_ok) begin
            case (ar_tx_port)
              3'd0: s_axi_rdata <= ar_tx_hi ? {tx_fifo0[ar_tx_idx][52], 7'd0, tx_fifo0[ar_tx_idx][51:28]} : {4'd0, tx_fifo0[ar_tx_idx][27:0]};
              3'd1: s_axi_rdata <= ar_tx_hi ? {tx_fifo1[ar_tx_idx][52], 7'd0, tx_fifo1[ar_tx_idx][51:28]} : {4'd0, tx_fifo1[ar_tx_idx][27:0]};
              3'd2: s_axi_rdata <= ar_tx_hi ? {tx_fifo2[ar_tx_idx][52], 7'd0, tx_fifo2[ar_tx_idx][51:28]} : {4'd0, tx_fifo2[ar_tx_idx][27:0]};
              3'd3: s_axi_rdata <= ar_tx_hi ? {tx_fifo3[ar_tx_idx][52], 7'd0, tx_fifo3[ar_tx_idx][51:28]} : {4'd0, tx_fifo3[ar_tx_idx][27:0]};
              3'd4: s_axi_rdata <= ar_tx_hi ? {tx_fifo4[ar_tx_idx][52], 7'd0, tx_fifo4[ar_tx_idx][51:28]} : {4'd0, tx_fifo4[ar_tx_idx][27:0]};
              3'd5: s_axi_rdata <= ar_tx_hi ? {tx_fifo5[ar_tx_idx][52], 7'd0, tx_fifo5[ar_tx_idx][51:28]} : {4'd0, tx_fifo5[ar_tx_idx][27:0]};
              default: s_axi_rdata <= 32'd0;
            endcase
          end else if (ar_rx_ok) begin
            case (ar_rx_port)
              3'd0: s_axi_rdata <= ar_rx_hi ? {rx_fifo0[ar_rx_idx][55], 4'd0, rx_fifo0[ar_rx_idx][54:52], rx_fifo0[ar_rx_idx][51:28]} : {4'd0, rx_fifo0[ar_rx_idx][27:0]};
              3'd1: s_axi_rdata <= ar_rx_hi ? {rx_fifo1[ar_rx_idx][55], 4'd0, rx_fifo1[ar_rx_idx][54:52], rx_fifo1[ar_rx_idx][51:28]} : {4'd0, rx_fifo1[ar_rx_idx][27:0]};
              3'd2: s_axi_rdata <= ar_rx_hi ? {rx_fifo2[ar_rx_idx][55], 4'd0, rx_fifo2[ar_rx_idx][54:52], rx_fifo2[ar_rx_idx][51:28]} : {4'd0, rx_fifo2[ar_rx_idx][27:0]};
              3'd3: s_axi_rdata <= ar_rx_hi ? {rx_fifo3[ar_rx_idx][55], 4'd0, rx_fifo3[ar_rx_idx][54:52], rx_fifo3[ar_rx_idx][51:28]} : {4'd0, rx_fifo3[ar_rx_idx][27:0]};
              3'd4: s_axi_rdata <= ar_rx_hi ? {rx_fifo4[ar_rx_idx][55], 4'd0, rx_fifo4[ar_rx_idx][54:52], rx_fifo4[ar_rx_idx][51:28]} : {4'd0, rx_fifo4[ar_rx_idx][27:0]};
              3'd5: s_axi_rdata <= ar_rx_hi ? {rx_fifo5[ar_rx_idx][55], 4'd0, rx_fifo5[ar_rx_idx][54:52], rx_fifo5[ar_rx_idx][51:28]} : {4'd0, rx_fifo5[ar_rx_idx][27:0]};
              default: s_axi_rdata <= 32'd0;
            endcase
          end else if (araddr32 < TX_BASE_I) begin
            all_done_status = 1'b1;
            for (p = 0; p < NUM_PORTS; p = p + 1) begin
              if ((tx_cursor[p] < cfg_tx_count[p]) || in_pending[p]) all_done_status = 1'b0;
            end

            case (araddr32[7:0])
              REG_STATUS: begin
                s_axi_rdata <= {
                  24'd0,
                  (done & irq_enable),
                  1'b0,
                  all_done_status,
                  tx_invalid_entry_seen,
                  rx_overflow,
                  timeout_hit,
                  done,
                  running
                };
              end
              REG_TIMEOUT: s_axi_rdata <= cfg_timeout_cycles;
              REG_DRAIN_CYCLES: s_axi_rdata <= cfg_drain_cycles;
              REG_CYCLE: s_axi_rdata <= cycle_counter;
              REG_RX_COUNT: s_axi_rdata <= rx_count;
              REG_INJECTED: s_axi_rdata <= injected_flits;
              REG_DELIVERED: s_axi_rdata <= delivered_flits;
              REG_IRQ_ENABLE: s_axi_rdata <= {31'd0, irq_enable};
              REG_OUT_ACK_DELAY: s_axi_rdata <= cfg_out_ack_delay_cycles;
              REG_INFO0: s_axi_rdata <= {16'd0, 8'd6, 8'd28};
              REG_INFO1: s_axi_rdata <= {RX_DEPTH_INFO, TX_DEPTH_INFO};
              default: begin
                if ((araddr32[7:0] >= REG_TX_COUNT_BASE) &&
                    (araddr32[7:0] < (REG_TX_COUNT_BASE + NUM_PORTS*4))) begin
                  p = (araddr32[7:0] - REG_TX_COUNT_BASE) >> 2;
                  s_axi_rdata <= cfg_tx_count[p];
                end else if ((araddr32[7:0] >= REG_TX_CURSOR_BASE) &&
                             (araddr32[7:0] < (REG_TX_CURSOR_BASE + NUM_PORTS*4))) begin
                  p = (araddr32[7:0] - REG_TX_CURSOR_BASE) >> 2;
                  s_axi_rdata <= tx_cursor[p];
                end else if ((araddr32[7:0] >= REG_RX_COUNT_BASE) &&
                             (araddr32[7:0] < (REG_RX_COUNT_BASE + NUM_PORTS*4))) begin
                  p = (araddr32[7:0] - REG_RX_COUNT_BASE) >> 2;
                  s_axi_rdata <= rx_count_port[p];
                end
              end
            endcase
          end
        end
      end
    end
  end

  always @(posedge s_axi_aclk) begin : router_driver
    integer p;
    integer delivered_inc;
    reg [TX_ENTRY_W-1:0] entry;
    reg [23:0] entry_cycle;
    reg tx_all_done;
    reg output_pending;
    begin
      if (!s_axi_aresetn) begin
        running <= 1'b0;
        done <= 1'b0;
        timeout_hit <= 1'b0;
        rx_overflow <= 1'b0;
        tx_invalid_entry_seen <= 1'b0;
        cycle_counter <= 32'd0;
        rx_count <= 32'd0;
        injected_flits <= 32'd0;
        delivered_flits <= 32'd0;
        idle_counter <= 32'd0;
        in_req <= {NUM_PORTS{1'b0}};
        in_pending <= {NUM_PORTS{1'b0}};
        in_data <= {(NUM_PORTS*FLIT_W){1'b0}};
        out_ack <= {NUM_PORTS{1'b0}};
        start_cmd_seen <= 1'b0;
        abort_cmd_seen <= 1'b0;
        clear_rx_cmd_seen <= 1'b0;
        clear_done_cmd_seen <= 1'b0;
        for (p = 0; p < NUM_PORTS; p = p + 1) begin
          tx_cursor[p] <= 32'd0;
          rx_count_port[p] <= 32'd0;
          ack_countdown[p] <= -1;
          in_accept_time[p] <= 24'd0;
          out_req_time[p] <= 24'd0;
        end
      end else begin
        start_cmd_seen <= start_cmd_toggle;
        abort_cmd_seen <= abort_cmd_toggle;
        clear_rx_cmd_seen <= clear_rx_cmd_toggle;
        clear_done_cmd_seen <= clear_done_cmd_toggle;

        if (clear_rx_cmd_pulse) begin
          rx_count <= 32'd0;
          delivered_flits <= 32'd0;
          rx_overflow <= 1'b0;
          for (p = 0; p < NUM_PORTS; p = p + 1) rx_count_port[p] <= 32'd0;
        end

        if (clear_done_cmd_pulse) begin
          done <= 1'b0;
          timeout_hit <= 1'b0;
        end

        if (abort_cmd_pulse) begin
          running <= 1'b0;
          in_req <= {NUM_PORTS{1'b0}};
          in_pending <= {NUM_PORTS{1'b0}};
          for (p = 0; p < NUM_PORTS; p = p + 1) ack_countdown[p] <= -1;
        end

        if (start_cmd_pulse) begin
          running <= 1'b1;
          done <= 1'b0;
          timeout_hit <= 1'b0;
          rx_overflow <= 1'b0;
          tx_invalid_entry_seen <= 1'b0;
          cycle_counter <= 32'd0;
          rx_count <= 32'd0;
          injected_flits <= 32'd0;
          delivered_flits <= 32'd0;
          idle_counter <= 32'd0;
          in_req <= {NUM_PORTS{1'b0}};
          in_pending <= {NUM_PORTS{1'b0}};
          out_ack <= {NUM_PORTS{1'b0}};
          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            tx_cursor[p] <= 32'd0;
            rx_count_port[p] <= 32'd0;
            ack_countdown[p] <= -1;
            in_accept_time[p] <= 24'd0;
            out_req_time[p] <= 24'd0;
          end
        end else if (running) begin
          cycle_counter <= cycle_counter + 1'b1;

          delivered_inc = 0;
          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            output_pending = out_req[p] ^ out_ack[p];
            if (output_pending) begin
              if (cfg_out_ack_delay_cycles == 0) begin
                case (p)
                  0: begin `CAPTURE_RX(0, rx_fifo0) end
                  1: begin `CAPTURE_RX(1, rx_fifo1) end
                  2: begin `CAPTURE_RX(2, rx_fifo2) end
                  3: begin `CAPTURE_RX(3, rx_fifo3) end
                  4: begin `CAPTURE_RX(4, rx_fifo4) end
                  5: begin `CAPTURE_RX(5, rx_fifo5) end
                  default: begin end
                endcase
                delivered_inc = delivered_inc + 1;
                out_ack[p] <= out_req[p];
                ack_countdown[p] <= -1;
              end else if (ack_countdown[p] < 0) begin
                ack_countdown[p] <= cfg_out_ack_delay_cycles - 1;
              end else if (ack_countdown[p] == 0) begin
                case (p)
                  0: begin `CAPTURE_RX(0, rx_fifo0) end
                  1: begin `CAPTURE_RX(1, rx_fifo1) end
                  2: begin `CAPTURE_RX(2, rx_fifo2) end
                  3: begin `CAPTURE_RX(3, rx_fifo3) end
                  4: begin `CAPTURE_RX(4, rx_fifo4) end
                  5: begin `CAPTURE_RX(5, rx_fifo5) end
                  default: begin end
                endcase
                delivered_inc = delivered_inc + 1;
                out_ack[p] <= out_req[p];
                ack_countdown[p] <= -1;
              end else begin
                ack_countdown[p] <= ack_countdown[p] - 1;
              end
            end else begin
              ack_countdown[p] <= -1;
            end
          end
          rx_count <= rx_count + delivered_inc;
          delivered_flits <= delivered_flits + delivered_inc;

          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            if (in_pending[p]) begin
              if (in_ack[p] == in_req[p]) begin
                case (p)
                  0: `MARK_TX_ACCEPT(tx_fifo0)
                  1: `MARK_TX_ACCEPT(tx_fifo1)
                  2: `MARK_TX_ACCEPT(tx_fifo2)
                  3: `MARK_TX_ACCEPT(tx_fifo3)
                  4: `MARK_TX_ACCEPT(tx_fifo4)
                  5: `MARK_TX_ACCEPT(tx_fifo5)
                  default: begin end
                endcase
                tx_cursor[p] <= tx_cursor[p] + 1'b1;
                in_pending[p] <= 1'b0;
              end
            end else begin
              if ((tx_cursor[p] < cfg_tx_count[p]) && (tx_cursor[p] < TX_DEPTH)) begin
                case (p)
                  0: entry = tx_fifo0[tx_cursor[p][TX_ADDR_W-1:0]];
                  1: entry = tx_fifo1[tx_cursor[p][TX_ADDR_W-1:0]];
                  2: entry = tx_fifo2[tx_cursor[p][TX_ADDR_W-1:0]];
                  3: entry = tx_fifo3[tx_cursor[p][TX_ADDR_W-1:0]];
                  4: entry = tx_fifo4[tx_cursor[p][TX_ADDR_W-1:0]];
                  5: entry = tx_fifo5[tx_cursor[p][TX_ADDR_W-1:0]];
                  default: entry = {TX_ENTRY_W{1'b0}};
                endcase
                entry_cycle = entry[51:28];

                if (!entry[52]) begin
                  tx_invalid_entry_seen <= 1'b1;
                  tx_cursor[p] <= tx_cursor[p] + 1'b1;
                end else if (cycle_counter >= {8'd0, entry_cycle}) begin
                  `IN_DATA(p) <= entry[27:0];
                  in_req[p] <= ~in_req[p];
                  in_pending[p] <= 1'b1;
                end
              end
            end
          end
          injected_flits <= tx_cursor[0] + tx_cursor[1] + tx_cursor[2] +
                            tx_cursor[3] + tx_cursor[4] + tx_cursor[5];

          tx_all_done = 1'b1;
          for (p = 0; p < NUM_PORTS; p = p + 1) begin
            if ((tx_cursor[p] < cfg_tx_count[p]) || in_pending[p]) tx_all_done = 1'b0;
          end

          if (tx_all_done && (out_req == out_ack)) begin
            idle_counter <= idle_counter + 1'b1;
            if (idle_counter >= cfg_drain_cycles) begin
              running <= 1'b0;
              done <= 1'b1;
              in_pending <= {NUM_PORTS{1'b0}};
            end
          end else begin
            idle_counter <= 32'd0;
          end

          if (cycle_counter >= cfg_timeout_cycles) begin
            running <= 1'b0;
            done <= 1'b1;
            timeout_hit <= 1'b1;
            in_pending <= {NUM_PORTS{1'b0}};
          end
        end
      end
    end
  end

  RouterL1 dut (
    .clock                          (s_axi_aclk),
    .reset                          (~s_axi_aresetn),

    .io_inputs_child_0_0_HS_Req     (in_req[P_CHILD0]),
    .io_inputs_child_0_0_HS_Ack     (in_ack[P_CHILD0]),
    .io_inputs_child_0_0_Data_flit  (`IN_DATA(P_CHILD0)),
    .io_inputs_child_1_0_HS_Req     (in_req[P_CHILD1]),
    .io_inputs_child_1_0_HS_Ack     (in_ack[P_CHILD1]),
    .io_inputs_child_1_0_Data_flit  (`IN_DATA(P_CHILD1)),
    .io_inputs_child_2_0_HS_Req     (in_req[P_CHILD2]),
    .io_inputs_child_2_0_HS_Ack     (in_ack[P_CHILD2]),
    .io_inputs_child_2_0_Data_flit  (`IN_DATA(P_CHILD2)),
    .io_inputs_child_3_0_HS_Req     (in_req[P_CHILD3]),
    .io_inputs_child_3_0_HS_Ack     (in_ack[P_CHILD3]),
    .io_inputs_child_3_0_Data_flit  (`IN_DATA(P_CHILD3)),
    .io_inputs_parent_0_HS_Req      (in_req[P_PARENT0]),
    .io_inputs_parent_0_HS_Ack      (in_ack[P_PARENT0]),
    .io_inputs_parent_0_Data_flit   (`IN_DATA(P_PARENT0)),
    .io_inputs_parent_1_HS_Req      (in_req[P_PARENT1]),
    .io_inputs_parent_1_HS_Ack      (in_ack[P_PARENT1]),
    .io_inputs_parent_1_Data_flit   (`IN_DATA(P_PARENT1)),

    .io_outputs_child_0_0_HS_Req    (out_req[P_CHILD0]),
    .io_outputs_child_0_0_HS_Ack    (out_ack[P_CHILD0]),
    .io_outputs_child_0_0_Data_flit (`OUT_DATA(P_CHILD0)),
    .io_outputs_child_1_0_HS_Req    (out_req[P_CHILD1]),
    .io_outputs_child_1_0_HS_Ack    (out_ack[P_CHILD1]),
    .io_outputs_child_1_0_Data_flit (`OUT_DATA(P_CHILD1)),
    .io_outputs_child_2_0_HS_Req    (out_req[P_CHILD2]),
    .io_outputs_child_2_0_HS_Ack    (out_ack[P_CHILD2]),
    .io_outputs_child_2_0_Data_flit (`OUT_DATA(P_CHILD2)),
    .io_outputs_child_3_0_HS_Req    (out_req[P_CHILD3]),
    .io_outputs_child_3_0_HS_Ack    (out_ack[P_CHILD3]),
    .io_outputs_child_3_0_Data_flit (`OUT_DATA(P_CHILD3)),
    .io_outputs_parent_0_HS_Req     (out_req[P_PARENT0]),
    .io_outputs_parent_0_HS_Ack     (out_ack[P_PARENT0]),
    .io_outputs_parent_0_Data_flit  (`OUT_DATA(P_PARENT0)),
    .io_outputs_parent_1_HS_Req     (out_req[P_PARENT1]),
    .io_outputs_parent_1_HS_Ack     (out_ack[P_PARENT1]),
    .io_outputs_parent_1_Data_flit  (`OUT_DATA(P_PARENT1))
  );
endmodule

`undef CAPTURE_RX
`undef MARK_TX_ACCEPT
`undef WRITE_TX_HALF
`undef IN_DATA
`undef OUT_DATA
`default_nettype wire

`timescale 1ns/1ps
`default_nettype none

module async_noc16_axi_bram_wrapper #(
  parameter integer AXI_ADDR_WIDTH = 20,
  parameter integer AXI_DATA_WIDTH = 32,
  parameter integer TX_DEPTH       = 1024,
  parameter integer RX_DEPTH       = 1024
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
  localparam integer NUM_PORTS = 20;
  localparam integer PORT_W = 5;
  localparam integer TX_ENTRY_W = 53;
  localparam integer RX_ENTRY_W = 58;
  localparam integer TX_ADDR_W = (TX_DEPTH <= 2) ? 1 : $clog2(TX_DEPTH);
  localparam integer RX_ADDR_W = (RX_DEPTH <= 2) ? 1 : $clog2(RX_DEPTH);
  localparam [15:0] TX_DEPTH_INFO = TX_DEPTH;
  localparam [15:0] RX_DEPTH_INFO = RX_DEPTH;

  localparam [31:0] TX_BASE_I     = 32'h0000_1000;
  localparam [31:0] RX_BASE_I     = 32'h0004_0000;
  localparam [31:0] PORT_STRIDE_I = 32'h0000_2000;
  localparam [31:0] TX_BYTES_I    = TX_DEPTH * 8;
  localparam [31:0] RX_BYTES_I    = RX_DEPTH * 8;

  localparam [31:0] REG_CTRL           = 32'h0000_0000;
  localparam [31:0] REG_STATUS         = 32'h0000_0004;
  localparam [31:0] REG_TIMEOUT        = 32'h0000_0008;
  localparam [31:0] REG_DRAIN_CYCLES   = 32'h0000_000C;
  localparam [31:0] REG_CYCLE          = 32'h0000_0010;
  localparam [31:0] REG_RX_COUNT       = 32'h0000_0014;
  localparam [31:0] REG_INJECTED       = 32'h0000_0018;
  localparam [31:0] REG_DELIVERED      = 32'h0000_001C;
  localparam [31:0] REG_IRQ_ENABLE     = 32'h0000_0020;
  localparam [31:0] REG_OUT_ACK_DELAY  = 32'h0000_0024;
  localparam [31:0] REG_INFO0          = 32'h0000_0028;
  localparam [31:0] REG_INFO1          = 32'h0000_002C;
  localparam [31:0] REG_TX_COUNT_BASE  = 32'h0000_0040;
  localparam [31:0] REG_RX_COUNT_BASE  = 32'h0000_0090;
  localparam [31:0] REG_TX_CURSOR_BASE = 32'h0000_00E0;

  reg  [NUM_PORTS-1:0]        in_req;
  wire [NUM_PORTS-1:0]        in_ack;
  reg  [NUM_PORTS-1:0]        in_pending;
  reg  [NUM_PORTS*FLIT_W-1:0] in_data;

  wire [NUM_PORTS-1:0]        out_req;
  reg  [NUM_PORTS-1:0]        out_ack;
  wire [NUM_PORTS*FLIT_W-1:0] out_data;
  // Private simulation probes from Ultra NoC; not exposed by this wrapper.

  reg [23:0] in_accept_time [0:NUM_PORTS-1];
  reg [23:0] out_req_time [0:NUM_PORTS-1];

  (* ram_style = "distributed" *) reg [TX_ENTRY_W-1:0] tx_fifo [0:NUM_PORTS-1][0:TX_DEPTH-1];
  (* ram_style = "distributed" *) reg [RX_ENTRY_W-1:0] rx_fifo [0:NUM_PORTS-1][0:RX_DEPTH-1];

  reg aw_hold;
  reg [AXI_ADDR_WIDTH-1:0] awaddr_hold;
  reg w_hold;
  reg [AXI_DATA_WIDTH-1:0] wdata_hold;
  reg [AXI_DATA_WIDTH/8-1:0] wstrb_hold;
  reg wr_stage_valid;
  reg wr_stage_is_tx;
  reg wr_stage_is_reg;
  reg [PORT_W-1:0] wr_stage_tx_port;
  reg [TX_ADDR_W-1:0] wr_stage_tx_idx;
  reg wr_stage_tx_hi;
  reg [31:0] wr_stage_reg_addr;
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
  wire clock = s_axi_aclk;
  wire reset = ~s_axi_aresetn;
  integer edge_trace_enable;

  initial begin
    edge_trace_enable = 0;
    if ($test$plusargs("ASYNC_NOC16_EDGE_TRACE")) begin
      edge_trace_enable = 1;
      $display("TB_EDGE kind=TRACE_ENABLE t=%0t", $time);
    end
  end

  // Optional portable boundary trace.  These signals are the actual NoC
  // ports, after the wrapper's queueing/ack policy, rather than AXI traffic.
  genvar edge_trace_port;
  generate
    for (edge_trace_port = 0; edge_trace_port < NUM_PORTS;
         edge_trace_port = edge_trace_port + 1) begin : boundary_edge_trace
      always @(in_req[edge_trace_port]) begin
        if (edge_trace_enable && !reset)
          $display("TB_EDGE kind=IN_REQ cycle=%0d t=%0t port=%0d req=%0b ack=%0b data=%h",
                   cycle_counter, $time, edge_trace_port, in_req[edge_trace_port],
                   in_ack[edge_trace_port], in_data[edge_trace_port*FLIT_W +: FLIT_W]);
      end
      always @(in_ack[edge_trace_port]) begin
        if (edge_trace_enable && !reset)
          $display("TB_EDGE kind=IN_ACK cycle=%0d t=%0t port=%0d req=%0b ack=%0b data=%h",
                   cycle_counter, $time, edge_trace_port, in_req[edge_trace_port],
                   in_ack[edge_trace_port], in_data[edge_trace_port*FLIT_W +: FLIT_W]);
      end
      always @(out_req[edge_trace_port]) begin
        if (edge_trace_enable && !reset)
          $display("TB_EDGE kind=OUT_REQ cycle=%0d t=%0t port=%0d req=%0b ack=%0b data=%h",
                   cycle_counter, $time, edge_trace_port, out_req[edge_trace_port],
                   out_ack[edge_trace_port], out_data[edge_trace_port*FLIT_W +: FLIT_W]);
      end
      always @(out_ack[edge_trace_port]) begin
        if (edge_trace_enable && !reset)
          $display("TB_EDGE kind=OUT_ACK cycle=%0d t=%0t port=%0d req=%0b ack=%0b data=%h",
                   cycle_counter, $time, edge_trace_port, out_req[edge_trace_port],
                   out_ack[edge_trace_port], out_data[edge_trace_port*FLIT_W +: FLIT_W]);
      end
    end
  endgenerate

  reg start_cmd_toggle;
  reg abort_cmd_toggle;
  reg clear_rx_cmd_toggle;
  reg clear_done_cmd_toggle;
  reg start_cmd_seen;
  reg abort_cmd_seen;
  reg clear_rx_cmd_seen;
  reg clear_done_cmd_seen;

`ifdef ASYNC_NOC16_STAGE1_DEBUG_PORTS
  wire [4:0] stage1_debug_l1_input_valid [0:3];
  wire [4:0] stage1_debug_l1_output_valid [0:3];
  wire [4:0] stage1_debug_l1_context_active [0:3];
  wire [4:0] stage1_debug_l1_winner [0:3];
  wire [4:0] stage1_debug_l1_commit [0:3];
  wire [4:0] stage1_debug_l1_request_mask [0:3][0:4];
  wire [2:0] stage1_debug_l1_output_holder [0:3][0:4];
  wire [4:0] stage1_debug_l2_input_valid;
  wire [4:0] stage1_debug_l2_output_valid;
  wire [4:0] stage1_debug_l2_context_active;
  wire [4:0] stage1_debug_l2_winner;
  wire [4:0] stage1_debug_l2_commit;
  wire [4:0] stage1_debug_l2_request_mask [0:4];
  wire [2:0] stage1_debug_l2_output_holder [0:4];
`endif

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
  wire [PORT_W-1:0] wr_tx_port = wr_tx_rel[13 +: PORT_W];
  wire [31:0] wr_tx_off = wr_tx_rel & (PORT_STRIDE_I - 1);
  wire [TX_ADDR_W-1:0] wr_tx_idx = wr_tx_off[3 +: TX_ADDR_W];
  wire wr_tx_hi = wr_tx_off[2];
  wire wr_tx_ok = wr_is_tx && (wr_tx_port < NUM_PORTS) && (wr_tx_off < TX_BYTES_I);

  wire ar_is_tx = (araddr32 >= TX_BASE_I) && (araddr32 < (TX_BASE_I + NUM_PORTS * PORT_STRIDE_I));
  wire [31:0] ar_tx_rel = araddr32 - TX_BASE_I;
  wire [PORT_W-1:0] ar_tx_port = ar_tx_rel[13 +: PORT_W];
  wire [31:0] ar_tx_off = ar_tx_rel & (PORT_STRIDE_I - 1);
  wire [TX_ADDR_W-1:0] ar_tx_idx = ar_tx_off[3 +: TX_ADDR_W];
  wire ar_tx_hi = ar_tx_off[2];
  wire ar_tx_ok = ar_is_tx && (ar_tx_port < NUM_PORTS) && (ar_tx_off < TX_BYTES_I);

  wire ar_is_rx = (araddr32 >= RX_BASE_I) && (araddr32 < (RX_BASE_I + NUM_PORTS * PORT_STRIDE_I));
  wire [31:0] ar_rx_rel = araddr32 - RX_BASE_I;
  wire [PORT_W-1:0] ar_rx_port = ar_rx_rel[13 +: PORT_W];
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
        wr_stage_tx_port <= {PORT_W{1'b0}};
        wr_stage_tx_idx <= {TX_ADDR_W{1'b0}};
        wr_stage_tx_hi <= 1'b0;
        wr_stage_reg_addr <= 32'd0;
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
        cfg_timeout_cycles <= 32'd5000000;
        cfg_drain_cycles <= 32'd1024;
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
          wr_stage_reg_addr <= awaddr32;
          wr_stage_data <= wdata_hold;
          wr_stage_strb <= wstrb_hold;
          aw_hold <= 1'b0;
          w_hold <= 1'b0;
        end
        if (wr_stage_valid) begin
          s_axi_bvalid <= 1'b1;
          s_axi_bresp <= 2'b00;
          if (wr_stage_is_tx) begin
            if (wr_stage_tx_hi) begin
              if (wr_stage_strb[0]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][35:28] <= wr_stage_data[7:0];
              if (wr_stage_strb[1]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][43:36] <= wr_stage_data[15:8];
              if (wr_stage_strb[2]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][51:44] <= wr_stage_data[23:16];
              if (wr_stage_strb[3]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][52] <= wr_stage_data[31];
            end else begin
              if (wr_stage_strb[0]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][7:0]   <= wr_stage_data[7:0];
              if (wr_stage_strb[1]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][15:8]  <= wr_stage_data[15:8];
              if (wr_stage_strb[2]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][23:16] <= wr_stage_data[23:16];
              if (wr_stage_strb[3]) tx_fifo[wr_stage_tx_port][wr_stage_tx_idx][27:24] <= wr_stage_data[27:24];
            end
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
        if (s_axi_rvalid && s_axi_rready) s_axi_rvalid <= 1'b0;
        if (s_axi_arvalid && s_axi_arready) begin
          s_axi_rvalid <= 1'b1;
          s_axi_rresp <= 2'b00;
          s_axi_rdata <= 32'd0;
          if (ar_tx_ok) begin
            s_axi_rdata <= ar_tx_hi ?
              {tx_fifo[ar_tx_port][ar_tx_idx][52], 7'd0, tx_fifo[ar_tx_port][ar_tx_idx][51:28]} :
              {4'd0, tx_fifo[ar_tx_port][ar_tx_idx][27:0]};
          end else if (ar_rx_ok) begin
            s_axi_rdata <= ar_rx_hi ?
              {rx_fifo[ar_rx_port][ar_rx_idx][57], 2'd0, rx_fifo[ar_rx_port][ar_rx_idx][56:52], rx_fifo[ar_rx_port][ar_rx_idx][51:28]} :
              {4'd0, rx_fifo[ar_rx_port][ar_rx_idx][27:0]};
          end else if (araddr32 < TX_BASE_I) begin
            all_done_status = 1'b1;
            for (p = 0; p < NUM_PORTS; p = p + 1) begin
              if ((tx_cursor[p] < cfg_tx_count[p]) || in_pending[p]) all_done_status = 1'b0;
            end
            case (araddr32)
              REG_STATUS: s_axi_rdata <= {24'd0, (done & irq_enable), 1'b0, all_done_status,
                                           tx_invalid_entry_seen, rx_overflow, timeout_hit, done, running};
              REG_TIMEOUT: s_axi_rdata <= cfg_timeout_cycles;
              REG_DRAIN_CYCLES: s_axi_rdata <= cfg_drain_cycles;
              REG_CYCLE: s_axi_rdata <= cycle_counter;
              REG_RX_COUNT: s_axi_rdata <= rx_count;
              REG_INJECTED: s_axi_rdata <= injected_flits;
              REG_DELIVERED: s_axi_rdata <= delivered_flits;
              REG_IRQ_ENABLE: s_axi_rdata <= {31'd0, irq_enable};
              REG_OUT_ACK_DELAY: s_axi_rdata <= cfg_out_ack_delay_cycles;
              REG_INFO0: s_axi_rdata <= {16'd0, 8'd20, 8'd28};
              REG_INFO1: s_axi_rdata <= {RX_DEPTH_INFO, TX_DEPTH_INFO};
              default: begin
                if ((araddr32 >= REG_TX_COUNT_BASE) &&
                    (araddr32 < (REG_TX_COUNT_BASE + NUM_PORTS*4))) begin
                  p = (araddr32 - REG_TX_COUNT_BASE) >> 2;
                  s_axi_rdata <= cfg_tx_count[p];
                end else if ((araddr32 >= REG_RX_COUNT_BASE) &&
                             (araddr32 < (REG_RX_COUNT_BASE + NUM_PORTS*4))) begin
                  p = (araddr32 - REG_RX_COUNT_BASE) >> 2;
                  s_axi_rdata <= rx_count_port[p];
                end else if ((araddr32 >= REG_TX_CURSOR_BASE) &&
                             (araddr32 < (REG_TX_CURSOR_BASE + NUM_PORTS*4))) begin
                  p = (araddr32 - REG_TX_CURSOR_BASE) >> 2;
                  s_axi_rdata <= tx_cursor[p];
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
    reg [31:0] next_cursor;
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
                if (rx_count_port[p] < RX_DEPTH) begin
                  rx_fifo[p][rx_count_port[p][RX_ADDR_W-1:0]] <= {1'b1, p[4:0], out_req_time[p], out_data[p*FLIT_W +: FLIT_W]};
                  rx_count_port[p] <= rx_count_port[p] + 1'b1;
                end else begin
                  rx_overflow <= 1'b1;
                end
                delivered_inc = delivered_inc + 1;
                out_ack[p] <= out_req[p];
                ack_countdown[p] <= -1;
              end else if (ack_countdown[p] < 0) begin
                ack_countdown[p] <= cfg_out_ack_delay_cycles - 1;
              end else if (ack_countdown[p] == 0) begin
                if (rx_count_port[p] < RX_DEPTH) begin
                  rx_fifo[p][rx_count_port[p][RX_ADDR_W-1:0]] <= {1'b1, p[4:0], out_req_time[p], out_data[p*FLIT_W +: FLIT_W]};
                  rx_count_port[p] <= rx_count_port[p] + 1'b1;
                end else begin
                  rx_overflow <= 1'b1;
                end
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
                tx_fifo[p][tx_cursor[p][TX_ADDR_W-1:0]][51:28] <= in_accept_time[p];
                next_cursor = tx_cursor[p] + 1'b1;
                tx_cursor[p] <= next_cursor;
                in_pending[p] <= 1'b0;

                if ((next_cursor < cfg_tx_count[p]) && (next_cursor < TX_DEPTH)) begin
                  entry = tx_fifo[p][next_cursor[TX_ADDR_W-1:0]];
                  entry_cycle = entry[51:28];
                  if (!entry[52]) begin
                    tx_invalid_entry_seen <= 1'b1;
                    tx_cursor[p] <= next_cursor + 1'b1;
                  end else if (cycle_counter >= {8'd0, entry_cycle}) begin
                    in_data[p*FLIT_W +: FLIT_W] <= entry[27:0];
                    in_req[p] <= ~in_req[p];
                    in_pending[p] <= 1'b1;
                  end
                end
              end
            end else if ((tx_cursor[p] < cfg_tx_count[p]) && (tx_cursor[p] < TX_DEPTH)) begin
              entry = tx_fifo[p][tx_cursor[p][TX_ADDR_W-1:0]];
              entry_cycle = entry[51:28];
              if (!entry[52]) begin
                tx_invalid_entry_seen <= 1'b1;
                tx_cursor[p] <= tx_cursor[p] + 1'b1;
              end else if (cycle_counter >= {8'd0, entry_cycle}) begin
                in_data[p*FLIT_W +: FLIT_W] <= entry[27:0];
                in_req[p] <= ~in_req[p];
                in_pending[p] <= 1'b1;
              end
            end
          end

          injected_flits = 32'd0;
          for (p = 0; p < NUM_PORTS; p = p + 1) injected_flits = injected_flits + tx_cursor[p];

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

  NoC_16nodes dut (
    .clock(clock),
    .reset(reset),
    .io_core_inputs_0_HS_Req(in_req[0]),
    .io_core_inputs_0_HS_Ack(in_ack[0]),
    .io_core_inputs_0_Data_flit(in_data[0*FLIT_W +: FLIT_W]),
    .io_core_inputs_1_HS_Req(in_req[1]),
    .io_core_inputs_1_HS_Ack(in_ack[1]),
    .io_core_inputs_1_Data_flit(in_data[1*FLIT_W +: FLIT_W]),
    .io_core_inputs_2_HS_Req(in_req[2]),
    .io_core_inputs_2_HS_Ack(in_ack[2]),
    .io_core_inputs_2_Data_flit(in_data[2*FLIT_W +: FLIT_W]),
    .io_core_inputs_3_HS_Req(in_req[3]),
    .io_core_inputs_3_HS_Ack(in_ack[3]),
    .io_core_inputs_3_Data_flit(in_data[3*FLIT_W +: FLIT_W]),
    .io_core_inputs_4_HS_Req(in_req[4]),
    .io_core_inputs_4_HS_Ack(in_ack[4]),
    .io_core_inputs_4_Data_flit(in_data[4*FLIT_W +: FLIT_W]),
    .io_core_inputs_5_HS_Req(in_req[5]),
    .io_core_inputs_5_HS_Ack(in_ack[5]),
    .io_core_inputs_5_Data_flit(in_data[5*FLIT_W +: FLIT_W]),
    .io_core_inputs_6_HS_Req(in_req[6]),
    .io_core_inputs_6_HS_Ack(in_ack[6]),
    .io_core_inputs_6_Data_flit(in_data[6*FLIT_W +: FLIT_W]),
    .io_core_inputs_7_HS_Req(in_req[7]),
    .io_core_inputs_7_HS_Ack(in_ack[7]),
    .io_core_inputs_7_Data_flit(in_data[7*FLIT_W +: FLIT_W]),
    .io_core_inputs_8_HS_Req(in_req[8]),
    .io_core_inputs_8_HS_Ack(in_ack[8]),
    .io_core_inputs_8_Data_flit(in_data[8*FLIT_W +: FLIT_W]),
    .io_core_inputs_9_HS_Req(in_req[9]),
    .io_core_inputs_9_HS_Ack(in_ack[9]),
    .io_core_inputs_9_Data_flit(in_data[9*FLIT_W +: FLIT_W]),
    .io_core_inputs_10_HS_Req(in_req[10]),
    .io_core_inputs_10_HS_Ack(in_ack[10]),
    .io_core_inputs_10_Data_flit(in_data[10*FLIT_W +: FLIT_W]),
    .io_core_inputs_11_HS_Req(in_req[11]),
    .io_core_inputs_11_HS_Ack(in_ack[11]),
    .io_core_inputs_11_Data_flit(in_data[11*FLIT_W +: FLIT_W]),
    .io_core_inputs_12_HS_Req(in_req[12]),
    .io_core_inputs_12_HS_Ack(in_ack[12]),
    .io_core_inputs_12_Data_flit(in_data[12*FLIT_W +: FLIT_W]),
    .io_core_inputs_13_HS_Req(in_req[13]),
    .io_core_inputs_13_HS_Ack(in_ack[13]),
    .io_core_inputs_13_Data_flit(in_data[13*FLIT_W +: FLIT_W]),
    .io_core_inputs_14_HS_Req(in_req[14]),
    .io_core_inputs_14_HS_Ack(in_ack[14]),
    .io_core_inputs_14_Data_flit(in_data[14*FLIT_W +: FLIT_W]),
    .io_core_inputs_15_HS_Req(in_req[15]),
    .io_core_inputs_15_HS_Ack(in_ack[15]),
    .io_core_inputs_15_Data_flit(in_data[15*FLIT_W +: FLIT_W]),
    .io_top_input_0_HS_Req(in_req[16]),
    .io_top_input_0_HS_Ack(in_ack[16]),
    .io_top_input_0_Data_flit(in_data[16*FLIT_W +: FLIT_W]),
    .io_top_input_1_HS_Req(in_req[17]),
    .io_top_input_1_HS_Ack(in_ack[17]),
    .io_top_input_1_Data_flit(in_data[17*FLIT_W +: FLIT_W]),
    .io_top_input_2_HS_Req(in_req[18]),
    .io_top_input_2_HS_Ack(in_ack[18]),
    .io_top_input_2_Data_flit(in_data[18*FLIT_W +: FLIT_W]),
    .io_top_input_3_HS_Req(in_req[19]),
    .io_top_input_3_HS_Ack(in_ack[19]),
    .io_top_input_3_Data_flit(in_data[19*FLIT_W +: FLIT_W]),
    .io_top_output_0_HS_Req(out_req[16]),
    .io_top_output_0_HS_Ack(out_ack[16]),
    .io_top_output_0_Data_flit(out_data[16*FLIT_W +: FLIT_W]),
    .io_top_output_1_HS_Req(out_req[17]),
    .io_top_output_1_HS_Ack(out_ack[17]),
    .io_top_output_1_Data_flit(out_data[17*FLIT_W +: FLIT_W]),
    .io_top_output_2_HS_Req(out_req[18]),
    .io_top_output_2_HS_Ack(out_ack[18]),
    .io_top_output_2_Data_flit(out_data[18*FLIT_W +: FLIT_W]),
    .io_top_output_3_HS_Req(out_req[19]),
    .io_top_output_3_HS_Ack(out_ack[19]),
    .io_top_output_3_Data_flit(out_data[19*FLIT_W +: FLIT_W]),
    .io_core_outputs_0_HS_Req(out_req[0]),
    .io_core_outputs_0_HS_Ack(out_ack[0]),
    .io_core_outputs_0_Data_flit(out_data[0*FLIT_W +: FLIT_W]),
    .io_core_outputs_1_HS_Req(out_req[1]),
    .io_core_outputs_1_HS_Ack(out_ack[1]),
    .io_core_outputs_1_Data_flit(out_data[1*FLIT_W +: FLIT_W]),
    .io_core_outputs_2_HS_Req(out_req[2]),
    .io_core_outputs_2_HS_Ack(out_ack[2]),
    .io_core_outputs_2_Data_flit(out_data[2*FLIT_W +: FLIT_W]),
    .io_core_outputs_3_HS_Req(out_req[3]),
    .io_core_outputs_3_HS_Ack(out_ack[3]),
    .io_core_outputs_3_Data_flit(out_data[3*FLIT_W +: FLIT_W]),
    .io_core_outputs_4_HS_Req(out_req[4]),
    .io_core_outputs_4_HS_Ack(out_ack[4]),
    .io_core_outputs_4_Data_flit(out_data[4*FLIT_W +: FLIT_W]),
    .io_core_outputs_5_HS_Req(out_req[5]),
    .io_core_outputs_5_HS_Ack(out_ack[5]),
    .io_core_outputs_5_Data_flit(out_data[5*FLIT_W +: FLIT_W]),
    .io_core_outputs_6_HS_Req(out_req[6]),
    .io_core_outputs_6_HS_Ack(out_ack[6]),
    .io_core_outputs_6_Data_flit(out_data[6*FLIT_W +: FLIT_W]),
    .io_core_outputs_7_HS_Req(out_req[7]),
    .io_core_outputs_7_HS_Ack(out_ack[7]),
    .io_core_outputs_7_Data_flit(out_data[7*FLIT_W +: FLIT_W]),
    .io_core_outputs_8_HS_Req(out_req[8]),
    .io_core_outputs_8_HS_Ack(out_ack[8]),
    .io_core_outputs_8_Data_flit(out_data[8*FLIT_W +: FLIT_W]),
    .io_core_outputs_9_HS_Req(out_req[9]),
    .io_core_outputs_9_HS_Ack(out_ack[9]),
    .io_core_outputs_9_Data_flit(out_data[9*FLIT_W +: FLIT_W]),
    .io_core_outputs_10_HS_Req(out_req[10]),
    .io_core_outputs_10_HS_Ack(out_ack[10]),
    .io_core_outputs_10_Data_flit(out_data[10*FLIT_W +: FLIT_W]),
    .io_core_outputs_11_HS_Req(out_req[11]),
    .io_core_outputs_11_HS_Ack(out_ack[11]),
    .io_core_outputs_11_Data_flit(out_data[11*FLIT_W +: FLIT_W]),
    .io_core_outputs_12_HS_Req(out_req[12]),
    .io_core_outputs_12_HS_Ack(out_ack[12]),
    .io_core_outputs_12_Data_flit(out_data[12*FLIT_W +: FLIT_W]),
    .io_core_outputs_13_HS_Req(out_req[13]),
    .io_core_outputs_13_HS_Ack(out_ack[13]),
    .io_core_outputs_13_Data_flit(out_data[13*FLIT_W +: FLIT_W]),
    .io_core_outputs_14_HS_Req(out_req[14]),
    .io_core_outputs_14_HS_Ack(out_ack[14]),
    .io_core_outputs_14_Data_flit(out_data[14*FLIT_W +: FLIT_W]),
    .io_core_outputs_15_HS_Req(out_req[15]),
    .io_core_outputs_15_HS_Ack(out_ack[15]),
    .io_core_outputs_15_Data_flit(out_data[15*FLIT_W +: FLIT_W])
`ifdef ASYNC_NOC16_STAGE1_DEBUG_PORTS
    ,
    .io_debug_l1InputValid_0(stage1_debug_l1_input_valid[0]),
    .io_debug_l1InputValid_1(stage1_debug_l1_input_valid[1]),
    .io_debug_l1InputValid_2(stage1_debug_l1_input_valid[2]),
    .io_debug_l1InputValid_3(stage1_debug_l1_input_valid[3]),
    .io_debug_l1OutputValid_0(stage1_debug_l1_output_valid[0]),
    .io_debug_l1OutputValid_1(stage1_debug_l1_output_valid[1]),
    .io_debug_l1OutputValid_2(stage1_debug_l1_output_valid[2]),
    .io_debug_l1OutputValid_3(stage1_debug_l1_output_valid[3]),
    .io_debug_l1ContextActive_0(stage1_debug_l1_context_active[0]),
    .io_debug_l1ContextActive_1(stage1_debug_l1_context_active[1]),
    .io_debug_l1ContextActive_2(stage1_debug_l1_context_active[2]),
    .io_debug_l1ContextActive_3(stage1_debug_l1_context_active[3]),
    .io_debug_l1Winner_0(stage1_debug_l1_winner[0]),
    .io_debug_l1Winner_1(stage1_debug_l1_winner[1]),
    .io_debug_l1Winner_2(stage1_debug_l1_winner[2]),
    .io_debug_l1Winner_3(stage1_debug_l1_winner[3]),
    .io_debug_l1Commit_0(stage1_debug_l1_commit[0]),
    .io_debug_l1Commit_1(stage1_debug_l1_commit[1]),
    .io_debug_l1Commit_2(stage1_debug_l1_commit[2]),
    .io_debug_l1Commit_3(stage1_debug_l1_commit[3]),
    .io_debug_l1RequestMask_0_0(stage1_debug_l1_request_mask[0][0]),
    .io_debug_l1RequestMask_0_1(stage1_debug_l1_request_mask[0][1]),
    .io_debug_l1RequestMask_0_2(stage1_debug_l1_request_mask[0][2]),
    .io_debug_l1RequestMask_0_3(stage1_debug_l1_request_mask[0][3]),
    .io_debug_l1RequestMask_0_4(stage1_debug_l1_request_mask[0][4]),
    .io_debug_l1RequestMask_1_0(stage1_debug_l1_request_mask[1][0]),
    .io_debug_l1RequestMask_1_1(stage1_debug_l1_request_mask[1][1]),
    .io_debug_l1RequestMask_1_2(stage1_debug_l1_request_mask[1][2]),
    .io_debug_l1RequestMask_1_3(stage1_debug_l1_request_mask[1][3]),
    .io_debug_l1RequestMask_1_4(stage1_debug_l1_request_mask[1][4]),
    .io_debug_l1RequestMask_2_0(stage1_debug_l1_request_mask[2][0]),
    .io_debug_l1RequestMask_2_1(stage1_debug_l1_request_mask[2][1]),
    .io_debug_l1RequestMask_2_2(stage1_debug_l1_request_mask[2][2]),
    .io_debug_l1RequestMask_2_3(stage1_debug_l1_request_mask[2][3]),
    .io_debug_l1RequestMask_2_4(stage1_debug_l1_request_mask[2][4]),
    .io_debug_l1RequestMask_3_0(stage1_debug_l1_request_mask[3][0]),
    .io_debug_l1RequestMask_3_1(stage1_debug_l1_request_mask[3][1]),
    .io_debug_l1RequestMask_3_2(stage1_debug_l1_request_mask[3][2]),
    .io_debug_l1RequestMask_3_3(stage1_debug_l1_request_mask[3][3]),
    .io_debug_l1RequestMask_3_4(stage1_debug_l1_request_mask[3][4]),
    .io_debug_l1OutputHolder_0_0(stage1_debug_l1_output_holder[0][0]),
    .io_debug_l1OutputHolder_0_1(stage1_debug_l1_output_holder[0][1]),
    .io_debug_l1OutputHolder_0_2(stage1_debug_l1_output_holder[0][2]),
    .io_debug_l1OutputHolder_0_3(stage1_debug_l1_output_holder[0][3]),
    .io_debug_l1OutputHolder_0_4(stage1_debug_l1_output_holder[0][4]),
    .io_debug_l1OutputHolder_1_0(stage1_debug_l1_output_holder[1][0]),
    .io_debug_l1OutputHolder_1_1(stage1_debug_l1_output_holder[1][1]),
    .io_debug_l1OutputHolder_1_2(stage1_debug_l1_output_holder[1][2]),
    .io_debug_l1OutputHolder_1_3(stage1_debug_l1_output_holder[1][3]),
    .io_debug_l1OutputHolder_1_4(stage1_debug_l1_output_holder[1][4]),
    .io_debug_l1OutputHolder_2_0(stage1_debug_l1_output_holder[2][0]),
    .io_debug_l1OutputHolder_2_1(stage1_debug_l1_output_holder[2][1]),
    .io_debug_l1OutputHolder_2_2(stage1_debug_l1_output_holder[2][2]),
    .io_debug_l1OutputHolder_2_3(stage1_debug_l1_output_holder[2][3]),
    .io_debug_l1OutputHolder_2_4(stage1_debug_l1_output_holder[2][4]),
    .io_debug_l1OutputHolder_3_0(stage1_debug_l1_output_holder[3][0]),
    .io_debug_l1OutputHolder_3_1(stage1_debug_l1_output_holder[3][1]),
    .io_debug_l1OutputHolder_3_2(stage1_debug_l1_output_holder[3][2]),
    .io_debug_l1OutputHolder_3_3(stage1_debug_l1_output_holder[3][3]),
    .io_debug_l1OutputHolder_3_4(stage1_debug_l1_output_holder[3][4]),
    .io_debug_l2InputValid(stage1_debug_l2_input_valid),
    .io_debug_l2OutputValid(stage1_debug_l2_output_valid),
    .io_debug_l2ContextActive(stage1_debug_l2_context_active),
    .io_debug_l2Winner(stage1_debug_l2_winner),
    .io_debug_l2Commit(stage1_debug_l2_commit),
    .io_debug_l2RequestMask_0(stage1_debug_l2_request_mask[0]),
    .io_debug_l2RequestMask_1(stage1_debug_l2_request_mask[1]),
    .io_debug_l2RequestMask_2(stage1_debug_l2_request_mask[2]),
    .io_debug_l2RequestMask_3(stage1_debug_l2_request_mask[3]),
    .io_debug_l2RequestMask_4(stage1_debug_l2_request_mask[4]),
    .io_debug_l2OutputHolder_0(stage1_debug_l2_output_holder[0]),
    .io_debug_l2OutputHolder_1(stage1_debug_l2_output_holder[1]),
    .io_debug_l2OutputHolder_2(stage1_debug_l2_output_holder[2]),
    .io_debug_l2OutputHolder_3(stage1_debug_l2_output_holder[3]),
    .io_debug_l2OutputHolder_4(stage1_debug_l2_output_holder[4])
`endif
  );
endmodule

`default_nettype wire

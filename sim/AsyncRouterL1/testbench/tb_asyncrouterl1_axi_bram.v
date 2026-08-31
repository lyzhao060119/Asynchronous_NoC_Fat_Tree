`timescale 1ns/1ps

module tb_asyncrouterl1_axi_bram;
  localparam FLIT_W = 28;
  localparam NUM_PORTS = 6;
  localparam AXI_ADDR_WIDTH = 17;
  localparam AXI_DATA_WIDTH = 32;

  localparam TX_DEPTH = 24;
  localparam RX_DEPTH = 66;

  localparam MAX_INPUT_FLITS = 8192;
  localparam MAX_EXPECT_FLITS = 32768;
  localparam MAX_RX_FLITS = NUM_PORTS * RX_DEPTH;
  localparam MAX_PKT_SEQ = 65536;
  localparam STR_CHARS = 256;

  localparam P_CHILD0 = 0;
  localparam P_CHILD1 = 1;
  localparam P_CHILD2 = 2;
  localparam P_CHILD3 = 3;
  localparam P_PARENT0 = 4;
  localparam P_PARENT1 = 5;

  localparam [AXI_ADDR_WIDTH-1:0] REG_CTRL           = 17'h00000;
  localparam [AXI_ADDR_WIDTH-1:0] REG_STATUS         = 17'h00004;
  localparam [AXI_ADDR_WIDTH-1:0] REG_TIMEOUT        = 17'h00008;
  localparam [AXI_ADDR_WIDTH-1:0] REG_DRAIN_CYCLES   = 17'h0000C;
  localparam [AXI_ADDR_WIDTH-1:0] REG_CYCLE          = 17'h00010;
  localparam [AXI_ADDR_WIDTH-1:0] REG_RX_COUNT       = 17'h00014;
  localparam [AXI_ADDR_WIDTH-1:0] REG_INJECTED       = 17'h00018;
  localparam [AXI_ADDR_WIDTH-1:0] REG_DELIVERED      = 17'h0001C;
  localparam [AXI_ADDR_WIDTH-1:0] REG_IRQ_ENABLE     = 17'h00020;
  localparam [AXI_ADDR_WIDTH-1:0] REG_OUT_ACK_DELAY  = 17'h00024;
  localparam [AXI_ADDR_WIDTH-1:0] REG_TX_COUNT_BASE  = 17'h00040;
  localparam [AXI_ADDR_WIDTH-1:0] REG_RX_COUNT_BASE  = 17'h00080;

  localparam [AXI_ADDR_WIDTH-1:0] TX_BASE = 17'h01000;
  localparam [AXI_ADDR_WIDTH-1:0] TX_PORT_STRIDE = 17'h02000;
  localparam [AXI_ADDR_WIDTH-1:0] RX_BASE = 17'h10000;
  localparam AXI_TIMEOUT_CYCLES = 20000;
  localparam AXI_RESP_SAMPLE_DELAY = 2;

  reg clock;
  reg s_axi_aresetn;

  reg  [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
  reg                       s_axi_awvalid;
  wire                      s_axi_awready;
  reg  [AXI_DATA_WIDTH-1:0] s_axi_wdata;
  reg  [AXI_DATA_WIDTH/8-1:0] s_axi_wstrb;
  reg                       s_axi_wvalid;
  wire                      s_axi_wready;
  wire [1:0]                s_axi_bresp;
  wire                      s_axi_bvalid;
  reg                       s_axi_bready;

  reg  [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
  reg                       s_axi_arvalid;
  wire                      s_axi_arready;
  wire [AXI_DATA_WIDTH-1:0] s_axi_rdata;
  wire [1:0]                s_axi_rresp;
  wire                      s_axi_rvalid;
  reg                       s_axi_rready;
  wire                      irq;

  integer reset_cycles, timeout_cycles, out_ack_delay_cycles;
  reg [STR_CHARS*8-1:0] case_file, case_name, csv_file;

  integer input_count;
  integer input_cycle [0:MAX_INPUT_FLITS-1];
  integer input_port [0:MAX_INPUT_FLITS-1];
  integer input_pkt_seq [0:MAX_INPUT_FLITS-1];
  reg [FLIT_W-1:0] input_flit [0:MAX_INPUT_FLITS-1];

  integer expected_count;
  reg [NUM_PORTS-1:0] expected_mask [0:MAX_EXPECT_FLITS-1];
  integer expected_pkt_seq [0:MAX_EXPECT_FLITS-1];
  reg expected_is_tail [0:MAX_EXPECT_FLITS-1];
  reg [FLIT_W-1:0] expected_flit [0:MAX_EXPECT_FLITS-1];
  reg expected_seen [0:MAX_EXPECT_FLITS-1];

  integer rx_count;
  integer rx_port [0:MAX_RX_FLITS-1];
  integer rx_cycle [0:MAX_RX_FLITS-1];
  reg [FLIT_W-1:0] rx_flit [0:MAX_RX_FLITS-1];
  reg rx_valid [0:MAX_RX_FLITS-1];

  integer packet_head_cycle [0:MAX_PKT_SEQ-1];
  integer latency_samples [0:MAX_EXPECT_FLITS-1];
  integer latency_count;

  integer missing_flits;
  integer unexpected_flits;
  integer injected_flits;
  integer delivered_flits;
  integer injected_packets;
  integer delivered_packets;
  integer status_timeout_hit;
  integer status_rx_overflow;
  integer final_cycle;

  reg [31:0] rd_data;

  initial begin
    clock = 1'b0;
    forever #10 clock = ~clock;
  end

  function is_blank_or_comment;
    input [STR_CHARS*8-1:0] line;
    reg [STR_CHARS*8-1:0] tag;
    begin
      tag = "";
      is_blank_or_comment = (($sscanf(line, "%s", tag) != 1) || (tag == "#"));
    end
  endfunction

  function [AXI_ADDR_WIDTH-1:0] tx_addr_word;
    input integer port;
    input integer entry;
    input integer hi_word;
    reg [31:0] addr32;
    begin
      addr32 = TX_BASE + port * TX_PORT_STRIDE + entry * 8 + (hi_word ? 4 : 0);
      tx_addr_word = addr32[AXI_ADDR_WIDTH-1:0];
    end
  endfunction

  function [AXI_ADDR_WIDTH-1:0] rx_addr_word;
    input integer port;
    input integer entry;
    input integer hi_word;
    reg [31:0] addr32;
    begin
      addr32 = RX_BASE + port * TX_PORT_STRIDE + entry * 8 + (hi_word ? 4 : 0);
      rx_addr_word = addr32[AXI_ADDR_WIDTH-1:0];
    end
  endfunction

  task automatic load_case;
    integer fd, n, line_no;
    integer cyc, p, pkt_seq, tmp;
    reg [31:0] mask;
    reg [FLIT_W-1:0] flit;
    reg [STR_CHARS*8-1:0] line, tag, name;
    begin
      reset_cycles = 20;
      timeout_cycles = 2000;
      out_ack_delay_cycles = 0;
      input_count = 0;
      expected_count = 0;
      case_name = "unnamed";

      case_file = "";
      csv_file = "";
      if (!$value$plusargs("CASE=%s", case_file))
        case_file = "sim/AsyncRouterL1/testbench/cases/smoke_directed.case";
      if (!$value$plusargs("CSV=%s", csv_file))
        csv_file = "sim/AsyncRouterL1/summary/async_axi_wrapper_measure_summary.csv";

      fd = $fopen(case_file, "r");
      if ((fd == 0) && (case_file == "sim/AsyncRouterL1/testbench/cases/smoke_directed.case")) begin
        case_file = "cases/smoke_directed.case";
        fd = $fopen(case_file, "r");
      end
      if (fd == 0) begin
        $display("TB_FATAL cannot open CASE file: %0s", case_file);
        $finish;
      end

      line_no = 0;
      while (!$feof(fd)) begin
        line = "";
        n = $fgets(line, fd);
        line_no = line_no + 1;

        if (!is_blank_or_comment(line)) begin
          tag = "";
          n = $sscanf(line, "%s", tag);
          if (tag == "case") begin
            if ($sscanf(line, "%s %s", tag, name) != 2) begin
              $display("TB_FATAL malformed case at line %0d", line_no);
              $finish;
            end
            case_name = name;
          end else if (tag == "timeout_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed timeout_cycles at line %0d", line_no);
              $finish;
            end
            timeout_cycles = tmp;
          end else if (tag == "reset_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed reset_cycles at line %0d", line_no);
              $finish;
            end
            reset_cycles = tmp;
          end else if (tag == "out_ack_delay_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) != 2) begin
              $display("TB_FATAL malformed out_ack_delay_cycles at line %0d", line_no);
              $finish;
            end
            out_ack_delay_cycles = tmp;
          end else if (tag == "input") begin
            if ($sscanf(line, "%s %d %d %d %h", tag, cyc, p, pkt_seq, flit) != 5) begin
              $display("TB_FATAL malformed input at line %0d", line_no);
              $finish;
            end
            if ((input_count >= MAX_INPUT_FLITS) || (p < 0) || (p >= NUM_PORTS) ||
                (pkt_seq < 0) || (pkt_seq >= MAX_PKT_SEQ)) begin
              $display("TB_FATAL invalid input values at line %0d", line_no);
              $finish;
            end
            input_cycle[input_count] = cyc;
            input_port[input_count] = p;
            input_pkt_seq[input_count] = pkt_seq;
            input_flit[input_count] = flit;
            input_count = input_count + 1;
          end else if (tag == "expect") begin
            if ($sscanf(line, "%s %h %d %d %h", tag, mask, pkt_seq, tmp, flit) != 5) begin
              $display("TB_FATAL malformed expect at line %0d", line_no);
              $finish;
            end
            if ((expected_count >= MAX_EXPECT_FLITS) || (mask[NUM_PORTS-1:0] == 0) || (mask[31:NUM_PORTS] != 0) ||
                (pkt_seq < 0) || (pkt_seq >= MAX_PKT_SEQ) || ((tmp != 0) && (tmp != 1))) begin
              $display("TB_FATAL invalid expect values at line %0d", line_no);
              $finish;
            end
            expected_mask[expected_count] = mask[NUM_PORTS-1:0];
            expected_pkt_seq[expected_count] = pkt_seq;
            expected_is_tail[expected_count] = (tmp == 1);
            expected_flit[expected_count] = flit;
            expected_seen[expected_count] = 1'b0;
            expected_count = expected_count + 1;
          end
        end
      end
      $fclose(fd);
    end
  endtask

  task automatic axi_write;
    input [AXI_ADDR_WIDTH-1:0] addr;
    input [31:0] data;
    integer timeout;
    reg aw_done;
    reg w_done;
    begin
      aw_done = 1'b0;
      w_done = 1'b0;
      @(negedge clock);
      s_axi_awaddr = addr;
      s_axi_awvalid = 1'b0;
      s_axi_wdata = data;
      s_axi_wstrb = 4'hF;
      s_axi_wvalid = 1'b0;
      s_axi_bready = 1'b1;
      @(negedge clock);
      s_axi_awvalid = 1'b1;
      s_axi_wvalid = 1'b1;

      timeout = 0;
      while (!(aw_done && w_done)) begin
        @(posedge clock);
        if (!aw_done && s_axi_awready) begin
          aw_done = 1'b1;
        end
        if (!w_done && s_axi_wready) begin
          w_done = 1'b1;
        end
        @(negedge clock);
        if (aw_done) s_axi_awvalid = 1'b0;
        if (w_done) s_axi_wvalid = 1'b0;
        timeout = timeout + 1;
        if (timeout > AXI_TIMEOUT_CYCLES) begin
          $display("TB_FATAL axi_write handshake timeout addr=%h", addr);
          $finish;
        end
      end

      timeout = 0;
      while (!s_axi_bvalid) begin
        @(posedge clock);
        timeout = timeout + 1;
        if (timeout > AXI_TIMEOUT_CYCLES) begin
          $display("TB_FATAL axi_write bvalid timeout addr=%h", addr);
          $finish;
        end
      end
      #AXI_RESP_SAMPLE_DELAY;
      if (s_axi_bresp != 2'b00) begin
        $display("TB_FATAL axi_write bresp error addr=%h bresp=%b", addr, s_axi_bresp);
        $finish;
      end
      @(negedge clock);
      s_axi_bready = 1'b0;
    end
  endtask

  task automatic init_measurements;
    integer i;
    integer pkt_seq;
    begin
      injected_packets = 0;
      delivered_packets = 0;
      latency_count = 0;

      for (i = 0; i < MAX_PKT_SEQ; i = i + 1)
        packet_head_cycle[i] = -1;

      for (i = 0; i < input_count; i = i + 1) begin
        if (input_flit[i][27]) begin
          pkt_seq = input_pkt_seq[i];
          injected_packets = injected_packets + 1;
        end
      end
    end
  endtask

  task automatic axi_read;
    input [AXI_ADDR_WIDTH-1:0] addr;
    output [31:0] data;
    integer timeout;
    reg ar_done;
    begin
      ar_done = 1'b0;
      @(negedge clock);
      s_axi_araddr = addr;
      s_axi_arvalid = 1'b0;
      s_axi_rready = 1'b1;
      @(negedge clock);
      s_axi_arvalid = 1'b1;

      timeout = 0;
      while (!ar_done) begin
        @(posedge clock);
        if (s_axi_arready) begin
          ar_done = 1'b1;
        end
        @(negedge clock);
        if (ar_done) s_axi_arvalid = 1'b0;
        timeout = timeout + 1;
        if (timeout > AXI_TIMEOUT_CYCLES) begin
          $display("TB_FATAL axi_read ar handshake timeout addr=%h", addr);
          $finish;
        end
      end

      timeout = 0;
      while (!s_axi_rvalid) begin
        @(posedge clock);
        timeout = timeout + 1;
        if (timeout > AXI_TIMEOUT_CYCLES) begin
          $display("TB_FATAL axi_read rvalid timeout addr=%h", addr);
          $finish;
        end
      end
      #AXI_RESP_SAMPLE_DELAY;
      if (s_axi_rresp != 2'b00) begin
        $display("TB_FATAL axi_read rresp error addr=%h rresp=%b", addr, s_axi_rresp);
        $finish;
      end
      data = s_axi_rdata;
      @(negedge clock);
      s_axi_rready = 1'b0;
    end
  endtask

  task automatic program_wrapper_from_case;
    integer p, i, slot;
    reg [31:0] lo_word;
    reg [31:0] hi_word;
    begin
      // clear done/rx state
      axi_write(REG_CTRL, 32'h0000_000C);
      axi_write(REG_TIMEOUT, timeout_cycles);
      axi_write(REG_DRAIN_CYCLES, 32'd64);
      axi_write(REG_OUT_ACK_DELAY, out_ack_delay_cycles);
      axi_write(REG_IRQ_ENABLE, 32'd0);

      // Program per-port TX input queues + TX count.
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        slot = 0;
        for (i = 0; i < input_count; i = i + 1) begin
          if (input_port[i] == p) begin
            if (slot >= TX_DEPTH) begin
              $display("TB_FATAL TX depth overflow port=%0d slot=%0d TX_DEPTH=%0d", p, slot, TX_DEPTH);
              $finish;
            end
            lo_word = {4'd0, input_flit[i]};
            hi_word = {1'b1, 7'd0, input_cycle[i][23:0]};
            axi_write(tx_addr_word(p, slot, 0), lo_word);
            axi_write(tx_addr_word(p, slot, 1), hi_word);
            slot = slot + 1;
          end
        end
        axi_write(REG_TX_COUNT_BASE + p*4, slot);
      end
    end
  endtask

  task automatic run_wrapper;
    integer poll_limit;
    begin
      axi_write(REG_CTRL, 32'h0000_0001); // start
      poll_limit = timeout_cycles + 4096;
      while (poll_limit > 0) begin
        axi_read(REG_STATUS, rd_data);
        if (rd_data[1]) begin
          poll_limit = 0;
        end else begin
          poll_limit = poll_limit - 1;
        end
      end
      axi_read(REG_STATUS, rd_data);
      if (!rd_data[1]) begin
        $display("TB_FATAL wrapper did not assert done");
        $finish;
      end
      status_timeout_hit = rd_data[2];
      status_rx_overflow = rd_data[3];

      axi_read(REG_INJECTED, rd_data);
      injected_flits = rd_data;
      axi_read(REG_DELIVERED, rd_data);
      delivered_flits = rd_data;
      axi_read(REG_CYCLE, rd_data);
      final_cycle = rd_data;
    end
  endtask

  task automatic fetch_rx_entries;
    integer p, i;
    integer total_rx_count;
    integer port_rx_count;
    reg [31:0] lo_word;
    reg [31:0] hi_word;
    begin
      axi_read(REG_RX_COUNT, rd_data);
      total_rx_count = rd_data;
      if (total_rx_count > MAX_RX_FLITS) begin
        $display("TB_WARN global rx_count (%0d) exceeds MAX_RX_FLITS (%0d); using per-port RX counts", total_rx_count, MAX_RX_FLITS);
      end

      rx_count = 0;
      for (p = 0; p < NUM_PORTS; p = p + 1) begin
        axi_read(REG_RX_COUNT_BASE + p*4, rd_data);
        port_rx_count = rd_data;
        if (port_rx_count > RX_DEPTH) begin
          $display("TB_FATAL port %0d rx_count (%0d) exceeds RX_DEPTH (%0d)", p, port_rx_count, RX_DEPTH);
          $finish;
        end

        for (i = 0; i < port_rx_count; i = i + 1) begin
          if (rx_count >= MAX_RX_FLITS) begin
            $display("TB_FATAL merged RX overflow");
            $finish;
          end
          axi_read(rx_addr_word(p, i, 0), lo_word);
          axi_read(rx_addr_word(p, i, 1), hi_word);
          rx_valid[rx_count] = hi_word[31];
          rx_port[rx_count] = hi_word[26:24];
          rx_cycle[rx_count] = hi_word[23:0];
          rx_flit[rx_count] = lo_word[27:0];
          rx_count = rx_count + 1;
        end
      end

      if (rx_count != total_rx_count) begin
        $display("TB_WARN total RX mismatch: register=%0d merged=%0d; using merged per-port RX entries", total_rx_count, rx_count);
      end
    end
  endtask

  task automatic fetch_tx_accept_times;
    integer p, i, slot;
    integer slot_for_port [0:NUM_PORTS-1];
    integer pkt_seq;
    reg [31:0] hi_word;
    begin
      for (p = 0; p < NUM_PORTS; p = p + 1) slot_for_port[p] = 0;

      for (i = 0; i < input_count; i = i + 1) begin
        p = input_port[i];
        slot = slot_for_port[p];
        slot_for_port[p] = slot_for_port[p] + 1;

        if (input_flit[i][27]) begin
          pkt_seq = input_pkt_seq[i];
          axi_read(tx_addr_word(p, slot, 1), hi_word);
          if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && hi_word[31]) begin
            packet_head_cycle[pkt_seq] = hi_word[23:0];
          end
        end
      end
    end
  endtask

  task automatic check_expectations;
    integer i, j;
    integer pkt_seq;
    integer lat;
    reg found;
    reg [NUM_PORTS-1:0] port_bit;
    begin
      for (i = 0; i < expected_count; i = i + 1) expected_seen[i] = 1'b0;
      unexpected_flits = 0;
      delivered_packets = 0;
      latency_count = 0;

      for (i = 0; i < rx_count; i = i + 1) begin
        if (rx_valid[i] && (rx_port[i] >= 0) && (rx_port[i] < NUM_PORTS)) begin
          found = 1'b0;
          port_bit = 0;
          port_bit[rx_port[i]] = 1'b1;
          for (j = 0; j < expected_count; j = j + 1) begin
            if (!found && !expected_seen[j] &&
                ((expected_mask[j] & port_bit) != 0) &&
                (expected_flit[j] === rx_flit[i])) begin
              expected_seen[j] = 1'b1;
              found = 1'b1;
              if (expected_is_tail[j]) begin
                pkt_seq = expected_pkt_seq[j];
                delivered_packets = delivered_packets + 1;
                if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && (packet_head_cycle[pkt_seq] >= 0)) begin
                  lat = rx_cycle[i] - packet_head_cycle[pkt_seq];
                  if (latency_count < MAX_EXPECT_FLITS) begin
                    latency_samples[latency_count] = lat;
                    latency_count = latency_count + 1;
                  end
                end
              end
            end
          end
          if (!found) unexpected_flits = unexpected_flits + 1;
        end
      end

      missing_flits = 0;
      for (i = 0; i < expected_count; i = i + 1)
        if (!expected_seen[i]) missing_flits = missing_flits + 1;
    end
  endtask

  task automatic write_csv_and_finish;
    integer i, j, t;
    integer lat_sum;
    integer max_lat;
    integer rank95;
    integer rank99;
    integer p95_lat;
    integer p99_lat;
    integer fd_csv;
    integer csv_pos;
    reg write_header;
    reg pass_ok;
    reg [31:0] pass_text;
    real avg_lat;
    real avg_lat_ns;
    real max_lat_ns;
    real p95_lat_ns;
    real p99_lat_ns;
    real throughput;
    begin
      lat_sum = 0;
      max_lat = 0;
      for (i = 0; i < latency_count; i = i + 1) begin
        lat_sum = lat_sum + latency_samples[i];
        if (latency_samples[i] > max_lat) max_lat = latency_samples[i];
      end

      for (i = 0; i < latency_count; i = i + 1) begin
        for (j = i + 1; j < latency_count; j = j + 1) begin
          if (latency_samples[j] < latency_samples[i]) begin
            t = latency_samples[i];
            latency_samples[i] = latency_samples[j];
            latency_samples[j] = t;
          end
        end
      end

      if (latency_count > 0) begin
        rank95 = (95 * latency_count + 99) / 100;
        rank99 = (99 * latency_count + 99) / 100;
        if (rank95 < 1) rank95 = 1;
        if (rank99 < 1) rank99 = 1;
        if (rank95 > latency_count) rank95 = latency_count;
        if (rank99 > latency_count) rank99 = latency_count;
        p95_lat = latency_samples[rank95 - 1];
        p99_lat = latency_samples[rank99 - 1];
        avg_lat = lat_sum * 1.0 / latency_count;
      end else begin
        p95_lat = 0;
        p99_lat = 0;
        avg_lat = 0.0;
      end
      avg_lat_ns = avg_lat / 10.0;
      max_lat_ns = max_lat / 10.0;
      p95_lat_ns = p95_lat / 10.0;
      p99_lat_ns = p99_lat / 10.0;

      throughput = (final_cycle > 0) ? (delivered_flits * 1.0 / final_cycle) : 0.0;
      pass_ok = (missing_flits == 0) &&
                (unexpected_flits == 0) &&
                (status_timeout_hit == 0) &&
                (status_rx_overflow == 0) &&
                (injected_flits == input_count);
      pass_text = pass_ok ? "PASS" : "FAIL";

      fd_csv = $fopen(csv_file, "a+");
      if ((fd_csv == 0) && (csv_file == "sim/AsyncRouterL1/summary/async_axi_wrapper_measure_summary.csv")) begin
        csv_file = "../summary/async_axi_wrapper_measure_summary.csv";
        fd_csv = $fopen(csv_file, "a+");
      end
      if (fd_csv == 0) begin
        $display("TB_FATAL cannot open CSV file: %0s", csv_file);
        $finish;
      end
      csv_pos = $fseek(fd_csv, 0, 2);
      csv_pos = $ftell(fd_csv);
      write_header = (csv_pos == 0);
      if (write_header) begin
        $fwrite(fd_csv, "case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,rx_overflow,measure_cycles,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      end
      $fwrite(fd_csv, "%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.3f,%0.3f,%0.3f,%0.3f,%0s\n",
              case_name, injected_packets, delivered_packets, injected_flits, delivered_flits,
              missing_flits, unexpected_flits, status_timeout_hit, status_rx_overflow, final_cycle,
              throughput, avg_lat_ns, max_lat_ns, p95_lat_ns, p99_lat_ns, pass_text);
      $fclose(fd_csv);

      $display("TB_RESULT %0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d avg_lat_ns=%0.3f p95_ns=%0.3f p99_ns=%0.3f missing=%0d unexpected=%0d timeout=%0d rx_overflow=%0d",
               pass_text, case_name, injected_flits, delivered_flits, delivered_packets,
               avg_lat_ns, p95_lat_ns, p99_lat_ns, missing_flits, unexpected_flits,
               status_timeout_hit, status_rx_overflow);
      $finish;
    end
  endtask
  integer i;
  initial begin
    s_axi_aresetn = 1'b0;
    s_axi_awaddr = 0;
    s_axi_awvalid = 0;
    s_axi_wdata = 0;
    s_axi_wstrb = 0;
    s_axi_wvalid = 0;
    s_axi_bready = 0;
    s_axi_araddr = 0;
    s_axi_arvalid = 0;
    s_axi_rready = 0;
    rx_count = 0;
    missing_flits = 0;
    unexpected_flits = 0;
    injected_flits = 0;
    delivered_flits = 0;
    injected_packets = 0;
    delivered_packets = 0;
    status_timeout_hit = 0;
    status_rx_overflow = 0;
    final_cycle = 0;
    latency_count = 0;
    for (i = 0; i < MAX_RX_FLITS; i = i + 1) begin
      rx_valid[i] = 1'b0;
      rx_port[i] = 0;
      rx_cycle[i] = 0;
      rx_flit[i] = 0;
    end

    load_case();
    init_measurements();
    if (reset_cycles < 20) reset_cycles = 20;

    repeat (reset_cycles) @(posedge clock);
    @(negedge clock);
    s_axi_aresetn = 1'b1;
    repeat (2) @(posedge clock);

    program_wrapper_from_case();
    run_wrapper();
    fetch_tx_accept_times();
    fetch_rx_entries();
    check_expectations();
    write_csv_and_finish();
  end

  async_routerl1_axi_bram_wrapper #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .TX_DEPTH(TX_DEPTH),
    .RX_DEPTH(RX_DEPTH)
  ) dut (
    .s_axi_aclk      (clock),
    .s_axi_aresetn   (s_axi_aresetn),

    .s_axi_awaddr    (s_axi_awaddr),
    .s_axi_awvalid   (s_axi_awvalid),
    .s_axi_awready   (s_axi_awready),
    .s_axi_wdata     (s_axi_wdata),
    .s_axi_wstrb     (s_axi_wstrb),
    .s_axi_wvalid    (s_axi_wvalid),
    .s_axi_wready    (s_axi_wready),
    .s_axi_bresp     (s_axi_bresp),
    .s_axi_bvalid    (s_axi_bvalid),
    .s_axi_bready    (s_axi_bready),

    .s_axi_araddr    (s_axi_araddr),
    .s_axi_arvalid   (s_axi_arvalid),
    .s_axi_arready   (s_axi_arready),
    .s_axi_rdata     (s_axi_rdata),
    .s_axi_rresp     (s_axi_rresp),
    .s_axi_rvalid    (s_axi_rvalid),
    .s_axi_rready    (s_axi_rready),
    .irq             (irq)
  );
endmodule

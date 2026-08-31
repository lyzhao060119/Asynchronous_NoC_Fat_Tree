`timescale 1ns/1ps

module tb_noc16_async_axi_bram;
  localparam FLIT_W = 28;
  localparam NUM_PORTS = 20;
  localparam AXI_ADDR_WIDTH = 20;
  localparam AXI_DATA_WIDTH = 32;
  localparam TX_DEPTH = 1024;
  localparam RX_DEPTH = 1024;

  localparam MAX_INPUT_FLITS = 131072;
  localparam MAX_EXPECT_FLITS = 262144;
  localparam MAX_RX_FLITS = NUM_PORTS * RX_DEPTH;
  localparam MAX_PKT_SEQ = 262144;
  localparam STR_CHARS = 256;

  localparam [AXI_ADDR_WIDTH-1:0] REG_CTRL           = 20'h00000;
  localparam [AXI_ADDR_WIDTH-1:0] REG_STATUS         = 20'h00004;
  localparam [AXI_ADDR_WIDTH-1:0] REG_TIMEOUT        = 20'h00008;
  localparam [AXI_ADDR_WIDTH-1:0] REG_DRAIN_CYCLES   = 20'h0000C;
  localparam [AXI_ADDR_WIDTH-1:0] REG_CYCLE          = 20'h00010;
  localparam [AXI_ADDR_WIDTH-1:0] REG_RX_COUNT       = 20'h00014;
  localparam [AXI_ADDR_WIDTH-1:0] REG_INJECTED       = 20'h00018;
  localparam [AXI_ADDR_WIDTH-1:0] REG_DELIVERED      = 20'h0001C;
  localparam [AXI_ADDR_WIDTH-1:0] REG_IRQ_ENABLE     = 20'h00020;
  localparam [AXI_ADDR_WIDTH-1:0] REG_OUT_ACK_DELAY  = 20'h00024;
  localparam [AXI_ADDR_WIDTH-1:0] REG_TX_COUNT_BASE  = 20'h00040;
  localparam [AXI_ADDR_WIDTH-1:0] REG_RX_COUNT_BASE  = 20'h00090;

  localparam [AXI_ADDR_WIDTH-1:0] TX_BASE = 20'h01000;
  localparam [AXI_ADDR_WIDTH-1:0] RX_BASE = 20'h40000;
  localparam [AXI_ADDR_WIDTH-1:0] PORT_STRIDE = 20'h02000;
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
  reg [STR_CHARS*8-1:0] case_file, case_name, case_group, csv_file;

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
  integer debug_on_fail;
  integer debug_max_pkt_seq;
  integer injected_flits;
  integer delivered_flits;
  integer injected_packets;
  integer delivered_packets;
  integer status_timeout_hit;
  integer status_rx_overflow;
  integer diag_fd;
  integer tab_trace_fd;
  integer tab_trace_enable;
  integer tab_trace_port;
  integer tab_trace_pkt;
  reg [2047:0] diag_file;
  reg [2047:0] tab_trace_file;
  reg [2047:0] tab_trace_vcd;
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
      addr32 = TX_BASE + port * PORT_STRIDE + entry * 8 + (hi_word ? 4 : 0);
      tx_addr_word = addr32[AXI_ADDR_WIDTH-1:0];
    end
  endfunction

  function [AXI_ADDR_WIDTH-1:0] rx_addr_word;
    input integer port;
    input integer entry;
    input integer hi_word;
    reg [31:0] addr32;
    begin
      addr32 = RX_BASE + port * PORT_STRIDE + entry * 8 + (hi_word ? 4 : 0);
      rx_addr_word = addr32[AXI_ADDR_WIDTH-1:0];
    end
  endfunction

  task automatic load_xsim_case_cfg;
    integer cfg_fd;
    integer n;
    reg [1023:0] line;
    reg [255:0] tag;
    reg [1023:0] value;
    begin
      cfg_fd = $fopen("noc16_xsim_case.cfg", "r");
      if (cfg_fd != 0) begin
        while (!$feof(cfg_fd)) begin
          line = "";
          if ($fgets(line, cfg_fd) != 0) begin
            tag = "";
            value = "";
            n = $sscanf(line, "%s %s", tag, value);
            if (n == 2) begin
              if (((tag == "CASE") || (tag == "CASE_FILE")) && (case_file == "")) case_file = value;
              else if ((tag == "CSV") && (csv_file == "")) csv_file = value;
              else if (tag == "DEBUG_MAX_PKT_SEQ") n = $sscanf(value, "%d", debug_max_pkt_seq);
            end
          end
        end
        $fclose(cfg_fd);
      end
    end
  endtask

  task automatic load_case;
    integer fd, n, line_no;
    integer cyc, p, pkt_seq, tmp;
    reg [31:0] mask;
    reg [FLIT_W-1:0] flit;
    reg [STR_CHARS*8-1:0] line, tag, name;
    begin
      reset_cycles = 20;
      timeout_cycles = 5000000;
      out_ack_delay_cycles = 0;
      input_count = 0;
      expected_count = 0;
      case_name = "unnamed";
      case_group = "misc";
      case_file = "";
      csv_file = "";
      debug_max_pkt_seq = -1;

      n = $value$plusargs("CASE=%s", case_file);
      if (case_file == "") n = $value$plusargs("CASE_FILE=%s", case_file);
      n = $value$plusargs("CSV=%s", csv_file);
      n = $value$plusargs("ASYNC_NOC16_DEBUG_MAX_PKT_SEQ=%d", debug_max_pkt_seq);
      if ((case_file == "") || (csv_file == "")) load_xsim_case_cfg();
      if (case_file == "") case_file = "testbench/generated_cases/VCTM_16/VCTM-NoMC-1f-r0p02.case";
      if (csv_file == "") csv_file = "summary/noc16_async_axi_summary.csv";

      fd = $fopen(string'(case_file), "r");
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
          end else if (tag == "group") begin
            if ($sscanf(line, "%s %s", tag, name) != 2) begin
              $display("TB_FATAL malformed group at line %0d", line_no);
              $finish;
            end
            case_group = name;
          end else if (tag == "timeout_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) == 2) timeout_cycles = tmp;
          end else if (tag == "reset_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) == 2) reset_cycles = tmp;
          end else if (tag == "out_ack_delay_cycles") begin
            if ($sscanf(line, "%s %d", tag, tmp) == 2) out_ack_delay_cycles = tmp;
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
            if ((debug_max_pkt_seq < 0) || (pkt_seq <= debug_max_pkt_seq)) begin
              input_cycle[input_count] = cyc;
              input_port[input_count] = p;
              input_pkt_seq[input_count] = pkt_seq;
              input_flit[input_count] = flit;
              input_count = input_count + 1;
            end
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
            if ((debug_max_pkt_seq < 0) || (pkt_seq <= debug_max_pkt_seq)) begin
              expected_mask[expected_count] = mask[NUM_PORTS-1:0];
              expected_pkt_seq[expected_count] = pkt_seq;
              expected_is_tail[expected_count] = (tmp == 1);
              expected_flit[expected_count] = flit;
              expected_seen[expected_count] = 1'b0;
              expected_count = expected_count + 1;
            end
          end
        end
      end
      $fclose(fd);
    end
  endtask

  task automatic print_ultra_control_snapshot;
    input [8*16-1:0] router_name;
    input [335:0] word;
    reg [4:0] active, pending, eligible, winner, release_ready, all_tail, busy;
    reg [24:0] masks, tail_seen, tail_event;
    reg [14:0] owners;
    reg [19:0] raw_rs, admitted_rs, ppe, done, tail_passed, req, ack, grant, mg;
    begin
      active = word[4:0]; masks = word[29:5]; owners = word[44:30];
      pending = word[49:45]; eligible = word[54:50]; winner = word[59:55];
      release_ready = word[64:60]; raw_rs = word[84:65]; admitted_rs = word[104:85];
      ppe = word[124:105]; done = word[144:125]; tail_seen = word[169:145];
      all_tail = word[174:170]; tail_event = word[199:175];
      tail_passed = word[219:200]; busy = word[224:220];
      req = word[244:225]; ack = word[264:245]; grant = word[284:265]; mg = word[304:285];
      $display("TB_ULTRA_DEBUG router=%0s active=%b masks=%h owners=%h pending=%b eligible=%b winner=%b release=%b", router_name, active, masks, owners, pending, eligible, winner, release_ready);
      $display("TB_ULTRA_DEBUG router=%0s rawRS=%h admitted=%h req=%h ack=%h done=%h grant=%h mg=%h ppe=%h orphan=%b release_stall=%b admission_wait=%b", router_name, raw_rs, admitted_rs, req, ack, done, grant, mg, ppe, ((active[0] && (ppe[3:0] == 0)) || (active[1] && (ppe[7:4] == 0)) || (active[2] && (ppe[11:8] == 0)) || (active[3] && (ppe[15:12] == 0)) || (active[4] && (ppe[19:16] == 0))), all_tail & active, pending & ~eligible);
      $display("TB_ULTRA_DEBUG router=%0s tailSeen=%h allTail=%b tailEvent=%h tailPassed=%h busy=%b", router_name, tail_seen, all_tail, tail_event, tail_passed, busy);
    end
  endtask

  task automatic print_ultra_control_snapshots;
    begin
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
        if (!aw_done && s_axi_awready) aw_done = 1'b1;
        if (!w_done && s_axi_wready) w_done = 1'b1;
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
        if (s_axi_arready) ar_done = 1'b1;
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

  task automatic init_measurements;
    integer i;
    begin
      injected_packets = 0;
      delivered_packets = 0;
      latency_count = 0;
      for (i = 0; i < MAX_PKT_SEQ; i = i + 1) packet_head_cycle[i] = -1;
      for (i = 0; i < input_count; i = i + 1)
        if (input_flit[i][27]) injected_packets = injected_packets + 1;
    end
  endtask

  // Full checker evidence is deliberately separate from the summary CSV.  In
  // particular, an unexpected flit never terminates the simulation: the
  // wrapper remains the sole owner of the case timeout/completion decision.
  task automatic open_diagnostics;
    begin
      diag_fd = 0;
      if ($value$plusargs("NOC16_DIAG_FILE=%s", diag_file)) begin
        diag_fd = $fopen(diag_file, "w");
        if (diag_fd == 0) begin
          $display("TB_FATAL cannot open NOC16_DIAG_FILE=%0s", diag_file);
          $finish;
        end
        $fdisplay(diag_fd, "# TAB/NoC16 complete checker evidence");
        $fdisplay(diag_fd, "# kind,index,port,cycle,flit,expected_index,expected_mask,pkt_seq,is_tail,expected_flit");
      end
    end
  endtask

  task automatic close_diagnostics;
    begin
      if (diag_fd != 0) begin
        $fdisplay(diag_fd, "SUMMARY,injected=%0d,delivered=%0d,rx=%0d,expected=%0d,missing=%0d,unexpected=%0d,timeout=%0d,overflow=%0d,cycle=%0d",
                  injected_flits, delivered_flits, rx_count, expected_count,
                  missing_flits, unexpected_flits, status_timeout_hit,
                  status_rx_overflow, final_cycle);
        $fclose(diag_fd);
        diag_fd = 0;
      end
    end
  endtask

  task automatic program_wrapper_from_case;
    integer p, i, slot;
    reg [31:0] lo_word;
    reg [31:0] hi_word;
    begin
      axi_write(REG_CTRL, 32'h0000_000C);
      axi_write(REG_TIMEOUT, timeout_cycles);
      axi_write(REG_DRAIN_CYCLES, 32'd1024);
      axi_write(REG_OUT_ACK_DELAY, out_ack_delay_cycles);
      axi_write(REG_IRQ_ENABLE, 32'd0);
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
      axi_write(REG_CTRL, 32'h0000_0001);
      poll_limit = timeout_cycles + 4096;
      while (poll_limit > 0) begin
        axi_read(REG_STATUS, rd_data);
        if (rd_data[1]) poll_limit = 0;
        else poll_limit = poll_limit - 1;
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
          rx_port[rx_count] = hi_word[28:24];
          rx_cycle[rx_count] = hi_word[23:0];
          rx_flit[rx_count] = lo_word[27:0];
          rx_count = rx_count + 1;
        end
      end
      if (rx_count != total_rx_count) begin
        $display("TB_WARN total RX mismatch: register=%0d merged=%0d", total_rx_count, rx_count);
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
          if ((pkt_seq >= 0) && (pkt_seq < MAX_PKT_SEQ) && hi_word[31]) packet_head_cycle[pkt_seq] = hi_word[23:0];
        end
      end
    end
  endtask

  task automatic check_expectations;
    integer i, j;
    integer pkt_seq;
    integer lat;
    integer unexpected_printed;
    integer missing_printed;
    integer matched_index;
    reg found;
    reg [NUM_PORTS-1:0] port_bit;
    begin
      for (i = 0; i < expected_count; i = i + 1) expected_seen[i] = 1'b0;
      unexpected_flits = 0;
      unexpected_printed = 0;
      missing_printed = 0;
      delivered_packets = 0;
      latency_count = 0;
      for (i = 0; i < rx_count; i = i + 1) begin
        if (rx_valid[i] && (rx_port[i] >= 0) && (rx_port[i] < NUM_PORTS)) begin
          found = 1'b0;
          matched_index = -1;
          port_bit = 0;
          port_bit[rx_port[i]] = 1'b1;
          for (j = 0; j < expected_count; j = j + 1) begin
            if (!found && !expected_seen[j] && ((expected_mask[j] & port_bit) != 0) &&
                (expected_flit[j] === rx_flit[i])) begin
              expected_seen[j] = 1'b1;
              found = 1'b1;
              matched_index = j;
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
          if (diag_fd != 0) begin
            if (found) begin
              $fdisplay(diag_fd, "RX_MATCH,%0d,%0d,%0d,%h,%0d,%05h,%0d,%0d,%h",
                        i, rx_port[i], rx_cycle[i], rx_flit[i], matched_index,
                        expected_mask[matched_index], expected_pkt_seq[matched_index],
                        expected_is_tail[matched_index], expected_flit[matched_index]);
            end else begin
              $fdisplay(diag_fd, "RX_UNEXPECTED,%0d,%0d,%0d,%h,-1,00000,-1,-1,0000000",
                        i, rx_port[i], rx_cycle[i], rx_flit[i]);
            end
          end
          if (!found) begin
            unexpected_flits = unexpected_flits + 1;
            if (unexpected_printed < 16) begin
              $display("TB_DEBUG unexpected rx_idx=%0d port=%0d flit=%h cycle=%0d",
                       i, rx_port[i], rx_flit[i], rx_cycle[i]);
              unexpected_printed = unexpected_printed + 1;
            end
          end
        end
      end
      missing_flits = 0;
      for (i = 0; i < expected_count; i = i + 1) begin
        if (!expected_seen[i]) begin
          missing_flits = missing_flits + 1;
          if (diag_fd != 0) begin
            $fdisplay(diag_fd, "EXP_MISSING,-1,-1,-1,0000000,%0d,%05h,%0d,%0d,%h",
                      i, expected_mask[i], expected_pkt_seq[i],
                      expected_is_tail[i], expected_flit[i]);
          end
          if (missing_printed < 16) begin
            $display("TB_DEBUG missing exp_idx=%0d mask=%05h pkt_seq=%0d tail=%0d flit=%h",
                     i, expected_mask[i], expected_pkt_seq[i],
                     expected_is_tail[i], expected_flit[i]);
            missing_printed = missing_printed + 1;
          end
        end
      end
    end
  endtask

  task automatic write_csv_and_finish;
    integer i, j, t;
    integer dbg_p;
    integer lat_sum, max_lat, rank95, rank99, p95_lat, p99_lat;
    integer fd_csv;
    integer csv_pos;
    reg write_header;
    reg pass_ok;
    reg [31:0] pass_text;
    real avg_lat, avg_lat_ns, max_lat_ns, p95_lat_ns, p99_lat_ns, throughput;
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
      pass_ok = (missing_flits == 0) && (unexpected_flits == 0) &&
                (status_timeout_hit == 0) && (status_rx_overflow == 0) &&
                (injected_flits == input_count);
      pass_text = pass_ok ? "PASS" : "FAIL";
      fd_csv = $fopen(string'(csv_file), "a+");
      if (fd_csv == 0) begin
        $display("TB_FATAL cannot open CSV file: %0s", csv_file);
        $finish;
      end
      csv_pos = $fseek(fd_csv, 0, 2);
      csv_pos = $ftell(fd_csv);
      write_header = (csv_pos == 0);
      if (write_header) begin
        $fwrite(fd_csv, "group,case_name,injected_packets,delivered_packets,injected_flits,delivered_flits,missing_expected_flits,unexpected_flits,timeout_hit,rx_overflow,measure_cycles,delivered_throughput,avg_packet_latency_ns,max_packet_latency_ns,p95_latency_ns,p99_latency_ns,pass_fail\n");
      end
      $fwrite(fd_csv, "%0s,%0s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.6f,%0.3f,%0.3f,%0.3f,%0.3f,%0s\n",
              case_group, case_name, injected_packets, delivered_packets, injected_flits, delivered_flits,
              missing_flits, unexpected_flits, status_timeout_hit, status_rx_overflow, final_cycle,
              throughput, avg_lat_ns, max_lat_ns, p95_lat_ns, p99_lat_ns, pass_text);
      $fclose(fd_csv);
      $display("TB_RESULT %0s group=%0s case=%0s injected_flits=%0d delivered_flits=%0d delivered_packets=%0d avg_lat_ns=%0.3f p95_ns=%0.3f p99_ns=%0.3f missing=%0d unexpected=%0d timeout=%0d rx_overflow=%0d",
               pass_text, case_group, case_name, injected_flits, delivered_flits, delivered_packets,
               avg_lat_ns, p95_lat_ns, p99_lat_ns, missing_flits, unexpected_flits,
               status_timeout_hit, status_rx_overflow);
      if (diag_fd != 0) begin
        for (dbg_p = 0; dbg_p < NUM_PORTS; dbg_p = dbg_p + 1) begin
          $fdisplay(diag_fd, "PORT_FINAL,%0d,tx_cursor=%0d,tx_count=%0d,in_pending=%0b,in_req=%0b,in_ack=%0b,rx_count=%0d,out_req=%0b,out_ack=%0b",
                    dbg_p, dut.tx_cursor[dbg_p], dut.cfg_tx_count[dbg_p],
                    dut.in_pending[dbg_p], dut.in_req[dbg_p], dut.in_ack[dbg_p],
                    dut.rx_count_port[dbg_p], dut.out_req[dbg_p], dut.out_ack[dbg_p]);
        end
      end
      if (!pass_ok && debug_on_fail) begin
        for (dbg_p = 0; dbg_p < NUM_PORTS; dbg_p = dbg_p + 1) begin
          if ((dut.cfg_tx_count[dbg_p] != 0) || (dut.rx_count_port[dbg_p] != 0)) begin
            $display("TB_DEBUG port_state port=%0d tx_cursor=%0d tx_count=%0d in_pending=%0b in_req=%0b in_ack=%0b rx_count=%0d out_req=%0b out_ack=%0b",
                     dbg_p, dut.tx_cursor[dbg_p], dut.cfg_tx_count[dbg_p],
                     dut.in_pending[dbg_p], dut.in_req[dbg_p], dut.in_ack[dbg_p],
                     dut.rx_count_port[dbg_p], dut.out_req[dbg_p], dut.out_ack[dbg_p]);
          end
        end
        print_ultra_control_snapshots();
`ifdef ASYNC_NOC16_STAGE1_DEBUG_PORTS
        $display("TB_DEBUG r1[0] inV=%b outV=%b ctx=%b win=%b com=%b req={%b,%b,%b,%b,%b} hold={%0d,%0d,%0d,%0d,%0d}",
                 dut.dut.io_debug_l1InputValid_0, dut.dut.io_debug_l1OutputValid_0,
                 dut.dut.io_debug_l1ContextActive_0, dut.dut.io_debug_l1Winner_0,
                 dut.dut.io_debug_l1Commit_0,
                 dut.dut.io_debug_l1RequestMask_0_4, dut.dut.io_debug_l1RequestMask_0_3,
                 dut.dut.io_debug_l1RequestMask_0_2, dut.dut.io_debug_l1RequestMask_0_1,
                 dut.dut.io_debug_l1RequestMask_0_0,
                 dut.dut.io_debug_l1OutputHolder_0_4, dut.dut.io_debug_l1OutputHolder_0_3,
                 dut.dut.io_debug_l1OutputHolder_0_2, dut.dut.io_debug_l1OutputHolder_0_1,
                 dut.dut.io_debug_l1OutputHolder_0_0);
        $display("TB_DEBUG r1[1] inV=%b outV=%b ctx=%b win=%b com=%b req={%b,%b,%b,%b,%b} hold={%0d,%0d,%0d,%0d,%0d}",
                 dut.dut.io_debug_l1InputValid_1, dut.dut.io_debug_l1OutputValid_1,
                 dut.dut.io_debug_l1ContextActive_1, dut.dut.io_debug_l1Winner_1,
                 dut.dut.io_debug_l1Commit_1,
                 dut.dut.io_debug_l1RequestMask_1_4, dut.dut.io_debug_l1RequestMask_1_3,
                 dut.dut.io_debug_l1RequestMask_1_2, dut.dut.io_debug_l1RequestMask_1_1,
                 dut.dut.io_debug_l1RequestMask_1_0,
                 dut.dut.io_debug_l1OutputHolder_1_4, dut.dut.io_debug_l1OutputHolder_1_3,
                 dut.dut.io_debug_l1OutputHolder_1_2, dut.dut.io_debug_l1OutputHolder_1_1,
                 dut.dut.io_debug_l1OutputHolder_1_0);
        $display("TB_DEBUG r1[2] inV=%b outV=%b ctx=%b win=%b com=%b req={%b,%b,%b,%b,%b} hold={%0d,%0d,%0d,%0d,%0d}",
                 dut.dut.io_debug_l1InputValid_2, dut.dut.io_debug_l1OutputValid_2,
                 dut.dut.io_debug_l1ContextActive_2, dut.dut.io_debug_l1Winner_2,
                 dut.dut.io_debug_l1Commit_2,
                 dut.dut.io_debug_l1RequestMask_2_4, dut.dut.io_debug_l1RequestMask_2_3,
                 dut.dut.io_debug_l1RequestMask_2_2, dut.dut.io_debug_l1RequestMask_2_1,
                 dut.dut.io_debug_l1RequestMask_2_0,
                 dut.dut.io_debug_l1OutputHolder_2_4, dut.dut.io_debug_l1OutputHolder_2_3,
                 dut.dut.io_debug_l1OutputHolder_2_2, dut.dut.io_debug_l1OutputHolder_2_1,
                 dut.dut.io_debug_l1OutputHolder_2_0);
        $display("TB_DEBUG r1[3] inV=%b outV=%b ctx=%b win=%b com=%b req={%b,%b,%b,%b,%b} hold={%0d,%0d,%0d,%0d,%0d}",
                 dut.dut.io_debug_l1InputValid_3, dut.dut.io_debug_l1OutputValid_3,
                 dut.dut.io_debug_l1ContextActive_3, dut.dut.io_debug_l1Winner_3,
                 dut.dut.io_debug_l1Commit_3,
                 dut.dut.io_debug_l1RequestMask_3_4, dut.dut.io_debug_l1RequestMask_3_3,
                 dut.dut.io_debug_l1RequestMask_3_2, dut.dut.io_debug_l1RequestMask_3_1,
                 dut.dut.io_debug_l1RequestMask_3_0,
                 dut.dut.io_debug_l1OutputHolder_3_4, dut.dut.io_debug_l1OutputHolder_3_3,
                 dut.dut.io_debug_l1OutputHolder_3_2, dut.dut.io_debug_l1OutputHolder_3_1,
                 dut.dut.io_debug_l1OutputHolder_3_0);
        $display("TB_DEBUG r2 inV=%b outV=%b ctx=%b win=%b com=%b req={%b,%b,%b,%b,%b} hold={%0d,%0d,%0d,%0d,%0d}",
                 dut.dut.io_debug_l2InputValid, dut.dut.io_debug_l2OutputValid,
                 dut.dut.io_debug_l2ContextActive, dut.dut.io_debug_l2Winner,
                 dut.dut.io_debug_l2Commit,
                 dut.dut.io_debug_l2RequestMask_4, dut.dut.io_debug_l2RequestMask_3,
                 dut.dut.io_debug_l2RequestMask_2, dut.dut.io_debug_l2RequestMask_1,
                 dut.dut.io_debug_l2RequestMask_0,
                 dut.dut.io_debug_l2OutputHolder_4, dut.dut.io_debug_l2OutputHolder_3,
                 dut.dut.io_debug_l2OutputHolder_2, dut.dut.io_debug_l2OutputHolder_1,
                 dut.dut.io_debug_l2OutputHolder_0);
`endif
      end
      close_diagnostics();
`ifdef ASYNC_NOC16_ULTRA_TRACE
      if (tab_trace_fd != 0) begin
        tab_trace_snapshot("TRACE_END");
        $fclose(tab_trace_fd);
        tab_trace_fd = 0;
      end
`endif
      $finish;
    end
  endtask

`ifdef ASYNC_NOC16_ULTRA_TRACE
  // Packet 19 is core2 -> core6.  In the generated NoC topology this is a
  // local L1 transfer (routerL1_1_0: child3 -> child2), not an L2 transfer.
  // These aliases intentionally observe only the physical signals; they do
  // not participate in source or receiver control.
  wire [27:0] tab_l1_datax = dut.dut.routerL1_1_0.inputModules_3.io_DataX_flit;
  wire        tab_l1_req = dut.dut.routerL1_1_0.outputModules_2.io_Req_2;
  wire        tab_l1_ppe = dut.dut.routerL1_1_0.outputModules_2.io_PPE_2;
  wire        tab_l1_mg = dut.dut.routerL1_1_0.outputModules_2.io_MG_2;
  wire [3:0]  tab_v2_mg = {dut.dut.routerL1_1_0.outputModules_2.io_MG_3,
                            dut.dut.routerL1_1_0.outputModules_2.io_MG_2,
                            dut.dut.routerL1_1_0.outputModules_2.io_MG_1,
                            dut.dut.routerL1_1_0.outputModules_2.io_MG_0};
  wire [27:0] tab_v2_datax0 = dut.dut.routerL1_1_0.outputModules_2.io_DataX_0_flit;
  wire [27:0] tab_v2_datax1 = dut.dut.routerL1_1_0.outputModules_2.io_DataX_1_flit;
  wire [27:0] tab_v2_datax2 = dut.dut.routerL1_1_0.outputModules_2.io_DataX_2_flit;
  wire [27:0] tab_v2_datax3 = dut.dut.routerL1_1_0.outputModules_2.io_DataX_3_flit;
  // The failing pair at this OPM is local source2=input3/Child3(core2),
  // branch2, and local source3=input4/Parent, branch2.  Everything below is
  // observation only: it never feeds a wrapper or DUT control signal.
  wire        tab_ppe2 = dut.dut.routerL1_1_0.requestBanks_3.io_PPE_2;
  wire        tab_ppe3 = dut.dut.routerL1_1_0.requestBanks_4.io_PPE_2;
  wire        tab_req2 = dut.dut.routerL1_1_0.requestBanks_3.io_Req_2;
  wire        tab_req3 = dut.dut.routerL1_1_0.requestBanks_4.io_Req_2;
  wire        tab_done2 = dut.dut.routerL1_1_0.requestBanks_3.io_Done_2;
  wire        tab_done3 = dut.dut.routerL1_1_0.requestBanks_4.io_Done_2;
  wire        tab_ack2 = dut.dut.routerL1_1_0.outputModules_2.io_Ack_2;
  wire        tab_ack3 = dut.dut.routerL1_1_0.outputModules_2.io_Ack_3;
  wire        tab_grant2 = dut.dut.routerL1_1_0.outputModules_2.io_Grant_2;
  wire        tab_grant3 = dut.dut.routerL1_1_0.outputModules_2.io_Grant_3;
  wire        tab_reqx2 = dut.dut.routerL1_1_0.inputModules_3.io_ReqX;
  wire        tab_reqx3 = dut.dut.routerL1_1_0.inputModules_4.io_ReqX;
  wire [3:0]  tab_rawrs2 = {dut.dut.routerL1_1_0.inputModules_3.io_RS_3,
                             dut.dut.routerL1_1_0.inputModules_3.io_RS_2,
                             dut.dut.routerL1_1_0.inputModules_3.io_RS_1,
                             dut.dut.routerL1_1_0.inputModules_3.io_RS_0};
  wire [3:0]  tab_rawrs3 = {dut.dut.routerL1_1_0.inputModules_4.io_RS_3,
                             dut.dut.routerL1_1_0.inputModules_4.io_RS_2,
                             dut.dut.routerL1_1_0.inputModules_4.io_RS_1,
                             dut.dut.routerL1_1_0.inputModules_4.io_RS_0};
  wire        tab_admit2 = dut.dut.routerL1_1_0.admission.io_admittedRS_3_2;
  wire        tab_admit3 = dut.dut.routerL1_1_0.admission.io_admittedRS_4_2;
  wire [4:0]  tab_active = {dut.dut.routerL1_1_0.admission.io_packetActive_4,
                             dut.dut.routerL1_1_0.admission.io_packetActive_3,
                             dut.dut.routerL1_1_0.admission.io_packetActive_2,
                             dut.dut.routerL1_1_0.admission.io_packetActive_1,
                             dut.dut.routerL1_1_0.admission.io_packetActive_0};
  wire [4:0]  tab_mask2 = dut.dut.routerL1_1_0.admission.io_packetMask_3;
  wire [4:0]  tab_mask3 = dut.dut.routerL1_1_0.admission.io_packetMask_4;
  wire [2:0]  tab_owner2 = dut.dut.routerL1_1_0.admission.io_outputOwner_2;
  wire        tab_fire = dut.dut.routerL1_1_0.admission.commitController_fire_o;
  wire        tab_tx_valid = dut.dut.routerL1_1_0.admission.tx_tx_valid;
  wire        tab_tx_release = dut.dut.routerL1_1_0.admission.tx_tx_release;
  wire [4:0]  tab_tx_winner = dut.dut.routerL1_1_0.admission.tx_tx_winner;
  wire [4:0]  tab_tx_mask2 = dut.dut.routerL1_1_0.admission.tx_tx_mask3;
  wire [4:0]  tab_tx_mask3 = dut.dut.routerL1_1_0.admission.tx_tx_mask4;
`ifdef ASYNC_NOC16_ULTRA_TRACE_POST
  // Post-DC keeps the HeadCapture P vector as the split tx input bus.
  wire [4:0]  tab_present = {dut.dut.routerL1_1_0.admission.tx_io_packet_present_hi,
                             dut.dut.routerL1_1_0.admission.tx_io_packet_present_lo};
  wire        tab_release_commit4 = dut.dut.routerL1_1_0.admission.capture_4_release_commit;
`else
  wire [4:0]  tab_present = dut.dut.routerL1_1_0.admission.tx_packet_present;
  wire        tab_release_commit4 = dut.dut.routerL1_1_0.admission.capture_4_release_commit;
`endif
  wire [4:0]  tab_anchor_grant = dut.dut.routerL1_1_0.admission.tx.anchor_grant;
  wire [4:0]  tab_arb_req = dut.dut.routerL1_1_0.admission.tx.arb_req;
  wire        tab_round_busy = dut.dut.routerL1_1_0.admission.tx.round_busy;
  wire        tab_round_close = dut.dut.routerL1_1_0.admission.tx.round_close;
  wire [3:0]  tab_seen = {dut.dut.routerL1_1_0.admission.tx.seen4,
                           dut.dut.routerL1_1_0.admission.tx.seen3,
                           dut.dut.routerL1_1_0.admission.tx.seen2,
                           dut.dut.routerL1_1_0.admission.tx.seen1};
  wire [3:0]  tab_close_ready = {dut.dut.routerL1_1_0.admission.tx.close_ready4,
                                  dut.dut.routerL1_1_0.admission.tx.close_ready3,
                                  dut.dut.routerL1_1_0.admission.tx.close_ready2,
                                  dut.dut.routerL1_1_0.admission.tx.close_ready1};
`ifdef ASYNC_NOC16_ULTRA_TRACE_POST
  // Current post-DC OutputPortModule_12: DC retains D/close but maps both
  // V2 latch Qs to their module outputs and shares physical enable n70.
  wire [27:0] tab_v2_data_d = dut.dut.routerL1_1_0.outputModules_2.dataOutLatch_d;
  wire        tab_v2_data_e = dut.dut.routerL1_1_0.outputModules_2.n70;
  wire [27:0] tab_v2_data_q = dut.dut.routerL1_1_0.outputModules_2.io_DataOut_flit;
  wire        tab_v2_req_d = dut.dut.routerL1_1_0.outputModules_2.v2RequestMargin_Z;
  wire        tab_v2_req_e = dut.dut.routerL1_1_0.outputModules_2.n70;
  wire        tab_v2_req_q = dut.dut.routerL1_1_0.outputModules_2.io_ReqOut;
  wire        tab_v2_close = dut.dut.routerL1_1_0.outputModules_2.closeEvent_close_clock;
`else
  wire [27:0] tab_v2_data_d = dut.dut.routerL1_1_0.outputModules_2.dataOutLatch_d;
  wire        tab_v2_data_e = dut.dut.routerL1_1_0.outputModules_2.dataOutLatch_en;
  wire [27:0] tab_v2_data_q = dut.dut.routerL1_1_0.outputModules_2.dataOutLatch_q;
  wire        tab_v2_req_d = dut.dut.routerL1_1_0.outputModules_2.requestOutLatch_d;
  wire        tab_v2_req_e = dut.dut.routerL1_1_0.outputModules_2.requestOutLatch_en;
  wire        tab_v2_req_q = dut.dut.routerL1_1_0.outputModules_2.requestOutLatch_q;
  wire        tab_v2_close = dut.dut.routerL1_1_0.outputModules_2.closeEvent_close_clock;
`endif
  wire        tab_v2_ack = dut.dut.routerL1_1_0.outputModules_2.io_Ack_2;
  wire        tab_port6_req = dut.out_req[6];
  wire        tab_port6_ack = dut.out_ack[6];
  wire [27:0] tab_port6_data = dut.out_data[6*28 +: 28];

  reg tab_seen_admit2, tab_seen_admit3;
  reg tab_reported_ppe_double, tab_reported_mg_double;
  reg tab_reported_active_overlap, tab_reported_tx_overlap, tab_reported_active_present_mismatch;

  function automatic tab_tx_pair_overlap;
    input [4:0] winner;
    input [4:0] mask_i;
    input [4:0] mask_j;
    input integer i;
    input integer j;
    begin
      tab_tx_pair_overlap = winner[i] && winner[j] && (|(mask_i & mask_j));
    end
  endfunction

  wire tab_active_overlap_23 = tab_active[3] && tab_active[4] && (|(tab_mask2 & tab_mask3));
  wire tab_tx_overlap_23 = tab_tx_pair_overlap(tab_tx_winner, tab_tx_mask2, tab_tx_mask3, 3, 4);

  task automatic tab_trace_snapshot;
    input [8*24-1:0] tag;
    begin
      if (tab_trace_enable && (tab_trace_fd != 0)) begin
        $fdisplay(tab_trace_fd,
          "TRACE t=%0t cycle=%0d tag=%0s datax=%h req=%b ppe=%b mg=%b allMG=%b datax0=%h datax1=%h datax2=%h datax3=%h v2D=%h v2E=%b v2Q=%h l5D=%b l5E=%b l5Q=%b close=%b ack=%b outReq=%b outAck=%b outData=%h bits27_26={%b,%b} | I3(rawRS=%b ReqX=%b admit=%b Req=%b Ack=%b Done=%b PPE=%b Grant=%b MG=%b) I4(rawRS=%b ReqX=%b admit=%b Req=%b Ack=%b Done=%b PPE=%b Grant=%b MG=%b) | P=%b relC4=%b active=%b maskI3=%b maskI4=%b ownerO2=%0d arbReq=%b anchor=%b busy=%b close=%b seen=%b ready=%b txValid=%b txRel=%b txWin=%b txM3=%b txM4=%b fire=%b",
          $time, dut.cycle_counter, tag, tab_l1_datax, tab_l1_req,
          tab_l1_ppe, tab_l1_mg, tab_v2_mg, tab_v2_datax0, tab_v2_datax1,
          tab_v2_datax2, tab_v2_datax3, tab_v2_data_d, tab_v2_data_e,
          tab_v2_data_q, tab_v2_req_d, tab_v2_req_e, tab_v2_req_q,
          tab_v2_close, tab_v2_ack, tab_port6_req, tab_port6_ack,
          tab_port6_data, tab_v2_data_q[27], tab_v2_data_q[26],
          tab_rawrs2, tab_reqx2, tab_admit2, tab_req2, tab_ack2, tab_done2,
          tab_ppe2, tab_grant2, tab_v2_mg[2], tab_rawrs3, tab_reqx3,
          tab_admit3, tab_req3, tab_ack3, tab_done3, tab_ppe3, tab_grant3,
          tab_v2_mg[3], tab_present, tab_release_commit4, tab_active, tab_mask2, tab_mask3, tab_owner2,
          tab_arb_req, tab_anchor_grant, tab_round_busy, tab_round_close,
          tab_seen, tab_close_ready, tab_tx_valid, tab_tx_release,
          tab_tx_winner, tab_tx_mask2, tab_tx_mask3, tab_fire);
      end
    end
  endtask

  initial begin
    tab_trace_enable = 0;
    tab_trace_port = -1;
    tab_trace_pkt = -1;
    tab_trace_fd = 0;
    tab_seen_admit2 = 0;
    tab_seen_admit3 = 0;
    tab_reported_ppe_double = 0;
    tab_reported_mg_double = 0;
    tab_reported_active_overlap = 0;
    tab_reported_tx_overlap = 0;
    tab_reported_active_present_mismatch = 0;
    if ($value$plusargs("TAB_TRACE_PORT=%d", tab_trace_port)) tab_trace_enable = 1;
    if ($value$plusargs("TAB_TRACE_PKT=%d", tab_trace_pkt)) tab_trace_enable = 1;
    // The original packet19/core2->core6 trace remains available as a
    // historical diagnosis harness.  Packet89 uses the dedicated, narrower
    // source-path trace below; do not open the legacy all-activity logger.
    if (tab_trace_enable && (tab_trace_pkt == 19)) begin
      if (tab_trace_port != 6) begin
        $display("TB_WARN TAB trace is currently wired for port6; requested port=%0d", tab_trace_port);
      end
      if (!$value$plusargs("TAB_TRACE_FILE=%s", tab_trace_file)) begin
        tab_trace_file = "tab_port6_packet19_trace.log";
      end
      tab_trace_fd = $fopen(tab_trace_file, "w");
      if (tab_trace_fd == 0) begin
        $display("TB_FATAL cannot open TAB_TRACE_FILE=%0s", tab_trace_file);
        $finish;
      end
      $fdisplay(tab_trace_fd, "# trace core2->core6 packet=%0d; local routerL1_1_0 child3->child2", tab_trace_pkt);
      if ($value$plusargs("TAB_TRACE_VCD=%s", tab_trace_vcd)) begin
        $dumpfile(tab_trace_vcd);
      $dumpvars(0, tab_l1_datax, tab_l1_req, tab_l1_ppe, tab_l1_mg,
                  tab_v2_mg, tab_v2_datax0, tab_v2_datax1, tab_v2_datax2, tab_v2_datax3,
                  tab_v2_data_d, tab_v2_data_e, tab_v2_data_q,
                  tab_v2_req_d, tab_v2_req_e, tab_v2_req_q, tab_v2_close,
                  tab_v2_ack, tab_port6_req, tab_port6_ack, tab_port6_data,
                  tab_rawrs2, tab_rawrs3, tab_admit2, tab_admit3,
                  tab_req2, tab_req3, tab_done2, tab_done3, tab_ppe2, tab_ppe3,
                  tab_active, tab_mask2, tab_mask3, tab_owner2, tab_arb_req,
                  tab_anchor_grant, tab_round_busy, tab_round_close, tab_seen,
                  tab_close_ready, tab_tx_valid, tab_tx_release, tab_tx_winner,
                  tab_tx_mask2, tab_tx_mask3, tab_present, tab_release_commit4, tab_fire);
      end
      tab_trace_snapshot("TRACE_START");
    end
  end

  always @(tab_l1_datax) tab_trace_snapshot("L1_DATAX");
  always @(tab_l1_req or tab_l1_ppe or tab_l1_mg) tab_trace_snapshot("L1_CTRL");
  always @(tab_v2_mg or tab_v2_datax0 or tab_v2_datax1 or tab_v2_datax2 or tab_v2_datax3)
    tab_trace_snapshot("V2_SOURCES");
  always @(tab_v2_data_d) tab_trace_snapshot("V2_DATA_D");
  always @(tab_v2_data_e) tab_trace_snapshot("V2_DATA_E");
  always @(tab_v2_data_q) tab_trace_snapshot("V2_DATA_Q");
  always @(tab_v2_req_d or tab_v2_req_e or tab_v2_req_q) tab_trace_snapshot("V2_REQ");
  always @(tab_v2_close) tab_trace_snapshot("V2_CLOSE");
  always @(tab_v2_ack) tab_trace_snapshot("V2_ACK");
  always @(tab_port6_req or tab_port6_ack or tab_port6_data) tab_trace_snapshot("PORT6");
  // These are the reservation-state edges needed to determine whether a
  // release/commit has separated packetActive from its output ownership.
  always @(tab_active or tab_mask2 or tab_mask3 or tab_owner2 or tab_present or tab_release_commit4)
    tab_trace_snapshot("ATOMIC_STATE");
  always @(tab_fire or tab_tx_valid or tab_tx_release or tab_tx_winner or
           tab_tx_mask2 or tab_tx_mask3)
    tab_trace_snapshot("ATOMIC_COMMIT");
  always @(tab_arb_req or tab_anchor_grant or tab_round_busy or tab_round_close or
           tab_seen or tab_close_ready)
    tab_trace_snapshot("ATOMIC_ROUND");
  always @(tab_admit2) if (tab_admit2) begin tab_seen_admit2 = 1'b1; tab_trace_snapshot("I3_ADMIT"); end
  always @(tab_admit3) if (tab_admit3) begin tab_seen_admit3 = 1'b1; tab_trace_snapshot("I4_ADMIT"); end
  always @(posedge tab_ppe2) begin
    tab_trace_snapshot("I3_PPE_RISE");
    if (!tab_seen_admit2) $fdisplay(tab_trace_fd, "ASSERT t=%0t PPE_I3_RISE_WITHOUT_PRIOR_ADMIT", $time);
  end
  always @(posedge tab_ppe3) begin
    tab_trace_snapshot("I4_PPE_RISE");
    if (!tab_seen_admit3) $fdisplay(tab_trace_fd, "ASSERT t=%0t PPE_I4_RISE_WITHOUT_PRIOR_ADMIT", $time);
  end
  always @(tab_ppe2 or tab_ppe3) if ((tab_ppe2 && tab_ppe3) && !tab_reported_ppe_double) begin
    tab_reported_ppe_double = 1'b1; tab_trace_snapshot("ASSERT_PPE_DOUBLE");
  end
  always @(tab_v2_mg) if ((tab_v2_mg[2] && tab_v2_mg[3]) && !tab_reported_mg_double) begin
    tab_reported_mg_double = 1'b1; tab_trace_snapshot("ASSERT_MG_DOUBLE");
  end
  always @(tab_active or tab_mask2 or tab_mask3) if (tab_active_overlap_23 && !tab_reported_active_overlap) begin
    tab_reported_active_overlap = 1'b1; tab_trace_snapshot("ASSERT_ACTIVE_OVERLAP_34");
  end
  always @(tab_active or tab_present) if (tab_active[4] && !tab_present[4] && !tab_reported_active_present_mismatch) begin
    tab_reported_active_present_mismatch = 1'b1; tab_trace_snapshot("ASSERT_ACTIVE4_WITHOUT_PRESENT4");
  end
  always @(tab_tx_winner or tab_tx_mask2 or tab_tx_mask3) if (tab_tx_overlap_23 && !tab_reported_tx_overlap) begin
    tab_reported_tx_overlap = 1'b1; tab_trace_snapshot("ASSERT_TX_OVERLAP_34");
  end

  // TAB r0p10 packet89: core6 -> core1.  Core6 is Child2 of L1(1,0), so
  // the source path is input2/branch3 -> parent OPM source2.  This is a
  // read-only, packet-specific control trace: no alias below feeds the DUT,
  // wrapper injection, or receiver Ack.
  wire        p89_in_req = dut.in_req[6];
  wire        p89_in_ack = dut.in_ack[6];
  wire [27:0] p89_in_data = dut.in_data[6*28 +: 28];
  wire        p89_reqx = dut.dut.routerL1_1_0.inputModules_2.io_ReqX;
  wire [27:0] p89_datax = dut.dut.routerL1_1_0.inputModules_2.io_DataX_flit;
  wire [3:0]  p89_raw_rs = {dut.dut.routerL1_1_0.inputModules_2.io_RS_3,
                            dut.dut.routerL1_1_0.inputModules_2.io_RS_2,
                            dut.dut.routerL1_1_0.inputModules_2.io_RS_1,
                            dut.dut.routerL1_1_0.inputModules_2.io_RS_0};
  wire        p89_ackx = dut.dut.routerL1_1_0.inputModules_2.ackGenerator.io_AckX;
  wire        p89_prs_ready = dut.dut.routerL1_1_0.inputModules_2.prs.io_PRSReady;
  wire        p89_v1_latch_en = dut.dut.routerL1_1_0.inputModules_2.mousetrap.latch_en;
  wire        p89_is_tail = dut.dut.routerL1_1_0.inputModules_2.mousetrap.DataOut[26];
  wire        p89_admitted = dut.dut.routerL1_1_0.admission.io_admittedRS_2_3;
  wire        p89_done = dut.dut.routerL1_1_0.requestBanks_2.io_Done_3;
  wire        p89_req = dut.dut.routerL1_1_0.requestBanks_2.io_Req_3;
  wire        p89_ppe = dut.dut.routerL1_1_0.requestBanks_2.io_PPE_3;
  wire        p89_ack = dut.dut.routerL1_1_0.outputModules_4.io_Ack_2;
  wire        p89_grant = dut.dut.routerL1_1_0.outputModules_4.io_Grant_2;
  wire        p89_mg = dut.dut.routerL1_1_0.outputModules_4.io_MG_2;
  wire        p89_tail_passed = dut.dut.routerL1_1_0.outputModules_4.io_TailPassed_2;
  wire        p89_opm_req = dut.dut.routerL1_1_0.outputModules_4.io_ReqOut;
  wire        p89_opm_ack = dut.dut.routerL1_1_0.outputModules_4.io_AckOut;
  wire [27:0] p89_opm_data = dut.dut.routerL1_1_0.outputModules_4.io_DataOut_flit;
  // L1(1,0) is connected to L2 child1 through upwardLinkFifos_1.  These
  // six pins discriminate a blocked parent OPM from a full/stalled FIFO.
  wire        p89_fifo_enq_req = dut.dut.upwardLinkFifos_1.io_enq_HS_Req;
  wire        p89_fifo_enq_ack = dut.dut.upwardLinkFifos_1.io_enq_HS_Ack;
  wire [27:0] p89_fifo_enq_data = dut.dut.upwardLinkFifos_1.io_enq_Data_flit;
  wire        p89_fifo_deq_req = dut.dut.upwardLinkFifos_1.io_deq_HS_Req;
  wire        p89_fifo_deq_ack = dut.dut.upwardLinkFifos_1.io_deq_HS_Ack;
  wire [27:0] p89_fifo_deq_data = dut.dut.upwardLinkFifos_1.io_deq_Data_flit;
  // The FIFO dequeue feeds L2 child1.  For core1 the L2 route is input1,
  // branch2, output3/source1, followed by downwardLinkFifos_3.
  wire        p89_l2_reqx = dut.dut.routerL2.inputModules_1.io_ReqX;
  wire        p89_l2_ackx = dut.dut.routerL2.inputModules_1.ackGenerator.io_AckX;
  wire [3:0]  p89_l2_all_done = dut.dut.routerL2.inputModules_1.ackGenerator.io_Done;
  wire        p89_l2_v1_latch_en = dut.dut.routerL2.inputModules_1.mousetrap.latch_en;
  wire        p89_l2_is_tail = dut.dut.routerL2.inputModules_1.mousetrap.DataOut[26];
  wire        p89_l2_prs_ready = dut.dut.routerL2.inputModules_1.prs.io_PRSReady;
  wire [3:0]  p89_l2_raw_rs = {dut.dut.routerL2.inputModules_1.io_RS_3,
                               dut.dut.routerL2.inputModules_1.io_RS_2,
                               dut.dut.routerL2.inputModules_1.io_RS_1,
                               dut.dut.routerL2.inputModules_1.io_RS_0};
  wire        p89_l2_admitted = dut.dut.routerL2.admission.io_admittedRS_1_2;
  wire        p89_l2_done = dut.dut.routerL2.requestBanks_1.io_Done_2;
  wire        p89_l2_req = dut.dut.routerL2.requestBanks_1.io_Req_2;
  wire        p89_l2_ppe = dut.dut.routerL2.requestBanks_1.io_PPE_2;
  wire        p89_l2_ack = dut.dut.routerL2.outputModules_3.io_Ack_1;
  wire        p89_l2_grant = dut.dut.routerL2.outputModules_3.io_Grant_1;
  wire        p89_l2_mg = dut.dut.routerL2.outputModules_3.io_MG_1;
  wire        p89_l2_opm_req = dut.dut.routerL2.outputModules_3.io_ReqOut;
  wire        p89_l2_opm_ack = dut.dut.routerL2.outputModules_3.io_AckOut;
  wire [27:0] p89_l2_opm_data = dut.dut.routerL2.outputModules_3.io_DataOut_flit;
  wire        p89_down_enq_req = dut.dut.downwardLinkFifos_3.io_enq_HS_Req;
  wire        p89_down_enq_ack = dut.dut.downwardLinkFifos_3.io_enq_HS_Ack;
  wire        p89_down_deq_req = dut.dut.downwardLinkFifos_3.io_deq_HS_Req;
  wire        p89_down_deq_ack = dut.dut.downwardLinkFifos_3.io_deq_HS_Ack;
  wire        p89_l2_all_tail = dut.dut.routerL2.tailJoin.io_allTailPassed_1;
  wire        p89_l2_tail_ready = dut.dut.routerL2.admission.io_tailReleaseReady_1;
  wire        p89_l2_active = dut.dut.routerL2.admission.io_packetActive_1;
  wire [4:0]  p89_l2_mask = dut.dut.routerL2.admission.io_packetMask_1;
  // V2 release-lifecycle evidence.  These are simulation-only hierarchical
  // reads of retained state-cell ports; they do not participate in DUT logic.
  wire        p89_l2_present = dut.dut.routerL2.admission.capture_1.packet_present;
  wire        p89_l2_present_q = dut.dut.routerL2.admission.capture_1.present_latch.q;
  wire        p89_l2_release_commit = dut.dut.routerL2.admission.capture_1.release_commit;
  wire        p89_l2_round_busy = dut.dut.routerL2.admission.tx.busy_latch.q;
  wire        p89_l2_commit_seen = dut.dut.routerL2.admission.tx.commit_seen_latch.q;
  wire        p89_l2_round_reset = dut.dut.routerL2.admission.tx.return_margin.Z;
  wire [4:0]  p89_l2_anchor_grant = dut.dut.routerL2.admission.tx.anchor_mutex.grant;
  wire [4:0]  p89_l2_anchor_req = dut.dut.routerL2.admission.tx.anchor_mutex.req;
  wire        p89_l2_tac_a_req_up = dut.dut.routerL2.admission.tx.anchor_mutex.tac_a.req_up;
  wire        p89_l2_tac_a_arbo0 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_a.arbo0;
  wire        p89_l2_tac_a_arbo1 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_a.arbo1;
  wire        p89_l2_tac_a_root = dut.dut.routerL2.admission.tx.anchor_mutex.root_a;
  wire        p89_l2_tac_a_grant0 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_a.grant0;
  wire        p89_l2_tac_a_grant1 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_a.grant1;
  wire        p89_l2_tac_b_req_up = dut.dut.routerL2.admission.tx.anchor_mutex.tac_b.req_up;
  wire        p89_l2_tac_b_arbo0 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_b.arbo0;
  wire        p89_l2_tac_b_arbo1 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_b.arbo1;
  wire        p89_l2_tac_b_root = dut.dut.routerL2.admission.tx.anchor_mutex.root_b;
  wire        p89_l2_tac_b_grant0 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_b.grant0;
  wire        p89_l2_tac_b_grant1 = dut.dut.routerL2.admission.tx.anchor_mutex.tac_b.grant1;
  wire        p89_l2_root_grant_a = dut.dut.routerL2.admission.tx.anchor_mutex.root.grant_a;
  wire        p89_l2_root_grant_b = dut.dut.routerL2.admission.tx.anchor_mutex.root.grant_b;
  wire        p89_l2_root_grant_p = dut.dut.routerL2.admission.tx.anchor_mutex.root.grant_p;
  wire [4:0]  p89_l2_anchor_q = dut.dut.routerL2.admission.tx.anchor_latch.q;
  wire        p89_l2_anchor_release_q = dut.dut.routerL2.admission.tx.kind_latch.q;
  wire        p89_l2_member_seen1 = dut.dut.routerL2.admission.tx.member1.member_seen;
  wire        p89_l2_member_seen2 = dut.dut.routerL2.admission.tx.member2.member_seen;
  wire        p89_l2_member_seen3 = dut.dut.routerL2.admission.tx.member3.member_seen;
  wire        p89_l2_member_seen4 = dut.dut.routerL2.admission.tx.member4.member_seen;
  wire        p89_l2_member_close1 = dut.dut.routerL2.admission.tx.member1.close_ready;
  wire        p89_l2_member_close2 = dut.dut.routerL2.admission.tx.member2.close_ready;
  wire        p89_l2_member_close3 = dut.dut.routerL2.admission.tx.member3.close_ready;
  wire        p89_l2_member_close4 = dut.dut.routerL2.admission.tx.member4.close_ready;
  wire        p89_l2_all_closed = dut.dut.routerL2.admission.tx.membership_join_all.Z;
  wire        p89_l2_tx_valid = dut.dut.routerL2.admission.tx_tx_valid;
  wire        p89_l2_tx_release = dut.dut.routerL2.admission.tx_tx_release;
  wire [4:0]  p89_l2_tx_winner = dut.dut.routerL2.admission.tx_tx_winner;
  wire [4:0]  p89_l2_tx_mask = dut.dut.routerL2.admission.tx_tx_mask1;
  wire        p89_l2_fire = dut.dut.routerL2.admission.commitController_fire_o;
  wire        p89_l2_acg_req = dut.dut.routerL2.admission.commitController.Out_0_Req;
  wire        p89_l2_acg_ack = dut.dut.routerL2.admission.commitController.Out_0_Ack;
  // The post-DC netlist optimizes the controller-local release_req/arb_req
  // names.  This derived level is their required release predicate provided
  // the V2 lifecycle invariant (active -> present) still holds.
  wire        p89_l2_release_expected = p89_l2_active & p89_l2_all_tail;
  wire        p89_all_tail = dut.dut.routerL1_1_0.tailJoin.io_allTailPassed_2;
  wire        p89_tail_ready = dut.dut.routerL1_1_0.admission.io_tailReleaseReady_2;
  wire        p89_active = dut.dut.routerL1_1_0.admission.io_packetActive_2;
  wire [4:0]  p89_mask = dut.dut.routerL1_1_0.admission.io_packetMask_2;
  wire [2:0]  p89_parent_owner = dut.dut.routerL1_1_0.admission.io_outputOwner_4;
  wire        p89_tx_valid = dut.dut.routerL1_1_0.admission.tx_tx_valid;
  wire        p89_tx_release = dut.dut.routerL1_1_0.admission.tx_tx_release;
  wire [4:0]  p89_tx_winner = dut.dut.routerL1_1_0.admission.tx_tx_winner;
  wire [4:0]  p89_tx_mask = dut.dut.routerL1_1_0.admission.tx_tx_mask2;
  wire        p89_fire = dut.dut.routerL1_1_0.admission.commitController_fire_o;

  integer p89_trace_fd;
  integer p89_trace_enable;
  reg [2047:0] p89_trace_file;
  reg [2047:0] p89_trace_vcd;
  task automatic p89_snapshot;
    input [8*24-1:0] tag;
    begin
      if (p89_trace_enable && (p89_trace_fd != 0)) begin
        $fdisplay(p89_trace_fd,
          "P89 t=%0t cycle=%0d tag=%0s in={req=%b ack=%b data=%h} V1={ReqX=%b AckX=%b en=%b tail=%b DataX=%h PRS=%b RS=%b} BR={admit=%b Req=%b Ack=%b Done=%b PPE=%b Grant=%b MG=%b} OPM={Req=%b Ack=%b Data=%h TP=%b} FIFO={enq=%b/%b enqD=%h deq=%b/%b deqD=%h} L2={ReqX=%b AckX=%b PRS=%b RS=%b admit=%b Req=%b Ack=%b Done=%b PPE=%b Grant=%b MG=%b out=%b/%b outD=%h down=%b/%b:%b/%b} AT={active=%b mask=%b ownerP=%0d allTail=%b tailReady=%b txV=%b txRel=%b txWin=%b txMask=%b fire=%b}",
          $time, dut.cycle_counter, tag, p89_in_req, p89_in_ack, p89_in_data,
          p89_reqx, p89_ackx, p89_v1_latch_en, p89_is_tail, p89_datax,
          p89_prs_ready, p89_raw_rs, p89_admitted, p89_req, p89_ack,
          p89_done, p89_ppe, p89_grant, p89_mg, p89_opm_req, p89_opm_ack,
          p89_opm_data, p89_tail_passed, p89_fifo_enq_req, p89_fifo_enq_ack,
          p89_fifo_enq_data, p89_fifo_deq_req, p89_fifo_deq_ack,
          p89_fifo_deq_data, p89_l2_reqx, p89_l2_ackx, p89_l2_prs_ready,
          p89_l2_raw_rs, p89_l2_admitted, p89_l2_req, p89_l2_ack,
          p89_l2_done, p89_l2_ppe, p89_l2_grant, p89_l2_mg,
          p89_l2_opm_req, p89_l2_opm_ack, p89_l2_opm_data,
          p89_down_enq_req, p89_down_enq_ack, p89_down_deq_req,
          p89_down_deq_ack, p89_active, p89_mask,
          p89_parent_owner, p89_all_tail, p89_tail_ready, p89_tx_valid,
          p89_tx_release, p89_tx_winner, p89_tx_mask, p89_fire);
      end
    end
  endtask

  // Simulation-only detail for the L2 input that consumes the stalled upward
  // FIFO entry.  This distinguishes an unfinished branch from a tail-release
  // barrier that is correctly withholding AckX.
  task automatic p89_l2_detail;
    input [8*24-1:0] tag;
    begin
      if (p89_trace_enable && (p89_trace_fd != 0)) begin
        $fdisplay(p89_trace_fd,
          "P89_L2_DETAIL t=%0t cycle=%0d tag=%0s fifoDeq={%b/%b D=%h} V1={ReqX=%b AckX=%b en=%b tail=%b Done=%b} life={P=%b Pq=%b relCommit=%b A=%b mask=%b allTail=%b tailReady=%b releaseExpected=%b} round={busy=%b seen=%b reset=%b anchorReq=%b anchorG=%b anchorQ=%b kind=%b TACa={up=%b arbo=%b%b root=%b grant=%b%b} TACb={up=%b arbo=%b%b root=%b grant=%b%b} root=%b%b%b memberSeen=%b memberClose=%b allClosed=%b} tx={V=%b Rel=%b Win=%b Mask=%b fire=%b acg=%b/%b} branch2={admit=%b Req=%b Ack=%b Done=%b PPE=%b Grant=%b MG=%b}",
          $time, dut.cycle_counter, tag, p89_fifo_deq_req, p89_fifo_deq_ack,
          p89_fifo_deq_data, p89_l2_reqx, p89_l2_ackx, p89_l2_v1_latch_en,
          p89_l2_is_tail, p89_l2_all_done, p89_l2_present, p89_l2_present_q,
          p89_l2_release_commit, p89_l2_active, p89_l2_mask, p89_l2_all_tail,
          p89_l2_tail_ready, p89_l2_release_expected, p89_l2_round_busy,
          p89_l2_commit_seen, p89_l2_round_reset, p89_l2_anchor_req,
          p89_l2_anchor_grant, p89_l2_anchor_q, p89_l2_anchor_release_q,
          p89_l2_tac_a_req_up, p89_l2_tac_a_arbo1, p89_l2_tac_a_arbo0,
          p89_l2_tac_a_root, p89_l2_tac_a_grant1, p89_l2_tac_a_grant0,
          p89_l2_tac_b_req_up, p89_l2_tac_b_arbo1, p89_l2_tac_b_arbo0,
          p89_l2_tac_b_root, p89_l2_tac_b_grant1, p89_l2_tac_b_grant0,
          p89_l2_root_grant_p, p89_l2_root_grant_b, p89_l2_root_grant_a,
          {p89_l2_member_seen4,p89_l2_member_seen3,p89_l2_member_seen2,p89_l2_member_seen1},
          {p89_l2_member_close4,p89_l2_member_close3,p89_l2_member_close2,p89_l2_member_close1},
          p89_l2_all_closed, p89_l2_tx_valid, p89_l2_tx_release,
          p89_l2_tx_winner, p89_l2_tx_mask, p89_l2_fire, p89_l2_acg_req,
          p89_l2_acg_ack, p89_l2_admitted, p89_l2_req,
          p89_l2_ack, p89_l2_done, p89_l2_ppe, p89_l2_grant, p89_l2_mg);
      end
    end
  endtask

  initial begin
    p89_trace_enable = 0;
    p89_trace_fd = 0;
    if ($value$plusargs("TAB_TRACE_PKT=%d", tab_trace_pkt) && (tab_trace_pkt == 89)) p89_trace_enable = 1;
    if (p89_trace_enable) begin
      if (!$value$plusargs("TAB_TRACE_FILE=%s", p89_trace_file)) p89_trace_file = "tab_port6_packet89.trace";
      p89_trace_fd = $fopen(p89_trace_file, "w");
      if (p89_trace_fd == 0) begin
        $display("TB_FATAL cannot open TAB_TRACE_FILE=%0s", p89_trace_file);
        $finish;
      end
      $fdisplay(p89_trace_fd, "# TAB r0p10 packet89: core6 Child2/L1(1,0) -> parent");
      if ($value$plusargs("TAB_TRACE_VCD=%s", p89_trace_vcd)) begin
        $dumpfile(p89_trace_vcd);
        $dumpvars(0, p89_in_req, p89_in_ack, p89_in_data, p89_reqx, p89_ackx,
                  p89_v1_latch_en, p89_is_tail, p89_datax, p89_prs_ready,
                  p89_raw_rs, p89_admitted, p89_req, p89_ack, p89_done,
                  p89_ppe, p89_grant, p89_mg, p89_tail_passed, p89_opm_req,
                  p89_opm_ack, p89_opm_data, p89_fifo_enq_req, p89_fifo_enq_ack,
                  p89_fifo_enq_data, p89_fifo_deq_req, p89_fifo_deq_ack,
                  p89_fifo_deq_data, p89_l2_reqx, p89_l2_ackx,
                  p89_l2_all_done, p89_l2_v1_latch_en, p89_l2_is_tail,
                  p89_l2_prs_ready, p89_l2_raw_rs, p89_l2_admitted,
                  p89_l2_req, p89_l2_ack, p89_l2_done, p89_l2_ppe,
                  p89_l2_grant, p89_l2_mg, p89_l2_opm_req, p89_l2_opm_ack,
                  p89_l2_opm_data, p89_down_enq_req, p89_down_enq_ack,
                  p89_down_deq_req, p89_down_deq_ack, p89_l2_all_tail,
                  p89_l2_tail_ready, p89_l2_present, p89_l2_present_q,
                  p89_l2_release_commit, p89_l2_active, p89_l2_mask,
                  p89_l2_round_busy, p89_l2_commit_seen, p89_l2_round_reset,
                  p89_l2_anchor_req, p89_l2_anchor_grant, p89_l2_anchor_q,
                  p89_l2_anchor_release_q, p89_l2_tac_a_req_up,
                  p89_l2_tac_a_arbo0, p89_l2_tac_a_arbo1, p89_l2_tac_a_root,
                  p89_l2_tac_a_grant0, p89_l2_tac_a_grant1, p89_l2_root_grant_a,
                  p89_l2_tac_b_req_up, p89_l2_tac_b_arbo0, p89_l2_tac_b_arbo1,
                  p89_l2_tac_b_root, p89_l2_tac_b_grant0, p89_l2_tac_b_grant1,
                  p89_l2_root_grant_b, p89_l2_root_grant_p,
                  p89_l2_member_seen1, p89_l2_member_seen2, p89_l2_member_seen3,
                  p89_l2_member_seen4, p89_l2_member_close1, p89_l2_member_close2,
                  p89_l2_member_close3, p89_l2_member_close4, p89_l2_all_closed,
                  p89_l2_tx_valid,
                  p89_l2_tx_release, p89_l2_tx_winner, p89_l2_tx_mask, p89_l2_fire,
                  p89_l2_acg_req, p89_l2_acg_ack, p89_l2_release_expected,
                  p89_all_tail, p89_tail_ready,
                  p89_active, p89_mask, p89_parent_owner, p89_tx_valid,
                  p89_tx_release, p89_tx_winner, p89_tx_mask, p89_fire);
      end
      p89_snapshot("TRACE_START");
      p89_l2_detail("TRACE_START");
    end
  end
  always @(p89_in_req or p89_in_ack or p89_in_data) p89_snapshot("INPUT");
  always @(p89_reqx or p89_ackx or p89_v1_latch_en or p89_is_tail or p89_datax or p89_prs_ready or p89_raw_rs) p89_snapshot("V1_PRS");
  always @(p89_admitted or p89_req or p89_ack or p89_done or p89_ppe or p89_grant or p89_mg) p89_snapshot("REQGEN_OPM");
  always @(p89_tail_passed or p89_opm_req or p89_opm_ack or p89_opm_data) p89_snapshot("OPM_OUT");
  always @(p89_fifo_enq_req or p89_fifo_enq_ack or p89_fifo_enq_data or p89_fifo_deq_req or p89_fifo_deq_ack or p89_fifo_deq_data) p89_snapshot("UP_FIFO");
  always @(p89_l2_reqx or p89_l2_ackx or p89_l2_prs_ready or p89_l2_raw_rs or
           p89_l2_admitted or p89_l2_req or p89_l2_ack or p89_l2_done or
           p89_l2_ppe or p89_l2_grant or p89_l2_mg or p89_l2_opm_req or
           p89_l2_opm_ack or p89_l2_opm_data or p89_down_enq_req or
           p89_down_enq_ack or p89_down_deq_req or p89_down_deq_ack) p89_snapshot("L2_CHAIN");
  always @(p89_l2_reqx or p89_l2_ackx or p89_l2_v1_latch_en or p89_l2_is_tail or
           p89_l2_all_done or p89_l2_present or p89_l2_present_q or
           p89_l2_release_commit or p89_l2_active or p89_l2_mask or p89_l2_all_tail or
           p89_l2_tail_ready or p89_l2_tx_valid or p89_l2_tx_release or
           p89_l2_tx_winner or p89_l2_tx_mask or p89_l2_fire or p89_l2_admitted or p89_l2_req or p89_l2_ack or
           p89_l2_done or p89_l2_ppe or p89_l2_grant or p89_l2_mg or p89_l2_release_expected or
           p89_l2_round_busy or p89_l2_commit_seen or p89_l2_round_reset or
           p89_l2_anchor_req or p89_l2_anchor_grant or p89_l2_anchor_q or p89_l2_anchor_release_q or
           p89_l2_tac_a_req_up or p89_l2_tac_a_arbo0 or p89_l2_tac_a_arbo1 or
           p89_l2_tac_a_root or p89_l2_tac_a_grant0 or p89_l2_tac_a_grant1 or
           p89_l2_tac_b_req_up or p89_l2_tac_b_arbo0 or p89_l2_tac_b_arbo1 or
           p89_l2_tac_b_root or p89_l2_tac_b_grant0 or p89_l2_tac_b_grant1 or
           p89_l2_root_grant_a or p89_l2_root_grant_b or p89_l2_root_grant_p or
           p89_l2_member_seen1 or p89_l2_member_seen2 or p89_l2_member_seen3 or p89_l2_member_seen4 or
           p89_l2_member_close1 or p89_l2_member_close2 or p89_l2_member_close3 or p89_l2_member_close4 or
           p89_l2_all_closed or p89_l2_acg_req or p89_l2_acg_ack or
           p89_fifo_deq_req or p89_fifo_deq_ack or p89_fifo_deq_data) p89_l2_detail("L2_DETAIL");
  always @(p89_active or p89_mask or p89_parent_owner or p89_all_tail or p89_tail_ready) p89_snapshot("TAIL_RELEASE");
  always @(p89_tx_valid or p89_tx_release or p89_tx_winner or p89_tx_mask or p89_fire) p89_snapshot("ATOMIC_TX");

  // TAB r0p30 first missing packet: core9 -> core0, packet sequence 246.
  // This is deliberately a read-only, path-specific trace.  Packet246's
  // Head reaches core0 but its Body/Tail do not; the trace therefore follows
  // the source L1(0,1) parent branch, the matching L2 child2 branch, and the
  // destination L1(0,0) parent-input branch.  None of these aliases feeds a
  // wrapper driver, receiver Ack, or DUT control input.
  wire        p246_in_req = dut.in_req[9];
  wire        p246_in_ack = dut.in_ack[9];
  wire [27:0] p246_in_data = dut.in_data[9*28 +: 28];
  wire        p246_l1_reqx = dut.dut.routerL1_0_1.inputModules_1.io_ReqX;
  wire        p246_l1_ackx = dut.dut.routerL1_0_1.inputModules_1.ackGenerator.io_AckX;
  wire        p246_l1_en = dut.dut.routerL1_0_1.inputModules_1.mousetrap.latch_en;
  wire        p246_l1_tail = dut.dut.routerL1_0_1.inputModules_1.mousetrap.DataOut[26];
  wire [3:0]  p246_l1_rs = {dut.dut.routerL1_0_1.inputModules_1.io_RS_3,
                            dut.dut.routerL1_0_1.inputModules_1.io_RS_2,
                            dut.dut.routerL1_0_1.inputModules_1.io_RS_1,
                            dut.dut.routerL1_0_1.inputModules_1.io_RS_0};
  wire        p246_l1_admit = dut.dut.routerL1_0_1.admission.io_admittedRS_1_3;
  wire        p246_l1_req = dut.dut.routerL1_0_1.requestBanks_1.io_Req_3;
  wire        p246_l1_done = dut.dut.routerL1_0_1.requestBanks_1.io_Done_3;
  wire        p246_l1_ppe = dut.dut.routerL1_0_1.requestBanks_1.io_PPE_3;
  wire        p246_l1_ack = dut.dut.routerL1_0_1.outputModules_4.io_Ack_1;
  wire        p246_l1_grant = dut.dut.routerL1_0_1.outputModules_4.io_Grant_1;
  wire        p246_l1_mg = dut.dut.routerL1_0_1.outputModules_4.io_MG_1;
  wire        p246_l1_tp = dut.dut.routerL1_0_1.outputModules_4.io_TailPassed_1;
  wire        p246_l1_out_req = dut.dut.routerL1_0_1.outputModules_4.io_ReqOut;
  wire        p246_l1_out_ack = dut.dut.routerL1_0_1.outputModules_4.io_AckOut;
  wire [27:0] p246_l1_out_data = dut.dut.routerL1_0_1.outputModules_4.io_DataOut_flit;
  wire        p246_l1_active = dut.dut.routerL1_0_1.admission.io_packetActive_1;
  wire [4:0]  p246_l1_mask = dut.dut.routerL1_0_1.admission.io_packetMask_1;
  wire        p246_l1_all_tail = dut.dut.routerL1_0_1.tailJoin.io_allTailPassed_1;
  wire        p246_l1_tail_ready = dut.dut.routerL1_0_1.admission.io_tailReleaseReady_1;
  wire        p246_l1_tx_valid = dut.dut.routerL1_0_1.admission.tx_tx_valid;
  wire        p246_l1_tx_release = dut.dut.routerL1_0_1.admission.tx_tx_release;
  wire        p246_l1_fire = dut.dut.routerL1_0_1.admission.commitController_fire_o;
  wire        p246_up_req = dut.dut.upwardLinkFifos_2.io_enq_HS_Req;
  wire        p246_up_ack = dut.dut.upwardLinkFifos_2.io_enq_HS_Ack;
  wire [27:0] p246_up_data = dut.dut.upwardLinkFifos_2.io_enq_Data_flit;
  wire        p246_up_deq_req = dut.dut.upwardLinkFifos_2.io_deq_HS_Req;
  wire        p246_up_deq_ack = dut.dut.upwardLinkFifos_2.io_deq_HS_Ack;
  wire [27:0] p246_up_deq_data = dut.dut.upwardLinkFifos_2.io_deq_Data_flit;
  wire        p246_l2_reqx = dut.dut.routerL2.inputModules_2.io_ReqX;
  wire        p246_l2_ackx = dut.dut.routerL2.inputModules_2.ackGenerator.io_AckX;
  wire        p246_l2_en = dut.dut.routerL2.inputModules_2.mousetrap.latch_en;
  wire        p246_l2_tail = dut.dut.routerL2.inputModules_2.mousetrap.DataOut[26];
  wire [3:0]  p246_l2_rs = {dut.dut.routerL2.inputModules_2.io_RS_3,
                            dut.dut.routerL2.inputModules_2.io_RS_2,
                            dut.dut.routerL2.inputModules_2.io_RS_1,
                            dut.dut.routerL2.inputModules_2.io_RS_0};
  // L2 input2 excludes physical Child2, so legal branch2 maps to physical
  // Child3/downward FIFO3.  OutputModules_3 local source2 is therefore fed
  // by RequestGeneratorBank input2 branch2 (not branch3).
  wire        p246_l2_admit = dut.dut.routerL2.admission.io_admittedRS_2_2;
  wire        p246_l2_req = dut.dut.routerL2.requestBanks_2.io_Req_2;
  wire        p246_l2_done = dut.dut.routerL2.requestBanks_2.io_Done_2;
  wire        p246_l2_ppe = dut.dut.routerL2.requestBanks_2.io_PPE_2;
  wire        p246_l2_ack = dut.dut.routerL2.outputModules_3.io_Ack_2;
  wire        p246_l2_grant = dut.dut.routerL2.outputModules_3.io_Grant_2;
  wire        p246_l2_mg = dut.dut.routerL2.outputModules_3.io_MG_2;
  wire        p246_l2_tp = dut.dut.routerL2.outputModules_3.io_TailPassed_2;
  wire        p246_l2_out_req = dut.dut.routerL2.outputModules_3.io_ReqOut;
  wire        p246_l2_out_ack = dut.dut.routerL2.outputModules_3.io_AckOut;
  wire [27:0] p246_l2_out_data = dut.dut.routerL2.outputModules_3.io_DataOut_flit;
  wire        p246_l2_active = dut.dut.routerL2.admission.io_packetActive_2;
  wire [4:0]  p246_l2_mask = dut.dut.routerL2.admission.io_packetMask_2;
  wire        p246_l2_all_tail = dut.dut.routerL2.tailJoin.io_allTailPassed_2;
  wire        p246_l2_tail_ready = dut.dut.routerL2.admission.io_tailReleaseReady_2;
  wire        p246_l2_tx_valid = dut.dut.routerL2.admission.tx_tx_valid;
  wire        p246_l2_tx_release = dut.dut.routerL2.admission.tx_tx_release;
  wire        p246_l2_fire = dut.dut.routerL2.admission.commitController_fire_o;
  wire        p246_down_req = dut.dut.downwardLinkFifos_3.io_enq_HS_Req;
  wire        p246_down_ack = dut.dut.downwardLinkFifos_3.io_enq_HS_Ack;
  wire [27:0] p246_down_data = dut.dut.downwardLinkFifos_3.io_enq_Data_flit;
  wire        p246_down_deq_req = dut.dut.downwardLinkFifos_3.io_deq_HS_Req;
  wire        p246_down_deq_ack = dut.dut.downwardLinkFifos_3.io_deq_HS_Ack;
  wire [27:0] p246_down_deq_data = dut.dut.downwardLinkFifos_3.io_deq_Data_flit;
  wire        p246_dst_reqx = dut.dut.routerL1_0_0.inputModules_4.io_ReqX;
  wire        p246_dst_ackx = dut.dut.routerL1_0_0.inputModules_4.ackGenerator.io_AckX;
  wire        p246_dst_en = dut.dut.routerL1_0_0.inputModules_4.mousetrap.latch_en;
  wire        p246_dst_tail = dut.dut.routerL1_0_0.inputModules_4.mousetrap.DataOut[26];
  // Core0 is Child3 of L1(0,0).  Parent input4 uses branch3 for physical
  // Child3, whose OPM legal-source index is 3 (the Parent ingress).
  wire        p246_dst_req = dut.dut.routerL1_0_0.requestBanks_4.io_Req_3;
  wire        p246_dst_done = dut.dut.routerL1_0_0.requestBanks_4.io_Done_3;
  wire        p246_dst_ppe = dut.dut.routerL1_0_0.requestBanks_4.io_PPE_3;
  // Simulation-only source-local OPM feedback: this establishes whether the
  // Head's V2 close event actually returns Ack to ReqGen.
  wire        p246_dst_opm_local_ack = dut.dut.routerL1_0_0.outputModules_3.io_Ack_3;
  wire        p246_dst_opm_local_grant = dut.dut.routerL1_0_0.outputModules_3.io_Grant_3;
  wire        p246_dst_opm_local_mg = dut.dut.routerL1_0_0.outputModules_3.io_MG_3;
  wire        p246_dst_opm_local_tp = dut.dut.routerL1_0_0.outputModules_3.io_TailPassed_3;
  // Pin-level post-DC view.  These are ports of retained cells/instances,
  // rather than Chisel-local aliases which DC is free to remove.
  wire        p246_dst_l1_d = dut.dut.routerL1_0_0.outputModules_3.requestLatches_3.d;
  wire        p246_dst_l1_e = dut.dut.routerL1_0_0.outputModules_3.requestLatches_3.en;
  wire        p246_dst_l1_q = dut.dut.routerL1_0_0.outputModules_3.requestLatches_3.q;
  wire        p246_dst_l5_d = dut.dut.routerL1_0_0.outputModules_3.requestOutLatch.d;
  wire        p246_dst_l5_e = dut.dut.routerL1_0_0.outputModules_3.requestOutLatch.en;
  wire        p246_dst_l5_q = dut.dut.routerL1_0_0.outputModules_3.requestOutLatch.q;
  wire        p246_dst_close_cp = dut.dut.routerL1_0_0.outputModules_3.closeEvent.close_clock;
  wire        p246_dst_ack_d = dut.dut.routerL1_0_0.outputModules_3.ackState_3_reg.D;
  wire        p246_dst_ack_cp = dut.dut.routerL1_0_0.outputModules_3.ackState_3_reg.CP;
  wire        p246_dst_ack_q = dut.dut.routerL1_0_0.outputModules_3.ackState_3_reg.Q;
  wire        p246_dst_opm_req = dut.dut.routerL1_0_0.outputModules_3.io_ReqOut;
  wire        p246_dst_opm_ack = dut.dut.routerL1_0_0.outputModules_3.io_AckOut;
  wire [27:0] p246_dst_opm_data = dut.dut.routerL1_0_0.outputModules_3.io_DataOut_flit;

  integer p246_trace_fd;
  integer p246_trace_enable;
  reg [2047:0] p246_trace_file;
  reg [2047:0] p246_trace_vcd;
  task automatic p246_snapshot;
    input [8*24-1:0] tag;
    begin
      if (p246_trace_enable && (p246_trace_fd != 0)) begin
        $fdisplay(p246_trace_fd,
          "P246 t=%0t cycle=%0d tag=%0s SRC={in=%b/%b:%h V1=%b/%b en=%b tail=%b RS=%b admit=%b Req=%b Ack=%b Done=%b PPE=%b G=%b MG=%b OPM=%b/%b:%h TP=%b life=%b/%b allTail=%b ready=%b tx=%b/%b fire=%b} UP={%b/%b:%h -> %b/%b:%h} L2={V1=%b/%b en=%b tail=%b RS=%b admit=%b Req=%b Ack=%b Done=%b PPE=%b G=%b MG=%b OPM=%b/%b:%h TP=%b life=%b/%b allTail=%b ready=%b tx=%b/%b fire=%b} DOWN={%b/%b:%h -> %b/%b:%h} DST={V1=%b/%b en=%b tail=%b Req=%b Done=%b PPE=%b OPM=%b/%b:%h}",
          $time, dut.cycle_counter, tag,
          p246_in_req, p246_in_ack, p246_in_data, p246_l1_reqx, p246_l1_ackx,
          p246_l1_en, p246_l1_tail, p246_l1_rs, p246_l1_admit, p246_l1_req,
          p246_l1_ack, p246_l1_done, p246_l1_ppe, p246_l1_grant, p246_l1_mg,
          p246_l1_out_req, p246_l1_out_ack, p246_l1_out_data, p246_l1_tp,
          p246_l1_active, p246_l1_mask, p246_l1_all_tail, p246_l1_tail_ready,
          p246_l1_tx_valid, p246_l1_tx_release, p246_l1_fire,
          p246_up_req, p246_up_ack, p246_up_data, p246_up_deq_req,
          p246_up_deq_ack, p246_up_deq_data, p246_l2_reqx, p246_l2_ackx,
          p246_l2_en, p246_l2_tail, p246_l2_rs, p246_l2_admit, p246_l2_req,
          p246_l2_ack, p246_l2_done, p246_l2_ppe, p246_l2_grant, p246_l2_mg,
          p246_l2_out_req, p246_l2_out_ack, p246_l2_out_data, p246_l2_tp,
          p246_l2_active, p246_l2_mask, p246_l2_all_tail, p246_l2_tail_ready,
          p246_l2_tx_valid, p246_l2_tx_release, p246_l2_fire,
          p246_down_req, p246_down_ack, p246_down_data, p246_down_deq_req,
          p246_down_deq_ack, p246_down_deq_data, p246_dst_reqx, p246_dst_ackx,
          p246_dst_en, p246_dst_tail, p246_dst_req, p246_dst_done, p246_dst_ppe,
          p246_dst_opm_req, p246_dst_opm_ack, p246_dst_opm_data);
        $fdisplay(p246_trace_fd,
          "P246_DSTCTRL t=%0t tag=%0s OPM={localAck=%b grant=%b mg=%b tp=%b} ACG={Done=%b AckX=%b} OUT={req=%b ack=%b data=%h}",
          $time, tag, p246_dst_opm_local_ack, p246_dst_opm_local_grant,
          p246_dst_opm_local_mg, p246_dst_opm_local_tp, p246_dst_done, p246_dst_ackx, p246_dst_opm_req,
          p246_dst_opm_ack, p246_dst_opm_data);
        $fdisplay(p246_trace_fd,
          "P246_DSTPINS t=%0t tag=%0s L1={D=%b E=%b Q=%b} L5={D=%b E=%b Q=%b} closeCP=%b AckDFF={D=%b CP=%b Q=%b}",
          $time, tag, p246_dst_l1_d, p246_dst_l1_e, p246_dst_l1_q,
          p246_dst_l5_d, p246_dst_l5_e, p246_dst_l5_q, p246_dst_close_cp,
          p246_dst_ack_d, p246_dst_ack_cp, p246_dst_ack_q);
      end
    end
  endtask
  initial begin
    p246_trace_enable = 0;
    p246_trace_fd = 0;
    if ($value$plusargs("TAB_TRACE_PKT=%d", tab_trace_pkt) && (tab_trace_pkt == 246)) p246_trace_enable = 1;
    if (p246_trace_enable) begin
      if (!$value$plusargs("TAB_TRACE_FILE=%s", p246_trace_file)) p246_trace_file = "tab_core9_packet246.trace";
      p246_trace_fd = $fopen(p246_trace_file, "w");
      if (p246_trace_fd == 0) begin
        $display("TB_FATAL cannot open TAB_TRACE_FILE=%0s", p246_trace_file);
        $finish;
      end
      $fdisplay(p246_trace_fd, "# TAB r0p30 packet246: core9/L1(0,1) -> core0/L1(0,0)");
      if ($value$plusargs("TAB_TRACE_VCD=%s", p246_trace_vcd)) begin
        $dumpfile(p246_trace_vcd);
        $dumpvars(0, p246_in_req, p246_in_ack, p246_in_data, p246_l1_reqx,
                  p246_l1_ackx, p246_l1_en, p246_l1_tail, p246_l1_rs,
                  p246_l1_admit, p246_l1_req, p246_l1_done, p246_l1_ppe,
                  p246_l1_ack, p246_l1_grant, p246_l1_mg, p246_l1_out_req,
                  p246_l1_out_ack, p246_l1_out_data, p246_l1_tp, p246_l1_active,
                  p246_l1_mask, p246_l1_all_tail, p246_l1_tail_ready,
                  p246_l1_tx_valid, p246_l1_tx_release, p246_l1_fire,
                  p246_up_req, p246_up_ack, p246_up_data, p246_up_deq_req,
                  p246_up_deq_ack, p246_up_deq_data, p246_l2_reqx, p246_l2_ackx,
                  p246_l2_en, p246_l2_tail, p246_l2_rs, p246_l2_admit, p246_l2_req,
                  p246_l2_done, p246_l2_ppe, p246_l2_ack, p246_l2_grant, p246_l2_mg,
                  p246_l2_out_req, p246_l2_out_ack, p246_l2_out_data, p246_l2_tp,
                  p246_l2_active, p246_l2_mask, p246_l2_all_tail, p246_l2_tail_ready,
                  p246_l2_tx_valid, p246_l2_tx_release, p246_l2_fire,
                  p246_down_req, p246_down_ack, p246_down_data, p246_down_deq_req,
                  p246_down_deq_ack, p246_down_deq_data, p246_dst_reqx, p246_dst_ackx,
                  p246_dst_en, p246_dst_tail, p246_dst_req, p246_dst_done,
                  p246_dst_ppe, p246_dst_opm_req, p246_dst_opm_ack, p246_dst_opm_data);
      end
      p246_snapshot("TRACE_START");
    end
  end
  always @(p246_in_req or p246_in_ack or p246_in_data or p246_l1_reqx or p246_l1_ackx or
           p246_l1_en or p246_l1_tail or p246_l1_rs or p246_l1_admit or p246_l1_req or
           p246_l1_ack or p246_l1_done or p246_l1_ppe or p246_l1_grant or p246_l1_mg or
           p246_l1_out_req or p246_l1_out_ack or p246_l1_out_data or p246_l1_tp or
           p246_l1_active or p246_l1_mask or p246_l1_all_tail or p246_l1_tail_ready or
           p246_l1_tx_valid or p246_l1_tx_release or p246_l1_fire or p246_up_req or
           p246_up_ack or p246_up_data or p246_up_deq_req or p246_up_deq_ack or
           p246_up_deq_data or p246_l2_reqx or p246_l2_ackx or p246_l2_en or p246_l2_tail or
           p246_l2_rs or p246_l2_admit or p246_l2_req or p246_l2_ack or p246_l2_done or
           p246_l2_ppe or p246_l2_grant or p246_l2_mg or p246_l2_out_req or p246_l2_out_ack or
           p246_l2_out_data or p246_l2_tp or p246_l2_active or p246_l2_mask or
           p246_l2_all_tail or p246_l2_tail_ready or p246_l2_tx_valid or p246_l2_tx_release or
           p246_l2_fire or p246_down_req or p246_down_ack or p246_down_data or
           p246_down_deq_req or p246_down_deq_ack or p246_down_deq_data or p246_dst_reqx or
           p246_dst_ackx or p246_dst_en or p246_dst_tail or p246_dst_req or p246_dst_done or
           p246_dst_ppe or p246_dst_opm_local_ack or p246_dst_opm_local_grant or
           p246_dst_opm_local_mg or p246_dst_opm_local_tp or p246_dst_opm_req or
           p246_dst_opm_ack or p246_dst_opm_data or p246_dst_l1_d or p246_dst_l1_e or
           p246_dst_l1_q or p246_dst_l5_d or p246_dst_l5_e or p246_dst_l5_q or
           p246_dst_close_cp or p246_dst_ack_d or p246_dst_ack_cp or p246_dst_ack_q)
    p246_snapshot("EDGE");
`else
  initial begin
    tab_trace_enable = 0;
    tab_trace_fd = 0;
  end
`endif

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
    debug_on_fail = 1;
    if ($test$plusargs("ASYNC_NOC16_DEBUG_ON_FAIL_OFF")) debug_on_fail = 0;
    injected_flits = 0;
    delivered_flits = 0;
    injected_packets = 0;
    delivered_packets = 0;
    status_timeout_hit = 0;
    status_rx_overflow = 0;
    open_diagnostics();
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
    if ($test$plusargs("ASYNC_NOC16_EDGE_TRACE"))
      $display("TB_EDGE kind=RESET_RELEASE cycle=0 t=%0t", $time);
    repeat (2) @(posedge clock);

    program_wrapper_from_case();
    run_wrapper();
    fetch_tx_accept_times();
    fetch_rx_entries();
    check_expectations();
    write_csv_and_finish();
  end

  async_noc16_axi_bram_wrapper #(
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
